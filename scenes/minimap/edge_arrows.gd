extends Control
## Shows arrows at minimap edges pointing to off-screen POI markers and waypoints.
## Uses Polygon2D nodes for web compatibility (instead of _draw()).

var minimap: Control = null
var arrow_color: Color = Color(1.0, 1.0, 0.0)  # Yellow
var waypoint_color: Color = Color(0.8, 0.5, 1.0)  # Purple
var arrow_size: float = 7.5  # Arrow size
var waypoint_size: float = 10.0  # Diamond size (larger than arrows)
var edge_padding: float = 12.0  # Distance from edge

# Pool of arrow polygons for reuse
var _arrow_pool: Array[Polygon2D] = []
var _arrow_pool_index: int = 0
var _waypoint_diamond: Polygon2D = null

const MAX_ARROWS := 20  # Max simultaneous edge arrows

func _ready() -> void:
	# Pre-create arrow pool
	for i in MAX_ARROWS:
		var arrow := Polygon2D.new()
		arrow.visible = false
		add_child(arrow)
		_arrow_pool.append(arrow)

	# Create waypoint diamond
	_waypoint_diamond = Polygon2D.new()
	_waypoint_diamond.visible = false
	add_child(_waypoint_diamond)

func _process(_delta: float) -> void:
	_update_arrows()

func _update_arrows() -> void:
	if not minimap or not minimap.player:
		_hide_all()
		return

	# Reset pool
	_arrow_pool_index = 0

	var map_center := size / 2.0
	var player_pos: Vector3 = minimap.player.global_position
	var scale_factor: float = size.x / minimap.camera_ortho_size

	# Update POI arrows
	for marker_id in minimap._markers:
		if _arrow_pool_index >= MAX_ARROWS:
			break

		var marker_data: Dictionary = minimap._markers[marker_id]
		var marker_node: Node3D = marker_data.node
		if not marker_node:
			continue

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
			_show_edge_arrow(map_center, marker_screen_pos)

	# Hide unused arrows
	for i in range(_arrow_pool_index, MAX_ARROWS):
		_arrow_pool[i].visible = false

	# Update waypoint diamond
	_update_waypoint_indicator(map_center, player_pos, scale_factor)

func _show_edge_arrow(center: Vector2, target: Vector2) -> void:
	var arrow := _arrow_pool[_arrow_pool_index]
	_arrow_pool_index += 1

	var direction := (target - center).normalized()
	var edge_pos := _get_edge_intersection(center, direction)
	var angle := direction.angle()

	# Triangle arrow pointing toward POI
	var points := PackedVector2Array([
		Vector2(0, 0),  # Tip
		Vector2(-arrow_size * 1.2, -arrow_size * 0.5),  # Back left
		Vector2(-arrow_size * 1.2, arrow_size * 0.5),  # Back right
	])

	arrow.polygon = points
	arrow.color = arrow_color
	arrow.position = edge_pos
	arrow.rotation = angle
	arrow.visible = true

func _get_edge_intersection(center: Vector2, direction: Vector2) -> Vector2:
	var half_size := size / 2.0 - Vector2(edge_padding, edge_padding)
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
		_waypoint_diamond.visible = false
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
		_waypoint_diamond.visible = false
		return

	var direction := (waypoint_screen_pos - map_center).normalized()
	var edge_pos := _get_edge_intersection(map_center, direction)

	# Diamond shape centered at origin
	var half := waypoint_size * 0.5
	var diamond_points := PackedVector2Array([
		Vector2(0, -half),   # Top
		Vector2(half, 0),    # Right
		Vector2(0, half),    # Bottom
		Vector2(-half, 0),   # Left
	])

	_waypoint_diamond.polygon = diamond_points
	_waypoint_diamond.color = wp_color
	_waypoint_diamond.position = edge_pos
	_waypoint_diamond.visible = true

func _hide_all() -> void:
	for arrow in _arrow_pool:
		arrow.visible = false
	_waypoint_diamond.visible = false
