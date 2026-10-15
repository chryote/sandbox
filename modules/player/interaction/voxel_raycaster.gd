class_name VoxelRaycaster
extends Node3D

## -----------------------------------------------------------------------------
## Named Constants
## -----------------------------------------------------------------------------
const SCREEN_CENTER_NORMALIZED: Vector2 = Vector2(0.5, 0.5)
const NO_COLLISION_RESULT: Dictionary = {}

## -----------------------------------------------------------------------------
## Dependencies & State
## -----------------------------------------------------------------------------
@export var camera_rig: Node3D = null
var active_placement_block_id: int = Constants.BLOCK_ID_STONE
var current_targeted_voxel: Vector3i = Vector3i.ZERO
var current_adjacent_voxel: Vector3i = Vector3i.ZERO
var has_target: bool = false

func _ready() -> void:
	if EventBus != null:
		EventBus.selected_block_changed.connect(_on_selected_block_changed)

func _physics_process(_delta: float) -> void:
	_perform_crosshair_raycast()

func _unhandled_input(event: InputEvent) -> void:
	if not has_target:
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if event.is_action_pressed("mine_block"):
		_request_mine_block()
	elif event.is_action_pressed("place_block"):
		_request_place_block()

func _perform_crosshair_raycast() -> void:
	if camera_rig == null:
		has_target = false
		return

	var camera: Camera3D = null
	if camera_rig.has_method("get_camera"):
		camera = camera_rig.call("get_camera")

	if camera == null:
		has_target = false
		return

	var viewport: Viewport = get_viewport()
	var screen_center_pixels: Vector2 = viewport.get_visible_rect().size * SCREEN_CENTER_NORMALIZED

	var ray_origin: Vector3 = camera.project_ray_origin(screen_center_pixels)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_center_pixels)
	var ray_endpoint: Vector3 = ray_origin + (ray_direction * Constants.INTERACTION_MAX_DISTANCE_METERS)

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_endpoint)

	var hit_result: Dictionary = space_state.intersect_ray(query)

	if hit_result.is_empty():
		has_target = false
		return

	has_target = true
	var hit_position: Vector3 = hit_result["position"]
	var hit_normal: Vector3 = hit_result["normal"]

	current_targeted_voxel = VoxelCoordinates.resolve_mined_voxel_coord(hit_position, hit_normal)
	current_adjacent_voxel = VoxelCoordinates.resolve_placed_voxel_coord(hit_position, hit_normal)

func _request_mine_block() -> void:
	if EventBus != null:
		EventBus.block_modify_requested.emit(current_targeted_voxel, Constants.BLOCK_ID_AIR)
		Logger.info("Emitted mine block request for: " + str(current_targeted_voxel), "Player")

func _request_place_block() -> void:
	if EventBus != null:
		EventBus.block_modify_requested.emit(current_adjacent_voxel, active_placement_block_id)
		Logger.info("Emitted place block request for: " + str(current_adjacent_voxel), "Player")

func _on_selected_block_changed(block_id: int) -> void:
	active_placement_block_id = block_id
