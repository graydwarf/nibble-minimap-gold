extends Control
## Player arrow marker on the minimap using TextureRect for web compatibility.

var _arrow_rect: TextureRect = null

const ARROW_SIZE := Vector2(24, 24)

func _ready() -> void:
	_arrow_rect = TextureRect.new()
	_arrow_rect.custom_minimum_size = ARROW_SIZE
	_arrow_rect.size = ARROW_SIZE
	_arrow_rect.pivot_offset = ARROW_SIZE / 2  # Rotate around center

	# Load texture
	if ResourceLoader.exists("res://assets/icons/player_arrow.svg"):
		_arrow_rect.texture = load("res://assets/icons/player_arrow.svg")

	add_child(_arrow_rect)
	_update_arrow()

func _process(_delta: float) -> void:
	_update_arrow()

func _update_arrow() -> void:
	if not _arrow_rect:
		return

	# Center the TextureRect in the control (position is top-left)
	_arrow_rect.position = (size - ARROW_SIZE) / 2
