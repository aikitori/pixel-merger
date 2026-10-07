class_name Village
extends Control
## Das Dorf: eigene Ansicht neben der Arena. Jedes Haus gehört einer Kategorie von Grundeinheiten,
## ein Tipp auf das Haus öffnet deren Kaufliste (Shop). Gekaufte Einheiten erscheinen in der Arena.

signal unit_chosen(data: UnitData)

## Position und Größe unter der oberen Leiste, in Bildschirmpixeln. Das Bild kommt aus tools/tiles_dcss.py
## (dort stehen die Häuser an denselben Stellen, in vollen Pixeln).
const AREA := Rect2(0, 24, 640, 296)
const ART := preload("res://assets/sprites/tiles/village.png")
const HOUSE_HEIGHT := 40
const HOUSE_HALF_WIDTH := 28

## Kategorie des Shops, Hausname, Mitte (x) und Grundlinie (y) in Zeichen-Pixeln, Bauart.
const HOUSES := [
	{"category": "Klassisch", "name": "Kaserne", "x": 55, "base": 56, "kind": "barracks"},
	{"category": "Fantasy", "name": "Gildenhaus", "x": 160, "base": 56, "kind": "guild"},
	{"category": "Märchen", "name": "Märchenhütte", "x": 265, "base": 56, "kind": "fairy"},
	{"category": "Mythologie", "name": "Tempel", "x": 65, "base": 122, "kind": "temple"},
	{"category": "Elemente", "name": "Elementarturm", "x": 255, "base": 122, "kind": "tower"},
	{"category": "Heilkunst", "name": "Lazarett", "x": 160, "base": 132, "kind": "clinic"},
]

var shop: Shop
var _buttons: Array[Button] = []


func _ready() -> void:
	visible = false
	position = AREA.position
	size = AREA.size
	mouse_filter = Control.MOUSE_FILTER_STOP  # schluckt Tipps, die sonst in die Arena gingen

	var background := TextureRect.new()
	background.texture = ART
	background.position = Vector2.ZERO
	background.size = AREA.size
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var banner := _sign(tr("Dorf – tippe auf ein Haus"), Rect2(200, 4, 240, 18))
	add_child(banner)

	var by_category := _units_by_category()
	for house in HOUSES:
		_add_house(house, by_category.get(house["category"], []))

	shop = Shop.new()
	shop.unit_chosen.connect(func(data: UnitData) -> void: unit_chosen.emit(data))
	add_child(shop)


func open_category(category: String) -> void:
	for house in HOUSES:
		if house["category"] == category:
			shop.open_category(category, "%s – %s" % [tr(house["name"]), tr(category)])
			return


## Platz, den die Ansicht gerade verdeckt (die ganze Fläche zwischen den Leisten).
func blocked_rect() -> Rect2:
	return AREA if visible else Rect2()


func _units_by_category() -> Dictionary:
	var result: Dictionary = {}
	for unit in Registry.shop_units():
		if not result.has(unit.category):
			result[unit.category] = []
		result[unit.category].append(unit)
	return result


func _add_house(house: Dictionary, units: Array) -> void:
	var cx: int = house["x"] * 2
	var base: int = house["base"] * 2
	var area := Rect2(cx - HOUSE_HALF_WIDTH * 2, base - HOUSE_HEIGHT * 2 - 8, HOUSE_HALF_WIDTH * 4, HOUSE_HEIGHT * 2 + 28)
	var button := Button.new()
	button.position = area.position
	button.size = area.size
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tr("%s: %d Einheiten") % [tr(house["name"]), units.size()]
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1, 1, 1, 0.14)
	hover.set_border_width_all(2)
	hover.border_color = Color("#ffe27a")
	hover.set_corner_radius_all(4)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(func() -> void: open_category(house["category"]))
	add_child(button)
	_buttons.append(button)
	add_child(_sign("%s (%d)" % [tr(house["name"]), units.size()], Rect2(cx - 62, base + 6, 124, 16)))
	# Zwei Bewohner vor der Tür, damit man sieht, was es dort gibt.
	for i in mini(units.size(), 2):
		var unit: UnitData = units[i]
		var figure := TextureRect.new()
		figure.texture = Combatant.frames_texture(unit.sprite, false)
		figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var feet := Vector2(cx + (-40 if i == 0 else 8), base + 4)
		figure.position = feet - Vector2(figure.texture.get_width() / 2.0 - 16.0, figure.texture.get_height())
		add_child(figure)


func _sign(text: String, rect: Rect2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_stylebox_override("normal", UiTheme.sign_style())
	return label
