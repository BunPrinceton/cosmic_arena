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

# Victory/Defeat screen
var game_over_screen: Control = null
var is_game_over: bool = false

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

		# Connect to base destroyed signals
		if enemy_base and enemy_base.has_signal("base_destroyed"):
			enemy_base.base_destroyed.connect(_on_enemy_base_destroyed)
		if player_base and player_base.has_signal("base_destroyed"):
			player_base.base_destroyed.connect(_on_player_base_destroyed)

	# Find towers (look for nodes with "tower" in name, case insensitive)
	towers.clear()
	var towers_to_init: Array[Node3D] = []
	_find_towers_recursive(self, towers_to_init)

	# Initialize tower scripts after recursion complete (avoids stack overflow)
	for tower in towers_to_init:
		tower._ready()

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

func _find_towers_recursive(node: Node, towers_to_init: Array[Node3D]) -> void:
	# Check if this node is a tower (but skip dynamically created nodes)
	if "tower" in node.name.to_lower() and not "Container" in node.name and not "Collision" in node.name:
		if node is Node3D and node not in towers:
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
				towers_to_init.append(tower_node)  # Mark for initialization later

			print("Found tower: %s at %s (team: %d)" % [node.name, tower_node.global_position, tower_team])
			return  # Don't recurse into tower's children

	# Check children (get list first to avoid modification during iteration)
	var children = node.get_children()
	for child in children:
		_find_towers_recursive(child, towers_to_init)

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
	# Handle swarm units (spawn multiple)
	var spawn_count = unit_data.spawn_count if unit_data.spawn_count > 0 else 1
	var spread = unit_data.swarm_spread if unit_data.swarm_spread > 0 else 0.0

	for i in range(spawn_count):
		# Calculate spawn offset for swarm
		var spawn_offset = Vector3.ZERO
		if spawn_count > 1:
			var angle = (float(i) / spawn_count) * TAU
			spawn_offset = Vector3(cos(angle), 0, sin(angle)) * spread

		var spawn_pos = position + spawn_offset

		# Create and spawn the placed unit
		var placed_unit = PlacedUnit.new()
		placed_units.add_child(placed_unit)
		placed_unit.setup(unit_data, spawn_pos, 0)  # Team 0 = player

		# Give the unit knowledge of bases and towers
		placed_unit.set_bases(player_base, enemy_base)
		placed_unit.set_towers(towers)

		# Connect to unit destroyed
		placed_unit.unit_destroyed.connect(_on_unit_destroyed)

	print("Placed %s x%d at %s" % [unit_data.unit_name, spawn_count, position])

func _on_placement_cancelled() -> void:
	print("Placement cancelled")

func _on_unit_destroyed(_unit: PlacedUnit) -> void:
	# Unit destroyed - no grid cleanup needed since we don't block moving units
	pass

func _on_enemy_base_destroyed(_base: Node3D) -> void:
	if is_game_over:
		return
	is_game_over = true
	_show_game_over_screen(true)  # Victory

func _on_player_base_destroyed(_base: Node3D) -> void:
	if is_game_over:
		return
	is_game_over = true
	_show_game_over_screen(false)  # Defeat

func _show_game_over_screen(victory: bool) -> void:
	# Pause unit spawning/placement
	if card_hand:
		card_hand.visible = false

	# Create game over screen
	game_over_screen = Control.new()
	game_over_screen.name = "GameOverScreen"
	game_over_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(game_over_screen)

	# Dark overlay
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	game_over_screen.add_child(overlay)

	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_screen.add_child(center)

	# Panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 300)
	center.add_child(panel)

	# Style the panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	panel_style.border_color = Color(0.8, 0.7, 0.3) if victory else Color(0.8, 0.2, 0.2)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", panel_style)

	# VBox for content
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 30)
	panel.add_child(vbox)

	# Spacer top
	var spacer_top = Control.new()
	spacer_top.custom_minimum_size.y = 20
	vbox.add_child(spacer_top)

	# Victory/Defeat text
	var title = Label.new()
	title.text = "VICTORY!" if victory else "DEFEAT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if victory else Color(0.9, 0.3, 0.3))
	vbox.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Enemy base destroyed!" if victory else "Your base was destroyed!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(subtitle)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 20
	vbox.add_child(spacer)

	# Main Menu button
	var menu_button = Button.new()
	menu_button.text = "Return to Main Menu"
	menu_button.custom_minimum_size = Vector2(200, 50)
	menu_button.add_theme_font_size_override("font_size", 18)
	menu_button.pressed.connect(_on_main_menu_pressed)
	vbox.add_child(menu_button)

	# Center the button
	menu_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Spacer bottom
	var spacer_bottom = Control.new()
	spacer_bottom.custom_minimum_size.y = 20
	vbox.add_child(spacer_bottom)

func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
