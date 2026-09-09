extends CanvasLayer

const DISPLAY_NAMES := {
	"speed": "SPD",
	"power": "PWR",
	"agility": "AGI",
	"awareness": "AWR",
	"hurdle": "HURDLE",
	"lineman": "O-LINE",
	"spin": "SPIN",
}

@onready var down_label: Label = $LeftColumn/Backing/Margin/VBox/DownLabel
@onready var series_label: Label = $LeftColumn/Backing/Margin/VBox/SeriesLabel
@onready var yards_label: Label = $LeftColumn/Backing/Margin/VBox/YardsLabel
@onready var upgrades_grid: GridContainer = $LeftColumn/UpgradesPanel/UpgradesMargin/UpgradesVBox/UpgradesGrid
@onready var speed_label: Label = $RightPanel/RightMargin/RightVBox/SpeedLabel
@onready var power_label: Label = $RightPanel/RightMargin/RightVBox/PowerLabel
@onready var agility_label: Label = $RightPanel/RightMargin/RightVBox/AgilityLabel
@onready var awareness_label: Label = $RightPanel/RightMargin/RightVBox/AwarenessLabel

var box_style: StyleBoxFlat = load("res://theme/badge_style.tres")
var upgrade_boxes: Dictionary = {}

func _ready() -> void:
	GameState.yards_updated.connect(_refresh)
	GameState.down_converted.connect(func(_v): _refresh())
	GameState.series_advanced.connect(func(_v): _refresh())
	GameState.stats_changed.connect(_refresh_stats)
	GameState.upgrade_picked.connect(_on_upgrade_picked)
	_refresh()
	_refresh_stats()

func _refresh() -> void:
	down_label.text = "%s & %d" % [GameState.get_down_ordinal(), int(ceil(GameState.yards_remaining()))]
	series_label.text = "Series %d  (%d downs)" % [GameState.series_count, GameState.downs_per_series]
	yards_label.text = "Total yards: %d" % int(GameState.total_yards)

func _refresh_stats() -> void:
	speed_label.text = "Speed: %d" % int(round(GameState.stats.get("speed", 0.0)))
	power_label.text = "Power: %d" % int(round(GameState.stats.get("power", 0.0)))
	agility_label.text = "Agility: %d" % int(round(GameState.stats.get("agility", 0.0)))
	awareness_label.text = "Awareness: %d" % int(round(GameState.stats.get("awareness", 0.0)))

func _on_upgrade_picked(key: String, kind: String, level: int) -> void:
	var display: String = DISPLAY_NAMES.get(key, key)
	var suffix: String = ("x%d" % level) if kind == "stat" else ("Lv%d" % level)
	if upgrade_boxes.has(key):
		var existing_lbl: Label = upgrade_boxes[key]
		existing_lbl.text = "%s\n%s" % [display, suffix]
		return
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", box_style)
	box.custom_minimum_size = Vector2(74, 44)
	var lbl := Label.new()
	lbl.text = "%s\n%s" % [display, suffix]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	box.add_child(lbl)
	upgrades_grid.add_child(box)
	upgrade_boxes[key] = lbl
