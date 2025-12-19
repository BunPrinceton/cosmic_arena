extends Commander
class_name PlayerCommander

## Player-controlled commander with WASD movement and click-to-move

var move_direction: Vector2 = Vector2.ZERO
var click_target: Vector2 = Vector2.ZERO
var has_click_target: bool = false

func _ready() -> void:
	super._ready()
	team = 0
	add_to_group("commanders")
	add_to_group("player")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if not is_alive:
		return

	# Handle movement
	move_direction = Vector2.ZERO

	# WASD movement
	if Input.is_action_pressed("move_up"):
		move_direction.y -= 1
	if Input.is_action_pressed("move_down"):
		move_direction.y += 1
	if Input.is_action_pressed("move_left"):
		move_direction.x -= 1
	if Input.is_action_pressed("move_right"):
		move_direction.x += 1

	# Normalize diagonal movement
	if move_direction.length() > 0:
		move_direction = move_direction.normalized()
		has_click_target = false

	# Click-to-move (right click)
	if Input.is_action_just_pressed("right_click"):
		click_target = get_global_mouse_position()
		has_click_target = true

	# Move towards click target if no WASD input
	if has_click_target and move_direction.length() == 0:
		var direction_to_target = global_position.direction_to(click_target)
		var distance_to_target = global_position.distance_to(click_target)

		if distance_to_target > 5.0:
			move_direction = direction_to_target
		else:
			has_click_target = false

	# Apply movement
	velocity = move_direction * move_speed
	move_and_slide()

	# Auto-attack
	attempt_attack()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("commander_ability"):
		use_ability()
