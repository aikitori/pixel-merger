class_name PausePanel
extends Control
## Spielmenü (Knopf oben, Esc, Zurück-Taste): Im Kampf hält es den Szenenbaum an (die Oberfläche läuft
## weiter), in der Bauphase nicht. Zeigt die Steuerung für Maus und Tastatur oder für Touch.

signal menu_pressed

var _title: Label
var _note: Label
var _help: GridContainer
var _help_touch := false


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.1, 0.7)
	dim.size = Vector2(640, 360)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_title = Label.new()
	_title.position = Vector2(220, 26)
	_title.size = Vector2(200, 36)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", UiTheme.GOLD_LIGHT)
	add_child(_title)
	var board := PanelContainer.new()
	board.position = Vector2(70, 64)
	board.size = Vector2(500, 10)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiTheme.sign_style()
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 6
	board.add_theme_stylebox_override("panel", style)
	add_child(board)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	board.add_child(column)
	var heading := Label.new()
	heading.text = tr("Steuerung")
	heading.add_theme_font_size_override("font_size", 11)
	heading.add_theme_color_override("font_color", UiTheme.GOLD_LIGHT)
	column.add_child(heading)
	_help = GridContainer.new()
	_help.columns = 2
	_help.add_theme_constant_override("h_separation", 8)
	_help.add_theme_constant_override("v_separation", 1)
	column.add_child(_help)
	_note = Label.new()
	_note.position = Vector2(120, 292)
	_note.size = Vector2(400, 14)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", 9)
	_note.add_theme_color_override("font_color", Color("#d8c8a0"))
	add_child(_note)
	var resume := Button.new()
	resume.text = tr("Weiter")
	resume.position = Vector2(206, 310)
	resume.size = Vector2(110, 30)
	resume.pressed.connect(close)
	add_child(resume)
	var leave := Button.new()
	leave.text = tr("Hauptmenü")
	leave.position = Vector2(324, 310)
	leave.size = Vector2(110, 30)
	leave.pressed.connect(func() -> void: menu_pressed.emit())
	add_child(leave)


## `pause`: Kampf anhalten (sonst nur das Menü zeigen).
func open(pause: bool) -> void:
	_title.text = tr("Pause") if pause else tr("Menü")
	_note.text = tr("Hauptmenü: Später geht es vor diesem Kampf weiter") if pause \
			else tr("Hauptmenü: Der Lauf wird gespeichert")
	_fill_help()
	visible = true
	get_tree().paused = pause


func close() -> void:
	visible = false
	get_tree().paused = false


func is_open() -> bool:
	return visible


## Hält das Menü gerade den Kampf an?
func is_paused() -> bool:
	return visible and get_tree().paused


## Übersicht passend zur letzten Eingabe (Finger oder Maus), nur bei Wechsel neu aufbauen.
func _fill_help() -> void:
	if _help.get_child_count() > 0 and _help_touch == PlayerInput.touch:
		return
	_help_touch = PlayerInput.touch
	for child in _help.get_children():
		child.queue_free()
	for line: Array in PlayerInput.help():
		var key := Label.new()
		key.text = line[0]
		key.add_theme_font_size_override("font_size", 9)
		key.add_theme_color_override("font_color", UiTheme.GOLD_LIGHT)
		_help.add_child(key)
		var text := Label.new()
		text.text = line[1]
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(350, 0)
		text.add_theme_font_size_override("font_size", 9)
		_help.add_child(text)
