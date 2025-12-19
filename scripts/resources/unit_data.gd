extends Resource
class_name UnitData

## ScriptableObject-style data resource for unit stats and properties
## Separates data from logic for easier balancing and modding

@export_group("Identity")
@export var unit_name: String = "Unit"
@export_multiline var description: String = ""
@export var visual_color: Color = Color.WHITE

@export_group("Stats")
@export var max_health: float = 100.0
@export var move_speed: float = 80.0
@export var attack_damage: float = 10.0
@export var attack_range: float = 60.0
@export var attack_cooldown: float = 1.5
@export var vision_range: float = 150.0

@export_group("Deployment")
@export var energy_cost: float = 2.0
@export var visual_size: Vector2 = Vector2(20, 20)

@export_group("Special Properties")
@export var is_ranged: bool = false
@export var is_support: bool = false
@export var heal_amount: float = 0.0
@export var heal_range: float = 0.0

## Returns a formatted string with unit stats for UI tooltips
func get_stats_text() -> String:
	var stats = "%s (Cost: %.1f)\n" % [unit_name, energy_cost]
	stats += "HP: %.0f | DMG: %.0f | SPD: %.0f\n" % [max_health, attack_damage, move_speed]
	stats += "Range: %.0f" % attack_range

	if is_support and heal_amount > 0:
		stats += "\nHeals: %.0f HP" % heal_amount

	return stats
