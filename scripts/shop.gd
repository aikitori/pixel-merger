class_name Shop
extends PanelContainer
## Kaufliste einer Kategorie. Wird im Dorf (siehe Village) geöffnet, wenn man ein Haus antippt.

signal unit_chosen(data: UnitData)

const ICON_WIDTH := 22
const SMALL_FONT := 10

var _title: Label
var _list: VBoxContainer
var _price_buttons: Dictionary = {}  # Button -> UnitData (Grundeinheit oder höhere Stufe)
var _category := ""
## Ausbau des Hauses (siehe Game.upgrade_house): Stufe und Wirkung links, Knopf mit Preis rechts.
var _house_label: Label
var _house_button: Button


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(470, 270)
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
	close.text = "X"
	close.custom_minimum_size = Vector2(32, 24)
	close.pressed.connect(close_panel)
	header.add_child(close)

	var house := HBoxContainer.new()
	column.add_child(house)
	_house_label = Label.new()
	_house_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_house_label.add_theme_font_size_override("font_size", SMALL_FONT)
	house.add_child(_house_label)
	_house_button = Button.new()
	_house_button.custom_minimum_size = Vector2(120, 24)
	_house_button.add_theme_font_size_override("font_size", SMALL_FONT)
	_house_button.tooltip_text = tr("Jede Stufe: +%d %% Leben und Stärke für alle Einheiten dieses Hauses, Kombinationen anteilig") \
			% roundi(Game.HOUSE_BONUS_PER_LEVEL * 100)
	_house_button.pressed.connect(func() -> void:
		if Game.upgrade_house(_category):
			Sound.play(&"buy")
		refresh())
	house.add_child(_house_button)

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
	_category = category
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
		var unit: UnitData = _price_buttons[button]
		var blocked := Registry.buy_block_reason(unit)
		# Höhere Stufen erscheinen erst, wenn sie kaufbar werden können (Runde), Gesperrtes bleibt sichtbar.
		button.visible = unit.shop_order > 0 or Game.round_number >= Game.DIRECT_BUY_ROUND
		button.disabled = not building or blocked != "" or Game.gold < Registry.shop_price(unit)
		var tip := tr("%s (%s)\n%s\nReichweite %d\n%s: %s") % [unit.display_name, unit.line_name,
				unit.stats_text(), roundi(unit.attack_range), Abilities.label(unit.ability), Abilities.description(unit.ability)]
		button.tooltip_text = tip + ("\n" + blocked if blocked != "" else "")
		if unit.shop_order > 0:
			var locked := Game.house_level(unit.category) < unit.house_level
			button.text = tr("%s  ab Ausbau %d") % [unit.display_name, unit.house_level] if locked \
					else "%s  %dg" % [unit.display_name, unit.price]
	if _category == "":
		return
	var level := Game.house_level(_category)
	var price := Game.house_price(_category)
	_house_label.text = tr("Ausbau Stufe %d: +%d %% Leben und Stärke") % [level, roundi(level * Game.HOUSE_BONUS_PER_LEVEL * 100)]
	_house_button.text = tr("Ausbauen: %dg") % price
	_house_button.disabled = not building or Game.gold < price


func _add_row(unit: UnitData) -> void:
	var row := HBoxContainer.new()
	var buy := Button.new()
	buy.icon = unit.sprite
	buy.expand_icon = true
	buy.alignment = HORIZONTAL_ALIGNMENT_LEFT
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.add_theme_constant_override("icon_max_width", ICON_WIDTH)
	buy.pressed.connect(func() -> void: unit_chosen.emit(unit))
	row.add_child(buy)
	_price_buttons[buy] = unit
	# Ab Runde Game.DIRECT_BUY_ROUND: Stufe 2 und 3 direkt kaufen.
	for higher in Registry.line_levels(unit).slice(1):
		var direct := Button.new()
		direct.text = tr("St. %d: %dg") % [higher.level, Registry.shop_price(higher)]
		direct.icon = higher.sprite
		direct.expand_icon = true
		direct.add_theme_constant_override("icon_max_width", 14)
		direct.add_theme_font_size_override("font_size", SMALL_FONT)
		direct.pressed.connect(func() -> void: unit_chosen.emit(higher))
		row.add_child(direct)
		_price_buttons[direct] = higher
	var stats := Label.new()
	stats.text = unit.stats_text() + "\n* " + Abilities.label(unit.ability)
	stats.add_theme_font_size_override("font_size", SMALL_FONT)
	stats.modulate.a = 0.8
	row.add_child(stats)
	_list.add_child(row)
