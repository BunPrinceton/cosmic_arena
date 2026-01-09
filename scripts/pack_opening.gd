extends Control
class_name PackOpening

## Pack Opening System Controller
## Handles pack opening animations, card reveals, and rewards

signal pack_opened(cards: Array[CardData])
signal card_revealed(card: CardData, index: int)
signal all_cards_revealed()
signal opening_complete()

enum PackType {
	BASIC,       # 4 cards, mostly common
	PREMIUM,     # 5 cards, guaranteed rare+
	LEGENDARY    # 6 cards, guaranteed epic+, chance for legendary
}

## Pack configuration
const PACK_CONFIG = {
	PackType.BASIC: {
		"name": "Basic Pack",
		"card_count": 4,
		"cost_credits": 1000,
		"cost_gems": 0,
		"guaranteed_rare": false,
		"color": Color(0.4, 0.35, 0.3, 1.0),
		"glow": Color(0.6, 0.5, 0.4, 1.0)
	},
	PackType.PREMIUM: {
		"name": "Premium Pack",
		"card_count": 5,
		"cost_credits": 0,
		"cost_gems": 100,
		"guaranteed_rare": true,
		"color": Color(0.2, 0.4, 0.7, 1.0),
		"glow": Color(0.3, 0.6, 1.0, 1.0)
	},
	PackType.LEGENDARY: {
		"name": "Legendary Pack",
		"card_count": 6,
		"cost_credits": 0,
		"cost_gems": 300,
		"guaranteed_rare": true,
		"guaranteed_epic": true,
		"color": Color(0.7, 0.5, 0.2, 1.0),
		"glow": Color(1.0, 0.8, 0.3, 1.0)
	}
}

## Animation timing
const PACK_SHAKE_DURATION: float = 0.8
const PACK_OPEN_DURATION: float = 0.5
const CARD_REVEAL_DELAY: float = 0.3
const CARD_FLIP_DURATION: float = 0.4
const CARD_SETTLE_DURATION: float = 0.3
const GLOW_PULSE_DURATION: float = 1.5

## Screen shake settings by rarity
const SHAKE_INTENSITY = {
	CardData.Rarity.COMMON: 0.0,
	CardData.Rarity.RARE: 3.0,
	CardData.Rarity.EPIC: 6.0,
	CardData.Rarity.LEGENDARY: 12.0
}
const SHAKE_DURATION = {
	CardData.Rarity.COMMON: 0.0,
	CardData.Rarity.RARE: 0.2,
	CardData.Rarity.EPIC: 0.35,
	CardData.Rarity.LEGENDARY: 0.5
}

## UI References
var pack_container: Control
var cards_container: HBoxContainer
var pack_sprite: Panel
var pack_glow: Panel
var open_button: Button
var skip_button: Button
var continue_button: Button
var title_label: Label
var subtitle_label: Label
var background: ColorRect

## State
var current_pack_type: PackType = PackType.BASIC
var opened_cards: Array[CardData] = []
var card_panels: Array[Panel] = []
var revealing_index: int = 0
var is_opening: bool = false
var is_revealing: bool = false
var can_skip: bool = false

## Available card pool (set externally or generated)
var card_pool: Array[CardData] = []

## Player collection (optional - for tracking ownership)
var player_collection: PlayerCollection = null

## Effects
var effects_container: Control
var original_position: Vector2
var shake_tween: Tween


func _ready() -> void:
	original_position = position
	_setup_ui()
	_generate_default_card_pool()
	_create_pack_display(PackType.BASIC)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if is_revealing and can_skip:
			_skip_to_end()
		elif not is_opening and not is_revealing and opened_cards.size() > 0:
			# Click anywhere to continue after reveal
			pass

	if event.is_action_pressed("ui_cancel"):
		_close_pack_opening()


func _setup_ui() -> void:
	# Dark background
	background = ColorRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.05, 0.05, 0.08, 0.95)
	add_child(background)

	# Title at top
	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "OPEN PACK"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_label.offset_top = 40
	title_label.offset_bottom = 90
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7, 1.0))
	add_child(title_label)

	# Subtitle
	subtitle_label = Label.new()
	subtitle_label.name = "Subtitle"
	subtitle_label.text = "Tap the pack to open!"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle_label.offset_top = 85
	subtitle_label.offset_bottom = 115
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	add_child(subtitle_label)

	# Pack container (center of screen)
	pack_container = Control.new()
	pack_container.name = "PackContainer"
	pack_container.set_anchors_preset(Control.PRESET_CENTER)
	pack_container.offset_left = -100
	pack_container.offset_top = -140
	pack_container.offset_right = 100
	pack_container.offset_bottom = 140
	add_child(pack_container)

	# Pack glow effect (behind pack)
	pack_glow = Panel.new()
	pack_glow.name = "PackGlow"
	pack_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	pack_glow.offset_left = -30
	pack_glow.offset_top = -30
	pack_glow.offset_right = 30
	pack_glow.offset_bottom = 30
	pack_glow.modulate.a = 0.0
	pack_container.add_child(pack_glow)

	# Pack sprite/panel
	pack_sprite = Panel.new()
	pack_sprite.name = "PackSprite"
	pack_sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	pack_sprite.gui_input.connect(_on_pack_clicked)
	pack_container.add_child(pack_sprite)

	# Cards container (for revealed cards)
	cards_container = HBoxContainer.new()
	cards_container.name = "CardsContainer"
	cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_container.set_anchors_preset(Control.PRESET_CENTER)
	cards_container.add_theme_constant_override("separation", 15)
	cards_container.visible = false
	add_child(cards_container)

	# Skip button
	skip_button = Button.new()
	skip_button.name = "SkipButton"
	skip_button.text = "SKIP"
	skip_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_button.offset_left = -120
	skip_button.offset_top = -60
	skip_button.offset_right = -20
	skip_button.offset_bottom = -20
	skip_button.visible = false
	skip_button.pressed.connect(_skip_to_end)
	add_child(skip_button)

	# Continue button
	continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = "CONTINUE"
	continue_button.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	continue_button.offset_left = 100
	continue_button.offset_top = -70
	continue_button.offset_right = -100
	continue_button.offset_bottom = -20
	continue_button.visible = false
	continue_button.pressed.connect(_close_pack_opening)
	_style_button(continue_button, Color(0.2, 0.6, 0.3, 1.0))
	add_child(continue_button)

	# Open button (below pack)
	open_button = Button.new()
	open_button.name = "OpenButton"
	open_button.text = "OPEN PACK"
	open_button.set_anchors_preset(Control.PRESET_CENTER)
	open_button.offset_left = -80
	open_button.offset_top = 160
	open_button.offset_right = 80
	open_button.offset_bottom = 210
	open_button.pressed.connect(_start_opening)
	_style_button(open_button, Color(0.8, 0.6, 0.2, 1.0))
	add_child(open_button)


func _style_button(button: Button, color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	button.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = color.lightened(0.15)
	button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = style.duplicate()
	pressed_style.bg_color = color.darkened(0.1)
	button.add_theme_stylebox_override("pressed", pressed_style)

	button.add_theme_font_size_override("font_size", 18)


func _create_pack_display(pack_type: PackType) -> void:
	current_pack_type = pack_type
	var config = PACK_CONFIG[pack_type]

	title_label.text = config.name.to_upper()

	# Style pack panel
	var pack_style = StyleBoxFlat.new()
	pack_style.bg_color = config.color
	pack_style.corner_radius_top_left = 12
	pack_style.corner_radius_top_right = 12
	pack_style.corner_radius_bottom_left = 12
	pack_style.corner_radius_bottom_right = 12
	pack_style.border_width_top = 3
	pack_style.border_width_bottom = 3
	pack_style.border_width_left = 3
	pack_style.border_width_right = 3
	pack_style.border_color = config.glow.lightened(0.2)
	pack_sprite.add_theme_stylebox_override("panel", pack_style)

	# Style glow panel
	var glow_style = StyleBoxFlat.new()
	glow_style.bg_color = config.glow
	glow_style.corner_radius_top_left = 20
	glow_style.corner_radius_top_right = 20
	glow_style.corner_radius_bottom_left = 20
	glow_style.corner_radius_bottom_right = 20
	pack_glow.add_theme_stylebox_override("panel", glow_style)

	# Add pack icon/text
	_clear_pack_content()

	var pack_icon = Label.new()
	pack_icon.name = "PackIcon"
	pack_icon.text = "?"
	pack_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pack_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pack_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	pack_icon.add_theme_font_size_override("font_size", 72)
	pack_icon.add_theme_color_override("font_color", config.glow.lightened(0.3))
	pack_sprite.add_child(pack_icon)

	var pack_name = Label.new()
	pack_name.name = "PackName"
	pack_name.text = config.name
	pack_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pack_name.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pack_name.offset_top = -40
	pack_name.add_theme_font_size_override("font_size", 14)
	pack_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	pack_sprite.add_child(pack_name)

	# Start idle glow animation
	_animate_idle_glow()


func _clear_pack_content() -> void:
	for child in pack_sprite.get_children():
		child.queue_free()


func _animate_idle_glow() -> void:
	if is_opening or is_revealing:
		return

	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(pack_glow, "modulate:a", 0.4, GLOW_PULSE_DURATION)
	tween.tween_property(pack_glow, "modulate:a", 0.1, GLOW_PULSE_DURATION)


func _on_pack_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_opening and not is_revealing:
			_start_opening()


func _start_opening() -> void:
	if is_opening or is_revealing:
		return

	is_opening = true
	open_button.visible = false
	subtitle_label.text = "Opening..."

	# Stop idle glow
	var tweens = get_tree().get_processed_tweens()
	for t in tweens:
		if t.is_valid():
			t.kill()

	# Generate cards for this pack
	_generate_pack_cards()

	# Shake animation
	var shake_tween = create_tween()
	shake_tween.set_loops(8)
	shake_tween.tween_property(pack_sprite, "rotation", deg_to_rad(3), PACK_SHAKE_DURATION / 16)
	shake_tween.tween_property(pack_sprite, "rotation", deg_to_rad(-3), PACK_SHAKE_DURATION / 16)

	# After shaking, do the open animation
	await get_tree().create_timer(PACK_SHAKE_DURATION).timeout
	shake_tween.kill()
	pack_sprite.rotation = 0

	# Intense glow burst
	var burst_tween = create_tween()
	burst_tween.set_parallel(true)
	burst_tween.tween_property(pack_glow, "modulate:a", 1.0, 0.2)
	burst_tween.tween_property(pack_glow, "scale", Vector2(1.5, 1.5), 0.2)
	burst_tween.tween_property(pack_sprite, "scale", Vector2(1.2, 1.2), 0.2)

	await burst_tween.finished

	# Flash white and fade out pack
	var flash_tween = create_tween()
	flash_tween.set_parallel(true)
	flash_tween.tween_property(pack_container, "modulate:a", 0.0, PACK_OPEN_DURATION)
	flash_tween.tween_property(background, "color", Color(0.3, 0.3, 0.35, 0.95), 0.1)
	flash_tween.chain().tween_property(background, "color", Color(0.05, 0.05, 0.08, 0.95), 0.3)

	await flash_tween.finished

	pack_container.visible = false
	is_opening = false

	# Start card reveal
	_start_card_reveal()


func _generate_pack_cards() -> void:
	# NEW: Using PackGenerator system for pure, testable pack generation
	var pack_type_mapped = current_pack_type as PackGenerator.PackType
	opened_cards = PackGenerator.generate_pack(pack_type_mapped, card_pool, -1)
	pack_opened.emit(opened_cards)

	# OLD LOGIC (deprecated, kept for reference):
	# opened_cards.clear()
	# var config = PACK_CONFIG[current_pack_type]
	# var card_count = config.card_count
	#
	# for i in range(card_count):
	# 	var card = _roll_card(i, config)
	# 	opened_cards.append(card)
	#
	# # Sort by rarity (legendary last for drama)
	# opened_cards.sort_custom(func(a, b): return a.rarity < b.rarity)
	#
	# pack_opened.emit(opened_cards)


## TODO: This function will be REMOVED when PackGenerator is integrated
func _roll_card(index: int, config: Dictionary) -> CardData:
	var guaranteed_epic = config.get("guaranteed_epic", false)
	var guaranteed_rare = config.get("guaranteed_rare", false)

	# Last card gets guaranteed rarity
	var is_last = index == config.card_count - 1
	var is_second_last = index == config.card_count - 2

	var min_rarity = CardData.Rarity.COMMON

	if is_last and guaranteed_epic:
		min_rarity = CardData.Rarity.EPIC
	elif (is_last or is_second_last) and guaranteed_rare:
		min_rarity = CardData.Rarity.RARE

	var rarity = _roll_rarity(min_rarity)

	# Pick a random card from pool matching rarity (or create one)
	var matching_cards = card_pool.filter(func(c): return c.rarity == rarity)

	if matching_cards.size() > 0:
		return matching_cards[randi() % matching_cards.size()]
	else:
		# Generate a placeholder card
		return _create_placeholder_card(rarity)


## TODO: This function will be REMOVED when PackGenerator is integrated
func _roll_rarity(min_rarity: CardData.Rarity) -> CardData.Rarity:
	var weights = CardData.RARITY_WEIGHTS.duplicate()

	# Zero out weights below minimum
	for r in weights:
		if r < min_rarity:
			weights[r] = 0

	var total = 0
	for w in weights.values():
		total += w

	var roll = randi() % total
	var cumulative = 0

	for r in weights:
		cumulative += weights[r]
		if roll < cumulative:
			return r

	return min_rarity


## TODO: This function will be REMOVED when PackGenerator is integrated
func _create_placeholder_card(rarity: CardData.Rarity) -> CardData:
	var card = CardData.new()
	var rarity_names = ["Common", "Rare", "Epic", "Legendary"]
	var unit_names = ["Soldier", "Knight", "Mage", "Champion", "Guardian", "Striker", "Assassin", "Healer"]

	card.card_name = unit_names[randi() % unit_names.size()] + " " + rarity_names[rarity]
	card.card_id = "generated_" + str(randi())
	card.rarity = rarity
	card.card_type = CardData.CardType.UNIT
	card.energy_cost = 2 + rarity
	card.health = 80 + rarity * 30
	card.attack = 10 + rarity * 8
	card.speed = 80 + rarity * 5
	card.description = "A powerful %s unit." % card.get_rarity_name().to_lower()

	return card


func _start_card_reveal() -> void:
	is_revealing = true
	can_skip = true
	revealing_index = 0
	card_panels.clear()

	# Clear cards container
	for child in cards_container.get_children():
		child.queue_free()

	# Calculate card size based on count
	var card_count = opened_cards.size()
	var screen_width = get_viewport_rect().size.x
	var available_width = screen_width - 200  # margins
	var card_width = min(120, (available_width - (card_count - 1) * 15) / card_count)
	var card_height = card_width * 1.5

	# Position cards container
	cards_container.offset_left = -available_width / 2
	cards_container.offset_right = available_width / 2
	cards_container.offset_top = -card_height / 2 - 30
	cards_container.offset_bottom = card_height / 2 + 30
	cards_container.visible = true

	# Create card backs
	for i in range(card_count):
		var card_panel = _create_card_back(Vector2(card_width, card_height))
		card_panel.modulate.a = 0.0
		card_panel.scale = Vector2(0.5, 0.5)
		cards_container.add_child(card_panel)
		card_panels.append(card_panel)

	skip_button.visible = true
	subtitle_label.text = "Tap cards to reveal!"

	# Animate cards appearing
	var appear_tween = create_tween()
	for i in range(card_panels.size()):
		appear_tween.tween_property(card_panels[i], "modulate:a", 1.0, 0.2)
		appear_tween.parallel().tween_property(card_panels[i], "scale", Vector2(1, 1), 0.2)
		appear_tween.tween_interval(0.1)

	await appear_tween.finished

	# Start auto-reveal sequence
	_reveal_next_card()


func _create_card_back(size: Vector2) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = size
	panel.pivot_offset = size / 2

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.3, 0.3, 0.4, 1.0)
	panel.add_theme_stylebox_override("panel", style)

	# Card back design
	var question = Label.new()
	question.text = "?"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question.set_anchors_preset(Control.PRESET_FULL_RECT)
	question.add_theme_font_size_override("font_size", int(size.x * 0.5))
	question.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5, 1.0))
	panel.add_child(question)

	# Make clickable
	panel.gui_input.connect(_on_card_back_clicked.bind(panel))

	return panel


func _on_card_back_clicked(event: InputEvent, panel: Panel) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var index = card_panels.find(panel)
		if index != -1 and index == revealing_index:
			_reveal_card_at(index)


func _reveal_next_card() -> void:
	if revealing_index >= opened_cards.size():
		_finish_reveal()
		return

	# Auto-reveal after delay
	await get_tree().create_timer(CARD_REVEAL_DELAY).timeout

	if revealing_index < opened_cards.size() and is_revealing:
		_reveal_card_at(revealing_index)


func _reveal_card_at(index: int) -> void:
	if index >= opened_cards.size() or index >= card_panels.size():
		return

	var card_data = opened_cards[index]
	var panel = card_panels[index]

	# Flip animation - first half (flip to side)
	var flip_tween = create_tween()
	flip_tween.tween_property(panel, "scale:x", 0.0, CARD_FLIP_DURATION / 2)

	await flip_tween.finished

	# Replace content with actual card
	_populate_card_panel(panel, card_data)

	# Flip animation - second half (flip to front)
	var flip_back_tween = create_tween()
	flip_back_tween.tween_property(panel, "scale:x", 1.0, CARD_FLIP_DURATION / 2)

	# Add glow effect for rare+ cards
	if card_data.rarity >= CardData.Rarity.RARE:
		_add_card_glow(panel, card_data)
		# Screen shake for rare+ cards
		_do_screen_shake(card_data.rarity)
		# Spawn sparkles around the card
		_spawn_sparkles(panel, card_data)
		# Extra flash for legendary
		if card_data.rarity == CardData.Rarity.LEGENDARY:
			_flash_background(card_data.get_glow_color())

	card_revealed.emit(card_data, index)

	await flip_back_tween.finished

	# Bounce effect - bigger for higher rarity
	var bounce_scale = 1.1 + (card_data.rarity * 0.05)
	var bounce_tween = create_tween()
	bounce_tween.tween_property(panel, "scale", Vector2(bounce_scale, bounce_scale), 0.1)
	bounce_tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.1)

	revealing_index += 1

	if revealing_index < opened_cards.size():
		_reveal_next_card()
	else:
		_finish_reveal()


func _populate_card_panel(panel: Panel, card_data: CardData) -> void:
	# Clear existing content
	for child in panel.get_children():
		child.queue_free()

	var size = panel.custom_minimum_size

	# Update panel style with rarity color
	var style = StyleBoxFlat.new()
	style.bg_color = card_data.get_rarity_color()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_color = card_data.get_glow_color()
	panel.add_theme_stylebox_override("panel", style)

	# Energy cost badge
	var energy_badge = Panel.new()
	energy_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	energy_badge.offset_right = size.x * 0.3
	energy_badge.offset_bottom = size.x * 0.25
	var energy_style = StyleBoxFlat.new()
	energy_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	energy_style.corner_radius_top_left = 8
	energy_style.corner_radius_bottom_right = 8
	energy_badge.add_theme_stylebox_override("panel", energy_style)
	panel.add_child(energy_badge)

	var energy_label = Label.new()
	energy_label.text = str(int(card_data.energy_cost))
	energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	energy_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	energy_label.add_theme_font_size_override("font_size", int(size.x * 0.15))
	energy_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	energy_badge.add_child(energy_label)

	# Card art area
	var art_rect = ColorRect.new()
	art_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	art_rect.offset_left = 5
	art_rect.offset_top = size.x * 0.25
	art_rect.offset_right = -5
	art_rect.offset_bottom = -size.y * 0.35
	art_rect.color = card_data.frame_color if card_data.frame_color else card_data.get_rarity_color().lightened(0.1)
	panel.add_child(art_rect)

	# Card icon text
	var icon_label = Label.new()
	icon_label.text = card_data.get_display_icon()
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_label.add_theme_font_size_override("font_size", int(size.x * 0.35))
	icon_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	art_rect.add_child(icon_label)

	# Card name
	var name_label = Label.new()
	name_label.text = card_data.card_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_top = -size.y * 0.32
	name_label.offset_bottom = -size.y * 0.18
	name_label.add_theme_font_size_override("font_size", int(size.x * 0.1))
	name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	panel.add_child(name_label)

	# Rarity label
	var rarity_label = Label.new()
	rarity_label.text = card_data.get_rarity_name()
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	rarity_label.offset_top = -size.y * 0.18
	rarity_label.offset_bottom = -size.y * 0.08
	rarity_label.add_theme_font_size_override("font_size", int(size.x * 0.08))
	rarity_label.add_theme_color_override("font_color", card_data.get_glow_color())
	panel.add_child(rarity_label)

	# Stats row
	var stats_label = Label.new()
	stats_label.text = "HP:%d ATK:%d" % [int(card_data.health), int(card_data.attack)]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	stats_label.offset_top = -size.y * 0.1
	stats_label.offset_bottom = -2
	stats_label.add_theme_font_size_override("font_size", int(size.x * 0.07))
	stats_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	panel.add_child(stats_label)


func _add_card_glow(panel: Panel, card_data: CardData) -> void:
	var glow = Panel.new()
	glow.name = "Glow"
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -10
	glow.offset_top = -10
	glow.offset_right = 10
	glow.offset_bottom = 10
	glow.z_index = -1

	var glow_style = StyleBoxFlat.new()
	glow_style.bg_color = card_data.get_glow_color()
	glow_style.corner_radius_top_left = 12
	glow_style.corner_radius_top_right = 12
	glow_style.corner_radius_bottom_left = 12
	glow_style.corner_radius_bottom_right = 12
	glow.add_theme_stylebox_override("panel", glow_style)

	panel.add_child(glow)
	panel.move_child(glow, 0)

	# Pulse animation
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(glow, "modulate:a", 0.8, 0.6)
	pulse_tween.tween_property(glow, "modulate:a", 0.4, 0.6)


## Screen shake effect for exciting reveals
func _do_screen_shake(rarity: CardData.Rarity) -> void:
	var intensity = SHAKE_INTENSITY.get(rarity, 0.0)
	var duration = SHAKE_DURATION.get(rarity, 0.0)

	if intensity <= 0 or duration <= 0:
		return

	# Kill existing shake
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
		position = original_position

	shake_tween = create_tween()
	var shake_count = int(duration / 0.05)

	for i in range(shake_count):
		var offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		# Decay shake intensity over time
		var decay = 1.0 - (float(i) / shake_count)
		shake_tween.tween_property(self, "position", original_position + offset * decay, 0.05)

	# Return to original position
	shake_tween.tween_property(self, "position", original_position, 0.05)


## Spawn sparkle particles around a card
func _spawn_sparkles(card_panel: Panel, card_data: CardData) -> void:
	var sparkle_count = 8 + (card_data.rarity * 6)  # More sparkles for higher rarity
	var glow_color = card_data.get_glow_color()

	# Ensure effects container exists
	if not effects_container:
		effects_container = Control.new()
		effects_container.name = "EffectsContainer"
		effects_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		effects_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(effects_container)

	var card_center = card_panel.global_position + card_panel.size / 2

	for i in range(sparkle_count):
		var sparkle = _create_sparkle(glow_color)
		effects_container.add_child(sparkle)

		# Random position around the card
		var angle = randf() * TAU
		var distance = randf_range(20, 80)
		var start_pos = card_center + Vector2(cos(angle), sin(angle)) * distance * 0.3
		var end_pos = card_center + Vector2(cos(angle), sin(angle)) * distance

		sparkle.global_position = start_pos

		# Animate sparkle outward and fade
		var sparkle_tween = create_tween()
		sparkle_tween.set_parallel(true)
		sparkle_tween.tween_property(sparkle, "global_position", end_pos, randf_range(0.4, 0.8))
		sparkle_tween.tween_property(sparkle, "modulate:a", 0.0, randf_range(0.5, 0.9))
		sparkle_tween.tween_property(sparkle, "scale", Vector2(0.2, 0.2), randf_range(0.5, 0.9))

		# Clean up after animation
		sparkle_tween.chain().tween_callback(sparkle.queue_free)


## Create a single sparkle particle
func _create_sparkle(color: Color) -> Panel:
	var sparkle = Panel.new()
	var size = randf_range(4, 12)
	sparkle.custom_minimum_size = Vector2(size, size)
	sparkle.pivot_offset = Vector2(size / 2, size / 2)
	sparkle.scale = Vector2(randf_range(0.5, 1.5), randf_range(0.5, 1.5))

	var style = StyleBoxFlat.new()
	style.bg_color = color.lightened(randf_range(0.0, 0.3))
	style.corner_radius_top_left = int(size / 2)
	style.corner_radius_top_right = int(size / 2)
	style.corner_radius_bottom_left = int(size / 2)
	style.corner_radius_bottom_right = int(size / 2)
	sparkle.add_theme_stylebox_override("panel", style)

	sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE

	return sparkle


## Flash the background for legendary reveals
func _flash_background(color: Color) -> void:
	var original_color = background.color
	var flash_tween = create_tween()
	flash_tween.tween_property(background, "color", color.lightened(0.3), 0.1)
	flash_tween.tween_property(background, "color", original_color, 0.3)


func _skip_to_end() -> void:
	if not is_revealing:
		return

	can_skip = false
	skip_button.visible = false

	# Instantly reveal all remaining cards
	for i in range(revealing_index, opened_cards.size()):
		if i < card_panels.size():
			_populate_card_panel(card_panels[i], opened_cards[i])
			card_panels[i].scale = Vector2(1, 1)
			if opened_cards[i].rarity >= CardData.Rarity.RARE:
				_add_card_glow(card_panels[i], opened_cards[i])
			card_revealed.emit(opened_cards[i], i)

	revealing_index = opened_cards.size()
	_finish_reveal()


func _finish_reveal() -> void:
	is_revealing = false
	can_skip = false
	skip_button.visible = false

	# Count rarities for summary
	var rarity_counts = {
		CardData.Rarity.COMMON: 0,
		CardData.Rarity.RARE: 0,
		CardData.Rarity.EPIC: 0,
		CardData.Rarity.LEGENDARY: 0
	}
	for card in opened_cards:
		rarity_counts[card.rarity] += 1

	# Update subtitle with summary
	var summary_parts = []
	if rarity_counts[CardData.Rarity.LEGENDARY] > 0:
		summary_parts.append("%d Legendary!" % rarity_counts[CardData.Rarity.LEGENDARY])
	if rarity_counts[CardData.Rarity.EPIC] > 0:
		summary_parts.append("%d Epic" % rarity_counts[CardData.Rarity.EPIC])
	if rarity_counts[CardData.Rarity.RARE] > 0:
		summary_parts.append("%d Rare" % rarity_counts[CardData.Rarity.RARE])
	if rarity_counts[CardData.Rarity.COMMON] > 0:
		summary_parts.append("%d Common" % rarity_counts[CardData.Rarity.COMMON])

	subtitle_label.text = " | ".join(summary_parts)

	# Add cards to player collection and log results
	if player_collection:
		_add_cards_to_collection()

	continue_button.visible = true
	all_cards_revealed.emit()


func _close_pack_opening() -> void:
	opening_complete.emit()
	# Either hide or queue_free depending on usage
	hide()


## Add opened cards to player collection and log summary
func _add_cards_to_collection() -> void:
	if not player_collection or opened_cards.is_empty():
		return

	# Add all cards from this pack to collection
	var result = player_collection.add_cards(opened_cards)

	# Log summary to console
	print("\n=== Pack Opening Collection Update ===")
	print("Pack Type: %s" % ["BASIC", "PREMIUM", "LEGENDARY"][current_pack_type])
	print("Cards in pack: %d" % opened_cards.size())
	print("")

	# New cards (first-time acquisitions)
	if result.added.size() > 0:
		print("NEW CARDS (%d):" % result.added.size())
		for card_id in result.added:
			var card = opened_cards.filter(func(c): return c.card_id == card_id)[0]
			print("  ✓ %s - %s (%s)" % [card_id, card.card_name, card.get_rarity_name()])
	else:
		print("NEW CARDS: None")

	print("")

	# Duplicates
	if result.duplicates.size() > 0:
		print("DUPLICATES (%d):" % result.duplicates.size())
		for card_id in result.duplicates:
			var card = opened_cards.filter(func(c): return c.card_id == card_id)[0]
			var total_owned = player_collection.get_card_count(card_id)
			print("  ↻ %s - %s (now own x%d)" % [card_id, card.card_name, total_owned])
	else:
		print("DUPLICATES: None")

	print("")

	# Collection totals
	print("COLLECTION SUMMARY:")
	print("  Total unique cards: %d" % player_collection.get_unique_card_count())
	print("  Total cards owned: %d" % player_collection.get_total_card_count())
	print("===================================\n")


func _generate_default_card_pool() -> void:
	card_pool.clear()

	# Generate cards from available units
	var units = GameState.get_available_units()
	var rarities = [CardData.Rarity.COMMON, CardData.Rarity.COMMON, CardData.Rarity.RARE, CardData.Rarity.EPIC]

	for i in range(units.size()):
		var rarity = rarities[i % rarities.size()]
		var card = CardData.from_unit_data(units[i], rarity)
		card_pool.append(card)

	# Generate cards from commanders (always legendary)
	var commanders = GameState.get_available_commanders()
	for commander in commanders:
		var card = CardData.from_commander_data(commander)
		card_pool.append(card)

	# Add some generated variety
	var extra_names = [
		["Scout", CardData.Rarity.COMMON],
		["Warrior", CardData.Rarity.COMMON],
		["Archer", CardData.Rarity.COMMON],
		["Defender", CardData.Rarity.RARE],
		["Berserker", CardData.Rarity.RARE],
		["Mystic", CardData.Rarity.EPIC],
		["Warlord", CardData.Rarity.EPIC],
		["Dragon Knight", CardData.Rarity.LEGENDARY]
	]

	for item in extra_names:
		var card = CardData.new()
		card.card_name = item[0]
		card.card_id = "extra_" + item[0].to_lower().replace(" ", "_")
		card.rarity = item[1]
		card.card_type = CardData.CardType.UNIT
		card.energy_cost = 2 + item[1]
		card.health = 80 + item[1] * 25
		card.attack = 10 + item[1] * 7
		card.speed = 80
		card.description = "A skilled %s ready for battle." % item[0].to_lower()
		card_pool.append(card)


## Public API for setting pack type
func set_pack_type(pack_type: PackType) -> void:
	_create_pack_display(pack_type)


## Public API for opening with custom card pool
func set_card_pool(pool: Array[CardData]) -> void:
	card_pool = pool


## Public API for setting player collection (for ownership tracking)
func set_player_collection(collection: PlayerCollection) -> void:
	player_collection = collection


## Reset and show for a new opening
func show_pack(pack_type: PackType = PackType.BASIC) -> void:
	# Reset state
	is_opening = false
	is_revealing = false
	revealing_index = 0
	opened_cards.clear()

	# Reset UI
	pack_container.visible = true
	pack_container.modulate.a = 1.0
	pack_sprite.scale = Vector2(1, 1)
	pack_sprite.rotation = 0
	pack_glow.scale = Vector2(1, 1)

	cards_container.visible = false
	for child in cards_container.get_children():
		child.queue_free()
	card_panels.clear()

	open_button.visible = true
	skip_button.visible = false
	continue_button.visible = false

	_create_pack_display(pack_type)
	show()
