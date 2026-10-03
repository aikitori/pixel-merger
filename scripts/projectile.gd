class_name Projectile
extends Node2D
## Pfeil, Feuerball oder Heilzauber auf dem Weg zu einem Ziel. Schaden bzw. Heilung kommt beim Einschlag.

const ARROW_SPEED := 260.0
const FIREBALL_SPEED := 150.0
const HEAL_SPEED := 120.0
const BURST_SECONDS := 0.18
const TRAIL_LENGTH := 5

var _style: StringName
var _color := Color.WHITE
var _damage := 0.0
var _target: Combatant
var _source: Combatant
var _aim := Vector2.ZERO
var _direction := Vector2.RIGHT
var _burst_left := 0.0
var _trail: Array[Vector2] = []


func setup(from: Vector2, target: Combatant, style: StringName, color: Color, damage: float, source: Combatant = null) -> void:
	_source = source
	position = from
	_target = target
	_style = style
	_color = color
	_damage = damage
	_aim = target.center()
	_direction = (_aim - from).normalized()
	z_index = 10


func _physics_process(frame_delta: float) -> void:
	if Game.phase != Game.Phase.BATTLE:
		queue_free()
		return
	var delta := Game.battle_delta(frame_delta)
	if _burst_left > 0.0:
		_burst_left -= delta
		if _burst_left <= 0.0:
			queue_free()
		queue_redraw()
		return
	if is_instance_valid(_target) and _target.is_alive():
		_aim = _target.center()
	var to_aim := _aim - position
	var step := (ARROW_SPEED if _style == &"arrow" else (HEAL_SPEED if _style == &"heal" else FIREBALL_SPEED)) * delta
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
		if _style == &"heal":
			_target.heal(_damage)
		else:
			_target.take_damage(_damage, _source if is_instance_valid(_source) else null)
	if _style == &"arrow":
		Sound.play(&"hit")
		queue_free()
	else:
		if _style != &"heal":
			Sound.play(&"explode")
		_burst_left = BURST_SECONDS
		queue_redraw()


func _draw() -> void:
	if _style == &"arrow":
		var tail := -_direction * 9.0
		draw_line(tail, Vector2.ZERO, Color("#c97a2e"), 1.0)
		draw_line(Vector2.ZERO, -_direction * 2.0, Color.WHITE, 2.0)
		var side := _direction.orthogonal() * 1.5
		draw_line(tail, tail - _direction * 2.0 + side, Color.WHITE, 1.0)
		draw_line(tail, tail - _direction * 2.0 - side, Color.WHITE, 1.0)
		return
	if _burst_left > 0.0:
		var t := 1.0 - _burst_left / BURST_SECONDS
		if _style == &"heal":
			draw_circle(Vector2.ZERO, 4.0 + 7.0 * t, Color(0.3, 1.0, 0.5, 0.7 * (1.0 - t)))
			draw_circle(Vector2.ZERO, 2.0 + 3.0 * t, Color(0.9, 1.0, 0.9, 0.9 * (1.0 - t)))
			return
		draw_circle(Vector2.ZERO, 4.0 + 7.0 * t, Color(1.0, 0.6, 0.15, 0.8 * (1.0 - t)))
		draw_circle(Vector2.ZERO, 2.0 + 3.0 * t, Color(1.0, 0.95, 0.6, 0.9 * (1.0 - t)))
		return
	if _style == &"heal":
		for i in _trail.size():
			var fade := 1.0 - float(i) / TRAIL_LENGTH
			draw_circle(_trail[i] - position, 3.0 * fade, Color(0.3, 1.0, 0.5, 0.45 * fade))
		draw_circle(Vector2.ZERO, 3.5, Color(0.3, 0.95, 0.5))
		draw_rect(Rect2(-1, -3, 2, 6), Color.WHITE)
		draw_rect(Rect2(-3, -1, 6, 2), Color.WHITE)
		return
	for i in _trail.size():
		var fade := 1.0 - float(i) / TRAIL_LENGTH
		draw_circle(_trail[i] - position, 4.0 * fade, Color(1.0, 0.45, 0.1, 0.5 * fade))
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.5, 0.1).lerp(_color, 0.35))
	draw_circle(Vector2.ZERO, 2.0, Color(1.0, 0.95, 0.6))
