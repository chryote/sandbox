class_name TestChunkData
extends RefCounted

const ConstantsScript = preload("res://core/constants.gd")
const ChunkDataScript = preload("res://modules/world/chunk/chunk_data.gd")

static func run_all() -> bool:
	var chunk = ChunkDataScript.new(Vector3i(1, 0, -2))

	# Newly initialized chunk must be empty
	if not chunk.is_empty():
		printerr("FAIL: Newly created chunk must be empty")
		return false

	var test_coord: Vector3i = Vector3i(4, 10, 8)
	chunk.set_block(test_coord, ConstantsScript.BLOCK_ID_STONE)

	if chunk.get_block(test_coord) != ConstantsScript.BLOCK_ID_STONE:
		printerr("FAIL: Chunk failed to retrieve set block")
		return false

	if chunk.is_empty():
		printerr("FAIL: Chunk with non-air block reported as empty")
		return false

	# Out of bounds access should safely return Air
	var invalid_coord: Vector3i = Vector3i(-5, 99, 100)
	if chunk.get_block(invalid_coord) != ConstantsScript.BLOCK_ID_AIR:
		printerr("FAIL: Out of bounds access should return Air")
		return false

	# Resetting back to Air should decrement count
	chunk.set_block(test_coord, ConstantsScript.BLOCK_ID_AIR)
	if not chunk.is_empty():
		printerr("FAIL: Chunk must be empty after removing block")
		return false

	# Test GenState lifecycle
	if chunk.gen_state != ChunkDataScript.GenState.UNGENERATED:
		printerr("FAIL: Newly created chunk must have gen_state UNGENERATED")
		return false

	chunk.gen_state = ChunkDataScript.GenState.SURFACE_ONLY
	if not chunk.is_surface_only() or chunk.is_full():
		printerr("FAIL: Chunk failed to report is_surface_only")
		return false

	chunk.gen_state = ChunkDataScript.GenState.FULL
	if not chunk.is_full() or chunk.is_surface_only():
		printerr("FAIL: Chunk failed to report is_full")
		return false

	# Test Homogeneous Storage & Promotion
	var homo_air = ChunkDataScript.new(Vector3i(0, 1, 0))
	homo_air.set_homogeneous(ConstantsScript.BLOCK_ID_AIR)
	if not homo_air.is_homogeneous() or not homo_air.is_homogeneous_air() or homo_air.is_homogeneous_solid():
		printerr("FAIL: Homogeneous air chunk flags invalid")
		return false
	if not homo_air.is_empty():
		printerr("FAIL: Homogeneous air chunk should report is_empty() == true")
		return false
	if homo_air.voxels.size() != 0:
		printerr("FAIL: Homogeneous chunk should consume 0 byte buffer")
		return false
	if homo_air.get_block(Vector3i(5, 5, 5)) != ConstantsScript.BLOCK_ID_AIR:
		printerr("FAIL: Homogeneous air get_block returned non-air")
		return false

	var homo_solid = ChunkDataScript.new(Vector3i(0, -1, 0))
	homo_solid.set_homogeneous(ConstantsScript.BLOCK_ID_STONE)
	if not homo_solid.is_homogeneous() or not homo_solid.is_homogeneous_solid() or homo_solid.is_homogeneous_air():
		printerr("FAIL: Homogeneous solid chunk flags invalid")
		return false
	if homo_solid.is_empty():
		printerr("FAIL: Homogeneous solid chunk should not report is_empty() == true")
		return false
	if homo_solid.get_block(Vector3i(2, 3, 4)) != ConstantsScript.BLOCK_ID_STONE:
		printerr("FAIL: Homogeneous solid get_block returned wrong block")
		return false

	# Writing a differing block must trigger automatic promotion to VOXEL_BUFFER
	var edit_pos: Vector3i = Vector3i(1, 2, 3)
	homo_solid.set_block(edit_pos, ConstantsScript.BLOCK_ID_DIRT)
	if homo_solid.is_homogeneous():
		printerr("FAIL: Modified chunk must promote out of homogeneous storage")
		return false
	if homo_solid.storage_type != ChunkDataScript.StorageType.VOXEL_BUFFER:
		printerr("FAIL: Modified chunk must have storage_type VOXEL_BUFFER")
		return false
	if homo_solid.voxels.size() != ConstantsScript.CHUNK_VOXEL_VOLUME:
		printerr("FAIL: Promoted chunk voxels array must match CHUNK_VOXEL_VOLUME")
		return false
	if homo_solid.get_block(edit_pos) != ConstantsScript.BLOCK_ID_DIRT:
		printerr("FAIL: Promoted chunk did not retain edited block")
		return false
	if homo_solid.get_block(Vector3i(0, 0, 0)) != ConstantsScript.BLOCK_ID_STONE:
		printerr("FAIL: Promoted chunk did not preserve background stone voxels")
		return false

	return true
