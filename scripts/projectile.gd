extends Node3D
class_name Projectile

## A projectile that travels to a target position and deals damage on impact

signal hit_target(position: Vector3)

var target_position: Vector3 = Vector3.ZERO
var speed: float = 10.0
var damage: float = 10.0
var splash_radius: float = 0.0  # 0 = single target, >0 = AoE
var team: int = 0  # 0 = player, 1 = enemy
var source_unit: Node3D = null  # Who fired this projectile

var model: Node3D = null
var has_hit: bool = false

func setup(p_target: Vector3, p_speed: float, p_damage: float, p_splash: float, p_team: int, model_path: String, model_scale: float = 0.3) -> void:
	target_position = p_target
	speed = p_speed
	damage = p_damage
	splash_radius = p_splash
	team = p_team

	# Load and add model
	if model_path != "":
		var model_scene = load(model_path)
		if model_scene:
			model = model_scene.instantiate()
			model.scale = Vector3.ONE * model_scale
			add_child(model)

	# Fallback: create a simple sphere if no model
	if not model:
		var mesh_instance = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.3
		sphere.height = 0.6
		mesh_instance.mesh = sphere

		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.4, 0.2)  # Orange-brown
		mesh_instance.material_override = mat

		add_child(mesh_instance)
		model = mesh_instance

func _physics_process(delta: float) -> void:
	if has_hit:
		return

	# Move toward target
	var direction = (target_position - global_position)
	var distance = direction.length()

	# Check if we've reached the target
	if distance < speed * delta * 1.5:
		_on_hit()
		return

	# Move
	direction = direction.normalized()
	global_position += direction * speed * delta

	# Rotate to face movement direction (optional - looks better for tree projectiles)
	if direction.length() > 0.1:
		look_at(global_position + direction, Vector3.UP)
		# Tilt forward for a more dynamic look
		rotation.x = -PI / 4

func _on_hit() -> void:
	if has_hit:
		return
	has_hit = true

	hit_target.emit(global_position)

	# Deal damage
	if splash_radius > 0:
		_deal_splash_damage()
	else:
		_deal_single_target_damage()

	# Destroy projectile
	queue_free()

func _get_all_damageable_targets() -> Array[Node3D]:
	# Collect all potential targets: units, towers, bases
	var targets: Array[Node3D] = []

	# Get units
	var units_node = get_tree().get_first_node_in_group("placed_units")
	if units_node:
		for unit in units_node.get_children():
			if is_instance_valid(unit):
				targets.append(unit)

	# Get towers (they have "tower" in name and take_damage method)
	for node in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(node):
			targets.append(node)

	# Also search for towers/bases by checking nodes with take_damage
	var root = get_tree().current_scene
	if root:
		_find_damageable_recursive(root, targets)

	return targets

func _find_damageable_recursive(node: Node, targets: Array[Node3D]) -> void:
	if node is Node3D and node.has_method("take_damage") and node.has_method("get_team"):
		if node not in targets:
			targets.append(node)
	for child in node.get_children():
		_find_damageable_recursive(child, targets)

func _deal_splash_damage() -> void:
	var targets = _get_all_damageable_targets()

	for target in targets:
		if not is_instance_valid(target):
			continue
		if target.has_method("get_team") and target.get_team() == team:
			continue  # Don't damage allies
		if target.has_method("is_alive") and not target.is_alive():
			continue  # Skip dead targets

		var dist = global_position.distance_to(target.global_position)
		if dist <= splash_radius:
			if target.has_method("take_damage"):
				var falloff = 1.0 - (dist / splash_radius) * 0.5
				# Pass attacker for vengeance tracking and response
				target.take_damage(damage * falloff, source_unit)
				# Notify target who attacked them so they can respond
				if target.has_method("on_attacked_by") and is_instance_valid(source_unit):
					target.on_attacked_by(source_unit)

func _deal_single_target_damage() -> void:
	var targets = _get_all_damageable_targets()
	var closest_target: Node3D = null
	var closest_dist: float = 3.0  # Max distance to count as "hit"

	for target in targets:
		if not is_instance_valid(target):
			continue
		if target.has_method("get_team") and target.get_team() == team:
			continue  # Don't damage allies
		if target.has_method("is_alive") and not target.is_alive():
			continue  # Skip dead targets

		var dist = global_position.distance_to(target.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_target = target

	if closest_target and closest_target.has_method("take_damage"):
		# Pass attacker for vengeance tracking and response
		closest_target.take_damage(damage, source_unit)
		# Notify target who attacked them so they can respond
		if closest_target.has_method("on_attacked_by") and is_instance_valid(source_unit):
			closest_target.on_attacked_by(source_unit)
