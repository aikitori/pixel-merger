extends Node2D
## Arena auf dem Kreuz (siehe World): Bauphase (im Shop kaufen, frei platzieren, durch Ziehen
## verbinden) und automatische Kampfphase mit optionalen Positionsbefehlen.

const PICK_RADIUS := 14.0
## Finger sind ungenauer als die Maus: größerer Trefferradius beim Antippen.
const PICK_RADIUS_TOUCH := 18.0
## Beim Loslassen reicht es, in der Nähe der Zieleinheit zu sein (Finger sind ungenau).
const MERGE_RADIUS := 24.0
## Ab dieser Strecke wird aus einem Druck ein Ziehen (Finger zittern mehr als die Maus).
const DRAG_THRESHOLD := 4.0
const DRAG_THRESHOLD_TOUCH := 8.0
## Touch: Die gezogene Figur steht mit den Füßen knapp über dem Finger, sonst verdeckt er sie.
const TOUCH_LIFT := 6.0
## Touch: Langes Drücken ersetzt den Rechtsklick (Befehl an die Auswahl).
const LONG_PRESS_MSEC := 450
## Farben der Befehlsmarken: hinlaufen, angreifen, schützen.
const MARK_MOVE := Color(0.55, 1.0, 0.5)
const MARK_ATTACK := Color(1.0, 0.4, 0.3)
const MARK_GUARD := Color(0.4, 0.9, 1.0)
const MAX_ENEMIES := 80
## Gegner kommen in Rudeln (1 bis 3), dafür etwas seltener: mehr Gewusel bei ähnlicher Gesamtmenge.
const PACK_INTERVAL_FACTOR := 1.35
const PACK_SPREAD := 12.0

var _hud: Hud
var _dragging: Combatant
var _drag_origin := Vector2.ZERO
var _grab_offset := Vector2.ZERO
var _selected: Combatant  # Hauptauswahl: erste Einheit der Auswahl (Anzeige, Befehlsknopf)
var _selection: Array[Combatant] = []
## Mehrfachauswahl-Modus (Knopf): Antippen fügt Einheiten hinzu oder nimmt sie heraus.
var _multi_mode := false
## Laufender Druck (linke Maustaste oder Finger): Ort, Einheit darunter, ob schon gezogen wurde.
## Erst beim Loslassen entscheidet sich, ob es ein Klick, ein Ziehen oder ein Auswahlrahmen war.
var _pressing := false
var _press_start := Vector2.ZERO
var _press_unit: Combatant
var _press_msec := 0
var _press_touch := false
var _press_moved := false
var _press_long := false
var _press_shift := false
var _press_ctrl := false
## Der Druck hat die Einheit gerade erst gewählt (Bauphase): Das Loslassen wählt sie dann nicht wieder ab.
var _press_selected := false
var _box_active := false
## Steuergruppen 1-9 (Strg+Ziffer speichert, Ziffer wählt).
var _groups := {}
var _hovered: Combatant
var _cursor := Input.CURSOR_ARROW
## Die gezogene Einheit steht über einer, mit der sie sich jetzt verbinden würde.
var _drop_ok := false
## Zweiter Tipp auf dieselbe Einheit innerhalb dieser Zeit wählt alle gleichen Einheiten.
const DOUBLE_TAP_MSEC := 400
var _last_tap_unit: Combatant
var _last_tap_msec := -10000
## Der Befehl "Schützen" wartet auf den Tipp auf den Schützling.
var _picking_guard := false
## Touch: zuletzt angetippter Gegner, seine Werte stehen eine Weile in der Info (die Maus zeigt sie beim Darüberfahren).
const INSPECT_MSEC := 4000
var _inspected: Combatant
var _inspected_msec := 0
## Die Verbindungs-Vorschau beim Ziehen warnt (Runde noch nicht erreicht oder zu wenig Gold).
var _preview_warning := false
## Im Kampf gefallene eigene Einheiten (Einheit, Ort, Heimatposition) für die Fähigkeit Wiederbeleben.
var _fallen: Array[Dictionary] = []
## Bossrunde: der Boss und ob er schon gefallen ist. _losses zählt eigene Verluste der Runde (Erfolg "makellos").
var _boss: Combatant
var _boss_dead := false
var _losses := 0
## Letzte Zeigerposition aus den Eingabeereignissen (Maus oder Touch), in Arena-Koordinaten.
var _pointer := Vector2.ZERO
var _battle_time_left := 0.0
var _spawn_timer := 0.0
## Gemischter Vorrat der Arme: Jede Runde von vier Spawns kommt aus allen vier Richtungen.
var _arm_bag: Array[World.Arm] = []
## Runden seit dem letzten Ereignis (siehe RoundEvents).
var _rounds_without_event := 0
## Tests, die nur Eingaben prüfen, schalten die Ereignisse ab.
var events_enabled := true


signal enemy_spawned(enemy: Combatant, arm: World.Arm)

const BOSS_ARENA_NOTICES := {
	&"hall": "Der Boss erwartet euch im Thronsaal!",
	&"chasm": "Der Boss erwartet euch am Abgrund!",
	&"ring": "Der Boss erwartet euch in der Arena!",
}


func _ready() -> void:
	y_sort_enabled = true
	add_to_group(&"arena")
	Game.reset()
	# Fortsetzen aus dem Menü: gespeicherten Lauf laden, sonst beginnt ein neuer (alter Stand verfällt).
	var saved := RunSave.read() if Game.resume_requested else {}
	Game.resume_requested = false
	if saved.is_empty():
		RunSave.clear()
		Game.stats["record_before"] = Progress.best_round
	else:
		RunSave.apply_game(saved)
	World.set_round(Game.round_number)
	_hud = Hud.new()
	add_child(_hud)
	_hud.shop_pressed.connect(buy_unit)
	_hud.start_pressed.connect(start_battle)
	_hud.quick_buy_pressed.connect(buy_bundle)
	_hud.menu_pressed.connect(func() -> void:
		get_tree().paused = false
		save_run()  # nicht erst in _exit_tree: Dann sind die Einheiten schon aus dem Baum
		get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	_hud.order_pressed.connect(cycle_order)
	_hud.ability_pressed.connect(cast_selected)
	_hud.select_all_pressed.connect(select_all)
	_hud.merge_all_pressed.connect(merge_all)
	_hud.clear_selection = clear_selection
	_hud.return_pressed.connect(return_selected)
	_hud.event_chosen.connect(_on_event_chosen)
	_hud.multi_toggled.connect(func(on: bool) -> void: _multi_mode = on)
	_hud.restart_pressed.connect(func() -> void: get_tree().reload_current_scene())
	Game.phase_changed.connect(_on_phase_changed)
	Game.gold_changed.connect(func(_gold: int) -> void: _refresh_hints())
	Game.round_changed.connect(_on_round_changed)
	Game.houses_changed.connect(func() -> void:
		for unit in get_player_units():
			unit.refresh_blessings())
	_build_obstacles()
	add_child(Weather.new())
	if not saved.is_empty():
		_resume(saved)
	# Einstieg beim ersten Lauf (Tests ohne Fenster prüfen ihn gezielt, siehe events_test)
	if Progress.persist and not Progress.tutorial_done:
		start_tutorial()


func start_tutorial() -> Tutorial:
	var tutorial := Tutorial.new()
	tutorial.setup(self, _hud)
	_hud.add_child(tutorial)
	return tutorial


## Gespeicherten Lauf fortsetzen: Einheiten aufstellen, Anzeige auf den geladenen Stand bringen.
func _resume(saved: Dictionary) -> void:
	for entry in RunSave.units(saved):
		_spawn_player(entry["data"], World.clamp_point(entry["position"])).set_xp(entry["xp"])
	_rounds_without_event = int(saved.get("rounds_without_event", 0))
	Game.round_changed.emit(Game.round_number)
	Game.gold_changed.emit(Game.gold)
	Game.modifier_changed.emit(Game.modifier)
	Game.speed_changed.emit(Game.battle_speed)
	Game.blessings_changed.emit()
	Game.houses_changed.emit()
	Game.phase_changed.emit(Game.phase)
	_hud.toast(tr("Lauf fortgesetzt: Runde %d") % Game.round_number)
	if bool(saved.get("event_pending", false)) and events_enabled:
		# Dieselben Angebote wie vor dem Schließen, sonst ließe sich neu ziehen.
		var offers: Array[Dictionary] = []
		for entry: Dictionary in saved.get("event_offers", []):
			var offer := RoundEvents.from_save(entry, self)
			if not offer.is_empty():
				offers.append(offer)
		if offers.is_empty():
			offers = RoundEvents.offers(self)
		if not offers.is_empty():
			_hud.show_event(offers)


## Lauf speichern, aber nur aus der Bauphase: Im Kampf bleibt der Stand vom Kampfbeginn stehen.
func save_run() -> void:
	if Game.phase == Game.Phase.BUILD and is_instance_valid(_hud) and RunSave.enabled:
		RunSave.write(RunSave.capture(self, _hud.event_offers()))


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		_cancel_press()  # das Loslassen kommt nicht mehr an
		save_run()
		if is_instance_valid(_hud) and what != NOTIFICATION_WM_CLOSE_REQUEST:
			_hud.set_paused(true)  # im Kampf: Anruf oder App-Wechsel hält das Spiel an


## Bossrunden spielen in einer eigenen Arena. Nach einem Boss ändert sich das Gelände: neuer Mauerstil,
## drei Hindernisse weniger.
func _on_round_changed(round_number: int) -> void:
	var old_layout := World.layout_name
	var old_stage := World.stage
	World.set_round(round_number)
	if World.layout_name == old_layout and World.stage == old_stage:
		return
	_build_obstacles()
	for unit in get_player_units():  # Figuren dürfen nicht außerhalb des neuen Bodens stehen
		unit.position = World.clamp_point(unit.position)
		unit.home_position = unit.position
	queue_redraw()
	var notice := ""
	if World.layout_name != &"cross":
		notice = tr(String(BOSS_ARENA_NOTICES.get(World.layout_name, "Der Boss erwartet euch!")))
	elif World.stage > 0:
		notice = tr("Das Gelände hat sich verändert: weniger Hindernisse!")
	if notice != "":
		# Erst nach der Rundenmeldung zeigen, sonst überschreibt sie den Hinweis sofort.
		get_tree().create_timer(2.6).timeout.connect(func() -> void:
			if is_instance_valid(_hud):
				_hud.toast(notice))


func _build_obstacles() -> void:
	for node in get_tree().get_nodes_in_group(&"obstacle"):
		node.queue_free()
	for obstacle in World.obstacles:
		var sprite := Sprite2D.new()
		var kind: String = obstacle["kind"]
		sprite.texture = World.obstacle_texture(kind)
		sprite.centered = false
		sprite.offset = World.obstacle_offset(kind)
		sprite.position = obstacle["pos"]
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.add_to_group(&"obstacle")
		add_child(sprite)


func _on_phase_changed(_phase: int) -> void:
	queue_redraw()
	_refresh_hints()


func _draw() -> void:
	World.draw(self)
	if Game.phase == Game.Phase.BUILD:
		draw_rect(World.CENTER_SQUARE.grow(6.0), Color(1, 1, 1, 0.07))
		draw_rect(World.CENTER_SQUARE.grow(6.0), Color(1, 1, 1, 0.25), false, 1.0)
	if _box_active:
		var box := Rect2(_press_start, _pointer - _press_start).abs()
		draw_rect(box, Color(0.5, 0.9, 1.0, 0.15))
		draw_rect(box, Color(0.7, 0.95, 1.0, 0.9), false, 1.0)
	if Game.phase != Game.Phase.BATTLE:
		return
	for unit in get_player_units():
		if unit.has_order:
			if unit.highlighted:  # Weg der gewählten Einheiten zum Ziel
				draw_dashed_line(unit.position, unit.order_position, Color(MARK_MOVE, 0.35), 1.0, 3.0)
			draw_line(unit.order_position - Vector2(3, 3), unit.order_position + Vector2(3, 3), Color.WHITE, 1.0)
			draw_line(unit.order_position - Vector2(3, -3), unit.order_position + Vector2(3, -3), Color.WHITE, 1.0)
		if unit.is_guarding():  # Schutzband zum Schützling
			var shield := Color(MARK_GUARD, 0.6)
			draw_dashed_line(unit.center(), unit.guard_target.center(), shield, 1.0, 3.0)
			draw_arc(unit.guard_target.position, 9.0, 0.0, TAU, 16, shield, 1.0)
		if unit.is_attacking():
			var aim := Color(MARK_ATTACK, 0.7)
			if unit.highlighted:
				draw_dashed_line(unit.center(), unit.attack_target.center(), Color(aim, 0.35), 1.0, 3.0)
			draw_arc(unit.attack_target.position, 8.0, 0.0, TAU, 16, aim, 1.0)
	# Touch: Ring um den Finger füllt sich bis zum Befehl durch langes Drücken.
	if _pressing and _press_touch and not _press_moved and not _press_long and not _selection.is_empty():
		var held := float(Time.get_ticks_msec() - _press_msec) / LONG_PRESS_MSEC
		if held > 0.25:
			draw_arc(_press_start, 12.0, -PI / 2.0, -PI / 2.0 + TAU * minf(held, 1.0), 24, Color(1, 1, 1, 0.8), 2.0)


# --- Einheiten ---------------------------------------------------------------

func get_player_units() -> Array[Combatant]:
	var result: Array[Combatant] = []
	for node in get_tree().get_nodes_in_group(Combatant.GROUP_PLAYER):
		if not (node as Combatant).summoned:  # beschworene Helfer zählen nicht
			result.append(node as Combatant)
	return result


func buy_unit(data: UnitData) -> bool:
	if Game.phase != Game.Phase.BUILD:
		return false
	if get_player_units().size() >= Game.BUILD_MAX_UNITS:
		_hud.toast(tr("Arena voll (max. %d Einheiten)") % Game.BUILD_MAX_UNITS)
		Sound.play(&"error")
		return false
	var blocked := Registry.buy_block_reason(data)
	if blocked != "":
		_hud.toast("%s: %s" % [data.display_name, blocked])
		Sound.play(&"error")
		return false
	var price := Registry.shop_price(data)
	if not Game.spend_gold(price):
		_hud.toast(tr("Zu wenig Gold: %s kostet %dg") % [data.display_name, price])
		Sound.play(&"error")
		return false
	_spawn_player(data, _free_position())
	Sound.play(&"buy")
	_hud.toast(tr("%s gekauft (%d/%d)") % [data.display_name, get_player_units().size(), Game.MAX_UNITS])
	return true


## Schnellkauf (Rezeptbuch): alle Grundeinheiten eines Bündels auf einmal, oder gar nichts.
## Verbunden wird danach von Hand.
func buy_bundle(bundle: Dictionary) -> bool:
	if Game.phase != Game.Phase.BUILD or bundle.is_empty():
		return false
	var count := Registry.bundle_size(bundle)
	var price := Registry.bundle_price(bundle)
	for unit: UnitData in bundle:
		var blocked := Registry.buy_block_reason(unit)
		if blocked != "":
			_hud.toast("%s: %s" % [unit.display_name, blocked])
			Sound.play(&"error")
			return false
	if get_player_units().size() + count > Game.BUILD_MAX_UNITS:
		_hud.toast(tr("Arena voll: %d Einheiten passen nicht mehr (max. %d)") % [count, Game.BUILD_MAX_UNITS])
		Sound.play(&"error")
		return false
	if not Game.spend_gold(price):
		_hud.toast(tr("Zu wenig Gold: Schnellkauf kostet %dg") % price)
		Sound.play(&"error")
		return false
	for unit: UnitData in bundle:
		for i in bundle[unit]:
			_spawn_player(unit, _free_position())
	Sound.play(&"buy")
	_hud.toast(tr("%d Einheiten gekauft (%dg). Jetzt verbinden!") % [count, price])
	return true


## Neue Einheiten erscheinen in der Mitte der Arena.
func _free_position() -> Vector2:
	var blocked := _hud.shop_blocked_rect()
	var pos := World.random_center_point()
	for _attempt in 30:
		pos = World.random_center_point()
		if not blocked.has_point(pos):
			break
	return pos


## `quiet`: ohne Meldung und Klang je Merge (Alles verbinden meldet einmal am Ende).
func try_merge(a: Combatant, b: Combatant, quiet := false) -> bool:
	var recipe := Registry.find_recipe(a.unit_data, b.unit_data)
	if recipe == null:
		_hud.toast(tr("Diese Einheiten lassen sich nicht verbinden"))
		Sound.play(&"error")
		return false
	if recipe.unlock_round > Game.round_number:
		_hud.toast(tr("Erst ab Runde %d") % recipe.unlock_round)
		Sound.play(&"error")
		return false
	if not Game.spend_gold(recipe.merge_cost):
		_hud.toast(tr("Zu wenig Gold: %s kostet %dg") % [_result_name(recipe), recipe.merge_cost])
		Sound.play(&"error")
		return false
	var discovered := Progress.discover(recipe)
	var pos := b.position
	var experience := maxi(a.xp, b.xp)  # das Ergebnis behält die Erfahrung der erfahreneren Zutat
	a.discard()
	b.discard()
	_spawn_player(recipe.result, pos).set_xp(experience)
	Game.count_stat("merges")
	Achievements.report(&"merge")
	if recipe.ingredient_a != recipe.ingredient_b:
		Achievements.report(&"combo")
	if not quiet:
		_hud.toast("%s!" % recipe.result.display_name)
		Sound.play(&"merge", 0.0)
	if discovered:
		Achievements.report(&"secret")
		_hud.announce(tr("Geheimrezept entdeckt: %s!") % recipe.result.display_name)
		var burst := Effect.new()
		burst.setup(&"burst", pos + Vector2(0, -10), 40.0, UiTheme.GOLD_LIGHT)
		add_child(burst)
	return true


# --- Alles verbinden -------------------------------------------------------------

## Nächster Selbst-Merge für "Alles verbinden": zwei gleiche Einheiten, niedrigste Stufe zuerst, dann
## der billigste. Kombinationen aus verschiedenen Einheiten bleiben Entscheidung des Spielers.
## `counts`: UnitData -> Anzahl. Gibt die Zutat zurück oder null.
func _next_auto_merge(counts: Dictionary, gold: int) -> UnitData:
	var best: UnitData = null
	for data: UnitData in counts:
		if counts[data] < 2 or data.upgrade == null or data.upgrade.unlock_round > Game.round_number \
				or data.upgrade_cost > gold:
			continue
		if best == null or [data.level, data.upgrade_cost, data.id] < [best.level, best.upgrade_cost, best.id]:
			best = data
	return best


func _unit_counts() -> Dictionary:
	var counts := {}
	for unit in get_player_units():
		counts[unit.unit_data] = int(counts.get(unit.unit_data, 0)) + 1
	return counts


## Was "Alles verbinden" gerade täte: Vector2i(Anzahl Merges, Gesamtkosten). Rechnet nur, ändert nichts.
func merge_all_plan() -> Vector2i:
	var counts := _unit_counts()
	var gold := Game.gold
	var plan := Vector2i.ZERO
	while true:
		var data := _next_auto_merge(counts, gold)
		if data == null:
			break
		counts[data] -= 2
		counts[data.upgrade] = int(counts.get(data.upgrade, 0)) + 1
		gold -= data.upgrade_cost
		plan += Vector2i(1, data.upgrade_cost)
	return plan


## Knopf "Alles verbinden": führt den Plan aus. Die erfahrenste Einheit wird mit der unerfahrensten
## verbunden (das Ergebnis behält die höhere Erfahrung, so geht am wenigsten verloren).
func merge_all() -> int:
	if Game.phase != Game.Phase.BUILD or _dragging != null:
		return 0
	var merges := 0
	var cost := 0
	while true:
		var data := _next_auto_merge(_unit_counts(), Game.gold)
		if data == null:
			break
		var pair := get_player_units().filter(func(u: Combatant) -> bool: return u.unit_data == data)
		pair.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.xp > b.xp)
		if not try_merge(pair[0], pair[-1], true):
			break
		merges += 1
		cost += data.upgrade_cost
	if merges > 0:
		_apply_selection([] as Array[Combatant])
		_hud.toast(tr("%d-mal verbunden: -%d Gold") % [merges, cost])
		Sound.play(&"merge", 0.0)
	return merges


## Name des Ergebnisses, bei unentdeckten Geheimrezepten "???".
func _result_name(recipe: RecipeData) -> String:
	return "???" if Progress.is_hidden(recipe) else recipe.result.display_name


func _spawn_player(data: UnitData, pos: Vector2) -> Combatant:
	var unit := Combatant.new()
	unit.position = pos
	unit.setup_player(data)
	unit.died.connect(_on_died)
	add_child(unit)
	Game.note_unit(data)
	Achievements.report_max(&"army", get_player_units().size())
	if data.upgrade == null:
		Achievements.report(&"level5" if data.category != "Kombination" else &"combo_max")
	return unit


## Einheit unter dem Punkt: getroffen ist, wessen Sprite (mit Rand) den Punkt enthält oder wessen
## Mitte im Radius liegt. Bei mehreren gewinnt die mit der nächsten Mitte.
func _unit_at(point: Vector2, exclude: Combatant = null, radius := PICK_RADIUS) -> Combatant:
	var best: Combatant = null
	var best_dist := INF
	for unit in get_player_units():
		if unit == exclude:
			continue
		var dist := unit.center().distance_squared_to(point)
		if (dist <= radius * radius or unit.hit_rect().has_point(point)) and dist < best_dist:
			best_dist = dist
			best = unit
	return best


# --- Eingabe -------------------------------------------------------------------
# Wie in Strategiespielen: Maus links wählt, rechts befiehlt. Touch: Tippen wählt und befiehlt,
# langes Drücken ersetzt den Rechtsklick. Tastenkürzel siehe PlayerInput.

func _unhandled_input(event: InputEvent) -> void:
	PlayerInput.note(event)
	if event is InputEventKey:
		if event.pressed and not event.echo and _handle_key(event):
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	var point := _local_position(event)
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if _dragging != null:
			return
		_cancel_press()
		_secondary(point)
	elif event.button_index == MOUSE_BUTTON_LEFT and Game.phase in [Game.Phase.BUILD, Game.Phase.BATTLE]:
		_pressing = true
		_press_start = point
		_press_touch = PlayerInput.is_touch(event)
		_press_unit = _unit_at(point, null, _pick_radius())
		_press_msec = Time.get_ticks_msec()
		_press_moved = false
		_press_long = false
		_press_shift = event.shift_pressed
		_press_ctrl = event.ctrl_pressed or event.meta_pressed
		# Bauphase: sofort wählen, damit Karte und Rezepte schon beim Anfassen erscheinen.
		_press_selected = Game.phase == Game.Phase.BUILD and _press_unit != null and not _press_shift \
				and not _press_ctrl and not _selection.has(_press_unit)
		if _press_selected:
			_select(_press_unit)


# _input läuft vor den Buttons, damit ein Ziehen über die Leisten hinweg sauber endet.
func _input(event: InputEvent) -> void:
	if not event is InputEventMouse:
		return
	_pointer = _local_position(event)
	if not _pressing:
		return
	if event is InputEventMouseMotion:
		var threshold := DRAG_THRESHOLD_TOUCH if _press_touch else DRAG_THRESHOLD
		if not _press_moved and _pointer.distance_to(_press_start) > threshold:
			_press_moved = true
			_start_drag_or_box()
		if _dragging != null:
			_dragging.position = World.clamp_point(_pointer + _grab_offset)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_release()


## Aus dem Druck wird ein Ziehen: In der Bauphase nimmt es die Einheit mit, auf freiem Boden
## (beide Phasen) zieht es einen Auswahlrahmen auf.
func _start_drag_or_box() -> void:
	if _press_unit == null:
		_box_active = true
	elif Game.phase == Game.Phase.BUILD and is_instance_valid(_press_unit):
		_begin_drag(_press_unit)


func _release() -> void:
	_pressing = false
	if _dragging != null:
		_end_drag()
	elif _box_active:
		_box_active = false
		queue_redraw()
		if Game.phase in [Game.Phase.BUILD, Game.Phase.BATTLE]:
			_select_in_rect(Rect2(_press_start, _pointer - _press_start).abs(), _press_shift or _press_ctrl or _multi_mode)
	elif not _press_long and Game.phase in [Game.Phase.BUILD, Game.Phase.BATTLE]:
		_tap(_press_start)


## Druck abbrechen (Rechtsklick währenddessen, App im Hintergrund): Gezogenes bleibt stehen.
func _cancel_press() -> void:
	_pressing = false
	if _box_active:
		_box_active = false
		queue_redraw()
	if _dragging != null:
		_end_drag()


func _pick_radius() -> float:
	return PICK_RADIUS_TOUCH if PlayerInput.touch else PICK_RADIUS


func _process(_delta: float) -> void:
	if Game.phase == Game.Phase.GAME_OVER:
		_set_hovered(null)
		_update_cursor()
		return
	_check_long_press()
	if _dragging != null:
		var text := _merge_preview(_dragging)
		_hud.show_text(text, _preview_warning)
		_hud.show_unit_card(null if _hud.merge_preview_visible() else _dragging)
		_set_hovered(_unit_at(_dragging.center(), _dragging, MERGE_RADIUS))
		_update_cursor()
		return
	# Im Kampf gestorben? Ein freigegebenes Objekt gilt in Godot 4 als "== null",
	# ist aber kein gültiges Argument mehr, daher ausdrücklich zurücksetzen.
	_prune_selection()
	if _box_active:
		queue_redraw()
	_hud.set_order_unit(_selected, _picking_guard)
	_hud.set_return_selection(_selection.size(), _selection.reduce(func(sum: int, u: Combatant) -> int: return sum + refund_for(u), 0))
	_hud.show_unit_card(_selected, _selection.size() - 1)
	_hud.set_ability_unit(_selected, _selection)
	_hud.set_merge_all(merge_all_plan() if Game.phase == Game.Phase.BUILD else Vector2i.ZERO)
	# Touch kennt kein Schweben: dort zeigt die Info die zuletzt angetippte Einheit.
	var hovered := _unit_at(_pointer)
	_set_hovered(null if PlayerInput.touch else hovered)
	var foe := _enemy_at(_pointer) if not PlayerInput.touch else null
	if foe == null and is_instance_valid(_inspected) and _inspected._alive and Time.get_ticks_msec() - _inspected_msec < INSPECT_MSEC:
		foe = _inspected
	_hud.show_info(hovered if hovered != null else (foe if foe != null else _selected))
	_update_cursor()


## Touch: Finger lange ruhig auf dem Feld gehalten gibt den Befehl wie ein Rechtsklick (mit Rütteln).
func _check_long_press() -> void:
	if not _pressing or not _press_touch or _press_moved or _press_long or Game.phase != Game.Phase.BATTLE:
		return
	if _selection.is_empty() or Time.get_ticks_msec() - _press_msec < LONG_PRESS_MSEC:
		return
	_press_long = true
	Input.vibrate_handheld(30)
	_secondary(_press_start)


func _set_hovered(unit: Combatant) -> void:
	if unit == _hovered:
		return
	if is_instance_valid(_hovered):
		_hovered.hovered = false
	_hovered = unit
	if unit != null:
		unit.hovered = true


## Mauszeiger zeigt, was ein Klick bewirkt: greifen, ablegen, verbinden, angreifen.
func _update_cursor() -> void:
	var shape := Input.CURSOR_ARROW
	if PlayerInput.touch:
		pass
	elif _dragging != null:
		shape = Input.CURSOR_CAN_DROP if _drop_ok else (Input.CURSOR_FORBIDDEN if _preview_warning else Input.CURSOR_DRAG)
	elif _hovered != null:
		shape = Input.CURSOR_POINTING_HAND
	elif Game.phase == Game.Phase.BATTLE and not _selection.is_empty() and _enemy_at(_pointer) != null:
		shape = Input.CURSOR_CROSS
	if shape != _cursor:
		_cursor = shape
		Input.set_default_cursor_shape(shape)


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


## Position eines Mausereignisses in Arena-Koordinaten. Die Position kommt aus dem Ereignis
## selbst, so funktioniert es auch bei Touch-Eingaben und ohne gesetzte Mausposition.
func _local_position(event: InputEvent) -> Vector2:
	return (make_input_local(event) as InputEventMouse).position


func _merge_preview(unit: Combatant) -> String:
	_preview_warning = false
	_drop_ok = false
	var target := _unit_at(unit.center(), unit, MERGE_RADIUS)
	if target == null:
		_hud.hide_merge_preview()
		return unit.display_name
	var recipe := Registry.find_recipe(unit.unit_data, target.unit_data)
	if recipe == null:
		_hud.hide_merge_preview()
		return tr("%s: hier abstellen (nicht verbindbar mit %s)") % [unit.display_name, target.display_name]
	var cost_text := tr("Kosten: %dg") % recipe.merge_cost
	if recipe.unlock_round > Game.round_number:
		_preview_warning = true
		cost_text = tr("Erst ab Runde %d") % recipe.unlock_round
	elif Game.gold < recipe.merge_cost:
		_preview_warning = true
		cost_text = tr("Kosten: %dg (du hast %dg)") % [recipe.merge_cost, Game.gold]
	_drop_ok = not _preview_warning
	_hud.show_merge_preview(unit.unit_data, target.unit_data, recipe.result, cost_text, _preview_warning, Progress.is_hidden(recipe))
	var result_name := _result_name(recipe)
	if recipe.unlock_round > Game.round_number:
		return tr("%s: ab Runde %d") % [result_name, recipe.unlock_round]
	if Game.gold < recipe.merge_cost:
		_preview_warning = true
		return tr("%s: kostet %dg, du hast nur %dg") % [result_name, recipe.merge_cost, Game.gold]
	return tr("%s verbinden: %dg") % [result_name, recipe.merge_cost]


## Bauphase: Rezepte der gehaltenen oder allein gewählten Einheit anzeigen, sonst ausblenden.
func _refresh_hints() -> void:
	if not is_instance_valid(_hud):
		return
	if _dragging != null:
		_show_recipe_hints(_dragging)
	elif Game.phase == Game.Phase.BUILD and _selection.size() == 1 and is_instance_valid(_selected):
		_show_recipe_hints(_selected)
	else:
		_hud.hide_recipe_hints()


## Alle Rezepte der Einheit: zuerst die, die mit einer Figur auf dem Feld sofort gehen.
func _show_recipe_hints(unit: Combatant) -> void:
	var on_field := {}
	for other in get_player_units():
		if other != unit:
			on_field[other.unit_data] = int(on_field.get(other.unit_data, 0)) + 1
	var hints: Array[Dictionary] = []
	for recipe in Registry.recipes:
		if Progress.is_hidden(recipe):
			continue  # Geheimrezepte muss man selbst finden
		var partner: UnitData
		if recipe.ingredient_a == unit.unit_data:
			partner = recipe.ingredient_b
		elif recipe.ingredient_b == unit.unit_data:
			partner = recipe.ingredient_a
		else:
			continue
		var state := &"missing"
		if recipe.unlock_round > Game.round_number:
			state = &"locked"
		elif on_field.has(partner):
			state = &"now" if Game.gold >= recipe.merge_cost else &"gold"
		hints.append({"partner": partner, "result": recipe.result, "cost": recipe.merge_cost,
				"state": state, "round": recipe.unlock_round})
	var order := {&"now": 0, &"gold": 1, &"missing": 2, &"locked": 3}
	hints.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["state"] != b["state"]:
			return order[a["state"]] < order[b["state"]]
		return a["cost"] < b["cost"])
	_hud.show_recipe_hints(unit.display_name, hints.slice(0, Hud.HINT_ROWS), hints.size())


## Bauphase: Einheit aufnehmen. Sie wird zur Auswahl (Karte, Rezepte, Zurückschicken).
func _begin_drag(unit: Combatant) -> void:
	_select(unit)
	_dragging = unit
	_drag_origin = unit.position
	_grab_offset = Vector2(0, -TOUCH_LIFT) if _press_touch else unit.position - _press_start
	unit.highlighted = true
	unit.position = World.clamp_point(_pointer + _grab_offset)
	_refresh_hints()


func _end_drag() -> void:
	var unit := _dragging
	_dragging = null
	_hud.hide_merge_preview()
	_hud.show_unit_card(null)
	_set_hovered(null)
	unit.highlighted = _selection.has(unit)
	var target := _unit_at(unit.center(), unit, MERGE_RADIUS)
	# Ohne passendes Rezept einfach abstellen, damit verschiedene Einheiten nebeneinander stehen können.
	if target != null and Registry.find_recipe(unit.unit_data, target.unit_data) != null:
		if not try_merge(unit, target):
			unit.position = _drag_origin
	_refresh_hints()


## Kurzer Klick oder Tipp (ohne Ziehen). Einheit: wählen (Umschalt: hinzu/heraus, Strg oder Doppelklick:
## alle gleichen). Freier Boden: mit der Maus abwählen, per Touch im Kampf der Befehl an die Auswahl.
func _tap(point: Vector2) -> void:
	var unit: Combatant = _press_unit if is_instance_valid(_press_unit) and _press_unit._alive else null
	var additive := _press_shift or _multi_mode
	var now := Time.get_ticks_msec()
	if unit != null and not _picking_guard \
			and (_press_ctrl or (unit == _last_tap_unit and now - _last_tap_msec <= DOUBLE_TAP_MSEC)):
		_last_tap_unit = null
		_select_same_kind(unit, additive)
		return
	_last_tap_unit = unit
	_last_tap_msec = now
	if unit != null:
		if _picking_guard and is_instance_valid(_selected):
			_guard_with_selection(unit)
		elif additive:
			_toggle_selected(unit)
		elif _press_selected:
			pass  # schon beim Drücken gewählt
		elif unit in _selection and _selection.size() > 1:
			_select(unit)
		elif unit in _selection:
			# Touch: zweiter Tipp wählt ab und gibt die Einheit frei. Die Maus wählt mit Esc oder auf freiem Boden ab.
			if _press_touch:
				unit.clear_order()
				_select(null)
		else:
			_select(unit)
		# Ein Tipp, der die Einheit abgewählt hat, zählt nicht als erster Tipp eines Doppeltipps:
		# sonst wählt schnelles Ab- und wieder Antippen gleich alle Einheiten dieser Sorte.
		if not _selection.has(unit):
			_last_tap_unit = null
		return
	if _picking_guard and not _press_touch:
		_picking_guard = false  # Zielmodus: Klick daneben bricht ab
		return
	_picking_guard = false
	if _press_touch:
		var foe := _enemy_at(point, _pick_radius())
		if foe != null:
			_inspected = foe
			_inspected_msec = now
	if _press_touch and Game.phase == Game.Phase.BATTLE and not _selection.is_empty():
		_command_at(point)
	elif not additive:
		_select(null)


## Rechtsklick (Maus) oder langes Drücken (Touch). Im Kampf der Befehl an die Auswahl, sonst abwählen.
func _secondary(point: Vector2) -> void:
	if Game.phase == Game.Phase.BATTLE and not _selection.is_empty():
		var picking := _picking_guard
		_picking_guard = false
		var ally := _unit_at(point, null, _pick_radius())
		if picking and (ally == null or _selection.has(ally)):
			return  # Zielmodus abbrechen wie in Strategiespielen
		_command_at(point)
	else:
		clear_selection()


## Befehl an die Auswahl je nach Ziel: Gegner angreifen, andere eigene Einheit schützen,
## eigene gewählte Einheit freigeben, sonst hinlaufen.
func _command_at(point: Vector2) -> void:
	var radius := _pick_radius()
	var ally := _unit_at(point, null, radius)
	var enemy := _enemy_at(point, radius)
	if enemy != null and (ally == null or enemy.center().distance_squared_to(point) < ally.center().distance_squared_to(point)):
		for unit in _selection:
			unit.attack_unit(enemy)
		_mark(enemy.position, MARK_ATTACK)
	elif ally != null and not _selection.has(ally):
		_guard_with_selection(ally)
	elif ally != null:
		_clear_orders()
		_hud.toast(tr("Frei: kämpft selbstständig"))
	elif World.contains(point):
		_order_group(point)


## Gewählte Einheiten schützen `unit` (die Einheit selbst nicht).
func _guard_with_selection(unit: Combatant) -> void:
	_picking_guard = false
	var guards := 0
	for other in _selection:
		if other != unit:
			other.guard(unit)
			guards += 1
	if guards == 1:
		var guard: Combatant = _selection[0] if _selection[0] != unit else _selection[1]
		_hud.toast(tr("%s schützt %s") % [guard.display_name, unit.display_name])
	elif guards > 1:
		_hud.toast(tr("%d Einheiten schützen %s") % [guards, unit.display_name])
	if guards > 0:
		_mark(unit.position, MARK_GUARD)


## Kurze Marke am Befehlsziel, damit Klick und Tipp sichtbar ankommen.
func _mark(point: Vector2, color: Color) -> void:
	var mark := Effect.new()
	mark.setup(&"ring", point, 9.0, color)
	add_child(mark)


## Gegner unter dem Punkt (wie _unit_at).
func _enemy_at(point: Vector2, radius := PICK_RADIUS) -> Combatant:
	var best: Combatant = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group(Combatant.GROUP_ENEMY):
		var enemy := node as Combatant
		if not enemy._alive:
			continue
		var dist := enemy.center().distance_squared_to(point)
		if (dist <= radius * radius or enemy.hit_rect().has_point(point)) and dist < best_dist:
			best_dist = dist
			best = enemy
	return best


## Tastenkürzel für Auswahl und Befehle (Knopf-Kürzel und Pause stehen im Hud). true = verbraucht.
func _handle_key(event: InputEventKey) -> bool:
	if _hud.panel_open() or event.alt_pressed:
		return false
	var ctrl := event.ctrl_pressed or event.meta_pressed
	var group := PlayerInput.group_for(event)
	if group > 0:
		if ctrl:
			_store_group(group)
		else:
			_recall_group(group)
		return true
	if ctrl:
		if event.keycode == KEY_A:
			select_all(true)
			return true
		return false
	match PlayerInput.action_for(event):
		&"next":
			if _selection.size() > 1:
				var units: Array[Combatant] = _selection.duplicate()
				units.push_back(units.pop_front())
				_apply_selection(units)
			return true
		&"hold":
			if Game.phase == Game.Phase.BATTLE and not _selection.is_empty():
				for unit in _selection:
					unit.hold_position()
			return true
		&"stop":
			if Game.phase == Game.Phase.BATTLE:
				_picking_guard = false
				_clear_orders()
			return true
		&"guard":
			if Game.phase == Game.Phase.BATTLE and not _selection.is_empty():
				_start_guard_pick()
			return true
	return false


func _store_group(number: int) -> void:
	if _selection.is_empty():
		_groups.erase(number)
		return
	_groups[number] = _selection.duplicate()
	_hud.toast(tr("Gruppe %d: %d Einheiten") % [number, _selection.size()])


func _recall_group(number: int) -> void:
	var members: Array[Combatant] = []
	for unit in _groups.get(number, []):
		if is_instance_valid(unit) and unit._alive and unit.is_inside_tree():
			members.append(unit)
	if not members.is_empty():
		_apply_selection(members)


func _select_in_rect(rect: Rect2, additive: bool) -> void:
	var picked: Array[Combatant] = []
	if additive:
		picked.append_array(_selection)
	for unit in get_player_units():
		if rect.has_point(unit.center()) and not picked.has(unit):
			picked.append(unit)
	_apply_selection(picked)
	if picked.size() > 1:
		_hud.toast(tr("%d Einheiten gewählt") % picked.size())


## Doppeltipp: alle eigenen Einheiten derselben Sorte (gleiche Stufe) wählen.
func _select_same_kind(unit: Combatant, additive: bool) -> void:
	var picked: Array[Combatant] = []
	if additive:
		picked.append_array(_selection)
	for other in get_player_units():
		if other.unit_data == unit.unit_data and not picked.has(other):
			picked.append(other)
	# Die angetippte Einheit steht vorn: Karte und Befehlsknopf beziehen sich auf sie.
	picked.erase(unit)
	picked.push_front(unit)
	_apply_selection(picked)
	_hud.toast(tr("Alle %s gewählt (%d)") % [unit.display_name, picked.size()])


## Knopf "Alle"/"Keine": ohne Auswahl alle eigenen Einheiten wählen, sonst die Auswahl aufheben.
## Strg+A (`only_select`) wählt immer alle.
func select_all(only_select := false) -> void:
	if Game.phase != Game.Phase.BATTLE and Game.phase != Game.Phase.BUILD:
		return
	if not only_select and clear_selection():
		return
	var all: Array[Combatant] = []
	all.append_array(get_player_units())
	_apply_selection(all)
	if all.size() > 1:
		_hud.toast(tr("%d Einheiten gewählt") % all.size())


## Alle gewählten Einheiten laufen zum Punkt, ihre Abstände zueinander bleiben (begrenzt) erhalten.
func _order_group(point: Vector2) -> void:
	var center := Vector2.ZERO
	for unit in _selection:
		center += unit.position
	center /= _selection.size()
	for unit in _selection:
		var offset := (unit.position - center).limit_length(45.0) if _selection.size() > 1 else Vector2.ZERO
		unit.give_order(World.clamp_point(point + offset))
	_mark(point, MARK_MOVE)


## Auswahl aufheben (Knopf "Keine", Zurück/Esc, Rechtsklick in der Bauphase). Wartet der Befehl
## Schützen noch auf sein Ziel, bricht erst das ab. Gibt false zurück, wenn nichts gewählt war.
func clear_selection() -> bool:
	if _picking_guard:
		_picking_guard = false
		return true
	if Game.phase not in [Game.Phase.BUILD, Game.Phase.BATTLE] or _selection.is_empty():
		return false
	_apply_selection([] as Array[Combatant])
	return true


func _prune_selection() -> void:
	var alive: Array[Combatant] = []
	for unit in _selection:
		if is_instance_valid(unit) and unit._alive:
			alive.append(unit)
	if alive.size() != _selection.size():
		_apply_selection(alive)
	elif not is_instance_valid(_selected):
		_selected = null
		_picking_guard = false


## Auswahl setzen: Hervorhebung nachziehen, erste Einheit ist die Hauptauswahl.
func _apply_selection(units: Array[Combatant]) -> void:
	_picking_guard = false
	for unit in _selection:
		if is_instance_valid(unit) and not units.has(unit):
			unit.highlighted = false
	_selection = units
	for unit in _selection:
		unit.highlighted = true
	_selected = _selection[0] if not _selection.is_empty() else null
	_refresh_hints()


## Rückzahlung beim Zurückschicken: die Hälfte des Kaufpreises der Grundeinheiten (Verbinden kostet extra).
func refund_for(unit: Combatant) -> int:
	return roundi(Registry.bundle_price(Registry.base_units(unit.unit_data)) * Game.REFUND_SHARE)


## Bauphase: gewählte Einheiten zurückschicken und das halbe Geld zurückbekommen.
func return_selected() -> void:
	if Game.phase != Game.Phase.BUILD or _selection.is_empty():
		return
	var total := 0
	var count := 0
	for unit in _selection:
		if is_instance_valid(unit):
			total += refund_for(unit)
			count += 1
			unit.discard()
	_apply_selection([] as Array[Combatant])
	Game.add_gold(total)
	Sound.play(&"coin")
	_hud.toast(tr("%d Einheit(en) zurückgeschickt: +%d Gold") % [count, total])


func _toggle_selected(unit: Combatant) -> void:
	var units: Array[Combatant] = []
	units.append_array(_selection)
	if units.has(unit):
		units.erase(unit)
	else:
		units.append(unit)
	_apply_selection(units)


## Fähigkeitsknopf: löst die aktive Fähigkeit der gewählten Einheit(en) sofort aus.
func cast_selected() -> bool:
	if Game.phase != Game.Phase.BATTLE:
		return false
	if _selection.size() > 1:
		var tried := 0
		var fired := 0
		for unit in _selection:
			if Abilities.is_active(unit.ability) and unit.ability_cooldown_left() <= 0.0:
				tried += 1
				if unit.cast_now():
					fired += 1
					Achievements.report(&"manual")
			if unit.veteran_ready():
				tried += 1
				if unit.cast_veteran():
					fired += 1
					Achievements.report(&"manual")
		if fired == 0:
			_hud.toast(tr("Keine Fähigkeit bereit oder einsetzbar"))
			Sound.play(&"error")
			return false
		_hud.toast(tr("%d von %d Fähigkeiten ausgelöst") % [fired, tried])
		return true
	if not is_instance_valid(_selected):
		return false
	var unit := _selected
	# Veteranen: ist die eigene Fähigkeit nicht bereit, springt die Veteranenfähigkeit ein.
	if unit.veteran_ready() and not (Abilities.is_active(unit.ability) and unit.ability_cooldown_left() <= 0.0):
		if unit.cast_veteran():
			Achievements.report(&"manual")
			return true
	if not Abilities.is_active(unit.ability):
		_hud.toast("%s: %s" % [unit.display_name, tr("passive Fähigkeit wirkt immer") if unit.ability != &"" else tr("keine Fähigkeit")])
		return false
	if unit.ability_cooldown_left() > 0.0:
		_hud.toast(tr("%s lädt noch %d s") % [Abilities.display_name(unit.ability), ceili(unit.ability_cooldown_left())])
		Sound.play(&"error")
		return false
	if not unit.cast_now():
		_hud.toast(tr("%s: gerade nicht möglich (%s)") % [Abilities.display_name(unit.ability), Abilities.description(unit.ability)])
		Sound.play(&"error")
		return false
	Achievements.report(&"manual")
	return true


## Befehlsknopf: Freikampf -> Position halten -> Schützen (wartet auf den Tipp auf den Schützling) -> Freikampf.
## Gilt für alle gewählten Einheiten, der Modus der Hauptauswahl bestimmt den nächsten Schritt.
func cycle_order() -> void:
	if not is_instance_valid(_selected) or Game.phase != Game.Phase.BATTLE:
		return
	if _picking_guard:
		_picking_guard = false
		_clear_orders()
		return
	match _selected.order_mode():
		&"free":
			for unit in _selection:
				unit.hold_position()
		&"hold":
			if not _start_guard_pick():
				_clear_orders()
		_:
			_clear_orders()


## Befehl Schützen: wartet auf Klick oder Tipp auf den Schützling (Rechtsklick oder Esc bricht ab).
func _start_guard_pick() -> bool:
	if get_player_units().size() <= _selection.size():
		_hud.toast(tr("Zum Schützen braucht es eine weitere Einheit"))
		Sound.play(&"error")
		return false
	_picking_guard = true
	_hud.toast(tr("Tippe die Einheit, die geschützt werden soll") if PlayerInput.touch \
			else tr("Klicke die Einheit, die geschützt werden soll"))
	return true


func _clear_orders() -> void:
	for unit in _selection:
		unit.clear_order()


func _select(unit: Combatant) -> void:
	var units: Array[Combatant] = []
	if unit != null:
		units.append(unit)
	_apply_selection(units)


# --- Kampfphase ----------------------------------------------------------------

func start_battle() -> bool:
	if Game.phase != Game.Phase.BUILD:
		return false
	var units := get_player_units()
	if units.is_empty():
		_hud.toast(tr("Erst Einheiten im Shop kaufen"))
		Sound.play(&"error")
		return false
	if units.size() > Game.MAX_UNITS:
		_hud.toast(tr("Zu viele Einheiten: im Kampf nur %d, schicke %d zurück") % [Game.MAX_UNITS, units.size() - Game.MAX_UNITS])
		Sound.play(&"error")
		return false
	save_run()  # Stand vor dem Kampf: Wird die App im Kampf geschlossen, geht es hier weiter
	for unit in units:
		unit.home_position = unit.position
		unit.clear_order()
		unit.apply_round_modifier()
	_fallen.clear()
	_losses = 0
	_boss = null
	_boss_dead = false
	Game.boss_enraged = false
	_battle_time_left = Game.battle_seconds()
	_spawn_timer = 0.5
	_hud.set_time(_battle_time_left)
	match Game.round_kind():
		Game.RoundKind.BOSS:
			_spawn_boss()
			_hud.toast(tr("Bossrunde! %s erscheint") % _boss.display_name)
		Game.RoundKind.BONUS:
			_hud.toast(tr("Bonusrunde! Gegner geben dreifaches Gold"))
	Game.set_phase(Game.Phase.BATTLE)
	return true


func _physics_process(frame_delta: float) -> void:
	if Game.phase != Game.Phase.BATTLE:
		return
	var delta := Game.battle_delta(frame_delta)
	_battle_time_left -= delta
	_spawn_timer -= delta
	var boss_round := Game.round_kind() == Game.RoundKind.BOSS
	while _spawn_timer <= 0.0:
		_spawn_enemy()
		_spawn_timer += Game.spawn_interval() * PACK_INTERVAL_FACTOR * (1.6 if boss_round else 1.0)
	_hud.set_time(_battle_time_left)
	queue_redraw()
	if boss_round:
		_hud.set_boss(_boss if not _boss_dead else null)
		if _boss_dead:
			_end_round()
		elif _battle_time_left <= 0.0 and not Game.boss_enraged:
			# Zeit um, Boss lebt: Er wird wütend, die Runde endet erst mit seinem Tod.
			Game.boss_enraged = true
			if is_instance_valid(_boss):
				_boss.enrage()
			_hud.toast(tr("Der Boss tobt!"))
			Sound.play(&"battle_start", 0.0)
			_hud.set_time(0.0)
	elif _battle_time_left <= 0.0:
		_end_round()


func _next_arm() -> World.Arm:
	if _arm_bag.is_empty():
		for arm in World.Arm.values():
			_arm_bag.append(arm)
		_arm_bag.shuffle()
	return _arm_bag.pop_back()


func _spawn_boss() -> void:
	_boss = Combatant.new()
	_boss.position = World.spawn_point(_next_arm())
	_boss.setup_enemy(Registry.boss_for_round(Game.round_number))
	_boss.died.connect(_on_died)
	add_child(_boss)


func _spawn_enemy() -> void:
	if get_tree().get_nodes_in_group(Combatant.GROUP_ENEMY).size() >= MAX_ENEMIES:
		return
	var arm := _next_arm()
	# Rudel wachsen mit der Runde: erst einzelne Gegner, später Gruppen bis 3.
	var pack := 1 + (1 if Game.round_number >= 4 and randf() < 0.4 else 0) + (1 if Game.round_number >= 8 and randf() < 0.3 else 0)
	var kind := Registry.pick_enemy(Game.round_number)
	for i in pack:
		var enemy := Combatant.new()
		enemy.position = World.clamp_point(World.spawn_point(arm) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * PACK_SPREAD * i)
		enemy.setup_enemy(kind if randf() < 0.7 else Registry.pick_enemy(Game.round_number))
		if randf() < Game.elite_chance():
			enemy.make_elite()
		enemy.died.connect(_on_died)
		add_child(enemy)
		enemy_spawned.emit(enemy, arm)


func _on_died(combatant: Combatant) -> void:
	if combatant.team == Combatant.Team.ENEMY:
		if combatant.summoned:  # Helfer eines Gegners: keine Beute, zählt nicht
			return
		Game.add_gold(combatant.gold_reward)
		Game.count_stat("kills")
		Game.count_stat("gold", combatant.gold_reward)
		if Game.modifier == &"gold_rain" and Effect.can_spawn_ambient():
			var coin := Effect.new()
			coin.setup(&"text", combatant.position + Vector2(0, -combatant.body_size), 0.0, UiTheme.GOLD_LIGHT, "+%dg" % combatant.gold_reward)
			add_child(coin)
		Achievements.report(&"kill")
		if combatant.is_boss:
			_boss_dead = true
			Achievements.report(&"boss")
			_hud.toast(tr("%s besiegt! +%d Gold") % [combatant.display_name, combatant.gold_reward])
			Sound.play(&"round_win", 0.0)
	elif Game.phase == Game.Phase.BATTLE:
		_losses += 1
		_fallen.append({"data": combatant.unit_data, "position": combatant.position, "home": combatant.home_position, "xp": combatant.xp})
		if get_player_units().is_empty():
			_game_over()


## Fähigkeit Wiederbeleben: der zuletzt gefallene Verbündete steht mit halben Lebenspunkten neben `reviver`
## wieder auf. Gibt false zurück, wenn niemand gefallen ist.
func revive_fallen(reviver: Combatant) -> bool:
	if _fallen.is_empty() or Game.phase != Game.Phase.BATTLE:
		return false
	var entry: Dictionary = _fallen.pop_back()
	var unit := _spawn_player(entry["data"], World.clamp_point(reviver.position + Vector2(randf_range(-14, 14), 10)))
	unit.home_position = entry["home"]
	unit.set_xp(int(entry.get("xp", 0)))
	unit.health = unit.max_health * 0.5
	Achievements.report(&"revive")
	return true


## Gegner und beschworene Helfer vom Feld nehmen (Rundenende, Niederlage).
func _clear_enemies() -> void:
	for node in get_tree().get_nodes_in_group(Combatant.GROUP_ENEMY):
		(node as Combatant).discard()
	for node in get_tree().get_nodes_in_group(Combatant.GROUP_PLAYER):
		if (node as Combatant).summoned:
			(node as Combatant).discard()


func _end_round() -> void:
	var kind := Game.round_kind()
	var message := tr("Runde überstanden!")
	if kind == Game.RoundKind.BONUS:
		var prize := Game.bonus_prize()
		Game.add_gold(prize)
		Game.count_stat("gold", prize)
		Achievements.report(&"bonus")
		message = tr("Bonusrunde geschafft! +%d Gold Prämie") % prize
	elif kind == Game.RoundKind.BOSS:
		message = tr("Bossrunde geschafft!")
	if Game.modifier != &"":
		Achievements.report(&"modifier")
	if _losses == 0:
		Achievements.report(&"perfect")
		message += tr(" Makellos!")
	_clear_enemies()
	_select(null)
	_boss = null
	_hud.set_boss(null)
	for unit in get_player_units():
		unit.gain_xp(Combatant.XP_SURVIVE)  # Überleben bringt Erfahrung
		unit.reset_after_battle()
		unit.position = unit.home_position
	Game.next_round()
	Achievements.report_max(&"round", Game.round_number)
	Progress.record_round(Game.round_number)
	_hud.toast(message)
	Sound.play(&"round_win", 0.0)
	_maybe_offer_event(kind == Game.RoundKind.BOSS)
	save_run()


## `sure`: nach einem Boss wartet immer ein Ereignis (Beute und Belohnung für den Sieg).
func _maybe_offer_event(sure := false) -> void:
	if not events_enabled:
		return
	if not sure and not RoundEvents.should_offer(Game.round_number, _rounds_without_event):
		_rounds_without_event += 1
		return
	var offers := RoundEvents.offers(self)
	if offers.is_empty():
		return
	_rounds_without_event = 0
	_hud.show_event(offers)


func _on_event_chosen(offer: Dictionary) -> void:
	var message := RoundEvents.apply(offer, self)
	if message == "":
		_hud.toast(tr("Das geht gerade nicht"))
		Sound.play(&"error")
		return
	Achievements.report(&"event")
	_hud.toast(message)
	Sound.play(&"merge", 0.0)
	save_run()


func _game_over() -> void:
	Game.set_phase(Game.Phase.GAME_OVER)
	RunSave.clear()
	Progress.record_round(Game.round_number)
	_clear_enemies()
	_select(null)
	_hud.show_game_over(Game.round_number, Game.stats, Progress.best_round,
			Game.round_number > int(Game.stats.get("record_before", 0)))
