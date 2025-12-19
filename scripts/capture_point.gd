extends Area2D
class_name CapturePoint

## Neutral objective that grants bonus energy regeneration when controlled

signal ownership_changed(new_owner: int)  # -1 = neutral, 0 = player, 1 = enemy

@export var capture_radius: float = 100.0
@export var capture_rate: float = 1.0  # Points per second per unit
@export var energy_bonus: float = 0.5  # +50% energy regen when controlled

var capture_progress: float = 0.0  # -100 to +100 (negative = enemy, positive = player)
var current_owner: int = -1  # -1 = neutral, 0 = player, 1 = enemy

# UI elements
@onready var visual = $Visual
@onready var progress_bar = $ProgressBar
@onready var ownership_label = $OwnershipLabel

func _ready() -> void:
	# Add to group for AI detection
	add_to_group("capture_point")

	# Setup collision
	monitoring = true
	monitorable = false

	# Visual setup
	update_visuals()

func _physics_process(delta: float) -> void:
	# Count nearby units by team
	var player_units = 0
	var enemy_units = 0

	var nearby_bodies = get_tree().get_nodes_in_group("units")
	nearby_bodies.append_array(get_tree().get_nodes_in_group("commanders"))

	for body in nearby_bodies:
		if "team" not in body or not "is_alive" in body:
			continue
		if not body.is_alive:
			continue

		var distance = global_position.distance_to(body.global_position)
		if distance <= capture_radius:
			if body.team == 0:
				player_units += 1
			elif body.team == 1:
				enemy_units += 1

	# Calculate capture progress
	var net_capture = (player_units - enemy_units) * capture_rate * delta

	if net_capture != 0:
		capture_progress = clamp(capture_progress + net_capture, -100.0, 100.0)

	# Determine ownership
	var new_owner = current_owner

	if capture_progress >= 75.0:
		new_owner = 0  # Player controlled
	elif capture_progress <= -75.0:
		new_owner = 1  # Enemy controlled
	elif capture_progress > -25.0 and capture_progress < 25.0:
		new_owner = -1  # Neutral

	# Update ownership if changed
	if new_owner != current_owner:
		current_owner = new_owner
		ownership_changed.emit(current_owner)
		update_visuals()

	# Update progress bar
	if progress_bar:
		progress_bar.value = (capture_progress + 100.0) / 2.0  # Convert -100..100 to 0..100

func update_visuals() -> void:
	if not visual or not ownership_label:
		return

	match current_owner:
		-1:  # Neutral
			visual.color = Color(0.5, 0.5, 0.5, 1.0)
			ownership_label.text = "Neutral"
			ownership_label.add_theme_color_override("font_color", Color.WHITE)
		0:  # Player
			visual.color = Color(0.3, 0.7, 1.0, 1.0)
			ownership_label.text = "Player"
			ownership_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		1:  # Enemy
			visual.color = Color(1.0, 0.3, 0.3, 1.0)
			ownership_label.text = "Enemy"
			ownership_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

func get_current_owner() -> int:
	return current_owner

func is_contested() -> bool:
	return abs(capture_progress) < 75.0
