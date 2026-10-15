class_name LODHeightmapMesher
extends RefCounted

## -----------------------------------------------------------------------------
## Distant 2D Heightmap LOD Meshing Pipeline
## -----------------------------------------------------------------------------
## Generates a lightweight 2D quad mesh for distant chunk columns beyond interaction radius.
## Avoids 3D voxel buffer allocations and physics baking entirely.
static func build_column_lod_mesh(
	col_coord: Vector2i,
	generator: TerrainGenerator,
	biome: BiomeDefinition,
	registry: BlockRegistry,
	step: int = 2
) -> ArrayMesh:
	if generator == null or biome == null or registry == null:
		return null

	var origin_x: int = col_coord.x * Constants.CHUNK_WIDTH_VOXELS
	var origin_z: int = col_coord.y * Constants.CHUNK_DEPTH_VOXELS

	var samples_x: int = (Constants.CHUNK_WIDTH_VOXELS / step) + 1
	var samples_z: int = (Constants.CHUNK_DEPTH_VOXELS / step) + 1
	var total_vertices: int = samples_x * samples_z

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()

	vertices.resize(total_vertices)
	normals.resize(total_vertices)
	uvs.resize(total_vertices)
	colors.resize(total_vertices)

	var surface_def: BlockDefinition = registry.get_block(biome.surface_block_id)
	var surface_color: Color = surface_def.top_color if surface_def != null else Color(0.28, 0.65, 0.22, 1.0)

	var vert_idx: int = 0
	for iz: int in range(samples_z):
		var lz: int = mini(iz * step, Constants.CHUNK_DEPTH_VOXELS)
		var wz: int = origin_z + lz

		for ix: int in range(samples_x):
			var lx: int = mini(ix * step, Constants.CHUNK_WIDTH_VOXELS)
			var wx: int = origin_x + lx

			var h: int = generator.get_terrain_height_at(wx, wz)

			# Local vertex position at world elevation Y
			vertices[vert_idx] = Vector3(
				float(lx) * Constants.VOXEL_SIZE_METERS,
				float(h) * Constants.VOXEL_SIZE_METERS,
				float(lz) * Constants.VOXEL_SIZE_METERS
			)

			# Central difference surface normal estimation
			var hl: float = float(generator.get_terrain_height_at(wx - step, wz))
			var hr: float = float(generator.get_terrain_height_at(wx + step, wz))
			var hd: float = float(generator.get_terrain_height_at(wx, wz - step))
			var hu: float = float(generator.get_terrain_height_at(wx, wz + step))
			var norm: Vector3 = Vector3(hl - hr, float(2 * step), hd - hu).normalized()
			normals[vert_idx] = norm

			uvs[vert_idx] = Vector2(
				float(lx) / float(Constants.CHUNK_WIDTH_VOXELS),
				float(lz) / float(Constants.CHUNK_DEPTH_VOXELS)
			)
			colors[vert_idx] = surface_color

			vert_idx += 1

	# Generate triangle indices (two triangles per quad cell, facing UP +Y)
	for iz: int in range(samples_z - 1):
		for ix: int in range(samples_x - 1):
			var v00: int = iz * samples_x + ix
			var v10: int = iz * samples_x + (ix + 1)
			var v01: int = (iz + 1) * samples_x + ix
			var v11: int = (iz + 1) * samples_x + (ix + 1)

			# Triangle 1
			indices.append(v00)
			indices.append(v01)
			indices.append(v10)

			# Triangle 2
			indices.append(v10)
			indices.append(v01)
			indices.append(v11)

	var mesh_arrays: Array = []
	mesh_arrays.resize(Mesh.ARRAY_MAX)
	mesh_arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh_arrays[Mesh.ARRAY_NORMAL] = normals
	mesh_arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh_arrays[Mesh.ARRAY_COLOR] = colors
	mesh_arrays[Mesh.ARRAY_INDEX] = indices

	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.8
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_BACK
	mesh.surface_set_material(0, material)

	return mesh
