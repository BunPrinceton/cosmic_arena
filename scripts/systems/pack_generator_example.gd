extends Node

## Example usage of PackGenerator system
## This demonstrates how to use the pure pack generation functions
## Run this scene to see deterministic vs random pack generation

func _ready() -> void:
	print("\n=== PackGenerator Example Usage ===\n")

	# Setup: Create a card pool (normally from GameState)
	var card_pool = _create_demo_card_pool()
	print("Created card pool with %d cards" % card_pool.size())

	# Example 1: Generate a random basic pack
	print("\n--- Example 1: Random Basic Pack ---")
	var basic_pack = PackGenerator.generate_pack(
		PackGenerator.PackType.BASIC,
		card_pool,
		-1  # Random seed
	)
	_print_pack_results("Basic Pack (Random)", basic_pack)

	# Example 2: Generate a deterministic pack with seed
	print("\n--- Example 2: Deterministic Pack (Seed: 12345) ---")
	var seeded_pack_1 = PackGenerator.generate_pack(
		PackGenerator.PackType.PREMIUM,
		card_pool,
		12345  # Fixed seed
	)
	_print_pack_results("Premium Pack #1 (Seed 12345)", seeded_pack_1)

	# Example 3: Generate the SAME pack again with same seed
	print("\n--- Example 3: Regenerating with Same Seed ---")
	var seeded_pack_2 = PackGenerator.generate_pack(
		PackGenerator.PackType.PREMIUM,
		card_pool,
		12345  # Same seed = identical results
	)
	_print_pack_results("Premium Pack #2 (Seed 12345)", seeded_pack_2)

	# Verify determinism
	if _packs_are_identical(seeded_pack_1, seeded_pack_2):
		print("✓ DETERMINISM VERIFIED: Both packs are identical!")
	else:
		print("✗ ERROR: Packs differ despite same seed")

	# Example 4: Legendary pack
	print("\n--- Example 4: Legendary Pack ---")
	var legendary_pack = PackGenerator.generate_pack(
		PackGenerator.PackType.LEGENDARY,
		card_pool,
		-1
	)
	_print_pack_results("Legendary Pack (Random)", legendary_pack)

	# Example 5: Get pack odds
	print("\n--- Example 5: Pack Odds Analysis ---")
	for pack_type in [PackGenerator.PackType.BASIC, PackGenerator.PackType.PREMIUM, PackGenerator.PackType.LEGENDARY]:
		var odds = PackGenerator.get_pack_odds(pack_type)
		var type_names = ["BASIC", "PREMIUM", "LEGENDARY"]
		print("%s Pack: %d cards - %s" % [type_names[pack_type], odds.card_count, odds.description])

	# Example 6: Generate multiple packs
	print("\n--- Example 6: Batch Generation (3 Basic Packs) ---")
	var multiple_packs = PackGenerator.generate_multiple_packs(
		PackGenerator.PackType.BASIC,
		card_pool,
		3,
		-1  # Random
	)
	for i in range(multiple_packs.size()):
		var pack = multiple_packs[i]
		_print_pack_results("Batch Pack #%d" % (i + 1), pack)


func _create_demo_card_pool() -> Array[CardData]:
	var pool: Array[CardData] = []

	# Add some common cards
	for i in range(5):
		var card = CardData.new()
		card.card_name = "Common Unit %d" % (i + 1)
		card.card_id = "common_%d" % i
		card.rarity = CardData.Rarity.COMMON
		card.card_type = CardData.CardType.UNIT
		card.energy_cost = 2
		card.health = 100
		card.attack = 15
		pool.append(card)

	# Add rare cards
	for i in range(3):
		var card = CardData.new()
		card.card_name = "Rare Unit %d" % (i + 1)
		card.card_id = "rare_%d" % i
		card.rarity = CardData.Rarity.RARE
		card.card_type = CardData.CardType.UNIT
		card.energy_cost = 3
		card.health = 150
		card.attack = 25
		pool.append(card)

	# Add epic cards
	for i in range(2):
		var card = CardData.new()
		card.card_name = "Epic Unit %d" % (i + 1)
		card.card_id = "epic_%d" % i
		card.rarity = CardData.Rarity.EPIC
		card.card_type = CardData.CardType.UNIT
		card.energy_cost = 4
		card.health = 200
		card.attack = 35
		pool.append(card)

	# Add legendary card
	var legendary = CardData.new()
	legendary.card_name = "Legendary Hero"
	legendary.card_id = "legendary_1"
	legendary.rarity = CardData.Rarity.LEGENDARY
	legendary.card_type = CardData.CardType.COMMANDER
	legendary.energy_cost = 5
	legendary.health = 300
	legendary.attack = 50
	pool.append(legendary)

	return pool


func _print_pack_results(label: String, pack: Array[CardData]) -> void:
	print("%s:" % label)
	for i in range(pack.size()):
		var card = pack[i]
		print("  [%d] %s - %s (HP:%d ATK:%d)" % [
			i + 1,
			card.get_rarity_name(),
			card.card_name,
			int(card.health),
			int(card.attack)
		])


func _packs_are_identical(pack1: Array[CardData], pack2: Array[CardData]) -> bool:
	if pack1.size() != pack2.size():
		return false

	for i in range(pack1.size()):
		if pack1[i].card_id != pack2[i].card_id:
			return false
		if pack1[i].rarity != pack2[i].rarity:
			return false

	return true
