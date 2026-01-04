extends Resource
class_name CommanderData

## ScriptableObject-style data resource for commander stats, traits, and abilities
## Separates data from logic for easier balancing and commander variety

@export_group("Identity")
@export var commander_name: String = "Commander"
@export_multiline var description: String = ""
@export var visual_color: Color = Color(0.2, 0.7, 1.0)
@export var portrait_color: Color = Color(0.3, 0.6, 0.9)  # For UI portraits

@export_group("Stats")
@export var max_health: float = 500.0
@export var move_speed: float = 200.0
@export var attack_damage: float = 30.0
@export var attack_range: float = 100.0
@export var attack_cooldown: float = 1.0

@export_group("Passive Trait")
@export var passive_trait: CommanderTrait

@export_group("Active Ability")
@export var active_ability: CommanderAbility

@export_group("Special Unit")
@export var special_unit: UnitData  # Commander's unique special unit

@export_group("Visual")
@export var visual_size: Vector2 = Vector2(40, 40)

## Returns a formatted string with commander info for UI
func get_info_text() -> String:
	var text = "%s\n%s\n\n" % [commander_name, description]

	text += "Stats:\n"
	text += "HP: %.0f | DMG: %.0f | SPD: %.0f\n\n" % [max_health, attack_damage, move_speed]

	if passive_trait:
		text += "Passive: %s\n" % passive_trait.get_trait_text()

	if active_ability:
		text += "Ability: %s\n" % active_ability.get_ability_text()

	return text

## Returns short name + trait for deck builder
func get_card_text() -> String:
	var text = commander_name
	if passive_trait:
		text += "\n" + passive_trait.trait_name
	return text
