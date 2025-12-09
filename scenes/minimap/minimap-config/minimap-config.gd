extends PanelContainer
## Configuration dialog for minimap runtime settings.
## Toggle with M key.

const DEBUG_VERBOSE: bool = false

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

	# Opacity - use getter for web compatibility (properties not always accessible on web)
	var opacity_value: float = 0.85  # Default fallback
	if minimap.has_method("get_opacity"):
		opacity_value = minimap.get_opacity()
	else:
		opacity_value = minimap.opacity
	opacity_slider.value = opacity_value
	opacity_label.text = "%d%%" % int(opacity_value * 100)

	# Cardinals
	cardinals_check.button_pressed = minimap.show_cardinal_directions

	# Marker visibility - use getter for web compatibility
	resource_check.button_pressed = minimap.show_resource_markers
	var view_dist: float = 40.0  # Default fallback
	if minimap.has_method("get_marker_view_distance"):
		view_dist = minimap.get_marker_view_distance()
	else:
		view_dist = minimap.marker_view_distance
	distance_slider.value = view_dist
	distance_label.text = "%dm" % int(view_dist)

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
		if DEBUG_VERBOSE: print("[CONFIG] Opacity changed to %s" % value)
		# Use public method to ensure web compatibility
		if minimap.has_method("set_opacity"):
			minimap.set_opacity(value)
		else:
			minimap.opacity = value
		opacity_label.text = "%d%%" % int(value * 100)
		if DEBUG_VERBOSE: print("[CONFIG] Minimap opacity now=%s, modulate.a=%s" % [minimap.opacity, minimap.modulate.a])

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
		if DEBUG_VERBOSE: print("[CONFIG] View distance changed to %s" % value)
		# Use setter method for web compatibility
		if minimap.has_method("set_marker_view_distance"):
			minimap.set_marker_view_distance(value)
		else:
			minimap.marker_view_distance = value
		distance_label.text = "%dm" % int(value)
		# Update existing tracked markers (loot and enemy) - use getter for web compatibility
		var tracked: Dictionary = {}
		if minimap.has_method("get_tracked_markers"):
			tracked = minimap.get_tracked_markers()
		else:
			tracked = minimap._tracked_markers
		for marker_id in tracked:
			var data: Dictionary = tracked[marker_id]
			if data.type in ["loot", "enemy"] and data.node:
				if data.node.has_method("set_visibility_distance"):
					data.node.set_visibility_distance(value)
				else:
					data.node.visibility_distance = value
		# Use getter for logging
		var actual_dist: float = 0.0
		if minimap.has_method("get_marker_view_distance"):
			actual_dist = minimap.get_marker_view_distance()
		if DEBUG_VERBOSE: print("[CONFIG] Updated marker_view_distance=%s" % actual_dist)

func _on_close_pressed() -> void:
	hide()
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
