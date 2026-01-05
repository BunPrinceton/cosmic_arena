extends StaticBody3D
class_name Base3D

## A base structure that can be attacked and destroyed

signal health_changed(current: float, maximum: float)
signal base_destroyed(base: Base3D)

@export var max_health: float = 1000.0
@export var team: int = 0  # 0 = player, 1 = enemy
@export var hp_bar_height: float = 8.0  # Height above base for HP bar
@export var chunk_count: int = 20  # Number of chunks (1000 HP / 20 = 50 per chunk)

var current_health: float = 0.0
var is_destroyed: bool = false

# HP Bar
var hp_bar_container: Node3D = null
var hp_chunks: Array[MeshInstance3D] = []
var hp_bar_background: MeshInstance3D = null
const HP_BAR_WIDTH: float = 5.0  # Wider bar for base
const HP_BAR_CHUNK_HEIGHT: float = 0.5
const HP_BAR_GAP: float = 0.04

func _ready() -> void:
	current_health = max_health
	# Don't modify collision layers - let the scene handle it
	# The base should already have appropriate collision from the scene file
	_create_hp_bar()
	health_changed.emit(current_health, max_health)

func _create_hp_bar() -> void:
	# Check if HP bar already exists (avoid duplicates)
	if hp_bar_container != null:
		return
	var existing = get_node_or_null("HPBarContainer")
	if existing:
		hp_bar_container = existing
		return

	# Container that will billboard toward camera
	hp_bar_container = Node3D.new()
	hp_bar_container.name = "HPBarContainer"
	hp_bar_container.position.y = hp_bar_height
	add_child(hp_bar_container)

	# Calculate total bar width with gaps
	var chunk_width = (HP_BAR_WIDTH - (chunk_count - 1) * HP_BAR_GAP) / chunk_count
	var start_x = -HP_BAR_WIDTH / 2.0 + chunk_width / 2.0

	# Create background
	hp_bar_background = MeshInstance3D.new()
	var bg_mesh = BoxMesh.new()
	bg_mesh.size = Vector3(HP_BAR_WIDTH + 0.1, HP_BAR_CHUNK_HEIGHT + 0.1, 0.05)
	hp_bar_background.mesh = bg_mesh
	hp_bar_background.position.z = 0.03

	var bg_material = StandardMaterial3D.new()
	bg_material.albedo_color = Color(0.1, 0.1, 0.1, 0.8)
	bg_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hp_bar_background.material_override = bg_material
	hp_bar_container.add_child(hp_bar_background)

	# Create chunks
	for i in range(chunk_count):
		var chunk = MeshInstance3D.new()
		var chunk_mesh = BoxMesh.new()
		chunk_mesh.size = Vector3(chunk_width, HP_BAR_CHUNK_HEIGHT, 0.08)
		chunk.mesh = chunk_mesh
		chunk.position.x = start_x + i * (chunk_width + HP_BAR_GAP)

		var chunk_material = StandardMaterial3D.new()
		chunk_material.albedo_color = Color(0.2, 0.9, 0.2)
		chunk_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		chunk.material_override = chunk_material

		hp_bar_container.add_child(chunk)
		hp_chunks.append(chunk)

	_update_hp_bar()

func _process(_delta: float) -> void:
	# HP bar faces perpendicular to lanes (fixed rotation facing positive Z)
	if hp_bar_container and not is_destroyed:
		hp_bar_container.rotation.y = 0

func _update_hp_bar() -> void:
	var health_percent = current_health / max_health
	var chunks_filled = int(ceil(health_percent * chunk_count))

	for i in range(chunk_count):
		var chunk = hp_chunks[i]
		var chunk_material = chunk.material_override as StandardMaterial3D

		if i < chunks_filled:
			chunk.visible = true
			chunk_material.albedo_color = _get_health_color(health_percent)
		else:
			chunk.visible = false

func _get_health_color(percent: float) -> Color:
	if percent > 0.75:
		var t = (percent - 0.75) / 0.25
		return Color(1.0 - t * 0.8, 0.9, 0.2)
	elif percent > 0.5:
		var t = (percent - 0.5) / 0.25
		return Color(1.0, 0.5 + t * 0.4, 0.1)
	elif percent > 0.25:
		var t = (percent - 0.25) / 0.25
		return Color(1.0, 0.2 + t * 0.3, 0.1)
	else:
		return Color(0.9, 0.15, 0.1)

func take_damage(amount: float) -> void:
	if is_destroyed:
		return

	current_health -= amount
	current_health = max(0, current_health)
	health_changed.emit(current_health, max_health)
	_update_hp_bar()
	print("Base took %.1f damage, health: %.1f/%.1f" % [amount, current_health, max_health])

	if current_health <= 0:
		_on_destroyed()

func _on_destroyed() -> void:
	is_destroyed = true
	print("Base destroyed!")
	base_destroyed.emit(self)

	if hp_bar_container:
		hp_bar_container.visible = false

func get_team() -> int:
	return team

func is_alive() -> bool:
	return not is_destroyed

func heal(amount: float) -> void:
	if is_destroyed:
		return
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
	_update_hp_bar()

func get_health_percentage() -> float:
	return current_health / max_health if max_health > 0 else 0.0
