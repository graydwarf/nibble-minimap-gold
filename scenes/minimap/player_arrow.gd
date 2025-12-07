extends Control
## Draws a clean vector arrow for the player marker on the minimap.

func _draw() -> void:
	var center := size / 2
	var arrow_size: float = minf(size.x, size.y) * 0.32

	# Arrow pointing up (north) - will be rotated by parent
	var points := PackedVector2Array([
		center + Vector2(0, -arrow_size),           # Tip (top)
		center + Vector2(-arrow_size * 0.6, arrow_size * 0.5),  # Bottom left
		center + Vector2(0, arrow_size * 0.2),      # Notch
		center + Vector2(arrow_size * 0.6, arrow_size * 0.5),   # Bottom right
	])

	# White fill with slight transparency
	draw_colored_polygon(points, Color(1, 1, 1, 0.95))

	# White outline for clarity
	draw_polyline(points + PackedVector2Array([points[0]]), Color(1, 1, 1, 1), 1.5, true)
