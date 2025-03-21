# poi.gd - Point of Interest object
class_name POI
extends GridObject

# Define shape options
enum ShapeType {SQUARE, DIAMOND, TRIANGLE, GEM}

# Shape definitions - use variable instead of constant for PackedVector2Array objects
var SHAPES = {
	"square": PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]),
	"diamond": PackedVector2Array([Vector2(0, -8), Vector2(8, 0), Vector2(0, 8), Vector2(-8, 0)]),
	"triangle": PackedVector2Array([Vector2(-8, 8), Vector2(8, 8), Vector2(0, -8)]),
	"gem": PackedVector2Array([Vector2(0, 0), Vector2(8, -16), Vector2(0, -24), Vector2(-8, -16)])
}

# Shape colors - these can be constants since Color is a builtin type
const SHAPE_COLORS = {
	"square": Color(0, 0.8, 0, 0.7), # green
	"gem": Color(0.0627451, 0.105882, 1, 0.7), # blue
	"triangle": Color(1, 0.8, 0, 0.7), # yellow
	"diamond": Color(0.0627451, 0.105882, 1, 0.7) # blue
}

var value: int = 50
var collected: bool = false
var shape_type: String = "square"
var polygon: Polygon2D

func _init():
	object_type = "poi"
	set_shape(shape_type)

func _ready():
	super._ready()
	
	# Only set up preview polygon in editor, not in-game
	if Engine.is_editor_hint():
		_setup_preview_polygon()

func _setup_preview_polygon():
	if not is_inside_tree():
		return
		
	# Only run this in the editor, not at runtime
	if not Engine.is_editor_hint():
		return
		
	# Remove existing polygon if needed
	if polygon and is_instance_valid(polygon):
		polygon.queue_free()
		
	# Create new polygon
	polygon = Polygon2D.new()
	polygon.polygon = SHAPES[shape_type]
	polygon.color = SHAPE_COLORS[shape_type]
	add_child(polygon)
	
	# Make sure polygon is owned by the scene in editor
	if Engine.is_editor_hint() and get_tree().edited_scene_root:
		polygon.owner = get_tree().edited_scene_root

func set_shape(new_shape: String):
	if SHAPES.has(new_shape):
		shape_type = new_shape
		
		# Update visual properties
		highlight_color = SHAPE_COLORS[shape_type].darkened(0.2)
		highlight_color.a = 0.4 # Make highlight more transparent
		
		highlight_border_color = SHAPE_COLORS[shape_type]
		
		# POIs are always visible through fog
		disable_fog = true
		
		# Update preview if possible
		if is_inside_tree():
			_setup_preview_polygon()

func get_visual_properties() -> Dictionary:
	var props = super.get_visual_properties()
	
	# Add shape information
	props["shape"] = shape_type
	props["shape_points"] = SHAPES[shape_type]
	props["shape_color"] = SHAPE_COLORS[shape_type] if not collected else SHAPE_COLORS[shape_type].darkened(0.5)
	
	# Update visual state based on collected state
	if collected:
		props["highlight_color"] = Color.TRANSPARENT
		props["shape_color"] = SHAPE_COLORS[shape_type].darkened(0.5)
		props["shape_color"].a = 0.3
	
	return props

func collect() -> int:
	if not collected:
		collected = true
		
		# Notify grid manager to update visuals
		if grid_manager:
			grid_manager.register_grid_object(self, grid_position)
		
		return value
	return 0

# Replaces static create_random() with instance method
func randomize_properties():
	# Randomly select a shape
	var shapes = ["square", "diamond", "triangle", "gem"]
	var shape = shapes[randi() % shapes.size()]
	set_shape(shape)
	
	# Set random value
	value = randi_range(10, 100)
	
	return self
