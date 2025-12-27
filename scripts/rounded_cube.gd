extends StaticBody3D
## Procedurally generated rounded cube with smooth collision edges

@export var cube_size: Vector3 = Vector3(4, 3, 4)
@export var corner_radius: float = 0.5
@export var material: StandardMaterial3D

func _ready() -> void:
	# Hide old mesh instance if it exists
	var old_mesh = get_node_or_null("MeshInstance3D")
	if old_mesh:
		old_mesh.visible = false

	# Disable old collision if it exists
	var old_collision = get_node_or_null("CollisionShape3D")
	if old_collision:
		old_collision.disabled = true

	_generate_rounded_cube()

func _generate_rounded_cube() -> void:
	# Create main box mesh (visual center)
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(
		cube_size.x - corner_radius * 2,
		cube_size.y - corner_radius * 2,
		cube_size.z - corner_radius * 2
	)
	mesh_instance.mesh = box_mesh
	if material:
		mesh_instance.material_override = material
	add_child(mesh_instance)

	# Add visual spheres at corners to show roundedness
	_add_corner_spheres()

	# Create rounded collision using multiple capsules at edges
	# This gives smooth sliding around corners

	# Vertical edge capsules (4 corners)
	var corners = [
		Vector3(cube_size.x/2 - corner_radius, 0, cube_size.z/2 - corner_radius),
		Vector3(-cube_size.x/2 + corner_radius, 0, cube_size.z/2 - corner_radius),
		Vector3(cube_size.x/2 - corner_radius, 0, -cube_size.z/2 + corner_radius),
		Vector3(-cube_size.x/2 + corner_radius, 0, -cube_size.z/2 + corner_radius),
	]

	for corner_pos in corners:
		_add_vertical_capsule(corner_pos, cube_size.y)

	# Horizontal edge capsules (top and bottom)
	_add_horizontal_edge_capsules()

	# Center box for main collision
	var center_box = CollisionShape3D.new()
	var center_shape = BoxShape3D.new()
	center_shape.size = Vector3(
		cube_size.x - corner_radius * 2,
		cube_size.y - corner_radius * 2,
		cube_size.z - corner_radius * 2
	)
	center_box.shape = center_shape
	add_child(center_box)

func _add_vertical_capsule(pos: Vector3, height: float) -> void:
	var capsule_col = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = corner_radius
	capsule.height = height - corner_radius * 2
	capsule_col.shape = capsule
	capsule_col.position = pos
	add_child(capsule_col)

func _add_horizontal_edge_capsules() -> void:
	# Top and bottom edges (12 edges total, but we'll use simplified collision)
	# Add capsules along X axis edges
	var y_positions = [cube_size.y/2 - corner_radius, -cube_size.y/2 + corner_radius]

	for y_pos in y_positions:
		# Front and back edges
		for z_offset in [cube_size.z/2 - corner_radius, -cube_size.z/2 + corner_radius]:
			var capsule_col = CollisionShape3D.new()
			var capsule = CapsuleShape3D.new()
			capsule.radius = corner_radius
			capsule.height = cube_size.x - corner_radius * 2
			capsule_col.shape = capsule
			capsule_col.position = Vector3(0, y_pos, z_offset)
			capsule_col.rotation = Vector3(0, 0, PI/2)  # Rotate to horizontal
			add_child(capsule_col)

		# Left and right edges
		for x_offset in [cube_size.x/2 - corner_radius, -cube_size.x/2 + corner_radius]:
			var capsule_col = CollisionShape3D.new()
			var capsule = CapsuleShape3D.new()
			capsule.radius = corner_radius
			capsule.height = cube_size.z - corner_radius * 2
			capsule_col.shape = capsule
			capsule_col.position = Vector3(x_offset, y_pos, 0)
			capsule_col.rotation = Vector3(PI/2, 0, 0)  # Rotate to horizontal
			add_child(capsule_col)

func _add_corner_spheres() -> void:
	# Add small spheres at all 8 corners for visual roundedness
	var half_x = cube_size.x / 2 - corner_radius
	var half_y = cube_size.y / 2 - corner_radius
	var half_z = cube_size.z / 2 - corner_radius

	var corner_positions = [
		Vector3(-half_x, -half_y, -half_z),
		Vector3(-half_x, -half_y, half_z),
		Vector3(-half_x, half_y, -half_z),
		Vector3(-half_x, half_y, half_z),
		Vector3(half_x, -half_y, -half_z),
		Vector3(half_x, -half_y, half_z),
		Vector3(half_x, half_y, -half_z),
		Vector3(half_x, half_y, half_z),
	]

	for pos in corner_positions:
		var sphere_mesh = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = corner_radius
		sphere.height = corner_radius * 2
		sphere_mesh.mesh = sphere
		sphere_mesh.position = pos
		if material:
			sphere_mesh.material_override = material
		add_child(sphere_mesh)
