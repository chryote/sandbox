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
	var max_y: int = Constants.WORLD_MAX_HEIGHT_VOXELS - 1
	return clampi(target_height, BEDROCK_LAYER_Y, max_y)

## Checks whether the cell at (cell_x, cell_z) resolves to a straight directional ramp
## whose downhill slope points in target_drop direction (0=North, 1=South, 2=East, 3=West).
func _is_cell_ramp_facing(cell_x: int, cell_z: int, target_drop: int) -> bool:
	var h_cell: int = get_terrain_height_at(cell_x, cell_z)
	var dn: int = get_terrain_height_at(cell_x, cell_z - 1) - h_cell
	var ds: int = get_terrain_height_at(cell_x, cell_z + 1) - h_cell
	var de: int = get_terrain_height_at(cell_x + 1, cell_z) - h_cell
	var dw: int = get_terrain_height_at(cell_x - 1, cell_z) - h_cell

	# Conflicting opposite drops (ridge or peak): full cube, not a ramp
	if (dn == -1 and ds == -1) or (de == -1 and dw == -1):
		return false

	var drop_count: int = 0
	var single_drop: int = -1
	if dn == -1:
		drop_count += 1
		single_drop = 0
	if ds == -1:
		drop_count += 1
		single_drop = 1
	if de == -1:
		drop_count += 1
		single_drop = 2
	if dw == -1:
		drop_count += 1
		single_drop = 3

	return drop_count == 1 and single_drop == target_drop

## Resolves whether an empty voxel at clamped_height + 1 is an inside corner bridging two higher terrace walls.
## Suppresses inner corner placement if an adjacent higher neighbor contains a straight ramp sloping into this cell,
## preventing the ramp's lowest edge from being blocked by the inner corner's back wall.
func _resolve_inner_corner_offset(
	diff_n: int, diff_s: int, diff_e: int, diff_w: int,
	h_nw: int, h_ne: int, h_sw: int, h_se: int,
	clamped_height: int,
	world_x: int = 0, world_z: int = 0
) -> int:
	var h: int = clamped_height
	# NW low (South & East higher)
	if diff_s >= 1 and diff_e >= 1 and h_se >= h + 1 and diff_n <= 0 and diff_w <= 0:
		if _is_cell_ramp_facing(world_x, world_z + 1, 0) or _is_cell_ramp_facing(world_x + 1, world_z, 3):
			return -1
		return 0 # INNER_CORNER_NORTH_WEST
	# NE low (South & West higher)
	if diff_s >= 1 and diff_w >= 1 and h_sw >= h + 1 and diff_n <= 0 and diff_e <= 0:
		if _is_cell_ramp_facing(world_x, world_z + 1, 0) or _is_cell_ramp_facing(world_x - 1, world_z, 2):
			return -1
		return 1 # INNER_CORNER_NORTH_EAST
	# SW low (North & East higher)
	if diff_n >= 1 and diff_e >= 1 and h_ne >= h + 1 and diff_s <= 0 and diff_w <= 0:
		if _is_cell_ramp_facing(world_x, world_z - 1, 1) or _is_cell_ramp_facing(world_x + 1, world_z, 3):
			return -1
		return 2 # INNER_CORNER_SOUTH_WEST
	# SE low (North & West higher)
	if diff_n >= 1 and diff_w >= 1 and h_nw >= h + 1 and diff_s <= 0 and diff_e <= 0:
		if _is_cell_ramp_facing(world_x, world_z - 1, 1) or _is_cell_ramp_facing(world_x - 1, world_z, 2):
			return -1
		return 3 # INNER_CORNER_SOUTH_EAST

	return -1

## Checks whether the cell at (cell_x, cell_z) contains solid geometry or a slope shim at target_y.
func _cell_has_slope_or_wall_at(cell_x: int, cell_z: int, target_y: int) -> bool:
	var h_cell: int = get_terrain_height_at(cell_x, cell_z)
	if h_cell >= target_y:
		return true
	if h_cell == target_y - 1:
		var dn: int = get_terrain_height_at(cell_x, cell_z - 1) - h_cell
		var ds: int = get_terrain_height_at(cell_x, cell_z + 1) - h_cell
		var de: int = get_terrain_height_at(cell_x + 1, cell_z) - h_cell
		var dw: int = get_terrain_height_at(cell_x - 1, cell_z) - h_cell
		var h_nw: int = get_terrain_height_at(cell_x - 1, cell_z - 1)
		var h_ne: int = get_terrain_height_at(cell_x + 1, cell_z - 1)
		var h_sw: int = get_terrain_height_at(cell_x - 1, cell_z + 1)
		var h_se: int = get_terrain_height_at(cell_x + 1, cell_z + 1)
		if _resolve_inner_corner_offset(dn, ds, de, dw, h_nw, h_ne, h_sw, h_se, h_cell, cell_x, cell_z) != -1:
			return true
	return false

## Resolves whether an empty voxel at clamped_height + 1 is an outer convex corner bridging between two inner corners
## or adjacent diagonal elevation step. Clears any outer corner that does not have a supporting neighbor on both of its side faces.
func _resolve_outer_corner_offset(
	diff_n: int, diff_s: int, diff_e: int, diff_w: int,
	h_nw: int, h_ne: int, h_sw: int, h_se: int,
	clamped_height: int,
	world_x: int = 0, world_z: int = 0
) -> int:
	var h: int = clamped_height
	var target_y: int = h + 1

	# SE high (high point at SE, slopes down towards NW)
	# Both South (z+1) and East (x+1) side faces must have a neighbor at target_y
	if h_se >= h + 1 and diff_s == 0 and diff_e == 0 and diff_n <= 0 and diff_w <= 0:
		if _cell_has_slope_or_wall_at(world_x, world_z + 1, target_y) and _cell_has_slope_or_wall_at(world_x + 1, world_z, target_y):
			return 3 # OUTER_CORNER_SOUTH_EAST

	# SW high (high point at SW, slopes down towards NE)
	# Both South (z+1) and West (x-1) side faces must have a neighbor at target_y
	if h_sw >= h + 1 and diff_s == 0 and diff_w == 0 and diff_n <= 0 and diff_e <= 0:
		if _cell_has_slope_or_wall_at(world_x, world_z + 1, target_y) and _cell_has_slope_or_wall_at(world_x - 1, world_z, target_y):
			return 2 # OUTER_CORNER_SOUTH_WEST

	# NE high (high point at NE, slopes down towards SW)
	# Both North (z-1) and East (x+1) side faces must have a neighbor at target_y
	if h_ne >= h + 1 and diff_n == 0 and diff_e == 0 and diff_s <= 0 and diff_w <= 0:
		if _cell_has_slope_or_wall_at(world_x, world_z - 1, target_y) and _cell_has_slope_or_wall_at(world_x + 1, world_z, target_y):
			return 1 # OUTER_CORNER_NORTH_EAST

	# NW high (high point at NW, slopes down towards SE)
	# Both North (z-1) and West (x-1) side faces must have a neighbor at target_y
	if h_nw >= h + 1 and diff_n == 0 and diff_w == 0 and diff_s <= 0 and diff_e <= 0:
		if _cell_has_slope_or_wall_at(world_x, world_z - 1, target_y) and _cell_has_slope_or_wall_at(world_x - 1, world_z, target_y):
			return 0 # OUTER_CORNER_NORTH_WEST

	return -1

## Resolves the registered block ID for an outer corner shape given the surface base material.
func _get_outer_corner_block_id(surface_base_id: int, corner_offset: int) -> int:
	match surface_base_id:
		Constants.BLOCK_ID_GRASS:
			return Constants.BLOCK_ID_GRASS_OUTER_CORNER_NW + corner_offset
		Constants.BLOCK_ID_SAND:
			return Constants.BLOCK_ID_SAND_OUTER_CORNER_NW + corner_offset
		Constants.BLOCK_ID_STONE:
			return Constants.BLOCK_ID_STONE_OUTER_CORNER_NW + corner_offset
		Constants.BLOCK_ID_DIRT:
			return Constants.BLOCK_ID_DIRT_OUTER_CORNER_NW + corner_offset
		_:
			return surface_base_id

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
	return surface_base_id

## Generates only the visible surface layer and its immediate foundation floor for a 16x16x16 sub-chunk.
## Utilizes an O(1) envelope pre-pass to skip 100% air or 100% stone chunks instantly.
func generate_surface_shell(chunk_data: ChunkData) -> void:
	var biome: BiomeDefinition = config.primary_biome
	var chunk_origin_x: int = chunk_data.chunk_coord.x * Constants.CHUNK_WIDTH_VOXELS
	var chunk_origin_y: int = chunk_data.chunk_coord.y * Constants.CHUNK_HEIGHT_VOXELS
	var chunk_origin_z: int = chunk_data.chunk_coord.z * Constants.CHUNK_DEPTH_VOXELS
	var chunk_max_y: int = chunk_origin_y + Constants.CHUNK_HEIGHT_VOXELS - 1

	# O(1) Envelope Pre-pass: Sample 5 points (4 corners + center) across chunk column footprint
	var h00: int = get_terrain_height_at(chunk_origin_x, chunk_origin_z)
	var h10: int = get_terrain_height_at(chunk_origin_x + Constants.CHUNK_WIDTH_VOXELS - 1, chunk_origin_z)
	var h01: int = get_terrain_height_at(chunk_origin_x, chunk_origin_z + Constants.CHUNK_DEPTH_VOXELS - 1)
	var h11: int = get_terrain_height_at(chunk_origin_x + Constants.CHUNK_WIDTH_VOXELS - 1, chunk_origin_z + Constants.CHUNK_DEPTH_VOXELS - 1)
	var h_mid: int = get_terrain_height_at(chunk_origin_x + (Constants.CHUNK_WIDTH_VOXELS / 2), chunk_origin_z + (Constants.CHUNK_DEPTH_VOXELS / 2))

	var min_h: int = mini(mini(h00, h10), mini(h01, mini(h11, h_mid)))
	var max_h: int = maxi(maxi(h00, h10), maxi(h01, maxi(h11, h_mid)))

	# Detect subterranean sub-chunk (entirely below ground surface and sealed on all sides)
	if chunk_max_y >= min_h:
		chunk_data.is_subterranean = false
	else:
		# Check if any adjacent neighbor drops below chunk_max_y, exposing side faces to air
		var is_sealed: bool = true
		var neighbor_sample_offsets: Array[Vector2i] = [
			# Immediate border points along each cardinal side
			Vector2i(-1, 0), Vector2i(-1, Constants.CHUNK_DEPTH_VOXELS / 2), Vector2i(-1, Constants.CHUNK_DEPTH_VOXELS - 1),
			Vector2i(Constants.CHUNK_WIDTH_VOXELS, 0), Vector2i(Constants.CHUNK_WIDTH_VOXELS, Constants.CHUNK_DEPTH_VOXELS / 2), Vector2i(Constants.CHUNK_WIDTH_VOXELS, Constants.CHUNK_DEPTH_VOXELS - 1),
			Vector2i(0, -1), Vector2i(Constants.CHUNK_WIDTH_VOXELS / 2, -1), Vector2i(Constants.CHUNK_WIDTH_VOXELS - 1, -1),
			Vector2i(0, Constants.CHUNK_DEPTH_VOXELS), Vector2i(Constants.CHUNK_WIDTH_VOXELS / 2, Constants.CHUNK_DEPTH_VOXELS), Vector2i(Constants.CHUNK_WIDTH_VOXELS - 1, Constants.CHUNK_DEPTH_VOXELS),
			# Surrounding neighbor chunk centers
			Vector2i(-Constants.CHUNK_WIDTH_VOXELS / 2, Constants.CHUNK_DEPTH_VOXELS / 2),
			Vector2i(Constants.CHUNK_WIDTH_VOXELS + Constants.CHUNK_WIDTH_VOXELS / 2, Constants.CHUNK_DEPTH_VOXELS / 2),
			Vector2i(Constants.CHUNK_WIDTH_VOXELS / 2, -Constants.CHUNK_DEPTH_VOXELS / 2),
			Vector2i(Constants.CHUNK_WIDTH_VOXELS / 2, Constants.CHUNK_DEPTH_VOXELS + Constants.CHUNK_DEPTH_VOXELS / 2)
		]
		for offset: Vector2i in neighbor_sample_offsets:
			if get_terrain_height_at(chunk_origin_x + offset.x, chunk_origin_z + offset.y) <= chunk_max_y:
				is_sealed = false
				break
		chunk_data.is_subterranean = is_sealed

	# 1. Sky Chunk (100% Air): entire sub-chunk is above terrain surface and shims
	if chunk_origin_y > max_h + 1:
		chunk_data.set_homogeneous(Constants.BLOCK_ID_AIR)
		chunk_data.gen_state = ChunkData.GenState.FULL
		return

	# 2. Deep Solid Stone (100% Stone): entire sub-chunk is sealed, below dirt layer and above bedrock
	if chunk_data.is_subterranean and chunk_max_y < (min_h - biome.subsurface_depth_layers) and chunk_origin_y > BEDROCK_LAYER_Y:
		chunk_data.set_homogeneous(biome.deep_block_id)
		chunk_data.gen_state = ChunkData.GenState.FULL
		return

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

			# Sample diagonal neighbor heights for corner detection
			var h_nw: int = get_terrain_height_at(world_x - 1, world_z - 1)
			var h_ne: int = get_terrain_height_at(world_x + 1, world_z - 1)
			var h_sw: int = get_terrain_height_at(world_x - 1, world_z + 1)
			var h_se: int = get_terrain_height_at(world_x + 1, world_z + 1)

			var inner_offset: int = -1
			var outer_offset: int = -1
			var shim_world_y: int = clamped_height + 1

			inner_offset = _resolve_inner_corner_offset(
				diff_n, diff_s, diff_e, diff_w,
				h_nw, h_ne, h_sw, h_se,
				clamped_height,
				world_x, world_z
			)
			if inner_offset == -1:
				outer_offset = _resolve_outer_corner_offset(
					diff_n, diff_s, diff_e, diff_w,
					h_nw, h_ne, h_sw, h_se,
					clamped_height,
					world_x, world_z
				)

			var has_inner_corner: bool = (inner_offset != -1)
			var has_outer_corner: bool = (outer_offset != -1)

			# 1. Corner shim layer at clamped_height + 1
			if shim_world_y >= chunk_origin_y and shim_world_y <= chunk_max_y:
				var local_shim_y: int = shim_world_y - chunk_origin_y
				var shim_pos: Vector3i = Vector3i(x, local_shim_y, z)
				if has_inner_corner:
					var inner_id: int = _get_inner_corner_block_id(biome.surface_block_id, inner_offset)
					chunk_data.set_block(shim_pos, inner_id)
				elif has_outer_corner:
					var outer_id: int = _get_outer_corner_block_id(biome.surface_block_id, outer_offset)
					chunk_data.set_block(shim_pos, outer_id)

			# 2. Surface layer at clamped_height
			var surf_world_y: int = clamped_height
			if surf_world_y >= chunk_origin_y and surf_world_y <= chunk_max_y:
				var local_surf_y: int = surf_world_y - chunk_origin_y
				var surf_pos: Vector3i = Vector3i(x, local_surf_y, z)
				if clamped_height == BEDROCK_LAYER_Y:
					chunk_data.set_block(surf_pos, biome.bedrock_block_id)
				elif has_inner_corner or has_outer_corner:
					chunk_data.set_block(surf_pos, biome.subsurface_block_id)
				else:
					var surface_block_id: int = _resolve_surface_block_id(
						biome.surface_block_id,
						diff_n, diff_s, diff_e, diff_w,
						world_x, world_z
					)
					chunk_data.set_block(surf_pos, surface_block_id)

			# 3. Solid foundation floor layer directly below surface (at clamped_height - 1)
			var under_world_y: int = clamped_height - 1
			if under_world_y >= BEDROCK_LAYER_Y and under_world_y >= chunk_origin_y and under_world_y <= chunk_max_y:
				var local_floor_y: int = under_world_y - chunk_origin_y
				var floor_pos: Vector3i = Vector3i(x, local_floor_y, z)
				if under_world_y == BEDROCK_LAYER_Y:
					chunk_data.set_block(floor_pos, biome.bedrock_block_id)
				else:
					chunk_data.set_block(floor_pos, biome.subsurface_block_id)

	chunk_data.gen_state = ChunkData.GenState.SURFACE_ONLY

## Fills remaining subterranean block layers (deep stone, dirt, bedrock) beneath the surface foundation.
func fill_subsurface(chunk_data: ChunkData) -> void:
	if chunk_data.is_homogeneous():
		chunk_data.gen_state = ChunkData.GenState.FULL
		return

	var biome: BiomeDefinition = config.primary_biome
	var chunk_origin_x: int = chunk_data.chunk_coord.x * Constants.CHUNK_WIDTH_VOXELS
	var chunk_origin_y: int = chunk_data.chunk_coord.y * Constants.CHUNK_HEIGHT_VOXELS
	var chunk_origin_z: int = chunk_data.chunk_coord.z * Constants.CHUNK_DEPTH_VOXELS
	var chunk_max_y: int = chunk_origin_y + Constants.CHUNK_HEIGHT_VOXELS - 1

	for z: int in range(Constants.CHUNK_DEPTH_VOXELS):
		var world_z: int = chunk_origin_z + z

		for x: int in range(Constants.CHUNK_WIDTH_VOXELS):
			var world_x: int = chunk_origin_x + x
			var clamped_height: int = get_terrain_height_at(world_x, world_z)

			# Fill from max(BEDROCK_LAYER_Y, chunk_origin_y) up to min(clamped_height - 2, chunk_max_y)
			var start_world_y: int = maxi(BEDROCK_LAYER_Y, chunk_origin_y)
			var end_world_y: int = mini(clamped_height - 2, chunk_max_y)

			for world_y: int in range(start_world_y, end_world_y + 1):
				var local_y: int = world_y - chunk_origin_y
				var local_pos: Vector3i = Vector3i(x, local_y, z)
				if world_y == BEDROCK_LAYER_Y:
					chunk_data.set_block(local_pos, biome.bedrock_block_id)
				elif world_y > (clamped_height - biome.subsurface_depth_layers):
					chunk_data.set_block(local_pos, biome.subsurface_block_id)
				else:
					chunk_data.set_block(local_pos, biome.deep_block_id)

	chunk_data.gen_state = ChunkData.GenState.FULL

## Fills a ChunkData buffer completely with both surface shell and subterranean layers.
func generate_chunk_data(chunk_data: ChunkData) -> void:
	generate_surface_shell(chunk_data)
	fill_subsurface(chunk_data)
