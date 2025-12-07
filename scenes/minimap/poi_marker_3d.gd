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

var _label_3d: Label3D = null
var _elevation_label: Label3D = null  # Shows ▲ or ▼
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

func _ready() -> void:
	# Randomize starting phase so markers don't all bob in sync
	_time = randf() * TAU
	_create_visual()

func _process(delta: float) -> void:
	_time += delta * _bob_speed
	_pulse_time += delta * 4.0  # Pulse speed

	if _label_3d:
		# Bob up and down
		_label_3d.position.y = _base_y + sin(_time) * _bob_height

		# Fade-in animation
		if _fade_progress < 1.0:
			_fade_progress = minf(_fade_progress + delta / fade_in_duration, 1.0)
			_update_fade()

		# Pulse animation (scale oscillation)
		if animation_type == AnimationType.PULSE or is_highlighted:
			var pulse_amount := 0.15 if is_highlighted else 0.1
			var pulse := 1.0 + sin(_pulse_time) * pulse_amount
			_label_3d.scale = Vector3.ONE * _base_scale * pulse

		# Highlight animation (brightness boost)
		if is_highlighted:
			var glow := 1.0 + sin(_pulse_time * 1.5) * 0.2
			_label_3d.modulate = marker_color * glow
			_label_3d.modulate.a = marker_color.a * _fade_progress

	# Update elevation indicator
	_update_elevation_indicator()

const MINIMAP_LAYER := 20  # Layer 20 for minimap-only objects

func _create_visual() -> void:
	_label_3d = Label3D.new()
	# Different symbols based on marker type
	match marker_type:
		"enemy":
			_label_3d.text = "●"  # Solid dot for enemies
			_label_3d.font_size = 48
		"friendly":
			_label_3d.text = "●"
			_label_3d.font_size = 48
		"loot":
			_label_3d.text = "★"
			_label_3d.font_size = 56
		_:
			_label_3d.text = "?"
			_label_3d.font_size = 72
	_label_3d.pixel_size = 0.05
	_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label_3d.no_depth_test = true
	_label_3d.modulate = marker_color
	_label_3d.outline_size = 8
	_label_3d.outline_modulate = Color(0.1, 0.1, 0.1)
	_label_3d.position.y = _base_y

	# Only visible to minimap camera (layer 20)
	_label_3d.layers = 1 << (MINIMAP_LAYER - 1)

	# Apply default animation for this marker type
	if animation_type == AnimationType.NONE:
		animation_type = TYPE_ANIMATIONS.get(marker_type, AnimationType.NONE)

	# Start invisible for fade-in effect
	_fade_progress = 0.0
	_update_fade()

	# Apply priority (higher renders on top)
	_apply_priority()

	add_child(_label_3d)

	# Create elevation indicator label (hidden by default)
	_create_elevation_label()

func _create_elevation_label() -> void:
	_elevation_label = Label3D.new()
	_elevation_label.name = "ElevationIndicator"
	_elevation_label.text = ""  # Set dynamically
	_elevation_label.font_size = 36
	_elevation_label.pixel_size = 0.04
	_elevation_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_elevation_label.no_depth_test = true
	_elevation_label.modulate = marker_color
	_elevation_label.outline_size = 4
	_elevation_label.outline_modulate = Color(0.1, 0.1, 0.1)
	_elevation_label.position.y = _base_y + 1.2  # Above main marker
	_elevation_label.layers = 1 << (MINIMAP_LAYER - 1)
	_elevation_label.visible = false
	_elevation_label.render_priority = 100  # Always on top
	add_child(_elevation_label)

func _update_elevation_indicator() -> void:
	if not show_elevation_indicator or not _elevation_label or not player_ref:
		if _elevation_label:
			_elevation_label.visible = false
		return

	if not is_instance_valid(player_ref):
		_elevation_label.visible = false
		return

	var height_diff := global_position.y - player_ref.global_position.y

	if absf(height_diff) < elevation_threshold:
		_elevation_label.visible = false
	elif height_diff > 0:
		# Marker is above player
		_elevation_label.text = "▲"
		_elevation_label.visible = true
	else:
		# Marker is below player
		_elevation_label.text = "▼"
		_elevation_label.visible = true

	# Sync elevation label position with main label bob
	if _label_3d and _elevation_label.visible:
		_elevation_label.position.y = _label_3d.position.y + 1.2

func set_player_reference(player: Node3D) -> void:
	player_ref = player

func _update_fade() -> void:
	if not _label_3d:
		return
	var alpha := marker_color.a * _fade_progress
	_label_3d.modulate.a = alpha
	# Also fade the outline
	var outline_alpha := 0.8 * _fade_progress  # Outline slightly transparent
	_label_3d.outline_modulate.a = outline_alpha

func _apply_priority() -> void:
	if not _label_3d:
		return
	# Use type priority if marker_priority not set explicitly
	var priority := marker_priority
	if priority == 0:
		priority = TYPE_PRIORITIES.get(marker_type, 10)
	_label_3d.render_priority = priority

func set_priority(priority: int) -> void:
	marker_priority = priority
	_apply_priority()

func set_animation(anim_type: AnimationType) -> void:
	animation_type = anim_type

func set_highlighted(highlighted: bool) -> void:
	is_highlighted = highlighted
	if not highlighted and _label_3d:
		# Reset scale and color when unhighlighted
		_label_3d.scale = Vector3.ONE * _base_scale
		_label_3d.modulate = marker_color
		_label_3d.modulate.a = marker_color.a * _fade_progress

func set_marker_color(color: Color) -> void:
	marker_color = color
	if _label_3d:
		_label_3d.modulate = color
