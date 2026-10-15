class_name TestLODAndOcclusion
extends RefCounted

const ConstantsScript = preload("res://core/constants.gd")
const BlockRegistryScript = preload("res://modules/world/data/block_registry.gd")
const BiomeDefinitionScript = preload("res://modules/world/data/biome_definition.gd")
const WorldGenConfigScript = preload("res://modules/world/data/world_gen_config.gd")
const TerrainGeneratorScript = preload("res://modules/world/generation/terrain_generator.gd")
const ChunkDataScript = preload("res://modules/world/chunk/chunk_data.gd")
const ChunkViewScript = preload("res://modules/world/chunk/chunk_view.gd")
const LODHeightmapMesherScript = preload("res://modules/world/chunk/lod_heightmap_mesher.gd")
const LODChunkViewScript = preload("res://modules/world/chunk/lod_chunk_view.gd")
const ChunkManagerScript = preload("res://modules/world/management/chunk_manager.gd")

static func run_all() -> bool:
	var all_passed: bool = true
	all_passed = test_lod_heightmap_mesher() and all_passed
	all_passed = test_subterranean_occlusion() and all_passed
	all_passed = test_chunk_manager_lod_and_occlusion() and all_passed
	return all_passed

static func test_lod_heightmap_mesher() -> bool:
	var registry = BlockRegistryScript.new()
	var biome = BiomeDefinitionScript.new()
	var config = WorldGenConfigScript.new()
	var generator = TerrainGeneratorScript.new(config)

	var col = Vector2i(10, 10)
	var mesh: ArrayMesh = LODHeightmapMesherScript.build_column_lod_mesh(col, generator, biome, registry, 2)

	if mesh == null:
		printerr("FAIL: LODHeightmapMesher returned null mesh")
		return false

	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	# Step 2 across 16 voxels = 9x9 top surface (81) + 32 skirt quads (128) = 209 vertices
	if vertices.size() != 209:
		printerr("FAIL: Expected 209 vertices (surface + skirts) for step 2, got: ", vertices.size())
		return false

	if normals.size() != 209:
		printerr("FAIL: Normals buffer mismatch, got: ", normals.size())
		return false

	if colors.size() != 209:
		printerr("FAIL: Colors buffer mismatch, got: ", colors.size())
		return false

	# 8x8 quads * 6 indices (384) + 32 skirt quads * 6 indices (192) = 576 indices
	if indices.size() != 576:
		printerr("FAIL: Expected 576 indices (surface + skirts), got: ", indices.size())
		return false

	var material: StandardMaterial3D = mesh.surface_get_material(0) as StandardMaterial3D
	if material == null or not material.vertex_color_use_as_albedo:
		printerr("FAIL: Expected StandardMaterial3D with vertex_color_use_as_albedo")
		return false

	return true

static func test_subterranean_occlusion() -> bool:
	var chunk_data = ChunkDataScript.new(Vector3i(0, -1, 0))
	var config = WorldGenConfigScript.new()
	var generator = TerrainGeneratorScript.new(config)

	generator.generate_surface_shell(chunk_data)

	# Sub-chunk below y=0 must be classified as subterranean
	if not chunk_data.is_subterranean:
		printerr("FAIL: Sub-chunk below ground should be classified as is_subterranean")
		return false

	var view = ChunkViewScript.new(chunk_data.chunk_coord)
	view.is_subterranean = chunk_data.is_subterranean

	# Occluded view should become invisible
	view.set_occluded(true)
	if view.visible:
		printerr("FAIL: Subterranean view should be invisible when occluded")
		view.free()
		return false

	# Unoccluded view should become visible
	view.set_occluded(false)
	if not view.visible:
		printerr("FAIL: Subterranean view should be visible when unoccluded")
		view.free()
		return false

	view.free()
	return true

static func test_chunk_manager_lod_and_occlusion() -> bool:
	var config = WorldGenConfigScript.new()
	config.load_radius_chunks = 2
	config.lod_radius_chunks = 4
	config.enable_lod = false
	config.enable_cave_occlusion = true

	var manager = ChunkManagerScript.new()
	manager.config = config
	manager._ready()

	# Enable LOD and synchronously populate LOD columns around origin
	config.enable_lod = true
	manager.update_lod_around_col(Vector2i.ZERO, true)

	var lod_count: int = manager.get_lod_chunk_count()
	if lod_count == 0:
		printerr("FAIL: Expected distant LOD chunks to be created, got 0")
		manager.cleanup()
		manager.free()
		return false

	# Test player altitude subterranean detection
	var ground_h: int = manager.generator.get_terrain_height_at(0, 0)
	var surface_pos = Vector3(0.0, float(ground_h + 5), 0.0) # Strictly above surface
	manager._on_player_position_updated(surface_pos)
	if manager.is_player_underground():
		printerr("FAIL: Player at Y=%d should not be considered underground (ground_h=%d)" % [ground_h + 5, ground_h])
		manager.cleanup()
		manager.free()
		return false

	var underground_pos = Vector3(0.0, float(maxi(0, ground_h - 5)), 0.0) # Strictly below surface
	manager._on_player_position_updated(underground_pos)
	if not manager.is_player_underground():
		printerr("FAIL: Player at Y=%d should be detected as underground (ground_h=%d)" % [ground_h - 5, ground_h])
		manager.cleanup()
		manager.free()
		return false

	# Test distant player movement unloading old 3D chunks and avoiding orphan floating islands
	var distant_pos = Vector3(160.0, float(ground_h + 5), 160.0) # Chunk (10, 0, 10)
	manager._on_player_position_updated(distant_pos)

	var origin_has_3d: bool = false
	for y: int in range(config.min_chunk_y, config.max_chunk_y + 1):
		if manager._chunk_view_map.has(Vector3i(0, y, 0)):
			origin_has_3d = true
			break
	if origin_has_3d:
		printerr("FAIL: Chunks at origin should have been unloaded after player moved away")
		manager.cleanup()
		manager.free()
		return false

	manager.cleanup()
	manager.free()
	return true

