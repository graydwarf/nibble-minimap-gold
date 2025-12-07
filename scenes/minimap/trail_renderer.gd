extends Node3D
## Renders a fading trail behind the player on the minimap.

@export var trail_color: Color = Color(0.3, 0.7, 1.0, 0.8)  # Light blue
@export var trail_length: int = 50  # Number of trail points
@export var trail_spacing: float = 0.5  # Minimum distance between points
@export var trail_duration: float = 10.0  # How long trail points last (seconds)
@export var trail_width: float = 0.15  # Width of trail line

const MINIMAP_LAYER := 20

var _trail_points: Array = []  # Array of { position: Vector3, time: float }
var _last_position: Vector3 = Vector3.ZERO
var _mesh_instance: MeshInstance3D = null
var _immediate_mesh: ImmediateMesh = null
var _material: StandardMaterial3D = null

func _ready() -> void:
	_setup_mesh()

func _setup_mesh() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "TrailMesh"
	_immediate_mesh = ImmediateMesh.new()
	_mesh_instance.mesh = _immediate_mesh

	_material = StandardMaterial3D.new()
	_material.albedo_color = trail_color
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.vertex_color_use_as_albedo = true
	_mesh_instance.material_override = _material

	# Only visible to minimap camera
	_mesh_instance.layers = 1 << (MINIMAP_LAYER - 1)

	add_child(_mesh_instance)

func _process(_delta: float) -> void:
	var current_time := Time.get_ticks_msec() / 1000.0

	# Remove old points
	while _trail_points.size() > 0:
		var oldest: Dictionary = _trail_points[0]
		if current_time - oldest.time > trail_duration:
			_trail_points.pop_front()
		else:
			break

	_rebuild_mesh(current_time)

# Adds a new trail point at the player's position
func add_point(world_pos: Vector3) -> void:
	# Check minimum spacing
	if _trail_points.size() > 0:
		var last: Dictionary = _trail_points.back()
		if world_pos.distance_to(last.position) < trail_spacing:
			return

	var current_time := Time.get_ticks_msec() / 1000.0
	_trail_points.append({
		"position": world_pos,
		"time": current_time
	})

	# Limit trail length
	while _trail_points.size() > trail_length:
		_trail_points.pop_front()

	_last_position = world_pos

func _rebuild_mesh(current_time: float) -> void:
	if not _immediate_mesh:
		return

	_immediate_mesh.clear_surfaces()

	if _trail_points.size() < 2:
		return

	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _material)

	for i in range(_trail_points.size()):
		var point: Dictionary = _trail_points[i]
		var pos: Vector3 = point.position

		# Calculate alpha based on age
		var point_time: float = point.time
		var age: float = current_time - point_time
		var alpha: float = 1.0 - (age / trail_duration)
		alpha = clampf(alpha, 0.0, 1.0)

		# Also fade based on position in trail (oldest = more faded)
		var position_fade := float(i) / float(_trail_points.size())
		alpha *= position_fade

		var color := trail_color
		color.a = trail_color.a * alpha

		# Get direction to next point for width calculation
		var direction := Vector3.FORWARD
		if i < _trail_points.size() - 1:
			direction = (_trail_points[i + 1].position - pos).normalized()
		elif i > 0:
			direction = (pos - _trail_points[i - 1].position).normalized()

		# Calculate perpendicular for trail width
		var right := direction.cross(Vector3.UP).normalized() * trail_width * 0.5

		# Two vertices for triangle strip (left and right of trail center)
		var left_pos := pos - right
		var right_pos := pos + right

		# Slight Y offset to render above ground
		left_pos.y = pos.y + 0.1
		right_pos.y = pos.y + 0.1

		_immediate_mesh.surface_set_color(color)
		_immediate_mesh.surface_add_vertex(left_pos)
		_immediate_mesh.surface_set_color(color)
		_immediate_mesh.surface_add_vertex(right_pos)

	_immediate_mesh.surface_end()

func set_trail_color(color: Color) -> void:
	trail_color = color
	if _material:
		_material.albedo_color = color

func clear_trail() -> void:
	_trail_points.clear()
	if _immediate_mesh:
		_immediate_mesh.clear_surfaces()
