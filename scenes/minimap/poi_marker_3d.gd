extends Node3D
## 3D POI marker - floating question mark that bobs up and down.
## Supports pulse, highlight, and fade-in animations.

enum AnimationType { NONE, PULSE, HIGHLIGHT }

var marker_color: Color = Color(1.0, 0.85, 0.0)  # Gold/yellow
var marker_type: String = "default"
var marker_priority: int = 0  # Higher = renders on top

# Animation settings
var animation_type: AnimationType = AnimationType.NONE
var is_highlighted: bool = false
var fade_in_duration: float = 0.3  # Seconds to fade in

# Default priorities per marker type
const TYPE_PRIORITIES := {
	"default": 10,
	"enemy": 20,
	"friendly": 25,
	"loot": 30,
	"objective": 40,
}

# Default animations per marker type
const TYPE_ANIMATIONS := {
	"default": AnimationType.NONE,
	"enemy": AnimationType.PULSE,
	"friendly": AnimationType.NONE,
	"loot": AnimationType.PULSE,
	"objective": AnimationType.HIGHLIGHT,
}

var _label_3d: Label3D = null  # Used for "?" default marker
var _marker_mesh: MeshInstance3D = null  # Used for dots/stars (web compatible)
var _marker_material: StandardMaterial3D = null
var _elevation_mesh: MeshInstance3D = null  # 3D triangle for elevation
var _elevation_material: StandardMaterial3D = null
var _base_y: float = 2.0
var _bob_speed: float = 2.0
var _bob_height: float = 0.5
var _time: float = 0.0

# Animation state
var _fade_progress: float = 0.0  # 0 = invisible, 1 = fully visible
var _pulse_time: float = 0.0
var _base_scale: float = 1.0

# Elevation indicator
var player_ref: Node3D = null
var elevation_threshold: float = 3.0  # Min height difference to show indicator
var show_elevation_indicator: bool = true

# Proximity visibility - markers only show when player is within this distance
var visibility_distance: float = 40.0  # 0 = always visible, >0 = only show within distance
var _is_visible_by_distance: bool = false

var _setup_complete: bool = false

func _ready() -> void:
	# Randomize starting phase so markers don't all bob in sync
	_time = randf() * TAU
	# Visual creation happens in setup() - called explicitly after properties are set

# Call this after setting marker_type, marker_color, etc.
func setup() -> void:
	if _setup_complete:
		return
	_setup_complete = true
	print("[POI] setup() called, type=", marker_type, " pos=", global_position)
	_create_visual()

func _process(delta: float) -> void:
	_time += delta * _bob_speed
	_pulse_time += delta * 4.0  # Pulse speed

	# Get the active visual node (either mesh or label)
	var visual_node: Node3D = _marker_mesh if _marker_mesh else _label_3d
	if not visual_node:
		return

	# Proximity-based visibility
	_update_proximity_visibility(visual_node)
	if not _is_visible_by_distance:
		return

	# Bob up and down
	visual_node.position.y = _base_y + sin(_time) * _bob_height

	# Fade-in animation
	if _fade_progress < 1.0:
		_fade_progress = minf(_fade_progress + delta / fade_in_duration, 1.0)
		_update_fade()

	# Pulse animation (scale oscillation)
	if animation_type == AnimationType.PULSE or is_highlighted:
		var pulse_amount := 0.15 if is_highlighted else 0.1
		var pulse := 1.0 + sin(_pulse_time) * pulse_amount
		visual_node.scale = Vector3.ONE * _base_scale * pulse

	# Highlight animation (brightness boost)
	if is_highlighted:
		var glow := 1.0 + sin(_pulse_time * 1.5) * 0.2

		if _marker_mesh and _marker_material:
			var glow_color := marker_color * glow
			glow_color.a = marker_color.a * _fade_progress
			_marker_material.albedo_color = glow_color

		if _label_3d:
			_label_3d.modulate = marker_color * glow
			_label_3d.modulate.a = marker_color.a * _fade_progress

	# Update elevation indicator
	_update_elevation_indicator()

# Updates visibility based on player distance
func _update_proximity_visibility(visual_node: Node3D) -> void:
	# If visibility_distance is 0, always visible
	if visibility_distance <= 0.0:
		_is_visible_by_distance = true
		visual_node.visible = true
		if _elevation_mesh:
			_elevation_mesh.visible = show_elevation_indicator
		return

	# Check distance to player
	if not player_ref or not is_instance_valid(player_ref):
		_is_visible_by_distance = false
		visual_node.visible = false
		if _elevation_mesh:
			_elevation_mesh.visible = false
		return

	var distance := global_position.distance_to(player_ref.global_position)
	var should_be_visible := distance <= visibility_distance

	if should_be_visible != _is_visible_by_distance:
		_is_visible_by_distance = should_be_visible
		visual_node.visible = should_be_visible
		# Reset fade when becoming visible
		if should_be_visible:
			_fade_progress = 0.0

	if not _is_visible_by_distance and _elevation_mesh:
		_elevation_mesh.visible = false

const MINIMAP_LAYER := 20  # Layer 20 for minimap-only objects

func _create_visual() -> void:
	# Use 3D meshes for enemy/friendly/loot (web compatible)
	# Use Label3D only for default "?" marker
	match marker_type:
		"enemy", "friendly":
			_create_sphere_marker(0.8)  # Dot
		"loot":
			_create_star_marker()  # Diamond/star shape
		_:
			_create_label_marker()  # "?" text

	# Apply default animation for this marker type
	if animation_type == AnimationType.NONE:
		animation_type = TYPE_ANIMATIONS.get(marker_type, AnimationType.NONE)

	# Start invisible for fade-in effect
	_fade_progress = 0.0
	_update_fade()

	# Apply priority (higher renders on top)
	_apply_priority()

	# Create elevation indicator (hidden by default)
	_create_elevation_label()

# Creates a sphere mesh marker (for enemy/friendly dots)
func _create_sphere_marker(size: float) -> void:
	_marker_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	# DEBUG: Make bigger for visibility testing
	sphere.radius = size * 2.0
	sphere.height = size * 4.0
	sphere.radial_segments = 16
	sphere.rings = 8
	_marker_mesh.mesh = sphere

	_marker_material = StandardMaterial3D.new()
	_marker_material.albedo_color = marker_color
	_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_mesh.material_override = _marker_material

	_marker_mesh.position.y = _base_y
	_marker_mesh.layers = 1 << (MINIMAP_LAYER - 1)
	add_child(_marker_mesh)

# Creates a diamond/star marker (for loot)
func _create_star_marker() -> void:
	_marker_mesh = MeshInstance3D.new()

	# DEBUG: Make bigger for visibility testing
	var size := 3.0
	var height := 4.0

	var top_cone := CylinderMesh.new()
	top_cone.top_radius = 0.0
	top_cone.bottom_radius = size / 2.0
	top_cone.height = height / 2.0
	top_cone.radial_segments = 4

	var bottom_cone := CylinderMesh.new()
	bottom_cone.top_radius = size / 2.0
	bottom_cone.bottom_radius = 0.0
	bottom_cone.height = height / 2.0
	bottom_cone.radial_segments = 4

	var combined := ArrayMesh.new()
	var st := SurfaceTool.new()

	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(top_cone, 0, Transform3D().translated(Vector3(0, height / 4.0, 0)))
	st.commit(combined)

	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(bottom_cone, 0, Transform3D().translated(Vector3(0, -height / 4.0, 0)))
	st.commit(combined)

	_marker_mesh.mesh = combined

	_marker_material = StandardMaterial3D.new()
	_marker_material.albedo_color = marker_color
	_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_marker_mesh.material_override = _marker_material

	_marker_mesh.position.y = _base_y
	_marker_mesh.layers = 1 << (MINIMAP_LAYER - 1)
	add_child(_marker_mesh)

# Creates a Label3D marker (for default "?" only)
func _create_label_marker() -> void:
	_label_3d = Label3D.new()
	_label_3d.text = "?"
	_label_3d.font_size = 72
	_label_3d.pixel_size = 0.05
	_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label_3d.no_depth_test = true
	_label_3d.modulate = marker_color
	_label_3d.outline_size = 8
	_label_3d.outline_modulate = Color(0.1, 0.1, 0.1)
	_label_3d.position.y = _base_y
	_label_3d.layers = 1 << (MINIMAP_LAYER - 1)
	add_child(_label_3d)

# Creates a 3D triangle mesh for elevation indicator (web compatible)
func _create_elevation_label() -> void:
	_elevation_mesh = MeshInstance3D.new()
	_elevation_mesh.name = "ElevationIndicator"
	_elevation_mesh.mesh = _create_triangle_mesh()

	_elevation_material = StandardMaterial3D.new()
	_elevation_material.albedo_color = marker_color
	_elevation_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_elevation_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_elevation_material.render_priority = 100  # Always on top
	_elevation_mesh.material_override = _elevation_material

	_elevation_mesh.position.y = _base_y + 1.2  # Above main marker
	_elevation_mesh.layers = 1 << (MINIMAP_LAYER - 1)
	_elevation_mesh.visible = false
	add_child(_elevation_mesh)

# Creates a simple triangle/cone mesh (pointing up by default, web compatible)
func _create_triangle_mesh() -> CylinderMesh:
	var size := 0.5  # Triangle size

	# Use a cone (cylinder with 0 top radius) with 3 sides for triangle
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = size / 2.0
	cone.height = size
	cone.radial_segments = 3  # Triangle shape

	return cone

func _update_elevation_indicator() -> void:
	if not show_elevation_indicator or not _elevation_mesh or not player_ref:
		if _elevation_mesh:
			_elevation_mesh.visible = false
		return

	if not is_instance_valid(player_ref):
		_elevation_mesh.visible = false
		return

	var height_diff := global_position.y - player_ref.global_position.y

	if absf(height_diff) < elevation_threshold:
		_elevation_mesh.visible = false
	elif height_diff > 0:
		# Marker is above player - cone points up (default)
		_elevation_mesh.rotation_degrees.x = 0
		_elevation_mesh.visible = true
	else:
		# Marker is below player - cone points down (flip 180° around X)
		_elevation_mesh.rotation_degrees.x = 180
		_elevation_mesh.visible = true

	# Sync elevation mesh position with main marker bob
	if _elevation_mesh.visible:
		var visual_node: Node3D = _marker_mesh if _marker_mesh else _label_3d
		if visual_node:
			_elevation_mesh.position.y = visual_node.position.y + 1.2

func set_player_reference(player: Node3D) -> void:
	player_ref = player

func _update_fade() -> void:
	var alpha := marker_color.a * _fade_progress

	# Handle mesh-based markers (enemy, friendly, loot)
	if _marker_mesh and _marker_material:
		var faded_color := marker_color
		faded_color.a = alpha
		_marker_material.albedo_color = faded_color

	# Handle Label3D markers (default "?")
	if _label_3d:
		_label_3d.modulate.a = alpha
		# Also fade the outline
		var outline_alpha := 0.8 * _fade_progress  # Outline slightly transparent
		_label_3d.outline_modulate.a = outline_alpha

func _apply_priority() -> void:
	# Use type priority if marker_priority not set explicitly
	var priority := marker_priority
	if priority == 0:
		priority = TYPE_PRIORITIES.get(marker_type, 10)

	# Apply to mesh-based markers
	if _marker_mesh and _marker_material:
		_marker_material.render_priority = priority

	# Apply to Label3D markers
	if _label_3d:
		_label_3d.render_priority = priority

func set_priority(priority: int) -> void:
	marker_priority = priority
	_apply_priority()

func set_animation(anim_type: AnimationType) -> void:
	animation_type = anim_type

func set_highlighted(highlighted: bool) -> void:
	is_highlighted = highlighted
	if not highlighted:
		# Reset scale and color when unhighlighted
		if _marker_mesh:
			_marker_mesh.scale = Vector3.ONE * _base_scale
			if _marker_material:
				var reset_color := marker_color
				reset_color.a = marker_color.a * _fade_progress
				_marker_material.albedo_color = reset_color

		if _label_3d:
			_label_3d.scale = Vector3.ONE * _base_scale
			_label_3d.modulate = marker_color
			_label_3d.modulate.a = marker_color.a * _fade_progress

func set_marker_color(color: Color) -> void:
	marker_color = color

	# Update mesh-based markers
	if _marker_mesh and _marker_material:
		_marker_material.albedo_color = color

	# Update elevation indicator
	if _elevation_mesh and _elevation_material:
		_elevation_material.albedo_color = color

	# Update Label3D markers
	if _label_3d:
		_label_3d.modulate = color
