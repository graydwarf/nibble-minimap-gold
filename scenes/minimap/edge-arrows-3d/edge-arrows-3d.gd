extends Node3D
## 3D edge arrows that appear at minimap edges pointing to off-screen markers.
## Uses 3D cone meshes on minimap layer. Native builds only (web uses integrated arrows in minimap.gd).

var minimap: Control = null
var player: Node3D = null

# Explicit initialization for native builds
func initialize(minimap_ref: Control, player_ref: Node3D) -> void:
	minimap = minimap_ref
	player = player_ref

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
const BASE_ORTHO_SIZE := 100.0  # Reference ortho_size for arrow scaling

var _arrow_pool: Array[MeshInstance3D] = []
var _arrow_materials: Array[StandardMaterial3D] = []
var _arrow_index: int = 0
var _waypoint_arrow: MeshInstance3D = null
var _waypoint_material: StandardMaterial3D = null

func _ready() -> void:
	set_process(true)

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

func _create_cone_mesh() -> CylinderMesh:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.75
	cone.height = 1.5
	cone.radial_segments = 8
	return cone

func _create_diamond_mesh() -> ArrayMesh:
	# Two cones for diamond shape
	var top := CylinderMesh.new()
	top.top_radius = 0.0
	top.bottom_radius = 0.75
	top.height = 1.0
	top.radial_segments = 4

	var bottom := CylinderMesh.new()
	bottom.top_radius = 0.75
	bottom.bottom_radius = 0.0
	bottom.height = 1.0
	bottom.radial_segments = 4

	var combined := ArrayMesh.new()
	var st := SurfaceTool.new()

	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(top, 0, Transform3D().translated(Vector3(0, 0.5, 0)))
	st.commit(combined)

	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(bottom, 0, Transform3D().translated(Vector3(0, -0.5, 0)))
	st.commit(combined)

	return combined

func _process(_delta: float) -> void:
	if not minimap or not player:
		_hide_all()
		return

	_arrow_index = 0

	var player_pos := player.global_position
	var ortho_size: float = minimap.camera_ortho_size

	# Use getter methods for compatibility
	var markers: Dictionary = minimap.get_markers()
	var tracked_markers: Dictionary = minimap.get_tracked_markers()

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
	if marker_type == "loot" and not minimap.show_resource_markers:
		return

	# Check proximity visibility for loot and enemy markers
	if marker_type in ["loot", "enemy"]:
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

	# Position arrow based on edge_arrow_inset from minimap
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
	# atan2(x, z) gives angle from +Z axis toward +X, then rotate around Y axis
	var angle := atan2(direction.x, direction.y)
	arrow.rotation = Vector3(PI/2, angle, 0)

	# Scale to maintain constant visual size regardless of zoom
	var scale_factor := ortho_size / BASE_ORTHO_SIZE * 3.0
	arrow.scale = Vector3.ONE * scale_factor

	# Set color by type
	var color: Color = MARKER_COLORS.get(marker_type, MARKER_COLORS["default"])
	mat.albedo_color = color
	arrow.visible = true

func _update_waypoint(player_pos: Vector3, ortho_size: float) -> void:
	# Use getter methods for compatibility
	var active_waypoint_id: int = minimap.get_active_waypoint_id()
	var waypoints: Dictionary = minimap.get_waypoints()

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

	# Position arrow based on edge_arrow_inset
	var direction := flat_offset.normalized()
	var inset: float = minimap.edge_arrow_inset
	var arrow_distance: float = ortho_size / 2.0 * (1.0 - inset)
	var edge_offset := direction * arrow_distance

	_waypoint_arrow.global_position = Vector3(
		player_pos.x + edge_offset.x,
		player_pos.y + ARROW_HEIGHT,
		player_pos.z + edge_offset.y
	)

	# Rotate to point toward waypoint (for consistency with marker arrows)
	var angle := atan2(direction.x, direction.y)
	_waypoint_arrow.rotation = Vector3(PI/2, angle, 0)

	# Scale to maintain constant visual size regardless of zoom
	var scale_factor := ortho_size / BASE_ORTHO_SIZE * 3.0
	_waypoint_arrow.scale = Vector3.ONE * scale_factor

	_waypoint_material.albedo_color = wp_color
	_waypoint_arrow.visible = true

func _hide_all() -> void:
	for arrow in _arrow_pool:
		arrow.visible = false
	if _waypoint_arrow:
		_waypoint_arrow.visible = false
