extends CharacterBody3D
## A wandering AI entity that moves around the terrain.
## Demonstrates dynamic marker tracking on the minimap.

@export var poi_name: String = "Hostile"
@export var marker_color: Color = Color(0.9, 0.2, 0.2)  # Red

@export_group("Movement")
@export var move_speed: float = 3.0
@export var wander_radius: float = 35.0
@export var waypoint_threshold: float = 2.0

var _current_waypoint: Vector3 = Vector3.ZERO
var _terrain_manager: Node3D  # TerrainManager
var _mesh: MeshInstance3D

func _ready() -> void:
	_create_visual()
	_pick_new_waypoint()

func _create_visual() -> void:
	# Simple capsule for NPC body
	_mesh = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	_mesh.mesh = capsule
	_mesh.position.y = 0.8

	var mat := StandardMaterial3D.new()
	mat.albedo_color = marker_color
	_mesh.material_override = mat

	add_child(_mesh)

	# Add collision
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.6
	collision.shape = shape
	collision.position.y = 0.8
	add_child(collision)

func set_terrain_manager(terrain: Node3D) -> void:
	_terrain_manager = terrain
	_update_height()
	_pick_new_waypoint()

func _physics_process(delta: float) -> void:
	if _current_waypoint == Vector3.ZERO:
		return

	var to_waypoint := _current_waypoint - global_position
	to_waypoint.y = 0
	var distance := to_waypoint.length()

	if distance < waypoint_threshold:
		_pick_new_waypoint()
		return

	var direction := to_waypoint.normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0

	move_and_slide()
	_update_height()

	if direction.length() > 0.1:
		var target_angle := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 5.0 * delta)

func _pick_new_waypoint() -> void:
	var angle := randf() * TAU
	var distance := randf_range(10.0, wander_radius)
	var waypoint_x := cos(angle) * distance
	var waypoint_z := sin(angle) * distance

	waypoint_x = clamp(waypoint_x, -wander_radius, wander_radius)
	waypoint_z = clamp(waypoint_z, -wander_radius, wander_radius)

	var waypoint_y := 0.0
	if _terrain_manager:
		waypoint_y = _terrain_manager.get_height_at(Vector3(waypoint_x, 0, waypoint_z))

	_current_waypoint = Vector3(waypoint_x, waypoint_y, waypoint_z)

func _update_height() -> void:
	if _terrain_manager:
		var terrain_height: float = _terrain_manager.get_height_at(global_position)
		global_position.y = lerp(global_position.y, terrain_height + 0.5, 0.3)
