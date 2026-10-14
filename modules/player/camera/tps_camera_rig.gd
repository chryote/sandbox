class_name TPSCameraRig
extends Node3D

## -----------------------------------------------------------------------------
## Named Configuration Constants
## -----------------------------------------------------------------------------
const CAMERA_FOV_DEGREES: float = 75.0
const CAMERA_CLIP_MARGIN_METERS: float = 0.2
const ROTATION_DEGREES_TO_RADIANS: float = PI / 180.0

## -----------------------------------------------------------------------------
## Nodes
## -----------------------------------------------------------------------------
var spring_arm: SpringArm3D = null
var camera: Camera3D = null

## -----------------------------------------------------------------------------
## State Variables
## -----------------------------------------------------------------------------
var current_pitch_degrees: float = 0.0

func _ready() -> void:
	_setup_camera_nodes()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _setup_camera_nodes() -> void:
	if spring_arm == null:
		spring_arm = SpringArm3D.new()
		spring_arm.name = "SpringArm"
		spring_arm.spring_length = Constants.CAMERA_SPRING_ARM_LENGTH_METERS
		spring_arm.margin = CAMERA_CLIP_MARGIN_METERS
		spring_arm.position = Constants.CAMERA_SHOULDER_OFFSET_METERS
		add_child(spring_arm)

	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		camera.fov = CAMERA_FOV_DEGREES
		spring_arm.add_child(camera)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.physical_keycode == KEY_ESCAPE:
			_toggle_mouse_mode()

	if event is InputEventMouseButton and event.is_pressed():
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_process_mouse_rotation(event.relative)

func _toggle_mouse_mode() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process_mouse_rotation(relative_mouse_delta: Vector2) -> void:
	# Horizontal Yaw rotation (rotates parent character node)
	var yaw_delta_rad: float = -relative_mouse_delta.x * Constants.CAMERA_MOUSE_SENSITIVITY
	var parent_node: Node3D = get_parent() as Node3D
	if parent_node != null:
		parent_node.rotate_y(yaw_delta_rad)

	# Vertical Pitch rotation (rotates SpringArm)
	var pitch_delta_deg: float = -relative_mouse_delta.y * Constants.CAMERA_MOUSE_SENSITIVITY / ROTATION_DEGREES_TO_RADIANS
	current_pitch_degrees = clampf(
		current_pitch_degrees + pitch_delta_deg,
		Constants.CAMERA_PITCH_MIN_DEGREES,
		Constants.CAMERA_PITCH_MAX_DEGREES
	)
	spring_arm.rotation.x = current_pitch_degrees * ROTATION_DEGREES_TO_RADIANS

## Returns the active Camera3D.
func get_camera() -> Camera3D:
	return camera
