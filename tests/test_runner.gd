class_name TestRunner
extends Node

const TestVoxelCoordinatesScript = preload("res://tests/unit/test_voxel_coordinates.gd")
const TestBlockRegistryScript = preload("res://tests/unit/test_block_registry.gd")
const TestChunkDataScript = preload("res://tests/unit/test_chunk_data.gd")
const TestRampBlocksScript = preload("res://tests/unit/test_ramp_blocks.gd")
const TestTerrainGeneratorScript = preload("res://tests/unit/test_terrain_generator.gd")
const TestWorkerPoolScript = preload("res://tests/unit/test_worker_pool.gd")
const TestLODAndOcclusionScript = preload("res://tests/unit/test_lod_and_occlusion.gd")

func _ready() -> void:
	Logger.info("Starting test suite execution...", "TestRunner")

	var success: bool = true

	# Test 1: Voxel Coordinates
	if TestVoxelCoordinatesScript.run_all():
		Logger.info("[PASS] TestVoxelCoordinates passed successfully.", "TestRunner")
	else:
		Logger.error("[FAIL] TestVoxelCoordinates failed.", "TestRunner")
		success = false

	# Test 2: Block Registry
	if TestBlockRegistryScript.run_all():
		Logger.info("[PASS] TestBlockRegistry passed successfully.", "TestRunner")
	else:
		Logger.error("[FAIL] TestBlockRegistry failed.", "TestRunner")
		success = false

	# Test 3: Chunk Data
	if TestChunkDataScript.run_all():
		Logger.info("[PASS] TestChunkData passed successfully.", "TestRunner")
	else:
		Logger.error("[FAIL] TestChunkData failed.", "TestRunner")
		success = false

	# Test 4: Ramp Blocks & Meshing
	if TestRampBlocksScript.run_all():
		Logger.info("[PASS] TestRampBlocks passed successfully.", "TestRunner")
	else:
		Logger.error("[FAIL] TestRampBlocks failed.", "TestRunner")
		success = false

	# Test 5: Terrain Generator & Smooth Noise Configuration
	if TestTerrainGeneratorScript.run_all():
		Logger.info("[PASS] TestTerrainGenerator passed successfully.", "TestRunner")
	else:
		Logger.error("[FAIL] TestTerrainGenerator failed.", "TestRunner")
		success = false

	# Test 6: Worker Thread Pool
	if TestWorkerPoolScript.run_all():
		Logger.info("[PASS] TestWorkerPool passed successfully.", "TestRunner")
	else:
		Logger.error("[FAIL] TestWorkerPool failed.", "TestRunner")
		success = false

	# Test 7: LOD Heightmap & Cave Occlusion
	if TestLODAndOcclusionScript.run_all():
		Logger.info("[PASS] TestLODAndOcclusion passed successfully.", "TestRunner")
	else:
		Logger.error("[FAIL] TestLODAndOcclusion failed.", "TestRunner")
		success = false

	if success:
		Logger.info("ALL SUITE TESTS PASSED (7/7)", "TestRunner")
	else:
		Logger.error("SOME TESTS FAILED", "TestRunner")

	await get_tree().process_frame
	get_tree().quit(0 if success else 1)

