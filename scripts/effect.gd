class_name Effect
extends Node2D
## Kurze Kampfeffekte: Ring, Pfeilregen, Explosion, Blitz, Feuerkegel und aufsteigender Fähigkeitsname.

## Wie viele Treffer-/Staubeffekte gleichzeitig laufen dürfen (Leistung auf dem Handy).
const MAX_AMBIENT := 50
static var ambient_count := 0

var _kind: StringName
var _radius := 20.0
var _color := Color.WHITE
var _text := ""
var _age := 0.0
var _life := 0.6
## Blitz: Weg zum Ziel, Kegel: Blickrichtung (relativ zur Position).
var direction := Vector2.ZERO


func setup(kind: StringName, at: Vector2, radius: float, color: Color, text := "") -> void:
	_kind = kind
	position = at
	_radius = radius
	_color = color
	_text = text
	_life = 1.0 if kind == &"text" else 0.55
	z_index = 12
	if kind == &"spark" or kind == &"puff":
		ambient_count += 1
		_life = 0.22 if kind == &"spark" else 0.5


func _exit_tree() -> void:
	if _kind == &"spark" or _kind == &"puff":
		ambient_count = maxi(ambient_count - 1, 0)


static func can_spawn_ambient() -> bool:
	return ambient_count < MAX_AMBIENT


func _physics_process(frame_delta: float) -> void:
	if Game.phase != Game.Phase.BATTLE:
		queue_free()
		return
	_age += Game.battle_delta(frame_delta)
	if _age >= _life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / _life
	var fade := Color(_color.r, _color.g, _color.b, 1.0 - t)
	match _kind:
		&"ring":
			draw_arc(Vector2.ZERO, _radius * (0.3 + 0.7 * t), 0.0, TAU, 28, fade, 2.0)
		&"burst":
			draw_circle(Vector2.ZERO, _radius * (0.4 + 0.6 * t), Color(_color.r, _color.g, _color.b, 0.45 * (1.0 - t)))
			draw_arc(Vector2.ZERO, _radius * (0.4 + 0.6 * t), 0.0, TAU, 28, fade, 2.0)
		&"rain":
			draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 28, Color(_color.r, _color.g, _color.b, 0.35 * (1.0 - t)), 1.0)
			for i in 9:
				var angle := i * 2.4
				var spot := Vector2(cos(angle), sin(angle)) * _radius * (0.2 + 0.08 * i)
				var drop := -34.0 * (1.0 - minf(1.0, t * 1.8 - i * 0.04))
				draw_line(spot + Vector2(0, drop - 6.0), spot + Vector2(0, drop), fade, 1.0)
		&"bolt":
			# Zickzack vom Start zum Ziel, jedes Bild neu verwackelt
			var points := PackedVector2Array([Vector2.ZERO])
			var normal := direction.orthogonal().normalized()
			for i in range(1, 6):
				points.append(direction * (i / 6.0) + normal * randf_range(-5.0, 5.0))
			points.append(direction)
			draw_polyline(points, fade, 2.0)
			draw_polyline(points, Color(1, 1, 1, 1.0 - t), 1.0)
		&"cone":
			var aim := direction.angle()
			var reach := _radius * (0.4 + 0.6 * t)
			var cone := PackedVector2Array([Vector2.ZERO])
			for i in 7:
				cone.append(Vector2.from_angle(aim - 0.6 + 0.2 * i) * reach)
			draw_colored_polygon(cone, Color(_color.r, _color.g, _color.b, 0.5 * (1.0 - t)))
			draw_polyline(cone.slice(1), fade, 2.0)
		&"spark":
			for i in 6:
				var angle := i * TAU / 6.0 + _radius
				draw_line(Vector2.from_angle(angle) * (2.0 + 5.0 * t), Vector2.from_angle(angle) * (4.0 + 8.0 * t), fade, 1.0)
		&"puff":
			for i in 3:
				var angle := i * 2.1 + _radius
				var spot := Vector2.from_angle(angle) * (3.0 + 9.0 * t)
				draw_circle(spot + Vector2(0, -6.0 * t), 3.0 + 4.0 * t, Color(_color.r, _color.g, _color.b, 0.55 * (1.0 - t)))
		&"text":
			var font := ThemeDB.fallback_font
			var at := Vector2(-40.0, -t * 10.0)
			draw_string(font, at + Vector2(1, 1), _text, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 9, Color(0, 0, 0, 1.0 - t))
			draw_string(font, at, _text, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 9, fade)
