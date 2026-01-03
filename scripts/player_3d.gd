extends CharacterBody3D
## Minimal 3D player controller for camera testing

@export var move_speed: float = 8.0
@export var rotation_speed: float = 10.0

var nav_agent: NavigationAgent3D = null
var move_target: Vector3 = Vector3.ZERO
var has_move_target: bool = false

# Animation
var anim_player: AnimationPlayer = null
var current_anim: String = ""

func _ready() -> void:
	# Check if NavigationAgent3D exists
	nav_agent = get_node_or_null("NavigationAgent3D")
	if nav_agent:
		# Wait for navigation map to synchronize
		call_deferred("_setup_navigation")

	# Find AnimationPlayer in the human-female model
	_setup_animation()

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
