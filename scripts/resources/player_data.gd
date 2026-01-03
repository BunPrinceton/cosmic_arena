extends Resource
class_name PlayerData

## Player progression and currency data
## Stores level, XP, rank, and currencies for the main menu

@export_group("Identity")
@export var player_name: String = "Commander"
@export var player_title: String = "Rookie"

@export_group("Progression")
@export var level: int = 8
@export var current_xp: int = 450
@export var xp_to_next_level: int = 1000
@export var rank_tier: String = "BRONZIUM"
@export var rank_tier_level: int = 4
@export var rank_points: int = 1491

@export_group("Currencies")
@export var credits: int = 1500
@export var gems: int = 361
@export var gold: int = 7620

@export_group("Collection")
@export var cards_owned: int = 31
@export var cards_total: int = 40


## Calculate XP progress as percentage (0.0 - 1.0)
func get_xp_progress() -> float:
	if xp_to_next_level <= 0:
		return 1.0
	return float(current_xp) / float(xp_to_next_level)


## Add XP and handle level-ups, returns true if leveled up
func add_xp(amount: int) -> bool:
	current_xp += amount
	if current_xp >= xp_to_next_level:
		current_xp -= xp_to_next_level
		level += 1
		xp_to_next_level = _calculate_xp_for_level(level + 1)
		return true
	return false


## XP curve formula
func _calculate_xp_for_level(target_level: int) -> int:
	return 100 + (target_level - 1) * 50


## Get formatted rank display string
func get_rank_display() -> String:
	return "%s TIER %d" % [rank_tier, rank_tier_level]
