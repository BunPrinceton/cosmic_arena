extends Node2D

## Main game scene - integrates all systems (now uses deck system)

# Preload unit scenes
const GRUNT_SCENE = preload("res://units/grunt.tscn")
const RANGER_SCENE = preload("res://units/ranger.tscn")
const TANK_SCENE = preload("res://units/tank.tscn")
const SUPPORT_SCENE = preload("res://units/support.tscn")

# Preload unit data resources
const GRUNT_DATA = preload("res://resources/units/grunt_data.tres")
const RANGER_DATA = preload("res://resources/units/ranger_data.tres")
const TANK_DATA = preload("res://resources/units/tank_data.tres")
const SUPPORT_DATA = preload("res://resources/units/support_data.tres")

# Mapping from UnitData to PackedScene
var unit_scene_map: Dictionary = {}

# Systems
var game_manager: GameManager
var player_energy_system: EnergySystem
var enemy_energy_system: EnergySystem
var ai_controller: AIController

# References
@onready var hud = $HUD
@onready var arena = $Arena
@onready var player_core = $PlayerCore
@onready var enemy_core = $EnemyCore
@onready var player_commander = $PlayerCommander
@onready var enemy_commander = $EnemyCommander
@onready var capture_point = $CapturePoint
@onready var camera = $Camera3D

# Camera shake state
var camera_shake_amount: float = 0.0

# Lane selection
var selected_lane: String = "center"

# Deck references
var player_deck: Deck
var ai_deck: Deck

# Capture point state
var base_player_energy_regen: float = 1.5
var base_enemy_energy_regen: float = 1.2


func _ready() -> void:

	# Activate camera
	camera.make_current()
	var asset_manager = AssetManager.new()
	asset_manager.load_my_test_glb()


	# Initialize unit scene mapping
	unit_scene_map[GRUNT_DATA] = GRUNT_SCENE
	unit_scene_map[RANGER_DATA] = RANGER_SCENE
	unit_scene_map[TANK_DATA] = TANK_SCENE
	unit_scene_map[SUPPORT_DATA] = SUPPORT_SCENE

	# Get decks from GameState
	player_deck = GameState.player_deck
	ai_deck = GameState.ai_deck

	# Initialize game manager
	game_manager = GameManager.new()
	add_child(game_manager)

	# Initialize energy systems
	player_energy_system = EnergySystem.new()
	player_energy_system.max_energy = 10.0
	player_energy_system.energy_regen_rate = 1.5
	player_energy_system.starting_energy = 5.0
	add_child(player_energy_system)

	enemy_energy_system = EnergySystem.new()
	enemy_energy_system.max_energy = 10.0
	enemy_energy_system.energy_regen_rate = 1.2
	enemy_energy_system.starting_energy = 5.0
	add_child(enemy_energy_system)

	# Initialize AI controller with AI's deck
	ai_controller = AIController.new()
	ai_controller.energy_system = enemy_energy_system
	ai_controller.deployment_cooldown = 4.0

	# Build AI unit scenes from deck
	var ai_unit_scenes: Array[PackedScene] = []
	for unit_data in ai_deck.units:
		if unit_data in unit_scene_map:
			ai_unit_scenes.append(unit_scene_map[unit_data])

	ai_controller.unit_scenes = ai_unit_scenes
	add_child(ai_controller)

	# Set up AI deployment positions
	var ai_positions: Array[Vector2] = [
		arena.get_enemy_deployment_position("left"),
		arena.get_enemy_deployment_position("center"),
		arena.get_enemy_deployment_position("right")
	]
	ai_controller.set_deployment_positions(ai_positions)

	# Register cores with game manager
	game_manager.register_player_core(player_core)
	game_manager.register_enemy_core(enemy_core)

	# Connect core health to HUD
	player_core.health_changed.connect(hud.update_player_health)
	enemy_core.health_changed.connect(hud.update_enemy_health)

	# Connect cores to camera shake
	player_core.health_changed.connect(_on_core_damaged)
	enemy_core.health_changed.connect(_on_core_damaged)

	# Setup HUD with player deck
	hud.setup(player_energy_system, game_manager, player_deck, self)

	# Connect capture point
	if capture_point:
		capture_point.ownership_changed.connect(_on_capture_point_ownership_changed)

func _on_capture_point_ownership_changed(new_owner: int) -> void:
	# Reset both to base values
	player_energy_system.energy_regen_rate = base_player_energy_regen
	enemy_energy_system.energy_regen_rate = base_enemy_energy_regen

	# Apply bonus to owner
	match new_owner:
		0:  # Player owns
			player_energy_system.energy_regen_rate = base_player_energy_regen * (1.0 + capture_point.energy_bonus)
			print("Player captured the point! Energy regen: +50%")
		1:  # Enemy owns
			enemy_energy_system.energy_regen_rate = base_enemy_energy_regen * (1.0 + capture_point.energy_bonus)
			print("Enemy captured the point! Their energy regen: +50%")
		-1:  # Neutral
			print("Capture point is neutral")

	# Update HUD
	hud.update_capture_status(new_owner)

func _input(event: InputEvent) -> void:
	# Lane selection with number keys
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				selected_lane = "left"
				print("Lane: Left")
			KEY_2:
				selected_lane = "center"
				print("Lane: Center")
			KEY_3:
				selected_lane = "right"
				print("Lane: Right")

## Deploy a unit from the player's deck
func deploy_unit(unit_data: UnitData) -> void:
	if game_manager.is_game_over():
		return

	if not unit_data or unit_data not in unit_scene_map:
		print("Invalid unit data or unit not in scene map")
		return

	var unit_scene: PackedScene = unit_scene_map[unit_data]
	var cost = unit_data.energy_cost

	if not player_energy_system.can_afford(cost):
		print("Not enough energy!")
		return

	if player_energy_system.spend_energy(cost):
		var unit = unit_scene.instantiate()
		unit.team = 0  # Player team
		unit.global_position = arena.get_player_deployment_position(selected_lane)
		add_child(unit)
		print("Deployed ", unit_data.unit_name, " in ", selected_lane, " lane")

func _process(delta: float) -> void:
	# Camera follows player commander
	if player_commander and is_instance_valid(player_commander):
		var follow_pos = player_commander.global_position

		# Apply camera shake offset if active
		if camera_shake_amount > 0:
			follow_pos += Vector2(
				randf_range(-camera_shake_amount, camera_shake_amount),
				randf_range(-camera_shake_amount, camera_shake_amount)
			)
			camera_shake_amount = lerp(camera_shake_amount, 0.0, delta * 10.0)

			# Reset when shake is very small
			if camera_shake_amount < 0.1:
				camera_shake_amount = 0.0

		camera.global_position = follow_pos

func shake_camera(intensity: float) -> void:
	camera_shake_amount = max(camera_shake_amount, intensity)

func _on_core_damaged(_current: float, _maximum: float) -> void:
	# Trigger camera shake when core takes damage
	shake_camera(8.0)
