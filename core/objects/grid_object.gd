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
	# Find grid manager in hierarchy
	grid_manager = _find_grid_manager()
	if grid_manager:
		# Register with grid manager
		register_with_grid()

func _find_grid_manager():
	var parent = get_parent()
	while parent:
		if parent.has_method("grid_to_screen") and parent.has_method("register_grid_object"):
			return parent
		parent = parent.get_parent()
	return null

func register_with_grid():
	# Only register if we have a valid grid position
	if grid_position != null and grid_position != Vector2(-1, -1) and grid_position != Vector2():
		grid_manager.register_grid_object(self, grid_position)
	else:
		# Object has no valid grid position, don't register it
		pass

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
