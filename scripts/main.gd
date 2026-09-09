extends Node2D

@export var min_spawn_interval := 0.35
@export var max_spawn_interval := 1.4

@onready var spawn_timer: Timer = $SpawnTimer
@onready var defender_container: Node2D = $DefenderContainer
@onready var player: Node2D = $Player
@onready var referee_sideline: RefereeActor = $RefereeSideline
@onready var referee_field: RefereeActor = $RefereeField

var defender_scene: PackedScene = preload("res://scenes/defender.tscn")
var lineman_scene: PackedScene = preload("res://scenes/lineman.tscn")
var lineman_offsets := [Vector2(-40, -20), Vector2(40, -20)]
var elapsed_time: float = 0.0

func _ready() -> void:
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	_schedule_next_spawn()
	GameState.down_failed.connect(_on_down_failed)
	GameState.ability_unlocked.connect(_on_ability_unlocked)
	referee_sideline.mode = RefereeActor.Mode.SIDELINE
	referee_sideline.sideline_x = GameState.FIELD_LEFT - 36.0
	referee_sideline.facing_locked = true
	referee_sideline.locked_flip_h = true
	referee_sideline.global_position = Vector2(referee_sideline.sideline_x, GameState.marker_world_y())

	referee_field.mode = RefereeActor.Mode.FIELD_WANDER
	referee_field.target = player
	referee_field.behind_offset = 70.0
	referee_field.catchup_distance = 300.0
	referee_field.anchor_position = Vector2(0.0, player.global_position.y + referee_field.behind_offset)
	referee_field.global_position = referee_field.anchor_position

func _process(delta: float) -> void:
	if GameState.run_active:
		elapsed_time += delta

func _difficulty() -> float:
	var time_difficulty: float = clamp(elapsed_time / 90.0, 0.0, 1.0)
	var down_difficulty: float = clamp(float(GameState.conversions) / 10.0, 0.0, 1.0)
	return clamp(max(time_difficulty, down_difficulty), 0.0, 1.0)

func _schedule_next_spawn() -> void:
	var difficulty: float = _difficulty()
	var interval: float = lerp(max_spawn_interval, min_spawn_interval, difficulty)
	spawn_timer.wait_time = interval
	spawn_timer.start()

func _on_spawn_timer_timeout() -> void:
	if GameState.run_active and not get_tree().paused:
		var spawn_count: int = 1 + int(GameState.series_count / 2)
		for i in range(spawn_count):
			_spawn_defender()
	_schedule_next_spawn()

func _spawn_defender() -> void:
	var defender: Defender = defender_scene.instantiate()
	var difficulty: float = _difficulty()
	var hp: float = 1.0 + floor(difficulty * 3.0)
	var speed: float = lerp(60.0, 110.0, difficulty)
	defender.setup(hp, speed)
	var side: float = 1.0 if randf() < 0.5 else -1.0
	var offset_x: float = randf_range(60.0, 220.0) * side
	var offset_y: float = randf_range(-260.0, -420.0)
	defender.position = player.global_position + Vector2(offset_x, offset_y)
	defender_container.add_child(defender)

func _on_ability_unlocked(key: String, level: int) -> void:
	if key == "lineman":
		_spawn_lineman(level)

func _spawn_lineman(level: int) -> void:
	if level > lineman_offsets.size():
		return
	var lineman: LinemanAlly = lineman_scene.instantiate()
	lineman.target = player
	lineman.follow_offset = lineman_offsets[level - 1]
	add_child(lineman)

func _on_down_failed() -> void:
	for d in defender_container.get_children():
		d.queue_free()
