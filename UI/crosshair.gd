class_name CrosshairUI
extends Control

## -----------------------------------------------------------------------------
## Named Styling Constants
## -----------------------------------------------------------------------------
const CROSSHAIR_SIZE_PIXELS: float = 6.0
const CROSSHAIR_THICKNESS_PIXELS: float = 2.0
const CROSSHAIR_COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)
const CENTER_ANCHOR: float = 0.5

func _draw() -> void:
	var center: Vector2 = size * CENTER_ANCHOR
	var half_size: float = CROSSHAIR_SIZE_PIXELS * 0.5

	# Horizontal reticle bar
	var h_start: Vector2 = Vector2(center.x - half_size, center.y)
	var h_end: Vector2 = Vector2(center.x + half_size, center.y)
	draw_line(h_start, h_end, CROSSHAIR_COLOR, CROSSHAIR_THICKNESS_PIXELS)

	# Vertical reticle bar
	var v_start: Vector2 = Vector2(center.x, center.y - half_size)
	var v_end: Vector2 = Vector2(center.x, center.y + half_size)
	draw_line(v_start, v_end, CROSSHAIR_COLOR, CROSSHAIR_THICKNESS_PIXELS)
