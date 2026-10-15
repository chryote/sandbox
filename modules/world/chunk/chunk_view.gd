class_name ChunkView
extends StaticBody3D

## -----------------------------------------------------------------------------
## Nodes & State
## -----------------------------------------------------------------------------
var chunk_coord: Vector3i = Vector3i.ZERO
var mesh_instance: MeshInstance3D = null
var collision_shape: CollisionShape3D = null

func _init(p_chunk_coord: Vector3i = Vector3i.ZERO) -> void:
	chunk_coord = p_chunk_coord
	name = "Chunk_%d_%d_%d" % [chunk_coord.x, chunk_coord.y, chunk_coord.z]
	collision_layer = 1
	collision_mask = 0

	# Set position corresponding to chunk minimum corner
	position = VoxelCoordinates.chunk_coord_to_world_pos(chunk_coord)

func _ready() -> void:
	_create_child_nodes_if_needed()

func _create_child_nodes_if_needed() -> void:
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance"
		add_child(mesh_instance)

	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape"
		add_child(collision_shape)

## Updates the chunk's visual mesh and physics collision body.
func update_mesh_and_collision(new_mesh: ArrayMesh) -> void:
	_create_child_nodes_if_needed()

	if new_mesh == null:
		mesh_instance.mesh = null
		collision_shape.shape = null
		return

	mesh_instance.mesh = new_mesh
	var trimesh_shape: ConcavePolygonShape3D = new_mesh.create_trimesh_shape()
	collision_shape.shape = trimesh_shape
