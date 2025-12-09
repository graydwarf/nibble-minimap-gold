extends Area3D
## Floating collectible pellet that bobs up and down.
## Emits signal when collected by player.

signal collected(collectible: Node3D)

@export var pellet_color: Color = Color(0.3, 0.7, 1.0)  # Blue
@export var pellet_size: float = 0.4
@export var bob_speed: float = 2.0
@export var bob_height: float = 0.3
@export var spin_speed: float = 1.5

var _mesh: MeshInstance3D
var _base_y: float = 0.0
var _time: float = 0.0

func _ready() -> void:
	_time = randf() * TAU  # Random start phase
	_create_visual()
	_create_collision()
	body_entered.connect(_on_body_entered)

func _create_visual() -> void:
	_mesh = MeshInstance3D.new()

	# Sphere pellet
	var sphere := SphereMesh.new()
	sphere.radius = pellet_size / 2.0
	sphere.height = pellet_size
	sphere.radial_segments = 16
	sphere.rings = 8
	_mesh.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = pellet_color
	mat.emission_enabled = true
	mat.emission = pellet_color * 0.5
	mat.emission_energy_multiplier = 0.5
	_mesh.material_override = mat

	_mesh.position.y = 1.0  # Float above ground
	add_child(_mesh)
	_base_y = _mesh.position.y

func _create_collision() -> void:
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = pellet_size * 1.5  # Slightly larger for easier pickup
	collision.shape = shape
	collision.position.y = 1.0
	add_child(collision)

func _process(delta: float) -> void:
	_time += delta

	if _mesh:
		# Bob up and down
		_mesh.position.y = _base_y + sin(_time * bob_speed) * bob_height
		# Spin slowly
		_mesh.rotation.y += spin_speed * delta

func _on_body_entered(body: Node3D) -> void:
	# Only respond to player
	if body.is_in_group("player") or body.name == "Player":
		collected.emit(self)
