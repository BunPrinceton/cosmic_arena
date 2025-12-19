extends Control

## Deck builder UI - allows player to select units for their deck

@onready var available_units_container = $MarginContainer/HBoxContainer/AvailableUnits/ScrollContainer/UnitGrid
@onready var selected_units_container = $MarginContainer/HBoxContainer/SelectedDeck/ScrollContainer/DeckGrid
@onready var deck_count_label = $MarginContainer/HBoxContainer/SelectedDeck/DeckCountLabel
@onready var start_button = $MarginContainer/HBoxContainer/SelectedDeck/StartButton

var current_deck: Deck
var available_units: Array[UnitData]

# Button scene for unit selection
var unit_button_scene: PackedScene

func _ready() -> void:
	# Create button scene programmatically (simple approach)
	unit_button_scene = create_unit_button_scene()

	# Get available units from GameState
	available_units = GameState.get_available_units()

	# Create a new deck or use existing
	current_deck = GameState.player_deck.duplicate_deck()

	# Setup UI
	populate_available_units()
	update_selected_deck_display()

	# Connect signals
	start_button.pressed.connect(_on_start_pressed)

	# Update button state
	update_start_button()

func create_unit_button_scene() -> PackedScene:
	# For simplicity, we'll create buttons procedurally
	return null

func populate_available_units() -> void:
	# Clear existing buttons
	for child in available_units_container.get_children():
		child.queue_free()

	# Create button for each available unit
	for unit_data in available_units:
		var button = Button.new()
		button.custom_minimum_size = Vector2(150, 80)
		button.text = "%s\nCost: %.1f\nHP: %.0f | DMG: %.0f" % [
			unit_data.unit_name,
			unit_data.energy_cost,
			unit_data.max_health,
			unit_data.attack_damage
		]

		# Store unit_data reference
		button.set_meta("unit_data", unit_data)

		# Connect signal
		button.pressed.connect(_on_unit_button_pressed.bind(button))

		available_units_container.add_child(button)

func update_selected_deck_display() -> void:
	# Clear existing
	for child in selected_units_container.get_children():
		child.queue_free()

	# Show selected units
	for i in range(current_deck.units.size()):
		var unit_data = current_deck.units[i]

		var button = Button.new()
		button.custom_minimum_size = Vector2(120, 60)
		button.text = "%s (%.1f)" % [unit_data.unit_name, unit_data.energy_cost]

		# Store index for removal
		button.set_meta("deck_index", i)

		# Connect removal signal
		button.pressed.connect(_on_deck_unit_pressed.bind(button))

		selected_units_container.add_child(button)

	# Update count label
	deck_count_label.text = "Deck: %d/%d units" % [current_deck.get_size(), Deck.MAX_DECK_SIZE]

	# Update start button
	update_start_button()

func _on_unit_button_pressed(button: Button) -> void:
	var unit_data = button.get_meta("unit_data") as UnitData

	if current_deck.add_unit(unit_data):
		update_selected_deck_display()
	else:
		print("Deck is full! (Max: ", Deck.MAX_DECK_SIZE, ")")

func _on_deck_unit_pressed(button: Button) -> void:
	var index = button.get_meta("deck_index") as int

	if index >= 0 and index < current_deck.units.size():
		current_deck.units.remove_at(index)
		update_selected_deck_display()

func update_start_button() -> void:
	start_button.disabled = not current_deck.is_valid()

	if current_deck.is_valid():
		start_button.text = "Start Battle!"
	else:
		start_button.text = "Select %d-%d Units" % [Deck.MIN_DECK_SIZE, Deck.MAX_DECK_SIZE]

func _on_start_pressed() -> void:
	if not current_deck.is_valid():
		return

	# Save deck to GameState
	GameState.set_player_deck(current_deck)

	# Generate random AI deck
	GameState.set_ai_deck(GameState.create_random_ai_deck())

	# Load main game scene
	get_tree().change_scene_to_file("res://main.tscn")
