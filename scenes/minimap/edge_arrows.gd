extends Control
## Shows triangular arrows at minimap edges pointing to off-screen markers.
## Uses custom _draw() for triangle rendering.

var minimap: Control = null
var edge_padding: float = 12.0  # Distance from edge
var edge_inset: float = 0.95  # 0.0 = at edges, 1.0 = at center (player arrow)

# Color scheme by marker type
const MARKER_COLORS := {
	"default": Color(1.0, 1.0, 0.0),   # Yellow
	"enemy": Color(1.0, 0.3, 0.3),     # Red
	"friendly": Color(0.3, 1.0, 0.3),  # Green
	"loot": Color(1.0, 1.0, 0.0),      # Yellow (matches pellets)
	"objective": Color(1.0, 0.9, 0.2), # Yellow
}
var waypoint_color: Color = Color(0.8, 0.5, 1.0)  # Purple

# Arrow data for drawing
var _arrows_to_draw: Array[Dictionary] = []  # {position, angle, color}
var _waypoint_to_draw: Dictionary = {}  # {position, color, visible}

const MAX_ARROWS := 20
const ARROW_SIZE := 10.0  # Triangle size

func _process(_delta: float) -> void:
	_update_arrows()
	queue_redraw()

func _draw() -> void:
	# Draw all arrows as triangles
	for arrow_data in _arrows_to_draw:
		_draw_triangle(arrow_data.position, arrow_data.angle, arrow_data.color)

	# Draw waypoint diamond
	if _waypoint_to_draw.get("visible", false):
		_draw_diamond(_waypoint_to_draw.position, _waypoint_to_draw.color)

func _draw_triangle(pos: Vector2, angle: float, color: Color) -> void:
	# Triangle pointing right, rotated by angle
	var points := PackedVector2Array()
	var tip := Vector2(ARROW_SIZE, 0).rotated(angle)
	var left := Vector2(-ARROW_SIZE * 0.6, -ARROW_SIZE * 0.5).rotated(angle)
	var right := Vector2(-ARROW_SIZE * 0.6, ARROW_SIZE * 0.5).rotated(angle)

	points.append(pos + tip)
	points.append(pos + left)
	points.append(pos + right)

	draw_colored_polygon(points, color)

func _draw_diamond(pos: Vector2, color: Color) -> void:
	var s := ARROW_SIZE * 0.8
	var points := PackedVector2Array()
	points.append(pos + Vector2(0, -s))  # Top
	points.append(pos + Vector2(s, 0))   # Right
	points.append(pos + Vector2(0, s))   # Bottom
	points.append(pos + Vector2(-s, 0))  # Left

	draw_colored_polygon(points, color)

func _update_arrows() -> void:
	_arrows_to_draw.clear()
	_waypoint_to_draw = {"visible": false}

	if not minimap or not minimap.player:
		return

	var map_center := size / 2.0
	var player_pos: Vector3 = minimap.player.global_position
	var scale_factor: float = size.x / minimap.camera_ortho_size

	# Update POI arrows (static markers)
	for marker_id in minimap._markers:
		if _arrows_to_draw.size() >= MAX_ARROWS:
			break
		_check_marker_visibility(minimap._markers[marker_id], map_center, player_pos, scale_factor)

	# Update tracked marker arrows (enemies, collectibles)
	for marker_id in minimap._tracked_markers:
		if _arrows_to_draw.size() >= MAX_ARROWS:
			break
		_check_marker_visibility(minimap._tracked_markers[marker_id], map_center, player_pos, scale_factor)

	# Update waypoint diamond
	_update_waypoint_indicator(map_center, player_pos, scale_factor)

func _check_marker_visibility(marker_data: Dictionary, map_center: Vector2, player_pos: Vector3, scale_factor: float) -> void:
	var marker_node: Node3D = marker_data.node
	if not marker_node:
		return

	# Get marker type for coloring
	var marker_type: String = marker_data.get("type", "default")

	# Check if this is a loot marker and respect visibility settings
	if marker_type == "loot":
		# Check if resource markers are disabled
		if not minimap.show_resource_markers:
			return
		# Check if the 3D marker is visible (respects proximity distance)
		if marker_node.has_method("get") and not marker_node.get("_is_visible_by_distance"):
			return

	var world_pos := marker_node.global_position
	var offset := world_pos - player_pos
	var map_offset := Vector2(offset.x, offset.z) * scale_factor
	var marker_screen_pos := map_center + map_offset

	var marker_visible := (
		marker_screen_pos.x >= 0 and
		marker_screen_pos.x <= size.x and
		marker_screen_pos.y >= 0 and
		marker_screen_pos.y <= size.y
	)

	if not marker_visible:
		var direction := (marker_screen_pos - map_center).normalized()
		var edge_pos := _get_edge_intersection(map_center, direction)
		var angle := direction.angle()
		var color: Color = MARKER_COLORS.get(marker_type, MARKER_COLORS["default"])

		_arrows_to_draw.append({
			"position": edge_pos,
			"angle": angle,
			"color": color
		})

func _get_edge_intersection(center: Vector2, direction: Vector2) -> Vector2:
	# Apply edge_inset: 0.0 = full size (edges), 0.5 = halfway to center
	var inset_factor := 1.0 - edge_inset
	var half_size := (size / 2.0 - Vector2(edge_padding, edge_padding)) * inset_factor
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

func _update_waypoint_indicator(map_center: Vector2, player_pos: Vector3, scale_factor: float) -> void:
	if minimap._active_waypoint_id == -1 or minimap._active_waypoint_id not in minimap._waypoints:
		_waypoint_to_draw = {"visible": false}
		return

	var waypoint_data: Dictionary = minimap._waypoints[minimap._active_waypoint_id]
	var waypoint_pos: Vector3 = waypoint_data.position
	var wp_color: Color = waypoint_data.get("color", waypoint_color)

	var offset := waypoint_pos - player_pos
	var map_offset := Vector2(offset.x, offset.z) * scale_factor
	var waypoint_screen_pos := map_center + map_offset

	var waypoint_visible := (
		waypoint_screen_pos.x >= 0 and
		waypoint_screen_pos.x <= size.x and
		waypoint_screen_pos.y >= 0 and
		waypoint_screen_pos.y <= size.y
	)

	if waypoint_visible:
		_waypoint_to_draw = {"visible": false}
		return

	var direction := (waypoint_screen_pos - map_center).normalized()
	var edge_pos := _get_edge_intersection(map_center, direction)

	_waypoint_to_draw = {
		"position": edge_pos,
		"color": wp_color,
		"visible": true
	}
