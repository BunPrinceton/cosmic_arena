extends CharacterBody2D
class_name Commander

## Base class for all commanders (heroes) - now uses CommanderData resources

signal commander_died
signal health_changed(current: float, maximum: float)
signal ability_used
signal ability_ready

# Preload floating damage number
const FLOATING_DAMAGE = preload("res://scenes/floating_damage_number.tscn")

## Reference to the CommanderData resource containing this commander's stats
@export var commander_data: CommanderData

## Runtime stats (initialized from commander_data)
var max_health: float = 500.0
var move_speed: float = 200.0
var attack_damage: float = 30.0
var attack_range: float = 100.0
var attack_cooldown: float = 1.0

var current_health: float
var team: int = 0  # 0 = player, 1 = enemy
var can_attack: bool = true
var can_use_ability: bool = true
var is_alive: bool = true

var attack_timer: float = 0.0
var ability_timer: float = 0.0
var current_target: Node2D = null

# References to data resources
var passive_trait: CommanderTrait
var active_ability: CommanderAbility

func _ready() -> void:
	# Load stats from CommanderData resource
	if commander_data:
		max_health = commander_data.max_health
		move_speed = commander_data.move_speed
		attack_damage = commander_data.attack_damage
		attack_range = commander_data.attack_range
		attack_cooldown = commander_data.attack_cooldown

		passive_trait = commander_data.passive_trait
		active_ability = commander_data.active_ability

		# Apply visual color
		if has_node("Visual"):
			var visual = get_node("Visual")
			if visual is ColorRect:
				visual.color = commander_data.visual_color

	current_health = max_health
	health_changed.emit(current_health, max_health)

	# Set collision layer based on team
	if team == 0:
		collision_layer = 1  # Player layer
		collision_mask = 2 | 4  # Can collide with enemy and neutral
	else:
		collision_layer = 2  # Enemy layer
		collision_mask = 1 | 4  # Can collide with player and neutral

func _physics_process(delta: float) -> void:
	# Update timers
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true

	if ability_timer > 0:
		ability_timer -= delta
		if ability_timer <= 0:
			can_use_ability = true
			ability_ready.emit()

func take_damage(amount: float) -> void:
	if not is_alive:
		return

	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)

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
	health_changed.emit(current_health, max_health)

func die() -> void:
	if not is_alive:
		return

	is_alive = false
	commander_died.emit()
	# Simple death animation - just fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func attempt_attack() -> void:
	if not can_attack or not is_alive:
		return

	# Find nearest enemy in range
	var enemies = get_enemies_in_range()
	if enemies.is_empty():
		return

	current_target = enemies[0]
	perform_attack(current_target)

	can_attack = false
	attack_timer = attack_cooldown

func perform_attack(target: Node2D) -> void:
	if target and target.has_method("take_damage"):
		target.take_damage(attack_damage)

func use_ability() -> void:
	if not can_use_ability or not is_alive or not active_ability:
		return

	# Show wind-up indicator before executing
	show_ability_windup()
	await get_tree().create_timer(0.3).timeout

	# Execute data-driven ability
	execute_ability(active_ability)

	can_use_ability = false
	ability_timer = active_ability.cooldown
	ability_used.emit()

func show_ability_windup() -> void:
	# Create expanding ring indicator
	var indicator = ColorRect.new()
	indicator.custom_minimum_size = Vector2(40, 40)
	indicator.position = Vector2(-20, -20)
	indicator.color = Color(active_ability.visual_color.r, active_ability.visual_color.g, active_ability.visual_color.b, 0.7)
	add_child(indicator)

	# Animate: pulse and expand
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(indicator, "custom_minimum_size", Vector2(80, 80), 0.3)
	tween.tween_property(indicator, "position", Vector2(-40, -40), 0.3)
	tween.tween_property(indicator, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(indicator.queue_free)

func execute_ability(ability: CommanderAbility) -> void:
	match ability.ability_type:
		CommanderAbility.AbilityType.AOE_DAMAGE:
			ability_aoe_damage(ability)
		CommanderAbility.AbilityType.HEAL_ALLIES:
			ability_heal_allies(ability)
		CommanderAbility.AbilityType.SPEED_BOOST:
			ability_speed_boost(ability)
		CommanderAbility.AbilityType.SUMMON_UNITS:
			ability_summon_units(ability)
		CommanderAbility.AbilityType.ENERGY_BURST:
			ability_energy_burst(ability)
		CommanderAbility.AbilityType.DAMAGE_BUFF:
			ability_damage_buff(ability)

func ability_aoe_damage(ability: CommanderAbility) -> void:
	print("%s used %s!" % [commander_data.commander_name if commander_data else "Commander", ability.ability_name])

	# Find enemies in range
	var enemies = get_tree().get_nodes_in_group("units")
	enemies.append_array(get_tree().get_nodes_in_group("commanders"))

	for enemy in enemies:
		if enemy == self:
			continue
		if "team" not in enemy or enemy.team == team:
			continue
		if global_position.distance_to(enemy.global_position) <= ability.range:
			if enemy.has_method("take_damage"):
				enemy.take_damage(ability.power)

	# Visual effect
	create_ability_visual(ability)

func ability_heal_allies(ability: CommanderAbility) -> void:
	print("%s used %s!" % [commander_data.commander_name if commander_data else "Commander", ability.ability_name])

	# Heal self
	heal(ability.power)

	# Find allies in range
	var allies = get_tree().get_nodes_in_group("units")
	allies.append_array(get_tree().get_nodes_in_group("commanders"))

	for ally in allies:
		if ally == self:
			continue
		if "team" not in ally or ally.team != team:
			continue
		if global_position.distance_to(ally.global_position) <= ability.range:
			if ally.has_method("heal"):
				ally.heal(ability.power)

	# Visual effect
	create_ability_visual(ability)

func ability_speed_boost(ability: CommanderAbility) -> void:
	print("%s used %s!" % [commander_data.commander_name if commander_data else "Commander", ability.ability_name])

	var original_speed = move_speed
	move_speed *= (1.0 + ability.power / 100.0)

	# Visual effect
	create_ability_visual(ability)

	# Revert after duration
	if ability.duration > 0:
		await get_tree().create_timer(ability.duration).timeout
		move_speed = original_speed

func ability_summon_units(ability: CommanderAbility) -> void:
	# Not implemented yet (would need unit spawning logic)
	print("%s used %s! (Summon not implemented)" % [commander_data.commander_name if commander_data else "Commander", ability.ability_name])
	create_ability_visual(ability)

func ability_energy_burst(ability: CommanderAbility) -> void:
	# Not implemented yet (would need energy system reference)
	print("%s used %s! (Energy burst not implemented)" % [commander_data.commander_name if commander_data else "Commander", ability.ability_name])
	create_ability_visual(ability)

func ability_damage_buff(ability: CommanderAbility) -> void:
	# Not implemented yet (would need unit buff system)
	print("%s used %s! (Damage buff not implemented)" % [commander_data.commander_name if commander_data else "Commander", ability.ability_name])
	create_ability_visual(ability)

func create_ability_visual(ability: CommanderAbility) -> void:
	var visual = ColorRect.new()
	visual.custom_minimum_size = Vector2(ability.range * 2, ability.range * 2)
	visual.position = -Vector2(ability.range, ability.range)
	visual.color = Color(ability.visual_color.r, ability.visual_color.g, ability.visual_color.b, 0.5)
	add_child(visual)

	var tween = create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, 0.5)
	tween.tween_callback(visual.queue_free)

func get_enemies_in_range() -> Array:
	var enemies = []
	var all_bodies = get_tree().get_nodes_in_group("units")
	all_bodies.append_array(get_tree().get_nodes_in_group("commanders"))
	all_bodies.append_array(get_tree().get_nodes_in_group("cores"))

	for body in all_bodies:
		if body == self:
			continue
		if "team" not in body or body.team == team:
			continue
		if global_position.distance_to(body.global_position) <= attack_range:
			enemies.append(body)

	return enemies
