# poi.gd - Point of Interest object
class_name POI
extends GridObject

# Define shape options
enum ShapeType {SQUARE, TRIANGLE, GEM}

# HOW TO ADD NEW SHAPES:
# 1. Add the new shape to the ShapeType enum above (e.g., HEXAGON)
# 2. Add the corresponding string key to the SHAPE_KEYS constant below (e.g., "hexagon")
# 3. Add the shape definition to the SHAPES dictionary using the same string key
# 4. Add the color to the SHAPE_COLORS dictionary using the same string key
# 5. Add the offset to the SHAPE_OFFSETS dictionary to optionally adjust shape position
# 6. Add the scale factors to the SHAPE_SCALES dictionary for controlling size
# No other code changes are needed - the randomize_properties() and shape_type_to_string() 
# functions will automatically work with the new shape.

# Shape definitions - use variable instead of constant for PackedVector2Array objects

# this first set of shapes is 1x size
# var SHAPES = {
# 	"square": PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]),
# 	"triangle": PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(0, 8)]),
# 	"gem": PackedVector2Array([Vector2(0, 0), Vector2(8, -16), Vector2(0, -24), Vector2(-8, -16)])
# }

# this second set of shapes is 2x size
var SHAPES = {
	"square": PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]),
	"triangle": PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(0, 16)]),
	"gem": PackedVector2Array([Vector2(0, 0), Vector2(16, -32), Vector2(0, -48), Vector2(-16, -32)])
}

# Shape colors - these can be constants since Color is a builtin type
const SHAPE_COLORS = {
	"square": Color(0.686, 0.255, 0.541, 0.9), # purple
	"gem": Color(0.447, 0.882, 0.82, 0.9), # blue
	"triangle": Color(1.0, 0.737, 0.259, 1.0) # yellow
}

# Default offsets for each shape type (x, y). Negative values move the shape up and left.
const SHAPE_OFFSETS = {
	"square": Vector2(0, -10),
	"triangle": Vector2(0, -15),
	"gem": Vector2(0, 0)
}

# Default scale factors for each shape type (x_scale, y_scale)
const SHAPE_SCALES = {
	"square": Vector2(1.0, 1.0),
	"triangle": Vector2(1.0, 1.0),
	"gem": Vector2(1.0, 1.0)
}

var value: int = 50
var collected: bool = false
var shape_type: String = ""

# Offset properties for positioning along true x/y axes
var horizontal_offset: float = 0.0
var vertical_offset: float = 0.0

# Scale properties for adjusting shape size
var scale_x: float = 1.0
var scale_y: float = 1.0

# Array of string keys matching enum order
const SHAPE_KEYS = ["square", "triangle", "gem"]

# Static counter to track which shape to generate next
static var next_shape_index: int = 0

# Helper function to convert enum to string key
func shape_type_to_string(shape: ShapeType) -> String:
	# Check if the enum value is within valid range
	if shape >= 0 and shape < SHAPE_KEYS.size():
		return SHAPE_KEYS[shape]
	return "square" # Default fallback

func _init():
	object_type = "poi"
	set_shape(ShapeType.SQUARE)

func _ready():
	super._ready()

func set_shape(new_shape: ShapeType):
	var shape_key = shape_type_to_string(new_shape)
	if SHAPES.has(shape_key):
		shape_type = shape_key
		
		# Update visual properties
		highlight_color = SHAPE_COLORS[shape_key].darkened(0.2)
		highlight_color.a = 0.4 # Make highlight more transparent
		
		highlight_border_color = SHAPE_COLORS[shape_key]
		
		# POIs are always visible through fog
		disable_fog = true
		
		# Set shape-specific offsets
		if SHAPE_OFFSETS.has(shape_key):
			horizontal_offset = SHAPE_OFFSETS[shape_key].x
			vertical_offset = SHAPE_OFFSETS[shape_key].y
		else:
			# Default - no offset
			horizontal_offset = 0.0
			vertical_offset = 0.0
			
		# Set shape-specific scales
		if SHAPE_SCALES.has(shape_key):
			scale_x = SHAPE_SCALES[shape_key].x
			scale_y = SHAPE_SCALES[shape_key].y
		else:
			# Default - no scaling
			scale_x = 1.0
			scale_y = 1.0

# Set the scale factor for both dimensions (with a different name to avoid conflicts with Node2D.set_scale)
func set_shape_scale(x_scale: float, y_scale: float) -> void:
	scale_x = x_scale
	scale_y = y_scale
		
# Uniformly scale both dimensions
func set_uniform_shape_scale(scale: float) -> void:
	set_shape_scale(scale, scale)

func get_visual_properties() -> Dictionary:
	var props = super.get_visual_properties()
	
	# Add shape information
	props["shape"] = shape_type
	
	# Add scaled shape points
	var scaled_points = []
	for point in SHAPES[shape_type]:
		scaled_points.append(Vector2(point.x * scale_x, point.y * scale_y))
	
	props["shape_points"] = PackedVector2Array(scaled_points)
	props["shape_color"] = SHAPE_COLORS[shape_type] if not collected else SHAPE_COLORS[shape_type].darkened(0.5)
	props["horizontal_offset"] = horizontal_offset
	props["vertical_offset"] = vertical_offset
	props["scale_x"] = scale_x
	props["scale_y"] = scale_y
	
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
		register_with_grid()
		
		return value
	return 0

# Replaces static create_random() with instance method
func randomize_properties():
	# Instead of random, cycle through each shape type
	var shape = next_shape_index
	set_shape(shape)
	
	# Increment counter and wrap around when we reach the end
	next_shape_index = (next_shape_index + 1) % ShapeType.size()
	
	# Set random value
	value = randi_range(10, 100)
	
	return self
