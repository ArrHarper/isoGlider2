# player.gd - Player character that can move on the grid
class_name Player
extends CharacterBody2D

# ----- Signals -----
## Emitted when the player has completed movement to the target position
signal movement_completed

# ----- Properties -----
# Player properties
var move_speed: int = 200 # Movement speed in world units (affects only physics movement speed)
@export var movement_range: int = 3 # Maximum movement range in grid tiles
var score: int = 0
var grid_position: Vector2 = Vector2.ZERO # Current position in grid coordinates
var player_state: String = "IDLE" # Track player state for UI and visual indication

# Movement properties
var current_grid_pos: Vector2 = Vector2.ZERO # For compatibility with movement system
var should_move: bool = false # Flag for movement control
var target_position: Vector2 = Vector2.ZERO # Target position to move to
var movement_path: Array = [] # Array of screen positions for tile-by-tile movement
var current_path_index: int = 0 # Current index in the movement path

# Optional movement confirmation
@export var MOVEMENT_CONFIRM: bool = false # When true, requires confirmation before moving
@export var PLAYER_GRIDLOCKED: bool = true # When true, only allows movement along grid

# Visual properties for the player
var PLAYER_SHAPE = PackedVector2Array([
	Vector2(-16, 12), Vector2(16, 12), Vector2(8, 0),
	Vector2(16, -12), Vector2(-16, -12), Vector2(-8, 0)
])
const PLAYER_COLOR = Color(0.737, 0.929, 0.035, 1.0)

# Shape properties 
var shape_type: String = "player"
var horizontal_offset: float = 0.0
var vertical_offset: float = -10.0
var scale_x: float = 2
var scale_y: float = 1.35714

# For GridObject compatibility
var object_type: String = "player"
var highlight_color: Color = PLAYER_COLOR.darkened(0.2)
var highlight_border_color: Color = PLAYER_COLOR
var disable_fog: bool = true # Player should always be visible through fog

# Player ID for tracking multiple players (future support)
var player_id: int = 1

# ----- Core Methods -----
func _ready():
	# Initialize highlight color properties
	highlight_color.a = 0.4 # Make highlight more transparent
	
	# Initialize target position to current position
	target_position = position
	
	# Initialize current_grid_pos from grid_position
	current_grid_pos = grid_position
	
	# Log position for debugging
	var grid_manager = get_node_or_null("/root/Main/GridManager")
	if grid_manager:
		var chess_pos = grid_manager.grid_to_chess(grid_position) if grid_manager.has_method("grid_to_chess") else "unknown"
		print("Player initialized at grid position: %s (%s)" % [grid_position, chess_pos])
	
	# Set up signals
	_setup_signals()

# Physics-based movement implementation
func _physics_process(delta):
	if should_move:
		if movement_path.size() > 0:
			# Get the next position in the path
			var next_target = movement_path[current_path_index]
			
			# Calculate the direction to move
			var direction = position.direction_to(next_target)
			
			# Set velocity based on direction and speed
			velocity = direction * move_speed
			
			# Move using CharacterBody2D's built-in functions
			move_and_slide()
			
			# Check if we've reached the current target (with a small threshold)
			if position.distance_to(next_target) < 5:
				# Snap to the exact position
				position = next_target
				
				# Check if we've reached the end of the path
				if current_path_index == movement_path.size() - 1:
					_complete_movement()
				else:
					# Move to the next point in the path
					current_path_index += 1
					_log_intermediate_position()
		else:
			# Fallback to direct movement if no path is provided
			print("No path provided, moving directly towards target: ", target_position)
			
			# Calculate direction and set velocity
			var direction = position.direction_to(target_position)
			velocity = direction * move_speed
			
			# Move using CharacterBody2D's built-in functions
			move_and_slide()
			
			# Check if we've reached the target
			if position.distance_to(target_position) < 5:
				_complete_movement()

# ----- Movement Methods -----
# Set the movement path for tile-by-tile movement
func set_movement_path(path: Array):
	movement_path = path
	current_path_index = 0
	
	if movement_path.size() > 0:
		print("Movement path set with ", movement_path.size(), " points")
		# The final target position is the last point in the path
		target_position = movement_path[movement_path.size() - 1]
		
		# Set the should_move flag to start movement
		should_move = true
		
		# Set player state to MOVEMENT_EXECUTING
		set_player_state("MOVEMENT_EXECUTING")
	else:
		print("Empty movement path provided!")

# Complete the movement and update all required state
func _complete_movement():
	position = target_position
	velocity = Vector2.ZERO
	should_move = false
	
	print("Reached target position: ", position)
	
	# Update grid positions
	var grid_manager = get_node_or_null("/root/Main/GridManager")
	if grid_manager:
		# Get the old grid position before updating it
		var old_grid_pos = current_grid_pos
		
		# Update current position
		current_grid_pos = grid_manager.screen_to_grid(position)
		grid_position = current_grid_pos
		
		# Emit object removed signal for old position (if we've moved)
		if old_grid_pos != current_grid_pos:
			print("Player moved from ", old_grid_pos, " to ", current_grid_pos)
			SignalManager.emit_signal("grid_object_removed", "player", old_grid_pos)
			SignalManager.emit_signal("grid_object_added", "player", current_grid_pos)
			
			# Print updated positions in both grid and chess notation
			var chess_pos = grid_manager.grid_to_chess(current_grid_pos) if grid_manager.has_method("grid_to_chess") else "unknown"
			print("Updated player's position to: %s (%s)" % [current_grid_pos, chess_pos])
		
		# IMPORTANT: Check for POIs at the new position *after* player position is fully updated
		check_for_poi_at_position(current_grid_pos, grid_manager)
		
		# Check if player is on starting tile and update state accordingly 
		check_if_on_starting_tile()
	
	# Clear movement path
	movement_path.clear()
	current_path_index = 0
	
	# Set player state to MOVEMENT_COMPLETED
	set_player_state("MOVEMENT_COMPLETED")
	
	# Emit signal that movement is completed
	movement_completed.emit()

# Log intermediate position during path movement
func _log_intermediate_position():
	var grid_manager = get_node_or_null("/root/Main/GridManager")
	if grid_manager:
		var current_pos = grid_manager.screen_to_grid(position)
		
		# Only check for POI if position has changed
		if current_pos != current_grid_pos:
			# Update the current position FIRST
			var old_pos = current_grid_pos
			current_grid_pos = current_pos
			
			# DEBUG: Track position changes
			var chess_pos = grid_manager.grid_to_chess(current_pos) if grid_manager.has_method("grid_to_chess") else "unknown"
			print("Intermediate position: %s (%s)" % [current_pos, chess_pos])
			
			# Check for POIs at each intermediate position BEFORE announcing movement
			check_for_poi_at_position(current_grid_pos, grid_manager)
			
			# Now announce movement for grid tracking
			if old_pos != current_grid_pos:
				SignalManager.emit_signal("grid_object_removed", "player", old_pos)
				SignalManager.emit_signal("grid_object_added", "player", current_grid_pos)

# Check for POIs at the player's current position and collect them
func check_for_poi_at_position(grid_pos: Vector2, grid_manager):
	if not grid_manager:
		return
		
	# Get object at player's position using the grid manager
	var object_data = grid_manager.get_grid_object(grid_pos)
	
	# If there's no object, exit early
	if not object_data:
		return
		
	# Check if the object is a POI
	if object_data.type == "poi" and object_data.object:
		var poi_object = object_data.object
		
		# Make sure it's a valid POI class instance
		if poi_object is POI:
			# Check if it's not already collected
			if not poi_object.is_collected():
				# Collect the POI
				var reward = poi_object.collect()
				
				# Add reward to player's score
				score += reward
				
				print("Player collected POI at %s (%s) with value %d. New score: %d" %
					[grid_pos, grid_manager.grid_to_chess(grid_pos), reward, score])
					
				# Emit player-specific signal for collected POI
				SignalManager.emit_signal("player_collected_poi", poi_object.poi_id, reward)
				
				# Force the grid manager to update visuals at this position immediately
				if grid_manager.has_node("GridVisualizer"):
					var visualizer = grid_manager.get_node("GridVisualizer")
					visualizer.update_grid_position(grid_pos)
					visualizer._clear_position_visuals(grid_pos) # Ensure visuals are cleared

# Set player state and emit signal
func set_player_state(new_state: String):
	if player_state == new_state:
		return
		
	print("Player state changing from %s to %s" % [player_state, new_state])
	
	# Update state
	player_state = new_state
	
	# If state changed to MOVEMENT_COMPLETED, immediately check for POIs at current position
	if new_state == "MOVEMENT_COMPLETED":
		var grid_manager = get_node_or_null("/root/Main/GridManager")
		if grid_manager:
			# Ensure we check for and collect POIs immediately when movement completes
			check_for_poi_at_position(current_grid_pos, grid_manager)
	
	# Check if on starting tile for special state handling
	var is_on_starting_tile = check_if_on_starting_tile()
	
	# Emit signal for state change
	SignalManager.emit_signal("player_state_changed", player_id, player_state, is_on_starting_tile)

# Check if player is on starting tile and return result
func check_if_on_starting_tile() -> bool:
	var grid_manager = get_node_or_null("/root/Main/GridManager")
	if grid_manager and current_grid_pos != Vector2.ZERO:
		var starting_tile_pos = Vector2.ZERO
		
		# Get starting tile position from the manager or use the GridVisualizer
		if grid_manager.has_node("GridVisualizer"):
			var visualizer = grid_manager.get_node("GridVisualizer")
			if visualizer.starting_tile_position != Vector2(-1, -1):
				starting_tile_pos = visualizer.starting_tile_position
		
		# Check if player is on starting tile
		var is_on_starting_tile = (current_grid_pos == starting_tile_pos)
		
		# If on starting tile and in immobile state, ensure highlight is updated
		if is_on_starting_tile and player_state == "IMMOBILE":
			SignalManager.emit_signal("player_state_changed", player_id, player_state, true)
		
		return is_on_starting_tile
	
	return false

# Set player to IMMOBILE state
func set_immobile(is_immobile: bool = true):
	if is_immobile:
		set_player_state("IMMOBILE")
	else:
		set_player_state("IDLE")

# ----- Signal Methods -----
# Centralized function to manage all signal connections
func _setup_signals():
	# Connect to GridManager signals
	var grid_manager = get_node_or_null("/root/Main/GridManager")
	if grid_manager:
		# Connect to movement range signal if it exists
		if grid_manager.has_signal("player_movement_range") and not grid_manager.is_connected("player_movement_range", _on_player_movement_range):
			grid_manager.connect("player_movement_range", _on_player_movement_range)
	
	# Connect our movement_completed signal to the state machine if needed
	if not is_connected("movement_completed", _on_movement_completed):
		movement_completed.connect(_on_movement_completed)

# Handle movement range signal from grid
func _on_player_movement_range(range_value: int):
	movement_range = range_value
	print("Player movement range set to: ", movement_range)

# Handler for movement_completed signal
func _on_movement_completed():
	print("Player: Movement completed at grid position: ", grid_position)
	
	# Find the GridManager and its movement state machine
	var grid_manager = get_node_or_null("/root/Main/GridManager")
	if grid_manager and grid_manager.has_method("get_movement_state_machine"):
		var state_machine = grid_manager.get_movement_state_machine()
		if state_machine:
			# Transition to MOVEMENT_COMPLETED state
			print("Player: Transitioning to MOVEMENT_COMPLETED state")
			state_machine.transition_to(state_machine.MovementState.MOVEMENT_COMPLETED)
		else:
			print("ERROR: Movement state machine not found")
	else:
		print("ERROR: GridManager not found or missing get_movement_state_machine method")

# ----- Visual Methods -----
# Set the scale factor for both dimensions
func set_shape_scale(x_scale: float, y_scale: float) -> void:
	scale_x = x_scale
	scale_y = y_scale
	
	# Update the polygon nodes
	$Polygon2D.scale = Vector2(x_scale, y_scale)
	$CollisionPolygon2D.scale = Vector2(x_scale, y_scale)
		
# Uniformly scale both dimensions
func set_uniform_shape_scale(scale: float) -> void:
	set_shape_scale(scale, scale)

# Get visual properties for the grid system
func get_visual_properties() -> Dictionary:
	var props = {
		"position": grid_position,
		"type": object_type,
		"highlight_color": highlight_color,
		"highlight_border_color": highlight_border_color,
		"disable_fog": disable_fog
	}
	
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

# Get the current player state
func get_player_state() -> String:
	return player_state
