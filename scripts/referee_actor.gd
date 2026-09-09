extends Node2D
class_name RefereeActor

enum Mode { SIDELINE, FIELD_WANDER }

const MOVE_SPEED := 200.0

@onready var body_sprite: Sprite2D = $Body

var mode: Mode = Mode.FIELD_WANDER
var target: Node2D

# Sideline mode: x is fixed, y chases the current down-line marker position.
# Never reads the player's position at all, so player movement in any
# direction (including side to side) has zero direct effect on this ref.
var sideline_x: float = 0.0
var facing_locked: bool = false
var locked_flip_h: bool = false

# Field-wander mode: wanders around a fixed anchor point that is NOT updated
# every frame from the player's position. The anchor only jumps forward when
# the player has advanced downfield past a threshold, so left/right player
# movement never touches this ref either.
var anchor_position: Vector2 = Vector2.ZERO
var catchup_distance: float = 300.0
var behind_offset: float = 70.0
var wander_x_range := Vector2(-90.0, 90.0)
var wander_y_range := Vector2(-20.0, 40.0)
var wander_interval_range := Vector2(1.5, 3.0)

var _wander_timer: float = 0.0
var _current_wander_target: Vector2 = Vector2.ZERO
var _last_anchor_player_y: float = 0.0

func _process(delta: float) -> void:
	if mode == Mode.SIDELINE:
		_process_sideline(delta)
	else:
		_process_field_wander(delta)

func _process_sideline(delta: float) -> void:
	var desired := Vector2(sideline_x, GameState.marker_world_y())
	global_position = global_position.move_toward(desired, MOVE_SPEED * delta)
	if facing_locked:
		body_sprite.flip_h = locked_flip_h

func _process_field_wander(delta: float) -> void:
	if target and target.global_position.y < _last_anchor_player_y - catchup_distance:
		_last_anchor_player_y = target.global_position.y
		anchor_position = Vector2(anchor_position.x, target.global_position.y + behind_offset)
		_pick_new_wander_target()
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_new_wander_target()
	var prev_x := global_position.x
	global_position = global_position.move_toward(_current_wander_target, MOVE_SPEED * delta)
	var dx := global_position.x - prev_x
	if dx < -0.05:
		body_sprite.flip_h = true
	elif dx > 0.05:
		body_sprite.flip_h = false

func _pick_new_wander_target() -> void:
	var offset_x := randf_range(wander_x_range.x, wander_x_range.y)
	var desired_x: float = clamp(anchor_position.x + offset_x, GameState.FIELD_LEFT + 20.0, GameState.FIELD_RIGHT - 20.0)
	var offset_y := randf_range(wander_y_range.x, wander_y_range.y)
	_current_wander_target = Vector2(desired_x, anchor_position.y + offset_y)
	_wander_timer = randf_range(wander_interval_range.x, wander_interval_range.y)
