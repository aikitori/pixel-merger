extends Node2D
## Arena auf dem Kreuz (siehe World): Bauphase (im Shop kaufen, frei platzieren, durch Ziehen
## verbinden) und automatische Kampfphase mit optionalen Positionsbefehlen.

const PICK_RADIUS := 14.0
## Beim Loslassen reicht es, in der Nähe der Zieleinheit zu sein (Finger sind ungenau).
const MERGE_RADIUS := 24.0
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
var _box_pending := false
var _box_active := false
var _box_start := Vector2.ZERO
const BOX_MIN_DRAG := 10.0
## Zweiter Tipp auf dieselbe Einheit innerhalb dieser Zeit wählt alle gleichen Einheiten.
const DOUBLE_TAP_MSEC := 400
var _last_tap_unit: Combatant
var _last_tap_msec := -10000
## Der Befehl "Schützen" wartet auf den Tipp auf den Schützling.
var _picking_guard := false
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


signal enemy_spawned(enemy: Combatant, arm: World.Arm)


func _ready() -> void:
	y_sort_enabled = true
	add_to_group(&"arena")
	Game.reset()
	World.set_stage(World.stage_for_round(Game.round_number))
	_hud = Hud.new()
	add_child(_hud)
	_hud.shop_pressed.connect(buy_unit)
	_hud.start_pressed.connect(start_battle)
	_hud.quick_buy_pressed.connect(buy_bundle)
	_hud.menu_pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	_hud.order_pressed.connect(cycle_order)
	_hud.ability_pressed.connect(cast_selected)
	_hud.select_all_pressed.connect(select_all)
	_hud.multi_toggled.connect(func(on: bool) -> void: _multi_mode = on)
	_hud.restart_pressed.connect(func() -> void: get_tree().reload_current_scene())
	Game.phase_changed.connect(_on_phase_changed)
	Game.round_changed.connect(_on_round_changed)
	_build_obstacles()


## Nach einem Boss ändert sich das Gelände: drei Hindernisse verschwinden.
func _on_round_changed(round_number: int) -> void:
	var new_stage := World.stage_for_round(round_number)
	if new_stage == World.stage:
		return
	World.set_stage(new_stage)
	_build_obstacles()
	if new_stage > 0:
		_hud.toast(tr("Das Gelände hat sich verändert: weniger Hindernisse!"))


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


func _draw() -> void:
	World.draw(self)
	if Game.phase == Game.Phase.BUILD:
		draw_rect(World.CENTER_SQUARE.grow(6.0), Color(1, 1, 1, 0.07))
		draw_rect(World.CENTER_SQUARE.grow(6.0), Color(1, 1, 1, 0.25), false, 1.0)
	elif Game.phase == Game.Phase.BATTLE:
		if _box_active:
			var box := Rect2(_box_start, _pointer - _box_start).abs()
			draw_rect(box, Color(0.5, 0.9, 1.0, 0.15))
			draw_rect(box, Color(0.7, 0.95, 1.0, 0.9), false, 1.0)
		for unit in get_player_units():
			if unit.has_order:
				draw_line(unit.order_position - Vector2(3, 3), unit.order_position + Vector2(3, 3), Color.WHITE, 1.0)
				draw_line(unit.order_position - Vector2(3, -3), unit.order_position + Vector2(3, -3), Color.WHITE, 1.0)
			if unit.is_guarding():  # Schutzband zum Schützling
				var shield := Color(0.4, 0.9, 1.0, 0.6)
				draw_dashed_line(unit.center(), unit.guard_target.center(), shield, 1.0, 3.0)
				draw_arc(unit.guard_target.position, 9.0, 0.0, TAU, 16, shield, 1.0)


# --- Einheiten ---------------------------------------------------------------

func get_player_units() -> Array[Combatant]:
	var result: Array[Combatant] = []
	for node in get_tree().get_nodes_in_group(Combatant.GROUP_PLAYER):
		result.append(node as Combatant)
	return result


func buy_unit(data: UnitData) -> bool:
	if Game.phase != Game.Phase.BUILD:
		return false
	if get_player_units().size() >= Game.MAX_UNITS:
		_hud.toast(tr("Arena voll (max. %d Einheiten)") % Game.MAX_UNITS)
		Sound.play(&"error")
		return false
	if not Game.spend_gold(data.price):
		_hud.toast(tr("Zu wenig Gold: %s kostet %dg") % [data.display_name, data.price])
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
	if get_player_units().size() + count > Game.MAX_UNITS:
		_hud.toast(tr("Arena voll: %d Einheiten passen nicht mehr (max. %d)") % [count, Game.MAX_UNITS])
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


func try_merge(a: Combatant, b: Combatant) -> bool:
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
		_hud.toast(tr("Zu wenig Gold: %s kostet %dg") % [recipe.result.display_name, recipe.merge_cost])
		Sound.play(&"error")
		return false
	var pos := b.position
	a.discard()
	b.discard()
	_spawn_player(recipe.result, pos)
	Achievements.report(&"merge")
	if recipe.ingredient_a != recipe.ingredient_b:
		Achievements.report(&"combo")
	_hud.toast("%s!" % recipe.result.display_name)
	Sound.play(&"merge", 0.0)
	return true


func _spawn_player(data: UnitData, pos: Vector2) -> Combatant:
	var unit := Combatant.new()
	unit.position = pos
	unit.setup_player(data)
	unit.died.connect(_on_died)
	add_child(unit)
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

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	var point := _local_position(event)
	if Game.phase == Game.Phase.BUILD:
		_begin_drag(point)
	elif Game.phase == Game.Phase.BATTLE:
		# Ausgeführt wird erst beim Loslassen: Ziehen auf freiem Boden zieht einen Auswahlrahmen auf.
		_box_pending = true
		_box_active = false
		_box_start = point


# _input läuft vor den Buttons, damit ein Ziehen über die Leisten hinweg sauber endet.
func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_pointer = _local_position(event)
	if _box_pending:
		_handle_box_input(event)
	if _dragging == null:
		return
	if event is InputEventMouseMotion:
		_dragging.position = World.clamp_point(_pointer + _grab_offset)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag()


func _process(_delta: float) -> void:
	if Game.phase == Game.Phase.GAME_OVER:
		return
	if _dragging != null:
		var text := _merge_preview(_dragging)
		_hud.show_text(text, _preview_warning)
		_hud.show_unit_card(null if _hud.merge_preview_visible() else _dragging)
		return
	# Im Kampf gestorben? Ein freigegebenes Objekt gilt in Godot 4 als "== null",
	# ist aber kein gültiges Argument mehr, daher ausdrücklich zurücksetzen.
	_prune_selection()
	if _box_active:
		queue_redraw()
	_hud.set_order_unit(_selected, _picking_guard)
	_hud.show_unit_card(_selected, _selection.size() - 1)
	_hud.set_ability_unit(_selected, _selection)
	var hovered := _unit_at(_pointer)
	_hud.show_info(hovered if hovered != null else _selected)


## Position eines Mausereignisses in Arena-Koordinaten. Die Position kommt aus dem Ereignis
## selbst, so funktioniert es auch bei Touch-Eingaben und ohne gesetzte Mausposition.
func _local_position(event: InputEvent) -> Vector2:
	return (make_input_local(event) as InputEventMouse).position


func _merge_preview(unit: Combatant) -> String:
	_preview_warning = false
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
	_hud.show_merge_preview(unit.unit_data, target.unit_data, recipe.result, cost_text, _preview_warning)
	if recipe.unlock_round > Game.round_number:
		return tr("%s: ab Runde %d") % [recipe.result.display_name, recipe.unlock_round]
	if Game.gold < recipe.merge_cost:
		_preview_warning = true
		return tr("%s: kostet %dg, du hast nur %dg") % [recipe.result.display_name, recipe.merge_cost, Game.gold]
	return tr("%s verbinden: %dg") % [recipe.result.display_name, recipe.merge_cost]


## Alle Rezepte der gehaltenen Einheit: zuerst die, die mit einer Figur auf dem Feld sofort gehen.
func _show_recipe_hints(unit: Combatant) -> void:
	var on_field := {}
	for other in get_player_units():
		if other != unit:
			on_field[other.unit_data] = int(on_field.get(other.unit_data, 0)) + 1
	var hints: Array[Dictionary] = []
	for recipe in Registry.recipes:
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


func _begin_drag(point: Vector2) -> void:
	var unit := _unit_at(point)
	if unit == null:
		return
	_dragging = unit
	_show_recipe_hints(unit)
	_drag_origin = unit.position
	_grab_offset = unit.position - point
	unit.highlighted = true


func _end_drag() -> void:
	var unit := _dragging
	_dragging = null
	_hud.hide_merge_preview()
	_hud.show_unit_card(null)
	_hud.hide_recipe_hints()
	unit.highlighted = false
	var target := _unit_at(unit.center(), unit, MERGE_RADIUS)
	if target == null:
		return
	# Ohne passendes Rezept einfach abstellen, damit verschiedene Einheiten nebeneinander stehen können.
	if Registry.find_recipe(unit.unit_data, target.unit_data) == null:
		return
	if not try_merge(unit, target):
		unit.position = _drag_origin


## Kampfphase: Einheit antippen wählt sie aus, ein Tipp aufs Feld schickt sie dorthin.
## Erneutes Antippen der gewählten Einheit hebt den Befehl auf (wieder automatisch).
func _command(point: Vector2, additive := false) -> void:
	var unit := _unit_at(point)
	var now := Time.get_ticks_msec()
	if unit != null and unit == _last_tap_unit and now - _last_tap_msec <= DOUBLE_TAP_MSEC and not _picking_guard:
		_last_tap_unit = null
		_select_same_kind(unit, additive or _multi_mode)
		return
	_last_tap_unit = unit
	_last_tap_msec = now
	if unit != null:
		if _picking_guard and is_instance_valid(_selected):
			var guards := 0
			for other in _selection:
				if other != unit:
					other.guard(unit)
					guards += 1
			_picking_guard = false
			if guards == 1:
				_hud.toast(tr("%s schützt %s") % [_selected.display_name, unit.display_name])
			elif guards > 1:
				_hud.toast(tr("%d Einheiten schützen %s") % [guards, unit.display_name])
		elif additive or _multi_mode:
			_toggle_selected(unit)
		elif unit in _selection:
			if _selection.size() == 1:
				unit.clear_order()
				_select(null)
			else:
				_select(unit)
		else:
			_select(unit)
	elif not _selection.is_empty() and World.contains(point):
		_order_group(point)
		_picking_guard = false


## Auswahlrahmen: Ziehen auf freiem Boden. Ohne Ziehen ist es ein normaler Tipp.
func _handle_box_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if not _box_active and _unit_at(_box_start) == null and _pointer.distance_to(_box_start) > BOX_MIN_DRAG:
			_box_active = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var additive: bool = event.shift_pressed or event.ctrl_pressed
		var was_box := _box_active
		_box_pending = false
		_box_active = false
		queue_redraw()
		if Game.phase != Game.Phase.BATTLE:
			return
		if was_box:
			_select_in_rect(Rect2(_box_start, _pointer - _box_start).abs(), additive or _multi_mode)
		else:
			_command(_box_start, additive)


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


## Alle eigenen Einheiten wählen (Knopf "Alle").
func select_all() -> void:
	if Game.phase != Game.Phase.BATTLE:
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
		if fired == 0:
			_hud.toast(tr("Keine Fähigkeit bereit oder einsetzbar"))
			Sound.play(&"error")
			return false
		_hud.toast(tr("%d von %d Fähigkeiten ausgelöst") % [fired, tried])
		return true
	if not is_instance_valid(_selected):
		return false
	var unit := _selected
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
			if get_player_units().size() <= _selection.size():
				_hud.toast(tr("Zum Schützen braucht es eine weitere Einheit"))
				Sound.play(&"error")
				_clear_orders()
				return
			_picking_guard = true
			_hud.toast(tr("Tippe die Einheit, die geschützt werden soll"))
		_:
			_clear_orders()


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
	for unit in units:
		unit.home_position = unit.position
		unit.clear_order()
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
		enemy.died.connect(_on_died)
		add_child(enemy)
		enemy_spawned.emit(enemy, arm)


func _on_died(combatant: Combatant) -> void:
	if combatant.team == Combatant.Team.ENEMY:
		Game.add_gold(combatant.gold_reward)
		Achievements.report(&"kill")
		if combatant.is_boss:
			_boss_dead = true
			Achievements.report(&"boss")
			_hud.toast(tr("%s besiegt! +%d Gold") % [combatant.display_name, combatant.gold_reward])
			Sound.play(&"round_win", 0.0)
	elif Game.phase == Game.Phase.BATTLE:
		_losses += 1
		_fallen.append({"data": combatant.unit_data, "position": combatant.position, "home": combatant.home_position})
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
	unit.health = unit.max_health * 0.5
	Achievements.report(&"revive")
	return true


func _clear_enemies() -> void:
	for node in get_tree().get_nodes_in_group(Combatant.GROUP_ENEMY):
		(node as Combatant).discard()


func _end_round() -> void:
	var kind := Game.round_kind()
	var message := tr("Runde überstanden!")
	if kind == Game.RoundKind.BONUS:
		var prize := Game.bonus_prize()
		Game.add_gold(prize)
		Achievements.report(&"bonus")
		message = tr("Bonusrunde geschafft! +%d Gold Prämie") % prize
	elif kind == Game.RoundKind.BOSS:
		message = tr("Bossrunde geschafft!")
	if _losses == 0:
		Achievements.report(&"perfect")
		message += tr(" Makellos!")
	_clear_enemies()
	_select(null)
	_boss = null
	_hud.set_boss(null)
	for unit in get_player_units():
		unit.reset_after_battle()
		unit.position = unit.home_position
	Game.next_round()
	Achievements.report_max(&"round", Game.round_number)
	_hud.toast(message)
	Sound.play(&"round_win", 0.0)


func _game_over() -> void:
	Game.set_phase(Game.Phase.GAME_OVER)
	_clear_enemies()
	_select(null)
	_hud.show_game_over(Game.round_number)
