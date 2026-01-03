extends Control

## Force Arena-style main menu controller
## Manages navigation, character display, and game mode selection

const HIGHLIGHT_COLOR = Color(1.0, 0.6, 0.2, 1.0)  # Orange highlight like Force Arena
const NORMAL_COLOR = Color(0.8, 0.8, 0.8, 1.0)
const DISABLED_COLOR = Color(0.4, 0.4, 0.4, 1.0)

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

# Navigation state
var nav_buttons: Dictionary = {}
var current_nav: String = "battle"

# Commander selection
var selected_commander_index: int = 0
var available_commanders: Array = []
var commander_buttons: Array = []

# Player data
var player_data: PlayerData


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

	# Update displays
	_update_player_stats()
	_select_commander(0)


func _setup_references() -> void:
	# Get main containers
	top_bar = $MainLayout/RightSection/TopBar/HBoxContainer
	left_sidebar = $MainLayout/LeftSidebar
	center_area = $MainLayout/RightSection/ContentArea/CenterArea
	right_panel = $MainLayout/RightSection/ContentArea/RightPanel
	character_viewport = $MainLayout/RightSection/ContentArea/CenterArea/CharacterViewport
	commander_name_label = $MainLayout/RightSection/ContentArea/CenterArea/CommanderName
	character_selector = $MainLayout/RightSection/ContentArea/CenterArea/CharacterSelector
	coming_soon_popup = $ComingSoonPopup


func _setup_top_bar() -> void:
	# Player info section
	player_name_label = $MainLayout/RightSection/TopBar/HBoxContainer/PlayerInfo/NameTitle/PlayerName
	player_title_label = $MainLayout/RightSection/TopBar/HBoxContainer/PlayerInfo/NameTitle/PlayerTitle
	level_label = $MainLayout/RightSection/TopBar/HBoxContainer/PlayerInfo/LevelRow/LevelLabel
	xp_bar = $MainLayout/RightSection/TopBar/HBoxContainer/PlayerInfo/LevelRow/XPBar
	xp_text_label = $MainLayout/RightSection/TopBar/HBoxContainer/PlayerInfo/LevelRow/XPText

	# Rank display
	rank_name_label = $MainLayout/RightSection/TopBar/HBoxContainer/RankDisplay/RankInfo/RankName
	tier_label = $MainLayout/RightSection/TopBar/HBoxContainer/RankDisplay/RankInfo/TierRow/TierLabel
	rank_points_label = $MainLayout/RightSection/TopBar/HBoxContainer/RankDisplay/RankInfo/TierRow/RankPoints

	# Currencies
	credits_label = $MainLayout/RightSection/TopBar/HBoxContainer/Currencies/Credits/CreditsLabel
	gems_label = $MainLayout/RightSection/TopBar/HBoxContainer/Currencies/Gems/GemsLabel
	gold_label = $MainLayout/RightSection/TopBar/HBoxContainer/Currencies/Gold/GoldLabel

	# Connect top bar buttons
	var friends_btn = $MainLayout/RightSection/TopBar/HBoxContainer/FriendsButton
	friends_btn.pressed.connect(_show_coming_soon)

	var collection_btn = $MainLayout/RightSection/TopBar/HBoxContainer/CollectionButton
	collection_btn.pressed.connect(_show_coming_soon)

	var settings_btn = $MainLayout/RightSection/TopBar/HBoxContainer/SettingsButton
	settings_btn.pressed.connect(_on_settings_pressed)


func _setup_navigation() -> void:
	# Navigation items: id, display text, enabled status
	var nav_items = [
		{"id": "battle", "text": "BATTLE", "enabled": true},
		{"id": "rewards", "text": "REWARDS", "enabled": false},
		{"id": "deck", "text": "DECK", "enabled": true},
		{"id": "shop", "text": "SHOP", "enabled": false},
		{"id": "trade", "text": "TRADE", "enabled": false},
		{"id": "guild", "text": "GUILD", "enabled": false},
	]

	for item in nav_items:
		var button = $MainLayout/LeftSidebar.get_node("Nav_" + item.id.capitalize())
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
	match nav_id:
		"battle":
			_update_nav_highlight("battle")
		"deck":
			_show_coming_soon()  # Deck builder not yet integrated with 3D
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
