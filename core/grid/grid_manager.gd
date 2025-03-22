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
@export var enable_grid_glow: bool = false:
	set(value):
		enable_grid_glow = value
		queue_redraw()
@export var grid_glow_color: Color = Color(0.5, 0.5, 0.5, 0.5):
	set(value):
		grid_glow_color = value
		queue_redraw()
@export var grid_glow_width: float = 3.0:
	set(value):
		grid_glow_width = value
		queue_redraw()
@export var grid_glow_intensity: int = 3:
	set(value):
		grid_glow_intensity = max(1, value)
		queue_redraw()

@export_category("Grid Object Generation")
@export var poi_count: int = 3
@export var terrain_count: int = 12
@export var min_poi_distance: int = 3

@export_category("Player Settings")
@export var player_starting_tile: String = "A1":
	set(value):
		player_starting_tile = value
		# # Update player position if already spawned in editor
		# if Engine.is_editor_hint() and is_inside_tree():
		# 	update_player_in_editor()

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
var terrain_positions = [] # Track terrain positions

signal grid_mouse_hover(grid_pos)
signal grid_mouse_exit
signal grid_tile_clicked(grid_pos)
signal path_calculated(path)
signal poi_generated(positions)
signal grid_objects_generated(object_counts)

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
	
	# Initialize grid objects after a short delay to ensure everything is set up
	if not Engine.is_editor_hint():
		call_deferred("generate_grid_objects")

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
	
	# Add closed loop
	var closed_points = points + [points[0]]
	
	# Draw glow effect if enabled
	if enable_grid_glow:
		# Draw multiple lines with decreasing opacity and increasing width for glow effect
		for i in range(grid_glow_intensity, 0, -1):
			var scale_factor = float(i) / grid_glow_intensity
			var glow_width = grid_glow_width * scale_factor
			var glow_alpha = grid_glow_color.a * scale_factor
			var current_glow_color = Color(grid_glow_color.r, grid_glow_color.g, grid_glow_color.b, glow_alpha)
			
			draw_polyline(closed_points, current_glow_color, glow_width)
	
	# Draw the main outline
	draw_polyline(closed_points, grid_color, 1.0)

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

# Check if position is far enough from other positions based on min_distance
func is_position_valid(pos: Vector2, existing_positions: Array, min_distance: int = min_poi_distance) -> bool:
	for existing_pos in existing_positions:
		var distance = abs(existing_pos.x - pos.x) + abs(existing_pos.y - pos.y) # Manhattan distance
		if distance < min_distance:
			return false
	return true

# Create a grid object of the specified type at the given position
func create_grid_object(object_type: String, pos: Vector2):
	var instance = null
	match object_type:
		"poi":
			instance = load("res://core/objects/poi.gd").new()
			instance.randomize_properties()
		"terrain":
			instance = load("res://core/objects/terrain.gd").new()
			# No need to randomize terrain properties as it has a fixed style
	
	if instance:
		add_child(instance)
		instance.grid_position = pos
		instance.position = grid_to_screen(pos)
		register_grid_object(instance, pos)
		
		# Track position in type-specific arrays
		if object_type == "poi":
			poi_positions.append(pos)
		elif object_type == "terrain":
			terrain_positions.append(pos)
	
	return instance

# Player reference and management
var player_instance = null

# Create and add player to starting position
func add_player_to_grid() -> Node:
	# Convert chess notation to grid coordinates
	var start_pos = chess_to_grid(player_starting_tile)
	
	if not is_valid_grid_position(start_pos):
		push_error("Invalid player starting position: " + player_starting_tile)
		# Fallback to a valid position
		start_pos = Vector2(0, 0)
		player_starting_tile = grid_to_chess(start_pos)
	
	# Emit signal that starting tile is established
	if has_node("/root/SignalManager"):
		print("Emitting starting_tile_added signal with position: ", start_pos)
		var signal_manager = get_node("/root/SignalManager")
		signal_manager.emit_signal("starting_tile_added", start_pos)
	
	# Create player instance
	var player = load("res://core/objects/player.gd").new()
	add_child(player)
	
	# Set position and register
	player.grid_position = start_pos
	player.position = grid_to_screen(start_pos)
	
	# Register with the grid system
	register_grid_object(player, start_pos)
	
	# Store reference for easy access
	player_instance = player
	
	# Emit signal that player was added
	if has_node("/root/SignalManager"):
		var signal_manager = get_node("/root/SignalManager")
		signal_manager.emit_signal("player_spawned", player, start_pos)
	
	print("Player added at " + player_starting_tile + " (Grid: " + str(start_pos) + ")")
	return player

# Generate all grid objects (POIs and terrain)
func generate_grid_objects():
	print("Generating grid objects...")
	
	# Clear existing objects
	clear_existing_objects()

	# add player to grid
	add_player_to_grid()
	
	# Generate POIs first (higher priority)
	generate_objects_of_type("poi", poi_count)
	
	# Then generate terrain on remaining tiles
	generate_objects_of_type("terrain", terrain_count)
	
	# Emit signal for all generated objects
	if has_node("/root/SignalManager"):
		var signal_manager = get_node("/root/SignalManager")
		var object_counts = {
			"poi": poi_positions.size(),
			"terrain": terrain_positions.size()
		}
		signal_manager.emit_signal("grid_objects_generated", object_counts)
	else:
		push_warning("SignalManager not found. Grid objects generation signal not emitted.")
	
	print("Grid object generation complete. Created %d POIs and %d terrain objects" % [poi_positions.size(), terrain_positions.size()])

# Clear all existing generated objects
func clear_existing_objects():
	# Clear POIs
	for pos in poi_positions:
		var obj = get_grid_object_reference(pos)
		if obj and is_instance_valid(obj):
			obj.queue_free()
		remove_grid_object(pos)
	
	# Clear terrain
	for pos in terrain_positions:
		var obj = get_grid_object_reference(pos)
		if obj and is_instance_valid(obj):
			obj.queue_free()
		remove_grid_object(pos)
		
	poi_positions.clear()
	terrain_positions.clear()

# Generate objects of a specific type
func generate_objects_of_type(object_type: String, count: int):
	print("Generating %d objects of type %s" % [count, object_type])
	
	# Get already occupied positions
	var occupied_positions = []
	for pos in grid_objects.keys():
		occupied_positions.append(pos)
	
	var positions = []
	var max_attempts = grid_size_x * grid_size_y
	var attempts = 0
	
	# Apply minimum distance constraint only for POIs
	var min_distance = min_poi_distance if object_type == "poi" else 0
	
	while positions.size() < count and attempts < max_attempts:
		var x = randi() % grid_size_x
		var y = randi() % grid_size_y
		var pos = Vector2(x, y)
		
		# Skip if position is already occupied
		if occupied_positions.has(pos):
			attempts += 1
			continue
			
		# Check minimum distance requirement for POIs
		if object_type == "poi" and min_distance > 0:
			if not is_position_valid(pos, positions):
				attempts += 1
				continue
				
		# Create object at this position
		var instance = create_grid_object(object_type, pos)
		if instance:
			positions.append(pos)
			occupied_positions.append(pos)
			
		attempts += 1
	
	# Emit type-specific signal if needed
	if object_type == "poi" and has_node("/root/SignalManager"):
		var signal_manager = get_node("/root/SignalManager")
		signal_manager.emit_signal("poi_generated", positions)
		
	# Log a warning if we couldn't create all objects
	if positions.size() < count:
		push_warning("Could only create %d %s out of %d requested - try reducing constraints or increasing grid size."
			% [positions.size(), object_type, count])
		
	return positions

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

# The following functions are being kept for backward compatibility or future use
# with quadrant-based positioning

# Old functions that can be called by generate_grid_objects instead of the default random generation
func generate_pois():
	print("DEPRECATED: Use generate_grid_objects() instead")
	generate_grid_objects()

func generate_pois_random(count: int = 0):
	print("DEPRECATED: Use generate_objects_of_type('poi', count) instead")
	if count <= 0:
		count = poi_count
	generate_objects_of_type("poi", count)

# Create a POI at the given position - kept for backward compatibility
func create_poi_at_position(pos: Vector2):
	print("DEPRECATED: Use create_grid_object('poi', pos) instead")
	return create_grid_object("poi", pos)

func _on_object_visual_changed(object):
	# Re-register to update visuals when state changes
	register_grid_object(object, object.grid_position)
