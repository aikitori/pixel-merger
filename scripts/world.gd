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


# --- Hindernisse ------------------------------------------------------------------
# Am Anfang ist das Feld voller Hindernisse. Nach jedem Bosskampf (Runde 6, 16, 26, ...) verschwinden
# drei davon, bis das Feld frei ist. Die Platzierung ist fest (gleicher Seed), auch nach Neustart.

const OBSTACLE_KINDS := ["rock", "tree", "crystal", "ruin"]
const OBSTACLES_REMOVED_PER_STAGE := 3
const MAX_OBSTACLES := 18
## Platz um die Mitte, den kein Hindernis belegt, und Abstand zu den Armenden (Gegner erscheinen dort).
const PLAZA_CLEARANCE := 22.0
const ARM_END_CLEARANCE := 48.0
const OBSTACLE_SPACING := 46.0
## Fußbreite einer Figur, die zusätzlich zum Radius Abstand hält.
const FOOT_RADIUS := 4.0

static var stage := 0
## Einträge: {pos: Vector2 (Fußpunkt), radius: float, kind: String}
static var obstacles: Array[Dictionary] = []
static var _obstacle_textures: Dictionary = {}


## Geländestufe einer Runde: 0 bis Runde 5, danach +1 nach jedem Boss (Runde 6, 16, 26, ...).
static func stage_for_round(round_number: int) -> int:
	return (round_number + 4) / 10


## Anzahl Hindernisse einer Stufe: Stufe 0 voll, danach drei weniger pro Stufe.
static func obstacle_count(for_stage: int) -> int:
	return maxi(MAX_OBSTACLES - OBSTACLES_REMOVED_PER_STAGE * for_stage, 0)


static func set_stage(new_stage: int) -> void:
	stage = new_stage
	obstacles = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4177
	var tries := 0
	var wanted := MAX_OBSTACLES
	while obstacles.size() < wanted and tries < 2000:
		tries += 1
		var point := Vector2(rng.randf_range(0.0, FIELD.size.x), rng.randf_range(FIELD.position.y, FIELD.end.y))
		if _obstacle_fits(point):
			var kind: String = OBSTACLE_KINDS[obstacles.size() % OBSTACLE_KINDS.size()]
			obstacles.append({"pos": point, "radius": _kind_radius(kind), "kind": kind})
	obstacles.resize(mini(obstacles.size(), obstacle_count(new_stage)))


static func _kind_radius(kind: String) -> float:
	match kind:
		"tree": return 7.0
		"crystal": return 9.0
		"ruin": return 9.0
		_: return 11.0


static func _obstacle_fits(point: Vector2) -> bool:
	# Beide Füße der Figuren müssen noch Platz haben: mit Rand im Kreuz, weit weg von Platz und Armenden.
	var inner_h := WALK_HORIZONTAL.grow(-18.0)
	var inner_v := WALK_VERTICAL.grow(-18.0)
	if not (_inside(inner_h, point) or _inside(inner_v, point)):
		return false
	if CENTER_SQUARE.grow(PLAZA_CLEARANCE).has_point(point):
		return false
	if point.x < ARM_END_CLEARANCE and _inside(inner_h, point):
		return false
	if point.x > FIELD.size.x - ARM_END_CLEARANCE and _inside(inner_h, point):
		return false
	if point.y < WALK_VERTICAL.position.y + 30.0 and _inside(inner_v, point) and not _inside(inner_h, point):
		return false
	if point.y > WALK_VERTICAL.end.y - 30.0 and _inside(inner_v, point) and not _inside(inner_h, point):
		return false
	for other in obstacles:
		if point.distance_to(other["pos"]) < OBSTACLE_SPACING:
			return false
	return true


## Schiebt einen Punkt aus Hindernissen heraus. Die Bewegung rutscht dadurch seitlich daran vorbei.
static func push_out_of_obstacles(point: Vector2) -> Vector2:
	for obstacle in obstacles:
		var reach: float = obstacle["radius"] + FOOT_RADIUS
		var offset: Vector2 = point - obstacle["pos"]
		# Flache Ellipse, weil die Hindernisse auf dem Boden stehen und von oben flacher wirken.
		var squashed := Vector2(offset.x, offset.y * 1.4)
		if squashed.length_squared() < reach * reach:
			var direction := squashed.normalized() if squashed.length_squared() > 0.0001 else Vector2.DOWN
			point = obstacle["pos"] + Vector2(direction.x * reach, direction.y * reach / 1.4)
	return point


static func obstacle_texture(kind: String) -> ImageTexture:
	if not _obstacle_textures.has(kind):
		_obstacle_textures[kind] = ImageTexture.create_from_image(_build_obstacle(kind))
	return _obstacle_textures[kind]


## Fußpunkt des Bildes: unten Mitte.
static func obstacle_offset(kind: String) -> Vector2:
	var size := obstacle_texture(kind).get_size()
	return Vector2(-size.x / 2.0, -size.y + 3.0)


static func _build_obstacle(kind: String) -> Image:
	var ink := Color("#24123a")
	match kind:
		"tree":
			var img := Image.create(34, 46, false, Image.FORMAT_RGBA8)
			img.fill_rect(Rect2i(14, 30, 6, 14), Color("#6b4122"))
			img.fill_rect(Rect2i(14, 30, 2, 14), Color("#8a5630"))
			img.fill_rect(Rect2i(13, 42, 8, 2), ink)
			for blob in [[17, 14, 15, 12], [9, 21, 10, 8], [25, 21, 10, 8], [17, 24, 14, 7]]:
				_ellipse(img, blob[0], blob[1], blob[2], blob[3], Color("#1f5a2a"))
			for blob in [[17, 13, 13, 10], [10, 20, 8, 6], [24, 20, 8, 6], [17, 23, 12, 5]]:
				_ellipse(img, blob[0], blob[1], blob[2], blob[3], Color("#2f8a3a"))
			_ellipse(img, 13, 9, 6, 4, Color("#58b84a"))
			img.set_pixel(22, 15, Color("#e8403c"))
			img.set_pixel(12, 22, Color("#e8403c"))
			return img
		"crystal":
			var img := Image.create(26, 38, false, Image.FORMAT_RGBA8)
			for spike in [[13, 6, 5, 30, "#6fd8ff", "#c8f8ff"], [6, 16, 4, 20, "#4aa0e0", "#8ad4ff"], [20, 18, 4, 18, "#4aa0e0", "#8ad4ff"]]:
				var cx: int = spike[0]
				var top: int = spike[1]
				var half: int = spike[2]
				var height: int = spike[3]
				for y in height:
					var narrow := half if y > 4 else maxi(1, half * y / 5)
					img.fill_rect(Rect2i(cx - narrow, top + y, narrow * 2, 1), Color(spike[4]))
					img.fill_rect(Rect2i(cx - narrow, top + y, maxi(1, narrow / 2), 1), Color(spike[5]))
			img.fill_rect(Rect2i(3, 33, 20, 4), Color("#6b6888"))
			img.fill_rect(Rect2i(3, 33, 20, 1), Color("#a7a7bd"))
			img.set_pixel(13, 8, Color.WHITE)
			img.set_pixel(12, 9, Color.WHITE)
			return img
		"ruin":
			var img := Image.create(28, 44, false, Image.FORMAT_RGBA8)
			img.fill_rect(Rect2i(4, 38, 20, 5), Color("#6b6888"))
			img.fill_rect(Rect2i(4, 38, 20, 1), Color("#a7a7bd"))
			img.fill_rect(Rect2i(8, 10, 12, 28), Color("#9a97b0"))
			img.fill_rect(Rect2i(8, 10, 3, 28), Color("#c8c6dc"))
			img.fill_rect(Rect2i(17, 10, 3, 28), Color("#7a7796"))
			img.fill_rect(Rect2i(6, 6, 16, 5), Color("#a7a7bd"))
			img.fill_rect(Rect2i(6, 6, 16, 1), Color("#d6d6e6"))
			img.fill_rect(Rect2i(12, 2, 4, 4), Color("#8683a0"))
			for crack in [[11, 18], [12, 19], [13, 20], [16, 28], [15, 29]]:
				img.set_pixel(crack[0], crack[1], Color("#4a4766"))
			img.fill_rect(Rect2i(8, 30, 4, 3), Color("#4aa43f"))
			img.fill_rect(Rect2i(16, 22, 3, 3), Color("#4aa43f"))
			return img
		_:
			var img := Image.create(30, 24, false, Image.FORMAT_RGBA8)
			_ellipse(img, 15, 13, 14, 10, Color("#4a4766"))
			_ellipse(img, 15, 12, 13, 9, Color("#8683a0"))
			_ellipse(img, 13, 9, 9, 5, Color("#a7a7bd"))
			_ellipse(img, 11, 7, 4, 2, Color("#d6d6e6"))
			img.fill_rect(Rect2i(19, 6, 5, 2), Color("#4aa43f"))
			img.fill_rect(Rect2i(8, 18, 12, 1), Color("#6b6888"))
			return img


static func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, color: Color) -> void:
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			var nx := float(x - cx) / maxf(rx, 1)
			var ny := float(y - cy) / maxf(ry, 1)
			if nx * nx + ny * ny <= 1.0 and x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, color)


## Inklusive Ränder: Figuren, die von clamp_point() an den Rand gesetzt wurden, zählen als drin
## (Rect2.has_point schließt die rechte und untere Kante aus).
static func contains(point: Vector2) -> bool:
	return _inside(WALK_HORIZONTAL, point) or _inside(WALK_VERTICAL, point)


## Nächster begehbarer Punkt. Liegt der Punkt schon im Kreuz, bleibt er unverändert.
static func clamp_point(point: Vector2) -> Vector2:
	var result := _clamp_to_cross(point)
	if obstacles.is_empty():
		return result
	for i in 2:  # Herausschieben kann aus dem Kreuz führen, dann noch einmal zurück
		result = _clamp_to_cross(push_out_of_obstacles(result))
	return result


static func _clamp_to_cross(point: Vector2) -> Vector2:
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
