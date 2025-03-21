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

func _ready():
	# Only find grid manager and register if not already set up
	if not grid_manager:
		grid_manager = _find_grid_manager()
		# Only auto-register if position is explicitly set and not default values
		if grid_manager and grid_position != Vector2(0, 0) and grid_position != Vector2():
			register_with_grid()

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
		return grid_manager.register_grid_object(self, grid_position)
	
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
		grid_manager.unregister_grid_object(grid_position)

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
		grid_manager.unregister_grid_object(grid_position)
		
		# Update position
		grid_position = new_pos
		
		# Register at new position
		grid_manager.register_grid_object(self, grid_position)
		
		# Update visual position
		position = grid_manager.grid_to_screen(grid_position)
