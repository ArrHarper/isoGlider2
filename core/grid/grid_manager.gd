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

@export_category("POI Generation")
@export var poi_count: int = 3
@export var min_poi_distance: int = 3

var grid_tiles = [] # Array of tiles in the grid, stored as a 2D array of Vector2 positions
var hover_grid_pos = Vector2(-1, -1) # Track which tile is being hovered
var hover_chess_pos = "" # Track which tile is being hovered in chess notation
var target_grid_pos = Vector2(-1, -1) # Track the clicked target tile
var target_chess_pos = "" # Track the clicked target tile in chess notation
var path_tiles = [] # Array of tiles in the calculated path of the player
var player_is_moving = false # Track if the player is currently moving
var movement_state = null # Reference to movement state machine
var impassable_tiles = [] # Array of Vector2 positions that cannot be moved to
var grid_to_chess_friendly = true # Flag to determine if grid coordinates should be converted to chess notation
var grid_visualizer: Node2D
var poi_positions = [] # Track POI positions

signal grid_mouse_hover(grid_pos)
signal grid_mouse_exit
signal grid_tile_clicked(grid_pos)
signal path_calculated(path)
signal poi_generated(positions)

class GridObjectData:
	var object
	var type: String
	var visual_properties: Dictionary
	var disable_fog: bool
	
	func get_visual_properties() -> Dictionary:
		# First check if the object has its own visual properties
		if object and object.has_method("get_visual_properties"):
			return object.get_visual_properties()
		
		# Otherwise return stored visual properties
		return visual_properties

var grid_objects = {} # Dictionary keyed by grid position storing GridObjectData objects

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
	
	# Initialize POIs after a short delay to ensure everything is set up
	if not Engine.is_editor_hint():
		call_deferred("generate_pois")

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
				var chess_pos = grid_to_chess(Vector2(x, y))
				draw_string(ThemeDB.fallback_font, center + Vector2(0, 5), chess_pos, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)

# Draw chess notation labels around the grid
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

# Convert grid coordinates to screen coordinates for isometric rendering
func grid_to_screen(grid_pos) -> Vector2:
	if typeof(grid_pos) == TYPE_VECTOR2:
		var screen_x = (grid_pos.x - grid_pos.y) * (tile_width / 2.0)
		var screen_y = (grid_pos.x + grid_pos.y) * (tile_height / 2.0)
		return Vector2(screen_x, screen_y)
	else:
		# If not a Vector2, assume it's just the x coordinate and y is 0
		var x = float(grid_pos)
		var screen_x = x * (tile_width / 2.0)
		var screen_y = x * (tile_height / 2.0)
		return Vector2(screen_x, screen_y)

# Alternative version with explicit x, y parameters
func grid_to_screen_xy(x: float, y: float) -> Vector2:
	var screen_x = (x - y) * (tile_width / 2.0)
	var screen_y = (x + y) * (tile_height / 2.0)
	return Vector2(screen_x, screen_y)

# Draw a single isometric tile
func draw_isometric_tile(grid_pos: Vector2):
	var center = grid_to_screen(grid_pos)
	
	# Create diamond shape points
	var points = []
	points.append(Vector2(center.x, center.y - tile_height / 2)) # Top
	points.append(Vector2(center.x + tile_width / 2, center.y)) # Right
	points.append(Vector2(center.x, center.y + tile_height / 2)) # Bottom
	points.append(Vector2(center.x - tile_width / 2, center.y)) # Left
	
	# Draw the outline
	draw_polyline(points + [points[0]], grid_color, 1.0)

func _input(event):
	if Engine.is_editor_hint():
		return
		
	if event is InputEventMouseMotion:
		var mouse_pos = get_local_mouse_position()
		var grid_pos = screen_to_grid(mouse_pos)
		
		if is_valid_grid_position(grid_pos):
			if grid_pos != hover_grid_pos:
				hover_grid_pos = grid_pos
				hover_chess_pos = grid_to_chess(grid_pos)
				emit_signal("grid_mouse_hover", grid_pos)
		else:
			if hover_grid_pos != Vector2(-1, -1):
				hover_grid_pos = Vector2(-1, -1)
				hover_chess_pos = ""
				emit_signal("grid_mouse_exit")
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_local_mouse_position()
		var grid_pos = screen_to_grid(mouse_pos)
		
		if is_valid_grid_position(grid_pos):
			target_grid_pos = grid_pos
			target_chess_pos = grid_to_chess(grid_pos)
			emit_signal("grid_tile_clicked", grid_pos)
			
			# Print debug info in both editor and runtime
			print("Grid tile clicked: ", grid_pos, " ", target_chess_pos)

# Convert screen position to grid coordinates
func screen_to_grid(screen_pos: Vector2) -> Vector2:
	var grid_x = (screen_pos.x / (tile_width / 2) + screen_pos.y / (tile_height / 2)) / 2
	var grid_y = (screen_pos.y / (tile_height / 2) - screen_pos.x / (tile_width / 2)) / 2
	return Vector2(round(grid_x), round(grid_y))

# Convert grid coordinates to chess notation (A1, B2, etc.)
func grid_to_chess(grid_pos: Vector2) -> String:
	if not is_valid_grid_position(grid_pos):
		return ""
	
	var chess_col = char(65 + int(grid_pos.x)) # A, B, C, etc.
	var chess_row = grid_size_y - int(grid_pos.y) # 8, 7, 6, etc. (chess has row 1 at bottom)
	return "%s%d" % [chess_col, chess_row]

# Convert chess notation (A1, B2, etc.) to grid coordinates
func chess_to_grid(chess_pos: String) -> Vector2:
	if chess_pos.length() < 2:
		return Vector2(-1, -1)
	
	var col = chess_pos[0].to_upper().unicode_at(0) - 65 # A=0, B=1, etc.
	var row = int(chess_pos.substr(1))
	
	var grid_x = col
	var grid_y = grid_size_y - row
	
	if is_valid_grid_position(Vector2(grid_x, grid_y)):
		return Vector2(grid_x, grid_y)
	else:
		return Vector2(-1, -1)

# Check if a grid position is valid
func is_valid_grid_position(grid_pos: Vector2) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < grid_size_x and grid_pos.y >= 0 and grid_pos.y < grid_size_y

# Register an object on the grid
func add_grid_object(object, grid_pos: Vector2, type: String = "", visual_props: Dictionary = {}, disable_fog: bool = false) -> bool:
	if is_valid_grid_position(grid_pos):
		var data = GridObjectData.new()
		data.object = object
		data.type = type
		
		# Ensure visual properties have defaults for expected fields
		var default_props = {
			"highlight_color": Color.TRANSPARENT,
			"highlight_border_color": Color.TRANSPARENT,
			"sprite_texture": null,
			"sprite_modulate": Color.WHITE
		}
		
		# Merge provided properties with defaults
		for key in default_props:
			if not visual_props.has(key):
				visual_props[key] = default_props[key]
		
		data.visual_properties = visual_props
		data.disable_fog = disable_fog
		grid_objects[grid_pos] = data
		if grid_visualizer:
			grid_visualizer.update_grid_position(grid_pos)
		return true
	return false

# Get object at grid position
func get_grid_object(grid_pos: Vector2):
	# Return the GridObjectData object
	return grid_objects.get(grid_pos)

# Get the actual object reference at a grid position
func get_grid_object_reference(grid_pos: Vector2):
	var data = grid_objects.get(grid_pos)
	return data.object if data else null

# Get visual properties for an object at given position
func get_grid_object_visual_properties(grid_pos: Vector2) -> Dictionary:
	var data = grid_objects.get(grid_pos)
	if not data:
		return {}
		
	# If GridObjectData has visual properties, use those methods
	if data.has_method("get_visual_properties"):
		return data.get_visual_properties()
	
	# Otherwise, try to get properties from the object itself
	if data.object and data.object.has_method("get_visual_properties"):
		return data.object.get_visual_properties()
	
	# Fallback to returning the stored visual_properties dictionary
	if data.get("visual_properties"):
		return data.visual_properties
		
	return {}

# Remove object from grid
func remove_grid_object(grid_pos: Vector2) -> void:
	grid_objects.erase(grid_pos)
	
	if grid_visualizer:
		grid_visualizer.update_grid_position(grid_pos)

# Get grid object data directly (alias for get_grid_object for clarity)
func get_grid_object_data(grid_pos: Vector2) -> GridObjectData:
	return grid_objects.get(grid_pos)

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

# Get player's quadrant (0=top-left, 1=top-right, 2=bottom-left, 3=bottom-right)
func get_quadrant(grid_pos: Vector2) -> int:
	var half_size_x = int(grid_size_x / 2)
	var half_size_y = int(grid_size_y / 2)
	
	# Ensure grid_pos components are integers
	var x = int(grid_pos.x)
	var y = int(grid_pos.y)
	
	# Handle edge cases - always move towards the center of a quadrant rather than randomly
	if x == half_size_x: # On vertical middle line
		# Check if we're in upper or lower half to decide which side to move to
		if y < half_size_y:
			x = x - 1 # Move to left quadrant (0 or 2)
		else:
			x = x + 1 # Move to right quadrant (1 or 3)
		
	if y == half_size_y: # On horizontal middle line
		# Check if we're in left or right half to decide which side to move to
		if x < half_size_x:
			y = y - 1 # Move to top quadrant (0 or 1)
		else:
			y = y + 1 # Move to bottom quadrant (2 or 3)
	
	# Now determine the quadrant
	if x < half_size_x:
		if y < half_size_y:
			return 0 # Top-left
		else:
			return 2 # Bottom-left
	else:
		if y < half_size_y:
			return 1 # Top-right
		else:
			return 3 # Bottom-right

# Get random position within a specific quadrant
func get_random_position_in_quadrant(quadrant: int) -> Vector2:
	var half_size_x = int(grid_size_x / 2)
	var half_size_y = int(grid_size_y / 2)
	var x_start = 0
	var y_start = 0
	var x_end = half_size_x - 1 # Avoid boundary
	var y_end = half_size_y - 1 # Avoid boundary
	
	match quadrant:
		0: # Top-left
			x_start = 0
			y_start = 0
		1: # Top-right
			x_start = half_size_x + 1 # Ensure we're clearly in the right quadrant
			y_start = 0
			x_end = grid_size_x - 1
		2: # Bottom-left
			x_start = 0
			y_start = half_size_y + 1 # Ensure we're clearly in the bottom quadrant
			y_end = grid_size_y - 1
		3: # Bottom-right
			x_start = half_size_x + 1 # Ensure we're clearly in the right quadrant
			y_start = half_size_y + 1 # Ensure we're clearly in the bottom quadrant
			x_end = grid_size_x - 1
			y_end = grid_size_y - 1
	
	var x = x_start + randi() % (x_end - x_start + 1)
	var y = y_start + randi() % (y_end - y_start + 1)
	
	return Vector2(x, y)

# Check if position is far enough from other POIs
func is_position_valid(pos: Vector2, existing_positions: Array) -> bool:
	for existing_pos in existing_positions:
		var distance = abs(existing_pos.x - pos.x) + abs(existing_pos.y - pos.y) # Manhattan distance
		if distance < min_poi_distance:
			return false
	return true

# Generate POIs and place them on the grid
func generate_pois():
	print("Generating POIs...")
	
	# Clear existing POIs
	for pos in poi_positions:
		var poi_obj = get_grid_object_reference(pos)
		if poi_obj and is_instance_valid(poi_obj):
			poi_obj.queue_free()
		remove_grid_object(pos)
	poi_positions.clear()
	
	# Find player position if there is one
	var player_pos = Vector2(-1, -1)
	var player_quadrant = -1
	
	for pos in grid_objects.keys():
		var obj_data = grid_objects[pos]
		if obj_data and obj_data.type == "player":
			player_pos = pos
			player_quadrant = get_quadrant(player_pos)
			break
	
	# If no player found, use a random distribution approach
	if player_pos == Vector2(-1, -1):
		return generate_pois_random()
	
	# Get available quadrants (all except player's)
	var available_quadrants = [0, 1, 2, 3]
	if player_quadrant >= 0:
		available_quadrants.erase(player_quadrant)
	
	# Assign POIs to different quadrants
	for i in range(min(poi_count, available_quadrants.size())):
		var quadrant = available_quadrants[i]
		var max_attempts = 20 # Prevent infinite loops
		var attempts = 0
		var position = null
		
		# Try to find valid position in this quadrant
		while attempts < max_attempts:
			position = get_random_position_in_quadrant(quadrant)
			# Double-check the position is in the expected quadrant
			var actual_quadrant = get_quadrant(position)
			if actual_quadrant != quadrant:
				attempts += 1
				continue
				
			if is_position_valid(position, poi_positions) and position != player_pos:
				break
			attempts += 1
		
		if attempts == max_attempts:
			print("Warning: Could not find valid position in quadrant ", quadrant)
			continue
		
		# Create and add POI to this position
		create_poi_at_position(position)
	
	# If we didn't generate enough POIs from quadrants, fill in with random positions
	if poi_positions.size() < poi_count:
		var remaining = poi_count - poi_positions.size()
		print("Adding ", remaining, " additional random POIs")
		generate_pois_random(remaining)
	
	print("POI generation complete. Created ", poi_positions.size(), " POIs")
	emit_signal("poi_generated", poi_positions)

# Generate POIs with a simple random distribution
func generate_pois_random(count: int = 0):
	if count <= 0:
		count = poi_count
		
	print("Generating ", count, " random POIs")
	
	# Target number of POIs to generate
	var target_count = min(count, grid_size_x * grid_size_y - poi_positions.size())
	var max_attempts = target_count * 10 # Limit attempts to avoid infinite loops
	var attempts = 0
	
	# Generate more POIs until we reach the target count
	while poi_positions.size() < target_count and attempts < max_attempts:
		var x = randi() % grid_size_x
		var y = randi() % grid_size_y
		var pos = Vector2(x, y)
		
		# Skip if there's already an object at this position
		if grid_objects.has(pos):
			attempts += 1
			continue
			
		# Check minimum distance requirement
		if is_position_valid(pos, poi_positions):
			create_poi_at_position(pos)
		
		attempts += 1
	
	print("Random POI generation complete. Created ", poi_positions.size(), " POIs")
	emit_signal("poi_generated", poi_positions)

# Create a POI at the given position
func create_poi_at_position(pos: Vector2):
	# Create POI instance using the factory method
	var poi_instance = load("res://core/objects/poi.gd").new()
	poi_instance.randomize_properties() # Call a method to randomize instead of static factory
	
	# Add to scene
	add_child(poi_instance)
	
	# Make sure it's properly owned
	if get_tree() and get_tree().edited_scene_root:
		poi_instance.owner = get_tree().edited_scene_root
	
	# Set grid position and register
	poi_instance.setup(self, pos)
	
	# Add to our tracking
	poi_positions.append(pos)
	
	return poi_instance

# Register a grid object with the grid
func register_grid_object(object, grid_pos: Vector2) -> bool:
	if is_valid_grid_position(grid_pos):
		# Get the object type
		var type = "generic"
		if object.get("object_type"):
			type = object.object_type
		
		# Add to grid_objects dictionary without visual properties
		var data = GridObjectData.new()
		data.object = object
		data.type = type
		grid_objects[grid_pos] = data
		
		# Use the global SignalManager to emit the signal
		if has_node("/root/SignalManager"):
			var signal_manager = get_node("/root/SignalManager")
			signal_manager.emit_signal("grid_object_added", type, grid_pos)
		
		return true
	
	return false

func unregister_grid_object(grid_pos: Vector2) -> void:
	if grid_objects.has(grid_pos):
		var object_type = grid_objects[grid_pos].type
		grid_objects.erase(grid_pos)
		
		# Use the global SignalManager to emit the signal
		if has_node("/root/SignalManager"):
			var signal_manager = get_node("/root/SignalManager")
			signal_manager.emit_signal("grid_object_removed", object_type, grid_pos)
