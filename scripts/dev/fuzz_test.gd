extends Node
## Entwickler-Test: Zufallseingaben. Maus, Touch und Tasten (echte Ereignisse) plus Kaufen, Verbinden und
## Kampfstart über mehrere Runden, danach wird geprüft, dass die Arena in sich stimmig bleibt. Findet
## Abstürze (SCRIPT ERROR) und verwaiste Auswahlen. Mit festem Startwert, damit ein Fehler wiederholbar ist:
## godot --headless res://scenes/dev/fuzz_test.tscn [-- --seed=7 --steps=1500]

const FIELD := Rect2(0, 30, 640, 290)  # ohne obere und untere Leiste (Menü, Hauptmenü)
## Tasten ohne Esc (öffnet das Menü mit "Hauptmenü") und F11 (Vollbild).
const KEYS: Array[Key] = [KEY_ENTER, KEY_SPACE, KEY_P, KEY_D, KEY_R, KEY_V, KEY_DELETE, KEY_H, KEY_S, KEY_G, KEY_Q,
		KEY_TAB, KEY_1, KEY_2, KEY_3, KEY_A, KEY_PLUS, KEY_MINUS]

var _arena: Node2D
var _failed := false
var _steps := 1500


func _ready() -> void:
	var run_seed := 7
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			run_seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--steps="):
			_steps = int(arg.get_slice("=", 1))
	seed(run_seed)
	Engine.time_scale = 4.0
	get_tree().create_timer(400.0, true, false, true).timeout.connect(func() -> void:
		print("FUZZ-TEST ZEITÜBERSCHREITUNG")
		get_tree().quit(1))
	await _new_arena()
	for step in _steps:
		if Game.phase == Game.Phase.GAME_OVER:
			await _new_arena()
		if step % 60 == 59:  # Pause aufheben und kämpfen lassen, sonst bleibt der Lauf in der ersten Bauphase hängen
			(_arena.get("_hud") as Hud).set_paused(false)
			if Game.phase == Game.Phase.BUILD and _arena.get_player_units().size() <= Game.MAX_UNITS:
				_arena.start_battle()
		await _random_action()
		_check_state(step)
		if _failed:
			break
	get_tree().paused = false
	Engine.time_scale = 1.0
	print("FUZZ-TEST (Startwert %d, %d Schritte, bis Runde %d) %s" % [run_seed, _steps, Game.round_number, "FEHLER" if _failed else "OK"])
	get_tree().quit(1 if _failed else 0)


## Frische Arena (nach einer Niederlage). Neustart und Hauptmenü wechseln die Szene und würden den Test
## mitnehmen, ihre Knöpfe bleiben deshalb ohne Wirkung.
func _new_arena() -> void:
	if is_instance_valid(_arena):
		remove_child(_arena)
		_arena.free()  # sofort, sonst hört die alte Arena noch auf die Signale von Game
	get_tree().paused = false
	_arena = load("res://scenes/main.tscn").instantiate()
	_arena.events_enabled = false  # sonst fangen Ereignisfenster die Eingaben ab (eigener Test)
	add_child(_arena)
	await get_tree().process_frame
	var hud: Hud = _arena.get("_hud")
	for signal_name in ["restart_pressed", "menu_pressed"]:
		for connection in hud.get_signal_connection_list(signal_name):
			hud.disconnect(signal_name, connection["callable"])
	Game.gold = 400


func _point() -> Vector2:
	return Vector2(randf_range(FIELD.position.x, FIELD.end.x), randf_range(FIELD.position.y, FIELD.end.y))


## Mit Vorliebe auf eine Einheit zielen, sonst schlägt fast jeder Klick ins Leere.
func _target_point() -> Vector2:
	var nodes := get_tree().get_nodes_in_group(Combatant.GROUP_PLAYER) + get_tree().get_nodes_in_group(Combatant.GROUP_ENEMY)
	if not nodes.is_empty() and randf() < 0.6:
		return (nodes.pick_random() as Combatant).center()
	return _point()


func _random_action() -> void:
	var roll := randf()
	if roll < 0.22:
		await _click(_target_point(), MOUSE_BUTTON_LEFT)
	elif roll < 0.34:
		await _drag(_target_point(), _target_point())
	elif roll < 0.44:
		await _click(_target_point(), MOUSE_BUTTON_RIGHT)
	elif roll < 0.56:
		await _touch_tap(_target_point(), randf() < 0.25)
	elif roll < 0.70:
		var key: Key = KEYS.pick_random()
		# Strg nur mit Gruppen und "alles wählen": Strg+V würde ein Eingabefeld einfügen (Zwischenablage fehlt ohne Fenster)
		await _key(key, key in [KEY_1, KEY_2, KEY_3, KEY_A] and randf() < 0.4)
	elif roll < 0.82:
		_play()
		await get_tree().process_frame
	else:
		for i in randi_range(1, 30):
			await get_tree().physics_frame


## Wie ein Spieler: Gold nachlegen, kaufen, verbinden, den Kampf starten.
func _play() -> void:
	if Game.gold < 100:
		Game.gold += 300
	match randi() % 4:
		0, 1:
			var shop := Registry.shop_units().filter(func(u: UnitData) -> bool: return Registry.buy_block_reason(u) == "")
			_arena.buy_unit(shop.pick_random())
		2:
			var units: Array[Combatant] = _arena.get_player_units()
			if units.size() >= 2:
				_arena.try_merge(units.pick_random(), units.pick_random())
		3:
			(_arena.get("_hud") as Hud).set_paused(false)
			if _arena.get_player_units().size() <= Game.MAX_UNITS:
				_arena.start_battle()


func _check(ok: bool, text: String) -> void:
	if not ok:
		print("FAIL: " + text)
		_failed = true


## Zustand, der nach jeder Eingabe stimmen muss.
func _check_state(step: int) -> void:
	var tag := " (Schritt %d)" % step
	# Gefallene Einheiten räumt _process der Arena im nächsten Bild aus der Auswahl: nur gültige prüfen.
	for entry in _arena._selection:
		_check(not is_instance_valid(entry) or entry._alive or Game.phase != Game.Phase.BUILD, "Auswahl enthält eine tote Einheit" + tag)
	_check(Game.gold >= 0, "Gold nie negativ (%d)" % Game.gold + tag)
	_check(_arena.get_player_units().size() <= Game.BUILD_MAX_UNITS, "Höchstens %d Einheiten" % Game.BUILD_MAX_UNITS + tag)
	if Game.phase == Game.Phase.BATTLE:
		_check(_arena.get_player_units().size() <= Game.MAX_UNITS, "Im Kampf höchstens %d Einheiten" % Game.MAX_UNITS + tag)
	for unit: Combatant in _arena.get_player_units():
		_check(is_finite(unit.position.x) and is_finite(unit.position.y), "Einheit hat eine gültige Position" + tag)


# --- Ereignisse ------------------------------------------------------------------

func _mouse(pos: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = pos
	event.global_position = pos
	event.button_mask = (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	get_viewport().push_input(event, true)


func _motion(pos: Vector2, left_down := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if left_down else 0
	get_viewport().push_input(event, true)


func _click(pos: Vector2, button: MouseButton) -> void:
	_motion(pos)
	await get_tree().process_frame
	_mouse(pos, button, true)
	await get_tree().process_frame
	_mouse(pos, button, false)
	await get_tree().process_frame


func _drag(from: Vector2, to: Vector2) -> void:
	_motion(from)
	await get_tree().process_frame
	_mouse(from, MOUSE_BUTTON_LEFT, true)
	await get_tree().process_frame
	for i in range(1, randi_range(2, 9)):
		_motion(from.lerp(to, i / 8.0), true)
		await get_tree().process_frame
	_mouse(to, MOUSE_BUTTON_LEFT, false)
	await get_tree().process_frame


func _touch(pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = pressed
	event.position = get_viewport().get_screen_transform() * (get_viewport().get_final_transform() * pos)
	Input.parse_input_event(event)


func _touch_tap(pos: Vector2, long_press: bool) -> void:
	_touch(pos, true)
	if long_press:
		for i in 40:
			await get_tree().process_frame
	await get_tree().process_frame
	_touch(pos, false)
	await get_tree().process_frame
	await get_tree().process_frame


func _key(keycode: Key, ctrl: bool) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.ctrl_pressed = ctrl
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame
