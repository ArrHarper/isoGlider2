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

# Signals
signal poi_collected(id, reward, position)

var value: int = 50
var collected: bool = false
var shape_type: String = ""
var poi_id: String = ""

# Collection animation properties
var collect_animation_playing: bool = false
var animation_progress: float = 0.0
var animation_duration: float = 0.5
var collect_effect_scale: float = 1.0
var float_height: float = 0.0
var max_float_height: float = 40.0

# Visual effect options
var play_effect_on_collect: bool = true
var play_sound_on_collect: bool = true

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
static var poi_counter: int = 0

# Helper function to convert enum to string key
func shape_type_to_string(shape: ShapeType) -> String:
	# Check if the enum value is within valid range
	if shape >= 0 and shape < SHAPE_KEYS.size():
		return SHAPE_KEYS[shape]
	return "square" # Default fallback

func _init():
	object_type = "poi"
	set_shape(ShapeType.SQUARE)
	
	# Generate a unique ID for this POI
	poi_id = "poi_%d" % poi_counter
	poi_counter += 1

func _ready():
	super._ready()

func _process(delta):
	if collect_animation_playing:
		# Update animation progress
		animation_progress += delta / animation_duration
		
		if animation_progress >= 1.0:
			# Animation complete
			animation_progress = 1.0
			collect_animation_playing = false
			
			# Remove the POI now that animation is complete
			call_deferred("_finish_collection")
		else:
			# Update animation properties
			_update_collection_animation()
			# Force redraw in case this is used in editor
			queue_redraw()

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
	
	# Add collection animation properties
	if collect_animation_playing:
		props["float_height"] = float_height
		props["vertical_offset"] -= float_height
		props["scale_x"] *= (1.0 + collect_effect_scale * 0.5)
		props["scale_y"] *= (1.0 + collect_effect_scale * 0.5)
		
		var alpha = 1.0 - animation_progress
		props["shape_color"].a = alpha
	
	# Update visual state based on collected state
	if collected:
		props["highlight_color"] = Color.TRANSPARENT
		props["shape_color"] = SHAPE_COLORS[shape_type].darkened(0.5)
		props["shape_color"].a = 0.3
	
	return props

func collect() -> int:
	if not collected:
		collected = true
		
		# Get grid manager and calculate the correct screen position for effects
		var screen_position = Vector2.ZERO
		var grid_manager = _find_grid_manager()
		
		if grid_manager and grid_manager.has_method("grid_to_screen"):
			# Convert grid position to screen coordinates
			screen_position = grid_manager.grid_to_screen(grid_position)
			
			# Log the position for debugging
			print("POI at grid position: ", grid_position, " screen position: ", screen_position)
		else:
			# Fallback to using node's position if no grid manager
			screen_position = global_position
			print("Using fallback global position for POI: ", screen_position)
		
		# Play collection effect if enabled
		if play_effect_on_collect:
			_play_collection_effect(screen_position)
		
		# Play sound if enabled
		if play_sound_on_collect:
			_play_collection_sound()
			
		# Emit signals
		poi_collected.emit(poi_id, value, grid_position)
		
		# Emit global signal for UI and game state
		SignalManager.emit_signal("poi_collected", value, grid_position)
		
		# Immediately finish collection - don't defer, do it immediately
		_finish_collection()
		
		return value
	return 0

# Add a function to check if this POI was already collected
func is_collected() -> bool:
	return collected

# Update collection animation properties
func _update_collection_animation():
	# Calculate float height (object rises up as it's collected)
	float_height = max_float_height * animation_progress
	
	# Calculate scale effect (object expands slightly)
	collect_effect_scale = 1.0 - animation_progress
	
	# Update the visual representation
	register_with_grid()

# Play collection particle effect
func _play_collection_effect(screen_pos: Vector2):
	# Get the appropriate color for the effect based on shape type
	var effect_color = SHAPE_COLORS[shape_type]
	
	# Create and play the particle effect by loading the scene
	var effect_scene = load("res://core/objects/poi_collection_effect.tscn")
	if effect_scene:
		var effect = effect_scene.instantiate()
		
		# Get reference to player - particles should anchor to player position
		var grid_manager = _find_grid_manager()
		var player = null
		var player_pos = Vector2.ZERO
		
		if grid_manager and grid_manager.has_node("../Player"):
			player = grid_manager.get_node("../Player")
			# Anchor to player's position - use global_position for correct world coordinates
			player_pos = player.global_position
			print("Using player position for effect: ", player_pos)
			
			# Add effect to the same parent as the player for consistent positioning
			var player_parent = player.get_parent()
			if player_parent:
				player_parent.add_child(effect)
				effect.position = player_pos
				
				# Log critical position info for debugging
				print("Player global position: ", player.global_position)
				print("Effect local position: ", effect.position)
				print("Effect global position: ", effect.global_position)
				
				# Play the effect with the POI's color
				effect.play_effect(effect_color)
				
				print("Playing collection effect for POI: ", poi_id, " at player position")
			else:
				# Fallback if no player parent
				_add_effect_to_fallback(effect, screen_pos, effect_color)
		else:
			# Fallback if no player found
			_add_effect_to_fallback(effect, screen_pos, effect_color)
	else:
		print("ERROR: Could not load collection effect scene")

# Helper function for fallback effect placement
func _add_effect_to_fallback(effect, position, color):
	# Try to add to viewport or scene root
	var viewport = get_viewport()
	if viewport:
		viewport.add_child(effect)
		effect.global_position = position
		effect.play_effect(color)
		print("Fallback: Added effect to viewport at ", position)
	else:
		print("ERROR: Could not find parent for effect")

# Play collection sound
func _play_collection_sound():
	# In a full implementation, we would create an AudioStreamPlayer and play a sound
	# For now, we just print a placeholder message
	print("Playing collection sound for POI: ", poi_id)

# Finish the collection process
func _finish_collection():
	# Force the POI to become invisible immediately
	modulate = Color(0, 0, 0, 0)
	
	# Find grid manager
	var grid_manager = _find_grid_manager()
	if grid_manager:
		# Use forceful clear method if available
		if grid_manager.has_method("forcefully_clear_grid_object"):
			grid_manager.forcefully_clear_grid_object(grid_position)
		else:
			# Fallback to old method
			unregister_from_grid()
			
		# Also force visual update via visualizer if available
		if grid_manager.has_node("GridVisualizer"):
			var visualizer = grid_manager.get_node("GridVisualizer")
			visualizer._clear_position_visuals(grid_position)
	else:
		# Fallback if no grid manager found
		unregister_from_grid()
	
	# Force immediate removal from scene tree
	var parent = get_parent()
	if parent:
		parent.remove_child(self)
	
	# Queue this node for deletion
	queue_free()
	
	# Print collection event for debugging
	print("POI collected and removed: ", poi_id, " with value: ", value)

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
