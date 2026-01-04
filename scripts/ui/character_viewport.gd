extends SubViewport

## 3D character display for main menu
## Renders selected commander model with idle animation
## Uses pivot-based camera system to avoid mesh clipping during zoom

const HUMAN_FEMALE_MODEL = preload("res://assets/models/humanoid/human-female.glb")

# Pivot positions for different views (camera stays fixed relative to pivot)
const PIVOT_BATTLE_POS = Vector3(0, 0.5, 0)   # Full body view - pivot lower
const PIVOT_DECK_POS = Vector3(0, 1.0, 0)     # Upper body view - pivot at chest height
const ZOOM_DURATION = 0.4

# Fixed camera offset from pivot (never changes)
const CAMERA_LOCAL_POS = Vector3(0, 0.5, 3.0)  # Further back, slightly higher
const CAMERA_FOV = 45.0  # Wider FOV to see more

# Target point on character that camera looks at (chest/torso area)
const LOOK_TARGET_BATTLE = Vector3(0, 0.3, 0)  # Look at waist for full body
const LOOK_TARGET_DECK = Vector3(0, 0.8, 0)    # Look at chest for upper body

@onready var character_slot: Node3D = $CharacterSlot

var camera: Camera3D = null
var camera_pivot: Node3D = null
var current_character: Node3D = null
var anim_player: AnimationPlayer = null
var is_zoomed_in: bool = false
var is_zoom_tweening: bool = false  # Track when we're animating zoom


func _ready() -> void:
	# Setup pivot-based camera system
	_setup_camera_pivot()
	_update_camera_look()  # Initial aim at pivot
	# Load default character on startup
	call_deferred("_load_default_character")


func _process(_delta: float) -> void:
	# Continuously update camera aim while tweening
	if is_zoom_tweening:
		_update_camera_look()


## Make camera look at the pivot target (critical for proper framing)
func _update_camera_look() -> void:
	if camera and camera_pivot:
		# Camera looks at the pivot position (where the character is framed)
		camera.look_at(camera_pivot.global_position, Vector3.UP)


## Create camera pivot system for clean menu zooms without clipping
func _setup_camera_pivot() -> void:
	# Get existing camera
	var old_camera = get_node_or_null("Camera3D")

	# Create pivot node
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = PIVOT_BATTLE_POS
	add_child(camera_pivot)

	# Create new camera as child of pivot (or reparent existing)
	if old_camera:
		old_camera.reparent(camera_pivot)
		camera = old_camera
	else:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		camera_pivot.add_child(camera)

	# Set fixed camera properties (these never change during zoom)
	camera.position = CAMERA_LOCAL_POS
	camera.fov = CAMERA_FOV
	camera.near = 0.01
	camera.far = 10.0


func _load_default_character() -> void:
	var instance = HUMAN_FEMALE_MODEL.instantiate()
	_set_character_instance(instance)


func _set_character_instance(instance: Node3D) -> void:
	# Remove existing character
	if current_character:
		current_character.queue_free()

	current_character = instance
	character_slot.add_child(instance)

	# Scale and position for portrait view
	# Find the armature and scale it
	var armature = instance.get_node_or_null("CharacterArmature")
	if armature:
		armature.scale = Vector3(1.8, 1.8, 1.8)
		armature.position = Vector3(0, -1.5, 0)

	# Find animation player
	anim_player = _find_animation_player(instance)

	# Play idle animation
	_play_idle_animation()


func _find_animation_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var result = _find_animation_player(child)
		if result:
			return result
	return null


func _play_idle_animation() -> void:
	if not anim_player:
		return

	var anim_list = anim_player.get_animation_list()
	# Try idle animations in order of preference
	for anim_name in ["idle-unarmed", "idle-2h", "idle-1h", "Idle", "idle"]:
		if anim_name in anim_list:
			# Set animation to loop for breathing effect
			var anim = anim_player.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			anim_player.play(anim_name)
			return


## Called when commander selection changes
func set_commander(commander_data) -> void:
	# For now, all commanders use the same model
	# Apply commander's visual color as a tint
	if current_character and commander_data:
		_apply_commander_color(commander_data.visual_color)


func _apply_commander_color(color: Color) -> void:
	# Tint the character mesh with commander color
	# This is subtle - mainly affects outfit/armor areas
	pass  # Skip tinting for now to keep natural model appearance


## Zoom in for deck view by moving pivot up (shows upper body)
func zoom_in_for_deck() -> void:
	if is_zoomed_in:
		return
	is_zoomed_in = true
	is_zoom_tweening = true

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(camera_pivot, "position", PIVOT_DECK_POS, ZOOM_DURATION)
	tween.tween_callback(func():
		is_zoom_tweening = false
		_update_camera_look()
	)


## Zoom out for battle view by moving pivot down (shows full body)
func zoom_out_for_battle() -> void:
	if not is_zoomed_in:
		return
	is_zoomed_in = false
	is_zoom_tweening = true

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(camera_pivot, "position", PIVOT_BATTLE_POS, ZOOM_DURATION)
	tween.tween_callback(func():
		is_zoom_tweening = false
		_update_camera_look()
	)


## Set zoom directly (for immediate changes without animation)
func set_zoom(zoomed_in: bool) -> void:
	is_zoomed_in = zoomed_in
	if camera_pivot:
		camera_pivot.position = PIVOT_DECK_POS if zoomed_in else PIVOT_BATTLE_POS
		_update_camera_look()
