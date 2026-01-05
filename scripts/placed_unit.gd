extends CharacterBody3D
class_name PlacedUnit

## A unit that has been placed on the battlefield
## Has AI for movement, targeting, and combat
## Uses CharacterBody3D for collision-based movement

signal unit_destroyed(unit: PlacedUnit)
signal unit_attacking(unit: PlacedUnit, target: Node3D)

var unit_data: UnitData
var current_health: float = 0.0
var team: int = 0  # 0 = player, 1 = enemy
var model: Node3D = null

# AI component
var unit_ai: UnitAI = null

# Combat
var attack_cooldown_timer: float = 0.0
var is_attacking: bool = false

# Collision
var collision_shape: CollisionShape3D = null

# Soft collision (jello effect)
var soft_collision_area: Area3D = null
var push_strength: float = 1.0  # Scales with unit size

# HP Bar
var hp_bar_container: Node3D = null
var hp_chunks: Array[MeshInstance3D] = []
var hp_bar_background: MeshInstance3D = null

func _ready() -> void:
	# Units are children of the PlacedUnits container (which is in placed_units group)
	# Don't add individual units to the group - it confuses get_first_node_in_group
	pass

func setup(data: UnitData, spawn_pos: Vector3, unit_team: int = 0) -> void:
	unit_data = data
	team = unit_team
	current_health = data.max_health
	global_position = spawn_pos

	# Create collision shape for this unit
	_create_collision_shape()

	# Load and add the model
	if data.model_scene_path != "":
		var model_scene = load(data.model_scene_path)
		if model_scene:
			model = model_scene.instantiate()
			add_child(model)
	else:
		# Fallback: create a simple colored box
		_create_fallback_model()

	# Create HP bar
	_create_hp_bar()

	# Setup AI
	_setup_ai()

func _create_collision_shape() -> void:
	var unit_size = max(unit_data.grid_size.x, unit_data.grid_size.y)

	# Hard collision shape (only for obstacles, not player/units)
	collision_shape = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	# Smaller collision radius - units don't hard-block much
	shape.radius = unit_size * 0.3  # Reduced from 0.8
	shape.height = 1.5
	collision_shape.shape = shape
	collision_shape.position.y = 0.75
	add_child(collision_shape)

	# Set collision layers (bit flags: layer N = 2^(N-1)):
	# Layer 1 (value 1) = Ground/Obstacles/Static environment
	# Layer 2 (value 2) = Player/Commander
	# Layer 3 (value 4) = Units
	# Units collide with ground/obstacles (layer 1) but NOT player (layer 2) or other units
	collision_layer = 4  # Units are on layer 3 (value 4)
	collision_mask = 1   # Only collide with ground/obstacles (layer 1)

	# Create soft collision area for "jello" effect
	_create_soft_collision_area(unit_size)

func _create_soft_collision_area(unit_size: float) -> void:
	soft_collision_area = Area3D.new()
	soft_collision_area.name = "SoftCollisionArea"

	var area_shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	# Soft collision radius is larger than hard collision
	sphere.radius = unit_size * 1.2
	area_shape.shape = sphere
	area_shape.position.y = 1.0

	soft_collision_area.add_child(area_shape)
	add_child(soft_collision_area)

	# Area monitors player and other units for soft collision
	soft_collision_area.collision_layer = 0  # Area doesn't occupy a layer
	soft_collision_area.collision_mask = 2 | 4  # Detect player (layer 2 = value 2) and units (layer 3 = value 4)
	soft_collision_area.monitoring = true

	# Calculate push strength based on unit size (small units = weak push)
	# grid_size 1 = very weak (0.2), grid_size 4 = strong (2.0)
	push_strength = unit_size * 0.5

func _setup_ai() -> void:
	unit_ai = UnitAI.new()
	add_child(unit_ai)

	# Configure AI based on unit data
	var move_speed = unit_data.move_speed / 50.0  # Convert from 2D speed to 3D (rough scaling)
	if move_speed < 0.5:
		move_speed = 0.5  # Minimum speed for rocks

	unit_ai.setup(
		team,
		move_speed,
		unit_data.attack_range / 10.0,  # Scale attack range
		self
	)

	# Connect signals
	unit_ai.target_acquired.connect(_on_target_acquired)
	unit_ai.target_lost.connect(_on_target_lost)

func _create_hp_bar() -> void:
	var unit_size = max(unit_data.grid_size.x, unit_data.grid_size.y)

	# Scale HP bar based on unit size
	var bar_width = 1.0 + (unit_size - 1) * 0.5  # 1.0 for small, 1.5 for large, 2.0 for huge
	var bar_height = unit_size * 1.5 + 1.0  # Height above unit
	var chunk_height = 0.15
	var chunk_gap = 0.02

	# Determine chunk count based on HP (roughly 1 chunk per 25 HP for small, scales up)
	var hp_per_chunk = 25.0 + (unit_size - 1) * 15.0  # 25 for small, 40 for medium, 55 for large
	var chunk_count = int(ceil(unit_data.max_health / hp_per_chunk))
	chunk_count = clamp(chunk_count, 2, 12)  # Min 2, max 12 chunks

	# Container for HP bar
	hp_bar_container = Node3D.new()
	hp_bar_container.name = "HPBarContainer"
	hp_bar_container.position.y = bar_height
	add_child(hp_bar_container)

	# Calculate chunk dimensions
	var chunk_width = (bar_width - (chunk_count - 1) * chunk_gap) / chunk_count
	var start_x = -bar_width / 2.0 + chunk_width / 2.0

	# Create background
	hp_bar_background = MeshInstance3D.new()
	var bg_mesh = BoxMesh.new()
	bg_mesh.size = Vector3(bar_width + 0.05, chunk_height + 0.05, 0.03)
	hp_bar_background.mesh = bg_mesh
	hp_bar_background.position.z = 0.02

	var bg_material = StandardMaterial3D.new()
	bg_material.albedo_color = Color(0.1, 0.1, 0.1, 0.8)
	bg_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hp_bar_background.material_override = bg_material
	hp_bar_container.add_child(hp_bar_background)

	# Create chunks
	hp_chunks.clear()
	for i in range(chunk_count):
		var chunk = MeshInstance3D.new()
		var chunk_mesh = BoxMesh.new()
		chunk_mesh.size = Vector3(chunk_width, chunk_height, 0.05)
		chunk.mesh = chunk_mesh
		chunk.position.x = start_x + i * (chunk_width + chunk_gap)

		var chunk_material = StandardMaterial3D.new()
		chunk_material.albedo_color = Color(0.2, 0.9, 0.2)  # Start green
		chunk_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		chunk.material_override = chunk_material

		hp_bar_container.add_child(chunk)
		hp_chunks.append(chunk)

	_update_hp_bar()

func _update_hp_bar() -> void:
	if hp_chunks.is_empty():
		return

	var health_percent = current_health / unit_data.max_health
	var chunks_filled = int(ceil(health_percent * hp_chunks.size()))

	for i in range(hp_chunks.size()):
		var chunk = hp_chunks[i]
		var chunk_material = chunk.material_override as StandardMaterial3D

		if i < chunks_filled:
			chunk.visible = true
			chunk_material.albedo_color = _get_health_color(health_percent)
		else:
			chunk.visible = false

func _get_health_color(percent: float) -> Color:
	# Green (>75%) -> Yellow (50-75%) -> Orange (25-50%) -> Red (<25%)
	if percent > 0.75:
		var t = (percent - 0.75) / 0.25
		return Color(1.0 - t * 0.8, 0.9, 0.2)
	elif percent > 0.5:
		var t = (percent - 0.5) / 0.25
		return Color(1.0, 0.5 + t * 0.4, 0.1)
	elif percent > 0.25:
		var t = (percent - 0.25) / 0.25
		return Color(1.0, 0.2 + t * 0.3, 0.1)
	else:
		return Color(0.9, 0.15, 0.1)

func set_bases(player_base: Node3D, enemy_base: Node3D) -> void:
	if unit_ai:
		unit_ai.set_bases(player_base, enemy_base)

func set_towers(towers: Array[Node3D]) -> void:
	if unit_ai:
		unit_ai.set_towers(towers)

func _process(delta: float) -> void:
	# Handle attack cooldown
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

	# Attack if we have a target and cooldown is ready
	if is_attacking and attack_cooldown_timer <= 0:
		_perform_attack()

	# HP bar faces perpendicular to lanes (fixed rotation facing positive Z)
	if hp_bar_container:
		hp_bar_container.rotation.y = 0

func _physics_process(delta: float) -> void:
	# Apply soft "jello" collision to nearby bodies
	if soft_collision_area:
		_apply_soft_collision(delta)

func _apply_soft_collision(_delta: float) -> void:
	var overlapping_bodies = soft_collision_area.get_overlapping_bodies()

	for body in overlapping_bodies:
		if body == self:
			continue

		# Calculate push direction (away from this unit)
		var push_dir = body.global_position - global_position
		push_dir.y = 0  # Only push horizontally

		var distance = push_dir.length()
		if distance < 0.1:
			# Too close, push in random direction
			push_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
			distance = 0.1

		push_dir = push_dir.normalized()

		# Calculate push force - stronger when closer, weaker at edge
		var area_radius = max(unit_data.grid_size.x, unit_data.grid_size.y) * 1.2
		var closeness = 1.0 - clamp(distance / area_radius, 0.0, 1.0)
		# Quadratic falloff, scaled by unit size (small = weak push, large = stronger)
		var push_amount = push_strength * closeness * closeness * 0.15

		# Apply push directly to position (bypasses velocity/movement system)
		# This creates the "jello" feel - you wade through but feel resistance
		if body is Node3D:
			body.global_position += push_dir * push_amount

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

func _on_target_acquired(target: Node3D) -> void:
	is_attacking = true
	print("%s acquired target: %s" % [unit_data.unit_name, target.name if target else "null"])

func _on_target_lost() -> void:
	is_attacking = false

func _perform_attack() -> void:
	if not unit_ai:
		return

	var target = unit_ai.get_current_target()
	if not is_instance_valid(target):
		is_attacking = false
		return

	unit_attacking.emit(self, target)

	# Check if this is a ranged unit with projectile
	if unit_data.is_ranged and unit_data.projectile_speed > 0:
		_fire_projectile(target)
	else:
		# Melee attack - deal damage directly
		if target.has_method("take_damage"):
			target.take_damage(unit_data.attack_damage)
			print("%s attacks %s for %.1f damage" % [unit_data.unit_name, target.name, unit_data.attack_damage])

	# Reset cooldown
	attack_cooldown_timer = unit_data.attack_cooldown

func _fire_projectile(target: Node3D) -> void:
	# Create projectile
	var projectile = Projectile.new()
	projectile.name = "UnitProjectile"

	# Add to scene FIRST (not as child of this unit)
	var parent = get_tree().current_scene
	if parent:
		parent.add_child(projectile)
	else:
		add_child(projectile)

	# Position projectile at unit's position (slightly elevated) - AFTER adding to scene
	projectile.global_position = global_position + Vector3(0, 1.5, 0)
	projectile.source_unit = self

	# Setup projectile with target position and parameters
	var target_pos = target.global_position + Vector3(0, 1.0, 0)
	projectile.setup(
		target_pos,
		unit_data.projectile_speed,
		unit_data.attack_damage,
		unit_data.splash_radius,
		team,
		unit_data.projectile_model_path,
		0.3  # Model scale
	)

func take_damage(amount: float) -> void:
	current_health -= amount
	current_health = max(0, current_health)
	_update_hp_bar()
	print("%s took %.1f damage, health: %.1f/%.1f" % [unit_data.unit_name, amount, current_health, unit_data.max_health])

	if current_health <= 0:
		_die()

func _die() -> void:
	print("%s destroyed!" % unit_data.unit_name)
	unit_destroyed.emit(self)
	queue_free()

func get_grid_size() -> Vector2i:
	if unit_data:
		return unit_data.grid_size
	return Vector2i(1, 1)

func get_team() -> int:
	return team

func set_idle() -> void:
	if unit_ai:
		unit_ai.set_idle()

func on_attacked_by(attacker: Node3D) -> void:
	if unit_ai:
		unit_ai.on_attacked_by(attacker)
