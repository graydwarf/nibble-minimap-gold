extends CanvasLayer
## On-screen debug console for web builds where browser console isn't accessible.
## Usage: DebugConsole.log("message") from anywhere

var _panel: PanelContainer
var _scroll: ScrollContainer
var _label: Label
var _messages: PackedStringArray = []
const MAX_MESSAGES := 50

func _ready() -> void:
	layer = 100  # On top of everything

	# Create panel
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_right = 0.4
	_panel.anchor_bottom = 0.5
	_panel.offset_left = 10
	_panel.offset_top = 10
	_panel.offset_right = -10
	_panel.offset_bottom = -10

	# Semi-transparent background
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)

	add_child(_panel)

	# Create scroll container
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_panel.add_child(_scroll)

	# Create label
	_label = Label.new()
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	_scroll.add_child(_label)

	self.log("Debug Console Ready")

func log(message: String) -> void:
	var timestamp := Time.get_time_string_from_system().substr(0, 8)
	_messages.append("[%s] %s" % [timestamp, message])

	# Limit messages
	while _messages.size() > MAX_MESSAGES:
		_messages.remove_at(0)

	_label.text = "\n".join(_messages)

	# Auto-scroll to bottom
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func clear() -> void:
	_messages.clear()
	_label.text = ""
