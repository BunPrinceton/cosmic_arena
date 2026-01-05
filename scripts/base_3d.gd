extends StaticBody3D
class_name Base3D

## A base structure that can be attacked and destroyed

signal health_changed(current: float, maximum: float)
signal base_destroyed(base: Base3D)

@export var max_health: float = 1000.0
@export var team: int = 0  # 0 = player, 1 = enemy

var current_health: float = 0.0

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

func take_damage(amount: float) -> void:
	current_health -= amount
	current_health = max(0, current_health)
	health_changed.emit(current_health, max_health)
	print("Base took %.1f damage, health: %.1f/%.1f" % [amount, current_health, max_health])

	if current_health <= 0:
		_on_destroyed()

func _on_destroyed() -> void:
	print("Base destroyed!")
	base_destroyed.emit(self)

func get_team() -> int:
	return team

func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func get_health_percentage() -> float:
	return current_health / max_health if max_health > 0 else 0.0
