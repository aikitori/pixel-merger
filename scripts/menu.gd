class_name Menu
extends Control
## Hauptmenü: Titel, Starten oder Fortsetzen (gespeicherter Lauf, RunSave), Erfolge und Ton.
## Hinter dem Menü wuselt ein kleines Dorf mit Helden.

const GAME_SCENE := "res://scenes/main.tscn"
const BUTTON_STEP := 36.0
const HEROES := ["knight", "mage", "archer", "healer", "wolf", "horse", "dwarf_warrior", "elf_scout"]

var _achievements: AchievementsPanel
var _achievements_button: Button
var _sound_button: Button
var _fullscreen_button: Button
var _language_button: Button
var _quit_button: Button
var _new_game_button: Button
## Neues Spiel über einem gespeicherten Lauf braucht einen zweiten Tipp.
var _new_game_armed_msec := -10000


func _ready() -> void:
	theme = UiTheme.make()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_title()
	_build_buttons()
	_achievements = AchievementsPanel.new()
	add_child(_achievements)
	Sound.set_music(&"build")
	Sound.muted_changed.connect(func(_muted: bool) -> void: _refresh())
	_refresh()


## Zurück-Taste (Android): erst die Erfolgsliste schließen, dann die App beenden.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _achievements != null and _achievements.visible:
			_achievements.close_panel()
		else:
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _achievements.visible:
		_achievements.close_panel()
		get_viewport().set_input_as_handled()


func start_game() -> void:
	Game.resume_requested = false
	get_tree().change_scene_to_file(GAME_SCENE)


func continue_game() -> void:
	Game.resume_requested = true
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_new_game() -> void:
	var now := Time.get_ticks_msec()
	if now - _new_game_armed_msec < 2500:
		start_game()
		return
	_new_game_armed_msec = now
	_new_game_button.text = tr("Nochmal tippen: Lauf verwerfen")
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if is_instance_valid(_new_game_button):
			_new_game_button.text = tr("Neues Spiel"))


# --- Aufbau -------------------------------------------------------------------

func _build_background() -> void:
	var ground := TextureRect.new()
	ground.texture = World.TERRAIN
	ground.size = Vector2(640, 360)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.12, 0.4)
	dim.size = Vector2(640, 360)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# Helden laufen durch den Gang
	for i in HEROES.size():
		var data: UnitData = Registry.units.get(StringName(HEROES[i]))
		if data == null:
			continue
		var figure := TextureRect.new()
		figure.texture = Combatant.frames_texture(data.sprite, true)
		figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lane_y := 224.0 + (i % 3) * 8.0  # unten im waagrechten Gang der Arena
		figure.position = Vector2(-40.0 + i * 85.0, lane_y - data.sprite.get_height())
		add_child(figure)
		_animate_walker(figure, i)


func _animate_walker(figure: TextureRect, index: int) -> void:
	var speed := randf_range(26.0, 48.0)
	var walk := create_tween().set_loops()
	walk.tween_property(figure, "position:x", 680.0, (680.0 - figure.position.x) / speed)
	walk.tween_callback(func() -> void: figure.position.x = -48.0)
	walk.tween_property(figure, "position:x", 680.0, 728.0 / speed)


func _build_title() -> void:
	var logo := ArtStyle.logo()
	if logo:
		var image := TextureRect.new()
		image.texture = logo
		image.position = Vector2(roundi((640 - logo.get_width()) / 2.0), 18)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(image)
	var title := Label.new()
	title.visible = logo == null
	title.text = tr("Pixel Merger")
	title.position = Vector2(0, 18)
	title.size = Vector2(640, 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", UiTheme.GOLD_LIGHT)
	title.add_theme_color_override("font_shadow_color", Color("#24123a"))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	var subtitle := Label.new()
	subtitle.text = tr("Verbinde. Kämpfe. Werde zur Legende.")
	subtitle.position = Vector2(0, 72)
	subtitle.size = Vector2(640, 20)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(subtitle)


func _build_buttons() -> void:
	var next_y := 100.0
	var saved := RunSave.read()
	if saved.is_empty():
		_menu_button("Starten", next_y).pressed.connect(start_game)
	else:
		var resume := _menu_button("", next_y)
		resume.text = tr("Fortsetzen (Runde %d)") % int(saved["round"])
		resume.pressed.connect(continue_game)
		next_y += BUTTON_STEP
		_new_game_button = _menu_button("Neues Spiel", next_y)
		_new_game_button.pressed.connect(_on_new_game)
	next_y += BUTTON_STEP
	_achievements_button = _menu_button("Erfolge", next_y)
	_achievements_button.pressed.connect(func() -> void: _achievements.open_panel())
	next_y += BUTTON_STEP
	_language_button = _menu_button("", next_y)
	_language_button.pressed.connect(func() -> void:
		Loc.set_language(Loc.next_language())
		get_tree().reload_current_scene())
	next_y += BUTTON_STEP
	_sound_button = _menu_button("Ton an", next_y)
	_sound_button.pressed.connect(func() -> void: Sound.muted = not Sound.muted)
	next_y += BUTTON_STEP
	if Fullscreen.available():
		_fullscreen_button = _menu_button("Vollbild", next_y)
		_fullscreen_button.pressed.connect(func() -> void:
			Fullscreen.toggle()
			# Der Browser meldet den neuen Modus erst einen Moment später
			for delay in [0.2, 0.7, 1.5]:
				await get_tree().create_timer(delay, true, false, true).timeout
				_refresh())
		get_viewport().size_changed.connect(_refresh)
		next_y += BUTTON_STEP
	_quit_button = _menu_button("Beenden", next_y)
	_quit_button.pressed.connect(func() -> void: get_tree().quit())
	_quit_button.visible = not OS.has_feature("web")  # im Browser gibt es nichts zu beenden
	var version := Label.new()
	version.text = tr("Version %s") % ProjectSettings.get_setting("application/config/version", "?")
	version.position = Vector2(8, 340)
	version.size = Vector2(200, 16)
	version.add_theme_font_size_override("font_size", 10)
	version.modulate.a = 0.8
	version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(version)
	if Progress.best_round > 0:
		var record := Label.new()
		record.text = tr("Rekord: Runde %d") % Progress.best_round
		record.position = Vector2(432, 340)
		record.size = Vector2(200, 16)
		record.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		record.add_theme_font_size_override("font_size", 10)
		record.modulate.a = 0.8
		record.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(record)


func _menu_button(text: String, y: float) -> Button:
	var button := Button.new()
	button.text = tr(text)
	button.position = Vector2(220, y)
	button.size = Vector2(200, 34)
	button.add_theme_font_size_override("font_size", 15)
	add_child(button)
	return button


func _refresh() -> void:
	_achievements_button.text = tr("Erfolge  %d / %d") % [Achievements.unlocked_count(), Achievements.LIST.size()]
	_sound_button.text = tr("Ton aus") if Sound.muted else tr("Ton an")
	if _fullscreen_button != null:
		_fullscreen_button.text = Fullscreen.label()
	# Die Sprache steht immer in ihrer eigenen Sprache, damit man sie auch im Fremdtext findet.
	_language_button.text = "Sprache: Deutsch" if Loc.language == "de" else "Language: English"
