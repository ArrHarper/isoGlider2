@tool
extends Node2D


@export_category("Grid Dimensions")
@export var grid_size_x: int = 8:
	set(value):
		grid_size_x = value
		queue_redraw()
@export var grid_size_y: int = 8:
	set(value):
		grid_size_y = value
		queue_redraw()

@export_category("Tile Properties")
@export var tile_width: int = 64:
	set(value):
		tile_width = value
		queue_redraw()
@export var tile_height: int = 32:
	set(value):
		tile_height = value
		queue_redraw()

@export_category("Visual Settings")
@export var show_grid_lines: bool = true:
	set(value):
		show_grid_lines = value
		queue_redraw()
@export var grid_color: Color = Color(0.5, 0.5, 0.5, 0.5):
	set(value):
		grid_color = value
		queue_redraw()
@export var show_tile_coordinates: bool = false:
	set(value):
		show_tile_coordinates = value
		queue_redraw()
@export var highlight_origin: bool = true:
	set(value):
		highlight_origin = value
		queue_redraw()
@export var show_chess_coordinates: bool = true:
	set(value):
		show_chess_coordinates = value
		queue_redraw()
@export var show_chess_labels: bool = true:
	set(value):
		show_chess_labels = value
		queue_redraw()

var grid_tiles = [] # Array of tiles in the grid, stored as a 2D array of Vector2 positions
var hover_grid_pos = Vector2(-1, -1) # Track which tile is being hovered
var target_grid_pos = Vector2(-1, -1) # Track the clicked target tile
var path_tiles = [] # Array of tiles in the calculated path of the player
var player_is_moving = false # Track if the player is currently moving
var movement_state = null # Reference to movement state machine
var impassable_tiles = [] # Array of Vector2 positions that cannot be moved to
var grid_to_chess_friendly = true # Flag to determine if grid coordinates should be converted to chess notation
var grid_visualizer: Node2D
var grid_objects = {}

# # Signal for grid interaction
# signal grid_tile_clicked(grid_pos)

# Dictionary to store grid objects

# These signals are not used in the current implementation, but are kept here for future reference.

# ## Emitted when player completes a movement to a new grid position
# ## @param grid_position: Vector2 representing the grid coordinates the player moved to
# signal player_moved(grid_position)

# ## Emitted when mouse hovers over a grid position
# ## @param grid_position: Vector2 representing the grid coordinates being hovered over
# signal grid_mouse_hover(grid_position)

# ## Emitted when mouse exits the grid
# signal grid_mouse_exit

# ## Emitted with the player's starting tile in chess notation
# ## @param starting_tile: String representing chess notation (e.g. "H8")
# signal player_starting_tile(starting_tile)

# ## Emitted with the player's movement range
# ## @param movement_range: int representing how many tiles the player can move
# signal player_movement_range(movement_range)

# ## Emitted when a player movement path is calculated
# ## @param path_tiles: Array of Vector2 representing each tile in the path including start and destination
# signal player_path_calculated(path_tiles)

# ## Emitted when player wins a round by returning to starting position
# signal round_won

signal grid_mouse_hover(grid_pos)
signal grid_mouse_exit
signal grid_tile_clicked(grid_pos)
signal path_calculated(path)

func _ready():
	print("GridManager initialized")
	if Engine.is_editor_hint():
		# Find visualizer in editor too
		grid_visualizer = get_node_or_null("GridVisualizer")
		return
	
	grid_visualizer = get_node_or_null("GridVisualizer")
	if not grid_visualizer:
		push_error("GridVisualizer must be a child of GridManager")
		
	center_grid_in_viewport()

func _draw():
	if show_grid_lines:
		draw_isometric_grid()
		
		if show_chess_labels:
			draw_chess_labels()

		if highlight_origin:
			# Highlight the origin (0,0) with a different color
			var origin_pos = grid_to_screen(Vector2(0, 0))
			draw_circle(origin_pos, 5, Color.RED)

func draw_isometric_grid():
	# Draw grid tiles
	for x in range(grid_size_x):
		for y in range(grid_size_y):
			draw_isometric_tile(Vector2(x, y))
			
			var center = grid_to_screen(Vector2(x, y))
			
			# Optionally show coordinates
			if show_tile_coordinates:
				draw_string(ThemeDB.fallback_font, center + Vector2(0, -5), "%d,%d" % [x, y], HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
			
			# Optionally show chess coordinates
			if show_chess_coordinates:
				# Convert to chess notation (A-H for columns, 1-8 for rows)
				var chess_col = char(65 + x) # A, B, C, etc.
				var chess_row = grid_size_y - y # 8, 7, 6, etc. (chess has row 1 at bottom)
				draw_string(ThemeDB.fallback_font, center + Vector2(0, 5), "%s%d" % [chess_col, chess_row], HORIZONTAL_ALIGNMENT_CENTER, -1, 10)

func draw_isometric_tile(grid_pos: Vector2):
	# Calculate the four corners of the isometric tile
	var center = grid_to_screen(grid_pos)
	var top = center + Vector2(0, -tile_height / 2)
	var right = center + Vector2(tile_width / 2, 0)
	var bottom = center + Vector2(0, tile_height / 2)
	var left = center + Vector2(-tile_width / 2, 0)
	
	# Draw the diamond shape
	draw_line(top, right, grid_color)
	draw_line(right, bottom, grid_color)
	draw_line(bottom, left, grid_color)
	draw_line(left, top, grid_color)

# New method to draw chess notation labels around the grid
func draw_chess_labels():
	var font = ThemeDB.fallback_font
	var font_size = 12
	var label_offset = 15 # Distance from grid edge to labels
	
	# Draw column labels (A-H) at the top
	for x in range(grid_size_x):
		var chess_col = char(65 + x) # A, B, C, etc.
		var pos = grid_to_screen(Vector2(x, -0.5)) # Position above the grid
		draw_string(font, pos + Vector2(0, -label_offset), chess_col,
				   HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	
	# Draw row labels (1-8) on the left
	for y in range(grid_size_y):
		var chess_row = grid_size_y - y # 8, 7, 6, etc.
		var pos = grid_to_screen(Vector2(-0.5, y)) # Position left of the grid
		draw_string(font, pos + Vector2(-label_offset, 0), str(chess_row),
				   HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)

func _input(event):
	if Engine.is_editor_hint():
		return
		
	if event is InputEventMouseMotion:
		var mouse_pos = get_local_mouse_position()
		var grid_pos = screen_to_grid(mouse_pos)
		
		if is_valid_grid_position(grid_pos):
			if grid_pos != hover_grid_pos:
				hover_grid_pos = grid_pos
				emit_signal("grid_mouse_hover", grid_pos)
		else:
			if hover_grid_pos != Vector2(-1, -1):
				hover_grid_pos = Vector2(-1, -1)
				emit_signal("grid_mouse_exit")
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_local_mouse_position()
		var grid_pos = screen_to_grid(mouse_pos)
		
		if is_valid_grid_position(grid_pos):
			emit_signal("grid_tile_clicked", grid_pos)
			
			# Debug info in editor
			if Engine.is_editor_hint():
				print("Grid tile clicked: ", grid_pos)

# Convert grid coordinates to screen position
func grid_to_screen(grid_pos: Vector2) -> Vector2:
	var screen_x = (grid_pos.x - grid_pos.y) * tile_width / 2
	var screen_y = (grid_pos.x + grid_pos.y) * tile_height / 2
	return Vector2(screen_x, screen_y)

# Convert screen position to grid coordinates
func screen_to_grid(screen_pos: Vector2) -> Vector2:
	var grid_x = (screen_pos.x / (tile_width / 2) + screen_pos.y / (tile_height / 2)) / 2
	var grid_y = (screen_pos.y / (tile_height / 2) - screen_pos.x / (tile_width / 2)) / 2
	return Vector2(round(grid_x), round(grid_y))

# Check if a grid position is valid
func is_valid_grid_position(grid_pos: Vector2) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < grid_size_x and grid_pos.y >= 0 and grid_pos.y < grid_size_y

# Register an object on the grid
func add_grid_object(object, grid_pos: Vector2) -> bool:
	if is_valid_grid_position(grid_pos):
		grid_objects[grid_pos] = object
		return true
	return false

# Get object at grid position
func get_grid_object(grid_pos: Vector2):
	return grid_objects.get(grid_pos)

# Remove object from grid
func remove_grid_object(grid_pos: Vector2) -> void:
	grid_objects.erase(grid_pos)

func center_grid_in_viewport():
	# Calculate center tile of the grid
	var center_tile = Vector2(grid_size_x / 2.0, grid_size_y / 2.0)
	
	# Get the center of the viewport
	var viewport_center = get_viewport_rect().size / 2
	
	# Convert center tile to screen coordinates
	var center_tile_screen_pos = grid_to_screen(center_tile)
	
	# Calculate offset to move the center tile to viewport center
	var offset = viewport_center - center_tile_screen_pos
	
	# Apply the offset
	position = offset

# func _on_grid_tile_clicked(grid_pos: Vector2):
# 	# Grid manager handles the logic of what happens when a tile is clicked
# 	# For example, checking if the player can move there
