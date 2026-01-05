extends Node
class_name UnitPlacementSystem

## Coordinates the unit placement flow:
## 1. Card drag starts -> show grid + ghost
## 2. Mouse moves -> update ghost position, validate placement
## 3. Mouse release -> place unit if valid, cancel if invalid

signal unit_placed(unit_data: UnitData, position: Vector3)
signal placement_cancelled()

@export var energy_system: EnergySystem

# References
var camera: Camera3D
var ground_plane_y: float = 0.0

# Components
var placement_grid: PlacementGrid
var unit_ghost: UnitGhost
var card_hand: CardHand

# State
var is_placing: bool = false
var current_unit_data: UnitData = null
var current_mouse_world_pos: Vector3 = Vector3.ZERO
var is_current_position_valid: bool = false

func _ready() -> void:
	# Create placement grid
	placement_grid = PlacementGrid.new()
	add_child(placement_grid)

	# Create unit ghost
	unit_ghost = UnitGhost.new()
	add_child(unit_ghost)

func setup(p_camera: Camera3D, p_energy_system: EnergySystem, deck: Deck) -> CardHand:
	camera = p_camera
	energy_system = p_energy_system

	# Create card hand UI
	card_hand = CardHand.new()
	card_hand.setup(deck, energy_system)
	card_hand.card_drag_started.connect(_on_card_drag_started)
	card_hand.card_drag_ended.connect(_on_card_drag_ended)

	return card_hand

func _process(_delta: float) -> void:
	if is_placing:
		# Continuously update mouse position for smooth preview
		_update_mouse_world_position(get_viewport().get_mouse_position())
		_update_placement_preview()

func _input(event: InputEvent) -> void:
	if not is_placing:
		return

	# Handle mouse release anywhere on screen while placing
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_try_place_unit()
			get_viewport().set_input_as_handled()

func _update_mouse_world_position(screen_pos: Vector2) -> void:
	if not camera:
		return

	# Raycast from camera to ground plane
	var from = camera.project_ray_origin(screen_pos)
	var direction = camera.project_ray_normal(screen_pos)

	# Intersect with ground plane (Y = ground_plane_y)
	if abs(direction.y) > 0.001:
		var t = (ground_plane_y - from.y) / direction.y
		if t > 0:
			current_mouse_world_pos = from + direction * t

func _update_placement_preview() -> void:
	if not current_unit_data:
		return

	# Get snapped position
	var snapped_pos = placement_grid.get_snapped_position(current_mouse_world_pos)

	# Check if position is valid
	is_current_position_valid = placement_grid.is_position_valid(
		current_mouse_world_pos,
		current_unit_data.grid_size
	)

	# Update ghost
	unit_ghost.update_position(snapped_pos)
	unit_ghost.set_valid(is_current_position_valid)

	# Update grid footprint visualization
	placement_grid.update_unit_position(current_mouse_world_pos, is_current_position_valid)

func _on_card_drag_started(unit_data: UnitData) -> void:
	if not energy_system or not energy_system.can_afford(unit_data.energy_cost):
		card_hand.cancel_active_drag()
		return

	is_placing = true
	current_unit_data = unit_data

	# Show placement UI
	placement_grid.show_grid(unit_data.grid_size)
	unit_ghost.show_ghost(unit_data)

	# Initialize position
	_update_mouse_world_position(get_viewport().get_mouse_position())

func _on_card_drag_ended() -> void:
	# This is called by the card, but we handle actual placement in _try_place_unit
	pass

func _try_place_unit() -> void:
	if not is_placing or not current_unit_data:
		_cancel_placement()
		return

	var snapped_pos = placement_grid.get_snapped_position(current_mouse_world_pos)
	var final_pos: Vector3

	# Check if position is in valid zone (player's half)
	if is_current_position_valid:
		# Find best placement position (offset if overlapping with other units)
		final_pos = _find_best_placement_position(snapped_pos, current_unit_data.grid_size)
	else:
		# Position is invalid - try to find nearest valid position
		var nearest_valid = _find_nearest_valid_position(current_mouse_world_pos, current_unit_data.grid_size)
		if nearest_valid == Vector3.ZERO:
			# No valid position found
			placement_cancelled.emit()
			_end_placement()
			return
		final_pos = _find_best_placement_position(nearest_valid, current_unit_data.grid_size)

	# Spend energy and place
	if energy_system and energy_system.spend_energy(current_unit_data.energy_cost):
		unit_placed.emit(current_unit_data, final_pos)
	else:
		placement_cancelled.emit()

	_end_placement()

func _find_nearest_valid_position(attempted_pos: Vector3, grid_size: Vector2i) -> Vector3:
	## Find the nearest valid placement position when attempting to place in an invalid area.
	## This allows players to place units even when their camera can't see their valid territory -
	## the unit will spawn at the closest valid position toward their side of the board.

	var cell_size = placement_grid.CELL_SIZE

	# First, clamp the position toward valid territory
	# Player's valid zone is Z: playable_z_min (0) to playable_z_max (50)
	# X is clamped to grid bounds
	var clamped_z = clamp(attempted_pos.z, placement_grid.playable_z_min + cell_size, placement_grid.playable_z_max - cell_size)
	var clamped_x = clamp(attempted_pos.x, placement_grid.grid_min.x + cell_size, placement_grid.grid_max.x - cell_size)
	var clamped_pos = Vector3(clamped_x, 0, clamped_z)

	# Check if the clamped position is valid
	if placement_grid.is_position_valid(clamped_pos, grid_size):
		return placement_grid.get_snapped_position(clamped_pos)

	# If clamped position is blocked (by obstacle), search in expanding rings
	# Start from the clamped position and search outward, preferring positions closer to player base
	var best_pos = Vector3.ZERO
	var best_dist = INF

	# Search in expanding rings from the clamped position
	for ring in range(1, 20):  # Check up to 20 cells out (40 world units)
		var found_in_ring = false

		for dx in range(-ring, ring + 1):
			for dz in range(-ring, ring + 1):
				# Only check cells on the ring edge
				if abs(dx) != ring and abs(dz) != ring:
					continue

				var test_pos = clamped_pos + Vector3(dx * cell_size, 0, dz * cell_size)

				# Skip positions outside valid Z range
				if test_pos.z < placement_grid.playable_z_min or test_pos.z > placement_grid.playable_z_max:
					continue

				# Check if position is valid
				if not placement_grid.is_position_valid(test_pos, grid_size):
					continue

				# Calculate distance from attempted position (favor closer positions)
				var dist = attempted_pos.distance_to(test_pos)
				if dist < best_dist:
					best_dist = dist
					best_pos = test_pos
					found_in_ring = true

		# If we found a valid position in this ring, use it
		if found_in_ring:
			break

	if best_pos != Vector3.ZERO:
		return placement_grid.get_snapped_position(best_pos)

	return Vector3.ZERO  # No valid position found

func _find_best_placement_position(desired_pos: Vector3, grid_size: Vector2i) -> Vector3:
	# Check if desired position overlaps with existing units
	var unit_radius = max(grid_size.x, grid_size.y) * placement_grid.CELL_SIZE
	var placed_units_node = get_tree().get_first_node_in_group("placed_units")

	if not placed_units_node:
		return desired_pos

	# Check for nearby units
	var too_close = false
	for unit in placed_units_node.get_children():
		if not is_instance_valid(unit):
			continue
		var dist = desired_pos.distance_to(unit.global_position)
		if dist < unit_radius * 0.8:  # Allow some overlap for swarming
			too_close = true
			break

	if not too_close:
		return desired_pos

	# Find nearest free position by spiraling outward
	var best_pos = desired_pos
	var best_dist = INF
	var cell_size = placement_grid.CELL_SIZE

	# Check positions in expanding rings
	for ring in range(1, 6):  # Check up to 5 cells out
		for dx in range(-ring, ring + 1):
			for dz in range(-ring, ring + 1):
				# Only check cells on the ring edge
				if abs(dx) != ring and abs(dz) != ring:
					continue

				var test_pos = desired_pos + Vector3(dx * cell_size, 0, dz * cell_size)

				# Check if position is valid (bounds, obstacles, etc.)
				if not placement_grid.is_position_valid(test_pos, grid_size):
					continue

				# Check if far enough from other units
				var is_free = true
				for unit in placed_units_node.get_children():
					if not is_instance_valid(unit):
						continue
					if test_pos.distance_to(unit.global_position) < unit_radius * 0.6:
						is_free = false
						break

				if is_free:
					var dist_from_desired = test_pos.distance_to(desired_pos)
					if dist_from_desired < best_dist:
						best_dist = dist_from_desired
						best_pos = test_pos

		# If we found a position on this ring, use it
		if best_dist < INF:
			break

	return best_pos

func _cancel_placement() -> void:
	placement_cancelled.emit()
	_end_placement()

func _end_placement() -> void:
	is_placing = false
	current_unit_data = null
	is_current_position_valid = false

	placement_grid.hide_grid()
	unit_ghost.hide_ghost()

	if card_hand:
		card_hand.cancel_active_drag()

## Called by the main scene to add blocked cells for existing units/obstacles
func add_blocked_area(world_pos: Vector3, grid_size: Vector2i) -> void:
	var grid_pos = placement_grid.world_to_grid(world_pos)
	for dx in range(grid_size.x):
		for dz in range(grid_size.y):
			placement_grid.add_blocked_cell(Vector2i(
				grid_pos.x + dx - grid_size.x / 2,
				grid_pos.y + dz - grid_size.y / 2
			))

## Remove blocked area (when unit is destroyed/moved)
func remove_blocked_area(world_pos: Vector3, grid_size: Vector2i) -> void:
	var grid_pos = placement_grid.world_to_grid(world_pos)
	for dx in range(grid_size.x):
		for dz in range(grid_size.y):
			placement_grid.remove_blocked_cell(Vector2i(
				grid_pos.x + dx - grid_size.x / 2,
				grid_pos.y + dz - grid_size.y / 2
			))

## Add static blocked area (for obstacles that never move)
func add_static_blocked_area(world_pos: Vector3, grid_size: Vector2i) -> void:
	var grid_pos = placement_grid.world_to_grid(world_pos)
	for dx in range(grid_size.x):
		for dz in range(grid_size.y):
			placement_grid.add_static_blocked_cell(Vector2i(
				grid_pos.x + dx - grid_size.x / 2,
				grid_pos.y + dz - grid_size.y / 2
			))
