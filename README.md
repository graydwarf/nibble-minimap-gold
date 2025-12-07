# Nibble Minimap Bronze

A configurable mini-map component for Godot 4.x that shows "where you are" with player position tracking and cardinal direction indicators.

## Features

- **SubViewport-based mini-map** - Renders world from overhead camera
- **Configurable position** - Place in any corner or custom position
- **Adjustable size** - Set map dimensions via inspector
- **Multiple camera view modes** - Top-down, 2.5D angled, or perspective
- **Player marker** - 2D vector arrow showing position and facing direction
- **Cardinal directions** - N/S/E/W indicators on map border

## Installation

1. Copy the `scenes/minimap/` folder to your project
2. Instance `minimap.tscn` as a child of a CanvasLayer
3. Call `minimap.set_player(player_node)` to connect your player

## Usage

```gdscript
@onready var minimap: Control = $CanvasLayer/Minimap

func _ready() -> void:
	minimap.set_player($Player)
```

## Configuration (Inspector)

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `map_size` | Vector2i | (200, 200) | Minimap dimensions in pixels |
| `screen_corner` | enum | TOP_RIGHT | Corner placement (TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT, CUSTOM) |
| `margin` | Vector2 | (16, 16) | Offset from screen edge |
| `custom_position` | Vector2 | (0, 0) | Manual position when corner is CUSTOM |
| `map_view` | enum | TOP_DOWN | Camera angle (TOP_DOWN, ANGLED_25D, PERSPECTIVE_3D) |
| `camera_height` | float | 50.0 | Camera distance from ground |
| `camera_ortho_size` | float | 30.0 | Orthographic camera size |
| `camera_fov` | float | 60.0 | Perspective camera FOV |
| `show_cardinal_directions` | bool | true | Show N/S/E/W labels |
| `show_all_cardinals` | bool | true | Show all 4 directions (false = N only) |

## Demo Controls

The included demo scene provides:

- **WASD** - Move player
- **Shift** - Sprint
- **V** - Cycle game camera view (First Person, Third Person, 2.5D, Top-Down)
- **ESC** - Release mouse
- **Click** - Capture mouse

## API

```gdscript
# Connect player for tracking
func set_player(player_node: Node3D) -> void

# Change view mode at runtime
func set_view_mode(mode: MapView) -> void

# Cycle through view modes
func cycle_view_mode() -> void
```

## File Structure

```
scenes/minimap/
├── minimap.tscn          # Main minimap scene
├── minimap.gd            # Minimap controller
├── player_arrow.gd       # 2D vector arrow marker
└── cardinal_indicator.gd # N/S/E/W label renderer
```

## Requirements

- Godot 4.x
- Your player must be a Node3D with `global_position` and `rotation.y` accessible

## License

MIT License - See LICENSE file
