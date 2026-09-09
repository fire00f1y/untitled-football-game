extends CanvasLayer

@onready var stats_label: Label = $Panel/CenterContainer/Card/VBox/StatsLabel
@onready var restart_button: Button = $Panel/CenterContainer/Card/VBox/RestartButton

var button_style: StyleBoxTexture = load("res://theme/button_style.tres")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	stats_label.add_theme_font_size_override("font_size", 20)
	stats_label.add_theme_color_override("font_color", Color(1, 0.85, 0.1))
	stats_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	stats_label.add_theme_constant_override("shadow_offset_x", 2)
	stats_label.add_theme_constant_override("shadow_offset_y", 2)
	restart_button.custom_minimum_size = Vector2(220, 70)
	restart_button.add_theme_stylebox_override("normal", button_style)
	restart_button.add_theme_stylebox_override("hover", button_style)
	restart_button.add_theme_stylebox_override("pressed", button_style)
	restart_button.add_theme_stylebox_override("focus", button_style)
	restart_button.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
	restart_button.add_theme_color_override("font_hover_color", Color(0, 0, 0))
	restart_button.add_theme_font_size_override("font_size", 18)
	restart_button.pressed.connect(_on_restart_pressed)
	GameState.down_failed.connect(_on_down_failed)

func _on_down_failed() -> void:
	stats_label.text = "Turnover on downs!\nTotal yards: %d\nSeries reached: %d" % [int(GameState.total_yards), GameState.series_count]
	visible = true
	get_tree().paused = true

func _on_restart_pressed() -> void:
	get_tree().paused = false
	visible = false
	get_tree().change_scene_to_file("res://scenes/team_select.tscn")
