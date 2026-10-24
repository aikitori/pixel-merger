class_name DeathAnim
extends Node2D
## Kurze Todesanimation an der Stelle einer gefallenen Figur. Die Figur selbst wird sofort freigegeben
## (Zählungen und Gruppen bleiben einfach), dieser Knoten spielt die Todesbilder ihres Streifens ab
## (Bilder Combatant.DEATH_FRAME bis +3) und verschwindet dann.

const SECONDS := 0.5

var _anim: Texture2D
var _flip := 1.0
var _age := 0.0


static func spawn(unit: Combatant) -> void:
	if unit.anim == null or unit.get_parent() == null or not Effect.can_spawn_ambient():
		return
	var node := DeathAnim.new()
	node._anim = unit.anim
	node._flip = unit._flip
	node.position = unit.position
	node.modulate = Color(1.0, 0.8, 0.8) if unit.team == Combatant.Team.ENEMY else Color.WHITE
	node.scale = unit.scale
	unit.get_parent().add_child(node)


func _ready() -> void:
	z_index = -1  # hinter den Lebenden


func _physics_process(frame_delta: float) -> void:
	if Game.phase != Game.Phase.BATTLE:
		queue_free()
		return
	_age += Game.battle_delta(frame_delta)
	if _age >= SECONDS:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var frame_size := Vector2(_anim.get_width() / float(Combatant.ANIM_FRAMES), _anim.get_height())
	var frame := Combatant.DEATH_FRAME + mini(int(_age / SECONDS * 4.0), 3)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_flip, 1.0))
	draw_texture_rect_region(_anim, Rect2(Vector2(-frame_size.x / 2.0, -frame_size.y), frame_size),
			Rect2(Vector2(frame_size.x * frame, 0.0), frame_size))
