class_name TestBlockRegistry
extends RefCounted

const ConstantsScript = preload("res://core/constants.gd")
const BlockRegistryScript = preload("res://modules/world/data/block_registry.gd")
const BlockDefinitionScript = preload("res://modules/world/data/block_definition.gd")

static func run_all() -> bool:
	var registry = BlockRegistryScript.new()

	# 1. Test Air Block
	var air = registry.get_block(ConstantsScript.BLOCK_ID_AIR)
	if air.is_solid or not air.is_transparent:
		printerr("FAIL: Air block must be non-solid and transparent")
		return false

	# 2. Test Solid Blocks
	var stone = registry.get_block(ConstantsScript.BLOCK_ID_STONE)
	if not stone.is_solid or stone.is_transparent:
		printerr("FAIL: Stone block must be solid and opaque")
		return false

	var grass = registry.get_block(ConstantsScript.BLOCK_ID_GRASS)
	if not grass.is_solid or grass.is_transparent:
		printerr("FAIL: Grass block must be solid and opaque")
		return false

	# 3. Test Unknown Block fallback
	var unknown = registry.get_block(9999)
	if unknown.id != ConstantsScript.BLOCK_ID_AIR:
		printerr("FAIL: Unknown block must fallback to Air definition")
		return false

	return true
