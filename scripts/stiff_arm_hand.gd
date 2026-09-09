extends Node2D
class_name StiffArmHand

const TRAVEL_TIME := 0.15

@onready var body_sprite: Sprite2D = $Body

func launch(from_pos: Vector2, to_pos: Vector2) -> void:
	global_position = from_pos
	var dir := (to_pos - from_pos)
	if dir.length_squared() > 0.01:
		rotation = dir.angle() + PI / 2.0
	var tween := create_tween()
	tween.tween_property(self, "global_position", to_pos, TRAVEL_TIME)
	tween.parallel().tween_property(body_sprite, "modulate:a", 0.0, TRAVEL_TIME).set_delay(TRAVEL_TIME * 0.4)
	tween.tween_callback(queue_free)
