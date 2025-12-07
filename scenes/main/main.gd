extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var minimap: Control = $CanvasLayer/Minimap
@onready var hint_label: Label = $CanvasLayer/HintLabel
@onready var terrain_manager: Node3D = $TerrainManager

var config_dialog: Control = null
var collectibles: Dictionary = {}  # collectible_node -> marker_id
const SPAWN_RANGE := 40.0  # Stay within terrain chunk
const NUM_COLLECTIBLES := 8  # Number of pellets to spawn

const WandererScene = preload("res://scenes/entities/wanderer.tscn")
const CollectibleScene = preload("res://scenes/entities/collectible.tscn")

func _ready() -> void:
	# Add player to group for collectible detection
	player.add_to_group("player")

	minimap.set_player(player)
	player.camera_mode_changed.connect(_on_camera_mode_changed)
	# Set initial label
	_on_camera_mode_changed("FIRST_PERSON")
	# Spawn collectible pellets
	_spawn_collectibles()
	# Spawn roaming NPCs
	_spawn_wanderers()
	# Demo waypoints
	_spawn_waypoints()
	# Create config dialog
	_create_config_dialog()

func _process(_delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_M:
				_toggle_config_dialog()
				get_viewport().set_input_as_handled()
			KEY_TAB:
				minimap.cycle_active_waypoint()
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
	hint_label.text = "WASD: Move | V: %s | Tab: Waypoint | M: Settings | Scroll: Zoom" % mode_name

func _spawn_collectibles() -> void:
	# Spawn collectible pellets spread around the terrain
	var colors := [
		Color(0.3, 0.7, 1.0),   # Blue
		Color(0.3, 1.0, 0.5),   # Green
		Color(1.0, 0.8, 0.2),   # Gold
		Color(1.0, 0.4, 0.4),   # Red
	]

	for i in NUM_COLLECTIBLES:
		_spawn_single_collectible(colors[i % colors.size()])

func _spawn_single_collectible(color: Color) -> void:
	var collectible: Area3D = CollectibleScene.instantiate()
	collectible.pellet_color = color

	# Random position within spawn range
	var spawn_pos := _get_terrain_pos(
		randf_range(-SPAWN_RANGE, SPAWN_RANGE),
		randf_range(-SPAWN_RANGE, SPAWN_RANGE)
	)

	add_child(collectible)
	collectible.global_position = spawn_pos

	# Add tracked marker for this collectible
	var marker_id := minimap.add_tracked_marker(collectible, "loot")
	collectibles[collectible] = marker_id

	# Connect collection signal
	collectible.collected.connect(_on_collectible_collected)

func _on_collectible_collected(collectible: Node3D) -> void:
	# Remove marker from minimap
	if collectible in collectibles:
		minimap.remove_tracked_marker(collectibles[collectible])
		collectibles.erase(collectible)

	# Get color before destroying
	var color: Color = collectible.pellet_color

	# Remove the collectible
	collectible.queue_free()

	# Respawn after delay
	get_tree().create_timer(3.0).timeout.connect(func(): _spawn_single_collectible(color))

func _spawn_waypoints() -> void:
	# Demo waypoints - pinnable objectives with distance tracking
	minimap.add_waypoint(_get_terrain_pos(40, -30), "Cave Entrance", Color(0.8, 0.5, 1.0))
	minimap.add_waypoint(_get_terrain_pos(-35, 25), "Village", Color(0.3, 0.9, 0.5))
	minimap.add_waypoint(_get_terrain_pos(25, 40), "Tower", Color(1.0, 0.8, 0.3))

# Returns position with terrain height
func _get_terrain_pos(x: float, z: float) -> Vector3:
	var pos := Vector3(x, 0, z)
	if terrain_manager:
		pos.y = terrain_manager.get_height_at(pos)
	return pos

func _spawn_wanderers() -> void:
	# Spawn several roaming NPCs with tracked markers
	var spawn_configs := [
		{"pos": Vector2(20, 20), "color": Color(0.9, 0.2, 0.2), "name": "Goblin"},
		{"pos": Vector2(-25, 15), "color": Color(0.9, 0.4, 0.1), "name": "Orc"},
		{"pos": Vector2(10, -30), "color": Color(0.7, 0.2, 0.7), "name": "Wraith"},
	]

	for config in spawn_configs:
		var wanderer: CharacterBody3D = WandererScene.instantiate()
		wanderer.poi_name = config.name
		wanderer.marker_color = config.color

		# Add to tree first, then set position
		add_child(wanderer)
		var spawn_pos := _get_terrain_pos(config.pos.x, config.pos.y)
		wanderer.global_position = spawn_pos

		# Connect to terrain
		wanderer.set_terrain_manager(terrain_manager)

		# Add tracked marker that follows this wanderer
		minimap.add_tracked_marker(wanderer, "enemy")

