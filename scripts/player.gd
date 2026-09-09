extends CharacterBody2D

const BASE_ATTACK_COOLDOWN := 0.65
const MIN_ATTACK_COOLDOWN := 0.25
const BASE_ATTACK_RADIUS := 46.0
const HURDLE_COOLDOWN := 2.5
const SPIN_DODGE_COOLDOWN := 3.0
const CHARGE_RECHARGE_TIME := 3.0

@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape
@onready var attack_timer: Timer = $AttackTimer
@onready var recharge_timer: Timer = $RechargeTimer
@onready var sprint_timer: Timer = $SprintTimer
@onready var body_sprite: Sprite2D = $Body
@onready var football_sprite: Sprite2D = $Football

var hand_scene: PackedScene = preload("res://scenes/stiff_arm_hand.tscn")

var invulnerable := false
var hurdle_ready_at: float = 0.0
var spin_ready_at: float = 0.0
var sprint_speed_boost_until: float = 0.0
var stiff_arm_charges: int = 1
var max_stiff_arm_charges: int = 1

var football_base_position: Vector2
var football_base_rotation: float

func _ready() -> void:
	add_to_group("player")
	sprint_timer.timeout.connect(_on_sprint_timer_timeout)
	recharge_timer.timeout.connect(_on_recharge_timer_timeout)
	GameState.stats_changed.connect(_on_stats_changed)
	GameState.ability_unlocked.connect(_on_ability_unlocked)
	body_sprite.modulate = Color(0.93, 0.92, 0.88)
	football_base_position = football_sprite.position
	football_base_rotation = football_sprite.rotation
	_on_stats_changed()
	_update_sprint_timer()

func _physics_process(_delta: float) -> void:
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input_dir.length_squared() > 1.0:
		input_dir = input_dir.normalized()
	if input_dir.x < -0.1:
		body_sprite.flip_h = true
		football_sprite.flip_h = true
		football_sprite.position.x = -football_base_position.x
		football_sprite.rotation = -football_base_rotation
	elif input_dir.x > 0.1:
		body_sprite.flip_h = false
		football_sprite.flip_h = false
		football_sprite.position.x = football_base_position.x
		football_sprite.rotation = football_base_rotation
	var speed: float = GameState.stats.get("speed", 100.0)
	if _now() < sprint_speed_boost_until:
		speed *= 1.5
	velocity = input_dir * speed
	move_and_slide()
	global_position.x = clamp(global_position.x, GameState.FIELD_LEFT, GameState.FIELD_RIGHT)
	GameState.update_position(global_position.y)
	_try_stiff_arm()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _on_stats_changed() -> void:
	var awareness: float = GameState.stats.get("awareness", 55.0)
	var radius: float = BASE_ATTACK_RADIUS + awareness * 0.4
	if attack_shape.shape is CircleShape2D:
		(attack_shape.shape as CircleShape2D).radius = radius

func _base_attack_cooldown() -> float:
	var agility: float = GameState.stats.get("agility", 5.0)
	return max(BASE_ATTACK_COOLDOWN - agility * 0.02, MIN_ATTACK_COOLDOWN)

func _on_ability_unlocked(key: String, level: int) -> void:
	if key == "sprint":
		_update_sprint_timer()
	elif key == "stiff_arm_charges":
		max_stiff_arm_charges = 1 + level
		stiff_arm_charges = min(stiff_arm_charges + 1, max_stiff_arm_charges)
		_start_recharge_if_needed()

func _update_sprint_timer() -> void:
	var level: int = GameState.abilities.get("sprint", 0)
	if level <= 0:
		sprint_timer.stop()
		return
	sprint_timer.wait_time = max(4.0 - (level - 1) * 0.8, 1.5)
	if sprint_timer.is_stopped():
		sprint_timer.start()

func _try_stiff_arm() -> void:
	if not attack_timer.is_stopped():
		return
	if stiff_arm_charges <= 0:
		return
	var power: float = GameState.stats.get("power", 5.0)
	var hit_any := false
	for body in attack_area.get_overlapping_bodies():
		if body.has_method("stiff_arm"):
			body.stiff_arm(power, global_position)
			hit_any = true
			_spawn_hand(body.global_position)
	if hit_any:
		attack_timer.start(_base_attack_cooldown())
		stiff_arm_charges -= 1
		_start_recharge_if_needed()

func _start_recharge_if_needed() -> void:
	if stiff_arm_charges < max_stiff_arm_charges and recharge_timer.is_stopped():
		recharge_timer.start(CHARGE_RECHARGE_TIME)

func _on_recharge_timer_timeout() -> void:
	stiff_arm_charges = min(stiff_arm_charges + 1, max_stiff_arm_charges)
	if stiff_arm_charges < max_stiff_arm_charges:
		recharge_timer.start(CHARGE_RECHARGE_TIME)

func _spawn_hand(target_pos: Vector2) -> void:
	var hand: StiffArmHand = hand_scene.instantiate()
	get_parent().add_child(hand)
	hand.launch(global_position, target_pos)

func _on_sprint_timer_timeout() -> void:
	sprint_speed_boost_until = _now() + 1.0
	_play_sprint_visual()

func _play_sprint_visual() -> void:
	var tween := create_tween()
	tween.tween_property(body_sprite, "scale", Vector2(0.62, 0.42), 0.1)
	tween.tween_property(body_sprite, "scale", Vector2(0.55, 0.55), 0.2)

func get_stiff_arm_recharge_fraction() -> float:
	if recharge_timer.is_stopped() or recharge_timer.wait_time <= 0.0:
		return 0.0
	return clamp(recharge_timer.time_left / recharge_timer.wait_time, 0.0, 1.0)

func get_sprint_cooldown_fraction() -> float:
	if GameState.abilities.get("sprint", 0) <= 0:
		return 0.0
	if sprint_timer.is_stopped() or sprint_timer.wait_time <= 0.0:
		return 0.0
	return clamp(sprint_timer.time_left / sprint_timer.wait_time, 0.0, 1.0)

func get_hurdle_cooldown_fraction() -> float:
	var level: int = GameState.abilities.get("hurdle", 0)
	if level <= 0:
		return 0.0
	var cooldown: float = max(HURDLE_COOLDOWN - (level - 1) * 0.4, 1.0)
	var remaining: float = max(hurdle_ready_at - _now(), 0.0)
	return clamp(remaining / cooldown, 0.0, 1.0)

func get_spin_cooldown_fraction() -> float:
	var level: int = GameState.abilities.get("spin", 0)
	if level <= 0:
		return 0.0
	var cooldown: float = max(SPIN_DODGE_COOLDOWN - (level - 1) * 0.4, 1.0)
	var remaining: float = max(spin_ready_at - _now(), 0.0)
	return clamp(remaining / cooldown, 0.0, 1.0)

func try_hurdle() -> bool:
	var level: int = GameState.abilities.get("hurdle", 0)
	if level <= 0:
		return false
	var now := _now()
	if now < hurdle_ready_at:
		return false
	var cooldown: float = max(HURDLE_COOLDOWN - (level - 1) * 0.4, 1.0)
	hurdle_ready_at = now + cooldown
	_start_invulnerability(0.5)
	_play_hurdle_hop()
	return true

func try_spin() -> bool:
	var level: int = GameState.abilities.get("spin", 0)
	if level <= 0:
		return false
	var now := _now()
	if now < spin_ready_at:
		return false
	var cooldown: float = max(SPIN_DODGE_COOLDOWN - (level - 1) * 0.4, 1.0)
	spin_ready_at = now + cooldown
	_start_invulnerability(0.5)
	_play_spin_visual()
	return true

func _play_spin_visual() -> void:
	var tween := create_tween()
	tween.tween_property(body_sprite, "rotation", body_sprite.rotation + TAU, 0.35)

func _play_hurdle_hop() -> void:
	var tween := create_tween()
	tween.tween_property(body_sprite, "scale", Vector2(0.72, 0.72), 0.15)
	tween.tween_property(body_sprite, "scale", Vector2(0.55, 0.55), 0.2)

func on_tackled() -> void:
	if invulnerable or not GameState.run_active:
		return
	GameState.fail_down()
	_start_invulnerability(1.0)

func _start_invulnerability(duration: float) -> void:
	invulnerable = true
	modulate.a = 0.4
	await get_tree().create_timer(duration).timeout
	invulnerable = false
	modulate.a = 1.0
