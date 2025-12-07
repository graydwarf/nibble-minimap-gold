extends Control
## Mini-map component that renders a top-down view of the world.
## Configurable size, position, corner placement, and camera view modes.

enum ScreenCorner { TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT, CUSTOM }
enum MapView { TOP_DOWN, ANGLED_25D, PERSPECTIVE_3D }

@export var map_size: Vector2i = Vector2i(200, 200):
	set(value):
		map_size = value
		_update_size()

@export var screen_corner: ScreenCorner = ScreenCorner.TOP_RIGHT:
	set(value):
		screen_corner = value
		_update_position()

@export var margin: Vector2 = Vector2(16, 16):
	set(value):
		margin = value
		_update_position()

@export var custom_position: Vector2 = Vector2.ZERO:
	set(value):
		custom_position = value
		if screen_corner == ScreenCorner.CUSTOM:
			_update_position()

@export var map_view: MapView = MapView.TOP_DOWN:
	set(value):
		map_view = value
		_setup_camera()

@export var camera_height: float = 50.0
@export var camera_ortho_size: float = 30.0
@export var camera_fov: float = 60.0  # For perspective mode

@export var show_cardinal_directions: bool = true
@export var show_all_cardinals: bool = true  # N only vs N/S/E/W

@export_range(0.0, 1.0) var opacity: float = 0.85:  # 15% transparent by default
	set(value):
		opacity = value
		_update_opacity()

@export var scale_markers_by_distance: bool = true
@export var marker_scale_min: float = 0.5  # Scale at max distance
@export var marker_scale_max: float = 1.2  # Scale at min distance
@export var marker_distance_near: float = 10.0  # Distance for max scale
@export var marker_distance_far: float = 50.0  # Distance for min scale

@export_group("Zoom")
@export var zoom_enabled: bool = true
@export var zoom_min: float = 15.0  # Closest zoom (smaller ortho size)
@export var zoom_max: float = 60.0  # Farthest zoom (larger ortho size)
@export var zoom_step: float = 5.0  # Amount to zoom per scroll

# Marker type colors
const MARKER_COLORS := {
	"default": Color.WHITE,
	"enemy": Color(1.0, 0.3, 0.3),      # Red
	"friendly": Color(0.3, 1.0, 0.3),   # Green
	"objective": Color(1.0, 0.9, 0.2),  # Yellow
	"loot": Color(0.3, 0.7, 1.0),       # Blue
	"waypoint": Color(0.8, 0.5, 1.0),   # Purple
}

# Reference to player for camera tracking
var player: Node3D = null

# POI marker tracking: id -> { node: Node3D, type: String }
var _markers: Dictionary = {}
var _next_marker_id: int = 0
var _world_root: Node3D = null  # Where 3D markers get added

@onready var viewport_container: SubViewportContainer = $SubViewportContainer
@onready var sub_viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var minimap_camera: Camera3D = $SubViewportContainer/SubViewport/MinimapCamera
@onready var shadow: Panel = $Shadow

var player_marker: Control = null
var cardinal_indicator: Control = null
var edge_arrows: Control = null

func _ready() -> void:
	_update_size()
	_update_position()
	_update_opacity()
	_setup_camera()
	_create_player_marker()
	_create_cardinal_indicator()
	_create_edge_arrows()
	# Handle viewport resize (fullscreen, window resize)
	get_tree().root.size_changed.connect(_update_position)

func _process(_delta: float) -> void:
	if player:
		_update_camera_position()
		_update_player_marker()

func _gui_input(event: InputEvent) -> void:
	if not zoom_enabled:
		return

	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_in()
				accept_event()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_out()
				accept_event()

# Zooms in (decreases ortho size, shows less area)
func zoom_in() -> void:
	camera_ortho_size = maxf(camera_ortho_size - zoom_step, zoom_min)
	_setup_camera()

# Zooms out (increases ortho size, shows more area)
func zoom_out() -> void:
	camera_ortho_size = minf(camera_ortho_size + zoom_step, zoom_max)
	_setup_camera()

# Sets zoom level directly (clamped to min/max)
func set_zoom(ortho_size: float) -> void:
	camera_ortho_size = clampf(ortho_size, zoom_min, zoom_max)
	_setup_camera()

func set_player(player_node: Node3D) -> void:
	player = player_node
	# Find world root for 3D markers (player's parent or scene root)
	if player:
		_world_root = player.get_parent() as Node3D
		if not _world_root:
			_world_root = get_tree().root.get_child(0) as Node3D

# Adds a POI marker at the given world position. Returns marker ID.
func add_marker(world_position: Vector3, marker_type: String = "default", _label: String = "") -> int:
	if not _world_root:
		push_warning("Minimap: No world root set. Call set_player first.")
		return -1

	var marker_id := _next_marker_id
	_next_marker_id += 1

	# Create 3D marker node
	var marker_node := Node3D.new()
	marker_node.name = "POIMarker_%d" % marker_id
	marker_node.set_script(preload("res://scenes/minimap/poi_marker_3d.gd"))

	var color: Color = MARKER_COLORS.get(marker_type, Color.WHITE)
	marker_node.marker_color = color
	marker_node.marker_type = marker_type

	# Add to tree first, then set position
	_world_root.add_child(marker_node)
	marker_node.global_position = world_position

	_markers[marker_id] = {
		"node": marker_node,
		"type": marker_type
	}

	return marker_id

# Removes a marker by ID
func remove_marker(marker_id: int) -> void:
	if marker_id in _markers:
		var marker_data: Dictionary = _markers[marker_id]
		if marker_data.node:
			marker_data.node.queue_free()
		_markers.erase(marker_id)

# Updates an existing marker's position
func update_marker_position(marker_id: int, world_position: Vector3) -> void:
	if marker_id in _markers:
		var marker_node: Node3D = _markers[marker_id].node
		if marker_node:
			marker_node.global_position = world_position

# Clears all markers
func clear_markers() -> void:
	for marker_id in _markers.keys():
		remove_marker(marker_id)
	_markers.clear()

# Sets the camera view mode at runtime
func set_view_mode(mode: MapView) -> void:
	map_view = mode

# Cycles through view modes: TOP_DOWN -> ANGLED_25D -> PERSPECTIVE_3D -> TOP_DOWN
func cycle_view_mode() -> void:
	map_view = (map_view + 1) % MapView.size() as MapView

func _setup_camera() -> void:
	if not minimap_camera:
		return

	match map_view:
		MapView.TOP_DOWN:
			# Orthographic, straight down
			minimap_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			minimap_camera.size = camera_ortho_size
			minimap_camera.fov = camera_fov
			minimap_camera.rotation_degrees = Vector3(-90, 0, 0)

		MapView.ANGLED_25D:
			# Orthographic, ~30° angle (60° from horizontal)
			minimap_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			minimap_camera.size = camera_ortho_size
			minimap_camera.fov = camera_fov
			minimap_camera.rotation_degrees = Vector3(-60, 0, 0)

		MapView.PERSPECTIVE_3D:
			# Perspective, ~45° angle
			minimap_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			minimap_camera.size = camera_ortho_size
			minimap_camera.fov = camera_fov
			minimap_camera.rotation_degrees = Vector3(-45, 0, 0)

func _create_player_marker() -> void:
	# Create 2D arrow overlay centered on minimap
	player_marker = Control.new()
	player_marker.name = "PlayerArrow"
	player_marker.set_anchors_preset(Control.PRESET_CENTER)
	player_marker.pivot_offset = Vector2(12, 12)  # Center of 24x24 arrow
	player_marker.custom_minimum_size = Vector2(24, 24)
	player_marker.size = Vector2(24, 24)
	player_marker.position = Vector2(-12, -12)  # Center it

	# Custom draw for arrow
	player_marker.set_script(preload("res://scenes/minimap/player_arrow.gd"))

	viewport_container.add_child(player_marker)

func _create_cardinal_indicator() -> void:
	if not show_cardinal_directions:
		return

	cardinal_indicator = Control.new()
	cardinal_indicator.name = "CardinalIndicator"
	cardinal_indicator.set_anchors_preset(Control.PRESET_FULL_RECT)
	cardinal_indicator.set_script(preload("res://scenes/minimap/cardinal_indicator.gd"))
	cardinal_indicator.show_all_directions = show_all_cardinals

	viewport_container.add_child(cardinal_indicator)

func _create_edge_arrows() -> void:
	edge_arrows = Control.new()
	edge_arrows.name = "EdgeArrows"
	edge_arrows.set_anchors_preset(Control.PRESET_FULL_RECT)
	edge_arrows.set_script(preload("res://scenes/minimap/edge_arrows.gd"))
	edge_arrows.minimap = self
	edge_arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE

	viewport_container.add_child(edge_arrows)

func _update_player_marker() -> void:
	if not player or not player_marker:
		return

	# Rotate arrow to show player's facing direction
	# Negate because 3D Y rotation and 2D rotation have opposite conventions
	player_marker.rotation = -player.rotation.y

func _update_camera_position() -> void:
	if not player or not minimap_camera:
		return

	var target_pos := player.global_position

	match map_view:
		MapView.TOP_DOWN:
			# Camera directly above player
			minimap_camera.global_position = Vector3(
				target_pos.x,
				camera_height,
				target_pos.z
			)

		MapView.ANGLED_25D:
			# Camera offset backward (positive Z) to keep player centered
			var offset_z := camera_height * tan(deg_to_rad(30))  # 60° pitch = 30° from vertical
			minimap_camera.global_position = Vector3(
				target_pos.x,
				camera_height,
				target_pos.z + offset_z
			)

		MapView.PERSPECTIVE_3D:
			# Camera offset backward for 45° view
			var offset_z := camera_height * tan(deg_to_rad(45))
			minimap_camera.global_position = Vector3(
				target_pos.x,
				camera_height,
				target_pos.z + offset_z
			)

func _update_size() -> void:
	if not is_inside_tree():
		return

	custom_minimum_size = Vector2(map_size)
	size = Vector2(map_size)

	if viewport_container:
		viewport_container.custom_minimum_size = Vector2(map_size)
		viewport_container.size = Vector2(map_size)

	# Note: SubViewport size is managed by SubViewportContainer with stretch=true

	if shadow:
		shadow.custom_minimum_size = Vector2(map_size)
		shadow.size = Vector2(map_size)

	_update_position()

func _update_position() -> void:
	if not is_inside_tree():
		return

	var viewport_size := get_viewport_rect().size

	match screen_corner:
		ScreenCorner.TOP_LEFT:
			position = margin
		ScreenCorner.TOP_RIGHT:
			position = Vector2(viewport_size.x - size.x - margin.x, margin.y)
		ScreenCorner.BOTTOM_LEFT:
			position = Vector2(margin.x, viewport_size.y - size.y - margin.y)
		ScreenCorner.BOTTOM_RIGHT:
			position = Vector2(viewport_size.x - size.x - margin.x, viewport_size.y - size.y - margin.y)
		ScreenCorner.CUSTOM:
			position = custom_position

func _update_opacity() -> void:
	if not is_inside_tree():
		return
	modulate.a = opacity

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_position()
