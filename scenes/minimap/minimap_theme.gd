extends Resource
class_name MinimapTheme
## Resource for defining minimap visual themes.

@export_group("General")
@export var theme_name: String = "Default"
@export var background_color: Color = Color(0.1, 0.12, 0.15, 0.85)
@export var border_color: Color = Color(0.3, 0.35, 0.4, 1.0)
@export var border_width: float = 2.0

@export_group("Player Marker")
@export var player_color: Color = Color(0.3, 0.8, 1.0)  # Cyan
@export var player_outline_color: Color = Color(0.1, 0.1, 0.1)

@export_group("Marker Colors")
@export var marker_default: Color = Color.WHITE
@export var marker_enemy: Color = Color(1.0, 0.3, 0.3)  # Red
@export var marker_friendly: Color = Color(0.3, 1.0, 0.3)  # Green
@export var marker_objective: Color = Color(1.0, 0.9, 0.2)  # Yellow
@export var marker_loot: Color = Color(0.3, 0.7, 1.0)  # Blue

@export_group("Waypoint")
@export var waypoint_color: Color = Color(0.8, 0.5, 1.0)  # Purple
@export var waypoint_active_color: Color = Color(1.0, 0.7, 1.0)  # Brighter purple

@export_group("Trail")
@export var trail_color: Color = Color(0.3, 0.7, 1.0, 0.8)  # Light blue

@export_group("Fog of War")
@export var fog_color: Color = Color(0.1, 0.1, 0.15, 0.9)

@export_group("Cardinal Directions")
@export var cardinal_color: Color = Color(0.8, 0.8, 0.8)
@export var cardinal_north_color: Color = Color(1.0, 0.3, 0.3)  # Red for North

# Helper to get marker color by type
func get_marker_color(marker_type: String) -> Color:
	match marker_type:
		"enemy":
			return marker_enemy
		"friendly":
			return marker_friendly
		"objective":
			return marker_objective
		"loot":
			return marker_loot
		_:
			return marker_default
