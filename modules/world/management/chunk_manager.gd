class_name ChunkManager
extends Node3D

const LODHeightmapMesherScript = preload("res://modules/world/chunk/lod_heightmap_mesher.gd")
const LODChunkViewScript = preload("res://modules/world/chunk/lod_chunk_view.gd")

## -----------------------------------------------------------------------------
## Configuration & Dependencies
## -----------------------------------------------------------------------------
@export var config: WorldGenConfig = null
var registry: BlockRegistry = null
var generator: TerrainGenerator = null

## -----------------------------------------------------------------------------
## Internal Storage & Concurrency
## -----------------------------------------------------------------------------
var _chunk_data_map: Dictionary = {}   # Vector3i -> ChunkData
var _chunk_view_map: Dictionary = {}   # Vector3i -> ChunkView
var _last_player_chunk: Vector3i = Vector3i(999999, 999999, 999999)

## Worker thread queue & synchronization
var _data_mutex: Mutex = Mutex.new()
var _queue_mutex: Mutex = Mutex.new()
var _results_mutex: Mutex = Mutex.new()

var _surface_queue: Array[Vector3i] = []            # High-priority: surface shell generation & meshing
var _subsurface_queue: Array[Vector3i] = []         # Low-priority / deferred: subterranean fill
var _lod_queue: Array[Vector2i] = []                # Low-priority: distant 2D heightmap LOD generation
var _pending_surface_coords: Dictionary = {}        # Vector3i -> bool
var _pending_subsurface_coords: Dictionary = {}     # Vector3i -> bool
var _pending_lod_coords: Dictionary = {}            # Vector2i -> bool
var _completed_queue: Array[Dictionary] = []        # Completed tasks payload

var _lod_view_map: Dictionary = {}                  # Vector2i -> LODChunkView
var _is_player_underground: bool = false

var _is_worker_running: bool = false
var _stop_worker: bool = false
var _current_task_id: int = -1

## Main-thread budget: max completed chunk meshes to attach per frame to maintain steady 60+ FPS
const MAX_CHUNKS_APPLIED_PER_FRAME: int = 2

func _ready() -> void:
	if config == null:
		config = WorldGenConfig.new()

	registry = BlockRegistry.new()
	generator = TerrainGenerator.new(config)

	# Connect to decoupled EventBus modification requests
	if EventBus != null:
		EventBus.block_modify_requested.connect(_on_block_modify_requested)
		EventBus.player_position_updated.connect(_on_player_position_updated)
		Logger.info("ChunkManager initialized with background WorkerThreadPool pipeline.", "WorldGen")

	# Initial world generation:
	# Synchronously generate immediate spawn radius (radius 2 = 25 chunks) so player spawns on solid ground
	var initial_sync_radius: int = mini(2, config.load_radius_chunks)
	load_chunks_around_coord(Vector3i.ZERO, initial_sync_radius, true)
	_last_player_chunk = Vector3i.ZERO

	# Asynchronously dispatch remaining outer radius chunks to the background worker pipeline
	if config.load_radius_chunks > initial_sync_radius:
		load_chunks_around_coord(Vector3i.ZERO, config.load_radius_chunks, false)

	# Asynchronously dispatch distant 2D heightmap LOD shells (Phase 4)
	if config.enable_lod:
		update_lod_around_col(Vector2i.ZERO, false)

func _process(_delta: float) -> void:
	_check_worker_status()
	_apply_completed_chunk_meshes()

func cleanup() -> void:
	_queue_mutex.lock()
	_stop_worker = true
	var task_id: int = _current_task_id
	_queue_mutex.unlock()

	if task_id != -1:
		WorkerThreadPool.wait_for_task_completion(task_id)
		_queue_mutex.lock()
		_current_task_id = -1
		_is_worker_running = false
		_queue_mutex.unlock()

func _exit_tree() -> void:
	cleanup()

## -----------------------------------------------------------------------------
## Threaded Chunk Loading Pipeline
## -----------------------------------------------------------------------------
## Enqueues or immediately loads chunks in a square radius around a central chunk coordinate.
func load_chunks_around_coord(center_coord: Vector3i, radius_chunks: int, is_synchronous: bool = false) -> void:
	var needed_coords: Array[Vector3i] = []

	for offset_z: int in range(-radius_chunks, radius_chunks + 1):
		for offset_x: int in range(-radius_chunks, radius_chunks + 1):
			for chunk_y: int in range(config.min_chunk_y, config.max_chunk_y + 1):
				var target_coord: Vector3i = Vector3i(
					center_coord.x + offset_x,
					chunk_y,
					center_coord.z + offset_z
				)

				_data_mutex.lock()
				var already_has_data: bool = _chunk_data_map.has(target_coord)
				_data_mutex.unlock()

				_queue_mutex.lock()
				var already_pending: bool = _pending_surface_coords.has(target_coord)
				_queue_mutex.unlock()

				if not already_has_data and not already_pending:
					needed_coords.append(target_coord)

	if needed_coords.is_empty():
		return

	# Sort requested coords closest to center so immediate surroundings load first
	needed_coords.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return (a - center_coord).length_squared() < (b - center_coord).length_squared()
	)

	if is_synchronous:
		for coord: Vector3i in needed_coords:
			_generate_chunk_data_only(coord)
		for coord: Vector3i in needed_coords:
			_create_and_mesh_chunk_view(coord)
	else:
		_queue_mutex.lock()
		for coord: Vector3i in needed_coords:
			_pending_surface_coords[coord] = true
			_surface_queue.append(coord)

		# Re-sort surface queue by distance to player center so closest chunks render first
		_surface_queue.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			return (a - center_coord).length_squared() < (b - center_coord).length_squared()
		)

		if not _is_worker_running and (!_surface_queue.is_empty() or !_subsurface_queue.is_empty() or !_lod_queue.is_empty()):
			_is_worker_running = true
			_current_task_id = WorkerThreadPool.add_task(Callable(self, "_background_worker_loop"))
		_queue_mutex.unlock()

## Background worker thread loop: continuously processes queued chunks off the main thread.
## Always prioritizes visible surface chunks (Phase A) before deferred subsurface generation (Phase B),
## and processes distant 2D heightmap LOD shells as background filler.
func _background_worker_loop() -> void:
	while true:
		_queue_mutex.lock()
		if _stop_worker:
			_is_worker_running = false
			_queue_mutex.unlock()
			break

		var coord: Vector3i = Vector3i.ZERO
		var lod_col: Vector2i = Vector2i.ZERO
		var task_type: int = 0 # 1=surface, 2=subsurface, 3=lod

		if not _surface_queue.is_empty():
			coord = _surface_queue.pop_front()
			task_type = 1
		elif not _subsurface_queue.is_empty():
			coord = _subsurface_queue.pop_front()
			task_type = 2
		elif not _lod_queue.is_empty():
			lod_col = _lod_queue.pop_front()
			task_type = 3
		else:
			_is_worker_running = false
			_queue_mutex.unlock()
			break
		_queue_mutex.unlock()

		match task_type:
			1:
				_thread_generate_surface_and_mesh(coord)
			2:
				_thread_fill_subsurface(coord)
			3:
				_thread_generate_lod(lod_col)

## Phase A: Generates surface shell and builds ArrayMesh and ConcavePolygonShape3D completely off-thread.
func _thread_generate_surface_and_mesh(coord: Vector3i) -> void:
	var data: ChunkData = ChunkData.new(coord)
	generator.generate_surface_shell(data)

	_data_mutex.lock()
	_chunk_data_map[coord] = data
	_data_mutex.unlock()

	var mesh_and_shape: Dictionary = ChunkMesher.build_chunk_mesh_and_shape(
		data,
		registry,
		Callable(self, "get_block")
	)

	_results_mutex.lock()
	_completed_queue.append({
		"coord": coord,
		"mesh": mesh_and_shape["mesh"],
		"shape": mesh_and_shape["shape"]
	})
	_results_mutex.unlock()

	# Enqueue for background subsurface completion (Phase B) only if not already fully generated
	if data.is_surface_only():
		_queue_mutex.lock()
		if not _pending_subsurface_coords.has(coord) and not _stop_worker:
			_pending_subsurface_coords[coord] = true
			_subsurface_queue.append(coord)
		_queue_mutex.unlock()

## Phase B: Fills subterranean layers beneath the surface foundation in the background.
func _thread_fill_subsurface(coord: Vector3i) -> void:
	_data_mutex.lock()
	var data: ChunkData = _chunk_data_map.get(coord, null)
	_data_mutex.unlock()

	if data != null and data.is_surface_only():
		generator.fill_subsurface(data)

	_queue_mutex.lock()
	_pending_subsurface_coords.erase(coord)
	_queue_mutex.unlock()

## Generates lightweight 2D quad mesh for distant chunk columns completely off-thread.
func _thread_generate_lod(col: Vector2i) -> void:
	var lod_mesh: ArrayMesh = LODHeightmapMesherScript.build_column_lod_mesh(
		col,
		generator,
		config.primary_biome,
		registry
	)
	_results_mutex.lock()
	_completed_queue.append({
		"type": "lod",
		"col": col,
		"mesh": lod_mesh
	})
	_results_mutex.unlock()

## Checks if the worker task has completed and cleans up its handle
func _check_worker_status() -> void:
	_queue_mutex.lock()
	if not _is_worker_running and _current_task_id != -1:
		if WorkerThreadPool.is_task_completed(_current_task_id):
			WorkerThreadPool.wait_for_task_completion(_current_task_id)
			_current_task_id = -1

			# If new tasks arrived while finishing, restart the worker loop
			if (!_surface_queue.is_empty() or !_subsurface_queue.is_empty() or !_lod_queue.is_empty()) and not _stop_worker:
				_is_worker_running = true
				_current_task_id = WorkerThreadPool.add_task(Callable(self, "_background_worker_loop"))
	_queue_mutex.unlock()

## Applies a budgeted number of completed chunk meshes to the SceneTree per frame
func _apply_completed_chunk_meshes() -> void:
	_results_mutex.lock()
	if _completed_queue.is_empty():
		_results_mutex.unlock()
		return

	var chunks_to_apply: Array[Dictionary] = []
	var count_to_pop: int = mini(MAX_CHUNKS_APPLIED_PER_FRAME, _completed_queue.size())
	for i: int in range(count_to_pop):
		chunks_to_apply.append(_completed_queue.pop_front())
	_results_mutex.unlock()

	for item: Dictionary in chunks_to_apply:
		if item.get("type", "") == "lod":
			var col: Vector2i = item["col"]
			var mesh: ArrayMesh = item.get("mesh", null)
			_apply_lod_view(col, mesh)
		else:
			var coord: Vector3i = item["coord"]
			var mesh: ArrayMesh = item.get("mesh", null)
			var shape: Shape3D = item.get("shape", null)

			_queue_mutex.lock()
			_pending_surface_coords.erase(coord)
			_queue_mutex.unlock()

			_apply_chunk_view(coord, mesh, shape)

## Attaches or updates a ChunkView node with its mesh and physics collider.
## Skips allocating ChunkView instances for empty/homogeneous chunks that produce no geometry.
func _apply_chunk_view(coord: Vector3i, mesh: ArrayMesh, shape: Shape3D = null) -> void:
	if mesh == null:
		if _chunk_view_map.has(coord):
			var old_view: ChunkView = _chunk_view_map[coord]
			_chunk_view_map.erase(coord)
			old_view.queue_free()
		if EventBus != null:
			EventBus.chunk_loaded.emit(coord)
		return

	var view: ChunkView = null
	if _chunk_view_map.has(coord):
		view = _chunk_view_map[coord]
	else:
		view = ChunkView.new(coord)
		add_child(view)
		_chunk_view_map[coord] = view

	view.update_mesh_and_collision(mesh, shape)

	# Subterranean cave occlusion: hide underground chunks while player is on surface
	_data_mutex.lock()
	var chunk_data: ChunkData = _chunk_data_map.get(coord, null)
	_data_mutex.unlock()
	if chunk_data != null:
		view.is_subterranean = chunk_data.is_subterranean
		if view.is_subterranean and not _is_player_underground and config.enable_cave_occlusion:
			view.set_occluded(true)
		else:
			view.set_occluded(false)

	# If a full 3D chunk view is active in this column, remove any distant 2D LOD shell
	var col: Vector2i = Vector2i(coord.x, coord.z)
	if _lod_view_map.has(col):
		_remove_lod_view(col)

	if EventBus != null:
		EventBus.chunk_loaded.emit(coord)

## Generates voxel data for a single chunk coordinate synchronously.
func _generate_chunk_data_only(coord: Vector3i) -> ChunkData:
	var data: ChunkData = ChunkData.new(coord)
	generator.generate_chunk_data(data)
	_data_mutex.lock()
	_chunk_data_map[coord] = data
	_data_mutex.unlock()
	return data

## Meshes a chunk synchronously on the main thread (used for startup and player block edits).
func _create_and_mesh_chunk_view(coord: Vector3i) -> void:
	_data_mutex.lock()
	var has_data: bool = _chunk_data_map.has(coord)
	var data: ChunkData = _chunk_data_map.get(coord, null)
	_data_mutex.unlock()

	if not has_data or data == null:
		return

	if data.is_homogeneous_solid():
		data._promote_to_buffer()

	var mesh_and_shape: Dictionary = ChunkMesher.build_chunk_mesh_and_shape(
		data,
		registry,
		Callable(self, "get_block")
	)
	_apply_chunk_view(coord, mesh_and_shape["mesh"], mesh_and_shape["shape"])

## Unloads and frees a chunk at the specified coordinate.
func unload_chunk(coord: Vector3i) -> void:
	_queue_mutex.lock()
	_pending_surface_coords.erase(coord)
	_surface_queue.erase(coord)
	_pending_subsurface_coords.erase(coord)
	_subsurface_queue.erase(coord)
	_queue_mutex.unlock()

	if _chunk_view_map.has(coord):
		var view: ChunkView = _chunk_view_map[coord]
		view.queue_free()
		_chunk_view_map.erase(coord)

	_data_mutex.lock()
	if _chunk_data_map.has(coord):
		_chunk_data_map.erase(coord)
	_data_mutex.unlock()

	if EventBus != null:
		EventBus.chunk_unloaded.emit(coord)

## -----------------------------------------------------------------------------
## Voxel Query & Modification
## -----------------------------------------------------------------------------
## Returns the block ID at the specified world voxel coordinate. Thread-safe.
func get_block(world_voxel: Vector3i) -> int:
	var chunk_coord: Vector3i = VoxelCoordinates.voxel_coord_to_chunk_coord(world_voxel)
	_data_mutex.lock()
	var chunk_data: ChunkData = _chunk_data_map.get(chunk_coord, null)
	_data_mutex.unlock()

	if chunk_data == null:
		return Constants.BLOCK_ID_AIR

	var local_coord: Vector3i = VoxelCoordinates.voxel_coord_to_local_coord(world_voxel)
	return chunk_data.get_block(local_coord)

## Modifies a block at the specified world voxel coordinate and updates meshes.
func set_block(world_voxel: Vector3i, new_block_id: int) -> void:
	var chunk_coord: Vector3i = VoxelCoordinates.voxel_coord_to_chunk_coord(world_voxel)
	_data_mutex.lock()
	var has_chunk: bool = _chunk_data_map.has(chunk_coord)
	var target_data: ChunkData = _chunk_data_map.get(chunk_coord, null)
	_data_mutex.unlock()

	if not has_chunk or target_data == null:
		return

	# If the chunk only has surface shell generated, fill subsurface on-demand so player never breaks into a void
	if target_data.is_surface_only():
		generator.fill_subsurface(target_data)
		_queue_mutex.lock()
		_pending_subsurface_coords.erase(chunk_coord)
		_subsurface_queue.erase(chunk_coord)
		_queue_mutex.unlock()

	var local_coord: Vector3i = VoxelCoordinates.voxel_coord_to_local_coord(world_voxel)
	var old_id: int = target_data.get_block(local_coord)

	if old_id == new_block_id:
		return

	target_data.set_block(local_coord, new_block_id)
	_create_and_mesh_chunk_view(chunk_coord)

	# If the modified block lies on a chunk boundary, remesh adjacent neighbor chunks
	_remesh_neighbors_if_boundary(chunk_coord, local_coord)

	if EventBus != null:
		EventBus.block_modified.emit(world_voxel, new_block_id)

## Returns true if the voxel at world_voxel is transparent or resides in an unloaded chunk.
func is_voxel_transparent(world_voxel: Vector3i) -> bool:
	var chunk_coord: Vector3i = VoxelCoordinates.voxel_coord_to_chunk_coord(world_voxel)
	_data_mutex.lock()
	var chunk_data: ChunkData = _chunk_data_map.get(chunk_coord, null)
	_data_mutex.unlock()

	if chunk_data == null:
		return true

	var local_coord: Vector3i = VoxelCoordinates.voxel_coord_to_local_coord(world_voxel)
	var block_id: int = chunk_data.get_block(local_coord)
	return registry.is_transparent(block_id)

func _remesh_neighbors_if_boundary(chunk_coord: Vector3i, local_coord: Vector3i) -> void:
	# West boundary (-X)
	if local_coord.x == 0:
		_create_and_mesh_chunk_view(chunk_coord + Vector3i(-1, 0, 0))
	# East boundary (+X)
	elif local_coord.x == Constants.CHUNK_WIDTH_VOXELS - 1:
		_create_and_mesh_chunk_view(chunk_coord + Vector3i(1, 0, 0))

	# Bottom boundary (-Y)
	if local_coord.y == 0:
		_create_and_mesh_chunk_view(chunk_coord + Vector3i(0, -1, 0))
	# Top boundary (+Y)
	elif local_coord.y == Constants.CHUNK_HEIGHT_VOXELS - 1:
		_create_and_mesh_chunk_view(chunk_coord + Vector3i(0, 1, 0))

	# North boundary (-Z)
	if local_coord.z == 0:
		_create_and_mesh_chunk_view(chunk_coord + Vector3i(0, 0, -1))
	# South boundary (+Z)
	elif local_coord.z == Constants.CHUNK_DEPTH_VOXELS - 1:
		_create_and_mesh_chunk_view(chunk_coord + Vector3i(0, 0, 1))

## EventBus receiver for decoupled block modification requests
func _on_block_modify_requested(world_voxel_pos: Vector3i, new_block_id: int) -> void:
	set_block(world_voxel_pos, new_block_id)

## Attaches or updates a distant 2D LOD heightmap chunk view
func _apply_lod_view(col: Vector2i, mesh: ArrayMesh) -> void:
	_queue_mutex.lock()
	_pending_lod_coords.erase(col)
	_queue_mutex.unlock()

	if mesh == null:
		return

	# If 3D chunk views already exist for this column, do not display LOD shell
	for y: int in range(config.min_chunk_y, config.max_chunk_y + 1):
		if _chunk_view_map.has(Vector3i(col.x, y, col.y)):
			return

	var lod_view = null
	if _lod_view_map.has(col):
		lod_view = _lod_view_map[col]
	else:
		lod_view = LODChunkViewScript.new(col)
		add_child(lod_view)
		_lod_view_map[col] = lod_view

	lod_view.set_mesh(mesh)

## Removes and frees an LOD chunk view
func _remove_lod_view(col: Vector2i) -> void:
	if _lod_view_map.has(col):
		var old_view = _lod_view_map[col]
		_lod_view_map.erase(col)
		old_view.queue_free()

## Enqueues or builds distant 2D heightmap LOD shells between load_radius and lod_radius
func update_lod_around_col(center_col: Vector2i, is_synchronous: bool = false) -> void:
	if not config.enable_lod:
		return

	var load_r: int = config.load_radius_chunks
	var lod_r: int = config.lod_radius_chunks
	var load_r_sq: int = load_r * load_r
	var lod_r_sq: int = lod_r * lod_r

	var needed_cols: Array[Vector2i] = []

	for dz: int in range(-lod_r, lod_r + 1):
		for dx: int in range(-lod_r, lod_r + 1):
			var dist_sq: int = dx * dx + dz * dz
			# Only columns strictly outside load_radius and within lod_radius
			if dist_sq > load_r_sq and dist_sq <= lod_r_sq:
				var target_col: Vector2i = Vector2i(center_col.x + dx, center_col.y + dz)

				# Check if column already has an active 3D view
				var has_3d: bool = false
				for y: int in range(config.min_chunk_y, config.max_chunk_y + 1):
					if _chunk_view_map.has(Vector3i(target_col.x, y, target_col.y)):
						has_3d = true
						break
				if has_3d:
					continue

				_queue_mutex.lock()
				var already_pending: bool = _pending_lod_coords.has(target_col)
				_queue_mutex.unlock()

				if not _lod_view_map.has(target_col) and not already_pending:
					needed_cols.append(target_col)

	# Clean up LOD views that moved out of bounds or inside load_radius
	var cols_to_remove: Array[Vector2i] = []
	for col: Vector2i in _lod_view_map:
		var dx: int = col.x - center_col.x
		var dz: int = col.y - center_col.y
		var dist_sq: int = dx * dx + dz * dz
		if dist_sq > lod_r_sq or dist_sq <= load_r_sq:
			cols_to_remove.append(col)

	for col: Vector2i in cols_to_remove:
		_remove_lod_view(col)

	if needed_cols.is_empty():
		return

	needed_cols.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - center_col).length_squared() < (b - center_col).length_squared()
	)

	if is_synchronous:
		for col: Vector2i in needed_cols:
			var lod_mesh: ArrayMesh = LODHeightmapMesherScript.build_column_lod_mesh(
				col, generator, config.primary_biome, registry
			)
			_apply_lod_view(col, lod_mesh)
	else:
		_queue_mutex.lock()
		for col: Vector2i in needed_cols:
			_pending_lod_coords[col] = true
			_lod_queue.append(col)

		if not _is_worker_running:
			_is_worker_running = true
			_current_task_id = WorkerThreadPool.add_task(Callable(self, "_background_worker_loop"))
		_queue_mutex.unlock()

## Updates visibility of all subterranean chunk views based on player altitude
func _update_subterranean_occlusion() -> void:
	for coord: Vector3i in _chunk_view_map:
		var view: ChunkView = _chunk_view_map[coord]
		if view.is_subterranean:
			view.set_occluded(not _is_player_underground and config.enable_cave_occlusion)

## EventBus receiver for player movement, updating chunks and occlusion
func _on_player_position_updated(world_pos: Vector3) -> void:
	var player_voxel: Vector3i = VoxelCoordinates.world_pos_to_voxel_coord(world_pos)
	var current_chunk: Vector3i = VoxelCoordinates.voxel_coord_to_chunk_coord(player_voxel)

	if current_chunk != _last_player_chunk:
		_last_player_chunk = current_chunk
		load_chunks_around_coord(current_chunk, config.load_radius_chunks, false)
		if config.enable_lod:
			update_lod_around_col(Vector2i(current_chunk.x, current_chunk.z), false)

	# Update cave / subterranean occlusion based on player altitude vs surface datum
	var ground_h: int = generator.get_terrain_height_at(player_voxel.x, player_voxel.z)
	var player_underground_now: bool = player_voxel.y < ground_h
	if player_underground_now != _is_player_underground:
		_is_player_underground = player_underground_now
		_update_subterranean_occlusion()

## Returns count of currently active chunk views.
func get_loaded_chunk_count() -> int:
	return _chunk_view_map.size()

## Returns count of currently active distant LOD chunk views.
func get_lod_chunk_count() -> int:
	return _lod_view_map.size()

## Returns true if the player is currently detected below the local terrain surface datum.
func is_player_underground() -> bool:
	return _is_player_underground

