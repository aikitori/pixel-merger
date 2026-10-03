class_name AchievementsPanel
extends PanelContainer
## Liste aller Erfolge: freigeschaltete in Gold, die übrigen abgedunkelt mit Fortschritt.

const ICON_SIZE := 20

var _title: Label
var _list: VBoxContainer


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(420, 280)
	size = custom_minimum_size
	position = Vector2((640.0 - size.x) / 2.0, 36.0)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(32, 24)
	close.pressed.connect(close_panel)
	header.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_list)


func open_panel() -> void:
	for child in _list.get_children():
		child.queue_free()
	_title.text = tr("Erfolge  %d / %d") % [Achievements.unlocked_count(), Achievements.LIST.size()]
	for entry in Achievements.LIST:
		_list.add_child(_row(entry))
	visible = true


func close_panel() -> void:
	visible = false


func _row(entry: Dictionary) -> Control:
	var done := Achievements.is_unlocked(entry["id"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.texture = UiTheme.coin()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color.WHITE if done else Color(0.3, 0.3, 0.3, 0.8)
	row.add_child(icon)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := Label.new()
	name.text = tr(entry["name"])
	name.add_theme_color_override("font_color", UiTheme.GOLD_LIGHT if done else UiTheme.CREAM)
	info.add_child(name)
	var text := Label.new()
	text.text = tr(entry["text"])
	text.add_theme_font_size_override("font_size", 9)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 10.0
	info.add_child(text)
	row.add_child(info)
	var progress := Label.new()
	progress.text = tr("geschafft") if done else "%d / %d" % [Achievements.progress.get(entry["id"], 0), entry["goal"]]
	progress.add_theme_font_size_override("font_size", 10)
	progress.add_theme_color_override("font_color", Color("#9be66e") if done else Color("#b8a58a"))
	row.add_child(progress)
	row.modulate.a = 1.0 if done else 0.75
	return row
