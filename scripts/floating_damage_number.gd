extends Label
class_name FloatingDamageNumber

## Floating damage number that appears when units/cores take damage

func initialize(damage: float, start_pos: Vector2) -> void:
	# Set text to damage amount
	text = str(int(damage))

	# Position above the damaged entity
	global_position = start_pos + Vector2(-10, -30)

	# Style
	add_theme_font_size_override("font_size", 20)
	add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	add_theme_constant_override("outline_size", 2)

	# Animate upward and fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position:y", global_position.y - 40, 0.8)
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(queue_free)
