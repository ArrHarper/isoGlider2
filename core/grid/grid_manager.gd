@tool
extends Node2D

# Add class_name reference to the top
const GridConfigurationClass = preload("res://core/grid/grid_configuration.gd")
const GridObjectRegistryClass = preload("res://core/grid/grid_object_registry.gd")
const GridCoordinateConverterClass = preload("res://core/grid/grid_coordinate_converter.gd")

# Add a cached reference to SignalManager at the top with other variables
var signal_manager = null

# Reference to the object registry and coordinate converter
var object_registry = null
var coord_converter = null

# Use a resource for configuration
@export var configuration: GridConfigurationClass:
	set(value):
		if value != configuration:
			# Disconnect from old configuration if it exists
			if configuration and configuration.is_connected("property_changed", Callable(self, "_on_config_property_changed")):
				configuration.disconnect("property_changed", Callable(self, "_on_config_property_changed"))
			
			# Set new configuration
			configuration = value
			
			# Connect to new configuration
			if configuration and not configuration.is_connected("property_changed", Callable(self, "_on_config_property_changed")):
				configuration.connect("property_changed", Callable(self, "_on_config_property_changed"))
			
			# Force property update notifications
			notify_property_list_changed()
			queue_redraw()

# These properties will now be derived from the configuration resource
var grid_size_x: int:
	get: return configuration.grid_size_x if configuration else 8
	set(value):
		if configuration:
			configuration.grid_size_x = value
			queue_redraw()
var grid_size_y: int:
	get: return configuration.grid_size_y if configuration else 8
	set(value):
		if configuration:
			configuration.grid_size_y = value
			queue_redraw()
var tile_width: int:
	get: return configuration.tile_width if configuration else 64
	set(value):
		if configuration:
			configuration.tile_width = value
			queue_redraw()
var tile_height: int:
	get: return configuration.tile_height if configuration else 32
	set(value):
		if configuration:
			configuration.tile_height = value
			queue_redraw()
var show_grid_lines: bool:
	get: return configuration.show_grid_lines if configuration else true
	set(value):
		if configuration:
			configuration.show_grid_lines = value
			queue_redraw()
var grid_color: Color:
	get: return configuration.grid_color if configuration else Color(0.5, 0.5, 0.5, 0.5)
	set(value):
		if configuration:
			configuration.grid_color = value
			queue_redraw()
var show_tile_coordinates: bool:
	get: return configuration.show_tile_coordinates if configuration else false
	set(value):
		if configuration:
			configuration.show_tile_coordinates = value
			queue_redraw()
var highlight_origin: bool:
	get: return configuration.highlight_origin if configuration else true
	set(value):
		if configuration:
			configuration.highlight_origin = value
			queue_redraw()
var show_chess_coordinates: bool:
	get: return configuration.show_chess_coordinates if configuration else true
	set(value):
		if configuration:
			configuration.show_chess_coordinates = value
			queue_redraw()
var show_chess_labels: bool:
	get: return configuration.show_chess_labels if configuration else true
	set(value):
		if configuration:
			configuration.show_chess_labels = value
			queue_redraw()
var enable_grid_glow: bool:
	get: return configuration.enable_grid_glow if configuration else false
	set(value):
		if configuration:
			configuration.enable_grid_glow = value
			queue_redraw()
var grid_glow_color: Color:
	get: return configuration.grid_glow_color if configuration else Color(0.5, 0.5, 0.5, 0.5)
	set(value):
		if configuration:
			configuration.grid_glow_color = value
			queue_redraw()
var grid_glow_width: float:
	get: return configuration.grid_glow_width if configuration else 3.0
	set(value):
		if configuration:
			configuration.grid_glow_width = value
			queue_redraw()
var grid_glow_intensity: int:
	get: return configuration.grid_glow_intensity if configuration else 3
	set(value):
		if configuration:
			configuration.grid_glow_intensity = value
			queue_redraw()
var poi_count: int:
	get: return configuration.poi_count if configuration else 3
	set(value):
		if configuration:
			configuration.poi_count = value
var terrain_count: int:
	get: return configuration.terrain_count if configuration else 12
	set(value):
		if configuration:
			configuration.terrain_count = value
var min_poi_distance: int:
	get: return configuration.min_poi_distance if configuration else 3
	set(value):
		if configuration:
			configuration.min_poi_distance = value
var player_starting_tile: String:
	get: return configuration.player_starting_tile if configuration else "A1"
	set(value):
		if configuration:
			configuration.player_starting_tile = value

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

signal grid_mouse_hover(grid_pos)
signal grid_mouse_exit
signal grid_tile_clicked(grid_pos)
signal path_calculated(path)
signal poi_generated(positions)
signal grid_objects_generated(object_counts)
signal starting_tile_added(grid_pos)
signal player_spawned(player, grid_pos)
signal grid_object_added(type, grid_pos)
signal grid_object_removed(type, grid_pos)

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
	
	# Initialize configuration for editor and runtime
	ensure_configuration()
	
	# Initialize object registry and coordinate converter
	initialize_object_registry()
	initialize_coordinate_converter()
	
	# Initialize signal manager reference (only in runtime)
	if not Engine.is_editor_hint():
		signal_manager = get_node_or_null("/root/SignalManager")
	
	# Find visualizer in both editor and runtime
	grid_visualizer = get_node_or_null("GridVisualizer")
	if not grid_visualizer and not Engine.is_editor_hint():
		push_error("GridVisualizer must be a child of GridManager")
	
	# Only proceed with runtime-specific setup if not in editor
	if not Engine.is_editor_hint():
		center_grid_in_viewport()
		# Initialize grid objects after a short delay to ensure everything is set up
		call_deferred("generate_grid_objects")

# Initialize the object registry
func initialize_object_registry():
	# Create the registry instance
	object_registry = GridObjectRegistryClass.new(self)
	add_child(object_registry)
	
	# Connect signals from registry
	object_registry.connect("poi_generated", Callable(self, "_on_poi_generated"))
	object_registry.connect("grid_objects_generated", Callable(self, "_on_grid_objects_generated"))
	
	# Initialize the registry
	object_registry.initialize()

# Initialize the coordinate converter
func initialize_coordinate_converter():
	# Create the converter instance
	coord_converter = GridCoordinateConverterClass.new(self)

# Forward signal handlers
func _on_poi_generated(positions):
	emit_signal("poi_generated", positions)

func _on_grid_objects_generated(object_counts):
	emit_signal("grid_objects_generated", object_counts)

# Ensure configuration is set for both editor and runtime
func ensure_configuration():
	if not configuration:
		var config_resource = load("res://core/grid/default_grid_config.tres")
		if config_resource:
			configuration = config_resource
			print("Loaded default grid configuration")
		else:
			configuration = GridConfigurationClass.new()
			print("Created default grid configuration")
		
		# Connect to property changed signal
		if not configuration.is_connected("property_changed", Callable(self, "_on_config_property_changed")):
			configuration.connect("property_changed", Callable(self, "_on_config_property_changed"))
		
		queue_redraw()

# Respond to configuration property changes
func _on_config_property_changed():
	if Engine.is_editor_hint():
		print("Grid configuration property changed")
	queue_redraw()

# Call this occasionally to ensure editor UI remains responsive to property changes
func _process(_delta):
	if Engine.is_editor_hint():
		# Only rebuild properties when needed
		if not configuration:
			ensure_configuration()
		# No need to queue_redraw on every frame for performance reasons

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

# Register an object on the grid
func add_grid_object(object, grid_pos: Vector2, type: String = "", visual_props: Dictionary = {}, disable_fog: bool = false, emit_signal: bool = true) -> bool:
	if is_valid_grid_position(grid_pos):
		# If type wasn't provided, try to get it from the object
		if type.is_empty() and object.get("object_type"):
			type = object.object_type
		elif type.is_empty():
			type = "generic"
	
		# Create the GridObjectData instance
		var data = GridObjectData.new()
		data.object = object
		data.type = type
		
		# Handle visual properties if provided
		if not visual_props.is_empty():
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
		
		# Set fog properties
		data.disable_fog = disable_fog
		
		# Store in grid
		grid_objects[grid_pos] = data
		
		# Update visuals if visualizer is available
		if grid_visualizer:
			grid_visualizer.update_grid_position(grid_pos)
		
		# Emit signal if requested
		if emit_signal:
			emit_signal("grid_object_added", type, grid_pos)
		
		return true
	
	return false

# Get object at grid position
func get_grid_object(grid_pos: Vector2, return_object_only: bool = false) -> Variant:
	var data = grid_objects.get(grid_pos)
	return (data.object if data else null) if return_object_only else data

# Helper function to safely call method or return fallback
func safe_call_method(object, method_name: String, fallback = null):
	if object and object.has_method(method_name):
		return object.call(method_name)
	return fallback

# Get visual properties for an object at given position
func get_grid_object_visual_properties(grid_pos: Vector2) -> Dictionary:
	var data = grid_objects.get(grid_pos)
	if not data:
		return {}
	
	# Call data's get_visual_properties() method directly with callable check
	if data.has_method("get_visual_properties"):
		var properties = data.get_visual_properties()
		if properties:
			return properties
	
	# Call object's get_visual_properties() method directly with null-safe check
	if data.object and data.object.has_method("get_visual_properties"):
		var properties = data.object.get_visual_properties()
		if properties:
			return properties
	
	# Return stored visual properties or empty dictionary
	return data.get("visual_properties", {})

# Position and register an object on the grid
func place_grid_object(instance: Node, grid_pos: Vector2) -> bool:
	if not instance:
		return false
		
	# Set position properties
	instance.grid_position = grid_pos
	instance.position = grid_to_screen(grid_pos)
	
	# Register with grid system
	return add_grid_object(instance, grid_pos)

# Remove object from grid
func remove_grid_object(grid_pos: Vector2, emit_signal: bool = true) -> void:
	if grid_objects.has(grid_pos):
		# Store object type for signal if needed
		var object_type = ""
		if emit_signal:
			object_type = grid_objects[grid_pos].type
		
		# Remove from grid tracking
		grid_objects.erase(grid_pos)
		
		# Update visuals if visualizer is available
		if grid_visualizer:
			grid_visualizer.update_grid_position(grid_pos)
		
		# Emit signal if requested
		if emit_signal:
			emit_signal("grid_object_removed", object_type, grid_pos)

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

# Checks if position is far enough from other positions (delegated to the registry)
func is_position_valid(pos: Vector2, existing_positions: Array, min_distance: int = min_poi_distance) -> bool:
	return object_registry.is_position_valid(pos, existing_positions, min_distance)

# Player reference and management
var player_instance = null

# Create and add player to starting position
func add_player_to_grid() -> Node:
	# Use our new chained method to get valid grid position from chess notation
	var start_pos = get_valid_grid_position(player_starting_tile)
	
	if start_pos == Vector2(-1, -1):
		push_error("Invalid player starting position: " + player_starting_tile)
		# Fallback to a valid position
		start_pos = Vector2(0, 0)
		player_starting_tile = grid_to_chess(start_pos)
	
	# Emit signal that starting tile is established
	print("Emitting starting_tile_added signal with position: ", start_pos)
	emit_signal("starting_tile_added", start_pos)
	
	# Create player instance
	var player = load("res://core/objects/player.gd").new()
	add_child(player)
	
	# Set position and register
	player.grid_position = start_pos
	player.position = grid_to_screen(start_pos)
	
	# Register with the grid system
	add_grid_object(player, start_pos)
	
	# Store reference for easy access
	player_instance = player
	
	# Emit signal that player was added
	emit_signal("player_spawned", player, start_pos)
	
	print("Player added at " + player_starting_tile + " (Grid: " + str(start_pos) + ")")
	return player

# Main coordinator function for generating grid objects (delegated to registry)
func generate_grid_objects():
	object_registry.generate_grid_objects()

# Helper to check if property exists
func has_property(property_name: String) -> bool:
	return get(property_name) != null

# --------- Coordinate Conversion Methods (using Converter) ---------

# Convert grid coordinates to screen coordinates
func grid_to_screen(grid_pos) -> Vector2:
	return coord_converter.grid_to_screen(grid_pos)

# Convert grid coordinates to screen with explicit x, y parameters
func grid_to_screen_xy(x: float, y: float) -> Vector2:
	return coord_converter.grid_to_screen_xy(x, y)

# Convert screen position to grid coordinates
func screen_to_grid(screen_pos: Vector2) -> Vector2:
	return coord_converter.screen_to_grid(screen_pos)

# Convert grid coordinates to chess notation
func grid_to_chess(grid_pos: Vector2) -> String:
	return coord_converter.grid_to_chess(grid_pos)

# Convert chess notation to grid coordinates
func chess_to_grid(chess_pos: String) -> Vector2:
	return coord_converter.chess_to_grid(chess_pos)

# Check if a grid position is valid
func is_valid_grid_position(grid_pos: Vector2) -> bool:
	return coord_converter.is_valid_grid_position(grid_pos)

# Convert grid position to chess notation if valid
func get_valid_chess_notation(grid_pos: Vector2) -> String:
	return coord_converter.get_valid_chess_notation(grid_pos)

# Convert chess notation to grid position if valid
func get_valid_grid_position(chess_pos: String) -> Vector2:
	return coord_converter.get_valid_grid_position(chess_pos)

# Convert screen coordinates directly to chess notation
func screen_to_chess(screen_pos: Vector2) -> String:
	return coord_converter.screen_to_chess(screen_pos)

func _on_object_visual_changed(object):
	# Re-register to update visuals when state changes
	add_grid_object(object, object.grid_position)
