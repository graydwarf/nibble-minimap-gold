extends Control
## Visual representation of a POI marker on the minimap.

var marker_color: Color = Color.WHITE
var marker_type: String = "default"
var marker_icon: Texture2D = null
var marker_label: String = ""

const LABEL_FONT_SIZE := 10
const LABEL_OFFSET := Vector2(0, 13)  # Below marker

func _draw() -> void:
	var center := size / 2

	if marker_icon:
		# Draw icon centered
		var icon_size := marker_icon.get_size()
		var icon_pos := center - icon_size / 2
		draw_texture(marker_icon, icon_pos, marker_color)
	else:
		# Draw filled circle as fallback
		var radius: float = minf(size.x, size.y) * 0.4
		draw_circle(center, radius, marker_color)
		draw_arc(center, radius, 0, TAU, 16, Color(0, 0, 0, 0.5), 1.5)

	# Draw label if present
	if marker_label != "":
		var font := ThemeDB.fallback_font
		var text_size := font.get_string_size(marker_label, HORIZONTAL_ALIGNMENT_CENTER, -1, LABEL_FONT_SIZE)
		var label_pos := center + LABEL_OFFSET - Vector2(text_size.x / 2, 0)

		# Shadow for readability
		draw_string(font, label_pos + Vector2(1, 1), marker_label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, Color(0, 0, 0, 0.7))
		# Text
		draw_string(font, label_pos, marker_label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, Color.WHITE)

func set_marker_color(color: Color) -> void:
	marker_color = color
	queue_redraw()

func set_icon(icon: Texture2D) -> void:
	marker_icon = icon
	queue_redraw()

func set_label(text: String) -> void:
	marker_label = text
	queue_redraw()
