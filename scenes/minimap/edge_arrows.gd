extends Control
## Draws arrows at minimap edges pointing to off-screen POI markers.

var minimap: Control = null
var arrow_color: Color = Color(1.0, 1.0, 0.0)  # Yellow
var arrow_size: float = 7.5  # Arrow size
var edge_padding: float = 12.0  # Distance from edge

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not minimap or not minimap.player:
		return

	var map_center := size / 2.0
	var player_pos: Vector3 = minimap.player.global_position
	# camera_ortho_size is the full diameter, not radius
	var scale_factor: float = size.x / minimap.camera_ortho_size

	for marker_id in minimap._markers:
		var marker_data: Dictionary = minimap._markers[marker_id]
		var marker_node: Node3D = marker_data.node
		if not marker_node:
			continue

		var world_pos := marker_node.global_position
		var offset := world_pos - player_pos
		# Map 3D offset to 2D: X stays same, Z maps to Y
		# World -Z (north) should map to screen -Y (up), so use offset.z directly
		# (negative Z offset -> negative screen Y offset -> above center)
		var map_offset := Vector2(offset.x, offset.z) * scale_factor
		var marker_screen_pos := map_center + map_offset

		# Arrow shows until marker enters the minimap viewport
		var is_visible := (
			marker_screen_pos.x >= 0 and
			marker_screen_pos.x <= size.x and
			marker_screen_pos.y >= 0 and
			marker_screen_pos.y <= size.y
		)

		if not is_visible:
			_draw_edge_arrow(map_center, marker_screen_pos)

func _draw_edge_arrow(center: Vector2, target: Vector2) -> void:
	# Calculate direction to target
	var direction := (target - center).normalized()

	# Find intersection with minimap edge
	var edge_pos := _get_edge_intersection(center, direction)

	# Draw arrow pointing outward
	var angle := direction.angle()

	# Simple triangle arrow with tip at edge pointing toward POI
	var arrow_points := PackedVector2Array([
		edge_pos,  # Tip at edge
		edge_pos + Vector2(-arrow_size * 1.2, -arrow_size * 0.5).rotated(angle),  # Back left
		edge_pos + Vector2(-arrow_size * 1.2, arrow_size * 0.5).rotated(angle),  # Back right
	])

	# Draw shadow
	var shadow_offset := Vector2(1, 1)
	var shadow_points := PackedVector2Array()
	for p in arrow_points:
		shadow_points.append(p + shadow_offset)
	draw_colored_polygon(shadow_points, Color(0, 0, 0, 0.5))

	# Draw arrow
	draw_colored_polygon(arrow_points, arrow_color)

func _get_edge_intersection(center: Vector2, direction: Vector2) -> Vector2:
	# Find where the ray from center in direction intersects the minimap edge
	var half_size := size / 2.0 - Vector2(edge_padding, edge_padding)

	# Calculate t for each edge
	var t_values: Array[float] = []

	if direction.x != 0:
		var t_right := (half_size.x) / direction.x
		var t_left := (-half_size.x) / direction.x
		if t_right > 0:
			t_values.append(t_right)
		if t_left > 0:
			t_values.append(t_left)

	if direction.y != 0:
		var t_bottom := (half_size.y) / direction.y
		var t_top := (-half_size.y) / direction.y
		if t_bottom > 0:
			t_values.append(t_bottom)
		if t_top > 0:
			t_values.append(t_top)

	if t_values.is_empty():
		return center

	# Find the smallest positive t that keeps us in bounds
	var min_t: float = INF
	for t in t_values:
		var test_pos := center + direction * t
		if test_pos.x >= edge_padding and test_pos.x <= size.x - edge_padding:
			if test_pos.y >= edge_padding and test_pos.y <= size.y - edge_padding:
				if t < min_t:
					min_t = t

	if min_t == INF:
		min_t = t_values.min()

	return center + direction * min_t
