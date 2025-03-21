# terrain.gd
class_name Terrain
extends GridObject

# Simple pyramid shape - use variable instead of constant for PackedVector2Array
var PYRAMID_SHAPE = PackedVector2Array([Vector2(-10, 0), Vector2(0, -20), Vector2(10, 0), Vector2(0, 5)])

# Terrain color
const TERRAIN_COLOR = Color(0.6, 0.4, 0.2, 0.8) # Brownish

var is_passable: bool = false
var polygon: Polygon2D

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
    # Set up the polygon for editor visualization
    _setup_preview_polygon()

func _setup_preview_polygon():
    if not is_inside_tree():
        return
        
    # Remove existing polygon if needed
    if polygon and is_instance_valid(polygon):
        polygon.queue_free()
        
    # Create new polygon
    polygon = Polygon2D.new()
    polygon.polygon = PYRAMID_SHAPE
    polygon.color = TERRAIN_COLOR
    add_child(polygon)
    
    # Make sure polygon is owned by the scene in editor
    if Engine.is_editor_hint() and get_tree().edited_scene_root:
        polygon.owner = get_tree().edited_scene_root

func get_visual_properties() -> Dictionary:
    var props = super.get_visual_properties()
    
    # Add shape information
    props["shape_points"] = PYRAMID_SHAPE
    props["shape_color"] = TERRAIN_COLOR
    
    return props