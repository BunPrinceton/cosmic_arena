extends Node

## Global game state - persists across scene changes
## Holds player and AI decks and commanders during runtime

# Preload all available units
const AVAILABLE_UNITS: Array[UnitData] = [
	preload("res://resources/units/grunt_data.tres"),
	preload("res://resources/units/ranger_data.tres"),
	preload("res://resources/units/tank_data.tres"),
	preload("res://resources/units/support_data.tres")
]

# Preload all available commanders
const AVAILABLE_COMMANDERS: Array[CommanderData] = [
	preload("res://resources/commanders/assault_commander.tres"),
	preload("res://resources/commanders/tactical_commander.tres")
]

# Player's selected deck
var player_deck: Deck

# AI's deck (generated randomly)
var ai_deck: Deck

# Player's selected commander
var player_commander: CommanderData

# AI's commander (selected randomly)
var ai_commander: CommanderData

func _ready() -> void:
	# Initialize with default decks and commanders
	reset_to_defaults()

## Resets both decks and commanders to default configurations
func reset_to_defaults() -> void:
	player_deck = create_default_player_deck()
	ai_deck = create_random_ai_deck()
	player_commander = AVAILABLE_COMMANDERS[0]  # Default to first commander
	ai_commander = AVAILABLE_COMMANDERS[randi() % AVAILABLE_COMMANDERS.size()]

## Creates a default deck for the player (all units)
func create_default_player_deck() -> Deck:
	var deck = Deck.new()
	deck.deck_name = "Player Deck"

	# Add all available units
	for unit_data in AVAILABLE_UNITS:
		deck.add_unit(unit_data)

	return deck

## Creates a random valid deck for the AI
func create_random_ai_deck() -> Deck:
	var deck = Deck.new()
	deck.deck_name = "AI Deck"

	# Randomly select 4-6 units
	var deck_size = randi_range(4, 6)

	for i in range(deck_size):
		var random_unit = AVAILABLE_UNITS[randi() % AVAILABLE_UNITS.size()]
		deck.add_unit(random_unit)

	return deck

## Sets the player's deck
func set_player_deck(deck: Deck) -> void:
	player_deck = deck

## Sets the AI's deck
func set_ai_deck(deck: Deck) -> void:
	ai_deck = deck

## Gets all available units for deck building
func get_available_units() -> Array[UnitData]:
	return AVAILABLE_UNITS.duplicate()

## Validates that a deck is legal for play
func is_deck_valid(deck: Deck) -> bool:
	return deck != null and deck.is_valid()

## Gets all available commanders
func get_available_commanders() -> Array[CommanderData]:
	return AVAILABLE_COMMANDERS.duplicate()

## Sets the player's commander
func set_player_commander(commander: CommanderData) -> void:
	player_commander = commander

## Sets the AI's commander
func set_ai_commander(commander: CommanderData) -> void:
	ai_commander = commander
