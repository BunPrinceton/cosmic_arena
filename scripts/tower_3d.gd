extends Node3D
class_name Tower3D

## A tower structure that protects a lane
## Must be destroyed before units can reach the base in that lane

signal health_changed(current: float, maximum: float)
signal tower_destroyed(tower: Tower3D)

@export var max_health: float = 500.0
@export var team: int = 0  # 0 = player, 1 = enemy

var current_health: float = 0.0
var is_destroyed: bool = false

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

func take_damage(amount: float) -> void:
	if is_destroyed:
		return

	current_health -= amount
	current_health = max(0, current_health)
	health_changed.emit(current_health, max_health)
	print("%s took %.1f damage, health: %.1f/%.1f" % [name, amount, current_health, max_health])

	if current_health <= 0:
		_on_destroyed()

func _on_destroyed() -> void:
	is_destroyed = true
	print("Tower %s destroyed!" % name)
	tower_destroyed.emit(self)

	# Hide the tower visually but keep the node for reference
	visible = false

	# Disable collision if there is one
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = true

func get_team() -> int:
	return team

func is_alive() -> bool:
	return not is_destroyed

func heal(amount: float) -> void:
	if is_destroyed:
		return
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func get_health_percentage() -> float:
	return current_health / max_health if max_health > 0 else 0.0
