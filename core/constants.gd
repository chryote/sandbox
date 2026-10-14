class_name Constants
extends RefCounted

## -----------------------------------------------------------------------------
## Core Geometric & Physical Metrics
## -----------------------------------------------------------------------------
## The physical size of a single voxel block edge along any axis in meters.
const VOXEL_SIZE_METERS: float = 1.0

## Half the physical size of a voxel block edge in meters, used for center offsets.
const HALF_VOXEL_SIZE_METERS: float = 0.5

## Inverse of voxel size, used for fast coordinate space scaling.
const INV_VOXEL_SIZE: float = 1.0 / VOXEL_SIZE_METERS

## -----------------------------------------------------------------------------
## Chunk Geometry & Capacity
## -----------------------------------------------------------------------------
## Number of voxel columns along the X axis per chunk.
const CHUNK_WIDTH_VOXELS: int = 16

## Number of voxel layers along the Y axis per chunk.
const CHUNK_HEIGHT_VOXELS: int = 32

## Number of voxel rows along the Z axis per chunk.
const CHUNK_DEPTH_VOXELS: int = 16

## Vector3i representing full chunk dimensions.
const CHUNK_SIZE_VOXELS: Vector3i = Vector3i(
	CHUNK_WIDTH_VOXELS,
	CHUNK_HEIGHT_VOXELS,
	CHUNK_DEPTH_VOXELS
)

## Total count of individual voxels contained in one chunk data buffer.
const CHUNK_VOXEL_VOLUME: int = CHUNK_WIDTH_VOXELS * CHUNK_HEIGHT_VOXELS * CHUNK_DEPTH_VOXELS

## Stride along Y axis for flattened 1D array indexing (width * 1).
const STRIDE_Y: int = CHUNK_WIDTH_VOXELS

## Stride along Z axis for flattened 1D array indexing (width * height).
const STRIDE_Z: int = CHUNK_WIDTH_VOXELS * CHUNK_HEIGHT_VOXELS

## -----------------------------------------------------------------------------
## Directional Faces & Mesh Topology
## -----------------------------------------------------------------------------
## Identification for the six orthogonal cube faces.
enum CubeFace {
	EAST = 0,   ## +X
	WEST = 1,   ## -X
	TOP = 2,    ## +Y
	BOTTOM = 3, ## -Y
	SOUTH = 4,  ## +Z
	NORTH = 5   ## -Z
}

## Total number of faces on a cubic voxel.
const TOTAL_CUBE_FACES: int = 6

## Number of vertices required for a single quad face.
const VERTICES_PER_QUAD: int = 4

## Number of triangle indices required to form two triangles per quad face.
const INDICES_PER_QUAD: int = 6

## Unit normal vectors for each of the six cube faces in CubeFace order.
const FACE_NORMALS: Array[Vector3] = [
	Vector3(1.0, 0.0, 0.0),   ## EAST (+X)
	Vector3(-1.0, 0.0, 0.0),  ## WEST (-X)
	Vector3(0.0, 1.0, 0.0),   ## TOP (+Y)
	Vector3(0.0, -1.0, 0.0),  ## BOTTOM (-Y)
	Vector3(0.0, 0.0, 1.0),   ## SOUTH (+Z)
	Vector3(0.0, 0.0, -1.0)   ## NORTH (-Z)
]

## Integer neighbor offsets for adjacency checks in CubeFace order.
const FACE_NEIGHBOR_OFFSETS: Array[Vector3i] = [
	Vector3i(1, 0, 0),   ## EAST (+X)
	Vector3i(-1, 0, 0),  ## WEST (-X)
	Vector3i(0, 1, 0),   ## TOP (+Y)
	Vector3i(0, -1, 0),  ## BOTTOM (-Y)
	Vector3i(0, 0, 1),   ## SOUTH (+Z)
	Vector3i(0, 0, -1)   ## NORTH (-Z)
]

## Relative vertex coordinates for each of the six faces (unit cube from 0.0 to 1.0).
const FACE_QUAD_VERTICES: Array[Array] = [
	# EAST (+X)
	[
		Vector3(1.0, 0.0, 1.0),
		Vector3(1.0, 0.0, 0.0),
		Vector3(1.0, 1.0, 0.0),
		Vector3(1.0, 1.0, 1.0)
	],
	# WEST (-X)
	[
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 1.0),
		Vector3(0.0, 1.0, 1.0),
		Vector3(0.0, 1.0, 0.0)
	],
	# TOP (+Y)
	[
		Vector3(0.0, 1.0, 1.0),
		Vector3(1.0, 1.0, 1.0),
		Vector3(1.0, 1.0, 0.0),
		Vector3(0.0, 1.0, 0.0)
	],
	# BOTTOM (-Y)
	[
		Vector3(0.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 1.0),
		Vector3(0.0, 0.0, 1.0)
	],
	# SOUTH (+Z)
	[
		Vector3(0.0, 0.0, 1.0),
		Vector3(1.0, 0.0, 1.0),
		Vector3(1.0, 1.0, 1.0),
		Vector3(0.0, 1.0, 1.0)
	],
	# NORTH (-Z)
	[
		Vector3(1.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.0, 1.0, 0.0),
		Vector3(1.0, 1.0, 0.0)
	]
]

## Standard UV coordinates mapped to a 4-vertex quad face.
const QUAD_UVS: Array[Vector2] = [
	Vector2(0.0, 1.0),
	Vector2(1.0, 1.0),
	Vector2(1.0, 0.0),
	Vector2(0.0, 0.0)
]

## Standard clockwise triangle winding indices for a quad in Godot 3D.
const QUAD_INDEX_OFFSETS: Array[int] = [0, 2, 1, 0, 3, 2]

## -----------------------------------------------------------------------------
## Standard Registered Block Identifiers
## -----------------------------------------------------------------------------
const BLOCK_ID_AIR: int = 0
const BLOCK_ID_STONE: int = 1
const BLOCK_ID_DIRT: int = 2
const BLOCK_ID_GRASS: int = 3
const BLOCK_ID_SAND: int = 4
const BLOCK_ID_WOOD: int = 5
const BLOCK_ID_LEAVES: int = 6
const BLOCK_ID_BEDROCK: int = 7

## -----------------------------------------------------------------------------
## World Generation Defaults
## -----------------------------------------------------------------------------
const DEFAULT_WORLD_SEED: int = 1337
const DEFAULT_LOAD_RADIUS_CHUNKS: int = 2
const DEFAULT_TERRAIN_BASE_HEIGHT: int = 10
const DEFAULT_TERRAIN_HEIGHT_VARIATION: int = 12
const DEFAULT_DIRT_LAYER_THICKNESS: int = 3
const DEFAULT_NOISE_FREQUENCY: float = 0.035
const DEFAULT_NOISE_OCTAVES: int = 3
const DEFAULT_NOISE_LACUNARITY: float = 2.0
const DEFAULT_NOISE_GAIN: float = 0.5

## -----------------------------------------------------------------------------
## Third-Person Shooter (TPS) Controller & Camera Metrics
## -----------------------------------------------------------------------------
const PLAYER_WALK_SPEED_METERS_PER_SEC: float = 5.0
const PLAYER_SPRINT_SPEED_METERS_PER_SEC: float = 8.5
const PLAYER_ACCELERATION_METERS_PER_SEC_SQ: float = 35.0
const PLAYER_FRICTION_METERS_PER_SEC_SQ: float = 30.0
const PLAYER_AIR_CONTROL_FACTOR: float = 0.35
const PLAYER_JUMP_VELOCITY_METERS_PER_SEC: float = 7.5
const PLAYER_GRAVITY_METERS_PER_SEC_SQ: float = 22.0

const CAMERA_SPRING_ARM_LENGTH_METERS: float = 3.5
const CAMERA_SHOULDER_OFFSET_METERS: Vector3 = Vector3(0.65, 0.55, 0.0)
const CAMERA_MOUSE_SENSITIVITY: float = 0.0025
const CAMERA_PITCH_MIN_DEGREES: float = -75.0
const CAMERA_PITCH_MAX_DEGREES: float = 65.0

const INTERACTION_MAX_DISTANCE_METERS: float = 7.0
const RAY_NORMAL_EPSILON: float = 0.01
