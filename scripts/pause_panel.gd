class_name PausePanel
extends Control
## Pause im Kampf: hält den Szenenbaum an (die Oberfläche läuft weiter) und deckt das Feld ab.

func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.1, 0.6)
	dim.size = Vector2(640, 360)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var title := Label.new()
	title.text = tr("Pause")
	title.position = Vector2(220, 130)
	title.size = Vector2(200, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UiTheme.GOLD_LIGHT)
	add_child(title)
	var resume := Button.new()
	resume.text = tr("Weiter")
	resume.position = Vector2(270, 184)
	resume.size = Vector2(100, 30)
	resume.pressed.connect(func() -> void: set_paused(false))
	add_child(resume)


func set_paused(on: bool) -> void:
	visible = on
	get_tree().paused = on


func is_paused() -> bool:
	return visible
