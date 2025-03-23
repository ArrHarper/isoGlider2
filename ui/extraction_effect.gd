extends Node2D

# Animation parameters
@export var rise_speed: float = 40.0
@export var max_rise_height: float = 80.0
@export var pause_at_top: float = 0.5
@export var fall_speed: float = 30.0

# Animation state
var original_positions = {}
var current_height = 0.0
var pause_timer = 0.0
var animation_state = "rising" # "rising", "pausing", "falling"

# Called when the node enters the scene tree for the first time
func _ready():
	# Store original positions of all Line2D nodes
	store_original_positions()

# Store the original positions of all Line2D nodes
func store_original_positions():
	# Use the correct node names
	if has_node("gridAnim1") and has_node("gridAnim2"):
		for layer_node in [get_node("gridAnim1"), get_node("gridAnim2")]:
			for line in layer_node.get_children():
				if line is Line2D:
					original_positions[line] = line.global_position
	else:
		print("Warning: gridAnim1 or gridAnim2 not found in scene")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if original_positions.is_empty():
		return
		
	match animation_state:
		"rising":
			current_height += rise_speed * delta
			if current_height >= max_rise_height:
				current_height = max_rise_height
				animation_state = "pausing"
				pause_timer = pause_at_top
			update_positions(current_height)
			
		"pausing":
			pause_timer -= delta
			if pause_timer <= 0:
				animation_state = "falling"
			
		"falling":
			current_height -= fall_speed * delta
			if current_height <= 0:
				current_height = 0
				animation_state = "rising"
			update_positions(current_height)

# Update the positions of all Line2D nodes based on current height
func update_positions(height):
	# Use the correct node names
	if not has_node("gridAnim1") or not has_node("gridAnim2"):
		return
		
	# Layer 1 animation (gridAnim1)
	var laye
