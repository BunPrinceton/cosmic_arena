extends Camera3D
## Camera follow script for Force Arena-style isometric view

@export var target: Node3D
@export var follow_distance: float = 12.0
@export var camera_height: float = 8.0
@export var camera_angle: float = 50.0  # Degrees from horizontal
@export var follow_smoothness: float = 8.0

# Debug camera settings (zoomed out for debugging):
# follow_distance = 25.0, camera_height = 15.0

var _offset: Vector3

func _ready() -> void:
	# Find player if target not set
	if not target:
		target = get_node_or_null("../Player")
		if not target:
			print("Camera: Searching for player...")
			await get_tree().process_frame
			target = get_node_or_null("../Player")

	if not target:
		print("Camera FATAL: Cannot find player!")
		return

	print("Camera: Found target - ", target.name)

	# Isometric diagonal camera - rotated 45 degrees
	# Player appears at bottom-right, enemy at top-left

	var angle_rad = deg_to_rad(camera_angle)
	var horizontal_distance = follow_distance * cos(angle_rad)
	var vertical_distance = follow_distance * sin(angle_rad) + camera_height

	# Position camera at 45-degree diagonal (southeast of player)
	# Camera at positive X and positive Z, looking northwest toward enemy
	var diagonal_rad = deg_to_rad(45.0)
	var offset_x = horizontal_distance * sin(diagonal_rad)  # Positive X (east side)
	var offset_z = horizontal_distance * cos(diagonal_rad)  # Positive Z (south side)

	_offset = Vector3(offset_x, vertical_distance, offset_z)

	# Point camera down at angle AND rotate to face northwest
	rotation_degrees.x = -camera_angle
	rotation_degrees.y = -122.0  # Look northwest (toward enemy), yawed left

	# Immediately position camera at target on startup
	if target:
		global_position = target.global_position + _offset
		print("Camera positioned at: ", global_position)

func _physics_process(delta: float) -> void:
	if not target:
		return

	# Locked follow - camera stays at fixed offset from player
	global_position = target.global_position + _offset

	# Always look at the player to keep them centered in screen
	look_at(target.global_position, Vector3.UP)
