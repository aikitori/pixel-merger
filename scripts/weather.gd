class_name Weather
extends Node2D
## Darstellung der Sonderregel der Runde (siehe Modifiers): Nebel, Blutmond, Schnee, Goldregen ...
## Liegt über den Figuren und fängt keine Eingaben ab.

const FIELD := Rect2(0, 24, 640, 296)
const FLAKES := 150

var _kind: StringName = &""
var _flakes: Array[Vector3] = []  # x, y, Tempo
var _time := 0.0


func _ready() -> void:
	z_index = 20
	Game.modifier_changed.connect(func(_id: StringName) -> void: _restart())
	_restart()


func _restart() -> void:
	_kind = Modifiers.weather(Game.modifier)
	_flakes.clear()
	if _kind in [&"snow", &"gold", &"holy"]:
		for i in FLAKES if _kind == &"snow" else FLAKES / 3:
			_flakes.append(Vector3(randf() * FIELD.size.x, FIELD.position.y + randf() * FIELD.size.y, randf_range(0.6, 1.4)))
	visible = _kind != &""
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	for i in _flakes.size():
		var flake := _flakes[i]
		match _kind:
			&"snow":
				flake.y += 22.0 * flake.z * delta
				flake.x += sin(_time * 1.3 + i) * 10.0 * delta - 6.0 * delta
			&"gold":
				flake.y += 34.0 * flake.z * delta
			&"holy":  # Lichtfunken steigen auf
				flake.y -= 12.0 * flake.z * delta
		if flake.y > FIELD.end.y:
			flake.y = FIELD.position.y
			flake.x = randf() * FIELD.size.x
		elif flake.y < FIELD.position.y:
			flake.y = FIELD.end.y
			flake.x = randf() * FIELD.size.x
		flake.x = fposmod(flake.x, FIELD.size.x)
		_flakes[i] = flake
	queue_redraw()


func _draw() -> void:
	match _kind:
		&"fog":
			draw_rect(FIELD, Color(0.85, 0.88, 0.95, 0.22))
			for i in 7:  # treibende Nebelbänke
				var x := fposmod(i * 113.0 + _time * (8.0 + i * 2.0), FIELD.size.x + 160.0) - 80.0
				var y := FIELD.position.y + 30.0 + i * 38.0
				for j in 3:
					draw_circle(Vector2(x + j * 26.0, y + sin(_time + i) * 4.0), 26.0 - j * 4.0, Color(0.92, 0.94, 1.0, 0.13))
		&"blood_moon":
			draw_rect(FIELD, Color(0.55, 0.0, 0.05, 0.13 + 0.03 * sin(_time * 1.5)))
			draw_circle(Vector2(590, 52), 14.0, Color(0.85, 0.15, 0.12, 0.9))
			draw_circle(Vector2(585, 48), 4.0, Color(0.6, 0.05, 0.05, 0.8))
		&"calm":
			draw_rect(FIELD, Color(0.75, 0.9, 1.0, 0.06))
		&"holy":
			draw_rect(FIELD, Color(1.0, 0.95, 0.6, 0.08))
			for flake in _flakes:
				draw_rect(Rect2(flake.x, flake.y, 2, 4), Color(1.0, 0.97, 0.6, 0.9))
				draw_rect(Rect2(flake.x - 1, flake.y + 1, 4, 2), Color(1.0, 0.97, 0.6, 0.45))
		&"snow":
			draw_rect(FIELD, Color(0.85, 0.92, 1.0, 0.2))
			for flake in _flakes:
				var size := 4.0 if flake.z > 1.1 else 3.0
				draw_rect(Rect2(flake.x - 1, flake.y + 1, size, size), Color(0.45, 0.55, 0.75, 0.5))
				draw_rect(Rect2(flake.x, flake.y, size, size), Color(1, 1, 1, 0.95))
		&"gold":
			for flake in _flakes:
				draw_rect(Rect2(flake.x - 1, flake.y - 1, 6, 6), UiTheme.INK)
				draw_rect(Rect2(flake.x, flake.y, 4, 4), UiTheme.GOLD_LIGHT)
				draw_rect(Rect2(flake.x, flake.y + 3, 4, 1), Color("#e08a00"))
