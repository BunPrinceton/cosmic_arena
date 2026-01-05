extends Control
class_name CardUI

## Individual card in the player's hand
## Displays unit info and handles drag-start detection

signal drag_started(card: CardUI, unit_data: UnitData)
signal drag_ended(card: CardUI)

@export var unit_data: UnitData

# Card visual settings
const CARD_WIDTH: float = 80.0
const CARD_HEIGHT: float = 100.0
const DISABLED_ALPHA: float = 0.4

var is_dragging: bool = false
var can_afford: bool = true

# UI elements
var background: ColorRect
var name_label: Label
var cost_label: Label
var size_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_create_card_visuals()

func _create_card_visuals() -> void:
	# Background panel
	background = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.15, 0.15, 0.2, 0.95)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# Card border
	var border = ColorRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.color = Color(0.4, 0.6, 0.9, 1.0)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)

	# Inner background (slightly smaller to create border effect)
	var inner_bg = ColorRect.new()
	inner_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner_bg.offset_left = 2
	inner_bg.offset_top = 2
	inner_bg.offset_right = -2
	inner_bg.offset_bottom = -2
	inner_bg.color = Color(0.12, 0.12, 0.18, 1.0)
	inner_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(inner_bg)

	# Unit name label
	name_label = Label.new()
	name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name_label.offset_top = 8
	name_label.offset_bottom = 30
	name_label.offset_left = 4
	name_label.offset_right = -4
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)

	# Energy cost label (big, centered)
	cost_label = Label.new()
	cost_label.set_anchors_preset(Control.PRESET_CENTER)
	cost_label.offset_left = -30
	cost_label.offset_right = 30
	cost_label.offset_top = -15
	cost_label.offset_bottom = 15
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 24)
	cost_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cost_label)

	# Grid size label (bottom)
	size_label = Label.new()
	size_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	size_label.offset_top = -25
	size_label.offset_bottom = -5
	size_label.offset_left = 4
	size_label.offset_right = -4
	size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	size_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	size_label.add_theme_font_size_override("font_size", 10)
	size_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	size_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(size_label)

	_update_display()

func setup(data: UnitData) -> void:
	unit_data = data
	_update_display()

func _update_display() -> void:
	if not unit_data:
		return

	if name_label:
		name_label.text = unit_data.unit_name
	if cost_label:
		cost_label.text = "%.1f" % unit_data.energy_cost
	if size_label:
		size_label.text = "%dx%d" % [unit_data.grid_size.x, unit_data.grid_size.y]

func set_affordable(affordable: bool) -> void:
	can_afford = affordable
	modulate.a = 1.0 if can_afford else DISABLED_ALPHA

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and can_afford and not is_dragging:
				is_dragging = true
				drag_started.emit(self, unit_data)
			elif not event.pressed and is_dragging:
				is_dragging = false
				drag_ended.emit(self)

func cancel_drag() -> void:
	is_dragging = false
