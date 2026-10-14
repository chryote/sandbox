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

				# Test all 6 orthogonal cube faces
				for face_idx: int in range(Constants.TOTAL_CUBE_FACES):
					var neighbor_offset: Vector3i = Constants.FACE_NEIGHBOR_OFFSETS[face_idx]
					var neighbor_local_pos: Vector3i = local_pos + neighbor_offset
					var face_is_visible: bool = false

					if VoxelCoordinates.is_local_coord_valid(neighbor_local_pos):
						var neighbor_id: int = chunk_data.get_block(neighbor_local_pos)
						face_is_visible = registry.is_transparent(neighbor_id)
					else:
						# Neighbor resides across chunk boundary
						if neighbor_query_callable.is_valid():
							var neighbor_world_voxel: Vector3i = chunk_origin_voxel + neighbor_local_pos
							face_is_visible = neighbor_query_callable.call(neighbor_world_voxel)
						else:
							# In absence of neighbor chunk data, render boundary face
							face_is_visible = true

					if not face_is_visible:
						continue

					# Face is visible - emit geometry
					var normal_vec: Vector3 = Constants.FACE_NORMALS[face_idx]
					var face_color: Color = block_def.get_face_color(face_idx as Constants.CubeFace)
					var quad_verts: Array = Constants.FACE_QUAD_VERTICES[face_idx]

					for v_idx: int in range(Constants.VERTICES_PER_QUAD):
						var vert_offset: Vector3 = quad_verts[v_idx] * Constants.VOXEL_SIZE_METERS
						vertices.append(block_base_pos + vert_offset)
						normals.append(normal_vec)
						uvs.append(Constants.QUAD_UVS[v_idx])
						colors.append(face_color)

					# Emit 6 triangle indices for 2 counter-clockwise triangles
					for idx_offset: int in Constants.QUAD_INDEX_OFFSETS:
						indices.append(vertex_counter + idx_offset)

					vertex_counter += Constants.VERTICES_PER_QUAD

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
