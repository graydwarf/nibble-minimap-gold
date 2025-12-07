extends Node3D
## Generates stylized visual markers scattered across the terrain.
## Markers help players see their movement and orient themselves.

@export var marker_count: int = 30
@export var map_bounds: Vector2 = Vector2(45, 45)  # Half-size (stay within terrain chunk)
@export var min_distance_from_center: float = 5.0

var terrain_manager: Node3D  # TerrainManager

# Color palette for markers (low-poly stylized look)
const COLORS := [
	Color(0.9, 0.3, 0.3),   # Red
	Color(0.3, 0.7, 0.4),   # Green
	Color(0.3, 0.5, 0.9),   # Blue
	Color(0.9, 0.7, 0.2),   # Yellow/Gold
	Color(0.7, 0.3, 0.8),   # Purple
	Color(0.2, 0.8, 0.8),   # Cyan
]

func _ready() -> void:
	# Wait for terrain to be ready before placing markers
	terrain_manager = get_parent().get_node_or_null("TerrainManager")
	if terrain_manager:
		if terrain_manager.is_ready():
			_generate_markers()
		else:
			terrain_manager.terrain_ready.connect(_generate_markers)
	else:
		_generate_markers()

func _generate_markers() -> void:
	for i in range(marker_count):
		var marker := _create_random_marker()

		# Random position within rectangular map bounds
		var pos := Vector3.ZERO
		var attempts := 0
		while attempts < 10:
			pos = Vector3(
				randf_range(-map_bounds.x, map_bounds.x),
				0,
				randf_range(-map_bounds.y, map_bounds.y)
			)
			# Avoid spawning too close to center (player spawn)
			if pos.length() >= min_distance_from_center:
				break
			attempts += 1

		# Place on terrain if available
		if terrain_manager:
			pos.y = terrain_manager.get_height_at(pos)

		marker.position = pos
		add_child(marker)

func _create_random_marker() -> Node3D:
	var root := Node3D.new()

	# Random marker type
	var marker_type := randi() % 4
	var mesh: Mesh
	var height: float

	match marker_type:
		0:  # Crystal/Gem
			mesh = _create_crystal_mesh()
			height = randf_range(0.8, 2.0)
		1:  # Pillar
			mesh = _create_pillar_mesh()
			height = randf_range(1.0, 2.5)
		2:  # Rock
			mesh = _create_rock_mesh()
			height = randf_range(0.5, 1.2)
		3:  # Tree-like
			mesh = _create_tree_mesh()
			height = randf_range(1.5, 3.0)

	# Random color and create material
	var color: Color = COLORS[randi() % COLORS.size()]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7

	# Main mesh
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position.y = height / 2.0
	mesh_instance.scale = Vector3(1, height, 1)
	root.add_child(mesh_instance)

	# Random rotation
	root.rotation.y = randf() * TAU

	return root

func _create_crystal_mesh() -> Mesh:
	var prism := PrismMesh.new()
	prism.size = Vector3(0.5, 1.0, 0.5)
	return prism

func _create_pillar_mesh() -> Mesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.2
	cylinder.bottom_radius = 0.35
	cylinder.height = 1.0
	cylinder.radial_segments = 6  # Hexagonal for low-poly look
	return cylinder

func _create_rock_mesh() -> Mesh:
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 1.0, 0.6)
	return box

func _create_tree_mesh() -> Mesh:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.6
	cone.height = 1.0
	cone.radial_segments = 5  # Pentagonal for stylized look
	return cone
