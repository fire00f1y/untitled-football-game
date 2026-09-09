extends CanvasLayer

const UPGRADES := [
	{"type": "stat", "key": "speed", "label": "Speed +", "amount": 12.0, "desc": "Move faster to outrun defenders."},
	{"type": "stat", "key": "power", "label": "Power +", "amount": 2.0, "desc": "Stronger stiff-arm, easier tackle breaks."},
	{"type": "stat", "key": "agility", "label": "Agility +", "amount": 2.0, "desc": "Faster stiff-arm, better tackle breaks."},
	{"type": "stat", "key": "awareness", "label": "Awareness +", "amount": 15.0, "desc": "Bigger stiff-arm range."},
	{"type": "ability", "key": "hurdle", "max_level": 5, "label": "Hurdle", "desc": "Automatically hurdle a defender instead of getting tackled. Cooldown shrinks each level."},
	{"type": "ability", "key": "lineman", "max_level": 2, "label": "Offensive Lineman", "desc": "An escort blocker runs with you, flattening any defender that touches him."},
	{"type": "ability", "key": "spin", "max_level": 4, "label": "Spin Move", "desc": "Reactively spin around a defender instead of getting tackled, dropping him to the ground. Cooldown shrinks each level."},
	{"type": "ability", "key": "sprint", "max_level": 4, "label": "Sprint", "desc": "Periodically burst to greater speed for a moment. Cooldown shrinks each level."},
	{"type": "ability", "key": "stiff_arm_charges", "max_level": 3, "label": "Extra Stiff-Arm", "desc": "The stiff-arm can fire again right away before it needs to fully recharge."},
]

@onready var button_container: VBoxContainer = $Panel/CenterContainer/Card/VBox/Buttons
@onready var title_label: Label = $Panel/CenterContainer/Card/VBox/Title

var button_style: StyleBoxTexture = load("res://theme/button_style.tres")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.1))
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	GameState.down_converted.connect(_on_down_converted)

func _on_down_converted(_yards_to_go: float) -> void:
	_show_choices()

func _show_choices() -> void:
	for child in button_container.get_children():
		child.queue_free()
	title_label.text = "First Down! Pick an upgrade"
	var pool: Array = UPGRADES.filter(func(d): return d["type"] != "ability" or GameState.abilities.get(d["key"], 0) < d.get("max_level", 999))
	pool.shuffle()
	for i in range(min(3, pool.size())):
		var data: Dictionary = pool[i]
		var btn := Button.new()
		var label: String = data["label"]
		if data["type"] == "ability":
			var level: int = GameState.abilities.get(data["key"], 0)
			label = "%s%s" % [label, (" (Lv %d -> %d)" % [level, level + 1]) if level > 0 else " (New!)"]
		btn.text = "%s\n%s" % [label, data["desc"]]
		btn.custom_minimum_size = Vector2(320, 84)
		btn.add_theme_stylebox_override("normal", button_style)
		btn.add_theme_stylebox_override("hover", button_style)
		btn.add_theme_stylebox_override("pressed", button_style)
		btn.add_theme_stylebox_override("focus", button_style)
		btn.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
		btn.add_theme_color_override("font_hover_color", Color(0, 0, 0))
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(_on_upgrade_chosen.bind(data))
		button_container.add_child(btn)
	visible = true
	get_tree().paused = true

func _on_upgrade_chosen(data: Dictionary) -> void:
	if data["type"] == "ability":
		GameState.apply_ability(data["key"])
	else:
		GameState.apply_upgrade(data["key"], data["amount"])
	visible = false
	get_tree().paused = false
