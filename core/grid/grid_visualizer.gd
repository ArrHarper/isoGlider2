@tool
extends Node2D

# Reference to the grid manager
var grid_manager: Node2D

# Starting tile position
var starting_tile_position: Vector2 = Vector2(-1, -1)

# Layer handling
var highlight_layer: Node2D
var object_layer: Node2D
var fog_layer: Node2D

# Highlight tracking
var active_highlights = {}
var hover_highlight_id = ""
var path_highlight_id = ""
var selection_highlight_id = ""

# Visual tracking
var object_sprites = {} # Dictionary keyed by grid position
var shape_polygons = {} # Dictionary to track shape polygons

# Visual configuration
@export_category("Visual Settings")
@export var default_highlight_color: Color = Color(0.5, 0.5, 0.5, 0.3)
@export var hover_highlight_color: Color = Color(0.7, 0.7, 0.7, 0.5)
@export var selection_highlight_color: Color = Color(0.2, 0.8, 0.2, 0.5)
@export var path_highlight_color: Color = Color(0.2, 0.6, 0.8, 0.4)
@export var starting_tile_color: Color = Color(0, 0.8, 0, 0.3)
@export var starting_tile_border_color: Color = Color(0, 0.8, 0, 0.7)
@export var starting_tile_immobilized_color: Color = Color(0.9, 0.9, 0, 0.4)
@export var starting_tile_immobilized_border_color: Color = Color(0.9, 0.9, 0, 0.8)
@export var test_highlight_enabled: bool = true:
	set(value):
		test_highlight_enabled = value
		if test_highlight_enabled and is_inside_tree():
			_create_test_highlight()
		elif not test_highlight_enabled:
			_clear_test_highlight()

var test_highlight_id = ""
var starting_tile_highlight_id = "starting_tile"

func _ready():
	# Create layers in both editor and runtime
	_setup_layers()
	
	# Get references
	grid_manager = get_parent()
	
	if !grid_manager or !grid_manager.has_method("grid_to_screen"):
		push_error("GridVisualizer: Parent is not a valid GridManager!")
		return
		
	# Connect all signals from the grid manager and signal manager
	print("GridVisualizer: Connecting signals in _ready()")
	
	# Connect essential signals DIRECTLY from GridManager first
	# This ensures signals are connected regardless of SignalManager
	if grid_manager and grid_manager.has_signal("starting_tile_added"):
		print("GridVisualizer: Directly connecting to GridManager starting_tile_added")
		if !grid_manager.is_connected("starting_tile_added", Callable(self, "_on_starting_tile_added")):
			grid_manager.connect("starting_tile_added", Callable(self, "_on_starting_tile_added"))
	
	# Use SignalManager for connections
	var signal_manager = get_node_or_null("/root/SignalManager")
	if signal_manager:
		print("GridVisualizer: Found SignalManager")
		
		# Connect signals
		SignalManager.connect_signal("grid_object_added", self, "_on_grid_object_added")
		SignalManager.connect_signal("grid_object_removed", self, "_on_grid_object_removed")
		SignalManager.connect_signal("grid_hovered", self, "_on_grid_hovered")
		SignalManager.connect_signal("grid_hover_exited", self, "_on_grid_hover_exited")
		SignalManager.connect_signal("grid_tile_clicked", self, "_on_grid_tile_clicked")
		SignalManager.connect_signal("path_calculated", self, "_on_path_calculated")
		SignalManager.connect_signal("poi_generated", self, "_on_poi_generated")
		SignalManager.connect_signal("starting_tile_added", self, "_on_starting_tile_added")
		SignalManager.connect_signal("player_state_changed", self, "_on_player_state_changed")
	else:
		push_error("GridVisualizer: SignalManager not found!")
	
	# Debug
	print("GridVisualizer initialized. Waiting for starting_tile_added signal.")

func _setup_layers():
	# Clean up any existing layers first
	for child in get_children():
		if child.name in ["HighlightLayer", "ObjectLayer", "FogLayer"]:
			child.queue_free()
			
	# Create visual layers with proper z-indexing
	highlight_layer = Node2D.new()
	highlight_layer.name = "HighlightLayer"
	highlight_layer.z_index = 1
	add_child(highlight_layer)
	
	object_layer = Node2D.new()
	object_layer.name = "ObjectLayer"
	object_layer.z_index = 5
	add_child(object_layer)
	
	fog_layer = Node2D.new()
	fog_layer.name = "FogLayer"
	fog_layer.z_index = 10
	add_child(fog_layer)

# Add handler for grid_object_added signal
func _on_grid_object_added(object_type: String, grid_pos: Vector2):
	# Special handling for player on starting tile 
	if object_type == "player" and grid_pos == starting_tile_position:
		print("GridVisualizer: Player added to starting tile position: ", grid_pos)
	
	update_grid_position(grid_pos)

# Add handler for grid_object_removed signal
func _on_grid_object_removed(object_type: String, grid_pos: Vector2):
	_clear_position_visuals(grid_pos)
	
	# Re-apply starting tile highlight if this was the starting position
	if grid_pos == starting_tile_position:
		update_starting_tile_highlight()

# Create a test highlight to verify the system works
func _create_test_highlight():
	if not grid_manager:
		return
		
	# Create test highlight at grid center 
	var test_pos = Vector2(int(_get_grid_size_x() / 2), int(_get_grid_size_y() / 2))
	test_highlight_id = "test_highlight"
	_add_highlight(test_pos, default_highlight_color, Color.RED, test_highlight_id)

# Clear the test highlight
func _clear_test_highlight():
	if test_highlight_id:
		_remove_highlight(test_highlight_id)
		test_highlight_id = ""

# MOUSE HANDLERS
# Handler for grid_mouse_hover signal
func _on_grid_mouse_hover(grid_pos: Vector2):
	# Remove previous hover highlight if any
	if hover_highlight_id:
		_remove_highlight(hover_highlight_id)
		
	# Add new hover highlight
	hover_highlight_id = "hover"
	_add_highlight(grid_pos, hover_highlight_color, Color.TRANSPARENT, hover_highlight_id)

# Handler for grid_mouse_exit signal
func _on_grid_mouse_exit():
	# Remove hover highlight
	if hover_highlight_id:
		_remove_highlight(hover_highlight_id)
		hover_highlight_id = ""

# Handler for grid_tile_clicked signal
func _on_grid_tile_clicked(grid_pos: Vector2):
	# Remove previous selection highlight if any
	if selection_highlight_id:
		_remove_highlight(selection_highlight_id)
		
	# Add new selection highlight
	selection_highlight_id = "selection"
	_add_highlight(grid_pos, selection_highlight_color, Color.GREEN, selection_highlight_id)

# Handler for path_calculated signal
func _on_path_calculated(path: Array):
	# Clear previous path highlight
	if path_highlight_id:
		_remove_highlight(path_highlight_id)
		path_highlight_id = ""
	
	# Create highlights for each tile in the path
	for i in range(path.size()):
		var pos = path[i]
		
		# Verify this tile is passable through the grid manager before highlighting
		if grid_manager.has_method("is_tile_passable") and grid_manager.is_tile_passable(pos):
			var id = "path_%d" % i
			_add_highlight(pos, path_highlight_color, Color.TRANSPARENT, id)
		else:
			print("Not highlighting impassable tile at path position: ", pos)

# GRID OBJECTS
# Create a sprite for an object at the specified grid position
func _create_sprite(grid_pos: Vector2, texture: Texture2D, modulate: Color = Color.WHITE) -> void:
	# Remove any existing sprite at this position
	if object_sprites.has(grid_pos):
		var old_sprite = object_sprites[grid_pos]
		if is_instance_valid(old_sprite):
			old_sprite.queue_free()
		object_sprites.erase(grid_pos)
	
	# Create new sprite
	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.modulate = modulate
	sprite.position = grid_manager.grid_to_screen(grid_pos)
	object_layer.add_child(sprite)
	object_sprites[grid_pos] = sprite

# Add a highlight to a grid position with specified colors and ID
func _add_highlight(grid_pos: Vector2, color: Color, border_color: Color = Color.TRANSPARENT, id: String = "") -> String:
	# Skip if already exists
	if id != "" and active_highlights.has(id):
		var highlight = active_highlights[id]
		if highlight and is_instance_valid(highlight):
			highlight.color = color
			# Update border if it has one
			for child in highlight.get_children():
				if child is Line2D:
					child.default_color = border_color
			return id
	
	# Safety check
	if not grid_manager:
		return ""
	
	# Convert grid position to screen position
	var screen_pos = grid_manager.grid_to_screen(grid_pos)
	
	# Create polygon node
	var polygon = Polygon2D.new()
	
	# Create isometric tile shape (no position offset)
	var iso_tile = _create_iso_polygon()
	
	polygon.polygon = iso_tile
	polygon.color = color
	polygon.position = screen_pos
	highlight_layer.add_child(polygon)
	
	# If there's a border color, add a border
	if border_color != Color.TRANSPARENT:
		var line = Line2D.new()
		
		# Create a new array for Line2D points - we need to close the loop by including the first point again
		var line_points = PackedVector2Array()
		for point in iso_tile:
			line_points.append(point)
		line_points.append(iso_tile[0]) # Close the loop
		
		line.points = line_points
		line.width = 1.5
		line.default_color = border_color
		polygon.add_child(line)
	
	# If no ID was provided, generate one
	if id == "":
		id = "highlight_%d_%d" % [grid_pos.x, grid_pos.y]
	
	# Keep track of active highlights
	active_highlights[id] = polygon
	
	# Store metadata for easy reference
	polygon.set_meta("grid_pos", grid_pos)
	polygon.set_meta("highlight_id", id)
	
	return id

# Remove a highlight by ID
func _remove_highlight(id: String) -> void:
	if active_highlights.has(id):
		var highlight = active_highlights[id]
		
		# Check if it's a valid Polygon2D and queue it for deletion
		if highlight is Polygon2D and is_instance_valid(highlight):
			highlight.queue_free()
		
		# Remove from tracking dictionary
		active_highlights.erase(id)

# Handler for POI generation signal
func _on_poi_generated(positions):
	print("Grid Visualizer: POIs generated at positions: ", positions)
	
	# Force refresh of all visuals
	for pos in positions:
		_clear_position_visuals(pos) # Clear any existing visuals first
		update_grid_position(pos)
		
# Update tile visualization with POI object
func update_grid_position(grid_pos: Vector2) -> void:
	# Clear existing visuals
	_clear_position_visuals(grid_pos)
	
	# Special case for starting tile - always keep its highlight
	if grid_pos == starting_tile_position:
		update_starting_tile_highlight()
	
	# Get the object directly from grid_manager
	var object = grid_manager.get_grid_object(grid_pos, true)
	if not object or not is_instance_valid(object):
		return
	
	# Skip visual creation for player objects since they're now instantiated as scenes
	if object.object_type == "player":
		print("GridVisualizer: Skipping player visualization at ", grid_pos)
		return
		
	# Get visual properties directly from the object
	if object.has_method("get_visual_properties"):
		var props = object.get_visual_properties()
		
		# Apply visual properties
		if props.has("sprite_texture") and props["sprite_texture"]:
			_create_sprite(grid_pos, props["sprite_texture"],
						  props.get("sprite_modulate", Color.WHITE))
		
		if props.has("highlight_color") and props["highlight_color"] != Color.TRANSPARENT:
			var border_color = props.get("highlight_border_color", Color.TRANSPARENT)
			_add_highlight(grid_pos, props["highlight_color"], border_color,
						  "object_%s_%s" % [grid_pos.x, grid_pos.y])
		
		if props.has("shape") and props.has("shape_points") and props.has("shape_color"):
			_update_tile_shape(grid_pos, props)
		else:
			print("Grid Visualizer: Missing shape properties for ", grid_pos)

# Update tile visualization with custom shape
func _update_tile_shape(grid_pos: Vector2, object_data) -> void:
	# Clear any existing shape at this position
	if shape_polygons.has(grid_pos):
		var old_shape = shape_polygons[grid_pos]
		if is_instance_valid(old_shape):
			old_shape.queue_free()
		shape_polygons.erase(grid_pos)
	
	# If we have an object with shape properties
	if object_data:
		var props = {}
		
		# Try to get visual properties from the object
		if grid_manager.has_method("get_grid_object_visual_properties"):
			props = grid_manager.get_grid_object_visual_properties(grid_pos)
		elif object_data.has_method("get_visual_properties"):
			props = object_data.get_visual_properties()
		elif object_data.object and object_data.object.has_method("get_visual_properties"):
			props = object_data.object.get_visual_properties()
		
		if props.has("shape") and props.has("shape_points") and props.has("shape_color"):
			# Create a shape polygon for the object
			var polygon = Polygon2D.new()
			polygon.polygon = props["shape_points"]
			polygon.color = props["shape_color"]
			
			# Get base position from grid position
			var base_position = grid_manager.grid_to_screen(grid_pos)
			
			# Apply offsets if available
			if props.has("horizontal_offset") or props.has("vertical_offset"):
				var h_offset = props.get("horizontal_offset", 0.0)
				var v_offset = props.get("vertical_offset", 0.0)
				polygon.position = base_position + Vector2(h_offset, v_offset)
			else:
				polygon.position = base_position
				
			object_layer.add_child(polygon)
			shape_polygons[grid_pos] = polygon

# Clear all visuals at a specific grid position
func _clear_position_visuals(grid_pos: Vector2) -> void:
	# Remove highlight if it exists
	var highlight_id = "object_%s_%s" % [grid_pos.x, grid_pos.y]
	_remove_highlight(highlight_id)
	
	# Remove sprite if it exists
	if object_sprites.has(grid_pos):
		var sprite = object_sprites[grid_pos]
		if is_instance_valid(sprite):
			sprite.queue_free()
		object_sprites.erase(grid_pos)
	
	# Remove shape if it exists
	if shape_polygons.has(grid_pos):
		var shape = shape_polygons[grid_pos]
		if is_instance_valid(shape):
			shape.queue_free()
		shape_polygons.erase(grid_pos)

func refresh_all_visuals() -> void:
	for y in range(_get_grid_size_y()):
		for x in range(_get_grid_size_x()):
			var grid_pos = Vector2(x, y)
			update_grid_position(grid_pos)

# Handler for starting_tile_added signal
func _on_starting_tile_added(grid_pos: Vector2) -> void:
	print("GridVisualizer: _on_starting_tile_added called with position: ", grid_pos)
	
	# Clear any existing starting tile visuals
	if starting_tile_position != Vector2(-1, -1):
		print("GridVisualizer: Clearing existing starting tile visuals at: ", starting_tile_position)
		_clear_position_visuals(starting_tile_position)
		if starting_tile_highlight_id != "":
			_remove_highlight(starting_tile_highlight_id)
			starting_tile_highlight_id = ""
	
	# Set the new starting tile position
	starting_tile_position = grid_pos
	
	# Add highlight for the starting tile
	update_starting_tile_highlight()
	
	# Debug verification
	if starting_tile_highlight_id.is_empty():
		print("ERROR: starting_tile_highlight_id is empty after update!")
		return
		
	if !active_highlights.has(starting_tile_highlight_id):
		print("ERROR: highlight not found in active_highlights dictionary!")
		
		# Try to add it directly as a fallback
		var color = starting_tile_color
		var border_color = starting_tile_border_color
		
		# Check if we need to use immobilized colors
		if grid_manager and grid_manager.player_instance and grid_manager.player_instance.has_method("get_player_state"):
			var player_state = grid_manager.player_instance.get_player_state()
			if player_state == "IMMOBILIZED":
				color = starting_tile_immobilized_color
				border_color = starting_tile_immobilized_border_color
		
		starting_tile_highlight_id = _add_highlight(starting_tile_position, color, border_color, "starting_tile")
		print("GridVisualizer: Retry - Starting tile highlight created with ID: ", starting_tile_highlight_id)
	else:
		print("GridVisualizer: Starting tile highlight successfully created with ID: ", starting_tile_highlight_id)

# Update the starting tile highlight based on current game state
func update_starting_tile_highlight() -> void:
	print("GridVisualizer: Updating starting tile highlight. Position: ", starting_tile_position)
	
	# Skip if no valid starting position is set
	if starting_tile_position == Vector2(-1, -1):
		print("GridVisualizer: No valid starting tile position set")
		return
	
	# Clear any existing highlight first
	if starting_tile_highlight_id != "":
		print("GridVisualizer: Removing existing highlight with ID: ", starting_tile_highlight_id)
		_remove_highlight(starting_tile_highlight_id)
		starting_tile_highlight_id = ""
	
	# Determine colors based on player state
	var color = starting_tile_color
	var border_color = starting_tile_border_color
	
	# Check if player is in IMMOBILIZED state
	if grid_manager and grid_manager.player_instance and grid_manager.player_instance.has_method("get_player_state"):
		var player_state = grid_manager.player_instance.get_player_state()
		print("GridVisualizer: Player state is: ", player_state)
		if player_state == "IMMOBILIZED":
			color = starting_tile_immobilized_color
			border_color = starting_tile_immobilized_border_color
	
	# Add the highlight
	starting_tile_highlight_id = _add_highlight(starting_tile_position, color, border_color, "starting_tile")
	print("GridVisualizer: Updated starting tile highlight with ID: ", starting_tile_highlight_id)

# Handler for player state changes to update starting tile highlight
func _on_player_state_changed(player_id: int, state: String, is_on_starting_tile: bool):
	print("GridVisualizer: Received player_state_changed signal. State: ", state)
	
	# Always update the starting tile highlight regardless of player position
	# This ensures starting tile has appropriate highlighting in all cases
	update_starting_tile_highlight()

# Helper methods to access grid configuration
func _get_grid_size_x() -> int:
	return grid_manager.grid_size_x if grid_manager else 8

func _get_grid_size_y() -> int:
	return grid_manager.grid_size_y if grid_manager else 8

func _get_tile_width() -> int:
	return grid_manager.tile_width if grid_manager else 64

func _get_tile_height() -> int:
	return grid_manager.tile_height if grid_manager else 32

# Create iso polygon function
func _create_iso_polygon(center: Vector2 = Vector2.ZERO, scale_factor: float = 1.0) -> PackedVector2Array:
	# Create isometric tile shape
	var iso_tile = []
	var half_width = _get_tile_width() * 0.5 * scale_factor
	var half_height = _get_tile_height() * 0.5 * scale_factor
	
	# If center is zero, create a centered polygon
	if center == Vector2.ZERO:
		iso_tile.append(Vector2(0, -half_height)) # Top
		iso_tile.append(Vector2(half_width, 0)) # Right
		iso_tile.append(Vector2(0, half_height)) # Bottom
		iso_tile.append(Vector2(-half_width, 0)) # Left
	else:
		# Create polygon at specific position
		iso_tile.append(Vector2(center.x, center.y - half_height)) # Top
		iso_tile.append(Vector2(center.x + half_width, center.y)) # Right
		iso_tile.append(Vector2(center.x, center.y + half_height)) # Bottom
		iso_tile.append(Vector2(center.x - half_width, center.y)) # Left
	
	return PackedVector2Array(iso_tile)

# Force set starting tile (can be called from other scripts)
func force_set_starting_tile(grid_pos: Vector2) -> void:
	print("GridVisualizer: Force setting starting tile at: ", grid_pos)
	
	# Clear any existing starting tile visuals
	if starting_tile_position != Vector2(-1, -1):
		_clear_position_visuals(starting_tile_position)
		_remove_highlight(starting_tile_highlight_id)
	
	# Set the new starting tile position
	starting_tile_position = grid_pos
	
	# Add highlight with default colors
	update_starting_tile_highlight()
	
	# Verify highlight was created
	if active_highlights.has(starting_tile_highlight_id):
		print("GridVisualizer: Starting tile highlight successfully set through force function")
	else:
		print("GridVisualizer: Failed to add starting tile highlight through force function!")
