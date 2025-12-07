extends CharacterBody3D
## Player controller with multiple camera perspectives.
## Supports first-person, third-person, 2.5D, and top-down views.

signal camera_mode_changed(mode_name: String)

enum CameraMode { FIRST_PERSON, THIRD_PERSON, ANGLED_25D, TOP_DOWN }

@export var move_speed: float = 5.0
@export var mouse_sensitivity: float = 0.002
@export var sprint_multiplier: float = 1.8
@export var camera_mode: CameraMode = CameraMode.FIRST_PERSON
@export var map_boundary: float = 45.0  # Keep player within this distance from origin

# Camera offset settings for different modes
const CAMERA_SETTINGS := {
	CameraMode.FIRST_PERSON: { "offset": Vector3(0, 1.6, 0), "rotation": Vector3(0, 0, 0) },
	CameraMode.THIRD_PERSON: { "offset": Vector3(0, 3, 4), "rotation": Vector3(-20, 0, 0) },
	CameraMode.ANGLED_25D: { "offset": Vector3(0, 10, 10), "rotation": Vector3(-45, 0, 0) },
	CameraMode.TOP_DOWN: { "offset": Vector3(0, 15, 0.01), "rotation": Vector3(-89, 0, 0) },
}

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_apply_camera_mode()

func _input(event: InputEvent) -> void:
	# V key cycles camera mode
	if event is InputEventKey and event.pressed and event.keycode == KEY_V:
		cycle_camera_mode()
		return

	# Handle mouse look (only in first-person when captured)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if camera_mode == CameraMode.FIRST_PERSON:
			# Rotate player body (yaw)
			rotate_y(-event.relative.x * mouse_sensitivity)
			# Rotate camera (pitch) - clamped to prevent flipping
			%Camera3D.rotate_x(-event.relative.y * mouse_sensitivity)
			%Camera3D.rotation.x = clamp(%Camera3D.rotation.x, -PI/2 + 0.1, PI/2 - 0.1)
		else:
			# In other modes, only rotate player yaw (no pitch control)
			rotate_y(-event.relative.x * mouse_sensitivity)

	# ESC releases mouse control
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	# Click to recapture mouse (only if no UI handled the click)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	# Get input direction
	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.z += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1

	# Transform to world space based on player rotation
	var direction := (transform.basis * input_dir).normalized()

	# Apply sprint
	var speed := move_speed
	if Input.is_action_pressed("sprint"):
		speed *= sprint_multiplier

	# Set velocity
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	# Simple gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta

	move_and_slide()

	# Clamp position to map boundary
	if map_boundary > 0:
		global_position.x = clampf(global_position.x, -map_boundary, map_boundary)
		global_position.z = clampf(global_position.z, -map_boundary, map_boundary)

# Cycles through camera modes
func cycle_camera_mode() -> void:
	camera_mode = (camera_mode + 1) % CameraMode.size() as CameraMode
	_apply_camera_mode()
	camera_mode_changed.emit(CameraMode.keys()[camera_mode])

func _apply_camera_mode() -> void:
	var settings: Dictionary = CAMERA_SETTINGS[camera_mode]
	%Camera3D.position = settings["offset"]
	%Camera3D.rotation_degrees = settings["rotation"]

# Returns current heading in degrees (0-360, 0=North)
func get_heading() -> float:
	var yaw := rotation.y
	return fmod(rad_to_deg(-yaw) + 360.0, 360.0)
