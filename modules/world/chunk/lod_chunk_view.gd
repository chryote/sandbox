class_name LODChunkView
extends Node3D

## -----------------------------------------------------------------------------
## Nodes & State
## -----------------------------------------------------------------------------
var col_coord: Vector2i = Vector2i.ZERO
var mesh_instance: MeshInstance3D = null

func _init(p_col_coord: Vector2i = Vector2i.ZERO) -> void:
	col_coord = p_col_coord
	name = "LODChunk_%d_%d" % [col_coord.x, col_coord.y]

	# Position column at world minimum X and Z
	position = Vector3(
		float(col_coord.x * Constants.CHUNK_WIDTH_VOXELS) * Constants.VOXEL_SIZE_METERS,
		0.0,
		float(col_coord.y * Constants.CHUNK_DEPTH_VOXELS) * Constants.VOXEL_SIZE_METERS
	)

func set_mesh(new_mesh: ArrayMesh) -> void:
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "LODMesh"
		add_child(mesh_instance)

	mesh_instance.mesh = new_mesh
