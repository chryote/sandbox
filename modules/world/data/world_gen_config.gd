class_name WorldGenConfig
extends Resource

## -----------------------------------------------------------------------------
## Configuration Properties
## -----------------------------------------------------------------------------
@export var world_seed: int = Constants.DEFAULT_WORLD_SEED
@export var chunk_dimensions: Vector3i = Constants.CHUNK_SIZE_VOXELS
@export var load_radius_chunks: int = Constants.DEFAULT_LOAD_RADIUS_CHUNKS
@export var lod_radius_chunks: int = 16
@export var enable_lod: bool = true
@export var enable_cave_occlusion: bool = true
@export var min_chunk_y: int = 0
@export var max_chunk_y: int = 2

@export var noise_frequency: float = Constants.DEFAULT_NOISE_FREQUENCY
@export var noise_fractal_octaves: int = Constants.DEFAULT_NOISE_OCTAVES
@export var noise_fractal_lacunarity: float = Constants.DEFAULT_NOISE_LACUNARITY
@export var noise_fractal_gain: float = Constants.DEFAULT_NOISE_GAIN

@export var enable_smoothing: bool = true
@export var enable_terrace_shaping: bool = true

@export var primary_biome: BiomeDefinition = null

func _init() -> void:
	if primary_biome == null:
		primary_biome = BiomeDefinition.new()

## Creates and returns a freshly configured FastNoiseLite instance based on this configuration.
func create_configured_noise() -> FastNoiseLite:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.frequency = noise_frequency
	noise.fractal_octaves = noise_fractal_octaves
	noise.fractal_lacunarity = noise_fractal_lacunarity
	noise.fractal_gain = noise_fractal_gain
	return noise
