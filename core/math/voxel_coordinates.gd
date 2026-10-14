class_name VoxelCoordinates
extends RefCounted

## -----------------------------------------------------------------------------
## Named Constants
## -----------------------------------------------------------------------------
const RAY_STEP_FACTOR: float = 0.25
const RAY_OFFSET_DISTANCE: float = Constants.HALF_VOXEL_SIZE_METERS * RAY_STEP_FACTOR

## -----------------------------------------------------------------------------
## Continuous World to Discrete Voxel Space
## -----------------------------------------------------------------------------
## Converts continuous floating-point world position to integer world voxel coordinate.
static func world_pos_to_voxel_coord(world_pos: Vector3) -> Vector3i:
	return Vector3i(
		floori(world_pos.x * Constants.INV_VOXEL_SIZE),
		floori(world_pos.y * Constants.INV_VOXEL_SIZE),
		floori(world_pos.z * Constants.INV_VOXEL_SIZE)
	)

## Converts integer world voxel coordinate to the continuous world position of its minimum corner (0,0,0).
static func voxel_coord_to_world_min_corner(voxel_coord: Vector3i) -> Vector3:
	return Vector3(
		float(voxel_coord.x) * Constants.VOXEL_SIZE_METERS,
		float(voxel_coord.y) * Constants.VOXEL_SIZE_METERS,
		float(voxel_coord.z) * Constants.VOXEL_SIZE_METERS
	)

## Converts integer world voxel coordinate to the continuous center point of the block.
static func voxel_coord_to_world_center(voxel_coord: Vector3i) -> Vector3:
	var min_corner: Vector3 = voxel_coord_to_world_min_corner(voxel_coord)
	return min_corner + Vector3(
		Constants.HALF_VOXEL_SIZE_METERS,
		Constants.HALF_VOXEL_SIZE_METERS,
		Constants.HALF_VOXEL_SIZE_METERS
	)

## -----------------------------------------------------------------------------
## Voxel to Chunk Coordinate Mapping
## -----------------------------------------------------------------------------
## Computes chunk coordinate from world voxel coordinate.
## Handles both negative and positive coordinates via floor division.
static func voxel_coord_to_chunk_coord(voxel_coord: Vector3i) -> Vector3i:
	return Vector3i(
		floori(float(voxel_coord.x) / float(Constants.CHUNK_WIDTH_VOXELS)),
		floori(float(voxel_coord.y) / float(Constants.CHUNK_HEIGHT_VOXELS)),
		floori(float(voxel_coord.z) / float(Constants.CHUNK_DEPTH_VOXELS))
	)

## Computes local voxel coordinate inside the chunk [0..width-1, 0..height-1, 0..depth-1].
## Uses posmod to ensure non-negative indices even for negative world coordinates.
static func voxel_coord_to_local_coord(voxel_coord: Vector3i) -> Vector3i:
	return Vector3i(
		posmod(voxel_coord.x, Constants.CHUNK_WIDTH_VOXELS),
		posmod(voxel_coord.y, Constants.CHUNK_HEIGHT_VOXELS),
		posmod(voxel_coord.z, Constants.CHUNK_DEPTH_VOXELS)
	)

## Converts chunk coordinate and local voxel coordinate to absolute world voxel coordinate.
static func chunk_and_local_to_voxel_coord(chunk_coord: Vector3i, local_coord: Vector3i) -> Vector3i:
	return Vector3i(
		chunk_coord.x * Constants.CHUNK_WIDTH_VOXELS + local_coord.x,
		chunk_coord.y * Constants.CHUNK_HEIGHT_VOXELS + local_coord.y,
		chunk_coord.z * Constants.CHUNK_DEPTH_VOXELS + local_coord.z
	)

## Converts chunk coordinate to continuous world position of the chunk's minimum corner.
static func chunk_coord_to_world_pos(chunk_coord: Vector3i) -> Vector3:
	return Vector3(
		float(chunk_coord.x * Constants.CHUNK_WIDTH_VOXELS) * Constants.VOXEL_SIZE_METERS,
		float(chunk_coord.y * Constants.CHUNK_HEIGHT_VOXELS) * Constants.VOXEL_SIZE_METERS,
		float(chunk_coord.z * Constants.CHUNK_DEPTH_VOXELS) * Constants.VOXEL_SIZE_METERS
	)

## -----------------------------------------------------------------------------
## 1D Buffer Indexing
## -----------------------------------------------------------------------------
## Converts local chunk coordinates to a 1D flattened array index.
static func local_coord_to_flat_index(local_coord: Vector3i) -> int:
	return local_coord.x + (local_coord.y * Constants.STRIDE_Y) + (local_coord.z * Constants.STRIDE_Z)

## Converts a 1D flattened array index back to local chunk coordinates.
static func flat_index_to_local_coord(index: int) -> Vector3i:
	var z: int = floori(float(index) / float(Constants.STRIDE_Z))
	var remainder_z: int = index % Constants.STRIDE_Z
	var y: int = floori(float(remainder_z) / float(Constants.STRIDE_Y))
	var x: int = remainder_z % Constants.STRIDE_Y
	return Vector3i(x, y, z)

## Checks whether local coordinates reside within chunk boundaries.
static func is_local_coord_valid(local_coord: Vector3i) -> bool:
	return (
		local_coord.x >= 0 and local_coord.x < Constants.CHUNK_WIDTH_VOXELS and
		local_coord.y >= 0 and local_coord.y < Constants.CHUNK_HEIGHT_VOXELS and
		local_coord.z >= 0 and local_coord.z < Constants.CHUNK_DEPTH_VOXELS
	)

## -----------------------------------------------------------------------------
## Raycast Hit Analysis
## -----------------------------------------------------------------------------
## Resolves the exact world voxel coordinate targeted for mining/destruction from a raycast hit.
static func resolve_mined_voxel_coord(hit_point: Vector3, hit_normal: Vector3) -> Vector3i:
	var sampling_point: Vector3 = hit_point - (hit_normal * RAY_OFFSET_DISTANCE)
	return world_pos_to_voxel_coord(sampling_point)

## Resolves the neighboring empty world voxel coordinate targeted for block placement.
static func resolve_placed_voxel_coord(hit_point: Vector3, hit_normal: Vector3) -> Vector3i:
	var sampling_point: Vector3 = hit_point + (hit_normal * RAY_OFFSET_DISTANCE)
	return world_pos_to_voxel_coord(sampling_point)
