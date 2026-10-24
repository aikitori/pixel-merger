class_name Projectile
extends Node2D
## Geschoss einer Fernkampf- oder Heil-Angriffsform (siehe AttackKinds) auf dem Weg zu einem Ziel.
## Schaden bzw. Heilung kommt beim Einschlag, Aussehen und Tempo stehen in AttackKinds.INFO.

const BURST_SECONDS := 0.18
const TRAIL_LENGTH := 5

var _kind: StringName
var _look := "orb"
var _speed := 150.0
var _color := Color.WHITE
var _tint := Color.WHITE  # Farbe der Einheit, färbt Kugeln leicht ein
var _damage := 0.0
var _target: Combatant
var _source: Combatant
var _aim := Vector2.ZERO
var _direction := Vector2.RIGHT
var _burst_left := 0.0
var _trail: Array[Vector2] = []
var _age := 0.0


func setup(from: Vector2, target: Combatant, kind: StringName, tint: Color, damage: float, source: Combatant = null) -> void:
	_source = source
	position = from
	_target = target
	_kind = kind if AttackKinds.INFO.has(kind) else AttackKinds.for_style(kind)
	var info: Dictionary = AttackKinds.INFO[_kind]
	_look = info.get("look", "orb")
	_speed = maxf(float(info.get("speed", 150.0)), 60.0)
	_color = info.get("color", Color.WHITE)
	_tint = tint
	_damage = damage
	_aim = target.center()
	_direction = (_aim - from).normalized()
	z_index = 10


func is_heal() -> bool:
	return AttackKinds.INFO[_kind]["family"] == "heal"


func _physics_process(frame_delta: float) -> void:
	if Game.phase != Game.Phase.BATTLE:
		queue_free()
		return
	var delta := Game.battle_delta(frame_delta)
	_age += delta
	if _burst_left > 0.0:
		_burst_left -= delta
		if _burst_left <= 0.0:
			queue_free()
		queue_redraw()
		return
	if is_instance_valid(_target) and _target.is_alive():
		_aim = _target.center()
	var to_aim := _aim - position
	var step := _speed * delta
	if to_aim.length() <= step:
		position = _aim
		_hit()
		return
	_direction = to_aim.normalized()
	position += _direction * step
	_trail.push_front(position)
	if _trail.size() > TRAIL_LENGTH:
		_trail.pop_back()
	queue_redraw()


func _hit() -> void:
	if is_instance_valid(_target) and _target.is_alive():
		if is_heal():
			_target.heal(_damage, _source if is_instance_valid(_source) else null)
		else:
			Combatant.land_hit(_source if is_instance_valid(_source) else null, _target, _damage, _kind)
	if _look in ["arrow", "javelin", "shard"]:
		Sound.play(&"hit")
		queue_free()
		return
	if _kind == &"fireball":
		Sound.play(&"explode")
	_burst_left = BURST_SECONDS
	queue_redraw()


func _draw() -> void:
	if _burst_left > 0.0:
		var t := 1.0 - _burst_left / BURST_SECONDS
		var big := 7.0 if _kind == &"fireball" else 4.0
		draw_circle(Vector2.ZERO, 3.0 + big * t, Color(_color.r, _color.g, _color.b, 0.75 * (1.0 - t)))
		draw_circle(Vector2.ZERO, 1.5 + 3.0 * t, Color(1.0, 1.0, 0.9, 0.85 * (1.0 - t)))
		return
	var side := _direction.orthogonal()
	match _look:
		"arrow":
			var tail := -_direction * 9.0
			draw_line(tail, Vector2.ZERO, _color, 1.0)
			draw_line(Vector2.ZERO, -_direction * 2.0, Color.WHITE, 2.0)
			draw_line(tail, tail - _direction * 2.0 + side * 1.5, Color.WHITE, 1.0)
			draw_line(tail, tail - _direction * 2.0 - side * 1.5, Color.WHITE, 1.0)
		"javelin":
			draw_line(-_direction * 13.0, Vector2.ZERO, _color, 1.5)
			draw_line(Vector2.ZERO, -_direction * 3.0, Color("#eef3ff"), 2.5)
		"shard":
			var tip := _direction * 3.0
			draw_colored_polygon(PackedVector2Array([tip, -_direction * 5.0 + side * 2.0, -_direction * 7.0,
					-_direction * 5.0 - side * 2.0]), _color)
			draw_line(tip, -_direction * 5.0, Color.WHITE, 1.0)
		"drop":
			_draw_trail(2.5, 0.4)
			draw_circle(Vector2.ZERO, 3.0, _color)
			draw_circle(-_direction * 0.5 + Vector2(-1, -1), 1.0, Color(1, 1, 1, 0.8))
		"skull":
			_draw_trail(3.0, 0.35)
			var wobble := sin(_age * 18.0) * 1.0
			draw_circle(side * wobble, 3.5, _color)
			draw_rect(Rect2(side * wobble + Vector2(-2, -1), Vector2(1.5, 1.5)), Color("#1a0d2a"))
			draw_rect(Rect2(side * wobble + Vector2(0.5, -1), Vector2(1.5, 1.5)), Color("#1a0d2a"))
		"fireball":
			_draw_trail(4.0, 0.5)
			draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.5, 0.1).lerp(_tint, 0.35))
			draw_circle(Vector2.ZERO, 2.0, Color(1.0, 0.95, 0.6))
		"heal":
			_draw_trail(3.0, 0.45)
			draw_circle(Vector2.ZERO, 3.5, _color)
			draw_rect(Rect2(-1, -3, 2, 6), Color.WHITE)
			draw_rect(Rect2(-3, -1, 6, 2), Color.WHITE)
		_:  # Kugel (Arkan, Glut)
			_draw_trail(3.0, 0.45)
			var pulse := 3.0 + sin(_age * 25.0) * 0.6
			draw_circle(Vector2.ZERO, pulse, _color.lerp(_tint, 0.2))
			draw_circle(Vector2.ZERO, 1.5, Color(1, 1, 1, 0.9))


func _draw_trail(size: float, alpha: float) -> void:
	for i in _trail.size():
		var fade := 1.0 - float(i) / TRAIL_LENGTH
		draw_circle(_trail[i] - position, size * fade, Color(_color.r, _color.g, _color.b, alpha * fade))
