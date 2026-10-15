class_name LODHeightmapMesher
extends RefCounted

## -----------------------------------------------------------------------------
## Distant 2D Heightmap LOD Meshing Pipeline
## -----------------------------------------------------------------------------
## Generates a lightweight 2D quad mesh with vertical skirts for distant chunk columns.
## Aligns flush at h + 1 with 3D voxel surfaces and drops skirts to Y=0 to eliminate void gaps.
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

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()

	var surface_def: BlockDefinition = registry.get_block(biome.surface_block_id)
	var surface_color: Color = surface_def.top_color if surface_def != null else Color(0.28, 0.65, 0.22, 1.0)

	var dirt_def: BlockDefinition = registry.get_block(biome.subsurface_block_id)
	var dirt_color: Color = dirt_def.side_color if dirt_def != null else Color(0.45, 0.30, 0.18, 1.0)

	# 1. Generate top terrain surface vertices
	for iz: int in range(samples_z):
		var lz: int = mini(iz * step, Constants.CHUNK_DEPTH_VOXELS)
		var wz: int = origin_z + lz

		for ix: int in range(samples_x):
			var lx: int = mini(ix * step, Constants.CHUNK_WIDTH_VOXELS)
			var wx: int = origin_x + lx

			var h: int = generator.get_terrain_height_at(wx, wz)

			# Top surface of voxel block h is at h + 1.0
			vertices.append(Vector3(
				float(lx) * Constants.VOXEL_SIZE_METERS,
				float(h + 1) * Constants.VOXEL_SIZE_METERS,
				float(lz) * Constants.VOXEL_SIZE_METERS
			))

			# Central difference normal estimation
			var hl: float = float(generator.get_terrain_height_at(wx - step, wz) + 1)
			var hr: float = float(generator.get_terrain_height_at(wx + step, wz) + 1)
			var hd: float = float(generator.get_terrain_height_at(wx, wz - step) + 1)
			var hu: float = float(generator.get_terrain_height_at(wx, wz + step) + 1)
			var norm: Vector3 = Vector3(hl - hr, float(2 * step), hd - hu).normalized()
			normals.append(norm)

			uvs.append(Vector2(
				float(lx) / float(Constants.CHUNK_WIDTH_VOXELS),
				float(lz) / float(Constants.CHUNK_DEPTH_VOXELS)
			))
			colors.append(surface_color)

	# Generate top surface quad indices (two triangles per cell, pointing UP)
	for iz: int in range(samples_z - 1):
		for ix: int in range(samples_x - 1):
			var v00: int = iz * samples_x + ix
			var v10: int = iz * samples_x + (ix + 1)
			var v01: int = (iz + 1) * samples_x + ix
			var v11: int = (iz + 1) * samples_x + (ix + 1)

			indices.append(v00)
			indices.append(v01)
			indices.append(v10)

			indices.append(v10)
			indices.append(v01)
			indices.append(v11)

	# 2. Generate downward vertical skirts on column boundaries to eliminate transparent gaps
	# North Skirt (lz = 0, normal = -Z)
	for ix: int in range(samples_x - 1):
		var lx0: int = mini(ix * step, Constants.CHUNK_WIDTH_VOXELS)
		var lx1: int = mini((ix + 1) * step, Constants.CHUNK_WIDTH_VOXELS)
		var h0: float = float(generator.get_terrain_height_at(origin_x + lx0, origin_z) + 1)
		var h1: float = float(generator.get_terrain_height_at(origin_x + lx1, origin_z) + 1)
		_add_skirt_quad(
			Vector3(lx0, h0, 0), Vector3(lx1, h1, 0),
			Vector3(lx0, 0, 0), Vector3(lx1, 0, 0),
			Vector3(0, 0, -1), dirt_color,
			vertices, normals, uvs, colors, indices
		)

	# South Skirt (lz = 16, normal = +Z)
	var max_lz: int = Constants.CHUNK_DEPTH_VOXELS
	for ix: int in range(samples_x - 1):
		var lx0: int = mini(ix * step, Constants.CHUNK_WIDTH_VOXELS)
		var lx1: int = mini((ix + 1) * step, Constants.CHUNK_WIDTH_VOXELS)
		var h0: float = float(generator.get_terrain_height_at(origin_x + lx0, origin_z + max_lz) + 1)
		var h1: float = float(generator.get_terrain_height_at(origin_x + lx1, origin_z + max_lz) + 1)
		_add_skirt_quad(
			Vector3(lx1, h1, max_lz), Vector3(lx0, h0, max_lz),
			Vector3(lx1, 0, max_lz), Vector3(lx0, 0, max_lz),
			Vector3(0, 0, 1), dirt_color,
			vertices, normals, uvs, colors, indices
		)

	# West Skirt (lx = 0, normal = -X)
	for iz: int in range(samples_z - 1):
		var lz0: int = mini(iz * step, Constants.CHUNK_DEPTH_VOXELS)
		var lz1: int = mini((iz + 1) * step, Constants.CHUNK_DEPTH_VOXELS)
		var h0: float = float(generator.get_terrain_height_at(origin_x, origin_z + lz0) + 1)
		var h1: float = float(generator.get_terrain_height_at(origin_x, origin_z + lz1) + 1)
		_add_skirt_quad(
			Vector3(0, h1, lz1), Vector3(0, h0, lz0),
			Vector3(0, 0, lz1), Vector3(0, 0, lz0),
			Vector3(-1, 0, 0), dirt_color,
			vertices, normals, uvs, colors, indices
		)

	# East Skirt (lx = 16, normal = +X)
	var max_lx: int = Constants.CHUNK_WIDTH_VOXELS
	for iz: int in range(samples_z - 1):
		var lz0: int = mini(iz * step, Constants.CHUNK_DEPTH_VOXELS)
		var lz1: int = mini((iz + 1) * step, Constants.CHUNK_DEPTH_VOXELS)
		var h0: float = float(generator.get_terrain_height_at(origin_x + max_lx, origin_z + lz0) + 1)
		var h1: float = float(generator.get_terrain_height_at(origin_x + max_lx, origin_z + lz1) + 1)
		_add_skirt_quad(
			Vector3(max_lx, h0, lz0), Vector3(max_lx, h1, lz1),
			Vector3(max_lx, 0, lz0), Vector3(max_lx, 0, lz1),
			Vector3(1, 0, 0), dirt_color,
			vertices, normals, uvs, colors, indices
		)

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
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)

	return mesh

static func _add_skirt_quad(
	p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
	norm: Vector3, col: Color,
	vertices: PackedVector3Array, normals: PackedVector3Array,
	uvs: PackedVector2Array, colors: PackedColorArray,
	indices: PackedInt32Array
) -> void:
	var base_idx: int = vertices.size()
	vertices.append(p0)
	vertices.append(p1)
	vertices.append(p2)
	vertices.append(p3)

	normals.append(norm)
	normals.append(norm)
	normals.append(norm)
	normals.append(norm)

	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(1, 0))
	uvs.append(Vector2(0, 1))
	uvs.append(Vector2(1, 1))

	colors.append(col)
	colors.append(col)
	colors.append(col)
	colors.append(col)

	indices.append(base_idx)
	indices.append(base_idx + 1)
	indices.append(base_idx + 2)

	indices.append(base_idx + 1)
	indices.append(base_idx + 3)
	indices.append(base_idx + 2)
