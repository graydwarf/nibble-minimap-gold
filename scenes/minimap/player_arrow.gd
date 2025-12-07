extends Control
## Player arrow marker on the minimap using Polygon2D for web compatibility.

var _arrow_polygon: Polygon2D = null

func _ready() -> void:
	_arrow_polygon = Polygon2D.new()
	_arrow_polygon.color = Color(1, 1, 1, 0.95)
	add_child(_arrow_polygon)
	_update_arrow()

func _process(_delta: float) -> void:
	_update_arrow()

func _update_arrow() -> void:
	if not _arrow_polygon:
		return

	var center := size / 2
	var arrow_size: float = minf(size.x, size.y) * 0.32

	# Arrow pointing up (north) - will be rotated by parent
	var points := PackedVector2Array([
		center + Vector2(0, -arrow_size),           # Tip (top)
		center + Vector2(-arrow_size * 0.6, arrow_size * 0.5),  # Bottom left
		center + Vector2(0, arrow_size * 0.2),      # Notch
		center + Vector2(arrow_size * 0.6, arrow_size * 0.5),   # Bottom right
	])

	_arrow_polygon.polygon = points
