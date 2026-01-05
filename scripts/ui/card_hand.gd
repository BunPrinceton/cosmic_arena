extends Control
class_name CardHand

## Container for the player's card hand in the bottom-right corner
## Manages card display and communicates with UnitPlacementSystem

signal card_drag_started(unit_data: UnitData)
signal card_drag_ended()

@export var energy_system: EnergySystem

var cards: Array[CardUI] = []
var cards_container: HBoxContainer
var active_drag_card: CardUI = null

# Stored for deferred setup
var _pending_deck: Deck = null
var _pending_energy_system: EnergySystem = null
var _is_ready: bool = false

func _ready() -> void:
	# Position in bottom-right
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -350
	offset_top = -130
	offset_right = -10
	offset_bottom = -10

	# Don't block mouse for 3D scene when not over cards
	mouse_filter = Control.MOUSE_FILTER_PASS

	# Create container for cards
	cards_container = HBoxContainer.new()
	cards_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	cards_container.add_theme_constant_override("separation", 8)
	cards_container.alignment = BoxContainer.ALIGNMENT_END
	cards_container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(cards_container)

	# Background panel
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.1, 0.7)
	bg.z_index = -1
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)

	_is_ready = true

	# If setup was called before _ready, do it now
	if _pending_deck != null:
		_do_setup(_pending_deck, _pending_energy_system)
		_pending_deck = null
		_pending_energy_system = null

func setup(deck: Deck, p_energy_system: EnergySystem) -> void:
	if not _is_ready:
		# Store for later - _ready hasn't run yet
		_pending_deck = deck
		_pending_energy_system = p_energy_system
		return

	_do_setup(deck, p_energy_system)

func _do_setup(deck: Deck, p_energy_system: EnergySystem) -> void:
	energy_system = p_energy_system

	# Connect to energy changes
	if energy_system and not energy_system.energy_changed.is_connected(_on_energy_changed):
		energy_system.energy_changed.connect(_on_energy_changed)

	# Clear existing cards
	for card in cards:
		card.queue_free()
	cards.clear()

	# Create cards for each unit in deck
	if deck:
		for unit_data in deck.units:
			var card = CardUI.new()
			card.setup(unit_data)
			card.drag_started.connect(_on_card_drag_started)
			card.drag_ended.connect(_on_card_drag_ended)
			cards_container.add_child(card)
			cards.append(card)

	# Initial affordability update
	if energy_system:
		_update_card_affordability(energy_system.get_current_energy())

	print("CardHand: Created %d cards" % cards.size())

func _on_energy_changed(current: float, _maximum: float) -> void:
	_update_card_affordability(current)

func _update_card_affordability(current_energy: float) -> void:
	for card in cards:
		if card.unit_data:
			card.set_affordable(current_energy >= card.unit_data.energy_cost)

func _on_card_drag_started(card: CardUI, unit_data: UnitData) -> void:
	active_drag_card = card
	card_drag_started.emit(unit_data)

func _on_card_drag_ended(_card: CardUI) -> void:
	active_drag_card = null
	card_drag_ended.emit()

func cancel_active_drag() -> void:
	if active_drag_card:
		active_drag_card.cancel_drag()
		active_drag_card = null
