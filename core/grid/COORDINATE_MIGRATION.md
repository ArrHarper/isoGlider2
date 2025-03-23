# Coordinate Conversion Migration Guide

## Overview

We've refactored coordinate conversion to improve separation of concerns. The `GridCoordinateConverter` now handles all coordinate conversion operations directly, removing redundant wrapper methods from the `GridManager`.

## How to Update Your Code

### Previous Pattern

```gdscript
# Before: Using GridManager wrapper methods
var grid_manager = get_node("/path/to/grid_manager")
var screen_pos = grid_manager.grid_to_screen(grid_pos)
var grid_pos = grid_manager.screen_to_grid(screen_pos)
var chess_notation = grid_manager.grid_to_chess(grid_pos)
var is_valid = grid_manager.is_valid_grid_position(grid_pos)
var path = grid_manager.find_gridlocked_path(start_pos, end_pos, 5)
```

### New Pattern

```gdscript
# After: Using coordinate converter directly
# Option 1: Through GridManager
var grid_manager = get_node("/path/to/grid_manager")
var converter = grid_manager.coordinate_converter
var screen_pos = converter.grid_to_screen(grid_pos)
var grid_pos = converter.screen_to_grid(screen_pos)
var chess_notation = converter.grid_to_chess(grid_pos)
var is_valid = converter.is_valid_grid_position(grid_pos)
var path = converter.find_gridlocked_path(start_pos, end_pos, 5)

# Option 2: Using singleton accessor (available anywhere)
var converter = GridCoordinateConverter.get_instance()
var screen_pos = converter.grid_to_screen(grid_pos)
var grid_pos = converter.screen_to_grid(screen_pos)
var chess_notation = converter.grid_to_chess(grid_pos)
var is_valid = converter.is_valid_grid_position(grid_pos)
var path = converter.find_gridlocked_path(start_pos, end_pos, 5)
```

## Methods Moved to GridCoordinateConverter

- `grid_to_screen(grid_pos) -> Vector2`
- `grid_to_screen_xy(x, y) -> Vector2`
- `screen_to_grid(screen_pos) -> Vector2`
- `grid_to_chess(grid_pos) -> String`
- `chess_to_grid(chess_pos) -> Vector2`
- `is_valid_grid_position(grid_pos) -> bool`
- `get_valid_chess_notation(grid_pos) -> String`
- `get_valid_grid_position(chess_pos) -> Vector2`
- `screen_to_chess(screen_pos) -> String`
- `find_gridlocked_path(start_pos, end_pos, max_distance) -> Array`
- `is_position_reachable(start_pos, target_pos, max_distance) -> bool`
- `get_grid_name(grid_pos) -> String`

## New Methods in GridCoordinateConverter

- `get_manhattan_distance(start_pos, end_pos) -> int`
- `is_valid_and_passable(grid_pos, check_objects) -> bool`
- `get_chess_adjacency(chess_pos) -> Dictionary`
- `get_chess_in_direction(chess_pos, direction, distance) -> String`
- `get_positions_within_distance(start_pos, max_distance) -> Array`

## Benefits of This Change

- **Clearer responsibilities**: Coordinate conversion is now fully owned by `GridCoordinateConverter`
- **Reduced coupling**: Systems can directly use the converter without going through `GridManager`
- **Enhanced functionality**: New methods added to make coordinate operations more powerful
- **Better maintainability**: Easier to understand and extend the coordinate system

## Remaining GridManager Responsibilities

The `GridManager` still handles:
- Tile passability checking via `is_tile_passable()`
- Object registration and management
- Grid visualization
- Path visualization
- Player management
- Signal coordination 