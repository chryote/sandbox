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
			if height < 0 or height >= ConstantsScript.CHUNK_HEIGHT_VOXELS:
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

	# 4. Test Chunk Generation
	var chunk = ChunkDataScript.new(Vector3i.ZERO)
	generator.generate_chunk_data(chunk)

	if chunk.is_empty():
		printerr("FAIL: Generated chunk is empty")
		return false

	# Bedrock must be present at layer 0
	if chunk.get_block(Vector3i(0, 0, 0)) != ConstantsScript.BLOCK_ID_BEDROCK:
		printerr("FAIL: Bedrock not found at (0, 0, 0)")
		return false

	# Air must be present at very top
	if chunk.get_block(Vector3i(0, ConstantsScript.CHUNK_HEIGHT_VOXELS - 1, 0)) != ConstantsScript.BLOCK_ID_AIR:
		printerr("FAIL: Air expected at chunk ceiling")
		return false

	return true
