class_name BlockDefinition
extends Resource

## -----------------------------------------------------------------------------
## Block Properties
## -----------------------------------------------------------------------------
@export var id: int = Constants.BLOCK_ID_AIR
@export var name: StringName = &"Air"
@export var is_solid: bool = false
@export var is_transparent: bool = true
@export var hardness: float = 1.0
@export var shape: Constants.BlockShape = Constants.BlockShape.CUBE
@export var base_block_id: int = Constants.BLOCK_ID_AIR

var is_straight_ramp: bool:
	get:
		return shape >= Constants.BlockShape.RAMP_NORTH and shape <= Constants.BlockShape.RAMP_WEST

var is_inner_corner: bool:
	get:
		return shape >= Constants.BlockShape.INNER_CORNER_NORTH_WEST and shape <= Constants.BlockShape.INNER_CORNER_SOUTH_EAST

var is_outer_corner: bool:
	get:
		return shape >= Constants.BlockShape.OUTER_CORNER_NORTH_WEST and shape <= Constants.BlockShape.OUTER_CORNER_SOUTH_EAST

var is_ramp: bool:
	get:
		return shape != Constants.BlockShape.CUBE

## Face-specific vertex tinting colors (used for clean shading and debugging)
@export var top_color: Color = Color.WHITE
@export var bottom_color: Color = Color.WHITE
@export var side_color: Color = Color.WHITE

## -----------------------------------------------------------------------------
## Accessors
## -----------------------------------------------------------------------------
func get_face_color(face: Constants.CubeFace) -> Color:
	match face:
		Constants.CubeFace.TOP:
			return top_color
		Constants.CubeFace.BOTTOM:
			return bottom_color
		_:
			return side_color
