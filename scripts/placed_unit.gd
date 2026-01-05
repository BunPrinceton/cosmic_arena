extends Node3D
class_name PlacedUnit

## A unit that has been placed on the battlefield
## For now, just a static rock. Later can have AI, attacks, etc.

signal unit_destroyed(unit: PlacedUnit)

var unit_data: UnitData
var current_health: float = 0.0
var team: int = 0  # 0 = player, 1 = enemy
var model: Node3D = null

func _ready() -> void:
	pass

func setup(data: UnitData, spawn_pos: Vector3, unit_team: int = 0) -> void:
	unit_data = data
	team = unit_team
	current_health = data.max_health
	global_position = spawn_pos

	# Load and add the model
	if data.model_scene_path != "":
		var model_scene = load(data.model_scene_path)
		if model_scene:
			model = model_scene.instantiate()
			add_child(model)
			return

	# Fallback: create a simple colored box
	_create_fallback_model()

func _create_fallback_model() -> void:
	var mesh_instance = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(
		unit_data.grid_size.x * 2.0,
		1.5,
		unit_data.grid_size.y * 2.0
	)
	mesh_instance.mesh = box
	mesh_instance.position.y = box.size.y / 2.0

	var material = StandardMaterial3D.new()
	material.albedo_color = unit_data.visual_color
	mesh_instance.material_override = material

	add_child(mesh_instance)
	model = mesh_instance

func take_damage(amount: float) -> void:
	current_health -= amount
	if current_health <= 0:
		_die()

func _die() -> void:
	unit_destroyed.emit(self)
	queue_free()

func get_grid_size() -> Vector2i:
	if unit_data:
		return unit_data.grid_size
	return Vector2i(1, 1)
