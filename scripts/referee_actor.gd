extends Node2D
class_name RefereeActor

const FOLLOW_SPEED := 200.0

@onready var body_sprite: Sprite2D = $Body

var target: Node2D
var follow_offset := Vector2(0, 0)
var _last_x: float = 0.0

func _process(delta: float) -> void:
	if not target:
		return
	var desired: Vector2 = target.global_position + follow_offset
	var prev_x := global_position.x
	global_position = global_position.move_toward(desired, FOLLOW_SPEED * delta)
	var dx := global_position.x - prev_x
	if dx < -0.05:
		body_sprite.flip_h = true
	elif dx > 0.05:
		body_sprite.flip_h = false
