extends Node3D
class_name Main3DController

## Main controller for the 3D battle scene
## Manages unit placement, energy, and game flow

# Node references
@onready var player = $Player
@onready var camera = $Camera3D

# Base references
var player_base: Node3D = null
var enemy_base: Node3D = null
var towers: Array[Node3D] = []

# Obstacle positions for placement blocking
var obstacle_positions: Array[Dictionary] = []  # {position: Vector3, size: Vector3}

# Systems
var energy_system: EnergySystem
var unit_placement_system: UnitPlacementSystem
var card_hand: CardHand

# UI Layer
var ui_layer: CanvasLayer

# Placed units container
var placed_units: Node3D

# Rock units deck for testing
var rock_deck: Deck

func _ready() -> void:
	print("Main3DController: Starting setup...")
	_find_bases_and_towers()
	_setup_placed_units_container()
	_setup_energy_system()
	_setup_rock_deck()
	_setup_placement_system()
	_setup_ui()
	print("Main3DController: Setup complete!")

func _find_bases_and_towers() -> void:
	# Find bases
	var bases_node = get_node_or_null("Bases")
	if bases_node:
		player_base = bases_node.get_node_or_null("PlayerBase")
		enemy_base = bases_node.get_node_or_null("EnemyBase")
		print("Found bases - Player: %s, Enemy: %s" % [player_base != null, enemy_base != null])

	# Find towers (look for nodes with "tower" in name, case insensitive)
	towers.clear()
	_find_towers_recursive(self)
	print("Found %d towers" % towers.size())

	# Find obstacles to block placement
	_find_and_block_obstacles()

func _find_and_block_obstacles() -> void:
	obstacle_positions.clear()
	var obstacles_node = get_node_or_null("Obstacles")
	if not obstacles_node:
		print("No Obstacles node found")
		return

	# Find all collision shapes under Obstacles
	_find_obstacles_recursive(obstacles_node)
	print("Found %d obstacle areas to block" % obstacle_positions.size())

func _find_obstacles_recursive(node: Node) -> void:
	# Check for CollisionShape3D to get obstacle bounds
	if node is CollisionShape3D:
		var col_shape = node as CollisionShape3D
		if col_shape.shape:
			var pos = col_shape.global_position
			var size = Vector3(5, 1, 5)  # Default size

			# Get actual size from shape
			if col_shape.shape is BoxShape3D:
				size = (col_shape.shape as BoxShape3D).size
			elif col_shape.shape is SphereShape3D:
				var radius = (col_shape.shape as SphereShape3D).radius
				size = Vector3(radius * 2, radius * 2, radius * 2)
			elif col_shape.shape is CapsuleShape3D:
				var cap = col_shape.shape as CapsuleShape3D
				size = Vector3(cap.radius * 2, cap.height, cap.radius * 2)

			obstacle_positions.append({"position": pos, "size": size})

	# Check children
	for child in node.get_children():
		_find_obstacles_recursive(child)

func _find_towers_recursive(node: Node) -> void:
	# Check if this node is a tower
	if "tower" in node.name.to_lower():
		if node is Node3D:
			var tower_node = node as Node3D
			towers.append(tower_node)

			# Determine team from name: "tower-p" = player (0), "tower-e" = enemy (1)
			var tower_team = 1 if "-e" in node.name.to_lower() else 0

			# Add Tower3D script if not already present
			if not tower_node.has_method("take_damage"):
				var tower_script = load("res://scripts/tower_3d.gd")
				tower_node.set_script(tower_script)
				tower_node.max_health = 500.0
				tower_node.team = tower_team
				tower_node._ready()  # Initialize the script

			print("Found tower: %s at %s (team: %d)" % [node.name, tower_node.global_position, tower_team])

	# Check children
	for child in node.get_children():
		_find_towers_recursive(child)

func _setup_placed_units_container() -> void:
	placed_units = Node3D.new()
	placed_units.name = "PlacedUnits"
	placed_units.add_to_group("placed_units")
	add_child(placed_units)

func _setup_energy_system() -> void:
	energy_system = EnergySystem.new()
	energy_system.name = "EnergySystem"
	add_child(energy_system)

func _setup_rock_deck() -> void:
	# Create a deck with rock units for testing
	rock_deck = Deck.new()
	rock_deck.deck_name = "Rock Test Deck"

	# Load rock units
	var rock_small = load("res://resources/units/rock_small.tres")
	var rock_medium = load("res://resources/units/rock_medium.tres")
	var rock_large = load("res://resources/units/rock_large.tres")
	var rock_huge = load("res://resources/units/rock_huge.tres")

	print("Loading rocks - small: %s, medium: %s, large: %s, huge: %s" % [
		rock_small != null, rock_medium != null, rock_large != null, rock_huge != null
	])

	if rock_small:
		rock_deck.add_unit(rock_small)
	if rock_medium:
		rock_deck.add_unit(rock_medium)
	if rock_large:
		rock_deck.add_unit(rock_large)
	if rock_huge:
		rock_deck.add_unit(rock_huge)

	print("Rock deck has %d units" % rock_deck.units.size())

func _setup_placement_system() -> void:
	unit_placement_system = UnitPlacementSystem.new()
	unit_placement_system.name = "UnitPlacementSystem"
	add_child(unit_placement_system)

	# Connect to placement events
	unit_placement_system.unit_placed.connect(_on_unit_placed)
	unit_placement_system.placement_cancelled.connect(_on_placement_cancelled)

	# Setup with camera and deck
	card_hand = unit_placement_system.setup(camera, energy_system, rock_deck)

	# Block obstacle areas for placement
	_block_obstacle_areas()

func _block_obstacle_areas() -> void:
	if not unit_placement_system:
		return

	for obs in obstacle_positions:
		var pos = obs["position"] as Vector3
		var size = obs["size"] as Vector3

		# Only block if on player's side (Z > 0)
		if pos.z <= 0:
			continue

		# Calculate grid cells to block based on obstacle size
		var grid_size = Vector2i(
			int(ceil(size.x / 2.0)) + 1,  # +1 for buffer
			int(ceil(size.z / 2.0)) + 1
		)

		unit_placement_system.add_static_blocked_area(pos, grid_size)
		print("Blocked obstacle at %s with grid size %s" % [pos, grid_size])

func _setup_ui() -> void:
	# Create UI layer
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UILayer"
	add_child(ui_layer)

	# Add card hand to UI
	if card_hand:
		ui_layer.add_child(card_hand)

	# Add energy display
	_create_energy_display()

func _create_energy_display() -> void:
	# Simple energy bar at the bottom center
	var energy_container = Control.new()
	energy_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	energy_container.offset_top = -50
	energy_container.offset_left = 100
	energy_container.offset_right = -400  # Leave space for cards
	ui_layer.add_child(energy_container)

	# Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.1, 0.1, 0.15, 0.8)
	energy_container.add_child(bg)

	# Energy bar
	var energy_bar = ProgressBar.new()
	energy_bar.name = "EnergyBar"
	energy_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	energy_bar.offset_left = 10
	energy_bar.offset_right = -10
	energy_bar.offset_top = 10
	energy_bar.offset_bottom = -10
	energy_bar.show_percentage = false
	energy_bar.max_value = 100
	energy_container.add_child(energy_bar)

	# Energy label
	var energy_label = Label.new()
	energy_label.name = "EnergyLabel"
	energy_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	energy_label.add_theme_font_size_override("font_size", 16)
	energy_container.add_child(energy_label)

	# Connect energy updates
	if energy_system:
		energy_system.energy_changed.connect(func(current: float, maximum: float):
			energy_bar.value = (current / maximum) * 100.0
			energy_label.text = "Energy: %.1f / %.0f" % [current, maximum]
		)
		# Trigger initial update
		energy_system.energy_changed.emit(
			energy_system.get_current_energy(),
			energy_system.get_max_energy()
		)

func _on_unit_placed(unit_data: UnitData, position: Vector3) -> void:
	# Create and spawn the placed unit
	var placed_unit = PlacedUnit.new()
	placed_units.add_child(placed_unit)
	placed_unit.setup(unit_data, position, 0)  # Team 0 = player

	# Give the unit knowledge of bases and towers
	placed_unit.set_bases(player_base, enemy_base)
	placed_unit.set_towers(towers)

	# Note: We don't block grid cells for moving units anymore
	# Units move, so blocking their spawn position doesn't make sense

	# Connect to unit destroyed
	placed_unit.unit_destroyed.connect(_on_unit_destroyed)

	print("Placed %s at %s" % [unit_data.unit_name, position])

func _on_placement_cancelled() -> void:
	print("Placement cancelled")

func _on_unit_destroyed(_unit: PlacedUnit) -> void:
	# Unit destroyed - no grid cleanup needed since we don't block moving units
	pass
