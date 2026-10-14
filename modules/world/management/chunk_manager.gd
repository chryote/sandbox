class_name ChunkManager
extends Node3D

## -----------------------------------------------------------------------------
## Configuration & Dependencies
## -----------------------------------------------------------------------------
@export var config: WorldGenConfig = null
var registry: BlockRegistry = null
var generator: TerrainGenerator = null

## -----------------------------------------------------------------------------
## Internal Storage
## -----------------------------------------------------------------------------
var _chunk_data_map: Dictionary = {}   # Vector3i -> ChunkData
var _chunk_view_map: Dictionary = {}   # Vector3i -> ChunkView

func _ready() -> void:
	if config == null:
		config = WorldGenConfig.new()

	registry = BlockRegistry.new()
	generator = TerrainGenerator.new(config)

	# Connect to decoupled EventBus modification requests
	if EventBus != null:
		EventBus.block_modify_requested.connect(_on_block_modify_requested)
		Logger.info("ChunkManager initialized and bound to EventBus.", "WorldGen")

	# Initial world generation around origin (chunk 0,0,0)
	load_chunks_around_coord(Vector3i.ZERO, config.load_radius_chunks)

## -----------------------------------------------------------------------------
## Chunk Loading & Lifecycle
## -----------------------------------------------------------------------------
## Generates and loads chunks in a square radius around a central chunk coordinate.
func load_chunks_around_coord(center_coord: Vector3i, radius_chunks: int) -> void:
	var newly_loaded_coords: Array[Vector3i] = []

	for offset_z: int in range(-radius_chunks, radius_chunks + 1):
		for offset_x: int in range(-radius_chunks, radius_chunks + 1):
			var target_coord: Vector3i = Vector3i(
				center_coord.x + offset_x,
				center_coord.y,
				center_coord.z + offset_z
			)

			if not _chunk_data_map.has(target_coord):
				_generate_chunk_data_only(target_coord)
				newly_loaded_coords.append(target_coord)

	# After data is generated for the entire radius, mesh all newly created chunks
	# (ensuring cross-boundary face culling has access to neighboring chunk data)
	for coord: Vector3i in newly_loaded_coords:
		_create_and_mesh_chunk_view(coord)

## Generates voxel data for a single chunk coordinate without meshing yet.
func _generate_chunk_data_only(coord: Vector3i) -> ChunkData:
	var data: ChunkData = ChunkData.new(coord)
	generator.generate_chunk_data(data)
	_chunk_data_map[coord] = data
	return data

## Meshes a chunk and attaches its visual/physics node to the scene tree.
func _create_and_mesh_chunk_view(coord: Vector3i) -> void:
	if not _chunk_data_map.has(coord):
		return

	var data: ChunkData = _chunk_data_map[coord]
	var view: ChunkView = null

	if _chunk_view_map.has(coord):
		view = _chunk_view_map[coord]
	else:
		view = ChunkView.new(coord)
		add_child(view)
		_chunk_view_map[coord] = view

	var mesh: ArrayMesh = ChunkMesher.build_chunk_mesh(
		data,
		registry,
		Callable(self, "is_voxel_transparent")
	)
	view.update_mesh_and_collision(mesh)

	if EventBus != null:
		EventBus.chunk_loaded.emit(coord)

## Unloads and frees a chunk at the specified coordinate.
func unload_chunk(coord: Vector3i) -> void:
	if _chunk_view_map.has(coord):
		var view: ChunkView = _chunk_view_map[coord]
		view.queue_free()
		_chunk_view_map.erase(coord)

	if _chunk_data_map.has(coord):
		_chunk_data_map.erase(coord)

	if EventBus != null:
		EventBus.chunk_unloaded.emit(coord)

## -----------------------------------------------------------------------------
## Voxel Query & Modification
## -----------------------------------------------------------------------------
## Returns the block ID at the specified world voxel coordinate.
func get_block(world_voxel: Vector3i) -> int:
	var chunk_coord: Vector3i = VoxelCoordinates.voxel_coord_to_chunk_coord(world_voxel)
	if not _chunk_data_map.has(chunk_coord):
		return Constants.BLOCK_ID_AIR

	var local_coord: Vector3i = VoxelCoordinates.voxel_coord_to_local_coord(world_voxel)
	var chunk_data: ChunkData = _chunk_data_map[chunk_coord]
	return chunk_data.get_block(local_coord)

## Modifies a block at the specified world voxel coordinate and updates meshes.
func set_block(world_voxel: Vector3i, new_block_id: int) -> void:
	var chunk_coord: Vector3i = VoxelCoordinates.voxel_coord_to_chunk_coord(world_voxel)
	if not _chunk_data_map.has(chunk_coord):
		return

	var local_coord: Vector3i = VoxelCoordinates.voxel_coord_to_local_coord(world_voxel)
	var target_data: ChunkData = _chunk_data_map[chunk_coord]
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
	if not _chunk_data_map.has(chunk_coord):
		return true

	var local_coord: Vector3i = VoxelCoordinates.voxel_coord_to_local_coord(world_voxel)
	var chunk_data: ChunkData = _chunk_data_map[chunk_coord]
	var block_id: int = chunk_data.get_block(local_coord)
	return registry.is_transparent(block_id)

func _remesh_neighbors_if_boundary(chunk_coord: Vector3i, local_coord: Vector3i) -> void:
	# West boundary (-X)
	if local_coord.x == 0:
		_create_and_mesh_chunk_view(chunk_coord + Vector3i(-1, 0, 0))
	# East boundary (+X)
	elif local_coord.x == Constants.CHUNK_WIDTH_VOXELS - 1:
		_create_and_mesh_chunk_view(chunk_coord + Vector3i(1, 0, 0))

	# North boundary (-Z)
	if local_coord.z == 0:
		_create_and_mesh_chunk_view(chunk_coord + Vector3i(0, 0, -1))
	# South boundary (+Z)
	elif local_coord.z == Constants.CHUNK_DEPTH_VOXELS - 1:
		_create_and_mesh_chunk_view(chunk_coord + Vector3i(0, 0, 1))

## EventBus receiver for decoupled block modification requests
func _on_block_modify_requested(world_voxel_pos: Vector3i, new_block_id: int) -> void:
	set_block(world_voxel_pos, new_block_id)

## Returns count of currently active chunk views.
func get_loaded_chunk_count() -> int:
	return _chunk_view_map.size()
