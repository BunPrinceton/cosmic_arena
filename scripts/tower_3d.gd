extends Node3D
class_name Tower3D

## A tower structure that protects a lane
## Must be destroyed before units can reach the base in that lane

signal health_changed(current: float, maximum: float)
signal tower_destroyed(tower: Tower3D)

@export var max_health: float = 500.0
@export var team: int = 0  # 0 = player, 1 = enemy
@export var hp_bar_height: float = 6.0  # Height above tower for HP bar
@export var chunk_count: int = 10  # Number of chunks in HP bar (500 HP / 10 = 50 per chunk)
@export var debug_show_collision: bool = true  # Show collision box for debugging
@export var collision_size: float = 2.0  # Collision box width/depth in world units
@export var collision_height: float = 6.0  # Collision box height in world units

# Combat
@export var attack_damage: float = 60.0  # One-shots swarm pebbles (50 HP)
@export var attack_range: float = 18.0  # Range to detect and attack enemies (less than artillery's 20.0)
@export var attack_cooldown: float = 2.5  # Time between attacks
@export var projectile_speed: float = 12.0  # Speed of rock projectiles
@export var projectile_model_path: String = "res://assets/models/environment/rocks/Rock_1.glb"

var current_health: float = 0.0
var is_destroyed: bool = false
var attack_timer: float = 0.0
var current_target: Node3D = null

# Collision
var collision_body: StaticBody3D = null
var collision_shape: CollisionShape3D = null
var debug_mesh: MeshInstance3D = null

# HP Bar
var hp_bar_container: Node3D = null
var hp_chunks: Array[MeshInstance3D] = []
var hp_bar_background: MeshInstance3D = null
const HP_BAR_WIDTH: float = 3.0
const HP_BAR_CHUNK_HEIGHT: float = 0.4
const HP_BAR_GAP: float = 0.05  # Gap between chunks

func _ready() -> void:
	current_health = max_health
	_create_collision()
	_create_hp_bar()
	health_changed.emit(current_health, max_health)

	# CRITICAL: Enable _process() since script was attached dynamically via set_script()
	set_process(true)

func _create_collision() -> void:
	# Check if collision already exists (avoid duplicates)
	if collision_body != null:
		return
	var existing = get_node_or_null("TowerCollision")
	if existing:
		collision_body = existing
		return

	# Get the tower's scale to compensate (towers might be scaled up in scene)
	var tower_scale = scale.x if scale.x > 0 else 1.0

	# Create a StaticBody3D for collision
	collision_body = StaticBody3D.new()
	collision_body.name = "TowerCollision"

	# Set collision layer to 1 (obstacles) so units/player collide with it
	collision_body.collision_layer = 1
	collision_body.collision_mask = 0  # Tower doesn't need to detect collisions

	collision_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	# Compensate for tower scale - use exported size values
	var size_compensated = collision_size / tower_scale
	var height_compensated = collision_height / tower_scale
	var box_size = Vector3(size_compensated, height_compensated, size_compensated)
	box.size = box_size
	collision_shape.shape = box
	collision_shape.position.y = 0  # Start from ground level

	collision_body.add_child(collision_shape)
	add_child(collision_body)

	# Debug visualization
	if debug_show_collision:
		debug_mesh = MeshInstance3D.new()
		debug_mesh.name = "DebugCollisionMesh"
		var debug_box = BoxMesh.new()
		debug_box.size = box_size
		debug_mesh.mesh = debug_box
		debug_mesh.position.y = 0  # Match collision position

		var debug_mat = StandardMaterial3D.new()
		debug_mat.albedo_color = Color(1.0, 0.0, 0.0, 0.3)  # Semi-transparent red
		debug_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		debug_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		debug_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		debug_mesh.material_override = debug_mat

		add_child(debug_mesh)

func _create_hp_bar() -> void:
	# Check if HP bar already exists (avoid duplicates)
	if hp_bar_container != null:
		return
	var existing = get_node_or_null("HPBarContainer")
	if existing:
		hp_bar_container = existing
		return

	# Container that will billboard toward camera
	hp_bar_container = Node3D.new()
	hp_bar_container.name = "HPBarContainer"
	# Compensate for tower scale
	var tower_scale = scale.x if scale.x > 0 else 1.0
	hp_bar_container.position.y = hp_bar_height / tower_scale
	# Also scale down the bar itself so it appears normal size
	hp_bar_container.scale = Vector3.ONE / tower_scale
	add_child(hp_bar_container)

	# Calculate total bar width with gaps
	var chunk_width = (HP_BAR_WIDTH - (chunk_count - 1) * HP_BAR_GAP) / chunk_count
	var start_x = -HP_BAR_WIDTH / 2.0 + chunk_width / 2.0

	# Create background (dark bar behind chunks)
	hp_bar_background = MeshInstance3D.new()
	var bg_mesh = BoxMesh.new()
	bg_mesh.size = Vector3(HP_BAR_WIDTH + 0.1, HP_BAR_CHUNK_HEIGHT + 0.1, 0.05)
	hp_bar_background.mesh = bg_mesh
	hp_bar_background.position.z = 0.03  # Slightly behind

	var bg_material = StandardMaterial3D.new()
	bg_material.albedo_color = Color(0.1, 0.1, 0.1, 0.8)
	bg_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hp_bar_background.material_override = bg_material
	hp_bar_container.add_child(hp_bar_background)

	# Create chunks
	for i in range(chunk_count):
		var chunk = MeshInstance3D.new()
		var chunk_mesh = BoxMesh.new()
		chunk_mesh.size = Vector3(chunk_width, HP_BAR_CHUNK_HEIGHT, 0.08)
		chunk.mesh = chunk_mesh
		chunk.position.x = start_x + i * (chunk_width + HP_BAR_GAP)

		var chunk_material = StandardMaterial3D.new()
		chunk_material.albedo_color = Color(0.2, 0.9, 0.2)  # Start green
		chunk_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		chunk.material_override = chunk_material

		hp_bar_container.add_child(chunk)
		hp_chunks.append(chunk)

	_update_hp_bar()

func _process(delta: float) -> void:
	# HP bar billboards to face the camera
	if hp_bar_container and not is_destroyed:
		var camera = get_viewport().get_camera_3d()
		if camera:
			# Make HP bar face the camera
			var look_pos = camera.global_position
			look_pos.y = hp_bar_container.global_position.y  # Keep level
			hp_bar_container.look_at(look_pos, Vector3.UP)
			hp_bar_container.rotate_y(PI)  # Flip to face camera

	# Handle combat
	if is_destroyed:
		return

	# Update attack cooldown
	if attack_timer > 0:
		attack_timer -= delta

	# Find and attack enemies
	if attack_timer <= 0:
		_find_target()
		if current_target and is_instance_valid(current_target):
			_fire_at_target()
			attack_timer = attack_cooldown

func _find_target() -> void:
	current_target = null
	var closest_dist = attack_range

	# Find enemy units
	var units_node = get_tree().get_first_node_in_group("placed_units")
	if not units_node:
		return

	for unit in units_node.get_children():
		if not is_instance_valid(unit):
			continue

		var unit_team = unit.get_team() if unit.has_method("get_team") else -1
		if unit_team == team:
			continue  # Skip allies (same team)

		var dist = global_position.distance_to(unit.global_position)
		if dist < closest_dist:
			closest_dist = dist
			current_target = unit

func _fire_at_target() -> void:
	if not current_target or not is_instance_valid(current_target):
		return

	# Create projectile
	var projectile = Projectile.new()
	projectile.name = "TowerProjectile"

	# Add to scene FIRST, then position
	var parent = get_tree().current_scene
	if parent:
		parent.add_child(projectile)
	else:
		get_parent().add_child(projectile)

	# Position projectile at tower top (after adding to scene so global_position works)
	var tower_scale = scale.x if scale.x > 0 else 1.0
	var spawn_pos = global_position + Vector3(0, 4.0 / tower_scale, 0)
	projectile.global_position = spawn_pos
	projectile.source_unit = self  # Track who fired so targets can respond

	# Setup projectile with target position
	var target_pos = current_target.global_position + Vector3(0, 1.0, 0)
	projectile.setup(
		target_pos,
		projectile_speed,
		attack_damage,
		0.0,  # No splash damage
		team,
		projectile_model_path,
		0.15  # Small rock scale
	)

func _update_hp_bar() -> void:
	var health_percent = current_health / max_health
	var chunks_filled = int(ceil(health_percent * chunk_count))

	for i in range(chunk_count):
		var chunk = hp_chunks[i]
		var chunk_material = chunk.material_override as StandardMaterial3D

		if i < chunks_filled:
			# This chunk is filled - color based on overall health
			chunk.visible = true
			chunk_material.albedo_color = _get_health_color(health_percent)
		else:
			# This chunk is empty
			chunk.visible = false

func _get_health_color(percent: float) -> Color:
	# Team-based colors: Blue for friendly (team 0), Red for enemy (team 1)
	# Brightness varies slightly with health
	var brightness = 0.7 + percent * 0.3  # 0.7 to 1.0 based on health

	if team == 0:
		# Friendly tower - Blue
		return Color(0.2 * brightness, 0.5 * brightness, 1.0 * brightness)
	else:
		# Enemy tower - Red
		return Color(1.0 * brightness, 0.2 * brightness, 0.2 * brightness)

func take_damage(amount: float, _attacker: Node3D = null) -> void:
	if is_destroyed:
		return

	current_health -= amount
	current_health = max(0, current_health)
	health_changed.emit(current_health, max_health)
	_update_hp_bar()
	print("%s took %.1f damage, health: %.1f/%.1f" % [name, amount, current_health, max_health])

	if current_health <= 0:
		_on_destroyed()

func _on_destroyed() -> void:
	is_destroyed = true
	print("Tower %s destroyed!" % name)
	tower_destroyed.emit(self)

	# Hide the tower visually but keep the node for reference
	visible = false

	# Hide HP bar
	if hp_bar_container:
		hp_bar_container.visible = false

	# Disable collision
	if collision_shape:
		collision_shape.disabled = true

func get_team() -> int:
	return team

func is_alive() -> bool:
	return not is_destroyed

func heal(amount: float) -> void:
	if is_destroyed:
		return
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
	_update_hp_bar()

func get_health_percentage() -> float:
	return current_health / max_health if max_health > 0 else 0.0
