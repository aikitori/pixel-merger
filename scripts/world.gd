class_name World
extends RefCounted
## Spielwelt: ein Kreuz aus zwei sich schneidenden Armen. Die eigenen Einheiten stehen in der
## Mitte, die Gegner kommen aus allen vier Richtungen. Außerhalb des Kreuzes ist Abgrund.
## Alle Positionen sind Fußpunkte der Figuren in Arena-Koordinaten (640x360).

enum Arm { WEST, NORTH, EAST, SOUTH }

## Sichtbarer Bereich zwischen oberer und unterer Leiste.
const FIELD := Rect2(0, 24, 640, 296)
const CENTER := Vector2(320, 172)
const ARM_HALF_WIDTH := 70.0
## Abstand der Figuren zum Rand, damit Köpfe nicht über den Abgrund ragen.
const EDGE_MARGIN := 6.0
const TOP_MARGIN := 14.0

## Begehbare Rechtecke (für Fußpunkte).
const WALK_HORIZONTAL := Rect2(0, 172 - 70 + 8, 640, 2 * 70 - 8)
const WALK_VERTICAL := Rect2(320 - 70 + 6, 24 + 14, 2 * 70 - 12, 296 - 14)
## Die Mitte, in der die eigenen Einheiten stehen.
const CENTER_SQUARE := Rect2(320 - 70 + 6, 172 - 70 + 8, 2 * 70 - 12, 2 * 70 - 8)


## Inklusive Ränder: Figuren, die von clamp_point() an den Rand gesetzt wurden, zählen als drin
## (Rect2.has_point schließt die rechte und untere Kante aus).
static func contains(point: Vector2) -> bool:
	return _inside(WALK_HORIZONTAL, point) or _inside(WALK_VERTICAL, point)


## Nächster begehbarer Punkt. Liegt der Punkt schon im Kreuz, bleibt er unverändert.
static func clamp_point(point: Vector2) -> Vector2:
	if contains(point):
		return point
	var a := _clamp_to_rect(point, WALK_HORIZONTAL)
	var b := _clamp_to_rect(point, WALK_VERTICAL)
	return a if point.distance_squared_to(a) <= point.distance_squared_to(b) else b


## Zufälliger Punkt am äußeren Ende des Arms, an dem Gegner erscheinen.
static func spawn_point(arm: Arm) -> Vector2:
	match arm:
		Arm.WEST:
			return Vector2(WALK_HORIZONTAL.position.x + 2.0, randf_range(WALK_HORIZONTAL.position.y, WALK_HORIZONTAL.end.y))
		Arm.EAST:
			return Vector2(WALK_HORIZONTAL.end.x - 2.0, randf_range(WALK_HORIZONTAL.position.y, WALK_HORIZONTAL.end.y))
		Arm.NORTH:
			return Vector2(randf_range(WALK_VERTICAL.position.x, WALK_VERTICAL.end.x), WALK_VERTICAL.position.y + 2.0)
		_:
			return Vector2(randf_range(WALK_VERTICAL.position.x, WALK_VERTICAL.end.x), WALK_VERTICAL.end.y - 2.0)


## Zufälliger Platz in der Mitte (Standard für neu gekaufte Einheiten).
static func random_center_point() -> Vector2:
	return Vector2(
		randf_range(CENTER_SQUARE.position.x, CENTER_SQUARE.end.x),
		randf_range(CENTER_SQUARE.position.y, CENTER_SQUARE.end.y))


## Zeichnet das Kreuz als schwebende Fantasy-Insel. `canvas` ist das Node2D, auf dem gemalt wird.
static func draw(canvas: CanvasItem) -> void:
	if _terrain == null:
		_terrain = ImageTexture.create_from_image(_build_terrain())
	canvas.draw_texture(_terrain, Vector2.ZERO)


static var _terrain: ImageTexture


static func _arms() -> Array[Rect2]:
	return [
		Rect2(0, CENTER.y - ARM_HALF_WIDTH, FIELD.size.x, 2 * ARM_HALF_WIDTH),
		Rect2(CENTER.x - ARM_HALF_WIDTH, FIELD.position.y, 2 * ARM_HALF_WIDTH, FIELD.size.y),
	]


static func _on_island(x: int, y: int) -> bool:
	for rect in _arms():
		if _inside(rect, Vector2(x, y)):
			return true
	return false


## Malt einmalig die ganze Spielfläche in ein Bild: Dämmerhimmel mit Sternen und Wolken,
## Grasinsel mit Blumen und Pilzen, Steinplatz mit Runenkreis in der Mitte, Felskante.
static func _build_terrain() -> Image:
	var img := Image.create(640, 360, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Himmel: Verlauf von tiefem Blau zu Violett und Orange am Horizont
	var top := Color("#171446")
	var mid := Color("#5a2d86")
	var low := Color("#d1699a")
	for y in 360:
		var t := y / 359.0
		var c := top.lerp(mid, minf(t * 1.6, 1.0)) if t < 0.625 else mid.lerp(low, (t - 0.625) / 0.375)
		img.fill_rect(Rect2i(0, y, 640, 1), c)
	for i in 90:
		var star := Color("#ffffff") if rng.randf() < 0.6 else Color("#9fe8ff")
		img.set_pixel(rng.randi_range(0, 639), rng.randi_range(0, 230), star)
	for i in 14:  # weiche Wolkenbänder
		var cx := rng.randi_range(0, 640)
		var cy := rng.randi_range(40, 340)
		var cloud := Color(1.0, 0.85, 0.95, 0.16)
		for j in 3:
			var w := rng.randi_range(30, 70)
			img.blend_rect(_solid(w, 5, cloud), Rect2i(0, 0, w, 5), Vector2i(cx + j * 10 - 15, cy - j * 3))
	# Felskante unter beiden Armen (zackig, mit Moos)
	for rect in _arms():
		for x in range(int(rect.position.x), int(rect.end.x)):
			var depth := 7 + absi(int(9.0 * sin(x * 0.21) * sin(x * 0.07 + 1.0))) + rng.randi_range(0, 2)
			for d in range(1, depth + 1):
				var y := int(rect.end.y) + d - 1
				if y >= 360 or _on_island(x, y):
					continue
				var c := Color("#9a7442") if d <= 2 else (Color("#6e4b2b") if d <= depth - 3 else Color("#4a3020"))
				if d > 2 and rng.randf() < 0.12:
					c = c.darkened(0.25)
				if d == 1 and rng.randf() < 0.5:
					c = Color("#4aa43f")
				img.set_pixel(x, y, c)
	# Gras mit Schachbrett-Tönung, Büscheln und hellem/dunklem Rand
	var grass_a := Color("#4fb04a")
	var grass_b := Color("#47a343")
	for y in 360:
		for x in 640:
			if not _on_island(x, y):
				continue
			var c := grass_a if ((x / 8) + (y / 8)) % 2 == 0 else grass_b
			if not _on_island(x, y - 1):
				c = Color("#9be36e")
			elif not _on_island(x, y + 1) or not _on_island(x, y + 2):
				c = Color("#2f7f3a")
			elif rng.randf() < 0.035:
				c = c.darkened(0.18)
			elif rng.randf() < 0.012:
				c = c.lightened(0.2)
			img.set_pixel(x, y, c)
	# Steinplatz in der Mitte, dort stehen die eigenen Einheiten
	var plaza := CENTER_SQUARE.grow(4.0)
	for y in range(int(plaza.position.y), int(plaza.end.y)):
		for x in range(int(plaza.position.x), int(plaza.end.x)):
			var tx := x % 16
			var ty := (y + 8 * ((x / 16) % 2)) % 16
			var c := Color("#9a97b0") if (tx + ty) % 7 != 0 else Color("#8683a0")
			if tx == 0 or ty == 0:
				c = Color("#6b6888")
			elif rng.randf() < 0.04:
				c = c.lightened(0.15)
			img.set_pixel(x, y, c)
	# Runenkreis um die Mitte
	for ring in [[56.0, Color("#7be6ff")], [48.0, Color("#b583ff")]]:
		var steps := int(TAU * ring[0] * 2.0)
		for i in steps:
			var a := TAU * i / steps
			var px := int(CENTER.x + cos(a) * ring[0])
			var py := int(CENTER.y + sin(a) * ring[0] * 0.8)
			if i % 9 < 6:
				img.set_pixel(px, py, ring[1])
	for i in 8:  # Runenpunkte
		var a := TAU * i / 8.0
		var rx := int(CENTER.x + cos(a) * 52.0)
		var ry := int(CENTER.y + sin(a) * 52.0 * 0.8)
		img.fill_rect(Rect2i(rx - 1, ry - 1, 3, 3), Color("#ffe27a"))
	# Deko: Blumen, Pilze, Steine abseits des Platzes
	var placed := 0
	while placed < 150:
		var x := rng.randi_range(0, 639)
		var y := rng.randi_range(26, 316)
		if not _on_island(x, y) or not _on_island(x, y + 6) or not _on_island(x + 6, y) or plaza.grow(6.0).has_point(Vector2(x, y)):
			continue
		placed += 1
		match rng.randi() % 4:
			0, 1:
				var petal: Color = [Color("#ffe14a"), Color("#ffffff"), Color("#ff86c8"), Color("#8ad4ff")][rng.randi() % 4]
				img.set_pixel(x, y, petal)
				img.set_pixel(x + 1, y, petal)
				img.set_pixel(x, y + 1, Color("#2f7f3a"))
			2:
				img.fill_rect(Rect2i(x, y, 5, 2), Color("#e8403c"))
				img.fill_rect(Rect2i(x + 1, y - 1, 3, 1), Color("#e8403c"))
				img.set_pixel(x + 1, y, Color("#ffffff"))
				img.fill_rect(Rect2i(x + 2, y + 2, 1, 2), Color("#f4e9d0"))
			_:
				img.fill_rect(Rect2i(x, y, 5, 3), Color("#a7a7bd"))
				img.fill_rect(Rect2i(x, y + 2, 5, 1), Color("#6b6888"))
				img.fill_rect(Rect2i(x + 1, y, 2, 1), Color("#d6d6e6"))
	return img


static func _solid(w: int, h: int, color: Color) -> Image:
	var i := Image.create(w, h, false, Image.FORMAT_RGBA8)
	i.fill(color)
	return i


static func _inside(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x and point.x <= rect.end.x and point.y >= rect.position.y and point.y <= rect.end.y


static func _clamp_to_rect(point: Vector2, rect: Rect2) -> Vector2:
	return Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))
