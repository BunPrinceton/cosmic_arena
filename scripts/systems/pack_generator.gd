extends RefCounted
class_name PackGenerator

## Pure pack generation system - UI-independent
## Generates card packs using weighted random distribution
## Can be seeded for deterministic testing

enum PackType {
	BASIC,       # 4 cards, mostly common
	PREMIUM,     # 5 cards, guaranteed rare+
	LEGENDARY    # 6 cards, guaranteed epic+, chance for legendary
}

## Pack configuration - defines card counts and guarantees
const PACK_CONFIG = {
	PackType.BASIC: {
		"card_count": 4,
		"guaranteed_rare": false,
		"guaranteed_epic": false
	},
	PackType.PREMIUM: {
		"card_count": 5,
		"guaranteed_rare": true,
		"guaranteed_epic": false
	},
	PackType.LEGENDARY: {
		"card_count": 6,
		"guaranteed_rare": true,
		"guaranteed_epic": true
	}
}


## Generate a pack of cards
## @param pack_type: Type of pack to generate (BASIC, PREMIUM, LEGENDARY)
## @param card_pool: Available cards to draw from (must be non-empty)
## @param seed: RNG seed for deterministic generation. -1 = use random seed
## @return: Array of CardData sorted by rarity (common first, legendary last)
static func generate_pack(
	pack_type: PackType,
	card_pool: Array[CardData],
	seed: int = -1
) -> Array[CardData]:
	if card_pool.is_empty():
		push_error("PackGenerator: Cannot generate pack from empty card pool")
		return []

	var config = PACK_CONFIG[pack_type]
	var card_count = config.card_count

	# Create RNG with optional seed for determinism
	var rng = RandomNumberGenerator.new()
	if seed != -1:
		rng.seed = seed
	else:
		rng.randomize()

	var generated_cards: Array[CardData] = []

	# Generate each card in the pack
	for i in range(card_count):
		var card = _roll_card(i, config, card_pool, rng)
		generated_cards.append(card)

	# Sort by rarity (legendary last for dramatic reveal)
	generated_cards.sort_custom(func(a, b): return a.rarity < b.rarity)

	return generated_cards


## Roll a single card based on pack guarantees and position
## @param index: Position in pack (last cards get guarantees)
## @param config: Pack configuration dictionary
## @param card_pool: Available cards to draw from
## @param rng: Random number generator to use
## @return: Generated CardData
static func _roll_card(
	index: int,
	config: Dictionary,
	card_pool: Array[CardData],
	rng: RandomNumberGenerator
) -> CardData:
	var guaranteed_epic = config.get("guaranteed_epic", false)
	var guaranteed_rare = config.get("guaranteed_rare", false)

	# Last card gets guaranteed rarity
	var is_last = index == config.card_count - 1
	var is_second_last = index == config.card_count - 2

	var min_rarity = CardData.Rarity.COMMON

	if is_last and guaranteed_epic:
		min_rarity = CardData.Rarity.EPIC
	elif (is_last or is_second_last) and guaranteed_rare:
		min_rarity = CardData.Rarity.RARE

	# Roll rarity based on weights and minimum
	var rarity = _roll_rarity(min_rarity, rng)

	# Pick a random card from pool matching rarity
	var matching_cards = card_pool.filter(func(c): return c.rarity == rarity)

	if matching_cards.size() > 0:
		var random_index = rng.randi() % matching_cards.size()
		return matching_cards[random_index]
	else:
		# No cards of this rarity in pool - generate placeholder
		return _create_placeholder_card(rarity, rng)


## Roll a rarity using weighted probability
## @param min_rarity: Minimum rarity allowed (for pack guarantees)
## @param rng: Random number generator to use
## @return: Rolled rarity enum value
static func _roll_rarity(min_rarity: CardData.Rarity, rng: RandomNumberGenerator) -> CardData.Rarity:
	var weights = CardData.RARITY_WEIGHTS.duplicate()

	# Zero out weights below minimum (for guaranteed rarities)
	for r in weights:
		if r < min_rarity:
			weights[r] = 0

	# Calculate total weight
	var total = 0
	for w in weights.values():
		total += w

	# Roll and find result
	var roll = rng.randi() % total
	var cumulative = 0

	for r in weights:
		cumulative += weights[r]
		if roll < cumulative:
			return r

	return min_rarity


## Create a placeholder card when no real cards match the rarity
## Used for testing or when card pool is limited
## @param rarity: Rarity of card to create
## @param rng: Random number generator to use
## @return: Generated placeholder CardData
static func _create_placeholder_card(rarity: CardData.Rarity, rng: RandomNumberGenerator) -> CardData:
	var card = CardData.new()
	var rarity_names = ["Common", "Rare", "Epic", "Legendary"]
	var unit_names = ["Soldier", "Knight", "Mage", "Champion", "Guardian", "Striker", "Assassin", "Healer"]

	var unit_name = unit_names[rng.randi() % unit_names.size()]
	card.card_name = unit_name + " " + rarity_names[rarity]
	card.card_id = "generated_" + str(rng.randi())
	card.rarity = rarity
	card.card_type = CardData.CardType.UNIT
	card.energy_cost = 2 + rarity
	card.health = 80 + rarity * 30
	card.attack = 10 + rarity * 8
	card.speed = 80 + rarity * 5
	card.description = "A powerful %s unit." % card.get_rarity_name().to_lower()

	return card


## Utility: Generate multiple packs at once
## Useful for batch operations or rewards
## @param pack_type: Type of pack to generate
## @param card_pool: Available cards to draw from
## @param count: Number of packs to generate
## @param base_seed: Base seed for deterministic generation. -1 = random
## @return: Array of pack results, where each result is an Array[CardData]
static func generate_multiple_packs(
	pack_type: PackType,
	card_pool: Array[CardData],
	count: int,
	base_seed: int = -1
) -> Array:
	var results: Array = []

	for i in range(count):
		# Use incremented seed for deterministic but varied results
		var pack_seed = -1
		if base_seed != -1:
			pack_seed = base_seed + i

		var pack = generate_pack(pack_type, card_pool, pack_seed)
		results.append(pack)

	return results


## Utility: Preview pack odds without generating
## @param pack_type: Type of pack to analyze
## @return: Dictionary with expected rarity distribution
static func get_pack_odds(pack_type: PackType) -> Dictionary:
	var config = PACK_CONFIG[pack_type]
	var card_count = config.card_count
	var guaranteed_rare = config.get("guaranteed_rare", false)
	var guaranteed_epic = config.get("guaranteed_epic", false)

	return {
		"card_count": card_count,
		"guaranteed_rare": guaranteed_rare,
		"guaranteed_epic": guaranteed_epic,
		"min_legendary": 0,
		"min_epic": 1 if guaranteed_epic else 0,
		"min_rare": 1 if guaranteed_rare else 0,
		"description": _get_odds_description(pack_type)
	}


## Generate human-readable odds description
static func _get_odds_description(pack_type: PackType) -> String:
	var config = PACK_CONFIG[pack_type]
	var guaranteed_epic = config.get("guaranteed_epic", false)
	var guaranteed_rare = config.get("guaranteed_rare", false)

	if guaranteed_epic:
		return "Epic+ Guaranteed"
	elif guaranteed_rare:
		return "Rare+ Guaranteed"
	else:
		return "No Guarantees"
