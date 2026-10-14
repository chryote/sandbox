class_name TerrainGenerator
extends RefCounted

## -----------------------------------------------------------------------------
## Named Constants
## -----------------------------------------------------------------------------
const BEDROCK_LAYER_Y: int = 0
const NOISE_NORMALIZATION_OFFSET: float = 1.0
const NOISE_NORMALIZATION_HALF: float = 0.5

## -----------------------------------------------------------------------------
## State
## -----------------------------------------------------------------------------
var config: WorldGenConfig = null
var noise: FastNoiseLite = null

func _init(p_config: WorldGenConfig = null) -> void:
	if p_config == null:
		config = WorldGenConfig.new()
	else:
		config = p_config

	noise = config.create_configured_noise()

## Fills a ChunkData buffer with terrain voxels according to the configuration.
func generate_chunk_data(chunk_data: ChunkData) -> void:
	var biome: BiomeDefinition = config.primary_biome
	var chunk_origin_x: int = chunk_data.chunk_coord.x * Constants.CHUNK_WIDTH_VOXELS
	var chunk_origin_z: int = chunk_data.chunk_coord.z * Constants.CHUNK_DEPTH_VOXELS
	var max_y: int = Constants.CHUNK_HEIGHT_VOXELS - 1

	for z: int in range(Constants.CHUNK_DEPTH_VOXELS):
		var world_z: int = chunk_origin_z + z

		for x: int in range(Constants.CHUNK_WIDTH_VOXELS):
			var world_x: int = chunk_origin_x + x

			# Sample 2D height noise [-1.0, 1.0]
			var raw_noise: float = noise.get_noise_2d(float(world_x), float(world_z))
			# Map noise from [-1.0, 1.0] to [0.0, 1.0]
			var normalized_noise: float = (raw_noise + NOISE_NORMALIZATION_OFFSET) * NOISE_NORMALIZATION_HALF

			var target_height: int = biome.base_elevation_voxels + floori(normalized_noise * float(biome.elevation_amplitude_voxels))
			var clamped_height: int = clampi(target_height, BEDROCK_LAYER_Y, max_y)

			for y: int in range(Constants.CHUNK_HEIGHT_VOXELS):
				var local_pos: Vector3i = Vector3i(x, y, z)

				if y > clamped_height:
					# Air above ground
					chunk_data.set_block(local_pos, Constants.BLOCK_ID_AIR)
				elif y == BEDROCK_LAYER_Y:
					# Indestructible bottom foundation
					chunk_data.set_block(local_pos, biome.bedrock_block_id)
				elif y == clamped_height:
					# Surface layer (e.g. Grass)
					chunk_data.set_block(local_pos, biome.surface_block_id)
				elif y > (clamped_height - biome.subsurface_depth_layers):
					# Subsurface layer (e.g. Dirt)
					chunk_data.set_block(local_pos, biome.subsurface_block_id)
				else:
					# Deep subterranean bedrock/stone
					chunk_data.set_block(local_pos, biome.deep_block_id)
