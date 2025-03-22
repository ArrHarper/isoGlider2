@tool
class_name GridCoordinateConverter
extends RefCounted

# Reference to parent grid manager (for configuration access)
var grid_manager = null

func _init(parent_grid_manager):
	grid_manager = parent_grid_manager

# Convert grid coordinates to screen coordinates for isometric rendering
func grid_to_screen(grid_pos) -> Vector2:
	if typeof(grid_pos) == TYPE_VECTOR2:
		var screen_x = (grid_pos.x - grid_pos.y) * (grid_manager.tile_width / 2.0)
		var screen_y = (grid_pos.x + grid_pos.y) * (grid_manager.tile_height / 2.0)
		return Vector2(screen_x, screen_y)
	else:
		# If not a Vector2, assume it's just the x coordinate and y is 0
		var x = float(grid_pos)
		var screen_x = x * (grid_manager.tile_width / 2.0)
		var screen_y = x * (grid_manager.tile_height / 2.0)
		return Vector2(screen_x, screen_y)

# Alternative version with explicit x, y parameters
func grid_to_screen_xy(x: float, y: float) -> Vector2:
	var screen_x = (x - y) * (grid_manager.tile_width / 2.0)
	var screen_y = (x + y) * (grid_manager.tile_height / 2.0)
	return Vector2(screen_x, screen_y)

# Convert screen position to grid coordinates
func screen_to_grid(screen_pos: Vector2) -> Vector2:
	var grid_x = (screen_pos.x / (grid_manager.tile_width / 2) + screen_pos.y / (grid_manager.tile_height / 2)) / 2
	var grid_y = (screen_pos.y / (grid_manager.tile_height / 2) - screen_pos.x / (grid_manager.tile_width / 2)) / 2
	return Vector2(round(grid_x), round(grid_y))

# Convert grid coordinates to chess notation (A1, B2, etc.)
func grid_to_chess(grid_pos: Vector2) -> String:
	if not is_valid_grid_position(grid_pos):
		return ""
	
	var chess_col = char(65 + int(grid_pos.x)) # A, B, C, etc.
	var chess_row = int(grid_pos.y) + 1 # 1, 2, 3, etc. (matching grid y-coordinate)
	return "%s%d" % [chess_col, chess_row]

# Convert chess notation (A1, B2, etc.) to grid coordinates
func chess_to_grid(chess_pos: String) -> Vector2:
	if chess_pos.length() < 2:
		return Vector2(-1, -1)
	
	var col = chess_pos[0].to_upper().unicode_at(0) - 65 # A=0, B=1, etc.
	var row = int(chess_pos.substr(1))
	
	var grid_x = col
	var grid_y = row - 1
	
	if is_valid_grid_position(Vector2(grid_x, grid_y)):
		return Vector2(grid_x, grid_y)
	else:
		return Vector2(-1, -1)

# Check if a grid position is valid
func is_valid_grid_position(grid_pos: Vector2) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < grid_manager.grid_size_x and grid_pos.y >= 0 and grid_pos.y < grid_manager.grid_size_y

# Convert grid position to chess notation if valid
func get_valid_chess_notation(grid_pos: Vector2) -> String:
	if is_valid_grid_position(grid_pos):
		return grid_to_chess(grid_pos)
	return ""

# Convert chess notation to grid position if valid
func get_valid_grid_position(chess_pos: String) -> Vector2:
	var grid_pos = chess_to_grid(chess_pos)
	if is_valid_grid_position(grid_pos):
		return grid_pos
	return Vector2(-1, -1)

# Convert screen coordinates directly to chess notation
func screen_to_chess(screen_pos: Vector2) -> String:
	var grid_pos = screen_to_grid(screen_pos)
	return get_valid_chess_notation(grid_pos)