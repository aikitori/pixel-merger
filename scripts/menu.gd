class_name Menu
extends Control
## Hauptmenü: Titel, Starten, Erfolge und Ton. Hinter dem Menü wuselt ein kleines Dorf mit Helden.

const GAME_SCENE := "res://scenes/main.tscn"
const HEROES := ["knight", "mage", "archer", "healer", "wolf", "horse", "dwarf_warrior", "elf_scout"]

var _achievements: AchievementsPanel
var _achievements_button: Button
var _sound_button: Button
var _language_button: Button
var _quit_button: Button


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
	get_tree().change_scene_to_file(GAME_SCENE)


# --- Aufbau -------------------------------------------------------------------

func _build_background() -> void:
	var sky := Gradient.new()
	sky.set_color(0, Color("#171446"))
	sky.set_color(1, Color("#d1699a"))
	var sky_texture := GradientTexture2D.new()
	sky_texture.gradient = sky
	sky_texture.fill_from = Vector2(0, 0)
	sky_texture.fill_to = Vector2(0, 1)
	sky_texture.height = 64
	sky_texture.width = 4
	var sky_rect := TextureRect.new()
	sky_rect.texture = sky_texture
	sky_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky_rect.stretch_mode = TextureRect.STRETCH_SCALE
	sky_rect.size = Vector2(640, 360)
	sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky_rect)

	var village := TextureRect.new()
	village.texture = ImageTexture.create_from_image(Village.build_art())
	village.position = Vector2(0, 64)
	village.size = Vector2(640, 296)
	village.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	village.stretch_mode = TextureRect.STRETCH_SCALE
	village.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(village)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.12, 0.4)
	dim.size = Vector2(640, 360)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# Helden laufen unten durchs Bild und hüpfen dabei
	for i in HEROES.size():
		var data: UnitData = Registry.units.get(StringName(HEROES[i]))
		if data == null:
			continue
		var figure := TextureRect.new()
		figure.texture = data.sprite
		figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lane_y := 318.0 + (i % 3) * 8.0
		figure.position = Vector2(-40.0 + i * 85.0, lane_y - data.sprite.get_height())
		add_child(figure)
		_animate_walker(figure, i)


func _animate_walker(figure: TextureRect, index: int) -> void:
	var speed := randf_range(26.0, 48.0)
	var walk := create_tween().set_loops()
	walk.tween_property(figure, "position:x", 680.0, (680.0 - figure.position.x) / speed)
	walk.tween_callback(func() -> void: figure.position.x = -48.0)
	walk.tween_property(figure, "position:x", 680.0, 728.0 / speed)
	var hop := create_tween().set_loops()
	hop.tween_interval(randf() * 0.4)
	hop.tween_property(figure, "position:y", figure.position.y - 3.0, 0.22)
	hop.tween_property(figure, "position:y", figure.position.y, 0.22)


func _build_title() -> void:
	var title := Label.new()
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
	var start := _menu_button("Starten", 100)
	start.pressed.connect(start_game)
	_achievements_button = _menu_button("Erfolge", 140)
	_achievements_button.pressed.connect(func() -> void: _achievements.open_panel())
	_language_button = _menu_button("", 180)
	_language_button.pressed.connect(func() -> void:
		Loc.set_language(Loc.next_language())
		get_tree().reload_current_scene())
	_sound_button = _menu_button("Ton an", 220)
	_sound_button.pressed.connect(func() -> void: Sound.muted = not Sound.muted)
	_quit_button = _menu_button("Beenden", 260)
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
	# Die Sprache steht immer in ihrer eigenen Sprache, damit man sie auch im Fremdtext findet.
	_language_button.text = "Sprache: Deutsch" if Loc.language == "de" else "Language: English"
