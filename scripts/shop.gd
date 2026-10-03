class_name Shop
extends PanelContainer
## Kaufliste einer Kategorie. Wird im Dorf (siehe Village) geöffnet, wenn man ein Haus antippt.

signal unit_chosen(data: UnitData)

const ICON_WIDTH := 22
const SMALL_FONT := 10

var _title: Label
var _list: VBoxContainer
var _price_buttons: Dictionary = {}  # Button -> Preis


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(384, 270)
	size = custom_minimum_size
	position = Vector2((640.0 - size.x) / 2.0, (296.0 - size.y) / 2.0)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(32, 24)
	close.pressed.connect(close_panel)
	header.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)


## Zeigt die kaufbaren Einheiten einer Kategorie (z.B. "Klassisch") unter der Überschrift `title`.
func open_category(category: String, title: String) -> void:
	for child in _list.get_children():
		child.queue_free()
	_price_buttons.clear()
	_title.text = title
	for unit in Registry.shop_units():
		if unit.category == category:
			_add_row(unit)
	visible = true
	refresh()


func close_panel() -> void:
	visible = false


## Platz, den das Panel auf dem Bildschirm belegt (leer, wenn es zu ist).
func blocked_rect() -> Rect2:
	return Rect2(position, size) if visible else Rect2()


## Preise gegen das aktuelle Gold prüfen und Kaufknöpfe sperren/freigeben.
func refresh() -> void:
	var building := Game.phase == Game.Phase.BUILD
	for button: Button in _price_buttons:
		button.disabled = not building or Game.gold < _price_buttons[button]


func _add_row(unit: UnitData) -> void:
	var row := HBoxContainer.new()
	var buy := Button.new()
	buy.text = "%s  %dg" % [unit.display_name, unit.price]
	buy.icon = unit.sprite
	buy.expand_icon = true
	buy.alignment = HORIZONTAL_ALIGNMENT_LEFT
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.add_theme_constant_override("icon_max_width", ICON_WIDTH)
	buy.tooltip_text = tr("%s (%s)\n%s\nReichweite %d\n%s: %s") % [
		unit.display_name, unit.line_name, unit.stats_text(), roundi(unit.attack_range),
		Abilities.label(unit.ability), Abilities.description(unit.ability)]
	buy.pressed.connect(func() -> void: unit_chosen.emit(unit))
	row.add_child(buy)
	var stats := Label.new()
	stats.text = unit.stats_text() + "\n★ " + Abilities.label(unit.ability)
	stats.add_theme_font_size_override("font_size", SMALL_FONT)
	stats.modulate.a = 0.8
	row.add_child(stats)
	_list.add_child(row)
	_price_buttons[buy] = unit.price
