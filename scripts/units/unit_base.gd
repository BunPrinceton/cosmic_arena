extends CharacterBody2D
class_name UnitBase

## Base class for all deployable units - now uses UnitData resources for stats

signal unit_died

# Preload floating damage number
const FLOATING_DAMAGE = preload("res://scenes/floating_damage_number.tscn")

## Reference to the UnitData resource containing this unit's stats
@export var unit_data: UnitData

## Runtime stats (initialized from unit_data)
var max_health: float = 100.0
var move_speed: float = 80.0
var attack_damage: float = 10.0
var attack_range: float = 60.0
var attack_cooldown: float = 1.5
var energy_cost: float = 2.0
var vision_range: float = 150.0

var current_health: float
var team: int = 0  # 0 = player, 1 = enemy
var is_alive: bool = true
var can_attack: bool = true
var attack_timer: float = 0.0

var current_target: Node2D = null
var move_target: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Load stats from UnitData resource
	if unit_data:
		max_health = unit_data.max_health
		move_speed = unit_data.move_speed
		attack_damage = unit_data.attack_damage
		attack_range = unit_data.attack_range
		attack_cooldown = unit_data.attack_cooldown
		energy_cost = unit_data.energy_cost
		vision_range = unit_data.vision_range

		# Apply visual color if we have a Visual node
		if has_node("Visual"):
			var visual = get_node("Visual")
			if visual is ColorRect:
				visual.color = unit_data.visual_color

	current_health = max_health
	add_to_group("units")

	# Set collision layers based on team
	if team == 0:
		collision_layer = 1
		collision_mask = 2 | 4
	else:
		collision_layer = 2
		collision_mask = 1 | 4

	# Determine initial move direction based on team
	if team == 0:
		move_target = global_position + Vector2(0, -1000)  # Move up
	else:
		move_target = global_position + Vector2(0, 1000)  # Move down

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	# Update attack timer
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true

	# Find enemies
	var enemies = find_enemies_in_range()

	if enemies.is_empty():
		# No enemies, move forward
		move_forward()
		current_target = null
	else:
		# Found enemy, attack
		current_target = enemies[0]
		attack_enemy(current_target)

	move_and_slide()

func move_forward() -> void:
	# Move toward lane target
	var direction = global_position.direction_to(move_target)
	velocity = direction * move_speed

func attack_enemy(target: Node2D) -> void:
	if not target or not is_instance_valid(target):
		return

	var distance = global_position.distance_to(target.global_position)

	if distance <= attack_range:
		# In range, stop and attack
		velocity = Vector2.ZERO

		if can_attack:
			perform_attack(target)
			can_attack = false
			attack_timer = attack_cooldown
	else:
		# Move towards enemy
		var direction = global_position.direction_to(target.global_position)
		velocity = direction * move_speed

func perform_attack(target: Node2D) -> void:
	if target and target.has_method("take_damage"):
		target.take_damage(attack_damage)

func find_enemies_in_range() -> Array:
	var enemies = []
	var potential_targets = get_tree().get_nodes_in_group("units")
	potential_targets.append_array(get_tree().get_nodes_in_group("commanders"))
	potential_targets.append_array(get_tree().get_nodes_in_group("cores"))

	for body in potential_targets:
		if body == self:
			continue
		if "team" not in body or body.team == team:
			continue
		if global_position.distance_to(body.global_position) <= vision_range:
			enemies.append(body)

	# Sort by distance
	enemies.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))

	return enemies

func take_damage(amount: float) -> void:
	if not is_alive:
		return

	current_health = max(0, current_health - amount)

	# Hit flash effect
	hit_flash()

	# Spawn floating damage number
	spawn_damage_number(amount)

	if current_health <= 0:
		die()

func spawn_damage_number(damage: float) -> void:
	var damage_label = FLOATING_DAMAGE.instantiate()
	get_tree().root.add_child(damage_label)
	damage_label.initialize(damage, global_position)

func hit_flash() -> void:
	# White flash for better visibility
	if has_node("Visual"):
		var visual = get_node("Visual")
		var original_color = visual.color if visual is ColorRect else Color.WHITE

		# Flash to bright white
		if visual is ColorRect:
			visual.color = Color(2.0, 2.0, 2.0, 1.0)

		# Tween back to original color
		var tween = create_tween()
		tween.tween_property(visual, "color", original_color, 0.15)

func heal(amount: float) -> void:
	if not is_alive:
		return
	current_health = min(max_health, current_health + amount)

func die() -> void:
	if not is_alive:
		return

	is_alive = false
	unit_died.emit()

	# Simple death effect
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.3)
	tween.tween_callback(queue_free)
