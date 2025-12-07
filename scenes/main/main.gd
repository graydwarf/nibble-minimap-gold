extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var minimap: Control = $CanvasLayer/Minimap
@onready var hint_label: Label = $CanvasLayer/HintLabel

var config_dialog: Control = null
var marker_positions: Dictionary = {}  # marker_id -> Vector3
const PICKUP_DISTANCE := 3.0
const SPAWN_RANGE := 80.0

func _ready() -> void:
	minimap.set_player(player)
	player.camera_mode_changed.connect(_on_camera_mode_changed)
	# Set initial label
	_on_camera_mode_changed("FIRST_PERSON")
	# Demo POI markers
	_spawn_demo_markers()
	# Create config dialog
	_create_config_dialog()

func _process(_delta: float) -> void:
	_check_marker_pickups()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_M:
		_toggle_config_dialog()
		get_viewport().set_input_as_handled()

func _create_config_dialog() -> void:
	var config_scene := load("res://scenes/minimap/minimap_config.tscn")
	config_dialog = config_scene.instantiate()
	config_dialog.visible = false
	$CanvasLayer.add_child(config_dialog)
	config_dialog.setup(minimap)
	config_dialog.closed.connect(_on_config_closed)

func _on_config_closed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _toggle_config_dialog() -> void:
	if config_dialog:
		config_dialog.visible = not config_dialog.visible
		if config_dialog.visible:
			config_dialog._sync_from_minimap()
			# Release mouse so user can interact with dialog
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			# Re-capture mouse for FPS controls
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_camera_mode_changed(mode_name: String) -> void:
	hint_label.text = "WASD: Move | Shift: Sprint | V: %s | M: Settings | Scroll: Zoom | ESC: Mouse" % mode_name

func _spawn_demo_markers() -> void:
	# Spawn various marker types to demo the POI system
	_add_tracked_marker(Vector3(20, 0, -15), "objective", "Quest")
	_add_tracked_marker(Vector3(-25, 0, 10), "enemy", "Goblin")
	_add_tracked_marker(Vector3(40, 0, 30), "loot", "Chest")
	_add_tracked_marker(Vector3(-35, 0, -40), "friendly", "NPC")
	_add_tracked_marker(Vector3(50, 0, -20), "waypoint")
	_add_tracked_marker(Vector3(-15, 0, 45), "enemy")
	_add_tracked_marker(Vector3(60, 0, 60), "loot", "Rare")

func _add_tracked_marker(pos: Vector3, marker_type: String, label: String = "") -> int:
	var marker_id: int = minimap.add_marker(pos, marker_type, label)
	marker_positions[marker_id] = {"pos": pos, "type": marker_type, "label": label}
	return marker_id

func _check_marker_pickups() -> void:
	var player_pos := player.global_position
	var to_respawn: Array = []

	for marker_id in marker_positions:
		var data: Dictionary = marker_positions[marker_id]
		var distance := player_pos.distance_to(data.pos)
		if distance < PICKUP_DISTANCE:
			to_respawn.append(marker_id)

	for marker_id in to_respawn:
		_respawn_marker(marker_id)

func _respawn_marker(old_id: int) -> void:
	var data: Dictionary = marker_positions[old_id]
	minimap.remove_marker(old_id)
	marker_positions.erase(old_id)

	# Spawn at new random location
	var new_pos := Vector3(
		randf_range(-SPAWN_RANGE, SPAWN_RANGE),
		0,
		randf_range(-SPAWN_RANGE, SPAWN_RANGE)
	)
	_add_tracked_marker(new_pos, data.type, data.label)
