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

func _ready() -> void:
	# Add to placed_units group for easy finding
	add_to_group("placed_units")

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

	# Deal damage
	if target.has_method("take_damage"):
		target.take_damage(unit_data.attack_damage)
		unit_attacking.emit(self, target)
		print("%s attacks %s for %.1f damage" % [unit_data.unit_name, target.name, unit_data.attack_damage])

	# Reset cooldown
	attack_cooldown_timer = unit_data.attack_cooldown

func take_damage(amount: float) -> void:
	current_health -= amount
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
