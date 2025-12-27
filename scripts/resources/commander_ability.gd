extends Resource
class_name CommanderAbility

## Active ability definition for commanders
## Defines what happens when ability is used

enum AbilityType {
	AOE_DAMAGE,          # Area of effect damage around commander
	HEAL_ALLIES,         # Heal nearby allies
	SPEED_BOOST,         # Temporary speed boost to commander
	SUMMON_UNITS,        # Spawn units around commander
	ENERGY_BURST,        # Gain bonus energy
	DAMAGE_BUFF,         # Temporary damage boost to nearby units
}

@export var ability_name: String = "Unnamed Ability"
@export_multiline var description: String = ""
@export var ability_type: AbilityType = AbilityType.AOE_DAMAGE
@export var cooldown: float = 10.0
@export var ability_range: float = 150.0
@export var power: float = 50.0  # Damage, heal amount, speed multiplier, etc.
@export var duration: float = 0.0  # For timed effects (0 = instant)
@export var visual_color: Color = Color(0.5, 0.7, 1.0)

## Returns formatted text for UI
func get_ability_text() -> String:
	return "%s (CD: %.0fs)" % [ability_name, cooldown]

## Gets a human-readable description with stats
func get_full_description() -> String:
	var stats = ""
	match ability_type:
		AbilityType.AOE_DAMAGE:
			stats = "Damage: %.0f | Range: %.0f" % [power, ability_range]
		AbilityType.HEAL_ALLIES:
			stats = "Heal: %.0f | Range: %.0f" % [power, ability_range]
		AbilityType.SPEED_BOOST:
			stats = "Speed: +%.0f%% | Duration: %.0fs" % [power, duration]
		AbilityType.SUMMON_UNITS:
			stats = "Units: %.0f | Range: %.0f" % [power, ability_range]
		AbilityType.ENERGY_BURST:
			stats = "Energy: +%.0f" % power
		AbilityType.DAMAGE_BUFF:
			stats = "Damage: +%.0f%% | Duration: %.0fs" % [power, duration]

	return "%s\n%s\nCooldown: %.0fs\n%s" % [ability_name, stats, cooldown, description]
