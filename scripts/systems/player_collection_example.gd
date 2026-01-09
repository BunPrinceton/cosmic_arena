extends Node

## Example usage of PlayerCollection system
## Demonstrates card tracking, duplicates, save/load, and queries
## Run this script to see pure data layer functionality

func _ready() -> void:
	print("\n=== PlayerCollection Example Usage ===\n")

	# Example 1: Create collection and add cards
	print("--- Example 1: Adding Cards ---")
	var collection = PlayerCollection.new()

	var cards_to_add = _create_demo_cards([
		"soldier_1",
		"knight_1",
		"mage_1"
	])

	var result = collection.add_cards(cards_to_add)
	print("Added cards:")
	print("  New cards: %s" % result.added)
	print("  Duplicates: %s" % result.duplicates)
	print("  Total unique: %d" % collection.get_unique_card_count())
	print("  Total copies: %d" % collection.get_total_card_count())

	# Example 2: Adding duplicates
	print("\n--- Example 2: Adding Duplicates ---")
	var more_cards = _create_demo_cards([
		"soldier_1",  # duplicate
		"soldier_1",  # duplicate
		"archer_1"    # new
	])

	result = collection.add_cards(more_cards)
	print("Added more cards:")
	print("  New cards: %s" % result.added)
	print("  Duplicates: %s" % result.duplicates)
	print("  Soldier count: %d" % collection.get_card_count("soldier_1"))
	print("  Total copies: %d" % collection.get_total_card_count())

	# Example 3: Querying collection
	print("\n--- Example 3: Querying Collection ---")
	print("Has soldier_1? %s" % collection.has_card("soldier_1"))
	print("Has dragon_1? %s" % collection.has_card("dragon_1"))
	print("Knight count: %d" % collection.get_card_count("knight_1"))
	print("Unknown card count: %d" % collection.get_card_count("unknown_123"))

	# Example 4: List all owned cards
	print("\n--- Example 4: All Owned Cards ---")
	var owned_ids = collection.get_owned_card_ids()
	print("Owned card IDs: %s" % owned_ids)

	var all_cards = collection.get_all_cards()
	for card_id in all_cards:
		print("  %s: x%d" % [card_id, all_cards[card_id]])

	# Example 5: Removing cards
	print("\n--- Example 5: Removing Cards ---")
	print("Removing 2 copies of soldier_1...")
	var removed = collection.remove_cards("soldier_1", 2)
	print("  Success: %s" % removed)
	print("  Soldier count now: %d" % collection.get_card_count("soldier_1"))

	print("Trying to remove 10 copies of knight_1...")
	removed = collection.remove_cards("knight_1", 10)
	print("  Success: %s (not enough copies)" % removed)
	print("  Knight count: %d" % collection.get_card_count("knight_1"))

	# Example 6: Save and load
	print("\n--- Example 6: Save/Load ---")
	var save_data = collection.to_dict()
	print("Saved data: %s" % save_data)

	var new_collection = PlayerCollection.new()
	var load_success = new_collection.from_dict(save_data)
	print("Load success: %s" % load_success)
	print("New collection has soldier_1? %s" % new_collection.has_card("soldier_1"))
	print("New collection unique cards: %d" % new_collection.get_unique_card_count())

	# Example 7: Direct manipulation (for admin/testing)
	print("\n--- Example 7: Direct Count Setting ---")
	collection.set_card_count("legendary_dragon", 5)
	print("Set legendary_dragon to 5 copies")
	print("  Count: %d" % collection.get_card_count("legendary_dragon"))

	collection.set_card_count("legendary_dragon", 0)
	print("Set legendary_dragon to 0 (removes it)")
	print("  Has card: %s" % collection.has_card("legendary_dragon"))

	# Example 8: Merging collections
	print("\n--- Example 8: Merging Collections ---")
	var collection_a = PlayerCollection.new()
	collection_a.add_cards(_create_demo_cards(["card_a", "card_b"]))
	collection_a.set_card_count("card_a", 3)

	var collection_b = PlayerCollection.new()
	collection_b.add_cards(_create_demo_cards(["card_a", "card_c"]))
	collection_b.set_card_count("card_a", 2)

	print("Collection A: %s" % collection_a.get_all_cards())
	print("Collection B: %s" % collection_b.get_all_cards())

	collection_a.merge_from(collection_b)
	print("After merge: %s" % collection_a.get_all_cards())
	print("  card_a count: %d (3 + 2)" % collection_a.get_card_count("card_a"))

	# Example 9: Pack opening integration
	print("\n--- Example 9: Pack Opening Integration ---")
	var pack_collection = PlayerCollection.new()

	# Simulate opening a pack
	var pack_type = PackGenerator.PackType.PREMIUM
	var card_pool = _create_card_pool()
	var pack_cards = PackGenerator.generate_pack(pack_type, card_pool, 42)

	print("Opened %s pack:" % ["BASIC", "PREMIUM", "LEGENDARY"][pack_type])
	for card in pack_cards:
		print("  - %s (%s)" % [card.card_name, card.get_rarity_name()])

	var add_result = pack_collection.add_cards(pack_cards)
	print("Added to collection:")
	print("  New: %d cards" % add_result.added.size())
	print("  Duplicates: %d cards" % add_result.duplicates.size())

	# Open another pack (might have duplicates)
	print("\nOpening second pack...")
	var pack_cards_2 = PackGenerator.generate_pack(pack_type, card_pool, 43)
	add_result = pack_collection.add_cards(pack_cards_2)
	print("Added to collection:")
	print("  New: %d cards" % add_result.added.size())
	print("  Duplicates: %d cards" % add_result.duplicates.size())
	print("  Total unique owned: %d" % pack_collection.get_unique_card_count())
	print("  Total copies: %d" % pack_collection.get_total_card_count())

	# Example 10: Empty collection check
	print("\n--- Example 10: Empty Check ---")
	var empty_collection = PlayerCollection.new()
	print("New collection is empty: %s" % empty_collection.is_empty())
	empty_collection.add_cards(_create_demo_cards(["test_card"]))
	print("After adding card: %s" % empty_collection.is_empty())
	empty_collection.clear()
	print("After clear: %s" % empty_collection.is_empty())


## Create demo CardData objects with specified IDs
func _create_demo_cards(card_ids: Array) -> Array[CardData]:
	var cards: Array[CardData] = []

	for card_id in card_ids:
		var card = CardData.new()
		card.card_id = card_id
		card.card_name = card_id.capitalize()
		card.rarity = CardData.Rarity.COMMON
		card.card_type = CardData.CardType.UNIT
		cards.append(card)

	return cards


## Create a simple card pool for pack generation
func _create_card_pool() -> Array[CardData]:
	var pool: Array[CardData] = []

	# Common cards
	for i in range(3):
		var card = CardData.new()
		card.card_id = "common_%d" % i
		card.card_name = "Common Unit %d" % i
		card.rarity = CardData.Rarity.COMMON
		card.card_type = CardData.CardType.UNIT
		pool.append(card)

	# Rare cards
	for i in range(2):
		var card = CardData.new()
		card.card_id = "rare_%d" % i
		card.card_name = "Rare Unit %d" % i
		card.rarity = CardData.Rarity.RARE
		card.card_type = CardData.CardType.UNIT
		pool.append(card)

	# Epic card
	var epic = CardData.new()
	epic.card_id = "epic_1"
	epic.card_name = "Epic Hero"
	epic.rarity = CardData.Rarity.EPIC
	epic.card_type = CardData.CardType.UNIT
	pool.append(epic)

	return pool
