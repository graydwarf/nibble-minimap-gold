extends Control
## Player arrow marker on the minimap using Sprite2D for web compatibility.

var _arrow_sprite: Sprite2D = null

func _ready() -> void:
	_arrow_sprite = Sprite2D.new()

	# Load texture
	if ResourceLoader.exists("res://assets/icons/player_arrow.svg"):
		_arrow_sprite.texture = load("res://assets/icons/player_arrow.svg")

	add_child(_arrow_sprite)
	_update_arrow()

func _process(_delta: float) -> void:
	_update_arrow()

func _update_arrow() -> void:
	if not _arrow_sprite:
		return

	# Center the sprite in the control
	_arrow_sprite.position = size / 2
