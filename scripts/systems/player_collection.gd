extends RefCounted
class_name PlayerCollection

## Pure card collection tracking system - UI-independent
## Stores which cards the player owns and how many copies
## Design: Dictionary-based for fast lookups and easy serialization

## Core data structure: card_id (String) -> copy_count (int)
## Why Dictionary instead of Array?
##   - O(1) lookup time for has_card() and get_card_count()
##   - Natural deduplication (can't have duplicate keys)
##   - Easy to serialize/save (JSON-compatible)
##   - Efficient memory usage (no CardData object storage)
var _cards: Dictionary = {}  # { "card_id_string": count_int }


## Add cards to the collection
## Distinguishes between first-time acquisitions and duplicates
## @param cards: Array of CardData to add to collection
## @return: Dictionary with "added" (new cards) and "duplicates" (already owned)
##
## Design note: We extract card_id immediately and discard CardData reference
## to avoid storing heavy resource objects long-term
func add_cards(cards: Array[CardData]) -> Dictionary:
	var result = {
		"added": [],       # Array[String] of card_ids acquired for first time
		"duplicates": []   # Array[String] of card_ids already in collection
	}

	for card in cards:
		if not card:
			push_warning("PlayerCollection: Attempted to add null card, skipping")
			continue

		# Extract ID immediately - don't store CardData object
		var card_id = card.card_id

		if card_id.is_empty():
			push_warning("PlayerCollection: Card has empty card_id, skipping: %s" % card.card_name)
			continue

		# Check if this is first time acquiring this card
		var is_new = not _cards.has(card_id)

		# Increment count (or initialize to 1 if new)
		if is_new:
			_cards[card_id] = 1
			result.added.append(card_id)
		else:
			_cards[card_id] += 1
			result.duplicates.append(card_id)

	return result


## Check if player owns at least one copy of a card
## @param card_id: Unique identifier of the card
## @return: true if player owns 1+ copies, false otherwise
func has_card(card_id: String) -> bool:
	return _cards.has(card_id) and _cards[card_id] > 0


## Get number of copies owned of a specific card
## @param card_id: Unique identifier of the card
## @return: Number of copies owned (0 if not owned)
func get_card_count(card_id: String) -> int:
	return _cards.get(card_id, 0)


## Get entire collection as a dictionary
## @return: Dictionary mapping card_id -> count
##
## Design note: Returns a duplicate to prevent external mutation
## Caller can modify returned dict without affecting internal state
func get_all_cards() -> Dictionary:
	return _cards.duplicate()


## Clear entire collection
## Primarily for testing, but also useful for account resets
func clear() -> void:
	_cards.clear()


## Get total number of unique cards owned
## @return: Count of distinct cards in collection
func get_unique_card_count() -> int:
	return _cards.size()


## Get total number of card copies owned (includes duplicates)
## @return: Sum of all card counts
func get_total_card_count() -> int:
	var total = 0
	for count in _cards.values():
		total += count
	return total


## Remove specific number of copies of a card
## Useful for crafting systems or trading
## @param card_id: Card to remove copies from
## @param amount: Number of copies to remove (default 1)
## @return: true if removal succeeded, false if not enough copies
##
## Design note: Returns false rather than error for graceful degradation
func remove_cards(card_id: String, amount: int = 1) -> bool:
	if not _cards.has(card_id):
		return false

	if _cards[card_id] < amount:
		return false

	_cards[card_id] -= amount

	# Remove entry entirely if count reaches 0
	# Keeps dictionary clean and saves memory
	if _cards[card_id] <= 0:
		_cards.erase(card_id)

	return true


## Serialize collection to save-friendly format
## @return: Dictionary that can be saved to JSON/config
##
## Design note: Returns the internal dict directly since it's already
## in a save-friendly format (String -> int)
func to_dict() -> Dictionary:
	return {
		"cards": _cards.duplicate(),
		"version": 1  # For future migration support
	}


## Deserialize collection from saved data
## @param data: Dictionary from to_dict() or save file
## @return: true if load succeeded, false if data invalid
##
## Design note: Validates data structure before applying to prevent
## corruption from malformed save files
func from_dict(data: Dictionary) -> bool:
	if not data.has("cards"):
		push_error("PlayerCollection: Invalid save data - missing 'cards' key")
		return false

	var cards_data = data.cards

	if not cards_data is Dictionary:
		push_error("PlayerCollection: Invalid save data - 'cards' must be Dictionary")
		return false

	# Validate all entries are String -> int
	for key in cards_data:
		if not key is String:
			push_error("PlayerCollection: Invalid save data - card_id must be String")
			return false

		if not cards_data[key] is int:
			push_error("PlayerCollection: Invalid save data - count must be int")
			return false

		if cards_data[key] < 0:
			push_error("PlayerCollection: Invalid save data - count cannot be negative")
			return false

	# Data is valid, apply it
	_cards = cards_data.duplicate()
	return true


## Set exact count for a card (bypasses add/remove logic)
## Useful for admin tools, testing, or rewards
## @param card_id: Card to set count for
## @param count: Exact count to set (0 removes the card)
##
## Design note: Direct setter for cases where add_cards() semantics
## are too restrictive (e.g., setting initial collection state)
func set_card_count(card_id: String, count: int) -> void:
	if count <= 0:
		_cards.erase(card_id)
	else:
		_cards[card_id] = count


## Get list of all card IDs in collection
## @return: Array of String card IDs
##
## Useful for UI iteration or filtering
func get_owned_card_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_cards.keys())
	return ids


## Check if collection is empty
## @return: true if no cards owned
func is_empty() -> bool:
	return _cards.is_empty()


## Merge another collection into this one
## Useful for account merging or importing
## @param other: Another PlayerCollection to merge from
##
## Design note: Adds counts together, doesn't replace
func merge_from(other: PlayerCollection) -> void:
	if not other:
		return

	var other_cards = other.get_all_cards()
	for card_id in other_cards:
		var count = other_cards[card_id]
		if _cards.has(card_id):
			_cards[card_id] += count
		else:
			_cards[card_id] = count
