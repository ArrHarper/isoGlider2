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
		# Connect grid signals to their handlers
		if not is_connected("grid_mouse_hover", Callable(self, "_on_grid_mouse_hover")):
			connect("grid_mouse_hover", Callable(self, "_on_grid_mouse_hover"))
		if not is_connected("grid_mouse_exit", Callable(self, "_on_grid_mouse_exit")):
			connect("grid_mouse_exit", Callable(self, "_on_grid_mouse_exit"))
		if not is_connected("grid_tile_clicked", Callable(self, "_on_grid_tile_clicked")):
			connect("grid_tile_clicked", Callable(self, "_on_grid_tile_clicked"))
		
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
		var chess_row = y + 1 # 1, 2, 3, etc. (matching grid y-coordinate)
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
				
				print("Mouse hovering over grid position: ", grid_pos, " (", hover_chess_pos, ")")
				emit_signal("grid_mouse_hover", grid_pos)
		else:
			if hover_grid_pos != Vector2(-1, -1):
				hover_grid_pos = Vector2(-1, -1)
				hover_chess_pos = ""
				
				print("Mouse exited grid")
				emit_signal("grid_mouse_exit")
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_local_mouse_position()
		var grid_pos = screen_to_grid(mouse_pos)
		
		if is_valid_grid_position(grid_pos):
			target_grid_pos = grid_pos
			target_chess_pos = grid_to_chess(grid_pos)
			
			print("Left mouse button clicked at grid position: ", grid_pos, " (", target_chess_pos, ")")
			
			# Check if player is moving
			if player_is_moving:
				print("Ignoring click because player is currently moving")
				return
				
			emit_signal("grid_tile_clicked", grid_pos)
			
			# Print debug info in both editor and runtime
			print("Grid tile clicked signal emitted for: ", grid_pos, " ", target_chess_pos)

# Register an object on the grid
func add_grid_object(object, grid_pos: Vector2, type: String = "", visual_props: Dictionary = {}, disable_fog: bool = false, emit_signal: bool = true) -> bool:
	if is_valid_grid_position(grid_pos):
		# Check if there's already an object at this position and log it
		if grid_objects.has(grid_pos):
			print("Warning: Replacing existing object at position ", grid_pos,
				" of type ", grid_objects[grid_pos].type, " with new object of type ",
				(type if not type.is_empty() else (object.get("object_type") if object else "unknown")))
		
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
		
		# Debug output
		print("Removing grid object at position ", grid_pos, " of type ", object_type)
		
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
	# First, clean up any existing player instance to prevent duplicates
	if player_instance and is_instance_valid(player_instance):
		print("Removing existing player instance")
		# Find current grid position of player
		var old_pos = player_instance.grid_position
		# Remove from grid tracking
		if grid_objects.has(old_pos):
			grid_objects.erase(old_pos)
			# Update grid visualizer for the old position
			if grid_visualizer:
				grid_visualizer.update_grid_position(old_pos)
		# Free the instance
		player_instance.queue_free()
		player_instance = null
	
	# Use our new chained method to get valid grid position from chess notation
	var start_pos = get_valid_grid_position(player_starting_tile)
	
	if start_pos == Vector2(-1, -1):
		push_error("Invalid player starting position: " + player_starting_tile)
		# Fallback to a valid position
		start_pos = Vector2(0, 0)
		player_starting_tile = grid_to_chess(start_pos)
	
	# Make sure grid_visualizer is properly set up before emitting the signal
	if grid_visualizer == null:
		print("WARNING: GridVisualizer not found when adding player, attempting to find it...")
		grid_visualizer = get_node_or_null("GridVisualizer")
		if grid_visualizer:
			print("GridVisualizer found!")
		else:
			print("ERROR: GridVisualizer still not found!")
	
	# Try both ways to set the starting tile - emit signal and direct call
	print("GridManager: Emitting starting_tile_added signal with position: ", start_pos)
	emit_signal("starting_tile_added", start_pos)
	
	# Direct call for reliability 
	if grid_visualizer and grid_visualizer.has_method("force_set_starting_tile"):
		grid_visualizer.force_set_starting_tile(start_pos)
	
	# Double-check the starting tile highlight
	if grid_visualizer:
		call_deferred("_check_starting_tile_highlight", start_pos)
	
	# Instantiate player scene instead of creating a new class instance
	var player_scene = load("res://core/objects/player.tscn")
	var player = player_scene.instantiate()
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
	
	# Initialize the movement state machine
	initialize_movement_state_machine()
	
	# Connect movement signals
	connect_movement_signals()
	
	return player

# Helper function to check if the starting tile highlight is properly applied
func _check_starting_tile_highlight(start_pos: Vector2) -> void:
	# Wait a frame to ensure all deferred calls are processed
	await get_tree().process_frame
	
	print("GridManager: Checking if starting tile highlight was applied at: ", start_pos)
	
	if grid_visualizer and grid_visualizer.active_highlights.has(grid_visualizer.starting_tile_highlight_id):
		print("GridManager: Starting tile highlight is active!")
	else:
		print("GridManager: Starting tile highlight is NOT active, forcing it...")
		if grid_visualizer and grid_visualizer.has_method("force_set_starting_tile"):
			grid_visualizer.force_set_starting_tile(start_pos)
		else:
			print("GridManager: Can't force starting tile highlight - visualizer not found or missing method")

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

# --------- Player Movement State Machine ---------

# Reference to player movement state machine
var movement_state_machine = null

# Initialize the movement state machine
func initialize_movement_state_machine():
	if not movement_state_machine:
		movement_state_machine = load("res://core/player/player_movement_state_machine.gd").new(self)
		print("Movement state machine initialized")
	return movement_state_machine

# Get reference to movement state machine (creating if needed)
func get_movement_state_machine():
	if not movement_state_machine:
		initialize_movement_state_machine()
	return movement_state_machine

# --------- Path Finding and Visualization ---------

# Find a path that follows grid rules (only allows X/Y movement, not diagonal)
func find_gridlocked_path(start_pos: Vector2, end_pos: Vector2, max_distance: int) -> Array:
	# Ensure we're working with integer coordinates
	start_pos = Vector2(int(start_pos.x), int(start_pos.y))
	end_pos = Vector2(int(end_pos.x), int(end_pos.y))
	
	# If start and end are the same, return empty path
	if start_pos == end_pos:
		return []
	
	# Check if target tile is passable first
	if not is_tile_passable(end_pos):
		print("Target position is not passable: ", end_pos, " (", grid_to_chess(end_pos), ")")
		return []
		
	# Calculate Manhattan distance
	var manhattan_distance = abs(end_pos.x - start_pos.x) + abs(end_pos.y - start_pos.y)
	
	# Check if destination is beyond movement range
	if manhattan_distance > max_distance:
		print("Path exceeds max distance: ", manhattan_distance, " > ", max_distance)
		return []
	
	# Debug output
	var start_chess = grid_to_chess(start_pos)
	var end_chess = grid_to_chess(end_pos)
	print("Finding path from %s(%s) to %s(%s), max distance: %d" % [str(start_pos), start_chess, str(end_pos), end_chess, max_distance])
	
	# Simple path along X then Y
	var path = []
	var current = start_pos
	
	# First move along X axis
	while current.x != end_pos.x:
		var step = 1 if end_pos.x > current.x else -1
		current.x += step
		
		# Create the potential new position
		var next_pos = Vector2(current.x, current.y)
		
		# Check if position is valid (not blocked)
		if is_valid_grid_position(next_pos) and is_tile_passable(next_pos):
			path.append(next_pos)
			print("Added X step: %s (%s)" % [str(next_pos), grid_to_chess(next_pos)])
		else:
			# Try Y-first approach instead
			print("X-first approach blocked at %s (%s), trying Y-first" % [str(next_pos), grid_to_chess(next_pos)])
			path = []
			current = start_pos
			break
	
	# If X-first approach failed or wasn't completed, try Y-first
	if path.size() == 0 or current.y != end_pos.y:
		# If we already have a partial X path, continue with Y movement
		if path.size() > 0:
			# Continue Y movement from current X position
			while current.y != end_pos.y:
				var step = 1 if end_pos.y > current.y else -1
				current.y += step
				
				# Create the potential new position
				var next_pos = Vector2(current.x, current.y)
				
				# Check if position is valid (not blocked)
				if is_valid_grid_position(next_pos) and is_tile_passable(next_pos):
					path.append(next_pos)
					print("Added Y step (after X): %s (%s)" % [str(next_pos), grid_to_chess(next_pos)])
				else:
					# Path was valid until now but got blocked
					print("Y movement blocked at %s (%s) after X movement, path failed" % [str(next_pos), grid_to_chess(next_pos)])
					return []
		else:
			# Try Y-first approach from scratch
			current = start_pos
			
			# Move along Y axis first
			while current.y != end_pos.y:
				var step = 1 if end_pos.y > current.y else -1
				current.y += step
				
				# Create the potential new position
				var next_pos = Vector2(current.x, current.y)
				
				# Check if position is valid (not blocked)
				if is_valid_grid_position(next_pos) and is_tile_passable(next_pos):
					path.append(next_pos)
					print("Added Y step: %s (%s)" % [str(next_pos), grid_to_chess(next_pos)])
				else:
					# Both approaches failed, no valid path
					print("Y-first approach blocked at %s (%s), no valid path" % [str(next_pos), grid_to_chess(next_pos)])
					return []
			
			# Then move along X axis
			while current.x != end_pos.x:
				var step = 1 if end_pos.x > current.x else -1
				current.x += step
				
				# Create the potential new position
				var next_pos = Vector2(current.x, current.y)
				
				# Check if position is valid (not blocked)
				if is_valid_grid_position(next_pos) and is_tile_passable(next_pos):
					path.append(next_pos)
					print("Added X step (after Y): %s (%s)" % [str(next_pos), grid_to_chess(next_pos)])
				else:
					# No valid path
					print("X movement blocked at %s (%s) after Y movement, path failed" % [str(next_pos), grid_to_chess(next_pos)])
					return []
	
	# Ensure the path doesn't exceed max distance
	if path.size() > max_distance:
		print("Path found but exceeds max distance, trimming to %d steps" % max_distance)
		path = path.slice(0, max_distance)
	
	print("Final path: %s" % str(path))
	return path

# Check if a tile can be moved to
func is_tile_passable(grid_pos: Vector2) -> bool:
	# Get object at position
	var object_data = get_grid_object(grid_pos)
	
	# If no object, tile is passable
	if not object_data:
		return true
	
	# Check if object is in impassable_tiles list
	if impassable_tiles.has(grid_pos):
		return false
		
	# If it's a terrain object, check its passable property
	if object_data.type == "terrain" and object_data.object and object_data.object.has_method("get_is_passable"):
		return object_data.object.get_is_passable()
	
	# Default to passable for other objects (like POIs)
	return true

# Update path visualization on the grid
func update_path_visualization(path: Array) -> void:
	# Clear any existing path highlights
	clear_movement_range()
	
	# Skip if path is empty
	if path.size() == 0:
		return
	
	# Create highlights for valid path tiles
	for i in range(path.size()):
		var grid_pos = path[i]
		
		# Only highlight if the tile is passable
		if is_tile_passable(grid_pos):
			var highlight_id = "path_" + str(i)
			var highlight_color = Color(0.2, 0.7, 0.9, 0.4)
			
			# Highlight grid tile
			if grid_visualizer:
				grid_visualizer._add_highlight(grid_pos, highlight_color, Color.TRANSPARENT, highlight_id)
		else:
			print("Skipping highlighting impassable tile at: ", grid_pos)
	
	# Emit signal for path calculation
	emit_signal("path_calculated", path)

# Clear movement range visualization
func clear_movement_range() -> void:
	if grid_visualizer:
		for i in range(50): # Clear up to 50 path tiles (arbitrary limit)
			var highlight_id = "path_" + str(i)
			grid_visualizer._remove_highlight(highlight_id)

# Show target highlight for selected destination
func show_target_highlight(grid_pos: Vector2) -> void:
	if grid_visualizer:
		var highlight_id = "target_highlight"
		var highlight_color = Color(0.9, 0.2, 0.2, 0.6)
		grid_visualizer._add_highlight(grid_pos, highlight_color, Color.RED, highlight_id)

# Clear target highlight
func clear_target_highlight() -> void:
	if grid_visualizer:
		grid_visualizer._remove_highlight("target_highlight")

# Get grid position name (chess notation if enabled)
func get_grid_name(grid_pos: Vector2) -> String:
	if grid_to_chess_friendly:
		return get_valid_chess_notation(grid_pos)
	else:
		return str(grid_pos)

# Add these input handlers to connect with the movement state machine

# Handle grid_mouse_hover signal for player movement
func _on_grid_mouse_hover(grid_pos: Vector2):
	# Update grid manager hover tracking
	hover_grid_pos = grid_pos
	hover_chess_pos = grid_to_chess(grid_pos)
	
	print("GridManager: Processing grid_mouse_hover at ", grid_pos, " (", hover_chess_pos, ")")
	
	# If player is moving, don't process hover
	if player_is_moving:
		print("GridManager: Ignoring hover because player is currently moving")
		return
	
	# Get movement state machine
	var state_machine = get_movement_state_machine()
	if state_machine:
		# Get current state as string for debugging
		var current_state_str = state_machine._state_to_string(state_machine.current_state)
		
		# Transition to HOVER state if we're in IDLE or already in HOVER
		if state_machine.current_state == state_machine.MovementState.IDLE or \
		   state_machine.current_state == state_machine.MovementState.HOVER:
			if state_machine.current_state != state_machine.MovementState.HOVER:
				print("GridManager: Transitioning to HOVER state from ", current_state_str)
			var success = state_machine.transition_to(state_machine.MovementState.HOVER, {"hover_pos": grid_pos})
			if not success:
				print("GridManager: Failed to transition to HOVER state")
		else:
			print("GridManager: Not transitioning to HOVER state from current state: ", current_state_str)
	else:
		print("GridManager: Error - Movement state machine not found!")

# Handle grid_mouse_exit signal
func _on_grid_mouse_exit():
	# Clear hover tracking
	hover_grid_pos = Vector2(-1, -1)
	hover_chess_pos = ""
	
	# Get movement state machine
	var state_machine = get_movement_state_machine()
	if state_machine:
		# If we're in HOVER state, go back to IDLE
		if state_machine.current_state == state_machine.MovementState.HOVER:
			state_machine.transition_to(state_machine.MovementState.IDLE)

# Handle grid_tile_clicked signal
func _on_grid_tile_clicked(grid_pos: Vector2):
	# Update target tracking
	target_grid_pos = grid_pos
	target_chess_pos = grid_to_chess(grid_pos)
	
	print("GridManager: Processing grid_tile_clicked at ", grid_pos, " (", target_chess_pos, ")")
	
	# If player is moving, don't process click
	if player_is_moving:
		print("GridManager: Ignoring click because player is currently moving")
		return
	
	# Check if we have a player instance
	if not player_instance:
		print("GridManager: Error - Player instance not found!")
		return
	
	# Get movement state machine
	var state_machine = get_movement_state_machine()
	if state_machine:
		# Get current state as string for debugging
		var current_state_str = state_machine._state_to_string(state_machine.current_state)
		
		print("GridManager: Current movement state before click: ", current_state_str)
		
		# Only process click if we're in HOVER or IDLE state
		if state_machine.current_state == state_machine.MovementState.HOVER or \
		   state_machine.current_state == state_machine.MovementState.IDLE:
			print("GridManager: Transitioning to PATH_PLANNED state")
			var success = state_machine.transition_to(state_machine.MovementState.PATH_PLANNED, {"target_pos": grid_pos})
			print("GridManager: Transition success: ", success)
		else:
			print("GridManager: Cannot transition to PATH_PLANNED from current state: ", current_state_str)
	else:
		print("GridManager: Error - Movement state machine not found!")

# Set up signal connections for player movement
func connect_movement_signals():
	if player_instance:
		if not player_instance.is_connected("movement_completed", _on_player_movement_completed):
			player_instance.connect("movement_completed", _on_player_movement_completed)

# Handler for player movement completed
func _on_player_movement_completed():
	# Get movement state machine
	var state_machine = get_movement_state_machine()
	if state_machine:
		# Transition to MOVEMENT_COMPLETED state
		state_machine.transition_to(state_machine.MovementState.MOVEMENT_COMPLETED)

# Check if a target position is reachable within the movement range
func is_position_reachable(start_pos: Vector2, target_pos: Vector2, max_distance: int) -> bool:
	# Calculate Manhattan distance
	var manhattan_distance = abs(target_pos.x - start_pos.x) + abs(target_pos.y - start_pos.y)
	
	# Check if distance is within range
	if manhattan_distance > max_distance:
		var start_chess = grid_to_chess(start_pos)
		var target_chess = grid_to_chess(target_pos)
		print("Position %s (%s) is too far from %s (%s): %d > %d" %
			[str(target_pos), target_chess, str(start_pos), start_chess, manhattan_distance, max_distance])
		return false
	
	# Check if there's a valid path
	var path = find_gridlocked_path(start_pos, target_pos, max_distance)
	var has_path = path.size() > 0
	
	# Debug output
	if not has_path:
		var start_chess = grid_to_chess(start_pos)
		var target_chess = grid_to_chess(target_pos)
		print("No valid path from %s (%s) to %s (%s)" %
			[str(start_pos), start_chess, str(target_pos), target_chess])
	
	return has_path

# --------- Player State Control ---------

# Set the player to immobilized state
func set_player_immobilized(immobilized: bool = true) -> void:
	var state_machine = get_movement_state_machine()
	if state_machine and state_machine.has_method("set_immobile"):
		state_machine.set_immobile(immobilized)
		print("Player immobilized state set to: %s" % immobilized)
	else:
		print("Failed to set player immobilized state: State machine not found or missing method")

# Get the current player state
func get_player_state() -> String:
	if player_instance and player_instance.has_method("get_player_state"):
		return player_instance.get_player_state()
	
	# If player has a state property, return it
	if player_instance and player_instance.get("player_state"):
		return player_instance.player_state
	
	# Otherwise get it from the state machine
	var state_machine = get_movement_state_machine()
	if state_machine:
		return state_machine._state_to_string(state_machine.current_state)
	
	return "UNKNOWN"

# Check if player is on the starting tile
func is_player_on_starting_tile() -> bool:
	if player_instance and player_instance.has_method("check_if_on_starting_tile"):
		return player_instance.check_if_on_starting_tile()
	
	# Otherwise calculate manually
	if player_instance:
		var start_pos = get_valid_grid_position(player_starting_tile)
		return player_instance.grid_position == start_pos
	
	return false
