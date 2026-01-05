extends Node3D
class_name PlacementGrid

## Visualizes the placement grid during unit deployment
## Shows blue for placeable, red for blocked, green for unit footprint

# Grid settings
const CELL_SIZE: float = 2.0  # Size of each grid cell in world units
const GRID_HEIGHT: float = 0.05  # Height above ground

# Grid bounds (matches 60x100 battlefield)
var grid_min: Vector3 = Vector3(-30, 0, -50)
var grid_max: Vector3 = Vector3(30, 0, 50)

# Playable zone (player's half of the field for now)
var playable_z_min: float = 0.0  # Player can only place on their half
var playable_z_max: float = 50.0

# Colors
const COLOR_PLACEABLE: Color = Color(0.2, 0.5, 0.9, 0.3)  # Light blue
const COLOR_BLOCKED: Color = Color(0.9, 0.2, 0.2, 0.4)  # Red
const COLOR_UNIT_VALID: Color = Color(0.2, 0.9, 0.3, 0.5)  # Bright green
const COLOR_UNIT_INVALID: Color = Color(0.9, 0.2, 0.2, 0.6)  # Brighter red

# Grid line materials
var placeable_material: StandardMaterial3D
var blocked_material: StandardMaterial3D
var unit_valid_material: StandardMaterial3D
var unit_invalid_material: StandardMaterial3D

# Grid meshes
var grid_lines_mesh: MeshInstance3D
var blocked_cells_mesh: MeshInstance3D
var unit_footprint_mesh: MeshInstance3D

# Current state
var is_visible: bool = false
var current_unit_grid_size: Vector2i = Vector2i(1, 1)
var current_unit_position: Vector3 = Vector3.ZERO
var blocked_positions: Array[Vector2i] = []  # Dynamic blocked cells (units)
var static_blocked_positions: Array[Vector2i] = []  # Static blocked cells (obstacles)

func _ready() -> void:
	_create_materials()
	_create_grid_meshes()
	hide_grid()

func _create_materials() -> void:
	placeable_material = StandardMaterial3D.new()
	placeable_material.albedo_color = COLOR_PLACEABLE
	placeable_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	placeable_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	placeable_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	blocked_material = StandardMaterial3D.new()
	blocked_material.albedo_color = COLOR_BLOCKED
	blocked_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blocked_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blocked_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	unit_valid_material = StandardMaterial3D.new()
	unit_valid_material.albedo_color = COLOR_UNIT_VALID
	unit_valid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	unit_valid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	unit_valid_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	unit_invalid_material = StandardMaterial3D.new()
	unit_invalid_material.albedo_color = COLOR_UNIT_INVALID
	unit_invalid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	unit_invalid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	unit_invalid_material.cull_mode = BaseMaterial3D.CULL_DISABLED

func _create_grid_meshes() -> void:
	# Grid lines mesh (blue lines for placeable area)
	grid_lines_mesh = MeshInstance3D.new()
	grid_lines_mesh.material_override = placeable_material
	add_child(grid_lines_mesh)

	# Blocked cells mesh (red quads for non-placeable area)
	blocked_cells_mesh = MeshInstance3D.new()
	blocked_cells_mesh.material_override = blocked_material
	add_child(blocked_cells_mesh)

	# Unit footprint mesh (green/red quads under dragged unit)
	unit_footprint_mesh = MeshInstance3D.new()
	add_child(unit_footprint_mesh)

func show_grid(unit_grid_size: Vector2i = Vector2i(1, 1)) -> void:
	current_unit_grid_size = unit_grid_size
	is_visible = true
	visible = true

	# Clear dynamic blocked positions (units move, so don't keep old positions)
	# Static blocked positions (obstacles) are kept
	blocked_positions.clear()

	_rebuild_grid_mesh()
	_rebuild_blocked_mesh()

func hide_grid() -> void:
	is_visible = false
	visible = false

func update_unit_position(world_pos: Vector3, is_valid: bool) -> void:
	current_unit_position = world_pos
	_rebuild_unit_footprint_mesh(is_valid)

func _rebuild_grid_mesh() -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)

	var y = GRID_HEIGHT

	# Calculate grid dimensions
	var x_start = grid_min.x
	var x_end = grid_max.x
	var z_start = playable_z_min
	var z_end = playable_z_max

	# Vertical lines (along Z axis)
	var x = x_start
	while x <= x_end:
		st.add_vertex(Vector3(x, y, z_start))
		st.add_vertex(Vector3(x, y, z_end))
		x += CELL_SIZE

	# Horizontal lines (along X axis)
	var z = z_start
	while z <= z_end:
		st.add_vertex(Vector3(x_start, y, z))
		st.add_vertex(Vector3(x_end, y, z))
		z += CELL_SIZE

	grid_lines_mesh.mesh = st.commit()

func _rebuild_blocked_mesh() -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var y = GRID_HEIGHT + 0.01

	# Enemy half of field is blocked
	_add_quad(st, grid_min.x, grid_max.x, grid_min.z, 0.0, y)

	# Add static blocked cells (obstacles)
	for cell in static_blocked_positions:
		var x = grid_min.x + cell.x * CELL_SIZE
		var z = grid_min.z + cell.y * CELL_SIZE
		_add_quad(st, x, x + CELL_SIZE, z, z + CELL_SIZE, y)

	# Add dynamic blocked cells (units)
	for cell in blocked_positions:
		var x = grid_min.x + cell.x * CELL_SIZE
		var z = grid_min.z + cell.y * CELL_SIZE
		_add_quad(st, x, x + CELL_SIZE, z, z + CELL_SIZE, y)

	blocked_cells_mesh.mesh = st.commit()

func _rebuild_unit_footprint_mesh(is_valid: bool) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var y = GRID_HEIGHT + 0.02

	# Snap position to grid
	var grid_pos = world_to_grid(current_unit_position)
	var snapped_pos = grid_to_world(grid_pos)

	# Draw footprint cells
	for dx in range(current_unit_grid_size.x):
		for dz in range(current_unit_grid_size.y):
			var cell_x = snapped_pos.x + dx * CELL_SIZE - (current_unit_grid_size.x * CELL_SIZE / 2.0) + CELL_SIZE / 2.0
			var cell_z = snapped_pos.z + dz * CELL_SIZE - (current_unit_grid_size.y * CELL_SIZE / 2.0) + CELL_SIZE / 2.0
			_add_quad(st, cell_x - CELL_SIZE / 2.0, cell_x + CELL_SIZE / 2.0,
					cell_z - CELL_SIZE / 2.0, cell_z + CELL_SIZE / 2.0, y)

	unit_footprint_mesh.mesh = st.commit()
	unit_footprint_mesh.material_override = unit_valid_material if is_valid else unit_invalid_material

func _add_quad(st: SurfaceTool, x1: float, x2: float, z1: float, z2: float, y: float) -> void:
	# First triangle
	st.add_vertex(Vector3(x1, y, z1))
	st.add_vertex(Vector3(x2, y, z1))
	st.add_vertex(Vector3(x2, y, z2))
	# Second triangle
	st.add_vertex(Vector3(x1, y, z1))
	st.add_vertex(Vector3(x2, y, z2))
	st.add_vertex(Vector3(x1, y, z2))

## Convert world position to grid cell
func world_to_grid(world_pos: Vector3) -> Vector2i:
	var gx = int(floor((world_pos.x - grid_min.x) / CELL_SIZE))
	var gz = int(floor((world_pos.z - grid_min.z) / CELL_SIZE))
	return Vector2i(gx, gz)

## Convert grid cell to world position (center of cell)
func grid_to_world(grid_pos: Vector2i) -> Vector3:
	var x = grid_min.x + (grid_pos.x + 0.5) * CELL_SIZE
	var z = grid_min.z + (grid_pos.y + 0.5) * CELL_SIZE
	return Vector3(x, 0, z)

## Check if a world position is valid for placement
func is_position_valid(world_pos: Vector3, grid_size: Vector2i) -> bool:
	var grid_pos = world_to_grid(world_pos)

	# Check each cell the unit would occupy
	for dx in range(grid_size.x):
		for dz in range(grid_size.y):
			var check_x = grid_pos.x + dx - grid_size.x / 2
			var check_z = grid_pos.y + dz - grid_size.y / 2

			# Check bounds
			var world_x = grid_min.x + check_x * CELL_SIZE
			var world_z = grid_min.z + check_z * CELL_SIZE

			if world_x < grid_min.x or world_x >= grid_max.x:
				return false
			if world_z < playable_z_min or world_z >= playable_z_max:
				return false

			# Check static blocked cells (obstacles)
			var cell_to_check = Vector2i(check_x, check_z)
			if cell_to_check in static_blocked_positions:
				return false

			# Check dynamic blocked cells (units)
			if cell_to_check in blocked_positions:
				return false

	return true

## Get snapped world position for placement
func get_snapped_position(world_pos: Vector3) -> Vector3:
	var grid_pos = world_to_grid(world_pos)
	return grid_to_world(grid_pos)

## Add a blocked cell (e.g., for existing units)
func add_blocked_cell(grid_pos: Vector2i) -> void:
	if grid_pos not in blocked_positions:
		blocked_positions.append(grid_pos)
		if is_visible:
			_rebuild_blocked_mesh()

## Remove a blocked cell
func remove_blocked_cell(grid_pos: Vector2i) -> void:
	blocked_positions.erase(grid_pos)
	if is_visible:
		_rebuild_blocked_mesh()

## Clear all blocked cells
func clear_blocked_cells() -> void:
	blocked_positions.clear()
	if is_visible:
		_rebuild_blocked_mesh()

## Add a static blocked cell (e.g., for obstacles that never move)
func add_static_blocked_cell(grid_pos: Vector2i) -> void:
	if grid_pos not in static_blocked_positions:
		static_blocked_positions.append(grid_pos)
		if is_visible:
			_rebuild_blocked_mesh()

## Remove a static blocked cell
func remove_static_blocked_cell(grid_pos: Vector2i) -> void:
	static_blocked_positions.erase(grid_pos)
	if is_visible:
		_rebuild_blocked_mesh()

## Clear all static blocked cells
func clear_static_blocked_cells() -> void:
	static_blocked_positions.clear()
	if is_visible:
		_rebuild_blocked_mesh()
