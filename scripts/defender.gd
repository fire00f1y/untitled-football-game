extends CharacterBody2D
class_name Defender

@onready var tackle_area: Area2D = $TackleArea
@onready var body_sprite: Sprite2D = $Body

var hp: float = 2.0
var move_speed: float = 70.0
var knockback_velocity := Vector2.ZERO
var staggered_time := 0.0

func setup(hp_value: float, speed_value: float) -> void:
	hp = hp_value
	move_speed = speed_value

func _ready() -> void:
	add_to_group("defenders")
	tackle_area.body_entered.connect(_on_tackle_area_body_entered)

func _physics_process(delta: float) -> void:
	if staggered_time > 0.0:
		staggered_time -= delta
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	else:
		var target := get_tree().get_first_node_in_group("player") as Node2D
		if target:
			var dir := (target.global_position - global_position).normalized()
			velocity = dir * move_speed
			if dir.x < -0.1:
				body_sprite.flip_h = true
			elif dir.x > 0.1:
				body_sprite.flip_h = false
		else:
			velocity = Vector2.ZERO
	move_and_slide()

func stiff_arm(power: float, from_pos: Vector2) -> void:
	hp -= power
	var dir := (global_position - from_pos)
	if dir.length_squared() < 0.01:
		dir = Vector2.DOWN
	dir = dir.normalized()
	knockback_velocity = dir * 280.0
	staggered_time = 0.35
	if hp <= 0.0:
		queue_free()

func _on_tackle_area_body_entered(body: Node) -> void:
	if staggered_time > 0.0:
		return
	if not body.is_in_group("player"):
		return
	var power: float = GameState.stats.get("power", 5.0)
	var agility: float = GameState.stats.get("agility", 5.0)
	var break_chance: float = clamp(0.08 + power * 0.02 + agility * 0.025, 0.0, 0.85)
	if randf() < break_chance:
		knockback_velocity = (global_position - body.global_position).normalized() * 320.0
		staggered_time = 0.4
	else:
		if body.has_method("try_hurdle") and body.try_hurdle():
			knockback_velocity = (global_position - body.global_position).normalized() * 200.0
			staggered_time = 0.5
			return
		if body.has_method("on_tackled"):
			body.on_tackled()
		queue_free()
