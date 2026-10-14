class_name BlockRegistry
extends RefCounted

## -----------------------------------------------------------------------------
## Named Color Constants for Default Block Palette
## -----------------------------------------------------------------------------
const COLOR_AIR: Color = Color(0.0, 0.0, 0.0, 0.0)
const COLOR_STONE: Color = Color(0.52, 0.52, 0.54, 1.0)
const COLOR_DIRT: Color = Color(0.45, 0.30, 0.18, 1.0)
const COLOR_GRASS_TOP: Color = Color(0.28, 0.65, 0.22, 1.0)
const COLOR_GRASS_SIDE: Color = Color(0.42, 0.42, 0.20, 1.0)
const COLOR_SAND: Color = Color(0.86, 0.80, 0.54, 1.0)
const COLOR_WOOD_SIDE: Color = Color(0.40, 0.26, 0.13, 1.0)
const COLOR_WOOD_TOP: Color = Color(0.62, 0.48, 0.29, 1.0)
const COLOR_LEAVES: Color = Color(0.18, 0.52, 0.16, 1.0)
const COLOR_BEDROCK: Color = Color(0.18, 0.18, 0.20, 1.0)

## Hardness values for default block palette
const HARDNESS_INSTANT: float = 0.0
const HARDNESS_SOFT: float = 0.5
const HARDNESS_MEDIUM: float = 1.0
const HARDNESS_HARD: float = 2.5
const HARDNESS_INDESTRUCTIBLE: float = 99999.0

## -----------------------------------------------------------------------------
## Storage
## -----------------------------------------------------------------------------
var _blocks_by_id: Dictionary = {}
var _air_definition: BlockDefinition = null

func _init() -> void:
	_register_default_palette()
	_register_ramp_palette()

## Registers a custom block definition into the registry.
func register_block(definition: BlockDefinition) -> void:
	_blocks_by_id[definition.id] = definition
	if definition.id == Constants.BLOCK_ID_AIR:
		_air_definition = definition

## Retrieves a block definition by its integer ID. Returns Air if ID is unknown.
func get_block(id: int) -> BlockDefinition:
	if _blocks_by_id.has(id):
		return _blocks_by_id[id]
	return _air_definition

## Returns whether the block at id is solid.
func is_solid(id: int) -> bool:
	return get_block(id).is_solid

## Returns whether the block at id is transparent to neighboring faces.
func is_transparent(id: int) -> bool:
	return get_block(id).is_transparent

## Returns whether the block at id is a full opaque cube.
func is_full_cube(id: int) -> bool:
	var def: BlockDefinition = get_block(id)
	return def.is_solid and def.shape == Constants.BlockShape.CUBE and not def.is_transparent

## Returns whether a face directed towards neighbor_id is completely occluded by that neighbor.
func is_face_occluded_by(neighbor_id: int, from_face: Constants.CubeFace) -> bool:
	var neighbor_def: BlockDefinition = get_block(neighbor_id)
	if not neighbor_def.is_solid:
		return false
	if neighbor_def.shape == Constants.BlockShape.CUBE:
		return not neighbor_def.is_transparent

	# Neighbor is a directional ramp:
	# 1. Ramp bottom is on -Y (horizontal plane y=0), so looking UP (+Y) into ramp bottom is occluded.
	if from_face == Constants.CubeFace.TOP:
		return true

	# 2. Ramp back wall is a full 1x1 quad. Occluded if looking directly into the back wall.
	match neighbor_def.shape:
		Constants.BlockShape.RAMP_NORTH:
			return from_face == Constants.CubeFace.NORTH
		Constants.BlockShape.RAMP_SOUTH:
			return from_face == Constants.CubeFace.SOUTH
		Constants.BlockShape.RAMP_EAST:
			return from_face == Constants.CubeFace.EAST
		Constants.BlockShape.RAMP_WEST:
			return from_face == Constants.CubeFace.WEST

	return false

## Checks if an ID has been registered.
func has_block(id: int) -> bool:
	return _blocks_by_id.has(id)

## Returns an array of all registered block definitions.
func get_all_blocks() -> Array:
	return _blocks_by_id.values()

## Initializes standard block definitions.
func _register_default_palette() -> void:
	# 0: Air
	var air: BlockDefinition = BlockDefinition.new()
	air.id = Constants.BLOCK_ID_AIR
	air.name = &"Air"
	air.is_solid = false
	air.is_transparent = true
	air.hardness = HARDNESS_INSTANT
	air.top_color = COLOR_AIR
	air.bottom_color = COLOR_AIR
	air.side_color = COLOR_AIR
	register_block(air)

	# 1: Stone
	var stone: BlockDefinition = BlockDefinition.new()
	stone.id = Constants.BLOCK_ID_STONE
	stone.name = &"Stone"
	stone.is_solid = true
	stone.is_transparent = false
	stone.hardness = HARDNESS_HARD
	stone.top_color = COLOR_STONE
	stone.bottom_color = COLOR_STONE
	stone.side_color = COLOR_STONE
	register_block(stone)

	# 2: Dirt
	var dirt: BlockDefinition = BlockDefinition.new()
	dirt.id = Constants.BLOCK_ID_DIRT
	dirt.name = &"Dirt"
	dirt.is_solid = true
	dirt.is_transparent = false
	dirt.hardness = HARDNESS_SOFT
	dirt.top_color = COLOR_DIRT
	dirt.bottom_color = COLOR_DIRT
	dirt.side_color = COLOR_DIRT
	register_block(dirt)

	# 3: Grass
	var grass: BlockDefinition = BlockDefinition.new()
	grass.id = Constants.BLOCK_ID_GRASS
	grass.name = &"Grass"
	grass.is_solid = true
	grass.is_transparent = false
	grass.hardness = HARDNESS_SOFT
	grass.top_color = COLOR_GRASS_TOP
	grass.bottom_color = COLOR_DIRT
	grass.side_color = COLOR_GRASS_SIDE
	register_block(grass)

	# 4: Sand
	var sand: BlockDefinition = BlockDefinition.new()
	sand.id = Constants.BLOCK_ID_SAND
	sand.name = &"Sand"
	sand.is_solid = true
	sand.is_transparent = false
	sand.hardness = HARDNESS_SOFT
	sand.top_color = COLOR_SAND
	sand.bottom_color = COLOR_SAND
	sand.side_color = COLOR_SAND
	register_block(sand)

	# 5: Wood
	var wood: BlockDefinition = BlockDefinition.new()
	wood.id = Constants.BLOCK_ID_WOOD
	wood.name = &"Wood"
	wood.is_solid = true
	wood.is_transparent = false
	wood.hardness = HARDNESS_MEDIUM
	wood.top_color = COLOR_WOOD_TOP
	wood.bottom_color = COLOR_WOOD_TOP
	wood.side_color = COLOR_WOOD_SIDE
	register_block(wood)

	# 6: Leaves
	var leaves: BlockDefinition = BlockDefinition.new()
	leaves.id = Constants.BLOCK_ID_LEAVES
	leaves.name = &"Leaves"
	leaves.is_solid = true
	leaves.is_transparent = false
	leaves.hardness = HARDNESS_SOFT
	leaves.top_color = COLOR_LEAVES
	leaves.bottom_color = COLOR_LEAVES
	leaves.side_color = COLOR_LEAVES
	register_block(leaves)

	# 7: Bedrock
	var bedrock: BlockDefinition = BlockDefinition.new()
	bedrock.id = Constants.BLOCK_ID_BEDROCK
	bedrock.name = &"Bedrock"
	bedrock.is_solid = true
	bedrock.is_transparent = false
	bedrock.hardness = HARDNESS_INDESTRUCTIBLE
	bedrock.top_color = COLOR_BEDROCK
	bedrock.bottom_color = COLOR_BEDROCK
	register_block(bedrock)

## Registers directional ramp definitions for all standard terrain materials.
func _register_ramp_palette() -> void:
	var ramp_shapes: Array[Constants.BlockShape] = [
		Constants.BlockShape.RAMP_NORTH,
		Constants.BlockShape.RAMP_SOUTH,
		Constants.BlockShape.RAMP_EAST,
		Constants.BlockShape.RAMP_WEST
	]
	var dir_names: Array[String] = ["North", "South", "East", "West"]

	# Grass Ramps (IDs 8..11)
	for i: int in range(4):
		var def: BlockDefinition = BlockDefinition.new()
		def.id = Constants.BLOCK_ID_GRASS_RAMP_NORTH + i
		def.name = StringName("Grass Ramp " + dir_names[i])
		def.is_solid = true
		def.is_transparent = true
		def.shape = ramp_shapes[i]
		def.base_block_id = Constants.BLOCK_ID_GRASS
		def.hardness = HARDNESS_SOFT
		def.top_color = COLOR_GRASS_TOP
		def.bottom_color = COLOR_DIRT
		def.side_color = COLOR_GRASS_SIDE
		register_block(def)

	# Dirt Ramps (IDs 12..15)
	for i: int in range(4):
		var def: BlockDefinition = BlockDefinition.new()
		def.id = Constants.BLOCK_ID_DIRT_RAMP_NORTH + i
		def.name = StringName("Dirt Ramp " + dir_names[i])
		def.is_solid = true
		def.is_transparent = true
		def.shape = ramp_shapes[i]
		def.base_block_id = Constants.BLOCK_ID_DIRT
		def.hardness = HARDNESS_SOFT
		def.top_color = COLOR_DIRT
		def.bottom_color = COLOR_DIRT
		def.side_color = COLOR_DIRT
		register_block(def)

	# Stone Ramps (IDs 16..19)
	for i: int in range(4):
		var def: BlockDefinition = BlockDefinition.new()
		def.id = Constants.BLOCK_ID_STONE_RAMP_NORTH + i
		def.name = StringName("Stone Ramp " + dir_names[i])
		def.is_solid = true
		def.is_transparent = true
		def.shape = ramp_shapes[i]
		def.base_block_id = Constants.BLOCK_ID_STONE
		def.hardness = HARDNESS_HARD
		def.top_color = COLOR_STONE
		def.bottom_color = COLOR_STONE
		def.side_color = COLOR_STONE
		register_block(def)

	# Sand Ramps (IDs 20..23)
	for i: int in range(4):
		var def: BlockDefinition = BlockDefinition.new()
		def.id = Constants.BLOCK_ID_SAND_RAMP_NORTH + i
		def.name = StringName("Sand Ramp " + dir_names[i])
		def.is_solid = true
		def.is_transparent = true
		def.shape = ramp_shapes[i]
		def.base_block_id = Constants.BLOCK_ID_SAND
		def.hardness = HARDNESS_SOFT
		def.top_color = COLOR_SAND
		def.bottom_color = COLOR_SAND
		def.side_color = COLOR_SAND
		register_block(def)

