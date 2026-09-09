extends Node2D

const FIELD_LEFT := -240.0
const FIELD_RIGHT := 240.0

var player: Node2D

@onready var marker_left: Sprite2D = $MarkerLeft
@onready var marker_right: Sprite2D = $MarkerRight

func _ready() -> void:
	call_deferred("_find_player")

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D

func _process(_delta: float) -> void:
	if not player:
		player = get_tree().get_first_node_in_group("player") as Node2D
		return
	var marker_y: float = GameState.marker_world_y()
	marker_left.position = Vector2(FIELD_LEFT + 24.0, marker_y)
	marker_right.position = Vector2(FIELD_RIGHT - 24.0, marker_y)
	queue_redraw()

func _draw() -> void:
	if not player:
		return
	var cam_y: float = player.global_position.y
	var view_height: float = 900.0
	var spacing: float = 100.0
	var first_line: float = floor((cam_y - view_height) / spacing) * spacing
	var y: float = first_line
	while y < cam_y + view_height:
		draw_line(Vector2(FIELD_LEFT, y), Vector2(FIELD_RIGHT, y), Color(1, 1, 1, 0.35), 3.0)
		y += spacing
	draw_line(Vector2(FIELD_LEFT, cam_y - view_height), Vector2(FIELD_LEFT, cam_y + view_height), Color(1, 1, 1, 0.85), 5.0)
	draw_line(Vector2(FIELD_RIGHT, cam_y - view_height), Vector2(FIELD_RIGHT, cam_y + view_height), Color(1, 1, 1, 0.85), 5.0)
	var marker_y: float = GameState.marker_world_y()
	draw_line(Vector2(FIELD_LEFT, marker_y), Vector2(FIELD_RIGHT, marker_y), Color(1, 0.85, 0.1, 0.9), 4.0)
