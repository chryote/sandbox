class_name ChunkMesher
extends RefCounted

## -----------------------------------------------------------------------------
## Named Constants
## -----------------------------------------------------------------------------
const EMPTY_VERTEX_COUNT: int = 0

## -----------------------------------------------------------------------------
## Core Meshing Pipeline
## -----------------------------------------------------------------------------
## Builds an ArrayMesh for a given ChunkData using directional face culling.
## [param chunk_data]: The voxel data for the chunk to mesh.
## [param registry]: Block registry used to resolve block properties and colors.
## [param neighbor_query_callable]: Optional Callable(world_voxel_pos: Vector3i) -> bool
##                                  that returns true if the adjacent voxel in a neighboring chunk is transparent.
static func build_chunk_mesh(
	chunk_data: ChunkData,
	registry: BlockRegistry,
	neighbor_query_callable: Callable = Callable()
) -> ArrayMesh:
	if chunk_data == null or chunk_data.is_empty():
		return null

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()

	var chunk_origin_voxel: Vector3i = Vector3i(
		chunk_data.chunk_coord.x * Constants.CHUNK_WIDTH_VOXELS,
		chunk_data.chunk_coord.y * Constants.CHUNK_HEIGHT_VOXELS,
		chunk_data.chunk_coord.z * Constants.CHUNK_DEPTH_VOXELS
	)

	var vertex_counter: int = 0

	for z: int in range(Constants.CHUNK_DEPTH_VOXELS):
		for y: int in range(Constants.CHUNK_HEIGHT_VOXELS):
			for x: int in range(Constants.CHUNK_WIDTH_VOXELS):
				var local_pos: Vector3i = Vector3i(x, y, z)
				var block_id: int = chunk_data.get_block(local_pos)

				if block_id == Constants.BLOCK_ID_AIR:
					continue

				var block_def: BlockDefinition = registry.get_block(block_id)
				var block_base_pos: Vector3 = Vector3(
					float(x) * Constants.VOXEL_SIZE_METERS,
					float(y) * Constants.VOXEL_SIZE_METERS,
					float(z) * Constants.VOXEL_SIZE_METERS
				)

				if block_def.shape == Constants.BlockShape.CUBE:
					vertex_counter = _mesh_cube_block(
						local_pos, block_def, block_base_pos,
						chunk_data, registry, chunk_origin_voxel, neighbor_query_callable,
						vertices, normals, uvs, colors, indices, vertex_counter
					)
				elif block_def.is_inner_corner:
					vertex_counter = _mesh_inner_corner_block(
						local_pos, block_def, block_base_pos,
						chunk_data, registry, chunk_origin_voxel, neighbor_query_callable,
						vertices, normals, uvs, colors, indices, vertex_counter
					)
				elif block_def.is_outer_corner:
					vertex_counter = _mesh_outer_corner_block(
						local_pos, block_def, block_base_pos,
						chunk_data, registry, chunk_origin_voxel, neighbor_query_callable,
						vertices, normals, uvs, colors, indices, vertex_counter
					)
				else:
					vertex_counter = _mesh_ramp_block(
						local_pos, block_def, block_base_pos,
						chunk_data, registry, chunk_origin_voxel, neighbor_query_callable,
						vertices, normals, uvs, colors, indices, vertex_counter
					)

	if vertices.size() == EMPTY_VERTEX_COUNT:
		return null

	var mesh_arrays: Array = []
	mesh_arrays.resize(Mesh.ARRAY_MAX)
	mesh_arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh_arrays[Mesh.ARRAY_NORMAL] = normals
	mesh_arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh_arrays[Mesh.ARRAY_COLOR] = colors
	mesh_arrays[Mesh.ARRAY_INDEX] = indices

	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)

	# Configure base vertex-colored material with PBR shading
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.8
	material.metallic = 0.0
	mesh.surface_set_material(0, material)

	return mesh

## Resolves the block ID of an adjacent voxel, querying the neighbor callable across chunk boundaries if needed.
static func _get_neighbor_block_id(
	chunk_data: ChunkData,
	local_pos: Vector3i,
	offset: Vector3i,
	chunk_origin_voxel: Vector3i,
	neighbor_query_callable: Callable
) -> int:
	var neighbor_local_pos: Vector3i = local_pos + offset
	if VoxelCoordinates.is_local_coord_valid(neighbor_local_pos):
		return chunk_data.get_block(neighbor_local_pos)

	if neighbor_query_callable.is_valid():
		var neighbor_world_voxel: Vector3i = chunk_origin_voxel + neighbor_local_pos
		var res: Variant = neighbor_query_callable.call(neighbor_world_voxel)
		if typeof(res) == TYPE_INT:
			return res
		elif typeof(res) == TYPE_BOOL:
			return Constants.BLOCK_ID_AIR if res else Constants.BLOCK_ID_STONE

	return Constants.BLOCK_ID_AIR

## Emits vertices, normals, uvs, and indices for a standard 6-faced cubic voxel.
static func _mesh_cube_block(
	local_pos: Vector3i,
	block_def: BlockDefinition,
	block_base_pos: Vector3,
	chunk_data: ChunkData,
	registry: BlockRegistry,
	chunk_origin_voxel: Vector3i,
	neighbor_query_callable: Callable,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	vertex_counter: int
) -> int:
	for face_idx: int in range(Constants.TOTAL_CUBE_FACES):
		var face_enum: Constants.CubeFace = face_idx as Constants.CubeFace
		var neighbor_offset: Vector3i = Constants.FACE_NEIGHBOR_OFFSETS[face_idx]
		var neighbor_id: int = _get_neighbor_block_id(
			chunk_data, local_pos, neighbor_offset, chunk_origin_voxel, neighbor_query_callable
		)

		if registry.is_face_occluded_by(neighbor_id, face_enum):
			continue

		var normal_vec: Vector3 = Constants.FACE_NORMALS[face_idx]
		var face_color: Color = block_def.get_face_color(face_enum)
		var quad_verts: Array = Constants.FACE_QUAD_VERTICES[face_idx]

		for v_idx: int in range(Constants.VERTICES_PER_QUAD):
			var vert_offset: Vector3 = quad_verts[v_idx] * Constants.VOXEL_SIZE_METERS
			vertices.append(block_base_pos + vert_offset)
			normals.append(normal_vec)
			uvs.append(Constants.QUAD_UVS[v_idx])
			colors.append(face_color)

		for idx_offset: int in Constants.QUAD_INDEX_OFFSETS:
			indices.append(vertex_counter + idx_offset)

		vertex_counter += Constants.VERTICES_PER_QUAD

	return vertex_counter

## Emits geometry for a 45-degree directional ramp (sloped top face, bottom, back wall, and 2 side triangles).
static func _mesh_ramp_block(
	local_pos: Vector3i,
	block_def: BlockDefinition,
	block_base_pos: Vector3,
	chunk_data: ChunkData,
	registry: BlockRegistry,
	chunk_origin_voxel: Vector3i,
	neighbor_query_callable: Callable,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	vertex_counter: int
) -> int:
	var shape: Constants.BlockShape = block_def.shape

	# 1. Sloped Top Face (45-degree quad)
	var slope_normal: Vector3 = Constants.RAMP_SLOPE_NORMALS[shape]
	var slope_verts: Array = Constants.RAMP_SLOPE_QUAD_VERTICES[shape]
	var slope_color: Color = block_def.top_color

	for v_idx: int in range(Constants.VERTICES_PER_QUAD):
		var vert_offset: Vector3 = slope_verts[v_idx] * Constants.VOXEL_SIZE_METERS
		vertices.append(block_base_pos + vert_offset)
		normals.append(slope_normal)
		uvs.append(Constants.QUAD_UVS[v_idx])
		colors.append(slope_color)

	for idx_offset: int in Constants.QUAD_INDEX_OFFSETS:
		indices.append(vertex_counter + idx_offset)

	vertex_counter += Constants.VERTICES_PER_QUAD

	# 2. Bottom Face (culled if bottom neighbor is full solid cube)
	var bottom_id: int = _get_neighbor_block_id(
		chunk_data, local_pos, Vector3i(0, -1, 0), chunk_origin_voxel, neighbor_query_callable
	)
	if not registry.is_full_cube(bottom_id):
		var bottom_verts: Array = Constants.FACE_QUAD_VERTICES[Constants.CubeFace.BOTTOM]
		var bottom_normal: Vector3 = Constants.FACE_NORMALS[Constants.CubeFace.BOTTOM]
		var bottom_color: Color = block_def.bottom_color

		for v_idx: int in range(Constants.VERTICES_PER_QUAD):
			var vert_offset: Vector3 = bottom_verts[v_idx] * Constants.VOXEL_SIZE_METERS
			vertices.append(block_base_pos + vert_offset)
			normals.append(bottom_normal)
			uvs.append(Constants.QUAD_UVS[v_idx])
			colors.append(bottom_color)

		for idx_offset: int in Constants.QUAD_INDEX_OFFSETS:
			indices.append(vertex_counter + idx_offset)

		vertex_counter += Constants.VERTICES_PER_QUAD

	# 3. Back Wall Face (full vertical quad on the high side)
	var back_face: Constants.CubeFace = Constants.RAMP_BACK_WALL_FACES[shape]
	var back_offset: Vector3i = Constants.FACE_NEIGHBOR_OFFSETS[back_face]
	var back_id: int = _get_neighbor_block_id(
		chunk_data, local_pos, back_offset, chunk_origin_voxel, neighbor_query_callable
	)
	if not registry.is_full_cube(back_id):
		var back_verts: Array = Constants.FACE_QUAD_VERTICES[back_face]
		var back_normal: Vector3 = Constants.FACE_NORMALS[back_face]
		var back_color: Color = block_def.side_color

		for v_idx: int in range(Constants.VERTICES_PER_QUAD):
			var vert_offset: Vector3 = back_verts[v_idx] * Constants.VOXEL_SIZE_METERS
			vertices.append(block_base_pos + vert_offset)
			normals.append(back_normal)
			uvs.append(Constants.QUAD_UVS[v_idx])
			colors.append(back_color)

		for idx_offset: int in Constants.QUAD_INDEX_OFFSETS:
			indices.append(vertex_counter + idx_offset)

		vertex_counter += Constants.VERTICES_PER_QUAD

	# 4. Side Triangles (2 triangles per ramp)
	var side_triangles: Array = Constants.RAMP_SIDE_TRIANGLES[shape]
	for side_data: Dictionary in side_triangles:
		var side_offset: Vector3i = side_data["neighbor_offset"]
		var side_id: int = _get_neighbor_block_id(
			chunk_data, local_pos, side_offset, chunk_origin_voxel, neighbor_query_callable
		)
		if registry.is_full_cube(side_id):
			continue

		var tri_normal: Vector3 = side_data["normal"]
		var tri_verts: Array = side_data["vertices"]
		var side_color: Color = block_def.side_color

		for v_idx: int in range(Constants.VERTICES_PER_TRIANGLE):
			var vert_offset: Vector3 = tri_verts[v_idx] * Constants.VOXEL_SIZE_METERS
			vertices.append(block_base_pos + vert_offset)
			normals.append(tri_normal)
			uvs.append(Constants.TRI_UVS[v_idx])
			colors.append(side_color)

		for idx_offset: int in Constants.TRI_INDEX_OFFSETS:
			indices.append(vertex_counter + idx_offset)

		vertex_counter += Constants.VERTICES_PER_TRIANGLE

	return vertex_counter

## Emits geometry for an inner corner slope block (2 inward sloped top triangles, bottom, 2 back walls, 2 side triangles).
static func _mesh_inner_corner_block(
	local_pos: Vector3i,
	block_def: BlockDefinition,
	block_base_pos: Vector3,
	chunk_data: ChunkData,
	registry: BlockRegistry,
	chunk_origin_voxel: Vector3i,
	neighbor_query_callable: Callable,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	vertex_counter: int
) -> int:
	var shape: Constants.BlockShape = block_def.shape

	# 1. Two Sloped Top Faces (meeting at central diagonal crease)
	var top_triangles: Array = Constants.INNER_CORNER_TOP_TRIANGLES[shape]
	var slope_color: Color = block_def.top_color
	for tri_data: Dictionary in top_triangles:
		var tri_normal: Vector3 = tri_data["normal"]
		var tri_verts: Array = tri_data["vertices"]

		for v_idx: int in range(Constants.VERTICES_PER_TRIANGLE):
			var vert_offset: Vector3 = tri_verts[v_idx] * Constants.VOXEL_SIZE_METERS
			vertices.append(block_base_pos + vert_offset)
			normals.append(tri_normal)
			uvs.append(Constants.TRI_UVS[v_idx])
			colors.append(slope_color)

		for idx_offset: int in Constants.TRI_INDEX_OFFSETS:
			indices.append(vertex_counter + idx_offset)

		vertex_counter += Constants.VERTICES_PER_TRIANGLE

	# 2. Bottom Face (culled if bottom neighbor is full solid cube)
	var bottom_id: int = _get_neighbor_block_id(
		chunk_data, local_pos, Vector3i(0, -1, 0), chunk_origin_voxel, neighbor_query_callable
	)
	if not registry.is_full_cube(bottom_id):
		var bottom_verts: Array = Constants.FACE_QUAD_VERTICES[Constants.CubeFace.BOTTOM]
		var bottom_normal: Vector3 = Constants.FACE_NORMALS[Constants.CubeFace.BOTTOM]
		var bottom_color: Color = block_def.bottom_color

		for v_idx: int in range(Constants.VERTICES_PER_QUAD):
			var vert_offset: Vector3 = bottom_verts[v_idx] * Constants.VOXEL_SIZE_METERS
			vertices.append(block_base_pos + vert_offset)
			normals.append(bottom_normal)
			uvs.append(Constants.QUAD_UVS[v_idx])
			colors.append(bottom_color)

		for idx_offset: int in Constants.QUAD_INDEX_OFFSETS:
			indices.append(vertex_counter + idx_offset)

		vertex_counter += Constants.VERTICES_PER_QUAD

	# 3. Two Solid Back Wall Faces (full vertical quads)
	var back_faces: Array = Constants.INNER_CORNER_BACK_WALL_FACES[shape]
	for back_face_val in back_faces:
		var back_face: Constants.CubeFace = back_face_val as Constants.CubeFace
		var back_offset: Vector3i = Constants.FACE_NEIGHBOR_OFFSETS[back_face]
		var back_id: int = _get_neighbor_block_id(
			chunk_data, local_pos, back_offset, chunk_origin_voxel, neighbor_query_callable
		)
		if not registry.is_full_cube(back_id):
			var back_verts: Array = Constants.FACE_QUAD_VERTICES[back_face]
			var back_normal: Vector3 = Constants.FACE_NORMALS[back_face]
			var back_color: Color = block_def.side_color

			for v_idx: int in range(Constants.VERTICES_PER_QUAD):
				var vert_offset: Vector3 = back_verts[v_idx] * Constants.VOXEL_SIZE_METERS
				vertices.append(block_base_pos + vert_offset)
				normals.append(back_normal)
				uvs.append(Constants.QUAD_UVS[v_idx])
				colors.append(back_color)

			for idx_offset: int in Constants.QUAD_INDEX_OFFSETS:
				indices.append(vertex_counter + idx_offset)

			vertex_counter += Constants.VERTICES_PER_QUAD

	# 4. Two Side Triangles
	var side_triangles: Array = Constants.INNER_CORNER_SIDE_TRIANGLES[shape]
	for side_data: Dictionary in side_triangles:
		var side_offset: Vector3i = side_data["neighbor_offset"]
		var side_id: int = _get_neighbor_block_id(
			chunk_data, local_pos, side_offset, chunk_origin_voxel, neighbor_query_callable
		)
		if registry.is_full_cube(side_id):
			continue

		var tri_normal: Vector3 = side_data["normal"]
		var tri_verts: Array = side_data["vertices"]
		var side_color: Color = block_def.side_color

		for v_idx: int in range(Constants.VERTICES_PER_TRIANGLE):
			var vert_offset: Vector3 = tri_verts[v_idx] * Constants.VOXEL_SIZE_METERS
			vertices.append(block_base_pos + vert_offset)
			normals.append(tri_normal)
			uvs.append(Constants.TRI_UVS[v_idx])
			colors.append(side_color)

		for idx_offset: int in Constants.TRI_INDEX_OFFSETS:
			indices.append(vertex_counter + idx_offset)

		vertex_counter += Constants.VERTICES_PER_TRIANGLE

	return vertex_counter

## Emits geometry for an outer corner slope block (2 outward sloped top triangles, bottom, 2 side triangles).
static func _mesh_outer_corner_block(
	local_pos: Vector3i,
	block_def: BlockDefinition,
	block_base_pos: Vector3,
	chunk_data: ChunkData,
	registry: BlockRegistry,
	chunk_origin_voxel: Vector3i,
	neighbor_query_callable: Callable,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	vertex_counter: int
) -> int:
	var shape: Constants.BlockShape = block_def.shape

	# 1. Two Sloped Top Faces (meeting at outward diagonal ridge)
	var top_triangles: Array = Constants.OUTER_CORNER_TOP_TRIANGLES[shape]
	var slope_color: Color = block_def.top_color
	for tri_data: Dictionary in top_triangles:
		var tri_normal: Vector3 = tri_data["normal"]
		var tri_verts: Array = tri_data["vertices"]

		for v_idx: int in range(Constants.VERTICES_PER_TRIANGLE):
			var vert_offset: Vector3 = tri_verts[v_idx] * Constants.VOXEL_SIZE_METERS
			vertices.append(block_base_pos + vert_offset)
			normals.append(tri_normal)
			uvs.append(Constants.TRI_UVS[v_idx])
			colors.append(slope_color)

		for idx_offset: int in Constants.TRI_INDEX_OFFSETS:
			indices.append(vertex_counter + idx_offset)

		vertex_counter += Constants.VERTICES_PER_TRIANGLE

	# 2. Bottom Face (culled if bottom neighbor is full solid cube)
	var bottom_id: int = _get_neighbor_block_id(
		chunk_data, local_pos, Vector3i(0, -1, 0), chunk_origin_voxel, neighbor_query_callable
	)
	if not registry.is_full_cube(bottom_id):
		var bottom_verts: Array = Constants.FACE_QUAD_VERTICES[Constants.CubeFace.BOTTOM]
		var bottom_normal: Vector3 = Constants.FACE_NORMALS[Constants.CubeFace.BOTTOM]
		var bottom_color: Color = block_def.bottom_color

		for v_idx: int in range(Constants.VERTICES_PER_QUAD):
			var vert_offset: Vector3 = bottom_verts[v_idx] * Constants.VOXEL_SIZE_METERS
			vertices.append(block_base_pos + vert_offset)
			normals.append(bottom_normal)
			uvs.append(Constants.QUAD_UVS[v_idx])
			colors.append(bottom_color)

		for idx_offset: int in Constants.QUAD_INDEX_OFFSETS:
			indices.append(vertex_counter + idx_offset)

		vertex_counter += Constants.VERTICES_PER_QUAD

	# 3. Two Side Triangles
	var side_triangles: Array = Constants.OUTER_CORNER_SIDE_TRIANGLES[shape]
	for side_data: Dictionary in side_triangles:
		var side_offset: Vector3i = side_data["neighbor_offset"]
		var side_id: int = _get_neighbor_block_id(
			chunk_data, local_pos, side_offset, chunk_origin_voxel, neighbor_query_callable
		)
		if registry.is_full_cube(side_id):
			continue

		var tri_normal: Vector3 = side_data["normal"]
		var tri_verts: Array = side_data["vertices"]
		var side_color: Color = block_def.side_color

		for v_idx: int in range(Constants.VERTICES_PER_TRIANGLE):
			var vert_offset: Vector3 = tri_verts[v_idx] * Constants.VOXEL_SIZE_METERS
			vertices.append(block_base_pos + vert_offset)
			normals.append(tri_normal)
			uvs.append(Constants.TRI_UVS[v_idx])
			colors.append(side_color)

		for idx_offset: int in Constants.TRI_INDEX_OFFSETS:
			indices.append(vertex_counter + idx_offset)

		vertex_counter += Constants.VERTICES_PER_TRIANGLE

	return vertex_counter

