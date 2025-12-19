extends Node
class_name AIController

## Simple heuristic-based AI for deploying units

@export var energy_system: EnergySystem
@export var deployment_cooldown: float = 3.0  # Seconds between deployments
@export var unit_scenes: Array[PackedScene] = []

var time_since_last_deployment: float = 0.0
var deployment_positions: Array[Vector2] = []

func _ready() -> void:
	# Wait a bit before starting AI
	await get_tree().create_timer(2.0).timeout

func _process(delta: float) -> void:
	time_since_last_deployment += delta

	if time_since_last_deployment >= deployment_cooldown:
		attempt_deployment()

func set_deployment_positions(positions: Array[Vector2]) -> void:
	deployment_positions = positions

func attempt_deployment() -> void:
	if not energy_system or unit_scenes.is_empty() or deployment_positions.is_empty():
		return

	# Simple heuristic: try to deploy any affordable unit
	for unit_scene in unit_scenes:
		# Get a sample unit to check cost (we'll instance it if we can afford)
		var temp_unit = unit_scene.instantiate()
		var cost = temp_unit.energy_cost if "energy_cost" in temp_unit else 2.0

		if energy_system.can_afford(cost):
			# Pick a random lane
			var random_pos = deployment_positions[randi() % deployment_positions.size()]

			if energy_system.spend_energy(cost):
				# Deploy the unit
				var unit = unit_scene.instantiate()
				unit.team = 1  # Enemy team
				unit.global_position = random_pos
				get_tree().current_scene.add_child(unit)

				time_since_last_deployment = 0.0
				temp_unit.queue_free()
				return

		temp_unit.queue_free()
