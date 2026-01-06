extends CharacterBody3D
## Minimal 3D player controller for camera testing

signal health_changed(current: float, maximum: float)
signal player_died()

@export var move_speed: float = 8.0
@export var rotation_speed: float = 10.0
@export var max_health: float = 300.0
@export var team: int = 0  # 0 = player

var nav_agent: NavigationAgent3D = null
var move_target: Vector3 = Vector3.ZERO
var has_move_target: bool = false

# Health
var current_health: float = 0.0
var is_dead: bool = false

# HP Bar
var hp_bar_container: Node3D = null
var hp_chunks: Array[MeshInstance3D] = []
var hp_bar_background: MeshInstance3D = null

# Animation
var anim_player: AnimationPlayer = null
var current_anim: String = ""

func _ready() -> void:
	# Set collision layers (bit flags: layer N = 2^(N-1)):
	# Layer 1 (value 1) = Ground/Obstacles/Static environment
	# Layer 2 (value 2) = Player/Commander
	# Layer 3 (value 4) = Units
	# Player collides with ground/obstacles (layer 1) but NOT units (layer 3)
	collision_layer = 2  # Player is on layer 2
	collision_mask = 1   # Only collide with ground/obstacles (layer 1)

	# Initialize health
	current_health = max_health

	# Check if NavigationAgent3D exists
	nav_agent = get_node_or_null("NavigationAgent3D")
	if nav_agent:
		# Wait for navigation map to synchronize
		call_deferred("_setup_navigation")

	# Find AnimationPlayer in the human-female model
	_setup_animation()

	# Create HP bar
	_create_hp_bar()

func _setup_navigation() -> void:
	# Wait for first physics frame so NavigationServer can sync
	await get_tree().physics_frame

	# Debug: Check if navigation is ready
	if nav_agent and nav_agent.is_target_reachable():
		print("Navigation mesh is baked and ready!")
	else:
		print("WARNING: Navigation mesh not baked. Using direct movement fallback.")
		print("To enable smart pathfinding: Add NavigationRegion3D and NavigationAgent3D, then bake the mesh")

func _input(event: InputEvent) -> void:
	# ESC to return to main menu
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	# Right-click to move
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_update_move_target_from_mouse(event.position)

func _update_move_target_from_mouse(mouse_pos: Vector2) -> void:
	# Raycast from camera to ground
	var camera = get_viewport().get_camera_3d()
	if camera:
		var from = camera.project_ray_origin(mouse_pos)
		var to = from + camera.project_ray_normal(mouse_pos) * 1000.0

		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [self]  # Ignore player's own collider
		var result = space_state.intersect_ray(query)

		if result:
			move_target = result.position
			move_target.y = global_position.y  # Keep same height
			if nav_agent:
				nav_agent.target_position = move_target  # Tell navigation agent where to go
			has_move_target = true

func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO

	# Continuously update move target while right mouse button is held
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_update_move_target_from_mouse(get_viewport().get_mouse_position())

	# Keyboard input (arrow keys)
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir.length() > 0:
		direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
		has_move_target = false  # Cancel click movement
	# Right-click pathfinding movement
	elif has_move_target:
		# Check actual distance to final target
		var distance_to_target = (move_target - global_position).length()

		if distance_to_target < 0.5:
			# Actually reached the target
			has_move_target = false
			direction = Vector3.ZERO
		elif nav_agent and nav_agent.is_target_reachable():
			# Use navigation pathfinding if nav mesh is baked
			var next_position = nav_agent.get_next_path_position()
			var direction_to_waypoint = next_position - global_position
			direction_to_waypoint.y = 0
			direction = direction_to_waypoint.normalized()
		else:
			# Fallback to direct movement if nav mesh not baked
			var direction_to_target = move_target - global_position
			direction_to_target.y = 0
			direction = direction_to_target.normalized()

	if direction.length() > 0:
		# Move the player
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed

		# Rotate to face movement direction
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)
	else:
		# Decelerate when no input
		velocity.x = move_toward(velocity.x, 0, move_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0, move_speed * delta * 5.0)

	# Apply gravity if not on floor
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0

	move_and_slide()

	# Update animation based on movement
	_update_animation(direction.length() > 0.1)

	# HP bar billboards to face the camera
	if hp_bar_container:
		var camera = get_viewport().get_camera_3d()
		if camera:
			var look_pos = camera.global_position
			look_pos.y = hp_bar_container.global_position.y  # Keep level
			hp_bar_container.look_at(look_pos, Vector3.UP)
			hp_bar_container.rotate_y(PI)  # Flip to face camera

func _setup_animation() -> void:
	# Find AnimationPlayer in the human-female model hierarchy
	var model = get_node_or_null("human-female")
	if model:
		anim_player = model.get_node_or_null("AnimationPlayer")
		if not anim_player:
			# Try finding it recursively
			anim_player = _find_animation_player(model)

		if anim_player:
			print("Found AnimationPlayer with animations: ", anim_player.get_animation_list())
		else:
			print("WARNING: No AnimationPlayer found in human-female model")

func _find_animation_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var result = _find_animation_player(child)
		if result:
			return result
	return null

func _update_animation(is_moving: bool) -> void:
	if not anim_player:
		return

	var anim_list = anim_player.get_animation_list()
	var target_anim = ""

	if is_moving:
		# Use sprint animation for running
		for name in ["sprint", "run", "Run"]:
			if name in anim_list:
				target_anim = name
				break
	else:
		# Use unarmed idle
		for name in ["idle-unarmed", "idle-2h", "Idle"]:
			if name in anim_list:
				target_anim = name
				break

	if target_anim != "" and target_anim != current_anim:
		# Set animation to loop for smooth breathing/running
		var anim = anim_player.get_animation(target_anim)
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR
		anim_player.play(target_anim)
		current_anim = target_anim

# HP Bar
func _create_hp_bar() -> void:
	var bar_width = 1.5
	var bar_height = 2.5  # Height above player
	var chunk_height = 0.15
	var chunk_gap = 0.02
	var chunk_count = 6  # 300 HP / 6 = 50 per chunk

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

	var health_percent = current_health / max_health
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
	# Player is always friendly - Green health bar
	# Brightness varies slightly with health
	var brightness = 0.7 + percent * 0.3  # 0.7 to 1.0 based on health
	return Color(0.2 * brightness, 1.0 * brightness, 0.3 * brightness)

func take_damage(amount: float, _attacker: Node3D = null) -> void:
	if is_dead:
		return

	current_health -= amount
	current_health = max(0, current_health)
	_update_hp_bar()
	health_changed.emit(current_health, max_health)
	print("Player took %.1f damage, health: %.1f/%.1f" % [amount, current_health, max_health])

	if current_health <= 0:
		_die()

func _die() -> void:
	is_dead = true
	print("Player died!")
	player_died.emit()

func heal(amount: float) -> void:
	if is_dead:
		return
	current_health = min(current_health + amount, max_health)
	_update_hp_bar()
	health_changed.emit(current_health, max_health)

func get_team() -> int:
	return team

func is_alive() -> bool:
	return not is_dead

func get_health_percentage() -> float:
	return current_health / max_health if max_health > 0 else 0.0
