class_name World
extends RefCounted
## Spielwelt: ein Kreuz aus zwei sich schneidenden Armen, von oben gesehen. Die eigenen Einheiten stehen in
## der Mitte, die Gegner kommen aus allen vier Richtungen. Außerhalb des Kreuzes sind Mauern.
## Boden, Mauern und Hindernisse sind Bilder aus tools/tiles_dcss.py (Maße müssen zu den Konstanten passen).
## Alle Positionen sind Fußpunkte der Figuren in Arena-Koordinaten (640x360).

enum Arm { WEST, NORTH, EAST, SOUTH }

## Sichtbarer Bereich zwischen oberer und unterer Leiste.
const FIELD := Rect2(0, 24, 640, 296)
const CENTER := Vector2(320, 172)
const ARM_HALF_WIDTH := 70.0
## Abstand der Figuren zum Rand, damit Köpfe nicht in die Mauer ragen.
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


static func obstacle_texture(kind: String) -> Texture2D:
	return load("res://assets/sprites/tiles/obstacle_%s.png" % kind)


## Fußpunkt des Bildes: unten Mitte.
static func obstacle_offset(kind: String) -> Vector2:
	var size := obstacle_texture(kind).get_size()
	return Vector2(-size.x / 2.0, -size.y + 3.0)


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


## Zeichnet Boden und Mauern. `canvas` ist das Node2D, auf dem gemalt wird.
static func draw(canvas: CanvasItem) -> void:
	canvas.draw_texture(TERRAIN, Vector2.ZERO)


const TERRAIN := preload("res://assets/sprites/tiles/arena.png")


static func _inside(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x and point.x <= rect.end.x and point.y >= rect.position.y and point.y <= rect.end.y


static func _clamp_to_rect(point: Vector2, rect: Rect2) -> Vector2:
	return Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))
