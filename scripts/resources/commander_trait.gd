extends Resource
class_name CommanderTrait

## Passive trait/modifier for commanders
## Affects gameplay through various modifiers

enum TraitType {
	ENERGY_REGEN_BONUS,      # Increases energy regeneration
	UNIT_DAMAGE_BONUS,       # Increases damage of deployed units
	UNIT_HEALTH_BONUS,       # Increases health of deployed units
	UNIT_SPEED_BONUS,        # Increases movement speed of deployed units
	REDUCED_UNIT_COST,       # Reduces energy cost of units
	COMMANDER_DAMAGE_BONUS,  # Increases commander's own damage
	COMMANDER_SPEED_BONUS,   # Increases commander's movement speed
}

@export var trait_name: String = "Unnamed Trait"
@export_multiline var description: String = ""
@export var trait_type: TraitType = TraitType.ENERGY_REGEN_BONUS
@export var modifier_value: float = 0.0  # Amount of modification (e.g., 0.2 = +20%)

## Returns formatted text for UI
func get_trait_text() -> String:
	var modifier_percent = int(modifier_value * 100)
	var sign = "+" if modifier_value >= 0 else ""
	return "%s: %s%d%%" % [trait_name, sign, modifier_percent]

## Applies the trait modifier to a target value
func apply_modifier(base_value: float) -> float:
	return base_value * (1.0 + modifier_value)

## Gets a human-readable description with the modifier
func get_full_description() -> String:
	var modifier_percent = int(modifier_value * 100)
	var sign = "+" if modifier_value >= 0 else ""
	return "%s (%s%d%%)\n%s" % [trait_name, sign, modifier_percent, description]
