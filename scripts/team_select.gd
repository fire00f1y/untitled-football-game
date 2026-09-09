extends Control

@onready var button_container: VBoxContainer = $CenterContainer/VBox/Buttons
@onready var title_label: Label = $CenterContainer/VBox/Title

var button_style: StyleBoxTexture = load("res://theme/button_style.tres")

func _ready() -> void:
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.1))
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	for child in button_container.get_children():
		child.queue_free()
	for team in Teams.LIST:
		var btn := Button.new()
		btn.text = "%s\n%s" % [team["name"], team["blurb"]]
		btn.custom_minimum_size = Vector2(420, 90)
		btn.add_theme_stylebox_override("normal", button_style)
		btn.add_theme_stylebox_override("hover", button_style)
		btn.add_theme_stylebox_override("pressed", button_style)
		btn.add_theme_stylebox_override("focus", button_style)
		btn.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
		btn.add_theme_color_override("font_hover_color", Color(0, 0, 0))
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_on_team_chosen.bind(team))
		button_container.add_child(btn)

func _on_team_chosen(team: Dictionary) -> void:
	GameState.start_run(team)
	get_tree().change_scene_to_file("res://scenes/main.tscn")
