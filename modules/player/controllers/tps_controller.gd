class_name TPSController
extends CharacterBody3D

## -----------------------------------------------------------------------------
## Named Physics Constants
## -----------------------------------------------------------------------------
const MIN_VELOCITY_THRESHOLD_MPS: float = 0.05
const ZERO_VELOCITY: Vector3 = Vector3.ZERO
const Y_UP_VECTOR: Vector3 = Vector3(0.0, 1.0, 0.0)

## -----------------------------------------------------------------------------
## Child Nodes
## -----------------------------------------------------------------------------
var camera_rig: TPSCameraRig = null
var raycaster: VoxelRaycaster = null

func _ready() -> void:
	camera_rig = $CameraRig as TPSCameraRig
	raycaster = $VoxelRaycaster as VoxelRaycaster
	if raycaster != null and camera_rig != null:
		raycaster.camera_rig = camera_rig

	if EventBus != null:
		EventBus.player_position_updated.emit(global_position)

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_jump()
	_handle_movement(delta)
	move_and_slide()

	if EventBus != null:
		EventBus.player_position_updated.emit(global_position)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= Constants.PLAYER_GRAVITY_METERS_PER_SEC_SQ * delta

func _handle_jump() -> void:
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = Constants.PLAYER_JUMP_VELOCITY_METERS_PER_SEC

func _handle_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var target_speed: float = Constants.PLAYER_WALK_SPEED_METERS_PER_SEC
	if Input.is_action_pressed("sprint") and is_on_floor():
		target_speed = Constants.PLAYER_SPRINT_SPEED_METERS_PER_SEC

	var accel_factor: float = 1.0 if is_on_floor() else Constants.PLAYER_AIR_CONTROL_FACTOR
	var target_velocity_x: float = move_direction.x * target_speed
	var target_velocity_z: float = move_direction.z * target_speed

	if move_direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, target_velocity_x, Constants.PLAYER_ACCELERATION_METERS_PER_SEC_SQ * accel_factor * delta)
		velocity.z = move_toward(velocity.z, target_velocity_z, Constants.PLAYER_ACCELERATION_METERS_PER_SEC_SQ * accel_factor * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, Constants.PLAYER_FRICTION_METERS_PER_SEC_SQ * accel_factor * delta)
		velocity.z = move_toward(velocity.z, 0.0, Constants.PLAYER_FRICTION_METERS_PER_SEC_SQ * accel_factor * delta)
