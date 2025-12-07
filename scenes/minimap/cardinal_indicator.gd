extends Control
## Draws cardinal direction indicators (N/S/E/W) on the minimap border.

@export var show_all_directions: bool = true  # Show N/S/E/W or just N
@export var font_size: int = 14
@export var text_color: Color = Color(1, 1, 1, 0.8)
@export var north_color: Color = Color(1, 0.3, 0.3, 1)  # Red for North

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var center := size / 2
	var radius := minf(size.x, size.y) / 2 - 16  # Inset from edge

	# Draw North (always) - same color as others for consistency
	_draw_cardinal("N", center + Vector2(0, -radius + 18), text_color)

	if show_all_directions:
		_draw_cardinal("E", center + Vector2(radius - 4, 14), text_color)
		_draw_cardinal("S", center + Vector2(0, radius + 10), text_color)
		_draw_cardinal("W", center + Vector2(-radius + 4, 14), text_color)

func _draw_cardinal(letter: String, pos: Vector2, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var draw_pos := pos - text_size / 2

	# Draw shadow for readability
	draw_string(font, draw_pos + Vector2(1, 1), letter, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0, 0, 0, 0.5))
	# Draw letter
	draw_string(font, draw_pos, letter, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
