extends CanvasLayer
class_name HUD

## Main HUD displaying energy, health, and unit deployment buttons
## Uses modular percentage-based layout for resolution independence

# Top info area - health bars, energy, capture status
@onready var energy_bar = $UIRoot/TopInfoContainer/MarginContainer/VBoxContainer/EnergyBar
@onready var energy_label = $UIRoot/TopInfoContainer/MarginContainer/VBoxContainer/EnergyBar/EnergyLabel
@onready var player_health_bar = $UIRoot/TopInfoContainer/MarginContainer/VBoxContainer/PlayerHealth/HealthBar
@onready var player_health_label = $UIRoot/TopInfoContainer/MarginContainer/VBoxContainer/PlayerHealth/Label
@onready var enemy_health_bar = $UIRoot/TopInfoContainer/MarginContainer/VBoxContainer/EnemyHealth/HealthBar
@onready var enemy_health_label = $UIRoot/TopInfoContainer/MarginContainer/VBoxContainer/EnemyHealth/Label
@onready var capture_status = $UIRoot/TopInfoContainer/MarginContainer/VBoxContainer/CaptureStatus

# Bottom tray - unit deployment buttons
@onready var unit_buttons_container = $UIRoot/BottomTrayContainer/MarginContainer/VBoxContainer/UnitButtons

# Game over overlay
@onready var game_over_container = $UIRoot/GameOverContainer
@onready var game_over_panel = $UIRoot/GameOverContainer/GameOverPanel
@onready var game_over_label = $UIRoot/GameOverContainer/GameOverPanel/VBoxContainer/ResultLabel
@onready var restart_button = $UIRoot/GameOverContainer/GameOverPanel/VBoxContainer/RestartButton

var energy_system: EnergySystem
var game_manager: GameManager
var player_deck: Deck
var main_scene: Node

# Dynamic button references
var unit_buttons: Array[Button] = []

func _ready() -> void:
	game_over_container.hide()

	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)

func setup(p_energy_system: EnergySystem, p_game_manager: GameManager, p_deck: Deck, p_main_scene: Node) -> void:
	energy_system = p_energy_system
	game_manager = p_game_manager
	player_deck = p_deck
	main_scene = p_main_scene

	if energy_system:
		energy_system.energy_changed.connect(_on_energy_changed)
		_on_energy_changed(energy_system.current_energy, energy_system.max_energy)

	if game_manager:
		game_manager.game_over.connect(_on_game_over)

	# Generate unit buttons from deck
	if player_deck:
		generate_unit_buttons()

func generate_unit_buttons() -> void:
	# Clear existing buttons
	for child in unit_buttons_container.get_children():
		child.queue_free()

	unit_buttons.clear()

	# Create button for each unit in deck
	for unit_data in player_deck.units:
		var button = Button.new()
		button.custom_minimum_size = Vector2(100, 60)
		button.text = "%s\n(%.1f)" % [unit_data.unit_name, unit_data.energy_cost]

		# Store unit data reference
		button.set_meta("unit_data", unit_data)

		# Connect to deployment
		button.pressed.connect(_on_unit_button_pressed.bind(unit_data))

		unit_buttons_container.add_child(button)
		unit_buttons.append(button)

	# Initial button state update
	if energy_system:
		_update_button_states(energy_system.current_energy)

func _on_unit_button_pressed(unit_data: UnitData) -> void:
	# Call deploy_unit on main scene
	if main_scene and main_scene.has_method("deploy_unit"):
		main_scene.deploy_unit(unit_data)

func _update_button_states(current_energy: float) -> void:
	for button in unit_buttons:
		var unit_data = button.get_meta("unit_data") as UnitData
		if unit_data:
			button.disabled = current_energy < unit_data.energy_cost

func _on_energy_changed(current: float, maximum: float) -> void:
	if energy_bar:
		energy_bar.value = (current / maximum) * 100.0
	if energy_label:
		energy_label.text = "Energy: %d/%d" % [int(current), int(maximum)]

	# Update button states
	_update_button_states(current)

func update_player_health(current: float, maximum: float) -> void:
	if player_health_bar:
		player_health_bar.value = (current / maximum) * 100.0
	if player_health_label:
		player_health_label.text = "Player Core: %d/%d" % [int(current), int(maximum)]

func update_enemy_health(current: float, maximum: float) -> void:
	if enemy_health_bar:
		enemy_health_bar.value = (current / maximum) * 100.0
	if enemy_health_label:
		enemy_health_label.text = "Enemy Core: %d/%d" % [int(current), int(maximum)]

func update_capture_status(point_owner: int) -> void:
	if not capture_status:
		return

	match point_owner:
		-1:  # Neutral
			capture_status.text = "Objective: Neutral"
			capture_status.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		0:  # Player
			capture_status.text = "Objective: Player Controlled (+50% Energy)"
			capture_status.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		1:  # Enemy
			capture_status.text = "Objective: Enemy Controlled"
			capture_status.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

func _on_game_over(player_won: bool) -> void:
	game_over_container.show()
	if player_won:
		game_over_label.text = "VICTORY!"
		game_over_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		game_over_label.text = "DEFEAT"
		game_over_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

func _on_restart_pressed() -> void:
	# Return to main menu
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
