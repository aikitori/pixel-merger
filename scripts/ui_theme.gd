class_name UiTheme
extends RefCounted
## Gemeinsames Aussehen der Oberfläche: Holz, Gold und Pergament, passend zum Pixel-Fantasy-Stil.
## Alle Rahmen sind kleine, im Code gezeichnete Bilder (9-Patch), damit die Pixel scharf bleiben.

const INK := Color("#24123a")
const GOLD := Color("#c58b2d")
const GOLD_LIGHT := Color("#ffe27a")
const CREAM := Color("#fff0c8")
const BROWN_TEXT := Color("#3a2410")
const PARCHMENT := Color("#f3e3b8")

static var _cache: Dictionary = {}


## Nach einem Stilwechsel (ArtStyle) neu zeichnen.
static func clear_cache() -> void:
	_cache.clear()


## Das Theme für die ganze Oberfläche (Knöpfe, Panels, Eingabefeld, Scrollbalken, Tooltips).
static func make() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 12

	var edge := ArtStyle.ui("edge", GOLD)
	var outline := ArtStyle.ui("outline", INK)
	var text := ArtStyle.ui("text", CREAM)
	var shadow := ArtStyle.ui("text_shadow", Color(0, 0, 0, 0.55))
	theme.set_stylebox("normal", "Button", _box("btn", ArtStyle.ui("btn_top", Color("#8a5630")),
			ArtStyle.ui("btn_bottom", Color("#6b4122")), edge, 8, 3, 0, outline))
	theme.set_stylebox("hover", "Button", _box("btn_hover", ArtStyle.ui("btn_hover_top", Color("#a56a3a")),
			ArtStyle.ui("btn_bottom", Color("#7f4e2a")), ArtStyle.ui("edge", GOLD_LIGHT), 8, 3, 0, outline))
	theme.set_stylebox("pressed", "Button", _box("btn_pressed", ArtStyle.ui("btn_pressed_top", Color("#5a3520")),
			ArtStyle.ui("btn_pressed_bottom", Color("#4a2a18")), edge, 8, 3, 1, outline))
	theme.set_stylebox("disabled", "Button", _box("btn_off", Color("#4a3a30"), Color("#3a2c24"), Color("#6b5a45"), 8, 3))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", text)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", GOLD_LIGHT)
	theme.set_color("font_disabled_color", "Button", Color("#8a7a66"))
	theme.set_color("font_shadow_color", "Button", shadow)
	theme.set_constant("shadow_offset_x", "Button", 1)
	theme.set_constant("shadow_offset_y", "Button", 1)

	var panel := _box("panel", ArtStyle.ui("panel_top", Color("#3a2415")), ArtStyle.ui("panel_bottom", Color("#2a190e")),
			edge, 6, 5, 0, outline)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)

	theme.set_color("font_color", "Label", ArtStyle.ui("label_text", text))
	theme.set_color("font_shadow_color", "Label", ArtStyle.ui("label_shadow", ArtStyle.ui("text_shadow", Color(0, 0, 0, 0.6))))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)

	var field := _box("field", Color("#f6e8c0"), Color("#eadaa8"), Color("#c9aa6c"), 5, 3, 0, Color("#5a3a1a"))
	var field_focus := _box("field_focus", Color("#fff3d0"), Color("#f3e3b8"), GOLD, 5, 3, 0, Color("#5a3a1a"))
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", field_focus)
	theme.set_stylebox("read_only", "LineEdit", field)
	theme.set_color("font_color", "LineEdit", BROWN_TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", Color(0.35, 0.22, 0.1, 0.55))
	theme.set_color("caret_color", "LineEdit", BROWN_TEXT)
	theme.set_color("selection_color", "LineEdit", Color(0.77, 0.55, 0.18, 0.4))

	for bar in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", bar, _flat(Color(0.1, 0.05, 0.02, 0.35), 2))
		theme.set_stylebox("scroll_focus", bar, _flat(Color(0.1, 0.05, 0.02, 0.35), 2))
		theme.set_stylebox("grabber", bar, _flat(GOLD, 2))
		theme.set_stylebox("grabber_highlight", bar, _flat(GOLD_LIGHT, 2))
		theme.set_stylebox("grabber_pressed", bar, _flat(GOLD_LIGHT, 2))

	theme.set_stylebox("panel", "TooltipPanel", _box("tip", Color("#3a2415"), Color("#2a190e"), GOLD, 4, 4))
	theme.set_color("font_color", "TooltipLabel", CREAM)
	return theme


## Theme für Beschriftungen auf Pergament (dunkle Tinte statt heller Schrift).
static func make_parchment() -> Theme:
	var theme := make()
	theme.set_color("font_color", "Label", BROWN_TEXT)
	theme.set_color("font_shadow_color", "Label", Color(1, 1, 1, 0.0))
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 0)
	theme.default_font_size = 10
	return theme


## Holztafel für Beschriftungen (Schilder im Dorf, Hinweise).
static func sign_style() -> StyleBoxTexture:
	return _box("sign", ArtStyle.ui("btn_top", Color("#8a5630")), ArtStyle.ui("btn_bottom", Color("#6b4122")),
			ArtStyle.ui("outline", Color("#3a2410")), 5, 2, 0, ArtStyle.ui("outline", INK))


## Querbalken aus Holzplanken, `edge_top`: Zierleiste oben (untere Leiste) statt unten (obere Leiste).
static func plank_bar(width: int, height: int, edge_top: bool) -> ImageTexture:
	var key := "bar_%d_%d_%s" % [width, height, edge_top]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var plank_width := 80
	for y in height:
		for x in width:
			var plank := x / plank_width
			var base := ArtStyle.ui("plank_a", Color("#5c3a20")) if plank % 2 == 0 else ArtStyle.ui("plank_b", Color("#523319"))
			var shade := rng.randf_range(-0.03, 0.03)
			if (y + plank * 5) % 6 == 0:  # Maserung
				shade -= 0.05
			var c := base.lightened(shade) if shade > 0.0 else base.darkened(-shade)
			if x % plank_width == 0:
				c = ArtStyle.ui("plank_seam", Color("#2a160a"))
			elif x % plank_width == 1:
				c = base.lightened(0.1)
			img.set_pixel(x, y, c)
	for plank in width / plank_width + 1:  # Nägel
		for nail_y in [4, height - 5]:
			for dx in [5, plank_width - 6]:
				var nx: int = plank * plank_width + dx
				if nx < width and nail_y >= 0 and nail_y < height:
					img.set_pixel(nx, nail_y, Color("#b8a58a"))
	var edge_y := 0 if edge_top else height - 1
	var step := 1 if edge_top else -1
	for x in width:
		img.set_pixel(x, edge_y, ArtStyle.ui("outline", INK))
		img.set_pixel(x, edge_y + step, ArtStyle.ui("edge", GOLD))
		img.set_pixel(x, edge_y + 2 * step, Color("#8a5f1e"))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Kleine Goldmünze (10x10).
static func coin() -> ImageTexture:
	if _cache.has("coin"):
		return _cache["coin"]
	var rows := [
		"..kkkkkk..",
		".kyyyyyyk.",
		"kyyYYYYyyk",
		"kyYyyyyYyk",
		"kyYyYYyYyk",
		"kyYyYYyYyk",
		"kyYyyyyYyk",
		"kyyYYYYyyk",
		".kYyyyyYk.",
		"..kkkkkk..",
	]
	var palette := {"k": INK, "y": Color("#ffd91f"), "Y": Color("#e08a00")}
	var img := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	for y in 10:
		for x in 10:
			var ch: String = rows[y][x]
			img.set_pixel(x, y, palette.get(ch, Color(0, 0, 0, 0)))
	var tex := ImageTexture.create_from_image(img)
	_cache["coin"] = tex
	return tex


## Schattenriss eines Sprites (unentdeckte Geheimrezepte): alle sichtbaren Pixel dunkel.
static func silhouette(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var key := "silhouette_%s" % texture.resource_path
	if _cache.has(key):
		return _cache[key]
	var img := texture.get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.1:
				img.set_pixel(x, y, Color(0.14, 0.07, 0.23, 0.9))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# --- Bausteine ------------------------------------------------------------------

## 9-Patch-Rahmen: Umriss, Zierkante, Füllung mit Farbverlauf und hellerer Oberkante.
static func _box(key: String, top: Color, bottom: Color, edge: Color, margin_x: int, margin_y: int,
		press_offset := 0, outline := INK) -> StyleBoxTexture:
	var tex: ImageTexture
	if _cache.has(key):
		tex = _cache[key]
	else:
		tex = _frame_texture(12, 12, outline, edge, top, bottom)
		_cache[key] = tex
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.set_texture_margin_all(4)
	box.content_margin_left = margin_x
	box.content_margin_right = margin_x
	box.content_margin_top = margin_y + press_offset
	box.content_margin_bottom = margin_y - press_offset
	return box


static func _frame_texture(w: int, h: int, outline: Color, edge: Color, top: Color, bottom: Color) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c: Color
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				c = outline
			elif x == 1 or y == 1 or x == w - 2 or y == h - 2:
				c = edge
			else:
				c = top.lerp(bottom, float(y - 2) / maxf(1.0, h - 5.0))
				if y == 2:
					c = top.lightened(0.22)
			img.set_pixel(x, y, c)
	for corner in [Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, h - 1), Vector2i(w - 1, h - 1)]:
		img.set_pixelv(corner, Color(0, 0, 0, 0))
	for inner in [Vector2i(1, 1), Vector2i(w - 2, 1), Vector2i(1, h - 2), Vector2i(w - 2, h - 2)]:
		img.set_pixelv(inner, outline)
	return ImageTexture.create_from_image(img)


static func _flat(color: Color, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(2)
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin
	box.content_margin_bottom = margin
	return box
