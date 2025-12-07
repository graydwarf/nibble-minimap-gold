extends Control
## Horizontal compass bar showing cardinal directions and nearby markers.

# Signal for future marker interaction
@warning_ignore("unused_signal")
signal marker_clicked(marker_id: int)

@export var bar_height: float = 40.0
@export var bar_color: Color = Color(0.1, 0.12, 0.15, 0.85)
@export var border_color: Color = Color(0.3, 0.35, 0.4, 1.0)
@export var text_color: Color = Color(0.9, 0.9, 0.9)
@export var north_color: Color = Color(1.0, 0.3, 0.3)  # Red for N
@export var marker_visible_angle: float = 90.0  # How wide the view is (degrees)

var player: Node3D = null
var _minimap: Control = null  # Reference to minimap for marker data

# Cardinal direction positions (degrees from north)
const CARDINALS := {
	"N": 0.0,
	"NE": 45.0,
	"E": 90.0,
	"SE": 135.0,
	"S": 180.0,
	"SW": 225.0,
	"W": 270.0,
	"NW": 315.0,
}

func _ready() -> void:
	custom_minimum_size.y = bar_height
	size.y = bar_height
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(minimap: Control) -> void:
	_minimap = minimap
	if minimap:
		player = minimap.player

func set_player(player_node: Node3D) -> void:
	player = player_node

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)

	# Background
	draw_rect(rect, bar_color)

	# Border
	draw_rect(rect, border_color, false, 2.0)

	# Center line (player facing direction)
	var center_x := size.x / 2.0
	draw_line(Vector2(center_x, 0), Vector2(center_x, size.y), Color(1, 1, 1, 0.3), 1.0)

	if not player:
		return

	var heading := _get_player_heading()

	# Draw cardinal directions
	_draw_cardinals(heading)

	# Draw markers from minimap
	if _minimap:
		_draw_markers(heading)

func _process(_delta: float) -> void:
	queue_redraw()

func _get_player_heading() -> float:
	if not player:
		return 0.0
	# Get player's Y rotation in degrees (0-360, 0 = facing positive Z / North)
	var yaw := player.rotation.y
	return fmod(rad_to_deg(-yaw) + 360.0, 360.0)

func _draw_cardinals(heading: float) -> void:
	var half_view := marker_visible_angle / 2.0
	var center_x := size.x / 2.0

	for cardinal_name: String in CARDINALS:
		var cardinal_angle: float = CARDINALS[cardinal_name]
		var relative := _angle_diff(heading, cardinal_angle)

		if absf(relative) <= half_view:
			# Calculate X position
			var x := center_x + (relative / half_view) * center_x

			# Draw text
			var color := north_color if cardinal_name == "N" else text_color
			var font := ThemeDB.fallback_font
			var font_size := 16
			var text_size := font.get_string_size(cardinal_name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var text_pos := Vector2(x - text_size.x / 2, size.y / 2 + text_size.y / 4)

			draw_string(font, text_pos, cardinal_name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)

			# Draw tick mark
			var tick_y := 4.0
			draw_line(Vector2(x, tick_y), Vector2(x, tick_y + 6), color, 2.0)

func _draw_markers(heading: float) -> void:
	var half_view := marker_visible_angle / 2.0
	var center_x := size.x / 2.0
	var player_pos := player.global_position

	# Get markers from minimap
	var all_markers := {}
	if _minimap.get("_markers"):
		all_markers.merge(_minimap._markers)
	if _minimap.get("_tracked_markers"):
		all_markers.merge(_minimap._tracked_markers)
	if _minimap.get("_waypoints"):
		all_markers.merge(_minimap._waypoints)

	for marker_id: int in all_markers:
		var marker_data: Dictionary = all_markers[marker_id]
		var marker_node: Node3D = marker_data.get("node")
		if not marker_node:
			continue

		var marker_pos: Vector3 = marker_node.global_position
		var to_marker := marker_pos - player_pos
		to_marker.y = 0  # Ignore vertical difference

		if to_marker.length() < 0.1:
			continue

		# Calculate angle to marker from player's perspective
		var angle_to_marker := rad_to_deg(atan2(to_marker.x, to_marker.z))
		angle_to_marker = fmod(angle_to_marker + 360.0, 360.0)

		var relative := _angle_diff(heading, angle_to_marker)

		if absf(relative) <= half_view:
			var x := center_x + (relative / half_view) * center_x

			# Get color based on marker type
			var marker_type: String = marker_data.get("type", "default")
			var color := _get_marker_color(marker_type)

			# Draw marker symbol
			var symbol := _get_marker_symbol(marker_type)
			var font := ThemeDB.fallback_font
			var font_size := 20
			var text_size := font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var text_pos := Vector2(x - text_size.x / 2, size.y - 8)

			draw_string(font, text_pos, symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)

# Returns angle difference in range [-180, 180]
func _angle_diff(from: float, to: float) -> float:
	var diff := fmod(to - from + 540.0, 360.0) - 180.0
	return diff

func _get_marker_color(marker_type: String) -> Color:
	match marker_type:
		"enemy":
			return Color(1.0, 0.3, 0.3)
		"friendly":
			return Color(0.3, 1.0, 0.3)
		"objective":
			return Color(1.0, 0.9, 0.2)
		"loot":
			return Color(0.3, 0.7, 1.0)
		"waypoint":
			return Color(0.8, 0.5, 1.0)
		_:
			return Color.WHITE

func _get_marker_symbol(marker_type: String) -> String:
	match marker_type:
		"enemy":
			return "●"
		"friendly":
			return "●"
		"loot":
			return "★"
		"waypoint":
			return "◆"
		_:
			return "•"
