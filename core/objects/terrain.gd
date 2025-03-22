# terrain.gd
class_name Terrain
extends GridObject

# Simple pyramid shape - use variable instead of constant for PackedVector2Array
# var PYRAMID_SHAPE = PackedVector2Array([Vector2(-10, 0), Vector2(0, -20), Vector2(10, 0), Vector2(0, 5)])
# 2x size
var PYRAMID_SHAPE = PackedVector2Array([Vector2(-20, 0), Vector2(0, -40), Vector2(20, 0), Vector2(0, 10)])

# Terrain color
const TERRAIN_COLOR = Color(0.6, 0.4, 0.2, 0.8) # Brownish

var is_passable: bool = false

# Add offset properties similar to POI
var horizontal_offset: float = 0.0
var vertical_offset: float = 0.0

func _init():
    object_type = "terrain"
    
    # Set visual properties
    highlight_color = TERRAIN_COLOR.darkened(0.2)
    highlight_color.a = 0.3 # Make highlight more transparent
    
    highlight_border_color = TERRAIN_COLOR
    
    # Terrain is not visible through fog by default
    disable_fog = false

func _ready():
    super._ready()

# Method to check if terrain is passable
func get_is_passable() -> bool:
    return is_passable

func get_visual_properties() -> Dictionary:
    var props = super.get_visual_properties()
    
    # Add shape information
    props["shape"] = "pyramid" # Add a shape identifier similar to POI
    props["shape_points"] = PYRAMID_SHAPE
    props["shape_color"] = TERRAIN_COLOR
    
    # Add offset properties that grid_visualizer might be looking for
    props["horizontal_offset"] = horizontal_offset
    props["vertical_offset"] = vertical_offset
    
    # Add scale properties that grid_visualizer might be looking for
    props["scale_x"] = 1.0
    props["scale_y"] = 1.0
    
    return props