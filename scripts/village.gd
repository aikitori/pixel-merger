class_name Village
extends Control
## Das Dorf: eigene Ansicht neben der Arena. Jedes Haus gehört einer Kategorie von Grundeinheiten,
## ein Tipp auf das Haus öffnet deren Kaufliste (Shop). Gekaufte Einheiten erscheinen in der Arena.

signal unit_chosen(data: UnitData)

## Position und Größe unter der oberen Leiste, in Bildschirmpixeln (die Zeichnung ist halb so groß).
const AREA := Rect2(0, 24, 640, 296)
const ART_SIZE := Vector2i(320, 148)
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

static var _art: ImageTexture

var shop: Shop
var _buttons: Array[Button] = []


func _ready() -> void:
	visible = false
	position = AREA.position
	size = AREA.size
	mouse_filter = Control.MOUSE_FILTER_STOP  # schluckt Tipps, die sonst in die Arena gingen

	var background := TextureRect.new()
	if _art == null:
		_art = ImageTexture.create_from_image(build_art())
	background.texture = _art
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
		figure.texture = unit.sprite
		figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var feet := Vector2(cx + (-40 if i == 0 else 8), base + 4)
		figure.position = feet - Vector2(unit.sprite.get_width() / 2.0 - 16.0, unit.sprite.get_height())
		add_child(figure)
		var bob := create_tween().set_loops()
		bob.tween_interval(randf() * 0.8)
		bob.tween_property(figure, "position:y", figure.position.y - 2.0, 0.45)
		bob.tween_property(figure, "position:y", figure.position.y, 0.45)


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


# --- Zeichnung ---------------------------------------------------------------------

## Malt das ganze Dorf in ein kleines Bild (halbe Auflösung, dadurch grobe Pixel wie bei den Sprites).
static func build_art() -> Image:
	var img := Image.create(ART_SIZE.x, ART_SIZE.y, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for y in ART_SIZE.y:
		for x in ART_SIZE.x:
			var c := Color("#5ab552") if ((x / 6) + (y / 6)) % 2 == 0 else Color("#51a84b")
			if rng.randf() < 0.04:
				c = c.darkened(0.15)
			elif rng.randf() < 0.012:
				c = c.lightened(0.18)
			img.set_pixel(x, y, c)
	_paths(img, rng)
	for i in 70:  # Blumen
		var x := rng.randi_range(2, ART_SIZE.x - 3)
		var y := rng.randi_range(2, ART_SIZE.y - 3)
		var petal: Color = [Color("#ffe14a"), Color("#ffffff"), Color("#ff86c8"), Color("#8ad4ff")][rng.randi() % 4]
		if img.get_pixel(x, y).r < 0.7:
			img.set_pixel(x, y, petal)
	for tree in [Vector2i(12, 24), Vector2i(308, 24), Vector2i(14, 96), Vector2i(306, 96), Vector2i(108, 30),
			Vector2i(212, 30), Vector2i(36, 140), Vector2i(284, 140), Vector2i(110, 136),
			Vector2i(210, 136)]:
		_tree(img, tree.x, tree.y)
	_fountain(img, 160, 80)
	for house in HOUSES:
		match house["kind"]:
			"barracks": _barracks(img, house["x"], house["base"])
			"guild": _guild(img, house["x"], house["base"])
			"fairy": _fairy(img, house["x"], house["base"])
			"temple": _temple(img, house["x"], house["base"])
			"tower": _tower(img, house["x"], house["base"])
			"clinic": _clinic(img, house["x"], house["base"])
	return img


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var r := Rect2i(x, y, w, h).intersection(Rect2i(0, 0, ART_SIZE.x, ART_SIZE.y))
	if r.size.x > 0 and r.size.y > 0:
		img.fill_rect(r, c)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < ART_SIZE.x and y < ART_SIZE.y:
		img.set_pixel(x, y, c)


static func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	for y in range(-ry, ry + 1):
		var span := int(rx * sqrt(maxf(0.0, 1.0 - float(y * y) / float(ry * ry))))
		_rect(img, cx - span, cy + y, span * 2 + 1, 1, c)


## Dachfläche als Dreieck mit Schindelstreifen. `top` ist die Spitze, `overhang` der Überstand.
static func _roof(img: Image, cx: int, top: int, half: int, height: int, c: Color, dark: Color) -> void:
	for r in height:
		var w := int(half * float(r + 1) / height)
		_rect(img, cx - w, top + r, w * 2 + 1, 1, dark if r % 4 == 3 else c)
		_px(img, cx - w, top + r, c.darkened(0.35))
		_px(img, cx + w, top + r, c.darkened(0.35))


static func _door(img: Image, cx: int, base: int, w: int, h: int, c: Color) -> void:
	_rect(img, cx - w / 2, base - h, w, h, c)
	_rect(img, cx - w / 2 + 1, base - h - 1, w - 2, 1, c)
	_px(img, cx + w / 2 - 2, base - h / 2, Color("#ffd91f"))


static func _window(img: Image, x: int, y: int, w: int, h: int) -> void:
	_rect(img, x - 1, y - 1, w + 2, h + 2, Color("#3a2410"))
	_rect(img, x, y, w, h, Color("#ffe88a"))
	_rect(img, x, y, w, 1, Color("#fff6c8"))
	_rect(img, x + w / 2, y, 1, h, Color("#c98a2e"))


static func _outline_wall(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	_rect(img, x - 1, y - 1, w + 2, h + 2, Color("#24123a"))
	_rect(img, x, y, w, h, c)


static func _barracks(img: Image, cx: int, base: int) -> void:
	var stone := Color("#a8b0c8")
	var top := base - 30
	_outline_wall(img, cx - 26, top, 53, 30, stone)
	for row in 6:  # Mauerwerk
		_rect(img, cx - 26, top + row * 5, 53, 1, stone.darkened(0.18))
		for col in range(row % 2 * 5, 53, 10):
			_rect(img, cx - 26 + col, top + row * 5, 1, 5, stone.darkened(0.18))
	for i in range(-26, 27, 10):  # Zinnen
		_rect(img, cx + i - 1, top - 5, 6, 5, Color("#24123a"))
		_rect(img, cx + i, top - 4, 4, 4, stone)
	_rect(img, cx - 3, top - 26, 1, 22, Color("#5e3b1a"))  # Fahnenstange
	_rect(img, cx - 2, top - 26, 12, 7, Color("#ff3b4a"))
	_rect(img, cx - 2, top - 22, 12, 1, Color("#a8153f"))
	_rect(img, cx + 3, top - 25, 2, 4, Color("#ffd91f"))
	_door(img, cx, base, 12, 17, Color("#7a3f1a"))
	_window(img, cx - 21, top + 7, 5, 8)
	_window(img, cx + 16, top + 7, 5, 8)
	# gekreuzte Schwerter über der Tür
	for i in 7:
		_px(img, cx - 9 + i, top + 3 + i / 2, Color("#ffffff"))
		_px(img, cx + 9 - i, top + 3 + i / 2, Color("#ffffff"))


static func _guild(img: Image, cx: int, base: int) -> void:
	var wall_top := base - 22
	_outline_wall(img, cx - 22, wall_top, 45, 22, Color("#f0e0b0"))
	_rect(img, cx - 22, wall_top, 45, 2, Color("#7a3f1a"))  # Fachwerk
	_rect(img, cx - 22, wall_top, 2, 22, Color("#7a3f1a"))
	_rect(img, cx + 21, wall_top, 2, 22, Color("#7a3f1a"))
	_rect(img, cx - 1, wall_top, 2, 22, Color("#7a3f1a"))
	for i in 10:
		_px(img, cx - 20 + i * 2, wall_top + 2 + i, Color("#7a3f1a"))
	_roof(img, cx, base - 40, 30, 19, Color("#3fb85a"), Color("#2a8a42"))
	_rect(img, cx + 14, base - 41, 6, 10, Color("#8a8a9c"))  # Schornstein
	_rect(img, cx + 14, base - 42, 6, 2, Color("#5a5a70"))
	for k in 3:  # Rauch
		_px(img, cx + 17 + k, base - 46 - k * 2, Color("#d8d8e8"))
	_door(img, cx - 9, base, 10, 15, Color("#7a3f1a"))
	_ellipse(img, cx + 11, base - 11, 5, 5, Color("#3a2410"))
	_ellipse(img, cx + 11, base - 11, 4, 4, Color("#ffe88a"))
	_rect(img, cx + 10, base - 15, 2, 8, Color("#c98a2e"))
	# Laterne
	_rect(img, cx + 24, base - 16, 1, 10, Color("#3a2410"))
	_rect(img, cx + 23, base - 18, 3, 3, Color("#ffd91f"))


static func _fairy(img: Image, cx: int, base: int) -> void:
	_ellipse(img, cx, base - 10, 19, 10, Color("#24123a"))
	_ellipse(img, cx, base - 10, 18, 9, Color("#fff0c8"))
	_rect(img, cx - 19, base - 10, 39, 11, Color("#24123a"))
	_rect(img, cx - 18, base - 10, 37, 10, Color("#fff0c8"))
	# Pilzhut als Dach
	_ellipse(img, cx, base - 24, 27, 16, Color("#24123a"))
	_ellipse(img, cx, base - 24, 26, 15, Color("#e8403c"))
	_rect(img, cx - 27, base - 24, 55, 5, Color("#24123a"))
	_rect(img, cx - 26, base - 24, 53, 4, Color("#e8403c"))
	for dot in [Vector2i(-14, -30), Vector2i(0, -34), Vector2i(13, -29), Vector2i(-5, -24), Vector2i(19, -23), Vector2i(-21, -23)]:
		_ellipse(img, cx + dot.x, base + dot.y, 3, 2, Color("#ffffff"))
	_door(img, cx, base, 9, 13, Color("#9b50c8"))
	_ellipse(img, cx - 12, base - 9, 3, 3, Color("#ffe88a"))
	_ellipse(img, cx + 12, base - 9, 3, 3, Color("#ffe88a"))
	for f in [Vector2i(-24, -2), Vector2i(-20, -1), Vector2i(21, -2), Vector2i(25, -1)]:  # Blumenbeet
		_px(img, cx + f.x, base + f.y, [Color("#ff86c8"), Color("#ffe14a")][(f.x + 100) % 2])
		_px(img, cx + f.x, base + f.y + 1, Color("#2f7f3a"))


static func _temple(img: Image, cx: int, base: int) -> void:
	var marble := Color("#f4f0ff")
	var dark := Color("#b9b4d8")
	for s in 3:  # Stufen
		_rect(img, cx - 28 + s * 2, base - 2 - s * 2, 57 - s * 4, 2, marble if s % 2 == 0 else dark)
	_rect(img, cx - 24, base - 32, 49, 2, dark)  # Gebälk
	_rect(img, cx - 25, base - 33, 51, 1, Color("#24123a"))
	_rect(img, cx - 5, base - 28, 11, 24, Color("#3a2f5a"))  # dunkle Tür
	_rect(img, cx - 5, base - 28, 11, 1, Color("#ffd91f"))
	for col in 5:  # Säulen
		var x := cx - 23 + col * 11
		_rect(img, x - 1, base - 31, 6, 27, Color("#24123a"))
		_rect(img, x, base - 31, 4, 27, marble)
		_rect(img, x + 3, base - 31, 1, 27, dark)
		_rect(img, x - 1, base - 31, 6, 2, Color("#ffd91f"))
	# Giebel
	_roof(img, cx, base - 44, 27, 11, Color("#ffd91f"), Color("#e08a00"))
	_ellipse(img, cx, base - 36, 3, 3, Color("#fff0a8"))
	_rect(img, cx - 28, base - 33, 57, 1, Color("#e08a00"))


static func _tower(img: Image, cx: int, base: int) -> void:
	var stone := Color("#7f8fe0")
	var top := base - 28
	_outline_wall(img, cx - 13, top, 27, 28, stone)
	for row in 6:
		_rect(img, cx - 13, top + row * 5, 27, 1, stone.darkened(0.2))
	_rect(img, cx - 13, top, 3, 28, stone.lightened(0.15))
	_rect(img, cx + 11, top, 3, 28, stone.darkened(0.2))
	_rect(img, cx - 16, top - 2, 33, 3, Color("#24123a"))  # Dachrand
	_rect(img, cx - 15, top - 1, 31, 2, Color("#4a3fa8"))
	_roof(img, cx, base - 50, 16, 20, Color("#9b50c8"), Color("#6a1fb8"))
	_px(img, cx, base - 52, Color("#ffd91f"))
	_px(img, cx, base - 51, Color("#ffd91f"))
	_door(img, cx, base, 8, 12, Color("#5a2e1c"))
	_window(img, cx - 3, top + 4, 6, 8)
	# vier schwebende Elementkristalle
	for crystal in [[-24, -38, Color("#ff3b4a")], [24, -38, Color("#2f8cff")], [-22, -22, Color("#3fe05a")], [22, -22, Color("#ffd91f")]]:
		var x: int = cx + crystal[0]
		var y: int = base + crystal[1]
		for r in 5:
			_rect(img, x - (2 - absi(r - 2)), y + r, (2 - absi(r - 2)) * 2 + 1, 1, crystal[2])
		_px(img, x - 1, y + 1, Color("#ffffff"))


static func _clinic(img: Image, cx: int, base: int) -> void:
	var wall_top := base - 22
	_outline_wall(img, cx - 22, wall_top, 45, 22, Color("#f4f0ff"))
	_rect(img, cx - 22, base - 3, 45, 3, Color("#b9d0ff"))  # Sockel
	_roof(img, cx, base - 40, 28, 19, Color("#e8f4ff"), Color("#b9d0ff"))
	_ellipse(img, cx, base - 34, 6, 6, Color("#24123a"))  # rotes Kreuz im Giebel
	_ellipse(img, cx, base - 34, 5, 5, Color("#ffffff"))
	_rect(img, cx - 1, base - 37, 3, 7, Color("#ff3b4a"))
	_rect(img, cx - 3, base - 35, 7, 3, Color("#ff3b4a"))
	_door(img, cx, base, 9, 14, Color("#3fb85a"))
	_window(img, cx - 17, wall_top + 6, 6, 7)
	_window(img, cx + 12, wall_top + 6, 6, 7)
	for k in 3:  # Kräuterbeet
		_px(img, cx - 26 + k * 2, base - 1, Color("#2f7f3a"))
		_px(img, cx + 22 + k * 2, base - 1, Color("#2f7f3a"))
		_px(img, cx - 26 + k * 2, base - 2, Color("#ffffff"))
		_px(img, cx + 22 + k * 2, base - 2, Color("#ff86c8"))


static func _tree(img: Image, x: int, y: int) -> void:
	_rect(img, x - 2, y - 2, 4, 8, Color("#24123a"))
	_rect(img, x - 1, y - 2, 2, 8, Color("#7a3f1a"))
	_ellipse(img, x, y - 8, 9, 8, Color("#24123a"))
	_ellipse(img, x, y - 8, 8, 7, Color("#2f9a3c"))
	_ellipse(img, x - 2, y - 11, 4, 3, Color("#5ed05a"))
	for dot in [Vector2i(3, -6), Vector2i(-4, -5), Vector2i(1, -9)]:
		_px(img, x + dot.x, y + dot.y, Color("#1d7a30"))


static func _fountain(img: Image, cx: int, cy: int) -> void:
	_ellipse(img, cx, cy, 16, 9, Color("#24123a"))
	_ellipse(img, cx, cy, 15, 8, Color("#c8ccd8"))
	_ellipse(img, cx, cy, 12, 6, Color("#5ff2ff"))
	_ellipse(img, cx - 3, cy - 1, 5, 2, Color("#b8f8ff"))
	_rect(img, cx - 2, cy - 12, 4, 12, Color("#c8ccd8"))
	_rect(img, cx - 1, cy - 13, 2, 2, Color("#5ff2ff"))
	for d in [Vector2i(-5, -10), Vector2i(5, -10), Vector2i(-3, -14), Vector2i(3, -14), Vector2i(0, -16)]:
		_px(img, cx + d.x, cy + d.y, Color("#b8f8ff"))


static func _paths(img: Image, rng: RandomNumberGenerator) -> void:
	var dirt := Color("#d8b676")
	var edge := Color("#b8935a")
	var strips: Array[Rect2i] = [
		Rect2i(55 - 6, 56, 12, 16), Rect2i(160 - 6, 56, 12, 50), Rect2i(160 - 6, 100, 12, 32), Rect2i(265 - 6, 56, 12, 16),
		Rect2i(55 - 6, 66, 216, 8), Rect2i(65 - 6, 100, 192, 8),
		Rect2i(65 - 6, 100, 12, 22), Rect2i(255 - 6, 100, 12, 22),
	]
	for strip in strips:
		_rect(img, strip.position.x - 1, strip.position.y - 1, strip.size.x + 2, strip.size.y + 2, edge)
	for strip in strips:
		_rect(img, strip.position.x, strip.position.y, strip.size.x, strip.size.y, dirt)
	for i in 160:  # Kiesel auf den Wegen
		var x := rng.randi_range(0, ART_SIZE.x - 1)
		var y := rng.randi_range(0, ART_SIZE.y - 1)
		if img.get_pixel(x, y).is_equal_approx(dirt):
			img.set_pixel(x, y, dirt.darkened(0.12) if rng.randf() < 0.6 else dirt.lightened(0.15))
