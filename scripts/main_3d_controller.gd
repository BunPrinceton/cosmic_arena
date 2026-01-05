extends Node3D
class_name Main3DController

## Main controller for the 3D battle scene
## Manages unit placement, energy, and game flow

# Node references
@onready var player = $Player
@onready var camera = $Camera3D

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
	_setup_placed_units_container()
	_setup_energy_system()
	_setup_rock_deck()
	_setup_placement_system()
	_setup_ui()
	print("Main3DController: Setup complete!")

func _setup_placed_units_container() -> void:
	placed_units = Node3D.new()
	placed_units.name = "PlacedUnits"
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

	# Block the grid cells
	unit_placement_system.add_blocked_area(position, unit_data.grid_size)

	# Connect to unit destroyed
	placed_unit.unit_destroyed.connect(_on_unit_destroyed)

	print("Placed %s at %s" % [unit_data.unit_name, position])

func _on_placement_cancelled() -> void:
	print("Placement cancelled")

func _on_unit_destroyed(unit: PlacedUnit) -> void:
	# Unblock the grid cells
	unit_placement_system.remove_blocked_area(
		unit.global_position,
		unit.get_grid_size()
	)
