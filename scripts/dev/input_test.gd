extends Node
## Entwickler-Test: speist echte Eingabeereignisse ein (Maus und Touch) und prüft Dorf und Häuser,
## Platzieren und Verbinden auf der ganzen Fläche sowie Positionsbefehle im Kampf.
## Start: godot --headless res://scenes/dev/input_test.tscn

var _arena: Node2D
var _failed := false


func _ready() -> void:
	# Zeitwächter: bricht ab, falls ein Ablauf nie zum Ergebnis führt.
	get_tree().create_timer(60.0, true, false, true).timeout.connect(func() -> void:
		print("INPUT-TEST ZEITÜBERSCHREITUNG")
		get_tree().quit(1))
	_arena = load("res://scenes/main.tscn").instantiate()
	add_child(_arena)
	await get_tree().process_frame
	await _test_shop()
	await _test_merge_preview_and_book()
	await _test_merge_on_whole_field()
	await _test_merge_without_gold()
	await _test_place_next_to_other()
	await _test_back_button()
	await _test_battle_order()
	await _test_multi_select()
	await _test_manual_ability()
	await _test_selected_unit_dies()
	await _test_battle_speed()
	await _test_touch_drag()
	await _test_world_shape()
	await _test_battle_stays_in_cross()
	await _test_merge_after_battle()
	await _test_real_round_then_village()
	print("INPUT-TEST ", "FEHLGESCHLAGEN" if _failed else "OK")
	get_tree().quit(1 if _failed else 0)


func _check(ok: bool, text: String) -> void:
	print(("ok:   " if ok else "FAIL: ") + text)
	if not ok:
		_failed = true


func _peasant() -> UnitData:
	return Registry.units[&"peasant"]


func _event_button(pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = pos
	event.global_position = pos
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	get_viewport().push_input(event, true)


func _event_motion(pos: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(event, true)


## Zieht mit mehreren Zwischenschritten wie ein Finger oder eine Maus.
func _drag(from: Vector2, to: Vector2) -> void:
	_event_motion(from)
	await get_tree().process_frame
	_event_button(from, true)
	await get_tree().process_frame
	for i in range(1, 9):
		_event_motion(from.lerp(to, i / 8.0))
		await get_tree().process_frame
	_event_button(to, false)
	await get_tree().process_frame


func _tap(pos: Vector2) -> void:
	_event_motion(pos)
	await get_tree().process_frame
	_event_button(pos, true)
	await get_tree().process_frame
	_event_button(pos, false)
	await get_tree().process_frame


func _units() -> Array[Combatant]:
	return _arena.get_player_units()


func _count(id: StringName) -> int:
	return _units().filter(func(u: Combatant) -> bool: return u.unit_data.id == id).size()


func _test_shop() -> void:
	var hud: Hud = _arena.get("_hud")
	var village: Village = hud._village
	var shop: Shop = hud._shop
	_check(not village.visible and not shop.visible, "Dorf und Kaufliste sind anfangs zu")
	hud._shop_button.pressed.emit()
	_check(village.visible and hud._shop_button.text == "Arena", "Knopf 'Dorf' öffnet das Dorf, der Knopf heißt dann 'Arena'")
	_check(village.blocked_rect().has_point(Vector2(320, 150)), "Das Dorf verdeckt die Arena")
	var buttons: Array = village._buttons
	_check(buttons.size() == Village.HOUSES.size(), "Das Dorf hat %d Häuser" % buttons.size())
	var total := 0
	for i in buttons.size():
		(buttons[i] as Button).pressed.emit()
		var listed: int = shop._price_buttons.size()
		var expected := Registry.shop_units().filter(func(u: UnitData) -> bool: return u.category == Village.HOUSES[i]["category"]).size()
		_check(shop.visible and listed == expected and listed > 0, "Haus %s listet %d Einheiten seiner Kategorie" % [Village.HOUSES[i]["name"], listed])
		total += listed
	_check(total == Registry.shop_units().size(), "Alle %d Grundeinheiten sind auf die Häuser verteilt" % total)
	(buttons[0] as Button).pressed.emit()
	var gold := Game.gold
	(shop._price_buttons.keys()[0] as Button).pressed.emit()
	_check(_units().size() == 1 and Game.gold == gold - 5, "Kauf im Haus: Einheit erscheint in der Arena, 5 Gold abgezogen")
	hud._shop_button.pressed.emit()
	_check(not village.visible and not shop.visible, "Knopf 'Arena' schließt Dorf und Kaufliste")


func _test_merge_preview_and_book() -> void:
	var hud: Hud = _arena.get("_hud")
	var existing := _units()
	var gold_before := Game.gold
	_arena.buy_unit(_peasant())
	_arena.buy_unit(_peasant())
	var units := _units().filter(func(u: Combatant) -> bool: return not existing.has(u))
	for other in existing:  # Zufällig verteilte Startfiguren aus dem Weg, sonst gibt es eine zufällige Vorschau
		other.position = Vector2(60, 200)
	units[0].position = Vector2(300, 140)
	units[1].position = Vector2(380, 140)
	var from: Vector2 = units[0].center()
	var to: Vector2 = units[1].center()
	_event_motion(from)
	await get_tree().process_frame
	_event_button(from, true)
	await get_tree().process_frame
	_check(not hud._merge_panel.visible, "Vorschau ist beim Anfassen noch zu")
	_check(hud._hint_panel.visible and hud._hint_rows[0]["row"].visible, "Beim Anfassen erscheinen mögliche Rezepte")
	_check(hud._card.visible and hud._card_title.text.begins_with("Bauer"), "Beim Anfassen zeigt die Karte Porträt und Werte (%s)" % hud._card_title.text)
	_event_motion(to)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not hud._card.visible, "Beim Merge-Vorschau ist die Einheitenkarte ausgeblendet")
	_check(hud._merge_panel.visible, "Beim Ziehen auf eine passende Einheit erscheint die Merge-Vorschau")
	_check(hud._merge_cards[2]["title"].text == "Knappe", "Vorschau zeigt das Ergebnis (%s)" % hud._merge_cards[2]["title"].text)
	_check(hud._merge_cards[0]["stats"].text != "", "Vorschau zeigt Werte der Zutat")
	_event_button(to, false)
	await get_tree().process_frame
	_check(not hud._merge_panel.visible, "Vorschau verschwindet nach dem Loslassen")
	_check(not hud._hint_panel.visible, "Rezeptliste verschwindet nach dem Loslassen")
	_check(not hud._start_button.disabled, "Start-Knopf ist ohne Buch aktiv")
	hud._book.open_book()
	await get_tree().process_frame
	_check(hud._start_button.disabled, "Start-Knopf ist bei offenem Rezeptbuch gesperrt")
	hud._book.close_book()
	await get_tree().process_frame
	_check(not hud._start_button.disabled, "Start-Knopf ist nach dem Schließen wieder aktiv")
	for unit in _units():
		if not existing.has(unit):
			unit.discard()
	Game.gold = gold_before
	await get_tree().process_frame


func _test_merge_on_whole_field() -> void:
	_arena.buy_unit(_peasant())
	_arena.buy_unit(_peasant())
	var units := _units()
	# Rechte Hälfte der Fläche: früher unerreichbar.
	units[0].position = Vector2(520, 140)
	units[1].position = Vector2(590, 140)
	units[2].position = Vector2(60, 200)
	var before := Game.gold
	await _drag(units[0].center(), units[1].center() + Vector2(14, 9))
	_check(_count(&"squire") == 1 and _units().size() == 2, "Bauer + Bauer ergeben rechts auf der Fläche einen Knappen")
	_check(Game.gold == before - 6, "Merge kostet 6 Gold (Gold: %d -> %d)" % [before, Game.gold])
	var lone: Combatant = _units().filter(func(u: Combatant) -> bool: return u.unit_data.id == &"peasant")[0]
	lone.position = Vector2(60, 200)
	await _drag(lone.center(), Vector2(580, 200))
	_check(lone.position.x > 500, "Figur lässt sich über die ganze Fläche nach rechts ziehen (x = %d)" % lone.position.x)


func _test_merge_without_gold() -> void:
	_arena.buy_unit(_peasant())
	var peasants: Array[Combatant] = _units().filter(func(u: Combatant) -> bool: return u.unit_data.id == &"peasant")
	var a := peasants[0]
	var b := peasants[1]
	a.position = Vector2(100, 150)
	b.position = Vector2(180, 150)
	var count_before := _units().size()
	var saved := Game.gold
	Game.gold = 2
	await _drag(a.center(), b.center())
	_check(_units().size() == count_before, "Mit zu wenig Gold wird nicht verbunden")
	_check(is_instance_valid(a) and a.position.distance_to(Vector2(100, 150)) < 1.0, "Einheit springt an ihre alte Stelle zurück")
	Game.gold = saved


func _test_battle_order() -> void:
	var unit := _units()[0]
	_check(_arena.start_battle(), "Kampf starten")
	await _tap(unit.center())
	await _tap(Vector2(300, 200))
	_check(unit.has_order, "Einheit antippen, dann Ziel antippen gibt einen Positionsbefehl")
	_check(unit.order_position.distance_to(Vector2(300, 200)) < 1.0, "Befehlsziel stimmt")
	await _tap(unit.center())
	_check(not unit.has_order, "Erneutes Antippen hebt den Befehl auf")
	# Befehlsknopf: Frei -> Halten -> Schützen (Schützling antippen) -> Frei
	var other := _units()[1]
	await _tap(unit.center())
	_arena.cycle_order()
	_check(unit.order_mode() == &"hold", "Befehlsknopf: Frei -> Halten")
	_arena.cycle_order()
	_check(_arena._picking_guard, "Befehlsknopf: Halten -> Schützen wartet auf den Schützling")
	await _tap(other.center())
	_check(unit.order_mode() == &"guard" and unit.guard_target == other, "Tipp auf andere Einheit setzt den Schützling")
	_arena.cycle_order()
	_check(unit.order_mode() == &"free", "Befehlsknopf: Schützen -> Frei")
	await _tap(unit.center())


## Echte Touch-Ereignisse: Godot wandelt sie selbst in Mausereignisse um (Android).
func _touch_position(pos: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * (get_viewport().get_final_transform() * pos)


func _touch(pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = pressed
	event.position = _touch_position(pos)
	Input.parse_input_event(event)


func _touch_move(pos: Vector2, previous: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = _touch_position(pos)
	event.relative = _touch_position(pos) - _touch_position(previous)
	Input.parse_input_event(event)


func _test_touch_drag() -> void:
	Game.set_phase(Game.Phase.BUILD)
	var unit := _units()[0]
	unit.position = Vector2(80, 200)
	var from := unit.center()
	var to := Vector2(560, 120)
	_touch(from, true)
	await get_tree().process_frame
	var previous := from
	for i in range(1, 9):
		var step := from.lerp(to, i / 8.0)
		_touch_move(step, previous)
		previous = step
		await get_tree().process_frame
	_touch(to, false)
	await get_tree().process_frame
	_check(unit.position.x > 500, "Touch: Figur lässt sich über die ganze Fläche ziehen (x = %d)" % unit.position.x)


func _test_world_shape() -> void:
	var unit := _units()[0]
	unit.position = Vector2(80, 200)
	# Ziehen in die Ecke außerhalb des Kreuzes: die Figur bleibt auf dem Kreuz.
	await _drag(unit.center(), Vector2(20, 40))
	_check(World.contains(unit.position), "Ziehen in den Abgrund: Figur bleibt im Kreuz (%s)" % unit.position)
	_check(World.contains(Vector2(320, 40)) and World.contains(Vector2(20, 172)), "Arme des Kreuzes sind begehbar")
	_check(not World.contains(Vector2(20, 40)) and not World.contains(Vector2(620, 300)), "Ecken außerhalb des Kreuzes sind Abgrund")


func _test_battle_stays_in_cross() -> void:
	_arena._clear_enemies()
	Game.set_phase(Game.Phase.BUILD)
	var arms := {}
	var spawn_ok := true
	_arena.enemy_spawned.connect(func(enemy: Combatant, arm: World.Arm) -> void:
		arms[arm] = true
		var edge := {
			World.Arm.WEST: enemy.position.x < 10.0, World.Arm.EAST: enemy.position.x > 630.0,
			World.Arm.NORTH: enemy.position.y < 50.0, World.Arm.SOUTH: enemy.position.y > 305.0}
		if not edge[arm]:
			spawn_ok = false)
	# Eine Einheit schickt einen Befehl in den Abgrund: sie bleibt trotzdem im Kreuz.
	var unit := _units()[0]
	unit.position = World.CENTER
	_check(_arena.start_battle(), "Kampf starten (Weltform-Test)")
	unit.give_order(Vector2(5, 30))
	Engine.time_scale = 8.0
	var outside := 0
	var frames := 0
	while frames < 4000 and (arms.size() < 4 or frames < 600):
		await get_tree().physics_frame
		frames += 1
		for node in get_tree().get_nodes_in_group(Combatant.GROUP_PLAYER) + get_tree().get_nodes_in_group(Combatant.GROUP_ENEMY):
			if not World.contains((node as Combatant).position):
				outside += 1
		if Game.phase != Game.Phase.BATTLE:
			break
	Engine.time_scale = 1.0
	_check(arms.size() == 4, "Gegner kommen aus allen 4 Richtungen (%d von 4)" % arms.size())
	_check(spawn_ok, "Gegner erscheinen jeweils am äußeren Ende ihres Arms")
	_check(outside == 0, "Keine Figur verlässt während des Kampfes das Kreuz (%d Verstöße)" % outside)


func _test_place_next_to_other() -> void:
	# Bauer neben einen Knappen stellen: kein Rezept, also einfach abstellen statt zurückspringen.
	var peasant: Combatant = _units().filter(func(u: Combatant) -> bool: return u.unit_data.id == &"peasant")[0]
	var squire: Combatant = _units().filter(func(u: Combatant) -> bool: return u.unit_data.id == &"squire")[0]
	peasant.position = Vector2(100, 200)
	squire.position = Vector2(300, 160)
	var count := _units().size()
	var drop := squire.center() + Vector2(16, 0)
	await _drag(peasant.center(), drop)
	_check(_units().size() == count, "Bauer neben Knappe: nichts wird verbunden")
	_check(peasant.position.distance_to(Vector2(100, 200)) > 100.0, "Bauer bleibt dort stehen, wo er losgelassen wurde")


func _test_back_button() -> void:
	var hud: Hud = _arena.get("_hud")
	hud._shop_button.pressed.emit()
	hud._village.open_category("Klassisch")
	hud._book.open_book()
	_check(hud.handle_back() and not hud._book.visible and hud._shop.visible, "Zurück schließt zuerst das Rezeptbuch")
	_check(hud.handle_back() and not hud._shop.visible and hud._village.visible, "Dann die Kaufliste, das Dorf bleibt")
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not hud._village.visible, "Zurück-Taste (Android) schließt danach das Dorf statt die App")
	_check(not hud.handle_back(), "Ist nichts offen, meldet handle_back() false (dann beendet Android die App)")


func _test_multi_select() -> void:
	_arena._clear_enemies()
	Game.set_phase(Game.Phase.BUILD)
	_arena._select(null)
	var gold_before := Game.gold
	while _units().size() < 5:
		_arena.buy_unit(_peasant())
	var units := _units()
	var cluster: Array[Combatant] = [units[0], units[1], units[2]]
	cluster[0].position = Vector2(280, 150)
	cluster[1].position = Vector2(310, 150)
	cluster[2].position = Vector2(340, 150)
	var outsiders: Array[Combatant] = []
	for i in range(3, units.size()):
		units[i].position = Vector2(60 + 40 * (i - 3), 205)
		outsiders.append(units[i])
	_check(outsiders.size() >= 1, "Mehrfachauswahl-Test: es gibt Einheiten außerhalb des Rahmens")
	Game.set_phase(Game.Phase.BATTLE)
	_arena._spawn_timer = 99999.0
	_arena._battle_time_left = 99999.0
	await get_tree().process_frame
	# Auswahlrahmen auf freiem Boden
	await _drag(Vector2(250, 118), Vector2(370, 188))
	_check(_arena._selection.size() == 3 and cluster.all(func(u: Combatant) -> bool: return u.highlighted),
		"Auswahlrahmen wählt die drei Einheiten im Rahmen (%d)" % _arena._selection.size())
	_check(not outsiders.any(func(u: Combatant) -> bool: return u.highlighted), "Einheiten außerhalb des Rahmens bleiben ungewählt")
	var hud: Hud = _arena.get("_hud")
	await get_tree().process_frame
	_check(hud._ability_button.text.begins_with("Fähigkeiten") or hud._ability_button.disabled, "Fähigkeitsknopf zählt die Gruppe")
	_check(hud._card_title.text.contains("+2"), "Einheitenkarte nennt die weiteren gewählten Einheiten (%s)" % hud._card_title.text)
	# Gruppenbefehl: alle laufen los, Abstände bleiben ungefähr erhalten
	await _tap(Vector2(480, 150))
	_check(cluster.all(func(u: Combatant) -> bool: return u.has_order), "Tipp aufs Feld schickt die ganze Gruppe los")
	_check(cluster[0].order_position.distance_to(cluster[2].order_position) > 20.0, "Die Gruppe behält Abstände im Ziel")
	# Befehlsknopf wirkt auf alle
	for unit in cluster:
		unit.clear_order()
	_arena.cycle_order()
	_check(cluster.all(func(u: Combatant) -> bool: return u.order_mode() == &"hold"), "Befehlsknopf: alle gewählten halten die Position")
	_arena.cycle_order()
	_check(_arena._picking_guard, "Befehlsknopf: Gruppe wartet auf den Schützling")
	await _tap(outsiders[0].center())
	_check(cluster.all(func(u: Combatant) -> bool: return u.order_mode() == &"guard" and u.guard_target == outsiders[0]),
		"Alle gewählten schützen dieselbe Einheit")
	_arena.cycle_order()
	_check(cluster.all(func(u: Combatant) -> bool: return u.order_mode() == &"free"), "Befehlsknopf: Gruppe zurück im Freikampf")
	# Tipp auf eine Einheit der Gruppe wählt nur diese
	await _tap(cluster[1].center())
	_check(_arena._selection.size() == 1 and _arena._selected == cluster[1], "Tipp auf Gruppenmitglied wählt nur diese Einheit")
	# Alle wählen
	hud._group_box.get_child(0).pressed.emit()
	_check(_arena._selection.size() == _units().size(), "Knopf 'Alle' wählt alle Einheiten (%d)" % _arena._selection.size())
	# Mehrfach-Modus: Antippen fügt hinzu und nimmt heraus
	_arena._select(null)
	hud._multi_button.button_pressed = true
	_check(_arena._multi_mode, "Mehrfach-Knopf schaltet den Modus ein")
	await _tap(cluster[0].center())
	await _tap(cluster[2].center())
	_check(_arena._selection.size() == 2, "Mehrfach: zwei angetippte Einheiten sind gewählt (%d)" % _arena._selection.size())
	await _tap(cluster[0].center())
	_check(_arena._selection.size() == 1 and _arena._selected == cluster[2], "Mehrfach: erneutes Antippen nimmt die Einheit heraus")
	hud._multi_button.button_pressed = false
	_check(not _arena._multi_mode, "Mehrfach-Knopf schaltet den Modus aus")
	# Doppeltipp wählt alle gleichen Einheiten
	_arena._select(null)
	_arena._spawn_player(cluster[0].unit_data, Vector2(560, 205))
	var same := _units().filter(func(u: Combatant) -> bool: return u.unit_data == cluster[0].unit_data)
	var other_kind := _units().filter(func(u: Combatant) -> bool: return u.unit_data != cluster[0].unit_data)
	_arena._last_tap_unit = null
	await _tap(cluster[0].center())
	_check(_arena._selection.size() == 1, "Einzeltipp wählt nur eine Einheit")
	await _tap(cluster[0].center())  # zweiter Tipp kurz danach
	_check(_arena._selection.size() == same.size() and _arena._selected == cluster[0], "Doppeltipp wählt alle %d gleichen Einheiten (%d)" % [same.size(), _arena._selection.size()])
	_check(not other_kind.any(func(u: Combatant) -> bool: return _arena._selection.has(u)), "Doppeltipp lässt andere Sorten aus")
	_arena._select(cluster[2])
	_arena._last_tap_unit = null
	# Umschalt-Klick (Maus) fügt hinzu
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.shift_pressed = true
	press.position = cluster[1].center()
	press.global_position = press.position
	press.pressed = true
	get_viewport().push_input(press, true)
	await get_tree().process_frame
	press = press.duplicate()
	press.pressed = false
	get_viewport().push_input(press, true)
	await get_tree().process_frame
	_check(_arena._selection.size() == 2, "Umschalt-Klick fügt eine Einheit zur Auswahl hinzu (%d)" % _arena._selection.size())
	# Gefallene Einheit verschwindet aus der Auswahl
	var victim: Combatant = _arena._selection[1]
	victim.take_damage(999999.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_arena._selection.size() == 1, "Gefallene Einheit verlässt die Auswahl")
	_arena._select(null)
	Game.gold = gold_before  # der Kampf läuft für die folgenden Tests weiter
	_arena._fallen.clear()


func _test_manual_ability() -> void:
	var hud: Hud = _arena.get("_hud")
	Game.auto_abilities = false
	var unit := _units()[0]
	unit.ability = &"shield"  # Schild hoch: braucht einen Gegner in der Nähe
	unit.ability_casts = 0
	unit._ability_cd = 0.0
	await _tap(unit.center())
	_check(_arena.get("_selected") == unit, "Einheit für Fähigkeit gewählt")
	_check(hud._ability_button.visible and not hud._start_button.visible, "Im Kampf: Fähigkeitsknopf statt Start-Knopf")
	await get_tree().process_frame
	_check(not hud._ability_button.disabled and hud._ability_button.text == "Schild hoch!", "Knopf zeigt bereite Fähigkeit (%s)" % hud._ability_button.text)
	_check(not _arena.cast_selected(), "Ohne Gegner in der Nähe lässt sich Schild hoch nicht auslösen")
	var foe := Combatant.new()
	foe.setup_enemy(Registry.pick_enemy(1))
	foe.position = unit.position + Vector2(20, 0)
	foe.attack = 0.0
	foe.move_speed = 0.0
	_arena.add_child(foe)
	await get_tree().physics_frame
	await get_tree().physics_frame
	hud._ability_button.pressed.emit()
	_check(unit.ability_casts == 1 and unit.has_effect(&"shield"), "Knopf löst die Fähigkeit aus (Auto aus)")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(hud._ability_button.disabled and hud._ability_button.text.begins_with("Schild hoch ") , "Danach lädt sie (%s)" % hud._ability_button.text)
	_check(not _arena.cast_selected() and unit.ability_casts == 1, "Beim Laden löst der Knopf nichts aus")
	foe.discard()
	Game.auto_abilities = true
	await _tap(unit.center())  # Auswahl wieder aufheben


func _test_selected_unit_dies() -> void:
	var units := _units()
	var victim := units[units.size() - 1]
	var victim_data := victim.unit_data
	await _tap(victim.center())
	_check(_arena.get("_selected") == victim, "Einheit im Kampf ausgewählt")
	victim.take_damage(100000.0)
	for i in 3:
		await get_tree().process_frame
	_check(_arena.get("_selected") == null, "Ausgewählte Einheit stirbt: Auswahl wird sauber gelöscht")
	# Wiederbeleben (Fähigkeit): die gefallene Einheit kommt mit halben Lebenspunkten zurück.
	_check(_arena._fallen.size() == 1, "Gefallene Einheit wird für Wiederbeleben gemerkt")
	var count := _units().size()
	_check(_arena.revive_fallen(_units()[0]) and _units().size() == count + 1, "Wiederbeleben stellt die Einheit auf")
	var revived := _units().filter(func(u: Combatant) -> bool: return u.unit_data == victim_data).back() as Combatant
	_check(is_equal_approx(revived.health, revived.max_health * 0.5), "Wiederbelebte Einheit hat halbe Lebenspunkte")
	_check(not _arena.revive_fallen(_units()[0]), "Ohne Gefallene gibt es nichts wiederzubeleben")


func _test_battle_speed() -> void:
	_check(Game.battle_speed == 1.0, "Kampftempo startet bei 1x")
	var hud: Hud = _arena.get("_hud")
	_check(hud._speed_button.visible and not hud._shop_button.visible, "Im Kampf: Tempo-Knopf statt Dorf-Knopf")
	hud._speed_button.pressed.emit()
	_check(Game.battle_speed == 2.0 and hud._speed_button.text == "Tempo 2x", "Tempo-Knopf schaltet auf 2x")
	var left: float = _arena.get("_battle_time_left")
	var frames := 10
	for i in frames:
		await get_tree().physics_frame
	var used: float = left - _arena.get("_battle_time_left")
	# Bei 1x wären es etwa 10/60 = 0,17 s, bei 2x etwa 0,33 s.
	_check(used > 0.25, "Bei 2x läuft die Kampfzeit doppelt so schnell (%.2f s in %d Frames)" % [used, frames])
	Game.battle_speed = 1.0


## Nach einem echten Rundenende (Zeit abgelaufen) lassen sich die Veteranen wieder ziehen und verbinden.
func _test_merge_after_battle() -> void:
	var hud: Hud = _arena.get("_hud")
	hud._game_over.visible = false
	for unit in _units():
		unit.discard()
	await get_tree().process_frame
	Game.set_phase(Game.Phase.BUILD)
	Game.gold = 500
	_arena.buy_unit(_peasant())
	_arena.buy_unit(_peasant())
	var units := _units()
	units[0].position = Vector2(280, 172)
	units[1].position = Vector2(360, 172)
	_check(_arena.start_battle(), "Kampf starten (Rundenende-Test)")
	for i in 20:
		await get_tree().physics_frame
	_arena.set("_battle_time_left", 0.001)
	for i in 5:
		await get_tree().physics_frame
	_check(Game.phase == Game.Phase.BUILD, "Runde endet regulär, Bauphase beginnt")
	units = _units()
	var a := units[0]
	var b := units[1]
	await _drag(a.center(), b.center())
	_check(_count(&"squire") == 1, "Nach dem Kampf: zwei Bauern lassen sich zum Knappen verbinden")
	_arena.buy_unit(_peasant())
	var fresh := _units().filter(func(u: Combatant) -> bool: return u.unit_data.id == &"peasant")[0] as Combatant
	var before := fresh.position
	await _drag(fresh.center(), Vector2(200, 172))
	_check(fresh.position.distance_to(before) > 20.0, "Nach dem Kampf: Einheit lässt sich verschieben")


func _touch_drag(from: Vector2, to: Vector2) -> void:
	_touch(from, true)
	await get_tree().process_frame
	var previous := from
	for i in range(1, 9):
		var step := from.lerp(to, i / 8.0)
		_touch_move(step, previous)
		previous = step
		await get_tree().process_frame
	_touch(to, false)
	await get_tree().process_frame


## Wie im echten Spiel: voller Kampf mit Gegnern, danach im Dorf kaufen, zurück in die Arena
## und alte wie neue Einheiten per Touch verschieben und verbinden.
func _test_real_round_then_village() -> void:
	var hud: Hud = _arena.get("_hud")
	for unit in _units():
		unit.discard()
	await get_tree().process_frame
	Game.gold = 500
	_arena.buy_unit(Registry.units[&"knight"])
	_arena.buy_unit(Registry.units[&"knight"])
	_arena.buy_unit(Registry.units[&"archer"])
	var veterans := _units()
	veterans[0].position = World.CENTER + Vector2(-30, 0)
	veterans[1].position = World.CENTER + Vector2(30, 0)
	veterans[2].position = World.CENTER + Vector2(0, 30)
	hud._speed_button.visible = true
	_check(_arena.start_battle(), "Kampf starten (Dorf-nach-Kampf-Test)")
	await _tap(veterans[0].center())
	await _tap(World.CENTER + Vector2(-50, 0))
	Engine.time_scale = 8.0
	var frames := 0
	while Game.phase == Game.Phase.BATTLE and frames < 6000:
		await get_tree().physics_frame
		frames += 1
	Engine.time_scale = 1.0
	_check(Game.phase == Game.Phase.BUILD, "Voller Kampf endet in der Bauphase (Phase %d)" % Game.phase)
	veterans = _units()
	if veterans.size() < 2:
		_check(false, "Zu wenige Überlebende für den Test (%d)" % veterans.size())
		return
	hud._shop_button.pressed.emit()
	hud._village._buttons[0].pressed.emit()
	(hud._shop._price_buttons.keys()[0] as Button).pressed.emit()
	hud._shop_button.pressed.emit()
	await get_tree().process_frame
	_check(not hud._village.visible, "Zurück in der Arena")
	var old := veterans[0]
	_check(is_equal_approx(absf(old._flip), 1.0) and old._walk_phase == 0.0 and old._swing_left == 0.0,
		"Nach dem Kampf sind Drehung, Laufwippen und Schwertschwung zurückgesetzt")
	# Antippen am Kopf (oberer Sprite-Rand) trifft ebenfalls.
	for other in _units():  # Zufällig verteilte Nachbarn könnten die Kopfstelle verdecken
		if other != old:
			other.position = Vector2(60, 200) if old.position.x > 320 else Vector2(580, 200)
	var head := old.position + Vector2(0, -old.sprite.get_height() + 2)
	_check(_arena._unit_at(head) == old, "Antippen am Kopf trifft die Figur")
	var before := old.position
	await _touch_drag(old.center(), old.center() + Vector2(0, 40))
	_check(old.position.distance_to(before) > 20.0, "Touch: Veteran lässt sich nach Kampf und Dorf verschieben (%s -> %s)" % [before, old.position])
	var newest := _units()[_units().size() - 1]
	before = newest.position
	await _touch_drag(newest.center(), newest.center() + Vector2(40, 0))
	_check(newest.position.distance_to(before) > 20.0, "Touch: neu gekaufte Einheit lässt sich verschieben")

