class_name TestRampBlocks
extends RefCounted

const ConstantsScript = preload("res://core/constants.gd")
const BlockRegistryScript = preload("res://modules/world/data/block_registry.gd")
const BlockDefinitionScript = preload("res://modules/world/data/block_definition.gd")
const ChunkDataScript = preload("res://modules/world/chunk/chunk_data.gd")
const ChunkMesherScript = preload("res://modules/world/chunk/chunk_mesher.gd")

static func run_all() -> bool:
	var registry = BlockRegistryScript.new()

	# 1. Test Ramp Block Registration
	var grass_ramp_n = registry.get_block(ConstantsScript.BLOCK_ID_GRASS_RAMP_NORTH)
	if grass_ramp_n.id != ConstantsScript.BLOCK_ID_GRASS_RAMP_NORTH:
		printerr("FAIL: Grass Ramp North not registered properly")
		return false

	if not grass_ramp_n.is_solid:
		printerr("FAIL: Grass Ramp North must be solid")
		return false

	if not grass_ramp_n.is_ramp:
		printerr("FAIL: Grass Ramp North must report is_ramp == true")
		return false

	if registry.is_full_cube(ConstantsScript.BLOCK_ID_GRASS_RAMP_NORTH):
		printerr("FAIL: Grass Ramp North must NOT be a full cube")
		return false

	# 2. Test Occlusion Logic
	# A neighbor directly below looking up (+Y) should be occluded by ramp bottom
	if not registry.is_face_occluded_by(ConstantsScript.BLOCK_ID_GRASS_RAMP_NORTH, ConstantsScript.CubeFace.TOP):
		printerr("FAIL: Face looking up into ramp bottom must be occluded")
		return false

	# A neighbor at South (+Z) looking North (-Z) into RAMP_NORTH back wall should be occluded
	if not registry.is_face_occluded_by(ConstantsScript.BLOCK_ID_GRASS_RAMP_NORTH, ConstantsScript.CubeFace.NORTH):
		printerr("FAIL: Face looking into RAMP_NORTH back wall must be occluded")
		return false

	# A neighbor at North (-Z) looking South (+Z) should NOT be occluded
	if registry.is_face_occluded_by(ConstantsScript.BLOCK_ID_GRASS_RAMP_NORTH, ConstantsScript.CubeFace.SOUTH):
		printerr("FAIL: Face facing the slope must NOT be occluded")
		return false

	# 3. Test Meshing of Isolated Ramp
	var chunk = ChunkDataScript.new(Vector3i.ZERO)
	var ramp_pos: Vector3i = Vector3i(4, 5, 4)
	chunk.set_block(ramp_pos, ConstantsScript.BLOCK_ID_GRASS_RAMP_NORTH)

	var mesh: ArrayMesh = ChunkMesherScript.build_chunk_mesh(chunk, registry)
	if mesh == null:
		printerr("FAIL: Mesher returned null for chunk with ramp")
		return false

	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	# Isolated ramp in air: 4 verts (slope) + 4 verts (bottom) + 4 verts (back) + 3 (side1) + 3 (side2) = 18 vertices
	if verts.size() != 18:
		printerr("FAIL: Isolated ramp should have 18 vertices, got: %d" % verts.size())
		return false

	# 8 triangles * 3 = 24 indices
	if indices.size() != 24:
		printerr("FAIL: Isolated ramp should have 24 indices, got: %d" % indices.size())
		return false

	# 4. Test Meshing with Bottom Culling
	# Adding a solid stone block underneath should cull the bottom face (4 vertices, 6 indices less)
	chunk.set_block(Vector3i(4, 4, 4), ConstantsScript.BLOCK_ID_STONE)
	var mesh_culled: ArrayMesh = ChunkMesherScript.build_chunk_mesh(chunk, registry)
	var arrays_culled: Array = mesh_culled.surface_get_arrays(0)
	var verts_culled: PackedVector3Array = arrays_culled[Mesh.ARRAY_VERTEX]

	# Stone block: 5 exposed faces (top is touching ramp bottom -> occluded!) = 5 * 4 = 20 verts
	# Ramp block: 18 - 4 (bottom culled) = 14 verts
	# Total: 34 verts
	if verts_culled.size() != 34:
		printerr("FAIL: Expected 34 vertices for ramp on stone block, got: %d" % verts_culled.size())
		return false

	# 5. Test Ramp Triangle Front-Facing Orientation
	# For all 4 ramp orientations, verify that (V2 - V0) x (V1 - V0) opposes the normal (matching Godot's clockwise winding convention)
	for shape in [ConstantsScript.BlockShape.RAMP_NORTH, ConstantsScript.BlockShape.RAMP_SOUTH, ConstantsScript.BlockShape.RAMP_EAST, ConstantsScript.BlockShape.RAMP_WEST]:
		var quad_v: Array = ConstantsScript.RAMP_SLOPE_QUAD_VERTICES[shape]
		var expected_n: Vector3 = ConstantsScript.RAMP_SLOPE_NORMALS[shape]
		var cross_prod: Vector3 = (quad_v[2] - quad_v[0]).cross(quad_v[1] - quad_v[0]).normalized()
		if not cross_prod.is_equal_approx(-expected_n):
			printerr("FAIL: Ramp slope quad winding inverted for shape: %d" % shape)
			return false

	return true
