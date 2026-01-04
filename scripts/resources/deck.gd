extends Resource
class_name Deck

## A deck of units that can be deployed in a match
## Similar to a card deck in deck-building games

@export var deck_name: String = "My Deck"
@export var units: Array[UnitData] = []

const MAX_DECK_SIZE: int = 7  # 1 special unit + 6 support units (commander shown separately)
const MIN_DECK_SIZE: int = 3
const SUPPORT_SLOTS: int = 6  # Number of regular support unit slots

## Validates that the deck meets requirements
func is_valid() -> bool:
	if units.size() < MIN_DECK_SIZE:
		return false
	if units.size() > MAX_DECK_SIZE:
		return false

	# Check that all units are not null
	for unit in units:
		if unit == null:
			return false

	return true

## Gets the number of units in the deck
func get_size() -> int:
	return units.size()

## Adds a unit to the deck if there's room
func add_unit(unit_data: UnitData) -> bool:
	if units.size() >= MAX_DECK_SIZE:
		return false
	if unit_data == null:
		return false

	units.append(unit_data)
	return true

## Removes a unit from the deck
func remove_unit(unit_data: UnitData) -> bool:
	var index = units.find(unit_data)
	if index >= 0:
		units.remove_at(index)
		return true
	return false

## Clears all units from the deck
func clear() -> void:
	units.clear()

## Returns a copy of this deck
func duplicate_deck() -> Deck:
	var new_deck = Deck.new()
	new_deck.deck_name = deck_name
	new_deck.units = units.duplicate()
	return new_deck

## Gets a formatted string listing all units in the deck
func get_unit_list_text() -> String:
	var text = "%s (%d units)\n" % [deck_name, units.size()]
	for i in range(units.size()):
		if units[i]:
			text += "%d. %s (Cost: %.1f)\n" % [i + 1, units[i].unit_name, units[i].energy_cost]
	return text
