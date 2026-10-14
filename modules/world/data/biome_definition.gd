class_name BiomeDefinition
extends Resource

## -----------------------------------------------------------------------------
## Biome Layer & Strata Configuration
## -----------------------------------------------------------------------------
@export var biome_name: StringName = &"Plains"
@export var surface_block_id: int = Constants.BLOCK_ID_GRASS
@export var subsurface_block_id: int = Constants.BLOCK_ID_DIRT
@export var deep_block_id: int = Constants.BLOCK_ID_STONE
@export var bedrock_block_id: int = Constants.BLOCK_ID_BEDROCK

@export var subsurface_depth_layers: int = Constants.DEFAULT_DIRT_LAYER_THICKNESS
@export var base_elevation_voxels: int = Constants.DEFAULT_TERRAIN_BASE_HEIGHT
@export var elevation_amplitude_voxels: int = Constants.DEFAULT_TERRAIN_HEIGHT_VARIATION
