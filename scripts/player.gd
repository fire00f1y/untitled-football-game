extends CharacterBody2D

const BASE_ATTACK_COOLDOWN := 0.65
const MIN_ATTACK_COOLDOWN := 0.25
const BASE_ATTACK_RADIUS := 46.0
const HURDLE_COOLDOWN := 2.5
const SPIN_RADIUS := 90.0

@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape
@onready var attack_timer: Timer = $AttackTimer
@onready var spin_timer: Timer = $SpinTimer
@onready var body_sprite: Sprite2D = $Body

var invulnerable := false
var hurdle_ready_at: float = 0.0
var spin_speed_boost_until: float = 0.0

func _ready() -> void:
	add_to_group("player")
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	spin_timer.timeout.connect(_on_spin_timer_timeout)
	GameState.stats_changed.connect(_on_stats_changed)
	GameState.ability_unlocked.connect(_on_ability_unlocked)
	body_sprite.modulate = Color(0.93, 0.92, 0.88)
	_on_stats_changed()
	_update_spin_timer()

func _physics_process(_delta: float) -> void:
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input_dir.length_squared() > 1.0:
		input_dir = input_dir.normalized()
	if input_dir.x < -0.1:
		body_sprite.flip_h = true
	elif input_dir.x > 0.1:
		body_sprite.flip_h = false
	var speed: float = GameState.stats.get("speed", 100.0)
	if _now() < spin_speed_boost_until:
		speed *= 1.5
	velocity = input_dir * speed
	move_and_slide()
	global_position.x = clamp(global_position.x, GameState.FIELD_LEFT, GameState.FIELD_RIGHT)
	GameState.update_position(global_position.y)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _on_stats_changed() -> void:
	var awareness: float = GameState.stats.get("awareness", 55.0)
	var agility: float = GameState.stats.get("agility", 5.0)
	var radius: float = BASE_ATTACK_RADIUS + awareness * 0.4
	if attack_shape.shape is CircleShape2D:
		(attack_shape.shape as CircleShape2D).radius = radius
	attack_timer.wait_time = max(BASE_ATTACK_COOLDOWN - agility * 0.02, MIN_ATTACK_COOLDOWN)

func _on_ability_unlocked(key: String, _level: int) -> void:
	if key == "spin":
		_update_spin_timer()

func _update_spin_timer() -> void:
	var level: int = GameState.abilities.get("spin", 0)
	if level <= 0:
		spin_timer.stop()
		return
	spin_timer.wait_time = max(4.0 - (level - 1) * 0.8, 1.5)
	if spin_timer.is_stopped():
		spin_timer.start()

func _on_attack_timer_timeout() -> void:
	var power: float = GameState.stats.get("power", 5.0)
	for body in attack_area.get_overlapping_bodies():
		if body.has_method("stiff_arm"):
			body.stiff_arm(power, global_position)

func _on_spin_timer_timeout() -> void:
	var power: float = GameState.stats.get("power", 5.0) * 1.5
	for body in get_tree().get_nodes_in_group("defenders"):
		if body is Node2D and global_position.distance_to(body.global_position) <= SPIN_RADIUS:
			if body.has_method("stiff_arm"):
				body.stiff_arm(power, global_position)
	spin_speed_boost_until = _now() + 1.0
	_play_spin_visual()

func _play_spin_visual() -> void:
	var tween := create_tween()
	tween.tween_property(body_sprite, "rotation", body_sprite.rotation + TAU, 0.35)

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
