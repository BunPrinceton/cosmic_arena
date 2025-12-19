extends StaticBody2D
class_name Core

## The base/core that teams must defend and destroy

signal core_destroyed
signal health_changed(current: float, maximum: float)

# Preload floating damage number
const FLOATING_DAMAGE = preload("res://scenes/floating_damage_number.tscn")

@export var max_health: float = 1000.0
@export var team: int = 0

var current_health: float
var is_alive: bool = true

func _ready() -> void:
	current_health = max_health
	add_to_group("cores")
	health_changed.emit(current_health, max_health)

	# Set collision layers
	if team == 0:
		collision_layer = 1
		collision_mask = 2
	else:
		collision_layer = 2
		collision_mask = 1

func take_damage(amount: float) -> void:
	if not is_alive:
		return

	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)

	# Flash when damaged
	if has_node("Visual"):
		var visual = get_node("Visual")
		var original_color = visual.color
		visual.color = Color(1.5, 0.5, 0.5)
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(visual):
			visual.color = original_color

	# Spawn floating damage number
	spawn_damage_number(amount)

	if current_health <= 0:
		die()

func spawn_damage_number(damage: float) -> void:
	var damage_label = FLOATING_DAMAGE.instantiate()
	get_tree().root.add_child(damage_label)
	damage_label.initialize(damage, global_position)

func die() -> void:
	if not is_alive:
		return

	is_alive = false
	core_destroyed.emit()
	print("Core destroyed! Team: ", team)

	# Visual destruction effect
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0.3, 0.3, 0.3, 0.5), 0.5)
