@tool
extends Node2D

# Reference to the grid manager
var grid_manager: Node2D

# Layer handling
var highlight_layer: Node2D
var object_layer: Node2D
var fog_layer: Node2D

# Highlight tracking
var active_highlights = {}
var hover_highlight_id = ""
var path_highlight_id = ""
var selection_highlight_id = ""

# Visual configuration
@export_category("Visual Settings")
@export var default_highlight_color: Color = Color(0.5, 0.5, 0.5, 0.3)
@export var hover_highlight_color: Color = Color(0.7, 0.7, 0.7, 0.5)
@export var selection_highlight_color: Color = Color(0.2, 0.8, 0.2, 0.5)
@export var path_highlight_color: Color = Color(0.2, 0.6, 0.8, 0.4)
@export var test_highlight_enabled: bool = true:
	set(value):
		test_highlight_enabled = value
		if test_highlight_enabled and is_inside_tree():
			_create_test_highlight()
		elif not test_highlight_enabled:
			_clear_test_highlight()

var test_highlight_id = ""

func _ready():
	print("GridVisualizer initialized")
	
	# Create layers in both editor and runtime
	_setup_layers()
	
	if Engine.is_editor_hint():
		# In editor, get parent reference and create test highlight if enabled
		grid_manager = get_parent()
		if grid_manager and grid_manager.has_method("grid_to_screen") and test_highlight_enabled:
			call_deferred("_create_test_highlight")
		return
		
	# Runtime setup
	grid_manager = get_parent()
	
	if not grid_manager or not grid_manager.has_method("grid_to_screen"):
		push_error("GridVisualizer must be a child of GridManager!")
		return
	
	# Manual test - add a highlight to see if it appears
	if test_highlight_enabled:
		call_deferred("_create_test_highlight")
	
	# Instead of depending on SignalManager, connect to grid_manager signals directly
	if grid_manager.has_signal("grid_mouse_hover"):
		grid_manager.connect("grid_mouse_hover", _on_grid_mouse_hover)
	if grid_manager.has_signal("grid_mouse_exit"):
		grid_manager.connect("grid_mouse_exit", _on_grid_mouse_exit)
	if grid_manager.has_signal("grid_tile_clicked"):
		grid_manager.connect("grid_tile_clicked", _on_grid_tile_clicked)
	if grid_manager.has_signal("path_calculated"):
		grid_manager.connect("path_calculated", _on_path_calculated)

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

func _create_test_highlight():
	if test_highlight_id != "":
		remove_highlight(test_highlight_id)
		
	if not grid_manager or not grid_manager.has_method("grid_to_screen"):
		return
		
	test_highlight_id = add_highlight(Vector2(3, 3), "test", Color(1, 0, 0, 0.5))

func _clear_test_highlight():
	if test_highlight_id != "":
		remove_highlight(test_highlight_id)
		test_highlight_id = ""

# Add a highlight to a specific tile with a given type
func add_highlight(grid_pos: Vector2, type: String = "default",
				   color: Color = Color.TRANSPARENT, border_color: Color = Color.TRANSPARENT) -> String:
	# Skip if position is invalid or no grid manager
	if not grid_manager or not grid_manager.has_method("is_valid_grid_position") or not grid_manager.is_valid_grid_position(grid_pos):
		return ""
	
	# Ensure highlight layer exists
	if not highlight_layer or not is_instance_valid(highlight_layer):
		_setup_layers()
		
	# Determine colors based on type if not explicitly provided
	if color == Color.TRANSPARENT:
		match type:
			"hover": color = hover_highlight_color
			"selection": color = selection_highlight_color
			"path": color = path_highlight_color
			_: color = default_highlight_color
	
	if border_color == Color.TRANSPARENT:
		border_color = Color(color.r, color.g, color.b, min(color.a + 0.3, 1.0))
	
	# Create unique ID for this highlight
	var highlight_id = type + "_" + str(grid_pos.x) + "_" + str(grid_pos.y) + "_" + str(Time.get_ticks_msec())
	
	# Create the visual elements
	var screen_pos = grid_manager.grid_to_screen(grid_pos)
	var tile_width = grid_manager.tile_width
	var tile_height = grid_manager.tile_height
	
	# Create diamond shape polygon
	var points = [
		Vector2(screen_pos.x, screen_pos.y - tile_height / 2), # Top
		Vector2(screen_pos.x + tile_width / 2, screen_pos.y), # Right
		Vector2(screen_pos.x, screen_pos.y + tile_height / 2), # Bottom
		Vector2(screen_pos.x - tile_width / 2, screen_pos.y) # Left
	]
	
	var polygon = Polygon2D.new()
	polygon.polygon = points
	polygon.color = color
	highlight_layer.add_child(polygon)
	
	var outline = Line2D.new()
	outline.points = points + [points[0]] # Close the shape
	outline.width = 1.0
	outline.default_color = border_color
	highlight_layer.add_child(outline)
	
	# Store in active highlights
	active_highlights[highlight_id] = {
		"type": type,
		"position": grid_pos,
		"nodes": [polygon, outline]
	}
	
	# For specific highlight types, track their IDs
	match type:
		"hover": hover_highlight_id = highlight_id
		"selection": selection_highlight_id = highlight_id
		"path":
			# For paths, we might have multiple highlights with this type
			if typeof(path_highlight_id) != TYPE_ARRAY:
				path_highlight_id = []
			path_highlight_id.append(highlight_id)
	
	return highlight_id

# Remove a highlight by ID
func remove_highlight(highlight_id: String) -> bool:
	if active_highlights.has(highlight_id):
		# Get the highlight info
		var highlight = active_highlights[highlight_id]
		
		# Free the visual nodes
		for node in highlight.nodes:
			if is_instance_valid(node):
				node.queue_free()
		
		# Remove from tracking
		active_highlights.erase(highlight_id)
		
		# Update specific type tracking
		match highlight.type:
			"hover":
				if hover_highlight_id == highlight_id:
					hover_highlight_id = ""
			"selection":
				if selection_highlight_id == highlight_id:
					selection_highlight_id = ""
			"path":
				if typeof(path_highlight_id) == TYPE_ARRAY and path_highlight_id.has(highlight_id):
					path_highlight_id.erase(highlight_id)
		
		return true
	
	return false

# Clear all highlights of a given type
func clear_highlights_by_type(type: String) -> void:
	var highlight_ids = active_highlights.keys()
	for id in highlight_ids:
		if active_highlights[id].type == type:
			remove_highlight(id)

func _on_grid_mouse_hover(grid_pos: Vector2) -> void:
	# Clear any existing hover highlight
	if hover_highlight_id:
		remove_highlight(hover_highlight_id)
	
	# Add new hover highlight
	hover_highlight_id = add_highlight(grid_pos, "hover")

func _on_grid_mouse_exit() -> void:
	# Clear hover highlight when mouse leaves grid
	if hover_highlight_id:
		remove_highlight(hover_highlight_id)
		hover_highlight_id = ""

func _on_grid_tile_clicked(grid_pos: Vector2) -> void:
	print("Grid tile clicked: ", grid_pos)
	
	# Clear any existing selection highlight
	if selection_highlight_id:
		remove_highlight(selection_highlight_id)
	
	# Add new selection highlight
	selection_highlight_id = add_highlight(grid_pos, "selection")

func _on_path_calculated(path: Array) -> void:
	# Clear any existing path highlights
	clear_highlights_by_type("path")
	
	# Add new path highlights
	path_highlight_id = []
	for point in path:
		if point != path[0]: # Skip the first point (current position)
			var id = add_highlight(point, "path")
			path_highlight_id.append(id)

# Highlight tiles within a specific range of a given position
func highlight_range(center: Vector2, range_value: int, type: String = "range",
					color: Color = Color(0.2, 0.6, 0.2, 0.2)) -> Array:
	var highlight_ids = []
	
	# Generate positions within range
	for x in range(-range_value, range_value + 1):
		for y in range(-range_value, range_value + 1):
			var pos = Vector2(center.x + x, center.y + y)
			
			# Skip the center position and make sure it's valid
			if pos != center and grid_manager.is_valid_grid_position(pos):
				# Calculate Manhattan distance
				var distance = abs(center.x - pos.x) + abs(center.y - pos.y)
				
				# Only include if within range
				if distance <= range_value:
					var id = add_highlight(pos, type, color)
					highlight_ids.append(id)
	
	return highlight_ids

# Highlight a path between two points
func highlight_path(start: Vector2, end: Vector2, type: String = "path",
				   color: Color = path_highlight_color) -> Array:
	# Clear previous path highlights
	clear_highlights_by_type(type)
	
	# Calculate a simple path between points
	var path = []
	
	# Calculate differences
	var dx = end.x - start.x
	var dy = end.y - start.y
	
	# For each step along the path
	var steps = max(abs(dx), abs(dy))
	if steps > 0:
		for i in range(1, steps + 1):
			var t = float(i) / steps
			var x = start.x + dx * t
			var y = start.y + dy * t
			path.append(Vector2(round(x), round(y)))
	
	# Add highlights for each point in the path
	var highlight_ids = []
	for point in path:
		if point != start: # Don't highlight the starting point
			var id = add_highlight(point, type, color)
			highlight_ids.append(id)
	
	return highlight_ids

# Apply a theme to all highlights (useful for dynamic visual changes)
func apply_highlight_theme(theme_name: String) -> void:
	match theme_name:
		"default":
			default_highlight_color = Color(0.5, 0.5, 0.5, 0.3)
			hover_highlight_color = Color(0.7, 0.7, 0.7, 0.5)
			selection_highlight_color = Color(0.2, 0.8, 0.2, 0.5)
			path_highlight_color = Color(0.2, 0.6, 0.8, 0.4)
		"dark":
			default_highlight_color = Color(0.2, 0.2, 0.2, 0.4)
			hover_highlight_color = Color(0.3, 0.3, 0.3, 0.6)
			selection_highlight_color = Color(0.1, 0.4, 0.1, 0.6)
			path_highlight_color = Color(0.1, 0.3, 0.4, 0.5)
		# Add more themes as needed
	
	# Update active highlights with new colors
	_refresh_highlight_colors()

# Refresh colors of all active highlights
func _refresh_highlight_colors() -> void:
	for id in active_highlights:
		var highlight = active_highlights[id]
		var color
		
		# Get appropriate color based on type
		match highlight.type:
			"hover": color = hover_highlight_color
			"selection": color = selection_highlight_color
			"path": color = path_highlight_color
			_: color = default_highlight_color
		
		# Update polygon color
		if highlight.nodes.size() > 0 and is_instance_valid(highlight.nodes[0]):
			highlight.nodes[0].color = color
		
		# Update border color
		if highlight.nodes.size() > 1 and is_instance_valid(highlight.nodes[1]):
			var border_color = Color(color.r, color.g, color.b, min(color.a + 0.3, 1.0))
			highlight.nodes[1].default_color = border_color
