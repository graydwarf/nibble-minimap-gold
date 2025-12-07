extends Control
## Shows arrows at minimap edges pointing to off-screen POI markers and waypoints.
## Uses TextureRect nodes for web compatibility (Control-based, not Node2D).

var minimap: Control = null
var arrow_color: Color = Color(1.0, 1.0, 0.0)  # Yellow
var waypoint_color: Color = Color(0.8, 0.5, 1.0)  # Purple
var edge_padding: float = 12.0  # Distance from edge
var edge_inset: float = 0.0  # 0.0 = edges, 0.5 = halfway to center (for web testing)

# Pool of arrow TextureRects for reuse
var _arrow_pool: Array[TextureRect] = []
var _arrow_pool_index: int = 0
var _waypoint_rect: TextureRect = null

var _arrow_texture: Texture2D = null
var _diamond_texture: Texture2D = null

const MAX_ARROWS := 20  # Max simultaneous edge arrows
const ARROW_SIZE := Vector2(16, 16)
const DIAMOND_SIZE := Vector2(16, 16)

func _ready() -> void:
	# Load textures
	if ResourceLoader.exists("res://assets/icons/edge_arrow.svg"):
		_arrow_texture = load("res://assets/icons/edge_arrow.svg")
	if ResourceLoader.exists("res://assets/icons/edge_diamond.svg"):
		_diamond_texture = load("res://assets/icons/edge_diamond.svg")

	# Pre-create arrow pool using TextureRect (Control-based for web)
	for i in MAX_ARROWS:
		var arrow := TextureRect.new()
		arrow.texture = _arrow_texture
		arrow.custom_minimum_size = ARROW_SIZE
		arrow.size = ARROW_SIZE
		arrow.pivot_offset = ARROW_SIZE / 2  # Rotate around center
		arrow.visible = false
		add_child(arrow)
		_arrow_pool.append(arrow)

	# Create waypoint diamond TextureRect
	_waypoint_rect = TextureRect.new()
	_waypoint_rect.texture = _diamond_texture
	_waypoint_rect.custom_minimum_size = DIAMOND_SIZE
	_waypoint_rect.size = DIAMOND_SIZE
	_waypoint_rect.visible = false
	add_child(_waypoint_rect)

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

	# TextureRect position is top-left corner, so offset by half size
	arrow.position = edge_pos - ARROW_SIZE / 2
	arrow.rotation = angle
	arrow.modulate = arrow_color
	arrow.visible = true

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
		_waypoint_rect.visible = false
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
		_waypoint_rect.visible = false
		return

	var direction := (waypoint_screen_pos - map_center).normalized()
	var edge_pos := _get_edge_intersection(map_center, direction)

	# TextureRect position is top-left corner, so offset by half size
	_waypoint_rect.position = edge_pos - DIAMOND_SIZE / 2
	_waypoint_rect.modulate = wp_color
	_waypoint_rect.visible = true

func _hide_all() -> void:
	for arrow in _arrow_pool:
		arrow.visible = false
	if _waypoint_rect:
		_waypoint_rect.visible = false
