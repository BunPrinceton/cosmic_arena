extends Node3D
class_name UnitGhost

## Gray opaque preview of a unit during placement
## Shows where the unit will be placed and its size

# Ghost appearance
const GHOST_COLOR: Color = Color(0.5, 0.5, 0.5, 0.6)  # Gray, semi-transparent
const INVALID_COLOR: Color = Color(0.8, 0.3, 0.3, 0.6)  # Red tint when invalid

var ghost_mesh: MeshInstance3D
var ghost_material: StandardMaterial3D
var current_model: Node3D = null
var current_unit_data: UnitData = null
var is_valid_position: bool = true

func _ready() -> void:
	_create_ghost_material()
	visible = false

func _create_ghost_material() -> void:
	ghost_material = StandardMaterial3D.new()
	ghost_material.albedo_color = GHOST_COLOR
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED

func show_ghost(unit_data: UnitData) -> void:
	current_unit_data = unit_data
	visible = true

	# Clear any existing model
	if current_model:
		current_model.queue_free()
		current_model = null

	# Try to load the unit's model
	if unit_data.model_scene_path != "":
		var model_scene = load(unit_data.model_scene_path)
		if model_scene:
			current_model = model_scene.instantiate()
			add_child(current_model)
			_apply_ghost_material_recursive(current_model)
			return

	# Fallback: create a simple box based on grid size
	_create_fallback_mesh(unit_data.grid_size)

func _create_fallback_mesh(grid_size: Vector2i) -> void:
	if ghost_mesh:
		ghost_mesh.queue_free()

	ghost_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	# Size based on grid cells (2.0 units per cell)
	box.size = Vector3(grid_size.x * 2.0, 1.5, grid_size.y * 2.0)
	ghost_mesh.mesh = box
	ghost_mesh.material_override = ghost_material
	add_child(ghost_mesh)
	# Raise slightly so it sits on ground
	ghost_mesh.position.y = box.size.y / 2.0

func _apply_ghost_material_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_inst = node as MeshInstance3D
		# Create a unique ghost material for this mesh
		var mat = ghost_material.duplicate() as StandardMaterial3D
		mesh_inst.material_override = mat

	for child in node.get_children():
		_apply_ghost_material_recursive(child)

func hide_ghost() -> void:
	visible = false
	current_unit_data = null

	if current_model:
		current_model.queue_free()
		current_model = null
	if ghost_mesh:
		ghost_mesh.queue_free()
		ghost_mesh = null

func update_position(world_pos: Vector3) -> void:
	global_position = world_pos

func set_valid(valid: bool) -> void:
	is_valid_position = valid
	var color = GHOST_COLOR if valid else INVALID_COLOR

	ghost_material.albedo_color = color

	# Update materials on loaded models too
	if current_model:
		_update_model_color(current_model, color)

func _update_model_color(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mesh_inst = node as MeshInstance3D
		if mesh_inst.material_override and mesh_inst.material_override is StandardMaterial3D:
			(mesh_inst.material_override as StandardMaterial3D).albedo_color = color

	for child in node.get_children():
		_update_model_color(child, color)
