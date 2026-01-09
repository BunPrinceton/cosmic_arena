extends Resource
class_name CardData

## Card data resource for the pack opening system
## Defines individual cards that can be obtained from packs

enum Rarity {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
}

enum CardType {
	UNIT,
	COMMANDER,
	ABILITY,
	EQUIPMENT
}

@export_group("Identity")
@export var card_name: String = "Card"
@export var card_id: String = ""  # Unique identifier
@export_multiline var description: String = ""
@export var card_type: CardType = CardType.UNIT
@export var rarity: Rarity = Rarity.COMMON

@export_group("Visuals")
@export var card_art: Texture2D  # Card artwork
@export var frame_color: Color = Color(0.3, 0.3, 0.35, 1.0)
@export var icon_text: String = ""  # Fallback text if no art (e.g., "GR" for Grunt)

@export_group("Stats")
@export var energy_cost: float = 2.0
@export var health: float = 100.0
@export var attack: float = 10.0
@export var speed: float = 80.0

@export_group("Linked Resources")
@export var unit_data: UnitData  # Link to actual unit if this is a unit card
@export var commander_data: CommanderData  # Link to commander if commander card

## Rarity colors matching main_menu.gd
const RARITY_COLORS = {
	Rarity.COMMON: Color(0.3, 0.3, 0.35, 1.0),
	Rarity.RARE: Color(0.2, 0.4, 0.7, 1.0),
	Rarity.EPIC: Color(0.5, 0.2, 0.6, 1.0),
	Rarity.LEGENDARY: Color(0.8, 0.6, 0.2, 1.0)
}

## Rarity glow colors (brighter for effects)
const RARITY_GLOW_COLORS = {
	Rarity.COMMON: Color(0.5, 0.5, 0.6, 1.0),
	Rarity.RARE: Color(0.3, 0.6, 1.0, 1.0),
	Rarity.EPIC: Color(0.8, 0.3, 1.0, 1.0),
	Rarity.LEGENDARY: Color(1.0, 0.85, 0.3, 1.0)
}

## Rarity names for display
const RARITY_NAMES = {
	Rarity.COMMON: "Common",
	Rarity.RARE: "Rare",
	Rarity.EPIC: "Epic",
	Rarity.LEGENDARY: "Legendary"
}

## Drop weights for pack opening (higher = more common)
const RARITY_WEIGHTS = {
	Rarity.COMMON: 60,
	Rarity.RARE: 25,
	Rarity.EPIC: 12,
	Rarity.LEGENDARY: 3
}

func get_rarity_color() -> Color:
	return RARITY_COLORS.get(rarity, RARITY_COLORS[Rarity.COMMON])

func get_glow_color() -> Color:
	return RARITY_GLOW_COLORS.get(rarity, RARITY_GLOW_COLORS[Rarity.COMMON])

func get_rarity_name() -> String:
	return RARITY_NAMES.get(rarity, "Common")

func get_display_icon() -> String:
	if icon_text:
		return icon_text
	return card_name.substr(0, 2).to_upper()

## Create CardData from existing UnitData
static func from_unit_data(unit: UnitData, card_rarity: Rarity = Rarity.COMMON) -> CardData:
	var card = CardData.new()
	card.card_name = unit.unit_name
	card.card_id = "unit_" + unit.unit_name.to_lower().replace(" ", "_")
	card.description = unit.description
	card.card_type = CardType.UNIT
	card.rarity = card_rarity
	card.frame_color = unit.visual_color
	card.energy_cost = unit.energy_cost
	card.health = unit.max_health
	card.attack = unit.attack_damage
	card.speed = unit.move_speed
	card.unit_data = unit
	return card

## Create CardData from existing CommanderData
static func from_commander_data(commander: CommanderData, card_rarity: Rarity = Rarity.LEGENDARY) -> CardData:
	var card = CardData.new()
	card.card_name = commander.commander_name
	card.card_id = "commander_" + commander.commander_name.to_lower().replace(" ", "_")
	card.description = commander.description if commander.description else "A powerful commander."
	card.card_type = CardType.COMMANDER
	card.rarity = card_rarity
	card.frame_color = commander.portrait_color
	card.health = commander.max_health
	card.attack = commander.attack_damage
	card.speed = commander.move_speed
	card.commander_data = commander
	return card
