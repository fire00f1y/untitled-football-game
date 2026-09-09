extends Node2D
class_name LinemanAlly

const FOLLOW_SPEED := 320.0

@onready var block_area: Area2D = $BlockArea
@onready var body_sprite: Sprite2D = $Body

var target: Node2D
var follow_offset := Vector2(0, -20)

func _ready() -> void:
	block_area.body_entered.connect(_on_block_area_body_entered)

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

func _on_block_area_body_entered(body: Node) -> void:
	if body.has_method("stiff_arm"):
		body.stiff_arm(9999.0, global_position)
