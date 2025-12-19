extends UnitBase
class_name UnitSupport

## Support unit - heals nearby allies instead of attacking enemies

var heal_amount: float = 20.0
var heal_range: float = 100.0

func _ready() -> void:
	super._ready()

	# Load heal properties from unit_data if it's a support unit
	if unit_data and unit_data.is_support:
		heal_amount = unit_data.heal_amount
		heal_range = unit_data.heal_range

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	# Update attack timer (used for heal cooldown)
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true

	# Find allies to heal
	var allies = find_allies_in_range()

	if not allies.is_empty():
		# Found ally to heal
		var ally_to_heal = allies[0]
		heal_ally(ally_to_heal)
		velocity = Vector2.ZERO
	else:
		# No allies to heal, move forward
		move_forward()

	move_and_slide()

func find_allies_in_range() -> Array:
	var allies = []
	var potential_targets = get_tree().get_nodes_in_group("units")
	potential_targets.append_array(get_tree().get_nodes_in_group("commanders"))

	for body in potential_targets:
		if body == self:
			continue
		if "team" not in body or body.team != team:
			continue

		# Only heal damaged allies
		if "current_health" in body and "max_health" in body:
			if body.current_health < body.max_health:
				if global_position.distance_to(body.global_position) <= heal_range:
					allies.append(body)

	# Sort by health (heal most damaged first)
	allies.sort_custom(func(a, b): return a.current_health / a.max_health < b.current_health / b.max_health)

	return allies

func heal_ally(target: Node2D) -> void:
	if not target or not is_instance_valid(target):
		return

	if can_attack:
		if target.has_method("heal"):
			target.heal(heal_amount)

			# Visual effect - green particles or glow
			var heal_effect = ColorRect.new()
			heal_effect.custom_minimum_size = Vector2(20, 20)
			heal_effect.position = Vector2(-10, -10)
			heal_effect.color = Color(0.3, 1.0, 0.3, 0.7)
			target.add_child(heal_effect)

			var tween = create_tween()
			tween.tween_property(heal_effect, "modulate:a", 0.0, 0.5)
			tween.tween_callback(heal_effect.queue_free)

		can_attack = false
		attack_timer = attack_cooldown
