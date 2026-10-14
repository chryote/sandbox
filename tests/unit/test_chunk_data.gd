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

	return true
