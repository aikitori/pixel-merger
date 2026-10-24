class_name GameOverPanel
extends ColorRect
## Verloren-Bildschirm: erreichte Runde, Auswertung des Laufs, Rekord, Neustart und Hauptmenü.

signal restart_pressed
signal menu_pressed

var _title: Label
var _stats: Label


func _ready() -> void:
	color = Color(0.05, 0.0, 0.08, 0.75)
	size = Vector2(640, 360)
	visible = false
	var board := Panel.new()
	board.position = Vector2(190, 70)
	board.size = Vector2(260, 220)
	add_child(board)
	_title = _add_label(board, Rect2(0, 14, 260, 56), HORIZONTAL_ALIGNMENT_CENTER)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", UiTheme.GOLD_LIGHT)
	_stats = _add_label(board, Rect2(20, 76, 220, 90), HORIZONTAL_ALIGNMENT_LEFT)
	_stats.add_theme_font_size_override("font_size", 11)
	var again := Button.new()
	again.text = tr("Neustart")
	again.position = Vector2(30, 174)
	again.size = Vector2(95, 30)
	again.pressed.connect(func() -> void: restart_pressed.emit())
	board.add_child(again)
	var to_menu := Button.new()
	to_menu.text = tr("Hauptmenü")
	to_menu.position = Vector2(135, 174)
	to_menu.size = Vector2(95, 30)
	to_menu.pressed.connect(func() -> void: menu_pressed.emit())
	board.add_child(to_menu)


## `stats` aus Game.stats, `new_record`: der Lauf hat den Rekord verbessert.
func show_result(reached_round: int, stats: Dictionary = {}, best_round := 0, new_record := false) -> void:
	_title.text = tr("Verloren!\nRunde %d erreicht") % reached_round
	var best: UnitData = Registry.units.get(StringName(stats.get("best_unit", "")))
	var lines := [
		tr("Besiegte Gegner: %d") % int(stats.get("kills", 0)),
		tr("Gold erbeutet: %d") % int(stats.get("gold", 0)),
		tr("Verbindungen: %d") % int(stats.get("merges", 0)),
		tr("Stärkste Einheit: %s") % (best.display_name if best != null else "-"),
		tr("Neuer Rekord!") if new_record else tr("Rekord: Runde %d") % best_round,
	]
	_stats.text = "\n".join(lines)
	visible = true


func _add_label(parent: Control, rect: Rect2, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = align
	parent.add_child(label)
	return label
