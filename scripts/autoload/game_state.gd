extends Node

signal down_converted(yards_to_go: float)
signal down_failed
signal series_advanced(downs_per_series: int)
signal stats_changed
signal yards_updated
signal ability_unlocked(key: String, level: int)
signal upgrade_picked(key: String, kind: String, level: int)

const FIELD_LEFT := -220.0
const FIELD_RIGHT := 220.0
const YARD_PX := 20.0
const BASE_YARDS_TO_GO := 10.0
const YARDS_TO_GO_GROWTH := 1.5
const YARDS_TO_GO_STEP_INCREASE := 1.0
const SERIES_UPGRADE_EVERY := 3
const STARTING_DOWNS_PER_SERIES := 4

var selected_team: Dictionary = {}
var stats: Dictionary = {}
var abilities: Dictionary = {}
var stat_pick_counts: Dictionary = {}

var current_down: int = 1
var downs_per_series: int = STARTING_DOWNS_PER_SERIES
var series_count: int = 1
var run_start_y: float = 0.0
var scrimmage_y: float = 0.0
var yards_to_go: float = BASE_YARDS_TO_GO
var yards_to_go_step: float = YARDS_TO_GO_GROWTH
var yards_gained_this_down: float = 0.0
var total_yards: float = 0.0
var conversions: int = 0
var run_active: bool = false

func start_run(team: Dictionary) -> void:
	selected_team = team
	stats = team.get("base_stats", {}).duplicate()
	abilities = {}
	stat_pick_counts = {}
	current_down = 1
	downs_per_series = STARTING_DOWNS_PER_SERIES
	series_count = 1
	run_start_y = 0.0
	scrimmage_y = 0.0
	yards_to_go = BASE_YARDS_TO_GO
	yards_to_go_step = YARDS_TO_GO_GROWTH
	yards_gained_this_down = 0.0
	total_yards = 0.0
	conversions = 0
	run_active = true
	stats_changed.emit()

func update_position(player_y: float) -> void:
	if not run_active:
		return
	yards_gained_this_down = max((scrimmage_y - player_y) / YARD_PX, 0.0)
	total_yards = max((run_start_y - player_y) / YARD_PX, 0.0)
	yards_updated.emit()
	if yards_gained_this_down >= yards_to_go:
		_convert_down(player_y)

func _convert_down(new_scrimmage_y: float) -> void:
	conversions += 1
	current_down = 1
	scrimmage_y = new_scrimmage_y
	yards_gained_this_down = 0.0
	yards_to_go += yards_to_go_step
	if conversions % SERIES_UPGRADE_EVERY == 0:
		series_count += 1
		downs_per_series += 1
		yards_to_go_step += YARDS_TO_GO_STEP_INCREASE
		series_advanced.emit(downs_per_series)
	down_converted.emit(yards_to_go)

func fail_down() -> void:
	if not run_active:
		return
	current_down += 1
	if current_down > downs_per_series:
		run_active = false
		down_failed.emit()

func apply_upgrade(stat_key: String, amount: float) -> void:
	stats[stat_key] = stats.get(stat_key, 0.0) + amount
	stat_pick_counts[stat_key] = stat_pick_counts.get(stat_key, 0) + 1
	stats_changed.emit()
	upgrade_picked.emit(stat_key, "stat", stat_pick_counts[stat_key])

func apply_ability(key: String) -> void:
	abilities[key] = abilities.get(key, 0) + 1
	ability_unlocked.emit(key, abilities[key])
	upgrade_picked.emit(key, "ability", abilities[key])

func get_down_ordinal() -> String:
	match current_down:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
		_: return str(current_down) + "th"

func yards_remaining() -> float:
	return max(yards_to_go - yards_gained_this_down, 0.0)

func marker_world_y() -> float:
	return scrimmage_y - yards_to_go * YARD_PX
