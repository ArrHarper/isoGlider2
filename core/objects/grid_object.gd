# grid_object.gd - Base class for all grid objects
class_name GridObject
extends Node2D

# Object properties
var grid_position: Vector2
var object_type: String = "generic"
var grid_manager = null

# Visual properties
var highlight_color = Color.TRANSPARENT
var highlight_border_color = Color.TRANSPARENT
var sprite_texture = null
var sprite_modulate = Color.WHITE
var disable_fog = false
var polygon: Polygon2D = null

func _ready():
	# Only find grid manager and register if not already set up
	if not grid_manager:
		grid_manager = _find_grid_manager()
		# Only auto-register if position is explicitly set and not default values
		if grid_manager and grid_position != Vector2(0, 0) and grid_position != Vector2():
			register_with_grid()
	
	# Set up preview polygon for editor visualization
	if Engine.is_editor_hint():
		_setup_preview_polygon()

func _find_grid_manager():
	var parent = get_parent()
	while parent:
		if parent.has_method("grid_to_screen") and parent.has_method("register_grid_object"):
			return parent
		parent = parent.get_parent()
	return null

func register_with_grid():
	if not grid_manager:
		push_error("Cannot register grid object - no grid manager found")
		return false
		
	# Only register if we have a valid grid position
	if grid_position != null and grid_position != Vector2(-1, -1):
		return grid_manager.add_grid_object(self, grid_position)
	
	return false

func setup(manager, position: Vector2):
	grid_manager = manager
	grid_position = position
	
	# Update visual position
	if grid_manager:
		position = grid_manager.grid_to_screen(grid_position)
	
	return register_with_grid()

func unregister_from_grid():
	if grid_manager:
		grid_manager.remove_grid_object(grid_position)

func get_visual_properties() -> Dictionary:
	return {
		"type": object_type,
		"highlight_color": highlight_color,
		"highlight_border_color": highlight_border_color,
		"sprite_texture": sprite_texture,
		"sprite_modulate": sprite_modulate,
		"disable_fog": disable_fog
	}

# When position changes
func set_grid_position(new_pos: Vector2):
	if grid_manager:
		# Unregister from old position
		grid_manager.remove_grid_object(grid_position)
		
		# Update position
		grid_position = new_pos
		
		# Register at new position
		grid_manager.add_grid_object(self, grid_position)
		
		# Update visual position
		position = grid_manager.grid_to_screen(grid_position)

# Setup preview polygon for editor visualization
func _setup_preview_polygon():
	if not is_inside_tree():
		return
		
	# Remove existing polygon if needed
	if polygon and is_instance_valid(polygon):
		polygon.queue_free()
	
	# Get visual properties
	var props = get_visual_properties()
	var shape_points = null
	var shape_color = Color.WHITE
	
	# Check if the object provides shape points and color
	if props.has("shape_points"):
		shape_points = props["shape_points"]
	if props.has("shape_color"):
		shape_color = props["shape_color"]
	
	# If no shape_points found but there's a constant/variable in the class with a name ending in _SHAPE or similar
	if not shape_points:
		for property in get_property_list():
			var prop_name = property["name"]
			if prop_name.ends_with("_SHAPE") and get(prop_name) is PackedVector2Array:
				shape_points = get(prop_name)
				break
	
	# Similarly try to find a color property if not specified
	if shape_color == Color.WHITE:
		for property in get_property_list():
			var prop_name = property["name"]
			if prop_name.ends_with("_COLOR") and get(prop_name) is Color:
				shape_color = get(prop_name)
				break
	
	# If we have shape points, create the polygon
	if shape_points:
		polygon = Polygon2D.new()
		polygon.polygon = shape_points
		polygon.color = shape_color
		
		# Apply offsets if any
		if props.has("horizontal_offset") and props.has("vertical_offset"):
			polygon.position = Vector2(props["horizontal_offset"], props["vertical_offset"])
		
		add_child(polygon)
		
		# Make sure polygon is owned by the scene in editor
		if Engine.is_editor_hint() and get_tree().edited_scene_root:
			polygon.owner = get_tree().edited_scene_root
