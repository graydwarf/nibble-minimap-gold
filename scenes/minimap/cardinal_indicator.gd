extends Control
## Cardinal direction indicators (N/S/E/W) using Label nodes for web compatibility.

@export var show_all_directions: bool = true  # Show N/S/E/W or just N
@export var font_size: int = 14
@export var text_color: Color = Color(1, 1, 1, 0.8)
@export var north_color: Color = Color(1, 0.3, 0.3, 1)  # Red for North

var _labels: Dictionary = {}  # "N", "E", "S", "W" -> Label

func _ready() -> void:
	_create_labels()
	_update_positions()

func _process(_delta: float) -> void:
	_update_positions()

func _create_labels() -> void:
	for letter in ["N", "E", "S", "W"]:
		var label := Label.new()
		label.text = letter
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		var settings := LabelSettings.new()
		settings.font_size = font_size
		settings.font_color = text_color
		settings.shadow_color = Color(0, 0, 0, 0.5)
		settings.shadow_size = 1
		settings.shadow_offset = Vector2(1, 1)
		label.label_settings = settings

		add_child(label)
		_labels[letter] = label

func _update_positions() -> void:
	var center := size / 2
	var radius := minf(size.x, size.y) / 2 - 12
	var label_offset := 6.0  # Half of approximate label size

	# Position labels centered on their anchor points
	if "N" in _labels:
		_labels["N"].position = center + Vector2(-label_offset, -radius - label_offset)
		_labels["N"].visible = true

	if "E" in _labels:
		_labels["E"].position = center + Vector2(radius - label_offset, -label_offset)
		_labels["E"].visible = show_all_directions

	if "S" in _labels:
		_labels["S"].position = center + Vector2(-label_offset, radius - label_offset * 2)
		_labels["S"].visible = show_all_directions

	if "W" in _labels:
		_labels["W"].position = center + Vector2(-radius - label_offset * 2 + 8, -label_offset)
		_labels["W"].visible = show_all_directions
