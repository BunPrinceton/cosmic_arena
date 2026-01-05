extends Node3D
class_name UnitAI

## AI controller for deployed units
## Handles movement along lanes, target acquisition, and combat

signal target_acquired(target: Node3D)
signal target_lost()
signal arrived_at_target()
signal unit_attacked(attacker: Node3D)

enum AIState {
	ADVANCING,      # Moving toward objective
	ATTACKING,      # In range, attacking target
	RESPONDING,     # Responding to threat
	IDLE            # Victory/defeat, do nothing
}

enum Lane {
	LEFT,
	RIGHT
}

# Configuration
@export var move_speed: float = 2.0  # Units per second
@export var attack_range: float = 5.0  # Distance to start attacking
@export var vision_range: float = 15.0  # Distance to detect enemies
@export var lane_adherence: float = 0.5  # How strongly to stay in lane (0-1)

# Team: 0 = player, 1 = enemy
var team: int = 0

# State
var current_state: AIState = AIState.ADVANCING
var current_lane: Lane = Lane.LEFT
var current_target: Node3D = null
var spawn_position: Vector3 = Vector3.ZERO

# Obstacle avoidance - reactive (when stuck)
var stuck_timer: float = 0.0
var last_position: Vector3 = Vector3.ZERO
var avoidance_direction: int = 0  # -1 = left, 0 = none, 1 = right
var avoidance_timer: float = 0.0
const STUCK_THRESHOLD: float = 0.3  # Time before considering stuck
const AVOIDANCE_DURATION: float = 0.8  # How long to avoid before rechecking
const STUCK_DISTANCE: float = 0.1  # Movement threshold to detect stuck

# Obstacle avoidance - proactive (raycast ahead)
const OBSTACLE_SIGHT_RANGE: float = 8.0  # How far ahead to look for obstacles
const OBSTACLE_SIDE_ANGLE: float = 0.5  # Radians (~30 degrees) for side rays
var proactive_avoidance: int = 0  # -1 = steer left, 0 = none, 1 = steer right

# Flocking behavior - ally awareness
const ALLY_AWARENESS_RANGE: float = 6.0  # Range to detect nearby allies
const SEPARATION_RANGE: float = 3.0  # Preferred minimum distance from allies
const SEPARATION_STRENGTH: float = 0.6  # How strongly to separate (0-1)
const PREDICTIVE_LOOK_AHEAD: float = 1.0  # Seconds to predict ally positions
const ATTACK_SPREAD_RANGE: float = 4.0  # Distance to spread around target when attacking
const ATTACK_SPREAD_STRENGTH: float = 0.4  # How strongly to spread around target

# Cached ally data for flocking
var nearby_allies: Array[Node3D] = []
var last_velocity: Vector3 = Vector3.ZERO
var current_velocity: Vector3 = Vector3.ZERO

# Lane positions
const LEFT_LANE_X: float = -15.0
const RIGHT_LANE_X: float = 15.0
const LANE_WIDTH: float = 8.0

# Base positions
const PLAYER_BASE_Z: float = 50.0
const ENEMY_BASE_Z: float = -50.0

# References (set by parent)
var enemy_base: Node3D = null
var player_base: Node3D = null
var towers: Array[Node3D] = []
var parent_unit: Node3D = null

func _ready() -> void:
	spawn_position = global_position
	_determine_lane()

func setup(p_team: int, p_move_speed: float, p_attack_range: float, p_parent: Node3D) -> void:
	team = p_team
	move_speed = p_move_speed
	attack_range = p_attack_range
	parent_unit = p_parent
	spawn_position = global_position
	_determine_lane()

func set_bases(p_player_base: Node3D, p_enemy_base: Node3D) -> void:
	player_base = p_player_base
	enemy_base = p_enemy_base

func set_towers(p_towers: Array[Node3D]) -> void:
	towers = p_towers

func _determine_lane() -> void:
	# Determine lane based on spawn X position
	if spawn_position.x < 0:
		current_lane = Lane.LEFT
	else:
		current_lane = Lane.RIGHT

func get_lane_center_x() -> float:
	return LEFT_LANE_X if current_lane == Lane.LEFT else RIGHT_LANE_X

func _physics_process(delta: float) -> void:
	if current_state == AIState.IDLE:
		return

	# Update ally awareness for flocking behaviors
	_update_nearby_allies()

	# Track velocity for predictive avoidance
	if parent_unit and parent_unit is CharacterBody3D:
		var body = parent_unit as CharacterBody3D
		current_velocity = Vector3(body.velocity.x, 0, body.velocity.z)

	match current_state:
		AIState.ADVANCING:
			_process_advancing(delta)
		AIState.ATTACKING:
			_process_attacking(delta)
		AIState.RESPONDING:
			_process_responding(delta)

func _process_advancing(delta: float) -> void:
	# Check for targets in range
	var new_target = _find_priority_target()
	if new_target and _is_in_attack_range(new_target):
		current_target = new_target
		current_state = AIState.ATTACKING
		target_acquired.emit(current_target)
		return

	# Move toward objective
	var objective_pos = _get_objective_position()
	if objective_pos == Vector3.ZERO:
		return

	# Calculate movement direction
	var direction = _calculate_movement_direction(objective_pos)

	# Apply movement
	_move(direction, delta)

	# Check if arrived at objective
	var distance_to_objective = global_position.distance_to(objective_pos)
	if distance_to_objective < attack_range:
		if current_target:
			current_state = AIState.ATTACKING
			arrived_at_target.emit()

func _process_attacking(delta: float) -> void:
	if not is_instance_valid(current_target):
		# Target destroyed, find new one
		current_target = null
		current_state = AIState.ADVANCING
		target_lost.emit()
		return

	# Check if target is still alive (towers/bases have is_alive method)
	if current_target.has_method("is_alive") and not current_target.is_alive():
		# Target died, find new one
		current_target = null
		current_state = AIState.ADVANCING
		target_lost.emit()
		return

	# Check if still in range
	if not _is_in_attack_range(current_target):
		# Move closer - use full movement calculation for flocking
		var direction = _calculate_movement_direction(current_target.global_position)
		_move(direction, delta)
	else:
		# In range - still apply slight separation/spread while attacking
		var separation = _calculate_separation_force()
		var spread = _calculate_attack_spread()
		var nudge = (separation + spread).limit_length(0.3)
		if nudge.length() > 0.1:
			# Gentle repositioning while attacking
			_move(nudge.normalized(), delta * 0.5)

func _process_responding(delta: float) -> void:
	if not is_instance_valid(current_target):
		# Threat eliminated, resume advancing
		current_target = null
		current_state = AIState.ADVANCING
		target_lost.emit()
		return

	# Check if target is still alive
	if current_target.has_method("is_alive") and not current_target.is_alive():
		current_target = null
		current_state = AIState.ADVANCING
		target_lost.emit()
		return

	# Move toward threat - use full movement calculation for flocking
	var direction = _calculate_movement_direction(current_target.global_position)
	_move(direction, delta)

	# If in range, start attacking
	if _is_in_attack_range(current_target):
		current_state = AIState.ATTACKING

func _find_priority_target() -> Node3D:
	# Priority: 1. Enemy units in vision, 2. Towers, 3. Enemy base

	# Check for enemy units in vision range
	var enemy_unit = _find_nearest_enemy_unit()
	if enemy_unit and global_position.distance_to(enemy_unit.global_position) <= vision_range:
		return enemy_unit

	# Check for towers in our lane (only if alive)
	var lane_tower = _find_lane_tower()
	if lane_tower:
		return lane_tower

	# Default to enemy base (if alive)
	var target_base: Node3D = enemy_base if team == 0 else player_base
	if target_base and is_instance_valid(target_base):
		if target_base.has_method("is_alive") and not target_base.is_alive():
			return null  # Base destroyed, no target
		return target_base

	return null

func _find_nearest_enemy_unit() -> Node3D:
	var units_node = get_tree().get_first_node_in_group("placed_units")
	if not units_node:
		return null

	var nearest: Node3D = null
	var nearest_dist: float = INF

	for unit in units_node.get_children():
		if not is_instance_valid(unit):
			continue
		if unit == parent_unit:
			continue
		if unit.has_method("get_team") and unit.get_team() != team:
			var dist = global_position.distance_to(unit.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = unit

	return nearest

func _find_lane_tower() -> Node3D:
	# Find tower in our lane that's still alive
	for tower in towers:
		if not is_instance_valid(tower):
			continue
		# Check if tower is actually alive (not just valid node)
		if tower.has_method("is_alive") and not tower.is_alive():
			continue
		# Check if tower is in our lane
		var tower_lane = Lane.LEFT if tower.global_position.x < 0 else Lane.RIGHT
		if tower_lane == current_lane:
			# Check if tower is between us and enemy base
			if team == 0:  # Player team, enemy towers are at negative Z
				if tower.global_position.z < global_position.z:
					return tower
			else:  # Enemy team
				if tower.global_position.z > global_position.z:
					return tower
	return null

func _get_objective_position() -> Vector3:
	# Get position to move toward
	if current_target and is_instance_valid(current_target):
		return current_target.global_position

	# No specific target, move toward enemy base
	var target_z: float
	if team == 0:
		target_z = ENEMY_BASE_Z
	else:
		target_z = PLAYER_BASE_Z

	return Vector3(get_lane_center_x(), 0, target_z)

## Flocking behavior - find nearby allies for separation/avoidance
func _update_nearby_allies() -> void:
	nearby_allies.clear()
	var units_node = get_tree().get_first_node_in_group("placed_units")
	if not units_node:
		return

	for unit in units_node.get_children():
		if not is_instance_valid(unit) or unit == parent_unit:
			continue
		# Only consider allies (same team)
		if unit.has_method("get_team") and unit.get_team() == team:
			var dist = global_position.distance_to(unit.global_position)
			if dist < ALLY_AWARENESS_RANGE:
				nearby_allies.append(unit)

## Calculate separation force - push away from nearby allies
func _calculate_separation_force() -> Vector3:
	if nearby_allies.is_empty():
		return Vector3.ZERO

	var separation = Vector3.ZERO
	var close_allies = 0

	for ally in nearby_allies:
		if not is_instance_valid(ally):
			continue

		var to_ally = ally.global_position - global_position
		to_ally.y = 0
		var dist = to_ally.length()

		if dist < SEPARATION_RANGE and dist > 0.1:
			# Push away from ally, stronger when closer
			var push_strength = 1.0 - (dist / SEPARATION_RANGE)
			push_strength = push_strength * push_strength  # Quadratic falloff
			separation -= to_ally.normalized() * push_strength
			close_allies += 1

	if close_allies > 0:
		separation = separation / close_allies
		separation = separation.normalized() * SEPARATION_STRENGTH

	return separation

## Predict if we'll collide with an ally and calculate avoidance
func _calculate_predictive_avoidance() -> Vector3:
	if nearby_allies.is_empty() or current_velocity.length() < 0.1:
		return Vector3.ZERO

	var avoidance = Vector3.ZERO
	var my_future_pos = global_position + current_velocity * PREDICTIVE_LOOK_AHEAD

	for ally in nearby_allies:
		if not is_instance_valid(ally):
			continue

		# Get ally's velocity if available
		var ally_velocity = Vector3.ZERO
		if ally.has_method("get_horizontal_velocity"):
			ally_velocity = ally.get_horizontal_velocity()
		elif ally is CharacterBody3D:
			ally_velocity = (ally as CharacterBody3D).velocity
			ally_velocity.y = 0

		var ally_future_pos = ally.global_position + ally_velocity * PREDICTIVE_LOOK_AHEAD

		# Check if our future positions are too close
		var future_dist = my_future_pos.distance_to(ally_future_pos)
		if future_dist < SEPARATION_RANGE:
			# Calculate avoidance direction - perpendicular to our movement
			var to_ally_future = ally_future_pos - my_future_pos
			to_ally_future.y = 0

			if to_ally_future.length() > 0.1:
				# Steer perpendicular to avoid collision
				var avoid_dir = Vector3(-current_velocity.z, 0, current_velocity.x).normalized()
				# Choose left or right based on which side ally is
				var cross = current_velocity.cross(to_ally_future)
				if cross.y > 0:
					avoid_dir = -avoid_dir  # Ally is on left, steer right

				var urgency = 1.0 - (future_dist / SEPARATION_RANGE)
				avoidance += avoid_dir * urgency * 0.5

	return avoidance.limit_length(0.6)

## When attacking, spread around the target for better surface coverage
func _calculate_attack_spread() -> Vector3:
	if current_state != AIState.ATTACKING or not is_instance_valid(current_target):
		return Vector3.ZERO

	var spread = Vector3.ZERO
	var allies_attacking_same = 0

	# Find allies attacking the same target
	for ally in nearby_allies:
		if not is_instance_valid(ally):
			continue

		# Check if ally has an AI and is attacking same target
		var ally_ai = ally.get_node_or_null("UnitAI") as UnitAI
		if ally_ai and ally_ai.current_target == current_target:
			allies_attacking_same += 1

			# Calculate spread direction - move away from ally, around target
			var my_to_target = current_target.global_position - global_position
			var ally_to_target = current_target.global_position - ally.global_position
			my_to_target.y = 0
			ally_to_target.y = 0

			if my_to_target.length() > 0.1 and ally_to_target.length() > 0.1:
				# Calculate angle between us and ally relative to target
				var my_angle = atan2(my_to_target.x, my_to_target.z)
				var ally_angle = atan2(ally_to_target.x, ally_to_target.z)
				var angle_diff = wrapf(my_angle - ally_angle, -PI, PI)

				# If we're too close angularly, spread apart
				if abs(angle_diff) < PI / 4:  # Within 45 degrees
					# Move perpendicular to target direction, away from ally
					var perpendicular = Vector3(-my_to_target.z, 0, my_to_target.x).normalized()
					if angle_diff < 0:
						perpendicular = -perpendicular  # Spread the other way
					spread += perpendicular * 0.3

	if allies_attacking_same > 0:
		spread = spread / allies_attacking_same
		return spread.limit_length(ATTACK_SPREAD_STRENGTH)

	return Vector3.ZERO

func _calculate_movement_direction(objective: Vector3) -> Vector3:
	# Primary direction: toward objective
	var to_objective = objective - global_position
	to_objective.y = 0
	var direction = to_objective.normalized()

	# Lane adherence: pull toward lane center
	var lane_x = get_lane_center_x()
	var x_offset = lane_x - global_position.x

	# Blend lane correction with forward movement
	if abs(x_offset) > 1.0:
		direction.x = lerp(direction.x, sign(x_offset), lane_adherence)
		direction = direction.normalized()

	# Proactive obstacle avoidance (raycast ahead)
	_check_obstacles_ahead(direction)

	# Apply proactive avoidance first (smooth steering)
	if proactive_avoidance != 0 and avoidance_direction == 0:
		# Gentle steering - blend with forward direction
		var steer_dir = Vector3(-direction.z, 0, direction.x) * proactive_avoidance
		direction = (direction * 0.6 + steer_dir * 0.4).normalized()

	# Apply reactive avoidance if stuck (stronger, overrides proactive)
	if avoidance_direction != 0:
		# Get perpendicular direction (rotate 90 degrees)
		var avoid_dir = Vector3(-direction.z, 0, direction.x) * avoidance_direction
		# Blend avoidance with forward movement (more lateral, less forward)
		direction = (direction * 0.3 + avoid_dir * 0.7).normalized()

	# --- Flocking behaviors (ally awareness) ---

	# Separation: push away from nearby allies to maintain spacing
	var separation = _calculate_separation_force()
	if separation.length() > 0.1:
		direction = (direction + separation).normalized()

	# Predictive avoidance: steer to avoid future collisions with allies
	var predictive = _calculate_predictive_avoidance()
	if predictive.length() > 0.1:
		direction = (direction + predictive).normalized()

	# Attack spread: spread around target when multiple units attacking same target
	var spread = _calculate_attack_spread()
	if spread.length() > 0.1:
		direction = (direction + spread).normalized()

	return direction

func _check_obstacles_ahead(move_direction: Vector3) -> void:
	if not parent_unit:
		return

	var space_state = parent_unit.get_world_3d().direct_space_state
	var ray_origin = parent_unit.global_position + Vector3(0, 0.5, 0)  # Slightly above ground

	# Cast rays: center, left, and right
	var center_blocked = _raycast_for_obstacle(space_state, ray_origin, move_direction, OBSTACLE_SIGHT_RANGE)
	var left_dir = move_direction.rotated(Vector3.UP, OBSTACLE_SIDE_ANGLE)
	var right_dir = move_direction.rotated(Vector3.UP, -OBSTACLE_SIDE_ANGLE)
	var left_blocked = _raycast_for_obstacle(space_state, ray_origin, left_dir, OBSTACLE_SIGHT_RANGE * 0.7)
	var right_blocked = _raycast_for_obstacle(space_state, ray_origin, right_dir, OBSTACLE_SIGHT_RANGE * 0.7)

	# Decide steering direction
	if center_blocked:
		if left_blocked and not right_blocked:
			proactive_avoidance = 1  # Steer right
		elif right_blocked and not left_blocked:
			proactive_avoidance = -1  # Steer left
		elif not left_blocked and not right_blocked:
			# Both sides clear, prefer toward lane center
			var lane_x = get_lane_center_x()
			proactive_avoidance = 1 if parent_unit.global_position.x < lane_x else -1
		else:
			# Both sides blocked, pick based on lane
			var lane_x = get_lane_center_x()
			proactive_avoidance = 1 if parent_unit.global_position.x < lane_x else -1
	elif left_blocked and not right_blocked:
		proactive_avoidance = 1  # Obstacle on left, steer right
	elif right_blocked and not left_blocked:
		proactive_avoidance = -1  # Obstacle on right, steer left
	else:
		proactive_avoidance = 0  # Path is clear

func _raycast_for_obstacle(space_state: PhysicsDirectSpaceState3D, origin: Vector3, direction: Vector3, distance: float) -> bool:
	var query = PhysicsRayQueryParameters3D.create(origin, origin + direction * distance)
	query.exclude = [parent_unit.get_rid()] if parent_unit else []
	query.collision_mask = 1  # Only check layer 1 (obstacles/ground)

	var result = space_state.intersect_ray(query)
	if result:
		# Check if it's an obstacle (not ground - ground normal points up)
		var normal = result.normal as Vector3
		if normal.y < 0.8:  # Not a floor (floor normal is mostly up)
			return true
	return false

func _move(direction: Vector3, delta: float) -> void:
	if direction.length() < 0.01:
		return

	# Move the parent unit using CharacterBody3D velocity
	if parent_unit and parent_unit is CharacterBody3D:
		var body = parent_unit as CharacterBody3D
		var pos_before = body.global_position

		# Set base movement velocity, soft collision push is added on top
		body.velocity.x = direction.x * move_speed
		body.velocity.z = direction.z * move_speed

		# Apply gravity if not on floor
		if not body.is_on_floor():
			body.velocity.y -= 20.0 * delta
		else:
			body.velocity.y = 0

		# Move with collision
		body.move_and_slide()

		# Check if we're stuck (colliding but not moving)
		var pos_after = body.global_position
		var actual_movement = pos_after.distance_to(pos_before)
		var expected_movement = move_speed * delta

		_update_obstacle_avoidance(actual_movement, expected_movement, delta)

		# Rotate to face movement direction (use original direction, not avoidance)
		if direction.length() > 0.1 and avoidance_direction == 0:
			var target_angle = atan2(direction.x, direction.z)
			parent_unit.rotation.y = lerp_angle(parent_unit.rotation.y, target_angle, 5.0 * delta)
	elif parent_unit:
		# Fallback for non-CharacterBody3D (shouldn't happen)
		parent_unit.global_position += direction * move_speed * delta

func _update_obstacle_avoidance(actual_movement: float, expected_movement: float, delta: float) -> void:
	# Decrease avoidance timer
	if avoidance_timer > 0:
		avoidance_timer -= delta
		if avoidance_timer <= 0:
			avoidance_direction = 0  # Stop avoiding, try normal path

	# Check if stuck (moving much less than expected)
	if actual_movement < expected_movement * 0.3:
		stuck_timer += delta

		if stuck_timer > STUCK_THRESHOLD and avoidance_direction == 0:
			# Start avoiding - pick a direction
			# Prefer the direction toward lane center
			var lane_x = get_lane_center_x()
			if global_position.x < lane_x:
				avoidance_direction = 1  # Go right (toward lane)
			else:
				avoidance_direction = -1  # Go left (toward lane)

			avoidance_timer = AVOIDANCE_DURATION
			stuck_timer = 0

		elif stuck_timer > STUCK_THRESHOLD and avoidance_timer <= 0:
			# Still stuck after avoiding, try the other direction
			avoidance_direction = -avoidance_direction
			avoidance_timer = AVOIDANCE_DURATION
			stuck_timer = 0
	else:
		# Moving fine, reset stuck timer
		stuck_timer = 0
		# If we were avoiding and now moving, we can stop avoiding sooner
		if avoidance_direction != 0 and actual_movement > expected_movement * 0.7:
			avoidance_timer = min(avoidance_timer, 0.2)  # Finish avoidance soon

func _is_in_attack_range(target: Node3D) -> bool:
	if not is_instance_valid(target):
		return false

	# Check if target is alive
	if target.has_method("is_alive") and not target.is_alive():
		return false

	var dist = global_position.distance_to(target.global_position)

	# Account for target size - larger structures have larger hitboxes
	var target_size_bonus: float = 0.0
	if target.has_method("get_team"):
		# Tower or base - add size bonus for melee to reach
		if target is StaticBody3D:
			target_size_bonus = 4.0  # Base is large
		elif "tower" in target.name.to_lower():
			target_size_bonus = 3.0  # Tower is medium-large

	return dist <= attack_range + target_size_bonus

func on_attacked_by(attacker: Node3D) -> void:
	# Respond to being attacked
	unit_attacked.emit(attacker)

	if current_state != AIState.ATTACKING:
		current_target = attacker
		current_state = AIState.RESPONDING

func set_idle() -> void:
	current_state = AIState.IDLE

func get_current_target() -> Node3D:
	return current_target

func is_attacking() -> bool:
	return current_state == AIState.ATTACKING

func get_horizontal_velocity() -> Vector3:
	return current_velocity
