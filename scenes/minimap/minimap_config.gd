extends PanelContainer
## Configuration dialog for minimap runtime settings.
## Toggle with M key.

signal closed

var minimap: Control = null

@onready var size_slider: HSlider = $MarginContainer/VBoxContainer/SizeRow/SizeSlider
@onready var size_label: Label = $MarginContainer/VBoxContainer/SizeRow/SizeValue
@onready var corner_option: OptionButton = $MarginContainer/VBoxContainer/CornerRow/CornerOption
@onready var zoom_slider: HSlider = $MarginContainer/VBoxContainer/ZoomRow/ZoomSlider
@onready var zoom_label: Label = $MarginContainer/VBoxContainer/ZoomRow/ZoomValue
@onready var view_option: OptionButton = $MarginContainer/VBoxContainer/ViewRow/ViewOption
@onready var opacity_slider: HSlider = $MarginContainer/VBoxContainer/OpacityRow/OpacitySlider
@onready var opacity_label: Label = $MarginContainer/VBoxContainer/OpacityRow/OpacityValue
@onready var cardinals_check: CheckBox = $MarginContainer/VBoxContainer/CardinalsRow/CardinalsCheck
@onready var resource_check: CheckBox = $MarginContainer/VBoxContainer/ResourceRow/ResourceCheck
@onready var distance_slider: HSlider = $MarginContainer/VBoxContainer/DistanceRow/DistanceSlider
@onready var distance_label: Label = $MarginContainer/VBoxContainer/DistanceRow/DistanceValue
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton

func _ready() -> void:
	# Block mouse events from passing through to game
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Setup corner options
	corner_option.add_item("Top Left", 0)
	corner_option.add_item("Top Right", 1)
	corner_option.add_item("Bottom Left", 2)
	corner_option.add_item("Bottom Right", 3)

	# Setup view mode options
	view_option.add_item("Top Down", 0)
	view_option.add_item("Angled 2.5D", 1)
	view_option.add_item("Perspective 3D", 2)

	# Connect signals
	size_slider.value_changed.connect(_on_size_changed)
	corner_option.item_selected.connect(_on_corner_changed)
	zoom_slider.value_changed.connect(_on_zoom_changed)
	view_option.item_selected.connect(_on_view_changed)
	opacity_slider.value_changed.connect(_on_opacity_changed)
	cardinals_check.toggled.connect(_on_cardinals_toggled)
	resource_check.toggled.connect(_on_resource_toggled)
	distance_slider.value_changed.connect(_on_distance_changed)
	close_button.pressed.connect(_on_close_pressed)

func setup(minimap_ref: Control) -> void:
	minimap = minimap_ref
	_sync_from_minimap()

func _sync_from_minimap() -> void:
	if not minimap:
		return

	# Size (use x dimension)
	size_slider.value = minimap.map_size.x
	size_label.text = "%d" % minimap.map_size.x

	# Corner
	corner_option.selected = minimap.screen_corner

	# Zoom
	zoom_slider.min_value = minimap.zoom_min
	zoom_slider.max_value = minimap.zoom_max
	zoom_slider.value = minimap.camera_ortho_size
	zoom_label.text = "%d" % minimap.camera_ortho_size

	# View mode
	view_option.selected = minimap.map_view

	# Opacity
	opacity_slider.value = minimap.opacity
	opacity_label.text = "%d%%" % int(minimap.opacity * 100)

	# Cardinals
	cardinals_check.button_pressed = minimap.show_cardinal_directions

	# Marker visibility
	resource_check.button_pressed = minimap.show_resource_markers
	distance_slider.value = minimap.marker_view_distance
	distance_label.text = "%dm" % int(minimap.marker_view_distance)

func _on_size_changed(value: float) -> void:
	if minimap:
		minimap.map_size = Vector2i(int(value), int(value))
		size_label.text = "%d" % int(value)

func _on_corner_changed(index: int) -> void:
	if minimap:
		minimap.screen_corner = index

func _on_zoom_changed(value: float) -> void:
	if minimap:
		minimap.set_zoom(value)
		zoom_label.text = "%d" % int(value)

func _on_view_changed(index: int) -> void:
	if minimap:
		minimap.map_view = index

func _on_opacity_changed(value: float) -> void:
	if minimap:
		# Use public method to ensure web compatibility
		if minimap.has_method("set_opacity"):
			minimap.set_opacity(value)
		else:
			minimap.opacity = value
		opacity_label.text = "%d%%" % int(value * 100)

func _on_cardinals_toggled(pressed: bool) -> void:
	if minimap:
		# Use public method to ensure proper visibility handling
		if minimap.has_method("set_cardinals_visible"):
			minimap.set_cardinals_visible(pressed)
		else:
			minimap.show_cardinal_directions = pressed
			if minimap.cardinal_indicator:
				minimap.cardinal_indicator.visible = pressed

func _on_resource_toggled(pressed: bool) -> void:
	if minimap:
		minimap.show_resource_markers = pressed

func _on_distance_changed(value: float) -> void:
	if minimap:
		minimap.marker_view_distance = value
		distance_label.text = "%dm" % int(value)
		# Update existing tracked markers (loot and enemy)
		for marker_id in minimap._tracked_markers:
			var data: Dictionary = minimap._tracked_markers[marker_id]
			if data.type in ["loot", "enemy"] and data.node:
				data.node.visibility_distance = value

func _on_close_pressed() -> void:
	hide()
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
