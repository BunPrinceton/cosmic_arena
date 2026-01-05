extends Node
class_name EnergySystem

## Manages energy generation and spending for unit deployment

signal energy_changed(current: float, maximum: float)

@export var max_energy: float = 10.0
@export var energy_regen_rate: float = 0.333  # Energy per second (1 energy every 3 seconds)
@export var starting_energy: float = 5.0

var current_energy: float = 0.0

func _ready() -> void:
	current_energy = starting_energy
	energy_changed.emit(current_energy, max_energy)

func _process(delta: float) -> void:
	# Regenerate energy over time
	if current_energy < max_energy:
		current_energy = min(current_energy + energy_regen_rate * delta, max_energy)
		energy_changed.emit(current_energy, max_energy)

func can_afford(cost: float) -> bool:
	return current_energy >= cost

func spend_energy(cost: float) -> bool:
	if can_afford(cost):
		current_energy -= cost
		energy_changed.emit(current_energy, max_energy)
		return true
	return false

func add_energy(amount: float) -> void:
	current_energy = min(current_energy + amount, max_energy)
	energy_changed.emit(current_energy, max_energy)

func get_current_energy() -> float:
	return current_energy

func get_max_energy() -> float:
	return max_energy
