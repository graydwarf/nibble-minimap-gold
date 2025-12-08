extends Node3D
## 3D edge arrows that appear at minimap edges pointing to off-screen markers.
## Uses 3D cone meshes on minimap layer for web compatibility.

var minimap: Control = null
var player: Node3D = null

# Explicit initialization for web compatibility
# Direct property assignment doesn't work on dynamically instantiated scripts on web
func initialize(minimap_ref: Control, player_ref: Node3D) -> void:
	minimap = minimap_ref
	player = player_ref
	DebugConsole.log("[EdgeArrows3D] initialize() minimap=%s player=%s" % [str(minimap != null), str(player != null)])

# Color scheme by marker type
const MARKER_COLORS := {
	"default": Color(1.0, 1.0, 0.0),   # Yellow
	"enemy": Color(1.0, 0.3, 0.3),     # Red
	"friendly": Color(0.3, 1.0, 0.3),  # Green
	"loot": Color(1.0, 1.0, 0.0),      # Yellow
	"objective": Color(1.0, 0.9, 0.2), # Yellow
}
var waypoint_color: Color = Color(0.8, 0.5, 1.0)  # Purple

const MINIMAP_LAYER := 20
const MAX_ARROWS := 20
const ARROW_HEIGHT := 10.0  # Height above player (must be BELOW camera at Y=50)
const EDGE_DISTANCE := 25.0  # Distance from player to place arrows

var _arrow_pool: Array[MeshInstance3D] = []
var _arrow_materials: Array[StandardMaterial3D] = []
var _arrow_index: int = 0
var _waypoint_arrow: MeshInstance3D = null
var _waypoint_material: StandardMaterial3D = null

func _ready() -> void:
	DebugConsole.log("[EdgeArrows3D] _ready() called")
	# Explicitly enable processing - web might not auto-register _process for dynamic scripts
	set_process(true)
	DebugConsole.log("[EdgeArrows3D] set_process(true) called")

	# Test timer to verify node is alive
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(_on_test_timer)

	# Create arrow mesh pool
	var cone_mesh := _create_cone_mesh()

	for i in MAX_ARROWS:
		var arrow := MeshInstance3D.new()
		arrow.mesh = cone_mesh
		arrow.layers = 1 << (MINIMAP_LAYER - 1)
		arrow.visible = false

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color.YELLOW
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		arrow.material_override = mat

		add_child(arrow)
		_arrow_pool.append(arrow)
		_arrow_materials.append(mat)

	# Create waypoint arrow (diamond shape)
	_waypoint_arrow = MeshInstance3D.new()
	_waypoint_arrow.mesh = _create_diamond_mesh()
	_waypoint_arrow.layers = 1 << (MINIMAP_LAYER - 1)
	_waypoint_arrow.visible = false

	_waypoint_material = StandardMaterial3D.new()
	_waypoint_material.albedo_color = waypoint_color
	_waypoint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_waypoint_arrow.material_override = _waypoint_material
	add_child(_waypoint_arrow)

func _on_test_timer() -> void:
	DebugConsole.log("[EdgeArrows3D] timer fired - node is alive, minimap=%s player=%s" % [str(minimap != null), str(player != null)])

func _create_cone_mesh() -> CylinderMesh:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.5
	cone.height = 3.0
	cone.radial_segments = 8
	return cone

func _create_diamond_mesh() -> ArrayMesh:
	# Two cones for diamond shape
	var top := CylinderMesh.new()
	top.top_radius = 0.0
	top.bottom_radius = 1.5
	top.height = 2.0
	top.radial_segments = 4

	var bottom := CylinderMesh.new()
	bottom.top_radius = 1.5
	bottom.bottom_radius = 0.0
	bottom.height = 2.0
	bottom.radial_segments = 4

	var combined := ArrayMesh.new()
	var st := SurfaceTool.new()

	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(top, 0, Transform3D().translated(Vector3(0, 1.0, 0)))
	st.commit(combined)

	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(bottom, 0, Transform3D().translated(Vector3(0, -1.0, 0)))
	st.commit(combined)

	return combined

var _debug_timer: float = 0.0
var _frame_count: int = 0

func _process(delta: float) -> void:
	_frame_count += 1

	# Log first few frames to see what's happening
	if _frame_count <= 3:
		DebugConsole.log("[EdgeArrows3D] frame %d: minimap=%s player=%s" % [_frame_count, str(minimap != null), str(player != null)])

	if not minimap or not player:
		if _frame_count <= 3:
			DebugConsole.log("[EdgeArrows3D] frame %d: early return (null refs)" % _frame_count)
		_hide_all()
		return

	_arrow_index = 0

	# Debug: check if property access works
	if _frame_count <= 5:
		DebugConsole.log("[EdgeArrows3D] frame %d: getting player_pos..." % _frame_count)

	var player_pos := player.global_position

	if _frame_count <= 5:
		DebugConsole.log("[EdgeArrows3D] frame %d: player_pos OK, getting ortho_size..." % _frame_count)

	var ortho_size: float = minimap.camera_ortho_size

	if _frame_count <= 5:
		DebugConsole.log("[EdgeArrows3D] frame %d: ortho_size=%.1f" % [_frame_count, ortho_size])

	# Debug logging every 2 seconds
	_debug_timer += delta
	if _debug_timer >= 2.0:
		_debug_timer = 0.0
		DebugConsole.log("[EdgeArrows3D] 2s tick - about to get marker count")
		# Use getter methods for web compatibility (direct property access crashes on web)
		var markers := minimap.get_markers()
		var tracked_markers := minimap.get_tracked_markers()
		var marker_count: int = markers.size() + tracked_markers.size()
		DebugConsole.log("[EdgeArrows3D] markers=%d, visible_radius=%.1f, arrows=%d" % [marker_count, ortho_size / 2.0 * 0.9, _arrow_index])

	# Use getter methods for web compatibility (direct property access crashes on web)
	var markers := minimap.get_markers()
	var tracked_markers := minimap.get_tracked_markers()

	# Check static markers
	for marker_id in markers:
		if _arrow_index >= MAX_ARROWS:
			break
		_check_marker(markers[marker_id], player_pos, ortho_size)

	# Check tracked markers
	for marker_id in tracked_markers:
		if _arrow_index >= MAX_ARROWS:
			break
		_check_marker(tracked_markers[marker_id], player_pos, ortho_size)

	# Debug: how many arrows are visible?
	if _debug_timer == 0.0:
		DebugConsole.log("arrows_visible=%d" % _arrow_index)

	# Hide unused arrows
	for i in range(_arrow_index, MAX_ARROWS):
		_arrow_pool[i].visible = false

	# Update waypoint
	_update_waypoint(player_pos, ortho_size)

func _check_marker(marker_data: Dictionary, player_pos: Vector3, ortho_size: float) -> void:
	var marker_node: Node3D = marker_data.node
	if not marker_node:
		return

	var marker_type: String = marker_data.get("type", "default")

	# Check loot visibility settings
	if marker_type == "loot":
		if not minimap.show_resource_markers:
			return
		# Check proximity visibility
		if marker_node.get("_is_visible_by_distance") == false:
			return

	var marker_pos := marker_node.global_position
	var offset := marker_pos - player_pos
	var flat_offset := Vector2(offset.x, offset.z)
	var distance := flat_offset.length()

	# Only show arrow if marker is outside visible area
	# ortho_size is the FULL camera width, divide by 2 for radius
	var visible_radius := ortho_size / 2.0 * 0.9  # 90% of visible radius
	if distance <= visible_radius:
		return

	# Position arrow near center for testing (edge_arrow_inset from minimap)
	var direction := flat_offset.normalized()
	var inset: float = minimap.edge_arrow_inset
	var arrow_distance: float = ortho_size / 2.0 * (1.0 - inset)
	var edge_offset := direction * arrow_distance

	var arrow := _arrow_pool[_arrow_index]
	var mat := _arrow_materials[_arrow_index]
	_arrow_index += 1

	# Position arrow in 3D space (high up for minimap camera)
	arrow.global_position = Vector3(
		player_pos.x + edge_offset.x,
		player_pos.y + ARROW_HEIGHT,
		player_pos.z + edge_offset.y
	)

	# Rotate to point outward (cone points down by default, we want it pointing in direction)
	var angle := atan2(direction.y, direction.x)
	arrow.rotation = Vector3(PI/2, 0, -angle + PI/2)

	# Set color by type
	var color: Color = MARKER_COLORS.get(marker_type, MARKER_COLORS["default"])
	mat.albedo_color = color
	arrow.visible = true

func _update_waypoint(player_pos: Vector3, ortho_size: float) -> void:
	# Use getter methods for web compatibility (direct property access crashes on web)
	var active_waypoint_id := minimap.get_active_waypoint_id()
	var waypoints := minimap.get_waypoints()

	if active_waypoint_id == -1 or active_waypoint_id not in waypoints:
		_waypoint_arrow.visible = false
		return

	var waypoint_data: Dictionary = waypoints[active_waypoint_id]
	var waypoint_pos: Vector3 = waypoint_data.position
	var wp_color: Color = waypoint_data.get("color", waypoint_color)

	var offset := waypoint_pos - player_pos
	var flat_offset := Vector2(offset.x, offset.z)
	var distance := flat_offset.length()

	# Only show if outside visible area
	# ortho_size is the FULL camera width, divide by 2 for radius
	var visible_radius := ortho_size / 2.0 * 0.9  # 90% of visible radius
	if distance <= visible_radius:
		_waypoint_arrow.visible = false
		return

	# Position arrow near center based on edge_arrow_inset
	var direction := flat_offset.normalized()
	var inset: float = minimap.edge_arrow_inset
	var arrow_distance: float = ortho_size / 2.0 * (1.0 - inset)
	var edge_offset := direction * arrow_distance

	_waypoint_arrow.global_position = Vector3(
		player_pos.x + edge_offset.x,
		player_pos.y + ARROW_HEIGHT,
		player_pos.z + edge_offset.y
	)

	_waypoint_material.albedo_color = wp_color
	_waypoint_arrow.visible = true

func _hide_all() -> void:
	for arrow in _arrow_pool:
		arrow.visible = false
	if _waypoint_arrow:
		_waypoint_arrow.visible = false
