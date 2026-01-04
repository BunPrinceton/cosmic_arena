extends Control

## Force Arena-style main menu controller
## Manages navigation, character display, and game mode selection

const HIGHLIGHT_COLOR = Color(1.0, 0.6, 0.2, 1.0)  # Orange highlight like Force Arena
const NORMAL_COLOR = Color(0.8, 0.8, 0.8, 1.0)
const DISABLED_COLOR = Color(0.4, 0.4, 0.4, 1.0)

# Card colors by rarity
const CARD_COLORS = {
	"common": Color(0.3, 0.3, 0.35, 1.0),
	"rare": Color(0.2, 0.4, 0.7, 1.0),
	"epic": Color(0.5, 0.2, 0.6, 1.0),
	"legendary": Color(0.8, 0.6, 0.2, 1.0)
}

# Animation durations
const TRANSITION_DURATION = 0.4

# UI References - set in _ready via get_node
var top_bar: HBoxContainer
var left_sidebar: VBoxContainer
var center_area: VBoxContainer
var right_panel: VBoxContainer
var character_viewport: SubViewportContainer
var commander_name_label: Label
var character_selector: HBoxContainer
var coming_soon_popup: Panel

# Top bar elements
var player_name_label: Label
var player_title_label: Label
var level_label: Label
var xp_bar: ProgressBar
var xp_text_label: Label
var rank_name_label: Label
var tier_label: Label
var rank_points_label: Label
var credits_label: Label
var gems_label: Label
var gold_label: Label
var currencies_container: Control  # For positioning viewport under currencies

# Navigation state
var nav_buttons: Dictionary = {}
var current_nav: String = "battle"
var current_view: String = "battle"  # "battle" or "deck"
var is_transitioning: bool = false

# Commander selection
var selected_commander_index: int = 0
var available_commanders: Array = []
var commander_buttons: Array = []

# Player data
var player_data: PlayerData

# Deck view elements
var deck_panel: Control
var deck_cards_container: HBoxContainer
var commander_card_panel: Panel
var avg_energy_label: Label
var card_collection_bar: HBoxContainer
var deck_commander_name: Label
var deck_number_label: Label
var calculated_card_size: Vector2 = Vector2(100, 150)  # Will be calculated dynamically

# Card detail popup
var card_detail_popup: Panel

# Store original positions for animation
var original_viewport_size: Vector2
var original_viewport_position: Vector2
var original_viewport_global_position: Vector2
var original_name_position: Vector2
var original_selector_position: Vector2


func _ready() -> void:
	# Initialize player data
	player_data = PlayerData.new()

	# Get available commanders
	available_commanders = GameState.get_available_commanders()

	# Setup all UI sections
	_setup_references()
	_setup_top_bar()
	_setup_navigation()
	_setup_character_selector()
	_setup_game_modes()
	_setup_coming_soon_popup()
	_setup_deck_view()
	_setup_card_detail_popup()

	# Store original positions for animations
	_store_original_positions()

	# Update displays
	_update_player_stats()
	_select_commander(0)


func _setup_references() -> void:
	# Get main containers - using modular percentage-based layout structure
	top_bar = $UIRoot/TopBarContainer/TopBar/HBoxContainer
	left_sidebar = $UIRoot/LeftMenuContainer/LeftSidebar
	center_area = $UIRoot/MainViewContainer/ContentArea/CenterArea
	right_panel = $UIRoot/MainViewContainer/ContentArea/RightPanel
	character_viewport = $UIRoot/MainViewContainer/ContentArea/CenterArea/CharacterViewport
	commander_name_label = $UIRoot/MainViewContainer/ContentArea/CenterArea/CommanderName
	character_selector = $UIRoot/MainViewContainer/ContentArea/CenterArea/CharacterSelector
	coming_soon_popup = $ComingSoonPopup


func _setup_top_bar() -> void:
	# Player info section - paths updated for modular layout
	player_name_label = $UIRoot/TopBarContainer/TopBar/HBoxContainer/PlayerInfo/NameTitle/PlayerName
	player_title_label = $UIRoot/TopBarContainer/TopBar/HBoxContainer/PlayerInfo/NameTitle/PlayerTitle
	level_label = $UIRoot/TopBarContainer/TopBar/HBoxContainer/PlayerInfo/LevelRow/LevelLabel
	xp_bar = $UIRoot/TopBarContainer/TopBar/HBoxContainer/PlayerInfo/LevelRow/XPBar
	xp_text_label = $UIRoot/TopBarContainer/TopBar/HBoxContainer/PlayerInfo/LevelRow/XPText

	# Rank display
	rank_name_label = $UIRoot/TopBarContainer/TopBar/HBoxContainer/RankDisplay/RankInfo/RankName
	tier_label = $UIRoot/TopBarContainer/TopBar/HBoxContainer/RankDisplay/RankInfo/TierRow/TierLabel
	rank_points_label = $UIRoot/TopBarContainer/TopBar/HBoxContainer/RankDisplay/RankInfo/TierRow/RankPoints

	# Currencies
	currencies_container = $UIRoot/TopBarContainer/TopBar/HBoxContainer/Currencies
	credits_label = $UIRoot/TopBarContainer/TopBar/HBoxContainer/Currencies/Credits/CreditsLabel
	gems_label = $UIRoot/TopBarContainer/TopBar/HBoxContainer/Currencies/Gems/GemsLabel
	gold_label = $UIRoot/TopBarContainer/TopBar/HBoxContainer/Currencies/Gold/GoldLabel

	# Connect top bar buttons
	var friends_btn = $UIRoot/TopBarContainer/TopBar/HBoxContainer/FriendsButton
	friends_btn.pressed.connect(_show_coming_soon)

	var collection_btn = $UIRoot/TopBarContainer/TopBar/HBoxContainer/CollectionButton
	collection_btn.pressed.connect(_show_coming_soon)

	var settings_btn = $UIRoot/TopBarContainer/TopBar/HBoxContainer/SettingsButton
	settings_btn.pressed.connect(_on_settings_pressed)


func _setup_navigation() -> void:
	# Navigation items: id, display text, enabled status
	# BATTLE and DECK are fully functional, others coming soon
	var nav_items = [
		{"id": "battle", "text": "BATTLE", "enabled": true},
		{"id": "rewards", "text": "REWARDS", "enabled": false},
		{"id": "deck", "text": "DECK", "enabled": true},  # Now functional!
		{"id": "shop", "text": "SHOP", "enabled": false},
		{"id": "trade", "text": "TRADE", "enabled": false},
		{"id": "guild", "text": "GUILD", "enabled": false},
	]

	for item in nav_items:
		var button = $UIRoot/LeftMenuContainer/LeftSidebar.get_node("Nav_" + item.id.capitalize())
		if button:
			button.set_meta("nav_id", item.id)
			button.set_meta("nav_enabled", item.enabled)
			button.disabled = not item.enabled
			button.pressed.connect(_on_nav_pressed.bind(item.id))
			nav_buttons[item.id] = button

			# Apply base styling to all buttons
			_apply_nav_button_style(button, false, item.enabled)

	# Set initial highlight
	_update_nav_highlight("battle")


func _apply_nav_button_style(button: Button, selected: bool, enabled: bool) -> void:
	# Create base stylebox
	var stylebox = StyleBoxFlat.new()
	stylebox.corner_radius_top_left = 4
	stylebox.corner_radius_top_right = 4
	stylebox.corner_radius_bottom_left = 4
	stylebox.corner_radius_bottom_right = 4
	stylebox.content_margin_left = 10
	stylebox.content_margin_right = 10
	stylebox.content_margin_top = 8
	stylebox.content_margin_bottom = 8

	if not enabled:
		# Disabled state - dark and muted
		stylebox.bg_color = Color(0.12, 0.12, 0.15, 0.6)
		button.add_theme_stylebox_override("normal", stylebox)
		button.add_theme_stylebox_override("hover", stylebox)
		button.add_theme_stylebox_override("pressed", stylebox)
		button.add_theme_stylebox_override("focus", stylebox)
		button.add_theme_stylebox_override("disabled", stylebox)
		button.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1.0))
		button.add_theme_color_override("font_hover_color", Color(0.4, 0.4, 0.4, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(0.4, 0.4, 0.4, 1.0))
		button.add_theme_color_override("font_focus_color", Color(0.4, 0.4, 0.4, 1.0))
		button.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.4, 1.0))
		button.modulate = Color(1, 1, 1, 1)
	elif selected:
		# Selected state - white background, black text
		stylebox.bg_color = Color(1.0, 1.0, 1.0, 1.0)
		button.add_theme_stylebox_override("normal", stylebox)
		button.add_theme_stylebox_override("hover", stylebox)
		button.add_theme_stylebox_override("pressed", stylebox)
		button.add_theme_stylebox_override("focus", stylebox)
		button.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 1.0))
		button.add_theme_color_override("font_hover_color", Color(0.0, 0.0, 0.0, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(0.0, 0.0, 0.0, 1.0))
		button.add_theme_color_override("font_focus_color", Color(0.0, 0.0, 0.0, 1.0))
		button.modulate = Color(1, 1, 1, 1)
	else:
		# Normal state - dark/transparent background, white text
		stylebox.bg_color = Color(0.12, 0.12, 0.15, 0.8)
		button.add_theme_stylebox_override("normal", stylebox)
		button.add_theme_stylebox_override("focus", stylebox)

		# Hover state - slightly lighter
		var hover_style = stylebox.duplicate()
		hover_style.bg_color = Color(0.2, 0.2, 0.25, 0.9)
		button.add_theme_stylebox_override("hover", hover_style)
		button.add_theme_stylebox_override("pressed", hover_style)

		button.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
		button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
		button.add_theme_color_override("font_focus_color", Color(0.9, 0.9, 0.9, 1.0))
		button.modulate = Color(1, 1, 1, 1)


func _on_nav_pressed(nav_id: String) -> void:
	if is_transitioning:
		return

	match nav_id:
		"battle":
			_update_nav_highlight("battle")
			if current_view != "battle":
				_transition_to_battle()
		"deck":
			_update_nav_highlight("deck")
			if current_view != "deck":
				_transition_to_deck()
		_:
			_show_coming_soon()


func _update_nav_highlight(active_id: String) -> void:
	current_nav = active_id
	for id in nav_buttons:
		var button = nav_buttons[id]
		var is_enabled = button.get_meta("nav_enabled", true)
		var is_selected = (id == active_id)
		_apply_nav_button_style(button, is_selected, is_enabled)


func _setup_character_selector() -> void:
	# Clear any existing buttons
	for child in character_selector.get_children():
		child.queue_free()

	commander_buttons.clear()

	# Create 4 commander slots (2 per faction)
	# Layout: [Light1] [Light2] [LightEmblem] [DarkEmblem] [Dark1] [Dark2]

	# Light side commanders (first 2 slots)
	for i in range(2):
		var button = _create_commander_button(i, "light")
		character_selector.add_child(button)
		commander_buttons.append(button)

	# Light side emblem
	var light_emblem = _create_faction_emblem("light")
	character_selector.add_child(light_emblem)

	# Dark side emblem
	var dark_emblem = _create_faction_emblem("dark")
	character_selector.add_child(dark_emblem)

	# Dark side commanders (slots 2-3)
	for i in range(2, 4):
		var button = _create_commander_button(i, "dark")
		character_selector.add_child(button)
		commander_buttons.append(button)


func _create_commander_button(index: int, faction: String) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(55, 55)
	button.text = ""
	button.set_meta("commander_index", index)
	button.pressed.connect(_on_commander_selected.bind(index))

	# Get commander if available, else use placeholder
	var has_commander = index < available_commanders.size()
	var bg_color: Color

	if has_commander:
		bg_color = available_commanders[index].portrait_color
	else:
		# Placeholder - darker color for locked/unavailable
		bg_color = Color(0.2, 0.2, 0.25, 1.0) if faction == "light" else Color(0.25, 0.15, 0.15, 1.0)
		button.disabled = true

	# Normal style - circular button
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = bg_color
	stylebox.corner_radius_top_left = 28
	stylebox.corner_radius_top_right = 28
	stylebox.corner_radius_bottom_left = 28
	stylebox.corner_radius_bottom_right = 28
	stylebox.border_width_top = 2
	stylebox.border_width_bottom = 2
	stylebox.border_width_left = 2
	stylebox.border_width_right = 2
	stylebox.border_color = Color(0.3, 0.3, 0.3, 1.0)
	button.add_theme_stylebox_override("normal", stylebox)

	# Hover style
	var hover_style = stylebox.duplicate()
	hover_style.bg_color = bg_color.lightened(0.15)
	hover_style.border_color = Color(0.6, 0.6, 0.6, 1.0)
	button.add_theme_stylebox_override("hover", hover_style)

	# Disabled style
	var disabled_style = stylebox.duplicate()
	disabled_style.bg_color = bg_color.darkened(0.3)
	button.add_theme_stylebox_override("disabled", disabled_style)

	return button


func _create_faction_emblem(faction: String) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(40, 40)

	var stylebox = StyleBoxFlat.new()
	stylebox.corner_radius_top_left = 20
	stylebox.corner_radius_top_right = 20
	stylebox.corner_radius_bottom_left = 20
	stylebox.corner_radius_bottom_right = 20

	if faction == "light":
		stylebox.bg_color = Color(0.2, 0.5, 0.8, 1.0)  # Blue for light side
	else:
		stylebox.bg_color = Color(0.6, 0.15, 0.15, 1.0)  # Red for dark side

	panel.add_theme_stylebox_override("panel", stylebox)

	# Add faction symbol label
	var label = Label.new()
	label.text = "L" if faction == "light" else "D"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchors_preset = Control.PRESET_FULL_RECT
	label.add_theme_font_size_override("font_size", 18)
	panel.add_child(label)

	return panel


func _on_commander_selected(index: int) -> void:
	_select_commander(index)


func _select_commander(index: int) -> void:
	if index < 0 or index >= available_commanders.size():
		return

	selected_commander_index = index
	var commander = available_commanders[index]

	# Update name display
	commander_name_label.text = commander.commander_name.to_upper()

	# Store in GameState
	GameState.player_commander = commander

	# Update button highlights with golden ring for selected
	for i in range(commander_buttons.size()):
		var btn = commander_buttons[i]
		if btn.disabled:
			continue

		var has_commander = i < available_commanders.size()
		if not has_commander:
			continue

		var cmd = available_commanders[i]
		var bg_color = cmd.portrait_color

		if i == index:
			# Selected - golden highlight ring
			var selected_style = StyleBoxFlat.new()
			selected_style.bg_color = bg_color
			selected_style.corner_radius_top_left = 28
			selected_style.corner_radius_top_right = 28
			selected_style.corner_radius_bottom_left = 28
			selected_style.corner_radius_bottom_right = 28
			selected_style.border_width_top = 3
			selected_style.border_width_bottom = 3
			selected_style.border_width_left = 3
			selected_style.border_width_right = 3
			selected_style.border_color = Color(1.0, 0.8, 0.2, 1.0)  # Golden ring
			btn.add_theme_stylebox_override("normal", selected_style)
			btn.add_theme_stylebox_override("hover", selected_style)
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			# Not selected - dimmed with gray border
			var normal_style = StyleBoxFlat.new()
			normal_style.bg_color = bg_color.darkened(0.2)
			normal_style.corner_radius_top_left = 28
			normal_style.corner_radius_top_right = 28
			normal_style.corner_radius_bottom_left = 28
			normal_style.corner_radius_bottom_right = 28
			normal_style.border_width_top = 2
			normal_style.border_width_bottom = 2
			normal_style.border_width_left = 2
			normal_style.border_width_right = 2
			normal_style.border_color = Color(0.3, 0.3, 0.3, 1.0)
			btn.add_theme_stylebox_override("normal", normal_style)

			var hover_style = normal_style.duplicate()
			hover_style.bg_color = bg_color
			hover_style.border_color = Color(0.6, 0.6, 0.6, 1.0)
			btn.add_theme_stylebox_override("hover", hover_style)
			btn.modulate = Color(0.8, 0.8, 0.8, 1.0)

	# Update 3D viewport
	var viewport = character_viewport.get_node("SubViewport")
	if viewport.has_method("set_commander"):
		viewport.set_commander(commander)


func _setup_game_modes() -> void:
	# Game mode buttons with their paths
	var modes = [
		{"id": "1v1", "path": "Mode_1v1", "enabled": true},
		{"id": "2vs2", "path": "Mode_2vs2", "enabled": false},
		{"id": "teamup", "path": "BottomModes/Mode_TeamUp", "enabled": false},
		{"id": "training", "path": "BottomModes/Mode_Training", "enabled": true},
	]

	for mode in modes:
		var panel = right_panel.get_node_or_null(mode.path)
		if panel:
			if mode.enabled:
				panel.gui_input.connect(_on_game_mode_input.bind(mode.id))
			else:
				panel.modulate = Color(0.5, 0.5, 0.5, 0.7)


func _on_game_mode_input(event: InputEvent, mode_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		match mode_id:
			"1v1":
				# Launch 3D battle
				get_tree().change_scene_to_file("res://scenes/main_3d.tscn")
			"training":
				# Training mode also goes to 3D scene
				get_tree().change_scene_to_file("res://scenes/main_3d.tscn")
			_:
				_show_coming_soon()


func _setup_coming_soon_popup() -> void:
	coming_soon_popup.hide()
	var close_btn = coming_soon_popup.get_node_or_null("VBoxContainer/CloseButton")
	if close_btn:
		close_btn.pressed.connect(_hide_coming_soon)


func _show_coming_soon() -> void:
	coming_soon_popup.show()


func _hide_coming_soon() -> void:
	coming_soon_popup.hide()


func _on_settings_pressed() -> void:
	_show_coming_soon()


func _update_player_stats() -> void:
	# Player identity
	if player_name_label:
		player_name_label.text = player_data.player_name
	if player_title_label:
		player_title_label.text = player_data.player_title

	# Level and XP
	if level_label:
		level_label.text = "Lv. %d" % player_data.level
	if xp_bar:
		xp_bar.value = player_data.get_xp_progress() * 100.0
	if xp_text_label:
		xp_text_label.text = "%d / %d" % [player_data.current_xp, player_data.xp_to_next_level]

	# Rank display
	if rank_name_label:
		rank_name_label.text = player_data.rank_tier.to_upper()
	if tier_label:
		tier_label.text = "TIER %d" % player_data.rank_tier_level
	if rank_points_label:
		rank_points_label.text = str(player_data.rank_points)

	# Currencies
	if credits_label:
		credits_label.text = _format_number(player_data.credits)
	if gems_label:
		gems_label.text = str(player_data.gems)
	if gold_label:
		gold_label.text = _format_number(player_data.gold)


## Format number with comma separators
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


## Store original positions for animation
func _store_original_positions() -> void:
	if character_viewport:
		original_viewport_size = character_viewport.custom_minimum_size
		original_viewport_position = character_viewport.position
		original_viewport_global_position = character_viewport.global_position
	if commander_name_label:
		original_name_position = commander_name_label.position
	if character_selector:
		original_selector_position = character_selector.position


## Setup the deck view panel (initially hidden)
func _setup_deck_view() -> void:
	# Create main deck panel container
	deck_panel = Control.new()
	deck_panel.name = "DeckPanel"
	deck_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	deck_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck_panel.modulate.a = 0.0  # Start invisible
	deck_panel.z_index = 10  # Above the character viewport (which is z_index 1)
	add_child(deck_panel)

	# Create the deck cards area at bottom of screen
	var deck_area = VBoxContainer.new()
	deck_area.name = "DeckArea"
	deck_area.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	deck_area.anchor_top = 0.58
	deck_area.offset_top = 0
	deck_area.offset_bottom = -10
	deck_area.offset_left = 120  # Account for sidebar (100px) + padding (20px)
	deck_area.offset_right = -20  # Right margin
	deck_panel.add_child(deck_area)

	# Average energy cost label (top right of deck area)
	var energy_row = HBoxContainer.new()
	energy_row.alignment = BoxContainer.ALIGNMENT_END
	deck_area.add_child(energy_row)

	avg_energy_label = Label.new()
	avg_energy_label.text = "Average Energy Cost ⚡3.0"
	avg_energy_label.add_theme_font_size_override("font_size", 16)
	avg_energy_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	energy_row.add_child(avg_energy_label)

	# Cards container (horizontal row) - fills available width
	deck_cards_container = HBoxContainer.new()
	deck_cards_container.name = "DeckCards"
	deck_cards_container.alignment = BoxContainer.ALIGNMENT_BEGIN  # Left-align to avoid sidebar overlap
	deck_cards_container.add_theme_constant_override("separation", 12)  # Spacing between cards
	deck_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_cards_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_area.add_child(deck_cards_container)

	# Card collection bar at bottom
	card_collection_bar = HBoxContainer.new()
	card_collection_bar.name = "CardCollectionBar"
	card_collection_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	card_collection_bar.add_theme_constant_override("separation", 20)
	deck_area.add_child(card_collection_bar)

	# Deck indicator (1/4 style)
	var deck_indicator = HBoxContainer.new()
	deck_indicator.add_theme_constant_override("separation", 5)
	card_collection_bar.add_child(deck_indicator)

	var deck_icon = ColorRect.new()
	deck_icon.custom_minimum_size = Vector2(20, 20)
	deck_icon.color = Color(0.4, 0.4, 0.5, 1.0)
	deck_indicator.add_child(deck_icon)

	deck_number_label = Label.new()
	deck_number_label.text = "1 / 4"
	deck_number_label.add_theme_font_size_override("font_size", 14)
	deck_indicator.add_child(deck_number_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_collection_bar.add_child(spacer)

	# Card collection count
	var collection_label = Label.new()
	collection_label.text = "Card Collection"
	collection_label.add_theme_font_size_override("font_size", 14)
	collection_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	card_collection_bar.add_child(collection_label)

	var collection_count = Label.new()
	collection_count.name = "CollectionCount"
	collection_count.text = "4 / 10"
	collection_count.add_theme_font_size_override("font_size", 14)
	collection_count.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	card_collection_bar.add_child(collection_count)

	# Edit button
	var edit_btn = Button.new()
	edit_btn.text = "▲ Edit"
	edit_btn.add_theme_font_size_override("font_size", 12)
	edit_btn.pressed.connect(_show_coming_soon)
	card_collection_bar.add_child(edit_btn)

	# Menu button
	var menu_btn = Button.new()
	menu_btn.text = "≡"
	menu_btn.custom_minimum_size = Vector2(30, 30)
	menu_btn.pressed.connect(_show_coming_soon)
	card_collection_bar.add_child(menu_btn)


## Create a unit card UI element
func _create_unit_card(unit_data: UnitData, index: int) -> Panel:
	var card = Panel.new()
	card.name = "Card_" + str(index)
	card.custom_minimum_size = calculated_card_size
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.set_meta("unit_data", unit_data)
	card.set_meta("card_index", index)

	# Card background style
	var style = StyleBoxFlat.new()
	style.bg_color = CARD_COLORS["common"]
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.5, 0.5, 0.5, 1.0)
	card.add_theme_stylebox_override("panel", style)

	# Make clickable
	card.gui_input.connect(_on_card_clicked.bind(unit_data, false))

	# Energy cost (top left corner)
	var energy_badge = Panel.new()
	energy_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	energy_badge.offset_right = 28
	energy_badge.offset_bottom = 28
	var energy_style = StyleBoxFlat.new()
	energy_style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	energy_style.corner_radius_top_left = 6
	energy_style.corner_radius_bottom_right = 8
	energy_badge.add_theme_stylebox_override("panel", energy_style)
	card.add_child(energy_badge)

	var energy_icon = Label.new()
	energy_icon.text = "⚡" + str(int(unit_data.energy_cost))
	energy_icon.set_anchors_preset(Control.PRESET_CENTER)
	energy_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_icon.add_theme_font_size_override("font_size", 12)
	energy_icon.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	energy_badge.add_child(energy_icon)

	# Card image placeholder (center)
	var image_rect = ColorRect.new()
	image_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	image_rect.offset_left = 5
	image_rect.offset_top = 30
	image_rect.offset_right = -5
	image_rect.offset_bottom = -50
	image_rect.color = unit_data.visual_color.darkened(0.3)
	card.add_child(image_rect)

	# Unit name initial
	var name_label = Label.new()
	name_label.text = unit_data.unit_name.substr(0, 1)
	name_label.set_anchors_preset(Control.PRESET_CENTER)
	name_label.position.y = -20
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	image_rect.add_child(name_label)

	# Level badge (bottom left)
	var level_container = HBoxContainer.new()
	level_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	level_container.offset_left = 5
	level_container.offset_top = -45
	level_container.offset_bottom = -30
	card.add_child(level_container)

	var level_label = Label.new()
	level_label.text = "Lv. 1"
	level_label.add_theme_font_size_override("font_size", 11)
	level_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	level_container.add_child(level_label)

	# Progress bar (bottom)
	var progress_container = VBoxContainer.new()
	progress_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	progress_container.offset_left = 5
	progress_container.offset_right = -5
	progress_container.offset_top = -28
	progress_container.offset_bottom = -5
	card.add_child(progress_container)

	var progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 8)
	progress_bar.value = randi_range(20, 80)  # Simulated progress
	progress_bar.show_percentage = false
	progress_container.add_child(progress_bar)

	var progress_label = Label.new()
	progress_label.text = "%d / %d" % [randi_range(1, 8), randi_range(8, 30)]
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 9)
	progress_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	progress_container.add_child(progress_label)

	return card


## Create commander card (larger, for deck view)
func _create_commander_card(commander: CommanderData) -> Panel:
	var card = Panel.new()
	card.name = "CommanderCard"
	card.custom_minimum_size = calculated_card_size
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.set_meta("commander_data", commander)

	# Card background style (legendary gold border)
	var style = StyleBoxFlat.new()
	style.bg_color = commander.portrait_color.darkened(0.2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_color = Color(0.8, 0.6, 0.2, 1.0)  # Gold border
	card.add_theme_stylebox_override("panel", style)

	# Make clickable
	card.gui_input.connect(_on_card_clicked.bind(commander, true))

	# Commander image placeholder
	var image_rect = ColorRect.new()
	image_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	image_rect.offset_left = 8
	image_rect.offset_top = 8
	image_rect.offset_right = -8
	image_rect.offset_bottom = -55
	image_rect.color = commander.portrait_color
	card.add_child(image_rect)

	# Commander initial
	var name_initial = Label.new()
	name_initial.text = commander.commander_name.substr(0, 2)
	name_initial.set_anchors_preset(Control.PRESET_CENTER)
	name_initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_initial.add_theme_font_size_override("font_size", 36)
	name_initial.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	image_rect.add_child(name_initial)

	# Level badge
	var level_badge = Panel.new()
	level_badge.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	level_badge.offset_left = 5
	level_badge.offset_top = -50
	level_badge.offset_right = 45
	level_badge.offset_bottom = -30
	var level_style = StyleBoxFlat.new()
	level_style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	level_style.corner_radius_top_left = 4
	level_style.corner_radius_top_right = 4
	level_style.corner_radius_bottom_left = 4
	level_style.corner_radius_bottom_right = 4
	level_badge.add_theme_stylebox_override("panel", level_style)
	card.add_child(level_badge)

	var level_label = Label.new()
	level_label.text = "Lv. 1"
	level_label.set_anchors_preset(Control.PRESET_CENTER)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 11)
	level_badge.add_child(level_label)

	# Progress bar
	var progress_container = VBoxContainer.new()
	progress_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	progress_container.offset_left = 5
	progress_container.offset_right = -5
	progress_container.offset_top = -28
	progress_container.offset_bottom = -5
	card.add_child(progress_container)

	var progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 8)
	progress_bar.value = 25
	progress_bar.show_percentage = false
	progress_container.add_child(progress_bar)

	var progress_label = Label.new()
	progress_label.text = "1 / 4"
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 9)
	progress_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	progress_container.add_child(progress_label)

	return card


## Calculate optimal card size based on available screen space
func _calculate_card_size() -> Vector2:
	var screen_size = get_viewport_rect().size

	# Available width: screen width minus left margin (120) and right margin (20)
	var available_width = screen_size.x - 120 - 20

	# Total cards to display: 1 commander + 1 special + 6 support = 8 cards
	var total_cards = 8
	var separation = 12  # Spacing between cards

	# Calculate card width: (available_width - total_separation) / num_cards
	var total_separation = (total_cards - 1) * separation
	var card_width = (available_width - total_separation) / total_cards

	# Clamp card width to reasonable bounds (min 70, max 150)
	card_width = clamp(card_width, 70.0, 150.0)

	# Maintain aspect ratio of 1:1.5 (width:height)
	var card_height = card_width * 1.5

	return Vector2(card_width, card_height)

## Populate deck cards
func _populate_deck_cards() -> void:
	# Clear existing cards
	for child in deck_cards_container.get_children():
		child.queue_free()

	# Calculate optimal card size based on available space
	calculated_card_size = _calculate_card_size()

	# Get current commander
	var commander = available_commanders[selected_commander_index] if selected_commander_index < available_commanders.size() else null
	var total_energy: float = 0.0
	var card_count: int = 0

	# 1. Add commander card first
	if commander:
		var cmd_card = _create_commander_card(commander)
		deck_cards_container.add_child(cmd_card)
		card_count += 1

	# 2. Add commander's special unit card
	if commander and commander.special_unit:
		var special_card = _create_special_unit_card(commander.special_unit, commander)
		deck_cards_container.add_child(special_card)
		total_energy += commander.special_unit.energy_cost
		card_count += 1
	elif commander:
		# Create placeholder special unit card if none assigned
		var placeholder = _create_placeholder_card("Special", Color(0.6, 0.4, 0.7, 1.0))
		deck_cards_container.add_child(placeholder)
		card_count += 1

	# 3. Add 6 support unit cards from player deck
	var units = GameState.player_deck.units if GameState.player_deck else GameState.get_available_units()
	var support_count = 0

	for i in range(min(units.size(), Deck.SUPPORT_SLOTS)):
		var unit_card = _create_unit_card(units[i], i)
		deck_cards_container.add_child(unit_card)
		total_energy += units[i].energy_cost
		support_count += 1
		card_count += 1

	# Fill remaining slots with placeholders if needed
	while support_count < Deck.SUPPORT_SLOTS:
		var placeholder = _create_placeholder_card("Empty", Color(0.25, 0.25, 0.3, 1.0))
		deck_cards_container.add_child(placeholder)
		support_count += 1
		card_count += 1

	# Update average energy cost (only count cards with energy)
	var energy_cards = (1 if commander and commander.special_unit else 0) + min(units.size(), Deck.SUPPORT_SLOTS)
	var avg_cost = total_energy / max(energy_cards, 1)
	avg_energy_label.text = "Average Energy Cost ⚡%.1f" % avg_cost

	# Update collection count
	var collection_count_label = deck_panel.get_node_or_null("DeckArea/CardCollectionBar/CollectionCount")
	if collection_count_label:
		var total_available = GameState.get_available_units().size()
		collection_count_label.text = "%d / %d" % [min(units.size(), Deck.SUPPORT_SLOTS), total_available + 4]  # +4 for potential special units


## Create a special unit card (commander's unique unit)
func _create_special_unit_card(unit_data: UnitData, commander: CommanderData) -> Panel:
	var card = Panel.new()
	card.name = "SpecialCard"
	card.custom_minimum_size = calculated_card_size
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.set_meta("unit_data", unit_data)
	card.set_meta("is_special", true)

	# Card background style with purple/unique border
	var style = StyleBoxFlat.new()
	style.bg_color = unit_data.visual_color.darkened(0.2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_color = Color(0.7, 0.4, 0.9, 1.0)  # Purple border for special unit
	card.add_theme_stylebox_override("panel", style)

	# Make clickable
	card.gui_input.connect(_on_card_clicked.bind(unit_data, false))

	# Energy cost (top left corner)
	var energy_badge = Panel.new()
	energy_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	energy_badge.offset_right = 28
	energy_badge.offset_bottom = 28
	var energy_style = StyleBoxFlat.new()
	energy_style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	energy_style.corner_radius_top_left = 6
	energy_style.corner_radius_bottom_right = 8
	energy_badge.add_theme_stylebox_override("panel", energy_style)
	card.add_child(energy_badge)

	var energy_icon = Label.new()
	energy_icon.text = "⚡" + str(int(unit_data.energy_cost))
	energy_icon.set_anchors_preset(Control.PRESET_CENTER)
	energy_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_icon.add_theme_font_size_override("font_size", 12)
	energy_icon.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	energy_badge.add_child(energy_icon)

	# "Unique" badge (top right)
	var unique_badge = Label.new()
	unique_badge.text = "★"
	unique_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	unique_badge.offset_left = -25
	unique_badge.offset_right = -5
	unique_badge.offset_bottom = 20
	unique_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unique_badge.add_theme_font_size_override("font_size", 16)
	unique_badge.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0, 1.0))
	card.add_child(unique_badge)

	# Card image placeholder (center)
	var image_rect = ColorRect.new()
	image_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	image_rect.offset_left = 5
	image_rect.offset_top = 30
	image_rect.offset_right = -5
	image_rect.offset_bottom = -50
	image_rect.color = unit_data.visual_color
	card.add_child(image_rect)

	# Unit name initial
	var name_label = Label.new()
	name_label.text = unit_data.unit_name.substr(0, 2)
	name_label.set_anchors_preset(Control.PRESET_CENTER)
	name_label.position.y = -20
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	image_rect.add_child(name_label)

	# Level badge (bottom left)
	var level_container = HBoxContainer.new()
	level_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	level_container.offset_left = 5
	level_container.offset_top = -45
	level_container.offset_bottom = -30
	card.add_child(level_container)

	var level_label = Label.new()
	level_label.text = "Lv. 1"
	level_label.add_theme_font_size_override("font_size", 11)
	level_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	level_container.add_child(level_label)

	# Progress bar (bottom)
	var progress_container = VBoxContainer.new()
	progress_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	progress_container.offset_left = 5
	progress_container.offset_right = -5
	progress_container.offset_top = -28
	progress_container.offset_bottom = -5
	card.add_child(progress_container)

	var progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 8)
	progress_bar.value = randi_range(10, 50)
	progress_bar.show_percentage = false
	progress_container.add_child(progress_bar)

	var progress_label = Label.new()
	progress_label.text = "%d / %d" % [randi_range(1, 4), randi_range(4, 10)]
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 9)
	progress_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	progress_container.add_child(progress_label)

	return card


## Create a placeholder card for empty slots
func _create_placeholder_card(text: String, color: Color) -> Panel:
	var card = Panel.new()
	card.name = "Placeholder_" + text
	card.custom_minimum_size = calculated_card_size
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Card background style
	var style = StyleBoxFlat.new()
	style.bg_color = color.darkened(0.3)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = color.darkened(0.1)
	card.add_theme_stylebox_override("panel", style)

	# Placeholder text
	var label = Label.new()
	label.text = "+"
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", color.lightened(0.2))
	card.add_child(label)

	# Make clickable to add card
	card.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_coming_soon()  # Will be card selection later
	)

	return card


## Setup card detail popup
func _setup_card_detail_popup() -> void:
	card_detail_popup = Panel.new()
	card_detail_popup.name = "CardDetailPopup"
	card_detail_popup.set_anchors_preset(Control.PRESET_CENTER)
	card_detail_popup.offset_left = -300
	card_detail_popup.offset_top = -200
	card_detail_popup.offset_right = 300
	card_detail_popup.offset_bottom = 200
	card_detail_popup.visible = false

	var popup_style = StyleBoxFlat.new()
	popup_style.bg_color = Color(0.12, 0.12, 0.15, 0.98)
	popup_style.corner_radius_top_left = 12
	popup_style.corner_radius_top_right = 12
	popup_style.corner_radius_bottom_left = 12
	popup_style.corner_radius_bottom_right = 12
	popup_style.border_width_top = 2
	popup_style.border_width_bottom = 2
	popup_style.border_width_left = 2
	popup_style.border_width_right = 2
	popup_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	card_detail_popup.add_theme_stylebox_override("panel", popup_style)

	add_child(card_detail_popup)

	# Main layout
	var main_hbox = HBoxContainer.new()
	main_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_hbox.offset_left = 15
	main_hbox.offset_top = 15
	main_hbox.offset_right = -15
	main_hbox.offset_bottom = -15
	main_hbox.add_theme_constant_override("separation", 20)
	card_detail_popup.add_child(main_hbox)

	# Left side - card preview
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(150, 0)
	left_panel.add_theme_constant_override("separation", 10)
	main_hbox.add_child(left_panel)

	var card_preview = Panel.new()
	card_preview.name = "CardPreview"
	card_preview.custom_minimum_size = Vector2(130, 180)
	left_panel.add_child(card_preview)

	var upgrade_btn = Button.new()
	upgrade_btn.name = "UpgradeButton"
	upgrade_btn.text = "UPGRADE\n2,000"
	upgrade_btn.custom_minimum_size = Vector2(130, 50)
	upgrade_btn.pressed.connect(_show_coming_soon)
	left_panel.add_child(upgrade_btn)

	# Right side - info
	var right_panel_popup = VBoxContainer.new()
	right_panel_popup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel_popup.add_theme_constant_override("separation", 8)
	main_hbox.add_child(right_panel_popup)

	# Title row with close button
	var title_row = HBoxContainer.new()
	right_panel_popup.add_child(title_row)

	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "UNIT NAME"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 22)
	title_row.add_child(title_label)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(35, 35)
	close_btn.pressed.connect(_close_card_detail)
	title_row.add_child(close_btn)

	# Type/Rarity info
	var info_grid = GridContainer.new()
	info_grid.columns = 2
	info_grid.add_theme_constant_override("h_separation", 30)
	info_grid.add_theme_constant_override("v_separation", 5)
	right_panel_popup.add_child(info_grid)

	_add_info_row(info_grid, "Type", "Squad")
	_add_info_row(info_grid, "Rarity", "Common")

	# Description
	var desc_label = Label.new()
	desc_label.name = "DescriptionLabel"
	desc_label.text = "Unit description goes here."
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(0, 60)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	right_panel_popup.add_child(desc_label)

	# Tabs (Battle Info / Details)
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	right_panel_popup.add_child(tabs)

	var battle_info_tab = Button.new()
	battle_info_tab.text = "Battle Info"
	battle_info_tab.custom_minimum_size = Vector2(100, 35)
	battle_info_tab.disabled = true  # Currently selected
	tabs.add_child(battle_info_tab)

	var details_tab = Button.new()
	details_tab.text = "Details"
	details_tab.custom_minimum_size = Vector2(100, 35)
	details_tab.pressed.connect(_show_coming_soon)
	tabs.add_child(details_tab)

	# Stats grid
	var stats_grid = GridContainer.new()
	stats_grid.name = "StatsGrid"
	stats_grid.columns = 3
	stats_grid.add_theme_constant_override("h_separation", 25)
	stats_grid.add_theme_constant_override("v_separation", 10)
	right_panel_popup.add_child(stats_grid)


func _add_info_row(parent: GridContainer, label_text: String, value_text: String) -> void:
	var label = Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	label.add_theme_font_size_override("font_size", 12)
	parent.add_child(label)

	var value = Label.new()
	value.name = label_text + "Value"
	value.text = value_text
	value.add_theme_font_size_override("font_size", 12)
	parent.add_child(value)


func _add_stat_item(parent: GridContainer, icon: String, label_text: String, value_text: String) -> void:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	parent.add_child(container)

	var icon_label = Label.new()
	icon_label.text = icon
	icon_label.add_theme_font_size_override("font_size", 16)
	container.add_child(icon_label)

	var info = VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	container.add_child(info)

	var name_lbl = Label.new()
	name_lbl.text = label_text
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	info.add_child(name_lbl)

	var value_lbl = Label.new()
	value_lbl.text = value_text
	value_lbl.add_theme_font_size_override("font_size", 14)
	info.add_child(value_lbl)


## Handle card clicks
func _on_card_clicked(event: InputEvent, data, is_commander: bool) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_card_detail(data, is_commander)


## Show card detail popup
func _show_card_detail(data, is_commander: bool) -> void:
	if not card_detail_popup:
		return

	var title_label = card_detail_popup.get_node_or_null("HBoxContainer/VBoxContainer/HBoxContainer/TitleLabel")
	var desc_label = card_detail_popup.get_node_or_null("HBoxContainer/VBoxContainer/DescriptionLabel")
	var stats_grid = card_detail_popup.get_node_or_null("HBoxContainer/VBoxContainer/StatsGrid")

	# Clear existing stats
	if stats_grid:
		for child in stats_grid.get_children():
			child.queue_free()

	if is_commander and data is CommanderData:
		var commander: CommanderData = data
		if title_label:
			title_label.text = commander.commander_name.to_upper()
		if desc_label:
			desc_label.text = commander.description if commander.description else "A powerful commander."

		if stats_grid:
			_add_stat_item(stats_grid, "❤", "Health", str(int(commander.max_health)))
			_add_stat_item(stats_grid, "⚔", "Attack Power", str(int(commander.attack_damage)))
			_add_stat_item(stats_grid, "→", "Movement Speed", "%.1f" % commander.move_speed)
			_add_stat_item(stats_grid, "⏱", "Attack Speed", "%.2fs" % commander.attack_cooldown)
			_add_stat_item(stats_grid, "◎", "Target", "All")
			_add_stat_item(stats_grid, "↔", "Attack Range", str(int(commander.attack_range)))

	elif data is UnitData:
		var unit: UnitData = data
		if title_label:
			title_label.text = unit.unit_name.to_upper()
		if desc_label:
			desc_label.text = unit.description if unit.description else "A deployable unit."

		if stats_grid:
			_add_stat_item(stats_grid, "❤", "Health", str(int(unit.max_health)))
			_add_stat_item(stats_grid, "⚔", "Attack Power", str(int(unit.attack_damage)))
			_add_stat_item(stats_grid, "→", "Movement Speed", "%.1f" % unit.move_speed)
			_add_stat_item(stats_grid, "⏱", "Attack Speed", "%.2fs" % unit.attack_cooldown)
			_add_stat_item(stats_grid, "◎", "Target", "All")
			_add_stat_item(stats_grid, "↔", "Attack Range", str(int(unit.attack_range)))

	card_detail_popup.visible = true


## Close card detail popup
func _close_card_detail() -> void:
	if card_detail_popup:
		card_detail_popup.visible = false


## Transition to deck view
func _transition_to_deck() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	current_view = "deck"

	# Populate deck cards
	_populate_deck_cards()

	# Reparent commander name and selector to deck_panel so VBoxContainer doesn't control them
	if commander_name_label and commander_name_label.get_parent() == center_area:
		var global_pos = commander_name_label.global_position
		commander_name_label.reparent(deck_panel)
		commander_name_label.global_position = global_pos

	if character_selector and character_selector.get_parent() == center_area:
		var global_pos = character_selector.global_position
		character_selector.reparent(deck_panel)
		character_selector.global_position = global_pos

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# Fade out right panel (game modes)
	tween.tween_property(right_panel, "modulate:a", 0.0, TRANSITION_DURATION)

	# Fade in deck panel
	tween.tween_property(deck_panel, "modulate:a", 1.0, TRANSITION_DURATION)

	# Zoom in the 3D character
	var viewport = character_viewport.get_node_or_null("SubViewport")
	if viewport and viewport.has_method("zoom_in_for_deck"):
		viewport.zoom_in_for_deck()

	# Reparent viewport to main control so we can move it freely (not deck_panel which fades)
	if character_viewport and character_viewport.get_parent() == center_area:
		var global_pos = character_viewport.global_position
		character_viewport.reparent(self)
		character_viewport.global_position = global_pos
		# Set z_index above background (0) but below deck UI (10)
		character_viewport.z_index = 1

	# Move the viewport to the right side of the screen (aligned with gold currency)
	if character_viewport and currencies_container:
		var screen_size = get_viewport_rect().size
		# Get currencies position - align with left side (gold currency area)
		var currencies_left_x = currencies_container.global_position.x
		var currencies_bottom = currencies_container.global_position.y + currencies_container.size.y

		# Scale viewport size based on screen height for responsiveness
		# Use 180% screen height for good coverage
		var viewport_height = screen_size.y * 1.8  # 180% of screen height
		var viewport_width = viewport_height * 0.85  # Maintain aspect ratio

		# Position viewport - moved left and up to center the character
		var target_x = currencies_left_x - (viewport_width * 0.3) - 650  # Adjusted right 60px
		var target_y = -500  # Adjusted down 100px

		tween.tween_property(character_viewport, "global_position", Vector2(target_x, target_y), TRANSITION_DURATION)
		tween.tween_property(character_viewport, "custom_minimum_size", Vector2(viewport_width, viewport_height), TRANSITION_DURATION)

	# Move commander name and selector UP and LEFT into the empty space above cards
	# Target area: left side, above the deck cards row
	if commander_name_label:
		# Move up and align left
		tween.tween_property(commander_name_label, "global_position", Vector2(130, 180), TRANSITION_DURATION)
		tween.tween_property(commander_name_label, "horizontal_alignment", HORIZONTAL_ALIGNMENT_LEFT, 0.01)

	# Move character selector up into empty space (below commander name)
	if character_selector:
		tween.tween_property(character_selector, "global_position", Vector2(200, 340), TRANSITION_DURATION)

	# Finish transition
	tween.chain().tween_callback(func():
		right_panel.visible = false
		is_transitioning = false
	)


## Transition to battle view
func _transition_to_battle() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	current_view = "battle"

	right_panel.visible = true

	# Calculate target positions by temporarily checking where VBoxContainer would place things
	# Do this BEFORE animating, while elements are still in deck_panel

	# Calculate battle view target positions based on stored originals
	var target_viewport_pos = original_viewport_global_position
	var target_viewport_size = original_viewport_size
	var target_name_pos = center_area.global_position + original_name_position
	var target_selector_pos = center_area.global_position + original_selector_position

	# Create tween and animate BEFORE reparenting
	# Keep elements in their current parents (deck_panel or self) during animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# Fade in right panel (game modes)
	tween.tween_property(right_panel, "modulate:a", 1.0, TRANSITION_DURATION)

	# Fade out deck panel
	tween.tween_property(deck_panel, "modulate:a", 0.0, TRANSITION_DURATION)

	# Zoom out the 3D character
	var viewport = character_viewport.get_node_or_null("SubViewport")
	if viewport and viewport.has_method("zoom_out_for_battle"):
		viewport.zoom_out_for_battle()

	# Animate viewport back to battle position and size
	if character_viewport:
		tween.tween_property(character_viewport, "global_position", target_viewport_pos, TRANSITION_DURATION)
		tween.tween_property(character_viewport, "custom_minimum_size", target_viewport_size, TRANSITION_DURATION)

	# Animate commander name and selector back to battle positions
	if commander_name_label:
		tween.tween_property(commander_name_label, "global_position", target_name_pos, TRANSITION_DURATION)
		tween.tween_property(commander_name_label, "horizontal_alignment", HORIZONTAL_ALIGNMENT_CENTER, 0.01)

	if character_selector:
		tween.tween_property(character_selector, "global_position", target_selector_pos, TRANSITION_DURATION)

	# AFTER animation completes, reparent everything back to center_area
	tween.chain().tween_callback(func():
		# Reparent viewport back to center_area
		if character_viewport and character_viewport.get_parent() == self:
			character_viewport.reparent(center_area)
			center_area.move_child(character_viewport, 0)
			character_viewport.z_index = 0

		# Reparent back to center_area so VBoxContainer manages them again
		if commander_name_label and commander_name_label.get_parent() == deck_panel:
			commander_name_label.reparent(center_area)
			# Move to correct position in VBoxContainer (index 1, after viewport)
			center_area.move_child(commander_name_label, 1)

		if character_selector and character_selector.get_parent() == deck_panel:
			character_selector.reparent(center_area)
			# Move to correct position in VBoxContainer (index 2, after name)
			center_area.move_child(character_selector, 2)

		is_transitioning = false
	)
