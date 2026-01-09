extends Control
class_name PackShop

## Pack Shop UI
## Displays available packs and handles purchasing/opening

signal pack_purchased(pack_type: PackOpening.PackType)
signal shop_closed()

const PACK_PREVIEW_SIZE = Vector2(180, 260)
const PACK_SPACING = 40

var pack_opening_scene: PackedScene
var pack_opening_instance: PackOpening

var title_label: Label
var pack_container: HBoxContainer
var player_currencies: HBoxContainer
var credits_label: Label
var gems_label: Label
var back_button: Button
var background: ColorRect

# Current player data reference
var player_data: PlayerData
var player_collection: PlayerCollection


func _ready() -> void:
	pack_opening_scene = preload("res://scenes/pack_opening.tscn")
	_setup_ui()
	_update_currencies()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()


func _setup_ui() -> void:
	# Background
	background = ColorRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.08, 0.08, 0.12, 1.0)
	add_child(background)

	# Decorative top gradient
	var top_gradient = ColorRect.new()
	top_gradient.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_gradient.offset_bottom = 150
	top_gradient.color = Color(0.12, 0.1, 0.18, 1.0)
	add_child(top_gradient)

	# Title
	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "CARD PACKS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_label.offset_top = 30
	title_label.offset_bottom = 80
	title_label.add_theme_font_size_override("font_size", 42)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7, 1.0))
	add_child(title_label)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Open packs to collect new cards!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top = 80
	subtitle.offset_bottom = 110
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	add_child(subtitle)

	# Currencies display (top right)
	player_currencies = HBoxContainer.new()
	player_currencies.name = "Currencies"
	player_currencies.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	player_currencies.offset_left = -300
	player_currencies.offset_top = 20
	player_currencies.offset_right = -20
	player_currencies.offset_bottom = 60
	player_currencies.add_theme_constant_override("separation", 30)
	add_child(player_currencies)

	# Credits display
	var credits_container = HBoxContainer.new()
	credits_container.add_theme_constant_override("separation", 8)
	player_currencies.add_child(credits_container)

	var credits_icon = Label.new()
	credits_icon.text = "$"
	credits_icon.add_theme_font_size_override("font_size", 20)
	credits_icon.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3, 1.0))
	credits_container.add_child(credits_icon)

	credits_label = Label.new()
	credits_label.name = "CreditsValue"
	credits_label.text = "10,000"
	credits_label.add_theme_font_size_override("font_size", 20)
	credits_container.add_child(credits_label)

	# Gems display
	var gems_container = HBoxContainer.new()
	gems_container.add_theme_constant_override("separation", 8)
	player_currencies.add_child(gems_container)

	var gems_icon = Label.new()
	gems_icon.text = ">"
	gems_icon.add_theme_font_size_override("font_size", 20)
	gems_icon.add_theme_color_override("font_color", Color(0.3, 0.8, 0.9, 1.0))
	gems_container.add_child(gems_icon)

	gems_label = Label.new()
	gems_label.name = "GemsValue"
	gems_label.text = "500"
	gems_label.add_theme_font_size_override("font_size", 20)
	gems_container.add_child(gems_label)

	# Back button (top left)
	back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = "< BACK"
	back_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back_button.offset_left = 20
	back_button.offset_top = 20
	back_button.offset_right = 120
	back_button.offset_bottom = 60
	back_button.pressed.connect(_on_back_pressed)
	_style_button(back_button, Color(0.3, 0.3, 0.35, 1.0))
	add_child(back_button)

	# Pack container (centered)
	pack_container = HBoxContainer.new()
	pack_container.name = "PackContainer"
	pack_container.alignment = BoxContainer.ALIGNMENT_CENTER
	pack_container.set_anchors_preset(Control.PRESET_CENTER)
	pack_container.add_theme_constant_override("separation", PACK_SPACING)
	add_child(pack_container)

	# Create pack displays
	_create_pack_display(PackOpening.PackType.BASIC)
	_create_pack_display(PackOpening.PackType.PREMIUM)
	_create_pack_display(PackOpening.PackType.LEGENDARY)

	# Position pack container properly
	var total_width = 3 * PACK_PREVIEW_SIZE.x + 2 * PACK_SPACING
	pack_container.offset_left = -total_width / 2
	pack_container.offset_right = total_width / 2
	pack_container.offset_top = -PACK_PREVIEW_SIZE.y / 2 + 20
	pack_container.offset_bottom = PACK_PREVIEW_SIZE.y / 2 + 120


func _style_button(button: Button, color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = color.lightened(0.15)
	button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = style.duplicate()
	pressed_style.bg_color = color.darkened(0.1)
	button.add_theme_stylebox_override("pressed", pressed_style)


func _create_pack_display(pack_type: PackOpening.PackType) -> void:
	var config = PackOpening.PACK_CONFIG[pack_type]

	var pack_panel = VBoxContainer.new()
	pack_panel.name = "Pack_" + str(pack_type)
	pack_panel.add_theme_constant_override("separation", 10)
	pack_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	pack_container.add_child(pack_panel)

	# Pack visual
	var pack_visual = Panel.new()
	pack_visual.name = "Visual"
	pack_visual.custom_minimum_size = PACK_PREVIEW_SIZE

	var pack_style = StyleBoxFlat.new()
	pack_style.bg_color = config.color
	pack_style.corner_radius_top_left = 16
	pack_style.corner_radius_top_right = 16
	pack_style.corner_radius_bottom_left = 16
	pack_style.corner_radius_bottom_right = 16
	pack_style.border_width_top = 4
	pack_style.border_width_bottom = 4
	pack_style.border_width_left = 4
	pack_style.border_width_right = 4
	pack_style.border_color = config.glow
	pack_visual.add_theme_stylebox_override("panel", pack_style)
	pack_panel.add_child(pack_visual)

	# Pack icon
	var icon_label = Label.new()
	icon_label.text = "?"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.set_anchors_preset(Control.PRESET_CENTER)
	icon_label.add_theme_font_size_override("font_size", 80)
	icon_label.add_theme_color_override("font_color", config.glow.lightened(0.3))
	pack_visual.add_child(icon_label)

	# Card count badge
	var count_badge = Panel.new()
	count_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	count_badge.offset_left = -50
	count_badge.offset_top = 10
	count_badge.offset_right = -10
	count_badge.offset_bottom = 40

	var count_style = StyleBoxFlat.new()
	count_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	count_style.corner_radius_top_left = 6
	count_style.corner_radius_top_right = 6
	count_style.corner_radius_bottom_left = 6
	count_style.corner_radius_bottom_right = 6
	count_badge.add_theme_stylebox_override("panel", count_style)
	pack_visual.add_child(count_badge)

	var count_label = Label.new()
	count_label.text = "x%d" % config.card_count
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	count_label.add_theme_font_size_override("font_size", 14)
	count_badge.add_child(count_label)

	# Pack name
	var name_label = Label.new()
	name_label.text = config.name.to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_top = -45
	name_label.offset_bottom = -20
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	pack_visual.add_child(name_label)

	# Guaranteed rarity indicator
	var guarantee_text = ""
	if config.get("guaranteed_epic", false):
		guarantee_text = "Epic+ Guaranteed!"
	elif config.get("guaranteed_rare", false):
		guarantee_text = "Rare+ Guaranteed!"

	if guarantee_text:
		var guarantee_label = Label.new()
		guarantee_label.text = guarantee_text
		guarantee_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		guarantee_label.add_theme_font_size_override("font_size", 11)
		guarantee_label.add_theme_color_override("font_color", config.glow)
		pack_panel.add_child(guarantee_label)
	else:
		# Spacer to maintain alignment
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 15)
		pack_panel.add_child(spacer)

	# Buy button
	var buy_button = Button.new()
	buy_button.name = "BuyButton"

	if config.cost_gems > 0:
		buy_button.text = "> %d" % config.cost_gems
	else:
		buy_button.text = "$ %d" % config.cost_credits

	buy_button.custom_minimum_size = Vector2(PACK_PREVIEW_SIZE.x, 50)
	buy_button.pressed.connect(_on_pack_buy_pressed.bind(pack_type))
	_style_buy_button(buy_button, config.glow)
	pack_panel.add_child(buy_button)

	# Hover effects
	pack_visual.mouse_entered.connect(_on_pack_hover_enter.bind(pack_visual, config))
	pack_visual.mouse_exited.connect(_on_pack_hover_exit.bind(pack_visual, config))
	pack_visual.gui_input.connect(_on_pack_clicked.bind(pack_type))


func _style_buy_button(button: Button, color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color.darkened(0.3)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = color
	button.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = color.darkened(0.1)
	button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = style.duplicate()
	pressed_style.bg_color = color
	button.add_theme_stylebox_override("pressed", pressed_style)

	button.add_theme_font_size_override("font_size", 18)


func _on_pack_hover_enter(panel: Panel, config: Dictionary) -> void:
	var tween = create_tween()
	tween.tween_property(panel, "scale", Vector2(1.05, 1.05), 0.15)
	tween.parallel().tween_property(panel, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.15)


func _on_pack_hover_exit(panel: Panel, config: Dictionary) -> void:
	var tween = create_tween()
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.15)
	tween.parallel().tween_property(panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)


func _on_pack_clicked(event: InputEvent, pack_type: PackOpening.PackType) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_pack_buy_pressed(pack_type)


func _on_pack_buy_pressed(pack_type: PackOpening.PackType) -> void:
	var config = PackOpening.PACK_CONFIG[pack_type]

	# Check if player can afford (would connect to real player data)
	var can_afford = true
	if player_data:
		if config.cost_gems > 0:
			can_afford = player_data.gems >= config.cost_gems
		else:
			can_afford = player_data.credits >= config.cost_credits

	if not can_afford:
		_show_cannot_afford()
		return

	# Deduct currency
	if player_data:
		if config.cost_gems > 0:
			player_data.gems -= config.cost_gems
		else:
			player_data.credits -= config.cost_credits
		_update_currencies()

	pack_purchased.emit(pack_type)
	_open_pack(pack_type)


func _open_pack(pack_type: PackOpening.PackType) -> void:
	# Create pack opening instance
	if pack_opening_instance:
		pack_opening_instance.queue_free()

	pack_opening_instance = pack_opening_scene.instantiate()
	pack_opening_instance.opening_complete.connect(_on_pack_opening_complete)
	add_child(pack_opening_instance)

	# Pass collection for ownership tracking
	if player_collection:
		pack_opening_instance.set_player_collection(player_collection)

	pack_opening_instance.show_pack(pack_type)


func _on_pack_opening_complete() -> void:
	if pack_opening_instance:
		pack_opening_instance.queue_free()
		pack_opening_instance = null


func _show_cannot_afford() -> void:
	# Flash currencies red
	var original_color = credits_label.get_theme_color("font_color")
	var flash_tween = create_tween()
	flash_tween.tween_property(credits_label, "modulate", Color(1.5, 0.3, 0.3, 1.0), 0.1)
	flash_tween.tween_property(credits_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
	flash_tween.tween_property(credits_label, "modulate", Color(1.5, 0.3, 0.3, 1.0), 0.1)
	flash_tween.tween_property(credits_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)

	var flash_tween2 = create_tween()
	flash_tween2.tween_property(gems_label, "modulate", Color(1.5, 0.3, 0.3, 1.0), 0.1)
	flash_tween2.tween_property(gems_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
	flash_tween2.tween_property(gems_label, "modulate", Color(1.5, 0.3, 0.3, 1.0), 0.1)
	flash_tween2.tween_property(gems_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)


func _update_currencies() -> void:
	if player_data:
		credits_label.text = _format_number(player_data.credits)
		gems_label.text = str(player_data.gems)
	else:
		# Default demo values
		credits_label.text = "10,000"
		gems_label.text = "500"


func _format_number(num: int) -> String:
	var str_num = str(num)
	var result = ""
	var count = 0
	for i in range(str_num.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = str_num[i] + result
		count += 1
	return result


func _on_back_pressed() -> void:
	shop_closed.emit()
	hide()


## Set player data for currency tracking
func set_player_data(data: PlayerData) -> void:
	player_data = data
	_update_currencies()


## Set player collection for ownership tracking
func set_player_collection(collection: PlayerCollection) -> void:
	player_collection = collection
