extends SubViewport

## 3D character display for main menu
## Renders selected commander model with idle animation

const HUMAN_FEMALE_MODEL = preload("res://assets/models/humanoid/human-female.glb")

@onready var character_slot: Node3D = $CharacterSlot
@onready var camera: Camera3D = $Camera3D

var current_character: Node3D = null
var anim_player: AnimationPlayer = null


func _ready() -> void:
	# Load default character on startup
	call_deferred("_load_default_character")


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
