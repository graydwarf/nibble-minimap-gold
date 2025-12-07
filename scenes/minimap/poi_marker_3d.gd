extends Node3D
## 3D POI marker - floating question mark that bobs up and down.

var marker_color: Color = Color(1.0, 0.85, 0.0)  # Gold/yellow
var marker_type: String = "default"

var _label_3d: Label3D = null
var _base_y: float = 2.0
var _bob_speed: float = 2.0
var _bob_height: float = 0.5
var _time: float = 0.0

func _ready() -> void:
	# Randomize starting phase so markers don't all bob in sync
	_time = randf() * TAU
	_create_visual()

func _process(delta: float) -> void:
	_time += delta * _bob_speed
	if _label_3d:
		_label_3d.position.y = _base_y + sin(_time) * _bob_height

func _create_visual() -> void:
	_label_3d = Label3D.new()
	_label_3d.text = "?"
	_label_3d.font_size = 72
	_label_3d.pixel_size = 0.05
	_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label_3d.no_depth_test = true
	_label_3d.modulate = marker_color
	_label_3d.outline_size = 8
	_label_3d.outline_modulate = Color(0.2, 0.15, 0.0)  # Dark gold outline
	_label_3d.position.y = _base_y

	add_child(_label_3d)

func set_marker_color(color: Color) -> void:
	marker_color = color
	if _label_3d:
		_label_3d.modulate = color
