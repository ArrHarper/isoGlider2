# player.gd - Player character that can move on the grid
class_name Player
extends GridObject

# Player properties
var move_speed: int = 1 # Grid cells per move
var score: int = 0
var inventory = [] # For collected items or power-ups

# Visual properties for the player
var PLAYER_SHAPE = PackedVector2Array([
	Vector2(-16, 12), Vector2(16, 12), Vector2(8, 0),
	Vector2(16, -12), Vector2(-16, -12), Vector2(-8, 0)
])
const PLAYER_COLOR = Color(0.737, 0.929, 0.035, 1.0)

# Shape properties matching POI structure
var shape_type: String = "player"
var horizontal_offset: float = 0.0
var vertical_offset: float = -10.0
var scale_x: float = 2
var scale_y: float = 1.35714

# Movement direction constants for clearer code
enum Direction {NORTH, EAST, SOUTH, WEST}

func _init():
	object_type = "player"
	
	# Set visual properties
	highlight_color = PLAYER_COLOR.darkened(0.2)
	highlight_color.a = 0.4 # Make highlight more transparent
	
	highlight_border_color = PLAYER_COLOR
	
	# Player should always be visible through fog
	disable_fog = true

func _ready():
	super._ready()
	
	# Connect input handlers if needed
	# set_process_input(true) - Enable this if you want direct input

# Set the scale factor for both dimensions
func set_shape_scale(x_scale: float, y_scale: float) -> void:
	scale_x = x_scale
	scale_y = y_scale
		
# Uniformly scale both dimensions
func set_uniform_shape_scale(scale: float) -> void:
	set_shape_scale(scale, scale)

# Override to add player-specific visual properties
func get_visual_properties() -> Dictionary:
	var props = super.get_visual_properties()
	
	# Add shape information
	props["shape"] = shape_type
	props["shape_points"] = PLAYER_SHAPE
	props["shape_color"] = PLAYER_COLOR
	props["horizontal_offset"] = horizontal_offset
	props["vertical_offset"] = vertical_offset
	props["scale_x"] = scale_x
	props["scale_y"] = scale_y
	
	return props

# Handle player death
func die() -> void:
	print("Player died!")
	# Implement game over logic here
