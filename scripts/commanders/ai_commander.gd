extends Commander
class_name AICommander

## AI-controlled enemy commander with simple behavior

@export var aggro_range: float = 300.0
@export var retreat_health_threshold: float = 0.3  # Retreat when below 30% health

var home_position: Vector2
var current_state: String = "patrol"  # patrol, attack, retreat

func _ready() -> void:
	super._ready()
	team = 1
	add_to_group("commanders")
	add_to_group("enemy")
	home_position = global_position

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if not is_alive:
		return

	# AI behavior state machine
	update_ai_state()

	match current_state:
		"patrol":
			patrol_behavior()
		"attack":
			attack_behavior()
		"retreat":
			retreat_behavior()

	move_and_slide()
	attempt_attack()

	# Use ability when ready and enemies nearby
	if can_use_ability and not get_enemies_in_range().is_empty():
		use_ability()

func update_ai_state() -> void:
	var health_percent = current_health / max_health

	# Check if should retreat
	if health_percent < retreat_health_threshold:
		current_state = "retreat"
		return

	# Check for nearby enemies
	var nearby_enemies = get_nearby_enemies()
	if not nearby_enemies.is_empty():
		current_state = "attack"
		current_target = nearby_enemies[0]
	else:
		current_state = "patrol"
		current_target = null

func patrol_behavior() -> void:
	var target_pos = home_position

	# Check capture point periodically (25% chance each frame)
	if randf() < 0.0025:
		var capture_point = get_tree().get_first_node_in_group("capture_point")
		if capture_point and "get_current_owner" in capture_point:
			var owner = capture_point.get_current_owner()
			# Move toward capture point if not owned by AI
			if owner != team:
				target_pos = capture_point.global_position
			else:
				# Patrol around home if we own the point
				var patrol_radius = 50.0
				var time_offset = Time.get_ticks_msec() / 1000.0
				target_pos = home_position + Vector2(
					sin(time_offset) * patrol_radius,
					cos(time_offset) * patrol_radius
				)
		else:
			# Default patrol around home position
			var patrol_radius = 50.0
			var time_offset = Time.get_ticks_msec() / 1000.0
			target_pos = home_position + Vector2(
				sin(time_offset) * patrol_radius,
				cos(time_offset) * patrol_radius
			)
	else:
		# Default patrol around home position
		var patrol_radius = 50.0
		var time_offset = Time.get_ticks_msec() / 1000.0
		target_pos = home_position + Vector2(
			sin(time_offset) * patrol_radius,
			cos(time_offset) * patrol_radius
		)

	var direction = global_position.direction_to(target_pos)
	velocity = direction * (move_speed * 0.3)

func attack_behavior() -> void:
	if not current_target or not is_instance_valid(current_target):
		current_state = "patrol"
		return

	var distance_to_target = global_position.distance_to(current_target.global_position)

	# Move towards target if out of attack range
	if distance_to_target > attack_range * 0.8:
		var direction = global_position.direction_to(current_target.global_position)
		velocity = direction * move_speed
	else:
		velocity = Vector2.ZERO

func retreat_behavior() -> void:
	# Move back to home position
	var direction = global_position.direction_to(home_position)
	var distance = global_position.distance_to(home_position)

	if distance > 10.0:
		velocity = direction * move_speed
	else:
		velocity = Vector2.ZERO
		# If mostly healed, return to patrol
		if current_health / max_health > 0.6:
			current_state = "patrol"

func get_nearby_enemies() -> Array:
	var enemies = []
	var all_bodies = get_tree().get_nodes_in_group("units")
	all_bodies.append_array(get_tree().get_nodes_in_group("commanders"))

	for body in all_bodies:
		if body == self:
			continue
		if "team" not in body or body.team == team:
			continue
		if global_position.distance_to(body.global_position) <= aggro_range:
			enemies.append(body)

	return enemies

