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
	var raw_noise: float = 0.0

	if config.enable_smoothing:
		# 5-point cross continuous smoothing kernel: averages micro-ripples across neighbor coordinates
		var center: float = noise.get_noise_2d(float(world_x), float(world_z))
		var neighbors: float = (
			noise.get_noise_2d(float(world_x - 1), float(world_z)) +
			noise.get_noise_2d(float(world_x + 1), float(world_z)) +
			noise.get_noise_2d(float(world_x), float(world_z - 1)) +
			noise.get_noise_2d(float(world_x), float(world_z + 1))
		) * 0.25
		raw_noise = center * 0.5 + neighbors * 0.5
	else:
		raw_noise = noise.get_noise_2d(float(world_x), float(world_z))

	var normalized_noise: float = (raw_noise + NOISE_NORMALIZATION_OFFSET) * NOISE_NORMALIZATION_HALF

	var height_factor: float = normalized_noise
	if config.enable_terrace_shaping:
		# S-curve (smoothstep) to flatten hilltops and valley floors into wide terraces
		var t: float = clampf(normalized_noise, 0.0, 1.0)
		height_factor = t * t * (3.0 - 2.0 * t)

	var target_height: int = biome.base_elevation_voxels + floori(height_factor * float(biome.elevation_amplitude_voxels))
	var max_y: int = Constants.CHUNK_HEIGHT_VOXELS - 1
	return clampi(target_height, BEDROCK_LAYER_Y, max_y)

## Resolves whether an empty voxel at clamped_height + 1 is an inside corner bridging two perpendicular ramps.
func _resolve_inner_corner_offset(
	diff_n: int, diff_s: int, diff_e: int, diff_w: int,
	h_nw: int, h_ne: int, h_sw: int, h_se: int,
	clamped_height: int
) -> int:
	var h: int = clamped_height
	# NW low (South & East ramps higher)
	if diff_s >= 1 and diff_e >= 1 and h_se >= h + 1 and diff_n <= 0 and diff_w <= 0:
		return 0 # INNER_CORNER_NORTH_WEST
	# NE low (South & West ramps higher)
	if diff_s >= 1 and diff_w >= 1 and h_sw >= h + 1 and diff_n <= 0 and diff_e <= 0:
		return 1 # INNER_CORNER_NORTH_EAST
	# SW low (North & East ramps higher)
	if diff_n >= 1 and diff_e >= 1 and h_ne >= h + 1 and diff_s <= 0 and diff_w <= 0:
		return 2 # INNER_CORNER_SOUTH_WEST
	# SE low (North & West ramps higher)
	if diff_n >= 1 and diff_w >= 1 and h_nw >= h + 1 and diff_s <= 0 and diff_e <= 0:
		return 3 # INNER_CORNER_SOUTH_EAST

	return -1

## Resolves the registered block ID for an inner corner shape given the surface base material.
func _get_inner_corner_block_id(surface_base_id: int, corner_offset: int) -> int:
	match surface_base_id:
		Constants.BLOCK_ID_GRASS:
			return Constants.BLOCK_ID_GRASS_INNER_CORNER_NW + corner_offset
		Constants.BLOCK_ID_SAND:
			return Constants.BLOCK_ID_SAND_INNER_CORNER_NW + corner_offset
		Constants.BLOCK_ID_STONE:
			return Constants.BLOCK_ID_STONE_INNER_CORNER_NW + corner_offset
		Constants.BLOCK_ID_DIRT:
			return Constants.BLOCK_ID_DIRT_INNER_CORNER_NW + corner_offset
		_:
			return surface_base_id

## Resolves the registered ramp block ID for a given cardinal direction offset.
func _get_ramp_block_id(surface_base_id: int, shape_offset: int) -> int:
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

## Resolves whether a surface voxel should be a standard flat cube or straight ramp.
## Diagonal slope steps with 2 perpendicular drops align with the dominant downhill gradient
## to create flush, continuous ramps rather than jagged outward teeth.
func _resolve_surface_block_id(
	surface_base_id: int,
	diff_n: int, diff_s: int, diff_e: int, diff_w: int,
	world_x: int = 0, world_z: int = 0
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

	# Single drop: standard directional ramp
	if drops.size() == 1:
		return _get_ramp_block_id(surface_base_id, drops[0])

	# 2 or more drops (corners / diagonal steps): keep flat full block
	# Prevents placing directional straight ramps whose vertical side walls stick out into open air.
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

			# Sample diagonal neighbor heights for inner corner detection
			var h_nw: int = get_terrain_height_at(world_x - 1, world_z - 1)
			var h_ne: int = get_terrain_height_at(world_x + 1, world_z - 1)
			var h_sw: int = get_terrain_height_at(world_x - 1, world_z + 1)
			var h_se: int = get_terrain_height_at(world_x + 1, world_z + 1)

			var inner_offset: int = -1
			if clamped_height + 1 < Constants.CHUNK_HEIGHT_VOXELS:
				inner_offset = _resolve_inner_corner_offset(
					diff_n, diff_s, diff_e, diff_w,
					h_nw, h_ne, h_sw, h_se,
					clamped_height
				)

			var has_inner_corner: bool = (inner_offset != -1)

			for y: int in range(Constants.CHUNK_HEIGHT_VOXELS):
				var local_pos: Vector3i = Vector3i(x, y, z)

				if y > clamped_height + 1:
					# Air above ground and slopes
					chunk_data.set_block(local_pos, Constants.BLOCK_ID_AIR)
				elif y == clamped_height + 1:
					# Inner corner shim layer
					if has_inner_corner:
						var inner_id: int = _get_inner_corner_block_id(biome.surface_block_id, inner_offset)
						chunk_data.set_block(local_pos, inner_id)
					else:
						chunk_data.set_block(local_pos, Constants.BLOCK_ID_AIR)
				elif y == BEDROCK_LAYER_Y:
					# Indestructible bottom foundation
					chunk_data.set_block(local_pos, biome.bedrock_block_id)
				elif y == clamped_height:
					# Surface layer (flat cube, directional ramp, or outer corner)
					if has_inner_corner:
						# Solid foundation below inner corner shim
						chunk_data.set_block(local_pos, biome.subsurface_block_id)
					else:
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
