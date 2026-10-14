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

## Computes the clamped terrain surface height for any world (x, z) coordinate.
func get_terrain_height_at(world_x: int, world_z: int) -> int:
	var biome: BiomeDefinition = config.primary_biome
	var raw_noise: float = noise.get_noise_2d(float(world_x), float(world_z))
	var normalized_noise: float = (raw_noise + NOISE_NORMALIZATION_OFFSET) * NOISE_NORMALIZATION_HALF
	var target_height: int = biome.base_elevation_voxels + floori(normalized_noise * float(biome.elevation_amplitude_voxels))
	var max_y: int = Constants.CHUNK_HEIGHT_VOXELS - 1
	return clampi(target_height, BEDROCK_LAYER_Y, max_y)

## Resolves whether a surface voxel should be a standard flat cube or a directional ramp.
func _resolve_surface_block_id(
	surface_base_id: int,
	diff_n: int, diff_s: int, diff_e: int, diff_w: int,
	world_x: int, world_z: int
) -> int:
	# Conflicting opposite drops (ridge or peak): keep full block
	if (diff_n == -1 and diff_s == -1) or (diff_e == -1 and diff_w == -1):
		return surface_base_id

	var drops: Array[int] = [] # 0=North, 1=South, 2=East, 3=West
	if diff_n == -1: drops.append(0)
	if diff_s == -1: drops.append(1)
	if diff_e == -1: drops.append(2)
	if diff_w == -1: drops.append(3)

	if drops.is_empty():
		return surface_base_id

	var chosen_dir: int = drops[0]
	if drops.size() > 1:
		# Pick the direction that has the steeper noise gradient (lower raw noise)
		var best_dir: int = drops[0]
		var min_raw: float = 999.0
		for d: int in drops:
			var nx: int = world_x + (1 if d == 2 else (-1 if d == 3 else 0))
			var nz: int = world_z + (1 if d == 1 else (-1 if d == 0 else 0))
			var raw: float = noise.get_noise_2d(float(nx), float(nz))
			if raw < min_raw:
				min_raw = raw
				best_dir = d
		chosen_dir = best_dir

	var shape_offset: int = chosen_dir # 0=North, 1=South, 2=East, 3=West
	match surface_base_id:
		Constants.BLOCK_ID_GRASS:
			return Constants.BLOCK_ID_GRASS_RAMP_NORTH + shape_offset
		Constants.BLOCK_ID_SAND:
			return Constants.BLOCK_ID_SAND_RAMP_NORTH + shape_offset
		Constants.BLOCK_ID_STONE:
			return Constants.BLOCK_ID_STONE_RAMP_NORTH + shape_offset
		Constants.BLOCK_ID_DIRT:
			return Constants.BLOCK_ID_DIRT_RAMP_NORTH + shape_offset
		_:
			return surface_base_id

## Fills a ChunkData buffer with terrain voxels according to the configuration.
func generate_chunk_data(chunk_data: ChunkData) -> void:
	var biome: BiomeDefinition = config.primary_biome
	var chunk_origin_x: int = chunk_data.chunk_coord.x * Constants.CHUNK_WIDTH_VOXELS
	var chunk_origin_z: int = chunk_data.chunk_coord.z * Constants.CHUNK_DEPTH_VOXELS

	for z: int in range(Constants.CHUNK_DEPTH_VOXELS):
		var world_z: int = chunk_origin_z + z

		for x: int in range(Constants.CHUNK_WIDTH_VOXELS):
			var world_x: int = chunk_origin_x + x

			var clamped_height: int = get_terrain_height_at(world_x, world_z)

			# Sample cardinal neighbor heights for slope/ramp placement
			var h_north: int = get_terrain_height_at(world_x, world_z - 1)
			var h_south: int = get_terrain_height_at(world_x, world_z + 1)
			var h_east: int = get_terrain_height_at(world_x + 1, world_z)
			var h_west: int = get_terrain_height_at(world_x - 1, world_z)

			var diff_n: int = h_north - clamped_height
			var diff_s: int = h_south - clamped_height
			var diff_e: int = h_east - clamped_height
			var diff_w: int = h_west - clamped_height

			for y: int in range(Constants.CHUNK_HEIGHT_VOXELS):
				var local_pos: Vector3i = Vector3i(x, y, z)

				if y > clamped_height:
					# Air above ground
					chunk_data.set_block(local_pos, Constants.BLOCK_ID_AIR)
				elif y == BEDROCK_LAYER_Y:
					# Indestructible bottom foundation
					chunk_data.set_block(local_pos, biome.bedrock_block_id)
				elif y == clamped_height:
					# Surface layer (flat cube or directional ramp)
					var surface_block_id: int = _resolve_surface_block_id(
						biome.surface_block_id,
						diff_n, diff_s, diff_e, diff_w,
						world_x, world_z
					)
					chunk_data.set_block(local_pos, surface_block_id)
				elif y > (clamped_height - biome.subsurface_depth_layers):
					# Subsurface layer (e.g. Dirt)
					chunk_data.set_block(local_pos, biome.subsurface_block_id)
				else:
					# Deep subterranean bedrock/stone
					chunk_data.set_block(local_pos, biome.deep_block_id)
