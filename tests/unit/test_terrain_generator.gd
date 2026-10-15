class_name TestTerrainGenerator
extends RefCounted

const ConstantsScript = preload("res://core/constants.gd")
const WorldGenConfigScript = preload("res://modules/world/data/world_gen_config.gd")
const TerrainGeneratorScript = preload("res://modules/world/generation/terrain_generator.gd")
const ChunkDataScript = preload("res://modules/world/chunk/chunk_data.gd")

static func run_all() -> bool:
	# 1. Test WorldGenConfig and FastNoiseLite properties
	var config = WorldGenConfigScript.new()
	if not is_equal_approx(config.noise_frequency, 0.01):
		printerr("FAIL: Expected default noise frequency 0.01, got: %f" % config.noise_frequency)
		return false

	if config.noise_fractal_octaves != 2:
		printerr("FAIL: Expected default noise octaves 2, got: %d" % config.noise_fractal_octaves)
		return false

	if not is_equal_approx(config.noise_fractal_gain, 0.2):
		printerr("FAIL: Expected default noise gain 0.2, got: %f" % config.noise_fractal_gain)
		return false

	if not config.enable_smoothing:
		printerr("FAIL: Expected enable_smoothing to be true by default")
		return false

	if not config.enable_terrace_shaping:
		printerr("FAIL: Expected enable_terrace_shaping to be true by default")
		return false

	var noise: FastNoiseLite = config.create_configured_noise()
	if noise == null:
		printerr("FAIL: create_configured_noise returned null")
		return false

	if not is_equal_approx(noise.frequency, 0.01):
		printerr("FAIL: Configured noise frequency mismatch")
		return false

	# 2. Test TerrainGenerator height bounds
	var generator = TerrainGeneratorScript.new(config)
	for x: int in range(-50, 50, 10):
		for z: int in range(-50, 50, 10):
			var height: int = generator.get_terrain_height_at(x, z)
			if height < 0 or height >= ConstantsScript.WORLD_MAX_HEIGHT_VOXELS:
				printerr("FAIL: Terrain height %d out of bounds at (%d, %d)" % [height, x, z])
				return false

	# 3. Test Terrain Smoothness Metric
	# With frequency 0.01 and low gain, adjacent voxels should rarely jump by more than 1 block.
	var steep_jumps: int = 0
	var sample_count: int = 100
	for i: int in range(sample_count):
		var h0: int = generator.get_terrain_height_at(i, 0)
		var h1: int = generator.get_terrain_height_at(i + 1, 0)
		var diff: int = absi(h1 - h0)
		if diff > 1:
			steep_jumps += 1

	if steep_jumps > 5:
		printerr("FAIL: Too many steep jumps (> 1 block) in smooth terrain: %d / %d" % [steep_jumps, sample_count])
		return false

	# 4. Test Chunk Generation (Two-Phase Surface-First Decoupling)
	var shell_chunk = ChunkDataScript.new(Vector3i.ZERO)
	generator.generate_surface_shell(shell_chunk)
	if shell_chunk.is_empty():
		printerr("FAIL: Surface shell chunk is empty")
		return false
	if not shell_chunk.is_surface_only():
		printerr("FAIL: Surface shell chunk should report is_surface_only() == true")
		return false

	var full_chunk = ChunkDataScript.new(Vector3i.ZERO)
	generator.generate_chunk_data(full_chunk)
	if full_chunk.is_empty():
		printerr("FAIL: Generated chunk is empty")
		return false
	if not full_chunk.is_full():
		printerr("FAIL: Generated chunk should report is_full() == true")
		return false

	# Bedrock must be present at layer 0 in full chunk
	if full_chunk.get_block(Vector3i(0, 0, 0)) != ConstantsScript.BLOCK_ID_BEDROCK:
		printerr("FAIL: Bedrock not found at (0, 0, 0)")
		return false

	# Filling subsurface on shell chunk should match full_chunk block-for-block
	generator.fill_subsurface(shell_chunk)
	if not shell_chunk.is_full():
		printerr("FAIL: Shell chunk after fill_subsurface should report is_full() == true")
		return false

	for cz: int in range(ConstantsScript.CHUNK_DEPTH_VOXELS):
		for cy: int in range(ConstantsScript.CHUNK_HEIGHT_VOXELS):
			for cx: int in range(ConstantsScript.CHUNK_WIDTH_VOXELS):
				var p: Vector3i = Vector3i(cx, cy, cz)
				if shell_chunk.get_block(p) != full_chunk.get_block(p):
					printerr("FAIL: Two-phase chunk mismatch at %s (shell: %d, full: %d)" % [p, shell_chunk.get_block(p), full_chunk.get_block(p)])
					return false

	# Test homogeneous envelope skipping for sky sub-chunk
	var sky_chunk = ChunkDataScript.new(Vector3i(0, 3, 0)) # y = 48..63
	generator.generate_surface_shell(sky_chunk)
	if not sky_chunk.is_homogeneous_air() or not sky_chunk.is_full():
		printerr("FAIL: Sky chunk (0, 3, 0) should be classified as homogeneous air and FULL")
		return false

	# 5. Test Ramp Landing Obstruction Suppression (Approach B)
	# When a neighbor cell contains a straight ramp sloping into this cell's lowest edge,
	# the inner corner shim must be suppressed (return -1) so the ramp exit remains open.
	var mock_gen = MockTerrainGenerator.new(config)
	# Center cell at (5, 5) with height 10
	mock_gen.set_mock_height(5, 5, 10)
	# South cell at (5, 6) with height 11
	mock_gen.set_mock_height(5, 6, 11)
	# East cell at (6, 5) with height 11
	mock_gen.set_mock_height(6, 5, 11)
	# SE diagonal at (6, 6) with height 11
	mock_gen.set_mock_height(6, 6, 11)
	# North and West at height 10
	mock_gen.set_mock_height(5, 4, 10)
	mock_gen.set_mock_height(4, 5, 10)

	# Configure South cell (5, 6) to have only 1 drop (North into (5, 5)), making it a RAMP_NORTH
	mock_gen.set_mock_height(5, 7, 11) # South neighbor of (5, 6)
	mock_gen.set_mock_height(4, 6, 11) # West neighbor of (5, 6)
	# East neighbor of (5, 6) is (6, 6) already 11

	var offset_suppressed: int = mock_gen._resolve_inner_corner_offset(
		0, 1, 1, 0,
		10, 10, 10, 11,
		10,
		5, 5
	)
	if offset_suppressed != -1:
		printerr("FAIL: Expected inner corner to be suppressed (-1) when ramp slopes into it, got: %d" % offset_suppressed)
		return false

	# If South cell is NOT a ramp (e.g. has 2 drops: North and South), inner corner should NOT be suppressed
	mock_gen.set_mock_height(5, 7, 10) # Now (5, 6) drops both North and South -> ridge, not a ramp
	mock_gen.set_mock_height(7, 5, 10) # (6, 5) drops East
	mock_gen.set_mock_height(6, 4, 11)
	var offset_unsuppressed: int = mock_gen._resolve_inner_corner_offset(
		0, 1, 1, 0,
		10, 10, 10, 11,
		10,
		5, 5
	)
	if offset_unsuppressed != 0:
		printerr("FAIL: Expected unsuppressed inner corner offset 0, got: %d" % offset_unsuppressed)
	# 6. Test Outer Corner Slope Gap Filler Resolution & Isolated Shim Clearing
	# A) Isolated case: cell at (5, 5) has SE diagonal neighbor at (6, 6) with height 11,
	# but no supporting side neighbors on South (5, 6) or East (6, 5).
	# Must be cleared / suppressed (return -1).
	var isolated_gen = MockTerrainGenerator.new(config)
	isolated_gen.set_mock_height(5, 5, 10)
	isolated_gen.set_mock_height(6, 6, 11)
	var isolated_offset: int = isolated_gen._resolve_outer_corner_offset(
		0, 0, 0, 0,
		10, 10, 10, 11,
		10,
		5, 5
	)
	if isolated_offset != -1:
		printerr("FAIL: Expected isolated outer corner shim without side neighbors to be cleared (-1), got: %d" % isolated_offset)
		return false

	# B) Connected case: South cell (5, 6) and East cell (6, 5) both have slopes/inner corners bridging into (6, 6).
	# Set heights so (5, 6) and (6, 5) form valid inner corners at y=11.
	isolated_gen.set_mock_height(5, 7, 11)
	isolated_gen.set_mock_height(6, 7, 11)
	isolated_gen.set_mock_height(7, 5, 11)
	isolated_gen.set_mock_height(7, 6, 11)
	var connected_offset: int = isolated_gen._resolve_outer_corner_offset(
		0, 0, 0, 0,
		10, 10, 10, 11,
		10,
		5, 5
	)
	if connected_offset != 3:
		printerr("FAIL: Expected connected outer corner shim to resolve to 3 (SE), got: %d" % connected_offset)
		return false

	return true

class MockTerrainGenerator extends TerrainGeneratorScript:
	var mock_heights: Dictionary = {}

	func _init(p_config: WorldGenConfigScript) -> void:
		super._init(p_config)

	func set_mock_height(x: int, z: int, h: int) -> void:
		mock_heights[Vector2i(x, z)] = h

	func get_terrain_height_at(x: int, z: int) -> int:
		if mock_heights.has(Vector2i(x, z)):
			return mock_heights[Vector2i(x, z)]
		return 10
