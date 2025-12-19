extends Node2D
class_name Arena

## Main arena/battlefield with lanes and deployment zones

const LANE_POSITIONS = {
	"left": -200.0,
	"center": 0.0,
	"right": 200.0
}

@export var player_deployment_y: float = 500.0
@export var enemy_deployment_y: float = 100.0

func _ready() -> void:
	pass

func get_player_deployment_position(lane: String) -> Vector2:
	if lane in LANE_POSITIONS:
		return Vector2(LANE_POSITIONS[lane], player_deployment_y)
	return Vector2(0, player_deployment_y)

func get_enemy_deployment_position(lane: String) -> Vector2:
	if lane in LANE_POSITIONS:
		return Vector2(LANE_POSITIONS[lane], enemy_deployment_y)
	return Vector2(0, enemy_deployment_y)

func get_random_player_deployment() -> Vector2:
	var lanes = LANE_POSITIONS.keys()
	var random_lane = lanes[randi() % lanes.size()]
	return get_player_deployment_position(random_lane)

func get_random_enemy_deployment() -> Vector2:
	var lanes = LANE_POSITIONS.keys()
	var random_lane = lanes[randi() % lanes.size()]
	return get_enemy_deployment_position(random_lane)
