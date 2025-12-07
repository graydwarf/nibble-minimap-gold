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

@export_group("Trail")
@export var trail_enabled: bool = true
@export var trail_length: int = 50  # Number of trail points
@export var trail_duration: float = 10.0  # How long trail points last

@export_group("Theme")
@export var minimap_theme: Resource = null  # MinimapTheme resource

@export_group("Compass Bar")
@export var compass_bar_enabled: bool = false
@export var compass_bar_width: float = 400.0
@export var compass_bar_position: ScreenCorner = ScreenCorner.TOP_LEFT

# Marker type colors (default, overridden by theme)
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

# Tracked markers that follow moving targets: id -> { node: Node3D, target: Node3D }
var _tracked_markers: Dictionary = {}

# Waypoint tracking: id -> { node: Node3D, position: Vector3, label: String }
var _waypoints: Dictionary = {}
var _next_waypoint_id: int = 0
var _active_waypoint_id: int = -1

var _distance_label: Label = null
var _elevation_icon: TextureRect = null
var _distance_container: HBoxContainer = null
var _arrow_up_texture: Texture2D = null
var _arrow_down_texture: Texture2D = null

@onready var viewport_container: SubViewportContainer = $SubViewportContainer
@onready var sub_viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var minimap_camera: Camera3D = $SubViewportContainer/SubViewport/MinimapCamera
@onready var shadow: Panel = $Shadow

var player_marker: Control = null
var cardinal_indicator: Control = null
var edge_arrows: Control = null
var trail_renderer: Node3D = null
var compass_bar: Control = null

func _ready() -> void:
	_update_size()
	_update_position()
	_update_opacity()
	_setup_camera()
	_create_player_marker()
	_create_cardinal_indicator()
	_create_edge_arrows()
	_create_distance_label()
	_create_compass_bar()
	# Handle viewport resize (fullscreen, window resize)
	get_tree().root.size_changed.connect(_update_position)

func _process(_delta: float) -> void:
	if player:
		_update_camera_position()
		_update_player_marker()
		_update_distance_label()
		_update_tracked_markers()
		_update_trail()

func _input(event: InputEvent) -> void:
	if not zoom_enabled:
		return

	# Handle scroll wheel zoom - always zooms minimap
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()
			get_viewport().set_input_as_handled()

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
# Optional priority parameter overrides default type priority (higher = renders on top)
func add_marker(world_position: Vector3, marker_type: String = "default", _label: String = "", priority: int = 0) -> int:
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
	if priority > 0:
		marker_node.marker_priority = priority

	# Add to tree first, then set position
	_world_root.add_child(marker_node)
	marker_node.global_position = world_position

	# Set player reference for elevation indicators
	if player and marker_node.has_method("set_player_reference"):
		marker_node.set_player_reference(player)

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

# Highlights a marker (makes it pulse and glow)
func set_marker_highlighted(marker_id: int, highlighted: bool) -> void:
	if marker_id in _markers:
		var marker_node: Node3D = _markers[marker_id].node
		if marker_node and marker_node.has_method("set_highlighted"):
			marker_node.set_highlighted(highlighted)
	elif marker_id in _tracked_markers:
		var marker_node: Node3D = _tracked_markers[marker_id].node
		if marker_node and marker_node.has_method("set_highlighted"):
			marker_node.set_highlighted(highlighted)

# ============ TRACKED MARKERS (follow moving targets) ============

# Adds a marker that tracks a moving Node3D target. Returns marker ID.
# Optional priority parameter overrides default type priority (higher = renders on top)
func add_tracked_marker(target: Node3D, marker_type: String = "enemy", _label: String = "", priority: int = 0) -> int:
	if not _world_root or not target:
		push_warning("Minimap: Cannot add tracked marker - no world root or target.")
		return -1

	var marker_id := _next_marker_id
	_next_marker_id += 1

	var marker_node := Node3D.new()
	marker_node.name = "TrackedMarker_%d" % marker_id
	marker_node.set_script(preload("res://scenes/minimap/poi_marker_3d.gd"))

	var color: Color = MARKER_COLORS.get(marker_type, Color.WHITE)
	marker_node.marker_color = color
	marker_node.marker_type = marker_type
	if priority > 0:
		marker_node.marker_priority = priority

	_world_root.add_child(marker_node)
	marker_node.global_position = target.global_position

	# Set player reference for elevation indicators
	if player and marker_node.has_method("set_player_reference"):
		marker_node.set_player_reference(player)

	_tracked_markers[marker_id] = {
		"node": marker_node,
		"target": target,
		"type": marker_type
	}

	return marker_id

# Removes a tracked marker by ID
func remove_tracked_marker(marker_id: int) -> void:
	if marker_id in _tracked_markers:
		var data: Dictionary = _tracked_markers[marker_id]
		if data.node:
			data.node.queue_free()
		_tracked_markers.erase(marker_id)

# Updates all tracked markers to follow their targets
func _update_tracked_markers() -> void:
	var to_remove: Array[int] = []

	for marker_id: int in _tracked_markers:
		var data: Dictionary = _tracked_markers[marker_id]
		var target: Node3D = data.target
		var node: Node3D = data.node

		# Check if target still exists
		if not is_instance_valid(target):
			to_remove.append(marker_id)
			continue

		# Update marker position to match target
		if node:
			node.global_position = target.global_position

	# Clean up markers for destroyed targets
	for marker_id: int in to_remove:
		remove_tracked_marker(marker_id)

# Clears all tracked markers
func clear_tracked_markers() -> void:
	for marker_id in _tracked_markers.keys():
		remove_tracked_marker(marker_id)
	_tracked_markers.clear()

# ============ WAYPOINT SYSTEM ============

# Adds a waypoint at the given world position. Returns waypoint ID.
# First waypoint added becomes active automatically.
func add_waypoint(world_position: Vector3, label: String = "", color: Color = Color(0.8, 0.5, 1.0)) -> int:
	if not _world_root:
		push_warning("Minimap: No world root set. Call set_player first.")
		return -1

	var waypoint_id := _next_waypoint_id
	_next_waypoint_id += 1

	var waypoint_node := Node3D.new()
	waypoint_node.name = "Waypoint_%d" % waypoint_id
	waypoint_node.set_script(preload("res://scenes/minimap/waypoint_marker_3d.gd"))
	waypoint_node.waypoint_id = waypoint_id
	waypoint_node.waypoint_color = color

	_world_root.add_child(waypoint_node)
	waypoint_node.global_position = world_position

	_waypoints[waypoint_id] = {
		"node": waypoint_node,
		"position": world_position,
		"label": label,
		"color": color
	}

	# First waypoint becomes active
	if _active_waypoint_id == -1:
		set_active_waypoint(waypoint_id)
	else:
		waypoint_node.is_active = false

	return waypoint_id

# Removes a waypoint by ID
func remove_waypoint(waypoint_id: int) -> void:
	if waypoint_id in _waypoints:
		var data: Dictionary = _waypoints[waypoint_id]
		if data.node:
			data.node.queue_free()
		_waypoints.erase(waypoint_id)

		# If we removed the active waypoint, activate another or clear
		if waypoint_id == _active_waypoint_id:
			_active_waypoint_id = -1
			if _waypoints.size() > 0:
				set_active_waypoint(_waypoints.keys()[0])

# Sets which waypoint is the active one (shown with distance)
func set_active_waypoint(waypoint_id: int) -> void:
	# Deactivate old
	if _active_waypoint_id != -1 and _active_waypoint_id in _waypoints:
		var old_node: Node3D = _waypoints[_active_waypoint_id].node
		if old_node:
			old_node.is_active = false

	_active_waypoint_id = waypoint_id

	# Activate new
	if waypoint_id in _waypoints:
		var new_node: Node3D = _waypoints[waypoint_id].node
		if new_node:
			new_node.is_active = true

# Cycles to next waypoint as active
func cycle_active_waypoint() -> void:
	if _waypoints.size() == 0:
		return

	var ids := _waypoints.keys()
	var current_idx := ids.find(_active_waypoint_id)
	var next_idx := (current_idx + 1) % ids.size()
	set_active_waypoint(ids[next_idx])

# Updates an existing waypoint's position
func update_waypoint_position(waypoint_id: int, world_position: Vector3) -> void:
	if waypoint_id in _waypoints:
		_waypoints[waypoint_id].position = world_position
		var node: Node3D = _waypoints[waypoint_id].node
		if node:
			node.global_position = world_position

# Clears all waypoints
func clear_waypoints() -> void:
	for waypoint_id in _waypoints.keys():
		remove_waypoint(waypoint_id)
	_waypoints.clear()
	_active_waypoint_id = -1

# Returns distance to active waypoint (or -1 if none)
func get_active_waypoint_distance() -> float:
	if _active_waypoint_id == -1 or not player:
		return -1.0
	if _active_waypoint_id not in _waypoints:
		return -1.0

	var waypoint_pos: Vector3 = _waypoints[_active_waypoint_id].position
	return player.global_position.distance_to(waypoint_pos)

# Returns active waypoint label (or empty string)
func get_active_waypoint_label() -> String:
	if _active_waypoint_id == -1 or _active_waypoint_id not in _waypoints:
		return ""
	return _waypoints[_active_waypoint_id].label

# ============ END WAYPOINT SYSTEM ============

# Sets the camera view mode at runtime
func set_view_mode(mode: MapView) -> void:
	map_view = mode

# Cycles through view modes: TOP_DOWN -> ANGLED_25D -> PERSPECTIVE_3D -> TOP_DOWN
func cycle_view_mode() -> void:
	map_view = (map_view + 1) % MapView.size() as MapView

const MINIMAP_LAYER := 20  # Layer for minimap-only markers

func _setup_camera() -> void:
	if not minimap_camera:
		return

	# Enable layer 20 for minimap-only objects (in addition to default layers 1-2)
	minimap_camera.cull_mask = minimap_camera.cull_mask | (1 << (MINIMAP_LAYER - 1))

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

func _create_distance_label() -> void:
	# Load arrow textures (optional - falls back to Unicode if not imported)
	if ResourceLoader.exists("res://assets/icons/arrow_up.svg"):
		_arrow_up_texture = load("res://assets/icons/arrow_up.svg")
	if ResourceLoader.exists("res://assets/icons/arrow_down.svg"):
		_arrow_down_texture = load("res://assets/icons/arrow_down.svg")

	# Create container for label + icon
	_distance_container = HBoxContainer.new()
	_distance_container.name = "DistanceContainer"
	_distance_container.alignment = BoxContainer.ALIGNMENT_CENTER

	# Position below minimap
	_distance_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_distance_container.offset_top = 4
	_distance_container.offset_bottom = 24

	# Create label
	_distance_label = Label.new()
	_distance_label.name = "DistanceLabel"
	_distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_distance_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Styling
	var label_settings := LabelSettings.new()
	label_settings.font_size = 14
	label_settings.font_color = Color(0.9, 0.7, 1.0)  # Light purple
	label_settings.shadow_color = Color(0, 0, 0, 0.8)
	label_settings.shadow_size = 2
	_distance_label.label_settings = label_settings

	# Create elevation icon
	_elevation_icon = TextureRect.new()
	_elevation_icon.name = "ElevationIcon"
	_elevation_icon.custom_minimum_size = Vector2(20, 20)
	_elevation_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_elevation_icon.visible = false

	_distance_container.add_child(_distance_label)
	_distance_container.add_child(_elevation_icon)

	_distance_container.visible = false  # Hidden until waypoint added
	add_child(_distance_container)

func _update_distance_label() -> void:
	if not _distance_label or not _distance_container:
		return

	var distance := get_active_waypoint_distance()
	if distance < 0:
		_distance_container.visible = false
		return

	_distance_container.visible = true
	var waypoint_label := get_active_waypoint_label()

	# Format distance
	var dist_text: String
	if distance < 10:
		dist_text = "%.1fm" % distance
	else:
		dist_text = "%dm" % int(distance)

	# Set label text
	if waypoint_label.is_empty():
		_distance_label.text = "◆ %s" % dist_text
	else:
		_distance_label.text = "◆ %s - %s" % [waypoint_label, dist_text]

	# Determine elevation indicator (icon for above/below, hidden if same level)
	var waypoint_pos: Vector3 = _waypoints[_active_waypoint_id].position
	var height_diff: float = waypoint_pos.y - player.global_position.y

	# Use icons if available, otherwise append Unicode arrows to label
	if _arrow_up_texture and _arrow_down_texture and _elevation_icon:
		if height_diff > 2.0:
			_elevation_icon.texture = _arrow_up_texture
			_elevation_icon.visible = true
		elif height_diff < -2.0:
			_elevation_icon.texture = _arrow_down_texture
			_elevation_icon.visible = true
		else:
			_elevation_icon.visible = false
	else:
		# Fallback to Unicode arrows
		if height_diff > 2.0:
			_distance_label.text += " ↑"
		elif height_diff < -2.0:
			_distance_label.text += " ↓"

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
	# Update shader opacity for the terrain/viewport
	if viewport_container and viewport_container.material:
		viewport_container.material.set_shader_parameter("opacity", opacity)
	# Also apply to shadow
	if shadow:
		shadow.modulate.a = opacity

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_position()

# ============ TRAIL SYSTEM ============

func _create_trail_renderer() -> void:
	if not trail_enabled or not _world_root:
		return

	trail_renderer = Node3D.new()
	trail_renderer.name = "TrailRenderer"
	trail_renderer.set_script(preload("res://scenes/minimap/trail_renderer.gd"))
	trail_renderer.trail_length = trail_length
	trail_renderer.trail_duration = trail_duration

	_world_root.add_child(trail_renderer)

func _update_trail() -> void:
	if not trail_enabled or not player:
		return

	# Create trail renderer if needed (after world root is available)
	if not trail_renderer and _world_root:
		_create_trail_renderer()

	if trail_renderer and trail_renderer.has_method("add_point"):
		trail_renderer.add_point(player.global_position)

# Sets trail enabled/disabled at runtime
func set_trail_enabled(enabled: bool) -> void:
	trail_enabled = enabled
	if trail_renderer:
		trail_renderer.visible = enabled

# Clears the current trail
func clear_trail() -> void:
	if trail_renderer and trail_renderer.has_method("clear_trail"):
		trail_renderer.clear_trail()

# ============ THEMING SYSTEM ============

# Gets marker color (from theme if set, otherwise default)
func get_marker_color(marker_type: String) -> Color:
	if minimap_theme and minimap_theme.has_method("get_marker_color"):
		return minimap_theme.get_marker_color(marker_type)
	return MARKER_COLORS.get(marker_type, Color.WHITE)

# Applies a theme to all minimap elements
func apply_theme(new_theme: Resource) -> void:
	minimap_theme = new_theme
	if not minimap_theme:
		return

	# Apply trail color
	if trail_renderer and minimap_theme.get("trail_color"):
		trail_renderer.set_trail_color(minimap_theme.trail_color)

	# Apply player marker color
	if player_marker and player_marker.has_method("set_colors"):
		player_marker.set_colors(minimap_theme.player_color, minimap_theme.player_outline_color)

	# Apply cardinal indicator colors
	if cardinal_indicator and cardinal_indicator.has_method("set_colors"):
		cardinal_indicator.set_colors(minimap_theme.cardinal_color, minimap_theme.cardinal_north_color)

	# Update existing markers with new colors
	_recolor_all_markers()

func _recolor_all_markers() -> void:
	if not minimap_theme:
		return

	# Recolor POI markers
	for marker_id in _markers:
		var marker_data: Dictionary = _markers[marker_id]
		var marker_node: Node3D = marker_data.node
		var marker_type: String = marker_data.type
		if marker_node and marker_node.has_method("set_marker_color"):
			marker_node.set_marker_color(get_marker_color(marker_type))

	# Recolor tracked markers
	for marker_id in _tracked_markers:
		var marker_data: Dictionary = _tracked_markers[marker_id]
		var marker_node: Node3D = marker_data.node
		var marker_type: String = marker_data.type
		if marker_node and marker_node.has_method("set_marker_color"):
			marker_node.set_marker_color(get_marker_color(marker_type))

	# Recolor waypoints
	for waypoint_id in _waypoints:
		var waypoint_data: Dictionary = _waypoints[waypoint_id]
		var waypoint_node: Node3D = waypoint_data.node
		if waypoint_node and waypoint_node.has_method("set_waypoint_color"):
			var is_active: bool = (waypoint_id == _active_waypoint_id)
			var color: Color = minimap_theme.waypoint_active_color if is_active else minimap_theme.waypoint_color
			waypoint_node.set_waypoint_color(color)

# ============ COMPASS BAR ============

func _create_compass_bar() -> void:
	if not compass_bar_enabled:
		return

	compass_bar = Control.new()
	compass_bar.name = "CompassBar"
	compass_bar.set_script(preload("res://scenes/minimap/compass_bar.gd"))
	compass_bar.custom_minimum_size = Vector2(compass_bar_width, 40)
	compass_bar.size = Vector2(compass_bar_width, 40)

	# Position based on compass_bar_position
	_update_compass_bar_position()

	# Add as sibling to minimap (in same CanvasLayer)
	if get_parent():
		get_parent().add_child(compass_bar)
		compass_bar.setup(self)

func _update_compass_bar_position() -> void:
	if not compass_bar:
		return

	var viewport_size := get_viewport_rect().size

	match compass_bar_position:
		ScreenCorner.TOP_LEFT:
			compass_bar.position = Vector2(margin.x, margin.y)
		ScreenCorner.TOP_RIGHT:
			compass_bar.position = Vector2(viewport_size.x - compass_bar.size.x - margin.x, margin.y)
		ScreenCorner.BOTTOM_LEFT:
			compass_bar.position = Vector2(margin.x, viewport_size.y - compass_bar.size.y - margin.y)
		ScreenCorner.BOTTOM_RIGHT:
			compass_bar.position = Vector2(viewport_size.x - compass_bar.size.x - margin.x, viewport_size.y - compass_bar.size.y - margin.y)
		ScreenCorner.CUSTOM:
			# Center at top by default
			compass_bar.position = Vector2((viewport_size.x - compass_bar.size.x) / 2, margin.y)

# Sets compass bar enabled/disabled at runtime
func set_compass_bar_enabled(enabled: bool) -> void:
	compass_bar_enabled = enabled
	if compass_bar:
		compass_bar.visible = enabled
	elif enabled:
		_create_compass_bar()
