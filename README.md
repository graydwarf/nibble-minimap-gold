# Nibble Minimap Gold

A feature-rich mini-map component for Godot 4.x with waypoints, roaming markers, fog of war, trails, theming, and more.

## Gold Features

| Feature | Description |
|---------|-------------|
| **Waypoint System** | Pin waypoints with distance display, cycle with Tab |
| **Roaming NPC Markers** | Track moving entities smoothly |
| **Marker Priority** | Higher priority markers render on top |
| **Animated Markers** | Pulse, highlight, fade-in effects |
| **Trail Rendering** | Breadcrumb path behind player |
| **Theming System** | Swap colors/textures via Resource |
| **Elevation Indicators** | Above/below arrows on markers |
| **Compass Bar** | Horizontal strip (optional) |

## Installation

1. Copy the `scenes/minimap/` folder to your project
2. Instance `minimap.tscn` as a child of a CanvasLayer
3. Call `minimap.set_player(player_node)` to connect your player

```gdscript
@onready var minimap: Control = $CanvasLayer/Minimap

func _ready() -> void:
	minimap.set_player($Player)
```

## Basic Configuration (Inspector)

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `map_size` | Vector2i | (200, 200) | Minimap dimensions in pixels |
| `screen_corner` | enum | TOP_RIGHT | Corner placement |
| `margin` | Vector2 | (16, 16) | Offset from screen edge |
| `map_view` | enum | TOP_DOWN | Camera angle mode |
| `camera_height` | float | 50.0 | Camera distance from ground |
| `camera_ortho_size` | float | 30.0 | Orthographic camera size |
| `opacity` | float | 0.85 | Minimap transparency |

## Gold Feature Configuration

### Zoom
| Property | Default | Description |
|----------|---------|-------------|
| `zoom_enabled` | true | Enable scroll wheel zoom |
| `zoom_min` | 15.0 | Closest zoom (smallest area) |
| `zoom_max` | 60.0 | Farthest zoom (largest area) |
| `zoom_step` | 5.0 | Zoom amount per scroll |

### Trail
| Property | Default | Description |
|----------|---------|-------------|
| `trail_enabled` | true | Enable breadcrumb trail |
| `trail_length` | 50 | Number of trail points |
| `trail_duration` | 10.0 | How long trail points last (seconds) |

### Theme
| Property | Default | Description |
|----------|---------|-------------|
| `minimap_theme` | null | MinimapTheme resource |

### Compass Bar
| Property | Default | Description |
|----------|---------|-------------|
| `compass_bar_enabled` | false | Enable compass bar |
| `compass_bar_width` | 400.0 | Width in pixels |
| `compass_bar_position` | TOP_LEFT | Screen position |

## API Reference

### Player Setup
```gdscript
# Connect player for tracking
func set_player(player_node: Node3D) -> void
```

### Static Markers
```gdscript
# Add marker at world position. Returns marker ID.
# Types: "default", "enemy", "friendly", "objective", "loot"
func add_marker(world_position: Vector3, marker_type: String = "default", label: String = "", priority: int = 0) -> int

# Remove marker by ID
func remove_marker(marker_id: int) -> void

# Update marker position
func update_marker_position(marker_id: int, world_position: Vector3) -> void

# Set marker highlight (pulse/glow effect)
func set_marker_highlighted(marker_id: int, highlighted: bool) -> void

# Clear all markers
func clear_markers() -> void
```

### Tracked Markers (Moving Entities)
```gdscript
# Add marker that follows a moving Node3D. Returns marker ID.
func add_tracked_marker(target: Node3D, marker_type: String = "enemy", label: String = "", priority: int = 0) -> int

# Remove tracked marker by ID
func remove_tracked_marker(marker_id: int) -> void

# Clear all tracked markers
func clear_tracked_markers() -> void
```

### Waypoints
```gdscript
# Add waypoint at position. Returns waypoint ID. First waypoint is auto-active.
func add_waypoint(world_position: Vector3, label: String = "", color: Color = Color(0.8, 0.5, 1.0)) -> int

# Remove waypoint by ID
func remove_waypoint(waypoint_id: int) -> void

# Set which waypoint is active (shows distance)
func set_active_waypoint(waypoint_id: int) -> void

# Cycle to next waypoint
func cycle_active_waypoint() -> void

# Update waypoint position
func update_waypoint_position(waypoint_id: int, world_position: Vector3) -> void

# Get distance to active waypoint (-1 if none)
func get_active_waypoint_distance() -> float

# Get active waypoint label
func get_active_waypoint_label() -> String

# Clear all waypoints
func clear_waypoints() -> void
```

### Zoom
```gdscript
# Zoom in (show smaller area)
func zoom_in() -> void

# Zoom out (show larger area)
func zoom_out() -> void

# Set zoom level directly
func set_zoom(ortho_size: float) -> void
```

### Trail
```gdscript
# Enable/disable trail at runtime
func set_trail_enabled(enabled: bool) -> void

# Clear current trail
func clear_trail() -> void
```

### Theming
```gdscript
# Apply a theme resource
func apply_theme(new_theme: Resource) -> void

# Get marker color (from theme or default)
func get_marker_color(marker_type: String) -> Color
```

### Camera View
```gdscript
# Set view mode (TOP_DOWN, ANGLED_25D, PERSPECTIVE_3D)
func set_view_mode(mode: MapView) -> void

# Cycle through view modes
func cycle_view_mode() -> void
```

## Creating Custom Themes

Create a new MinimapTheme resource:

1. Right-click in FileSystem -> New Resource
2. Select `MinimapTheme`
3. Configure colors in the inspector
4. Assign to minimap's `minimap_theme` property

### Theme Properties
```gdscript
@export var theme_name: String = "Custom"

# Background
@export var background_color: Color = Color(0.08, 0.1, 0.12, 0.9)
@export var border_color: Color = Color(0.4, 0.5, 0.6, 1.0)
@export var border_width: float = 2.0

# Player
@export var player_color: Color = Color(1.0, 1.0, 1.0)
@export var player_outline_color: Color = Color(0.1, 0.1, 0.1)

# Markers
@export var marker_default: Color = Color.WHITE
@export var marker_enemy: Color = Color(1.0, 0.3, 0.3)
@export var marker_friendly: Color = Color(0.3, 1.0, 0.3)
@export var marker_objective: Color = Color(1.0, 0.9, 0.2)
@export var marker_loot: Color = Color(0.3, 0.7, 1.0)

# Waypoints
@export var waypoint_color: Color = Color(0.8, 0.5, 1.0)
@export var waypoint_active_color: Color = Color(1.0, 0.7, 1.0)

# Trail
@export var trail_color: Color = Color(0.3, 0.7, 1.0, 0.8)

# Cardinals
@export var cardinal_color: Color = Color(0.8, 0.8, 0.8)
@export var cardinal_north_color: Color = Color(1.0, 0.4, 0.4)
```

### Included Themes
- `themes/theme_fantasy.tres` - Warm gold/brown medieval style
- `themes/theme_scifi.tres` - Cool cyan/blue futuristic style
- `themes/theme_minimal.tres` - Clean grayscale design

## Demo Controls

| Key | Action |
|-----|--------|
| WASD | Move player |
| Shift | Sprint |
| V | Cycle game camera view |
| Tab | Cycle active waypoint |
| Scroll | Zoom minimap |
| ESC | Release mouse |
| Click | Capture mouse |

## Usage Examples

### Track Enemies
```gdscript
var enemy_marker_id: int = -1

func _on_enemy_spawned(enemy: Node3D) -> void:
    enemy_marker_id = minimap.add_tracked_marker(enemy, "enemy")

func _on_enemy_died() -> void:
    minimap.remove_tracked_marker(enemy_marker_id)
```

### Quest Waypoints
```gdscript
func start_quest(objective_pos: Vector3, objective_name: String) -> void:
    var wp_id = minimap.add_waypoint(objective_pos, objective_name)
    minimap.set_active_waypoint(wp_id)

func complete_quest() -> void:
    minimap.clear_waypoints()
```

### Theme Switching
```gdscript
@export var scifi_theme: Resource  # Assign in inspector

func switch_to_scifi() -> void:
    minimap.apply_theme(scifi_theme)
```

## File Structure

```
scenes/minimap/
├── minimap.tscn              # Main minimap scene
├── minimap.gd                # Minimap controller
├── minimap_theme.gd          # Theme resource class
├── player_arrow.gd           # 2D player marker
├── cardinal_indicator.gd     # N/S/E/W labels
├── edge_arrows.gd            # Off-screen marker arrows
├── poi_marker_3d.gd          # 3D POI markers with animations
├── waypoint_marker_3d.gd     # 3D waypoint beams
├── trail_renderer.gd         # Breadcrumb trail
├── compass_bar.gd            # Horizontal compass strip
└── themes/
    ├── theme_fantasy.tres    # Fantasy theme
    ├── theme_scifi.tres      # Sci-fi theme
    └── theme_minimal.tres    # Minimal theme
```

## Layer System

Minimap markers use visibility layer 20 to be visible only to the minimap camera:
- Markers automatically set `layers = 1 << 19`
- Minimap camera includes layer 20 in its cull_mask
- Your main game camera should NOT include layer 20

## Requirements

- Godot 4.x
- Your player must be a Node3D with accessible `global_position` and `rotation.y`

## License

MIT License - See LICENSE file
