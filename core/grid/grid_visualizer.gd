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

# Visual tracking
var object_sprites = {} # Dictionary keyed by grid position
var shape_polygons = {} # Dictionary to track shape polygons

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
	SignalManager.connect_signal("grid_object_added", self, "_on_grid_object_added")
	SignalManager.connect_signal("grid_object_removed", self, "_on_grid_object_removed")
	SignalManager.connect_signal("grid_hovered", self, "_on_grid_mouse_hover")
	SignalManager.connect_signal("grid_hover_exited", self, "_on_grid_mouse_exit")
	SignalManager.connect_signal("grid_tile_clicked", self, "_on_grid_tile_clicked")
	SignalManager.connect_signal("path_calculated", self, "_on_path_calculated")

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
	update_grid_position(grid_pos)

# Add handler for grid_object_removed signal
func _on_grid_object_removed(object_type: String, grid_pos: Vector2):
	_clear_position_visuals(grid_pos)

# Create a test highlight to verify the system works
func _create_test_highlight():
	if not grid_manager:
		return
		
	# Create test highlight at grid center 
	var test_pos = Vector2(int(grid_manager.grid_size_x / 2), int(grid_manager.grid_size_y / 2))
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
		var id = "path_%d" % i
		_add_highlight(pos, path_highlight_color, Color.TRANSPARENT, id)

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
func _add_highlight(grid_pos: Vector2, color: Color, border_color: Color, id: String) -> void:
	# Remove existing highlight with this ID if it exists
	_remove_highlight(id)
	
	# Get screen position for the grid position
	var screen_pos = grid_manager.grid_to_screen(grid_pos)
	
	# Create highlight polygon
	var polygon = Polygon2D.new()
	
	# Create isometric tile shape
	var iso_tile = []
	var half_width = grid_manager.tile_width * 0.5
	var half_height = grid_manager.tile_height * 0.5
	
	iso_tile.append(Vector2(0, -half_height)) # Top
	iso_tile.append(Vector2(half_width, 0)) # Right
	iso_tile.append(Vector2(0, half_height)) # Bottom
	iso_tile.append(Vector2(-half_width, 0)) # Left
	
	polygon.polygon = PackedVector2Array(iso_tile)
	polygon.color = color
	polygon.position = screen_pos
	highlight_layer.add_child(polygon)
	
	# If there's a border color, add a border
	if border_color != Color.TRANSPARENT:
		var line = Line2D.new()
		line.points = PackedVector2Array(iso_tile + [iso_tile[0]]) # Close the loop
		line.width = 1.5
		line.default_color = border_color
		line.position = screen_pos
		highlight_layer.add_child(line)
		
		# Store both polygon and line in active highlights
		active_highlights[id] = {"polygon": polygon, "line": line, "position": grid_pos}
	else:
		# Store just the polygon in active highlights
		active_highlights[id] = {"polygon": polygon, "line": null, "position": grid_pos}

# Remove a highlight by ID
func _remove_highlight(id: String) -> void:
	if active_highlights.has(id):
		var highlight = active_highlights[id]
		
		# Remove polygon
		if highlight.has("polygon") and is_instance_valid(highlight["polygon"]):
			highlight["polygon"].queue_free()
			
		# Remove line if it exists
		if highlight.has("line") and is_instance_valid(highlight["line"]):
			highlight["line"].queue_free()
			
		# Remove from tracking dictionary
		active_highlights.erase(id)

# Handler for POI generation signal
func _on_poi_generated(positions):
	print("Grid Visualizer: POIs generated at positions: ", positions)
	# Refresh all POI visuals
	for pos in positions:
		update_grid_position(pos)

# Update tile visualization with POI object
func update_grid_position(grid_pos: Vector2) -> void:
	# Clear existing visuals
	_clear_position_visuals(grid_pos)
	
	# Get the object directly from grid_manager
	var object = grid_manager.get_grid_object_reference(grid_pos)
	if not object or not is_instance_valid(object):
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
			polygon.position = grid_manager.grid_to_screen(grid_pos)
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
	for y in range(grid_manager.grid_size_y):
		for x in range(grid_manager.grid_size_x):
			var grid_pos = Vector2(x, y)
			update_grid_position(grid_pos)
