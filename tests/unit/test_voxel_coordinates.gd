class_name TestVoxelCoordinates
extends RefCounted

const ConstantsScript = preload("res://core/constants.gd")
const VoxelCoordinatesScript = preload("res://core/math/voxel_coordinates.gd")

static func run_all() -> bool:
	var all_passed: bool = true
	all_passed = test_world_to_voxel() and all_passed
	all_passed = test_chunk_and_local_mapping() and all_passed
	all_passed = test_flat_index_roundtrip() and all_passed
	all_passed = test_mining_and_placement_resolution() and all_passed
	return all_passed

static func test_world_to_voxel() -> bool:
	var pos_positive: Vector3 = Vector3(5.4, 12.1, 8.9)
	var expected_pos: Vector3i = Vector3i(5, 12, 8)
	var actual_pos: Vector3i = VoxelCoordinatesScript.world_pos_to_voxel_coord(pos_positive)
	if actual_pos != expected_pos:
		printerr("FAIL: test_world_to_voxel positive failed: ", actual_pos, " expected: ", expected_pos)
		return false

	var pos_negative: Vector3 = Vector3(-0.1, -1.5, -16.0)
	var expected_neg: Vector3i = Vector3i(-1, -2, -16)
	var actual_neg: Vector3i = VoxelCoordinatesScript.world_pos_to_voxel_coord(pos_negative)
	if actual_neg != expected_neg:
		printerr("FAIL: test_world_to_voxel negative failed: ", actual_neg, " expected: ", expected_neg)
		return false

	return true

static func test_chunk_and_local_mapping() -> bool:
	# Positive world coordinate (e.g. voxel (35, 10, 50))
	var voxel_coord: Vector3i = Vector3i(35, 10, 50)
	var chunk_coord: Vector3i = VoxelCoordinatesScript.voxel_coord_to_chunk_coord(voxel_coord)
	var local_coord: Vector3i = VoxelCoordinatesScript.voxel_coord_to_local_coord(voxel_coord)

	# 35 / 16 = chunk 2, local 3 (2*16 + 3 = 35)
	# 10 / 32 = chunk 0, local 10
	# 50 / 16 = chunk 3, local 2 (3*16 + 2 = 50)
	var expected_chunk: Vector3i = Vector3i(2, 0, 3)
	var expected_local: Vector3i = Vector3i(3, 10, 2)

	if chunk_coord != expected_chunk or local_coord != expected_local:
		printerr("FAIL: test_chunk_and_local_mapping positive failed: chunk=", chunk_coord, " local=", local_coord)
		return false

	# Negative world coordinate (e.g. voxel (-1, 5, -17))
	var neg_voxel: Vector3i = Vector3i(-1, 5, -17)
	var neg_chunk: Vector3i = VoxelCoordinatesScript.voxel_coord_to_chunk_coord(neg_voxel)
	var neg_local: Vector3i = VoxelCoordinatesScript.voxel_coord_to_local_coord(neg_voxel)

	# -1 / 16 floor = chunk -1, local = posmod(-1, 16) = 15 (-1*16 + 15 = -1)
	# 5 / 32 floor = chunk 0, local = 5
	# -17 / 16 floor = chunk -2, local = posmod(-17, 16) = 15 (-2*16 + 15 = -17)
	var expected_neg_chunk: Vector3i = Vector3i(-1, 0, -2)
	var expected_neg_local: Vector3i = Vector3i(15, 5, 15)

	if neg_chunk != expected_neg_chunk or neg_local != expected_neg_local:
		printerr("FAIL: test_chunk_and_local_mapping negative failed: chunk=", neg_chunk, " local=", neg_local)
		return false

	# Roundtrip test
	var reconstructed: Vector3i = VoxelCoordinatesScript.chunk_and_local_to_voxel_coord(neg_chunk, neg_local)
	if reconstructed != neg_voxel:
		printerr("FAIL: test_chunk_and_local_mapping roundtrip failed: ", reconstructed, " expected: ", neg_voxel)
		return false

	return true

static func test_flat_index_roundtrip() -> bool:
	for z: int in [0, 5, ConstantsScript.CHUNK_DEPTH_VOXELS - 1]:
		for y: int in [0, 15, ConstantsScript.CHUNK_HEIGHT_VOXELS - 1]:
			for x: int in [0, 7, ConstantsScript.CHUNK_WIDTH_VOXELS - 1]:
				var local: Vector3i = Vector3i(x, y, z)
				var index: int = VoxelCoordinatesScript.local_coord_to_flat_index(local)
				var roundtrip: Vector3i = VoxelCoordinatesScript.flat_index_to_local_coord(index)
				if roundtrip != local:
					printerr("FAIL: flat_index_roundtrip failed for: ", local, " got: ", roundtrip)
					return false
	return true

static func test_mining_and_placement_resolution() -> bool:
	var hit_point: Vector3 = Vector3(2.5, 6.0, 3.5) # Top face of voxel (2, 5, 3) at Y=6.0
	var hit_normal: Vector3 = Vector3(0.0, 1.0, 0.0) # +Y

	var mined_voxel: Vector3i = VoxelCoordinatesScript.resolve_mined_voxel_coord(hit_point, hit_normal)
	var placed_voxel: Vector3i = VoxelCoordinatesScript.resolve_placed_voxel_coord(hit_point, hit_normal)

	if mined_voxel != Vector3i(2, 5, 3):
		printerr("FAIL: resolve_mined_voxel_coord got ", mined_voxel, " expected (2, 5, 3)")
		return false

	if placed_voxel != Vector3i(2, 6, 3):
		printerr("FAIL: resolve_placed_voxel_coord got ", placed_voxel, " expected (2, 6, 3)")
		return false

	return true
