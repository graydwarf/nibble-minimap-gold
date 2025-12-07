extends Node3D
## 3D Waypoint marker - vertical beam with diamond icon.
## Has distinct active vs secondary visual states.

# Signal emitted when player reaches this waypoint (for game logic)
@warning_ignore("unused_signal")
signal reached(waypoint_id: int)

var waypoint_id: int = -1
var waypoint_color: Color = Color(0.8, 0.5, 1.0)  # Purple default
var waypoint_priority: int = 50  # Waypoints have high priority by default
const ACTIVE_PRIORITY_BONUS := 10  # Active waypoint gets extra priority

var is_active: bool = false:
	set(value):
		is_active = value
		_update_visual_state()

var _diamond: MeshInstance3D = null
var _diamond_material: StandardMaterial3D = null
var _beam: MeshInstance3D = null
var _base_y: float = 3.0
var _bob_speed: float = 3.0
var _bob_height: float = 0.3
var _time: float = 0.0
var _pulse_time: float = 0.0

const ACTIVE_SCALE := 1.3
const INACTIVE_SCALE := 0.8
const INACTIVE_ALPHA := 0.6

func _ready() -> void:
	_time = randf() * TAU
	_create_visual()

func _process(delta: float) -> void:
	_time += delta * _bob_speed
	_pulse_time += delta * 4.0

	if _diamond:
		# Bob up and down
		_diamond.position.y = _base_y + sin(_time) * _bob_height

		# Pulse scale if active
		if is_active:
			var pulse := 1.0 + sin(_pulse_time) * 0.1
			_diamond.scale = Vector3.ONE * ACTIVE_SCALE * pulse

const MINIMAP_LAYER := 20  # Layer for minimap-only objects

func _create_visual() -> void:
	# Create vertical beam
	_beam = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.05
	cylinder.bottom_radius = 0.05
	cylinder.height = 6.0
	_beam.mesh = cylinder

	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = waypoint_color
	beam_mat.albedo_color.a = 0.3
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam.material_override = beam_mat
	_beam.position.y = 3.0
	_beam.layers = 1 << (MINIMAP_LAYER - 1)  # Only visible to minimap
	add_child(_beam)

	# Create diamond marker (3D mesh instead of Unicode text for web compatibility)
	_diamond = MeshInstance3D.new()
	var diamond_mesh := _create_diamond_mesh()
	_diamond.mesh = diamond_mesh

	_diamond_material = StandardMaterial3D.new()
	_diamond_material.albedo_color = waypoint_color
	_diamond_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_diamond_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_diamond.material_override = _diamond_material
	_diamond.layers = 1 << (MINIMAP_LAYER - 1)  # Only visible to minimap
	_diamond.position.y = _base_y
	add_child(_diamond)

	_update_visual_state()

# Creates a 3D diamond mesh (two pyramids joined at base)
func _create_diamond_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	var size := 2.0  # Diamond width/depth
	var height := 3.0  # Total height

	# Diamond vertices: top, middle 4 corners, bottom
	var top := Vector3(0, height / 2, 0)
	var bottom := Vector3(0, -height / 2, 0)
	var front := Vector3(0, 0, size / 2)
	var back := Vector3(0, 0, -size / 2)
	var left := Vector3(-size / 2, 0, 0)
	var right := Vector3(size / 2, 0, 0)

	# Top pyramid (4 triangles)
	surface.add_vertex(top); surface.add_vertex(front); surface.add_vertex(right)
	surface.add_vertex(top); surface.add_vertex(right); surface.add_vertex(back)
	surface.add_vertex(top); surface.add_vertex(back); surface.add_vertex(left)
	surface.add_vertex(top); surface.add_vertex(left); surface.add_vertex(front)

	# Bottom pyramid (4 triangles)
	surface.add_vertex(bottom); surface.add_vertex(right); surface.add_vertex(front)
	surface.add_vertex(bottom); surface.add_vertex(back); surface.add_vertex(right)
	surface.add_vertex(bottom); surface.add_vertex(left); surface.add_vertex(back)
	surface.add_vertex(bottom); surface.add_vertex(front); surface.add_vertex(left)

	surface.generate_normals()
	surface.commit(mesh)
	return mesh

func _update_visual_state() -> void:
	if not _diamond or not _beam or not _diamond_material:
		return

	if is_active:
		_diamond.scale = Vector3.ONE * ACTIVE_SCALE
		_diamond_material.albedo_color = waypoint_color
		_diamond_material.albedo_color.a = 1.0

		var beam_mat := _beam.material_override as StandardMaterial3D
		if beam_mat:
			beam_mat.albedo_color = waypoint_color
			beam_mat.albedo_color.a = 0.5
	else:
		_diamond.scale = Vector3.ONE * INACTIVE_SCALE
		_diamond_material.albedo_color = waypoint_color
		_diamond_material.albedo_color.a = INACTIVE_ALPHA

		var beam_mat := _beam.material_override as StandardMaterial3D
		if beam_mat:
			beam_mat.albedo_color = waypoint_color
			beam_mat.albedo_color.a = 0.2

	_apply_priority()

func _apply_priority() -> void:
	# MeshInstance3D uses material render priority
	if _diamond_material:
		var priority := waypoint_priority
		if is_active:
			priority += ACTIVE_PRIORITY_BONUS
		_diamond_material.render_priority = priority

func set_waypoint_color(color: Color) -> void:
	waypoint_color = color
	if _diamond_material:
		_diamond_material.albedo_color = color
		_diamond_material.albedo_color.a = 1.0 if is_active else INACTIVE_ALPHA
	if _beam:
		var beam_mat := _beam.material_override as StandardMaterial3D
		if beam_mat:
			beam_mat.albedo_color = color
			beam_mat.albedo_color.a = 0.5 if is_active else 0.2
	_update_visual_state()
