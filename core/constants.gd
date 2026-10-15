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

## Number of voxel layers along the Y axis per chunk (cubic 16x16x16 sub-chunk).
const CHUNK_HEIGHT_VOXELS: int = 16

## Number of voxel rows along the Z axis per chunk.
const CHUNK_DEPTH_VOXELS: int = 16

## World vertical sub-chunk count and total maximum height in voxels.
const WORLD_HEIGHT_CHUNKS: int = 4
const WORLD_MAX_HEIGHT_VOXELS: int = CHUNK_HEIGHT_VOXELS * WORLD_HEIGHT_CHUNKS

## Vector3i representing full chunk dimensions.
const CHUNK_SIZE_VOXELS: Vector3i = Vector3i(
	CHUNK_WIDTH_VOXELS,
	CHUNK_HEIGHT_VOXELS,
	CHUNK_DEPTH_VOXELS
)

## Total count of individual voxels contained in one chunk data buffer (16^3 = 4096).
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

## Identification for voxel shape geometry.
enum BlockShape {
	CUBE = 0,
	RAMP_NORTH = 1, ## Slopes down towards -Z (North). Back wall on South (+Z).
	RAMP_SOUTH = 2, ## Slopes down towards +Z (South). Back wall on North (-Z).
	RAMP_EAST = 3,  ## Slopes down towards +X (East). Back wall on West (-X).
	RAMP_WEST = 4,  ## Slopes down towards -X (West). Back wall on East (+X).

	## Inner Corner (Concave) Slopes: 3 high corners, 1 low corner.
	INNER_CORNER_NORTH_WEST = 5, ## Low point at NW (0,0). Back walls on South (+Z) and East (+X).
	INNER_CORNER_NORTH_EAST = 6, ## Low point at NE (1,0). Back walls on South (+Z) and West (-X).
	INNER_CORNER_SOUTH_WEST = 7, ## Low point at SW (0,1). Back walls on North (-Z) and East (+X).
	INNER_CORNER_SOUTH_EAST = 8, ## Low point at SE (1,1). Back walls on North (-Z) and West (-X).

	## Outer Corner (Convex) Slopes: 1 high corner, 3 low corners.
	OUTER_CORNER_NORTH_WEST = 9,  ## High point at NW (0,0). Slopes down towards South and East.
	OUTER_CORNER_NORTH_EAST = 10, ## High point at NE (1,0). Slopes down towards South and West.
	OUTER_CORNER_SOUTH_WEST = 11, ## High point at SW (0,1). Slopes down towards North and East.
	OUTER_CORNER_SOUTH_EAST = 12  ## High point at SE (1,1). Slopes down towards North and West.
}

## Total number of faces on a cubic voxel.
const TOTAL_CUBE_FACES: int = 6

## Number of vertices required for a single quad face.
const VERTICES_PER_QUAD: int = 4

## Number of triangle indices required to form two triangles per quad face.
const INDICES_PER_QUAD: int = 6

## Number of vertices and indices for a triangle face.
const VERTICES_PER_TRIANGLE: int = 3
const INDICES_PER_TRIANGLE: int = 3
const TRI_INDEX_OFFSETS: Array[int] = [0, 1, 2]
const TRI_UVS: Array[Vector2] = [
	Vector2(0.0, 1.0),
	Vector2(1.0, 0.0),
	Vector2(1.0, 1.0)
]

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
## Directional Ramp Mesh Topology
## -----------------------------------------------------------------------------
const RAMP_SLOPE_NORMALS: Dictionary = {
	BlockShape.RAMP_NORTH: Vector3(0.0, 0.70710678, -0.70710678),
	BlockShape.RAMP_SOUTH: Vector3(0.0, 0.70710678, 0.70710678),
	BlockShape.RAMP_EAST: Vector3(0.70710678, 0.70710678, 0.0),
	BlockShape.RAMP_WEST: Vector3(-0.70710678, 0.70710678, 0.0)
}

## CubeFace corresponding to the solid vertical back wall of the ramp.
const RAMP_BACK_WALL_FACES: Dictionary = {
	BlockShape.RAMP_NORTH: CubeFace.SOUTH,
	BlockShape.RAMP_SOUTH: CubeFace.NORTH,
	BlockShape.RAMP_EAST: CubeFace.WEST,
	BlockShape.RAMP_WEST: CubeFace.EAST
}

## 4-vertex quad definition for the sloped top face of each ramp.
## Wound so that (V2 - V0) x (V1 - V0) = -Normal, matching the engine's front-face winding.
const RAMP_SLOPE_QUAD_VERTICES: Dictionary = {
	BlockShape.RAMP_NORTH: [
		Vector3(0.0, 0.0, 0.0), # 0 (low West)
		Vector3(0.0, 1.0, 1.0), # 1 (high West)
		Vector3(1.0, 1.0, 1.0), # 2 (high East)
		Vector3(1.0, 0.0, 0.0)  # 3 (low East)
	],
	BlockShape.RAMP_SOUTH: [
		Vector3(1.0, 0.0, 1.0), # 0 (low East)
		Vector3(1.0, 1.0, 0.0), # 1 (high East)
		Vector3(0.0, 1.0, 0.0), # 2 (high West)
		Vector3(0.0, 0.0, 1.0)  # 3 (low West)
	],
	BlockShape.RAMP_EAST: [
		Vector3(1.0, 0.0, 0.0), # 0 (low North)
		Vector3(0.0, 1.0, 0.0), # 1 (high North)
		Vector3(0.0, 1.0, 1.0), # 2 (high South)
		Vector3(1.0, 0.0, 1.0)  # 3 (low South)
	],
	BlockShape.RAMP_WEST: [
		Vector3(0.0, 0.0, 1.0), # 0 (low South)
		Vector3(1.0, 1.0, 1.0), # 1 (high South)
		Vector3(1.0, 1.0, 0.0), # 2 (high North)
		Vector3(0.0, 0.0, 0.0)  # 3 (low North)
	]
}

## Definition for the two side triangle faces per ramp shape.
## Each element in the array has:
##   "normal": Vector3,
##   "neighbor_offset": Vector3i,
##   "vertices": Array[Vector3] (wound so (V1 - V0) x (V2 - V0) = -Normal)
const RAMP_SIDE_TRIANGLES: Dictionary = {
	BlockShape.RAMP_NORTH: [
		{
			"normal": Vector3(-1.0, 0.0, 0.0),
			"neighbor_offset": Vector3i(-1, 0, 0),
			"vertices": [Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.0, 1.0)]
		},
		{
			"normal": Vector3(1.0, 0.0, 0.0),
			"neighbor_offset": Vector3i(1, 0, 0),
			"vertices": [Vector3(1.0, 0.0, 0.0), Vector3(1.0, 0.0, 1.0), Vector3(1.0, 1.0, 1.0)]
		}
	],
	BlockShape.RAMP_SOUTH: [
		{
			"normal": Vector3(-1.0, 0.0, 0.0),
			"neighbor_offset": Vector3i(-1, 0, 0),
			"vertices": [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 1.0)]
		},
		{
			"normal": Vector3(1.0, 0.0, 0.0),
			"neighbor_offset": Vector3i(1, 0, 0),
			"vertices": [Vector3(1.0, 0.0, 0.0), Vector3(1.0, 0.0, 1.0), Vector3(1.0, 1.0, 0.0)]
		}
	],
	BlockShape.RAMP_EAST: [
		{
			"normal": Vector3(0.0, 0.0, -1.0),
			"neighbor_offset": Vector3i(0, 0, -1),
			"vertices": [Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 0.0)]
		},
		{
			"normal": Vector3(0.0, 0.0, 1.0),
			"neighbor_offset": Vector3i(0, 0, 1),
			"vertices": [Vector3(1.0, 0.0, 1.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, 1.0, 1.0)]
		}
	],
	BlockShape.RAMP_WEST: [
		{
			"normal": Vector3(0.0, 0.0, -1.0),
			"neighbor_offset": Vector3i(0, 0, -1),
			"vertices": [Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(1.0, 1.0, 0.0)]
		},
		{
			"normal": Vector3(0.0, 0.0, 1.0),
			"neighbor_offset": Vector3i(0, 0, 1),
			"vertices": [Vector3(0.0, 0.0, 1.0), Vector3(1.0, 1.0, 1.0), Vector3(1.0, 0.0, 1.0)]
		}
	]
}

## -----------------------------------------------------------------------------
## Inner Corner Slope Mesh Topology
## -----------------------------------------------------------------------------
## Two solid vertical back wall faces per inner corner.
const INNER_CORNER_BACK_WALL_FACES: Dictionary = {
	BlockShape.INNER_CORNER_NORTH_WEST: [CubeFace.SOUTH, CubeFace.EAST],
	BlockShape.INNER_CORNER_NORTH_EAST: [CubeFace.SOUTH, CubeFace.WEST],
	BlockShape.INNER_CORNER_SOUTH_WEST: [CubeFace.NORTH, CubeFace.EAST],
	BlockShape.INNER_CORNER_SOUTH_EAST: [CubeFace.NORTH, CubeFace.WEST]
}

## Two sloped top triangles meeting at the central diagonal crease.
## Wound so that (V2 - V0) x (V1 - V0) = Normal (Godot front-facing clockwise winding).
const INNER_CORNER_TOP_TRIANGLES: Dictionary = {
	BlockShape.INNER_CORNER_NORTH_WEST: [
		{
			"normal": Vector3(-0.70710678, 0.70710678, 0.0),
			"vertices": [Vector3(0.0, 0.0, 0.0), Vector3(1.0, 1.0, 0.0), Vector3(1.0, 1.0, 1.0)]
		},
		{
			"normal": Vector3(0.0, 0.70710678, -0.70710678),
			"vertices": [Vector3(0.0, 0.0, 0.0), Vector3(1.0, 1.0, 1.0), Vector3(0.0, 1.0, 1.0)]
		}
	],
	BlockShape.INNER_CORNER_NORTH_EAST: [
		{
			"normal": Vector3(0.70710678, 0.70710678, 0.0),
			"vertices": [Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 1.0), Vector3(0.0, 1.0, 0.0)]
		},
		{
			"normal": Vector3(0.0, 0.70710678, -0.70710678),
			"vertices": [Vector3(1.0, 0.0, 0.0), Vector3(1.0, 1.0, 1.0), Vector3(0.0, 1.0, 1.0)]
		}
	],
	BlockShape.INNER_CORNER_SOUTH_WEST: [
		{
			"normal": Vector3(0.0, 0.70710678, 0.70710678),
			"vertices": [Vector3(0.0, 0.0, 1.0), Vector3(0.0, 1.0, 0.0), Vector3(1.0, 1.0, 0.0)]
		},
		{
			"normal": Vector3(-0.70710678, 0.70710678, 0.0),
			"vertices": [Vector3(0.0, 0.0, 1.0), Vector3(1.0, 1.0, 0.0), Vector3(1.0, 1.0, 1.0)]
		}
	],
	BlockShape.INNER_CORNER_SOUTH_EAST: [
		{
			"normal": Vector3(0.0, 0.70710678, 0.70710678),
			"vertices": [Vector3(1.0, 0.0, 1.0), Vector3(0.0, 1.0, 0.0), Vector3(1.0, 1.0, 0.0)]
		},
		{
			"normal": Vector3(0.70710678, 0.70710678, 0.0),
			"vertices": [Vector3(1.0, 0.0, 1.0), Vector3(0.0, 1.0, 1.0), Vector3(0.0, 1.0, 0.0)]
		}
	]
}

## Two vertical side triangles on the lower sides of the inner corner block.
const INNER_CORNER_SIDE_TRIANGLES: Dictionary = {
	BlockShape.INNER_CORNER_NORTH_WEST: [
		{
			"normal": Vector3(0.0, 0.0, -1.0),
			"neighbor_offset": Vector3i(0, 0, -1),
			"vertices": [Vector3(1.0, 0.0, 0.0), Vector3(1.0, 1.0, 0.0), Vector3(0.0, 0.0, 0.0)]
		},
		{
			"normal": Vector3(-1.0, 0.0, 0.0),
			"neighbor_offset": Vector3i(-1, 0, 0),
			"vertices": [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.0, 1.0), Vector3(0.0, 0.0, 1.0)]
		}
	],
	BlockShape.INNER_CORNER_NORTH_EAST: [
		{
			"normal": Vector3(0.0, 0.0, -1.0),
			"neighbor_offset": Vector3i(0, 0, -1),
			"vertices": [Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0)]
		},
		{
			"normal": Vector3(1.0, 0.0, 0.0),
			"neighbor_offset": Vector3i(1, 0, 0),
			"vertices": [Vector3(1.0, 0.0, 0.0), Vector3(1.0, 0.0, 1.0), Vector3(1.0, 1.0, 1.0)]
		}
	],
	BlockShape.INNER_CORNER_SOUTH_WEST: [
		{
			"normal": Vector3(0.0, 0.0, 1.0),
			"neighbor_offset": Vector3i(0, 0, 1),
			"vertices": [Vector3(0.0, 0.0, 1.0), Vector3(1.0, 1.0, 1.0), Vector3(1.0, 0.0, 1.0)]
		},
		{
			"normal": Vector3(-1.0, 0.0, 0.0),
			"neighbor_offset": Vector3i(-1, 0, 0),
			"vertices": [Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0)]
		}
	],
	BlockShape.INNER_CORNER_SOUTH_EAST: [
		{
			"normal": Vector3(0.0, 0.0, 1.0),
			"neighbor_offset": Vector3i(0, 0, 1),
			"vertices": [Vector3(1.0, 0.0, 1.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, 1.0, 1.0)]
		},
		{
			"normal": Vector3(1.0, 0.0, 0.0),
			"neighbor_offset": Vector3i(1, 0, 0),
			"vertices": [Vector3(1.0, 0.0, 1.0), Vector3(1.0, 1.0, 0.0), Vector3(1.0, 0.0, 0.0)]
		}
	]
}

## -----------------------------------------------------------------------------
## Outer Corner Slope Mesh Topology
## -----------------------------------------------------------------------------
## Two sloped top triangles meeting at the outward diagonal ridge.
const OUTER_CORNER_TOP_TRIANGLES: Dictionary = {
	BlockShape.OUTER_CORNER_NORTH_WEST: [
		{
			"normal": Vector3(0.70710678, 0.70710678, 0.0),
			"vertices": [Vector3(0.0, 1.0, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(1.0, 0.0, 1.0)]
		},
		{
			"normal": Vector3(0.0, 0.70710678, 0.70710678),
			"vertices": [Vector3(0.0, 1.0, 0.0), Vector3(1.0, 0.0, 1.0), Vector3(0.0, 0.0, 1.0)]
		}
	],
	BlockShape.OUTER_CORNER_NORTH_EAST: [
		{
			"normal": Vector3(-0.70710678, 0.70710678, 0.0),
			"vertices": [Vector3(1.0, 1.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, 0.0)]
		},
		{
			"normal": Vector3(0.0, 0.70710678, 0.70710678),
			"vertices": [Vector3(1.0, 1.0, 0.0), Vector3(1.0, 0.0, 1.0), Vector3(0.0, 0.0, 1.0)]
		}
	],
	BlockShape.OUTER_CORNER_SOUTH_WEST: [
		{
			"normal": Vector3(0.70710678, 0.70710678, 0.0),
			"vertices": [Vector3(0.0, 1.0, 1.0), Vector3(1.0, 0.0, 0.0), Vector3(1.0, 0.0, 1.0)]
		},
		{
			"normal": Vector3(0.0, 0.70710678, -0.70710678),
			"vertices": [Vector3(0.0, 1.0, 1.0), Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0)]
		}
	],
	BlockShape.OUTER_CORNER_SOUTH_EAST: [
		{
			"normal": Vector3(0.0, 0.70710678, -0.70710678),
			"vertices": [Vector3(1.0, 1.0, 1.0), Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0)]
		},
		{
			"normal": Vector3(-0.70710678, 0.70710678, 0.0),
			"vertices": [Vector3(1.0, 1.0, 1.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, 0.0)]
		}
	]
}

## Two vertical side triangles on the higher sides of the outer corner block.
const OUTER_CORNER_SIDE_TRIANGLES: Dictionary = {
	BlockShape.OUTER_CORNER_NORTH_WEST: [
		{
			"normal": Vector3(0.0, 0.0, -1.0),
			"neighbor_offset": Vector3i(0, 0, -1),
			"vertices": [Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0)]
		},
		{
			"normal": Vector3(-1.0, 0.0, 0.0),
			"neighbor_offset": Vector3i(-1, 0, 0),
			"vertices": [Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0)]
		}
	],
	BlockShape.OUTER_CORNER_NORTH_EAST: [
		{
			"normal": Vector3(0.0, 0.0, -1.0),
			"neighbor_offset": Vector3i(0, 0, -1),
			"vertices": [Vector3(1.0, 0.0, 0.0), Vector3(1.0, 1.0, 0.0), Vector3(0.0, 0.0, 0.0)]
		},
		{
			"normal": Vector3(1.0, 0.0, 0.0),
			"neighbor_offset": Vector3i(1, 0, 0),
			"vertices": [Vector3(1.0, 0.0, 0.0), Vector3(1.0, 0.0, 1.0), Vector3(1.0, 1.0, 0.0)]
		}
	],
	BlockShape.OUTER_CORNER_SOUTH_WEST: [
		{
			"normal": Vector3(0.0, 0.0, 1.0),
			"neighbor_offset": Vector3i(0, 0, 1),
			"vertices": [Vector3(0.0, 0.0, 1.0), Vector3(0.0, 1.0, 1.0), Vector3(1.0, 0.0, 1.0)]
		},
		{
			"normal": Vector3(-1.0, 0.0, 0.0),
			"neighbor_offset": Vector3i(-1, 0, 0),
			"vertices": [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.0, 1.0), Vector3(0.0, 0.0, 1.0)]
		}
	],
	BlockShape.OUTER_CORNER_SOUTH_EAST: [
		{
			"normal": Vector3(0.0, 0.0, 1.0),
			"neighbor_offset": Vector3i(0, 0, 1),
			"vertices": [Vector3(1.0, 0.0, 1.0), Vector3(0.0, 0.0, 1.0), Vector3(1.0, 1.0, 1.0)]
		},
		{
			"normal": Vector3(1.0, 0.0, 0.0),
			"neighbor_offset": Vector3i(1, 0, 0),
			"vertices": [Vector3(1.0, 0.0, 1.0), Vector3(1.0, 1.0, 1.0), Vector3(1.0, 0.0, 0.0)]
		}
	]
}

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

## Grass Ramps (Surface Layer)
const BLOCK_ID_GRASS_RAMP_NORTH: int = 8
const BLOCK_ID_GRASS_RAMP_SOUTH: int = 9
const BLOCK_ID_GRASS_RAMP_EAST: int = 10
const BLOCK_ID_GRASS_RAMP_WEST: int = 11

## Dirt Ramps
const BLOCK_ID_DIRT_RAMP_NORTH: int = 12
const BLOCK_ID_DIRT_RAMP_SOUTH: int = 13
const BLOCK_ID_DIRT_RAMP_EAST: int = 14
const BLOCK_ID_DIRT_RAMP_WEST: int = 15

## Stone Ramps
const BLOCK_ID_STONE_RAMP_NORTH: int = 16
const BLOCK_ID_STONE_RAMP_SOUTH: int = 17
const BLOCK_ID_STONE_RAMP_EAST: int = 18
const BLOCK_ID_STONE_RAMP_WEST: int = 19

## Sand Ramps
const BLOCK_ID_SAND_RAMP_NORTH: int = 20
const BLOCK_ID_SAND_RAMP_SOUTH: int = 21
const BLOCK_ID_SAND_RAMP_EAST: int = 22
const BLOCK_ID_SAND_RAMP_WEST: int = 23

## Grass Inner Corner Slopes (IDs 24..27)
const BLOCK_ID_GRASS_INNER_CORNER_NW: int = 24
const BLOCK_ID_GRASS_INNER_CORNER_NE: int = 25
const BLOCK_ID_GRASS_INNER_CORNER_SW: int = 26
const BLOCK_ID_GRASS_INNER_CORNER_SE: int = 27

## Dirt Inner Corner Slopes (IDs 28..31)
const BLOCK_ID_DIRT_INNER_CORNER_NW: int = 28
const BLOCK_ID_DIRT_INNER_CORNER_NE: int = 29
const BLOCK_ID_DIRT_INNER_CORNER_SW: int = 30
const BLOCK_ID_DIRT_INNER_CORNER_SE: int = 31

## Stone Inner Corner Slopes (IDs 32..35)
const BLOCK_ID_STONE_INNER_CORNER_NW: int = 32
const BLOCK_ID_STONE_INNER_CORNER_NE: int = 33
const BLOCK_ID_STONE_INNER_CORNER_SW: int = 34
const BLOCK_ID_STONE_INNER_CORNER_SE: int = 35

## Sand Inner Corner Slopes (IDs 36..39)
const BLOCK_ID_SAND_INNER_CORNER_NW: int = 36
const BLOCK_ID_SAND_INNER_CORNER_NE: int = 37
const BLOCK_ID_SAND_INNER_CORNER_SW: int = 38
const BLOCK_ID_SAND_INNER_CORNER_SE: int = 39

## Grass Outer Corner Slopes (IDs 40..43)
const BLOCK_ID_GRASS_OUTER_CORNER_NW: int = 40
const BLOCK_ID_GRASS_OUTER_CORNER_NE: int = 41
const BLOCK_ID_GRASS_OUTER_CORNER_SW: int = 42
const BLOCK_ID_GRASS_OUTER_CORNER_SE: int = 43

## Dirt Outer Corner Slopes (IDs 44..47)
const BLOCK_ID_DIRT_OUTER_CORNER_NW: int = 44
const BLOCK_ID_DIRT_OUTER_CORNER_NE: int = 45
const BLOCK_ID_DIRT_OUTER_CORNER_SW: int = 46
const BLOCK_ID_DIRT_OUTER_CORNER_SE: int = 47

## Stone Outer Corner Slopes (IDs 48..51)
const BLOCK_ID_STONE_OUTER_CORNER_NW: int = 48
const BLOCK_ID_STONE_OUTER_CORNER_NE: int = 49
const BLOCK_ID_STONE_OUTER_CORNER_SW: int = 50
const BLOCK_ID_STONE_OUTER_CORNER_SE: int = 51

## Sand Outer Corner Slopes (IDs 52..55)
const BLOCK_ID_SAND_OUTER_CORNER_NW: int = 52
const BLOCK_ID_SAND_OUTER_CORNER_NE: int = 53
const BLOCK_ID_SAND_OUTER_CORNER_SW: int = 54
const BLOCK_ID_SAND_OUTER_CORNER_SE: int = 55

## -----------------------------------------------------------------------------
## World Generation Defaults
## -----------------------------------------------------------------------------
const DEFAULT_WORLD_SEED: int = 1337
const DEFAULT_LOAD_RADIUS_CHUNKS: int = 4
const DEFAULT_TERRAIN_BASE_HEIGHT: int = 10
const DEFAULT_TERRAIN_HEIGHT_VARIATION: int = 12
const DEFAULT_DIRT_LAYER_THICKNESS: int = 3
const DEFAULT_NOISE_FREQUENCY: float = 0.01
const DEFAULT_NOISE_OCTAVES: int = 2
const DEFAULT_NOISE_LACUNARITY: float = 2.0
const DEFAULT_NOISE_GAIN: float = 0.2

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
