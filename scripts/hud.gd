extends CanvasLayer

const DISPLAY_NAMES := {
	"speed": "SPD",
	"power": "PWR",
	"agility": "AGI",
	"awareness": "AWR",
	"hurdle": "HURDLE",
	"lineman": "O-LINE",
	"spin": "SPIN",
	"sprint": "SPRINT",
	"attack": "STIFF-ARM",
	"stiff_arm_charges": "STIFF-ARM",
}

const COOLDOWN_KEYS := ["hurdle", "spin", "sprint"]

@onready var down_label: Label = $LeftColumn/Backing/Margin/VBox/DownLabel
@onready var series_label: Label = $LeftColumn/Backing/Margin/VBox/SeriesLabel
@onready var yards_label: Label = $LeftColumn/Backing/Margin/VBox/YardsLabel
@onready var upgrades_grid: GridContainer = $LeftColumn/UpgradesPanel/UpgradesMargin/UpgradesVBox/UpgradesGrid
@onready var speed_label: Label = $RightColumn/RightPanel/RightMargin/RightVBox/SpeedLabel
@onready var power_label: Label = $RightColumn/RightPanel/RightMargin/RightVBox/PowerLabel
@onready var agility_label: Label = $RightColumn/RightPanel/RightMargin/RightVBox/AgilityLabel
@onready var awareness_label: Label = $RightColumn/RightPanel/RightMargin/RightVBox/AwarenessLabel
@onready var cooldowns_vbox: VBoxContainer = $RightColumn/CooldownsPanel/CooldownsMargin/CooldownsVBox

var box_style: StyleBoxFlat = load("res://theme/badge_style.tres")
var upgrade_boxes: Dictionary = {}
var cooldown_bars: Dictionary = {}
var player: Node2D

func _ready() -> void:
	GameState.yards_updated.connect(_refresh)
	GameState.down_converted.connect(func(_v): _refresh())
	GameState.series_advanced.connect(func(_v): _refresh())
	GameState.stats_changed.connect(_refresh_stats)
	GameState.upgrade_picked.connect(_on_upgrade_picked)
	GameState.ability_unlocked.connect(_on_ability_unlocked)
	_refresh()
	_refresh_stats()
	_add_cooldown_row("attack")
	call_deferred("_find_player")

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D

func _process(_delta: float) -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player") as Node2D
		return
	for key in cooldown_bars.keys():
		var data: Dictionary = cooldown_bars[key]
		var fraction: float = 0.0
		if key == "hurdle":
			fraction = player.get_hurdle_cooldown_fraction()
		elif key == "spin":
			fraction = player.get_spin_cooldown_fraction()
		elif key == "sprint":
			fraction = player.get_sprint_cooldown_fraction()
		elif key == "attack":
			fraction = player.get_stiff_arm_recharge_fraction()
			var attack_label: Label = data["label"]
			attack_label.text = "STIFF-ARM x%d" % player.stiff_arm_charges
		var fill: ColorRect = data["fill"]
		var max_width: float = data["max_width"]
		fill.size.x = max_width * fraction

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

func _on_ability_unlocked(key: String, _level: int) -> void:
	if key in COOLDOWN_KEYS and not cooldown_bars.has(key):
		_add_cooldown_row(key)

func _add_cooldown_row(key: String) -> void:
	var label := Label.new()
	label.text = "STIFF-ARM x1" if key == "attack" else DISPLAY_NAMES.get(key, key)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	cooldowns_vbox.add_child(label)

	var bar_root := Control.new()
	bar_root.custom_minimum_size = Vector2(150, 14)
	cooldowns_vbox.add_child(bar_root)

	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", box_style)
	bar_root.add_child(bg)

	var fill := ColorRect.new()
	fill.color = Color(0.95, 0.55, 0.15, 1.0)
	fill.position = Vector2(3, 3)
	fill.size = Vector2(0, 8)
	bar_root.add_child(fill)

	cooldown_bars[key] = {"fill": fill, "max_width": 144.0, "label": label}
