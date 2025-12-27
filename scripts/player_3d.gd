extends CharacterBody3D
## Minimal 3D player controller for camera testing

@export var move_speed: float = 8.0
@export var rotation_speed: float = 10.0

var move_target: Vector3 = Vector3.ZERO
var has_move_target: bool = false

func _input(event: InputEvent) -> void:
	# Right-click to move
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Raycast from camera to ground
			var camera = get_viewport().get_camera_3d()
			if camera:
				var from = camera.project_ray_origin(event.position)
				var to = from + camera.project_ray_normal(event.position) * 1000.0

				var space_state = get_world_3d().direct_space_state
				var query = PhysicsRayQueryParameters3D.create(from, to)
				var result = space_state.intersect_ray(query)

				if result:
					move_target = result.position
					move_target.y = global_position.y  # Keep same height
					has_move_target = true

func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO

	# Keyboard input (arrow keys)
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir.length() > 0:
		direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
		has_move_target = false  # Cancel click movement
	# Right-click movement
	elif has_move_target:
		var direction_to_target = move_target - global_position
		direction_to_target.y = 0

		if direction_to_target.length() < 0.5:
			has_move_target = false
			direction = Vector3.ZERO
		else:
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
