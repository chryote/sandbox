class_name ChunkData
extends RefCounted

## -----------------------------------------------------------------------------
## Generation Lifecycle States & Storage Models
## -----------------------------------------------------------------------------
enum GenState {
	UNGENERATED = 0,
	SURFACE_ONLY = 1,
	FULL = 2
}

enum StorageType {
	HOMOGENEOUS = 0,
	VOXEL_BUFFER = 1
}

## -----------------------------------------------------------------------------
## State
## -----------------------------------------------------------------------------
var chunk_coord: Vector3i = Vector3i.ZERO
var voxels: PackedByteArray = PackedByteArray()
var non_air_count: int = 0
var gen_state: GenState = GenState.UNGENERATED
var storage_type: StorageType = StorageType.VOXEL_BUFFER
var homogeneous_block_id: int = Constants.BLOCK_ID_AIR

func _init(p_chunk_coord: Vector3i = Vector3i.ZERO) -> void:
	chunk_coord = p_chunk_coord
	voxels.resize(Constants.CHUNK_VOXEL_VOLUME)
	voxels.fill(Constants.BLOCK_ID_AIR)
	non_air_count = 0
	gen_state = GenState.UNGENERATED
	storage_type = StorageType.VOXEL_BUFFER
	homogeneous_block_id = Constants.BLOCK_ID_AIR

func is_surface_only() -> bool:
	return gen_state == GenState.SURFACE_ONLY

func is_full() -> bool:
	return gen_state == GenState.FULL

## Sets the chunk into a 0-memory homogeneous state (all voxels share one block ID).
func set_homogeneous(block_id: int) -> void:
	storage_type = StorageType.HOMOGENEOUS
	homogeneous_block_id = block_id
	voxels.clear()
	non_air_count = 0 if block_id == Constants.BLOCK_ID_AIR else Constants.CHUNK_VOXEL_VOLUME

func is_homogeneous() -> bool:
	return storage_type == StorageType.HOMOGENEOUS

func is_homogeneous_air() -> bool:
	return storage_type == StorageType.HOMOGENEOUS and homogeneous_block_id == Constants.BLOCK_ID_AIR

func is_homogeneous_solid() -> bool:
	return storage_type == StorageType.HOMOGENEOUS and homogeneous_block_id != Constants.BLOCK_ID_AIR

## Promotes a homogeneous chunk into a full 4096-byte voxel buffer on write.
func _promote_to_buffer() -> void:
	storage_type = StorageType.VOXEL_BUFFER
	voxels.resize(Constants.CHUNK_VOXEL_VOLUME)
	voxels.fill(homogeneous_block_id)
	non_air_count = 0 if homogeneous_block_id == Constants.BLOCK_ID_AIR else Constants.CHUNK_VOXEL_VOLUME

## Retrieves the block ID at local voxel coordinates [0..15, 0..15, 0..15].
func get_block(local_pos: Vector3i) -> int:
	if not VoxelCoordinates.is_local_coord_valid(local_pos):
		return Constants.BLOCK_ID_AIR
	if storage_type == StorageType.HOMOGENEOUS:
		return homogeneous_block_id
	var flat_index: int = VoxelCoordinates.local_coord_to_flat_index(local_pos)
	return voxels[flat_index]

## Sets the block ID at local voxel coordinates and updates the non-air voxel count.
func set_block(local_pos: Vector3i, block_id: int) -> void:
	if not VoxelCoordinates.is_local_coord_valid(local_pos):
		return

	if storage_type == StorageType.HOMOGENEOUS:
		if block_id == homogeneous_block_id:
			return
		_promote_to_buffer()

	var flat_index: int = VoxelCoordinates.local_coord_to_flat_index(local_pos)
	var old_id: int = voxels[flat_index]

	if old_id == block_id:
		return

	voxels[flat_index] = block_id

	if old_id == Constants.BLOCK_ID_AIR and block_id != Constants.BLOCK_ID_AIR:
		non_air_count += 1
	elif old_id != Constants.BLOCK_ID_AIR and block_id == Constants.BLOCK_ID_AIR:
		non_air_count -= 1

## Fast index-based accessor.
func get_block_by_index(flat_index: int) -> int:
	if flat_index < 0 or flat_index >= Constants.CHUNK_VOXEL_VOLUME:
		return Constants.BLOCK_ID_AIR
	if storage_type == StorageType.HOMOGENEOUS:
		return homogeneous_block_id
	return voxels[flat_index]

## Fast index-based mutator.
func set_block_by_index(flat_index: int, block_id: int) -> void:
	if flat_index < 0 or flat_index >= Constants.CHUNK_VOXEL_VOLUME:
		return

	if storage_type == StorageType.HOMOGENEOUS:
		if block_id == homogeneous_block_id:
			return
		_promote_to_buffer()

	var old_id: int = voxels[flat_index]
	if old_id == block_id:
		return

	voxels[flat_index] = block_id

	if old_id == Constants.BLOCK_ID_AIR and block_id != Constants.BLOCK_ID_AIR:
		non_air_count += 1
	elif old_id != Constants.BLOCK_ID_AIR and block_id == Constants.BLOCK_ID_AIR:
		non_air_count -= 1

## Returns true if the chunk contains only air voxels (allowing early skip during meshing).
func is_empty() -> bool:
	return non_air_count == 0
