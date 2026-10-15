class_name DebugOverlayUI
extends Control

## -----------------------------------------------------------------------------
## Named Configuration Constants
## -----------------------------------------------------------------------------
const UPDATE_INTERVAL_SECONDS: float = 0.1
const DEFAULT_TEXT_COLOR: Color = Color(0.9, 0.9, 0.9, 1.0)
const BG_PANEL_COLOR: Color = Color(0.08, 0.08, 0.1, 0.75)

## -----------------------------------------------------------------------------
## State Variables
## -----------------------------------------------------------------------------
var time_since_last_update: float = 0.0
var last_player_world_pos: Vector3 = Vector3.ZERO
var label_telemetry: Label = null

func _ready() -> void:
	label_telemetry = $MarginContainer/PanelContainer/TelemetryLabel as Label

	if EventBus != null:
		EventBus.player_position_updated.connect(_on_player_position_updated)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		visible = not visible
		if EventBus != null:
			EventBus.debug_overlay_toggled.emit(visible)

func _process(delta: float) -> void:
	if not visible:
		return

	time_since_last_update += delta
	if time_since_last_update < UPDATE_INTERVAL_SECONDS:
		return

	time_since_last_update = 0.0
	_refresh_telemetry_display()

func _refresh_telemetry_display() -> void:
	if label_telemetry == null:
		return

	var fps: int = int(Engine.get_frames_per_second())
	var player_voxel: Vector3i = VoxelCoordinates.world_pos_to_voxel_coord(last_player_world_pos)
	var player_chunk: Vector3i = VoxelCoordinates.voxel_coord_to_chunk_coord(player_voxel)

	var text_lines: Array[String] = [
		"=== VOXEL SANDBOX DEBUG ===",
		"FPS: %d" % fps,
		"Player Pos: (%.1f, %.1f, %.1f)" % [last_player_world_pos.x, last_player_world_pos.y, last_player_world_pos.z],
		"Voxel Coord: (%d, %d, %d)" % [player_voxel.x, player_voxel.y, player_voxel.z],
		"Chunk Coord: (%d, %d, %d)" % [player_chunk.x, player_chunk.y, player_chunk.z],
		"Chunk Volume: %d voxels" % Constants.CHUNK_VOXEL_VOLUME,
		"Controls: WASD=Move, Space=Jump, Shift=Sprint, LMB=Mine, RMB=Place, F3=Debug, Esc=Cursor"
	]

	label_telemetry.text = "\n".join(text_lines)

func _on_player_position_updated(new_pos: Vector3) -> void:
	last_player_world_pos = new_pos
