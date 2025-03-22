extends RefCounted

# Define movement states
enum MovementState {IDLE, HOVER, PATH_PLANNED, MOVEMENT_EXECUTING, MOVEMENT_COMPLETED, IMMOBILE}

# Current state
var current_state = MovementState.IDLE

# Reference to grid owner
var grid_manager

# Shared data for all states
var current_path = []
var start_position = Vector2.ZERO
var target_position = Vector2.ZERO
var hover_position = Vector2.ZERO
var was_path_found = false
var has_moved_from_start = false # Track if player has moved away from the starting position
var initial_start_position = Vector2.ZERO # Store the initial start position

func _init(grid_manager_node):
	grid_manager = grid_manager_node
	if grid_manager.player_instance:
		start_position = grid_manager.player_instance.current_grid_pos
		initial_start_position = start_position # Vector2 is already passed by value

# Main state transition function
func transition_to(new_state, params = {}):
	# Only log if state is actually changing
	if new_state != current_state:
		print("Movement state: ", _state_to_string(current_state), " -> ", _state_to_string(new_state))
	
	# If we're in IMMOBILE state, only allow transitions to IDLE
	if current_state == MovementState.IMMOBILE and new_state != MovementState.IDLE:
		print("Blocked state transition: Player is IMMOBILE")
		return false
	
	# Always update start position to match player's current position
	if grid_manager.player_instance:
		start_position = grid_manager.player_instance.current_grid_pos
		# Print start position in both grid and chess notation for debugging
		var chess_start = grid_manager.grid_to_chess(start_position)
		print("Player at position: %s (%s), move_speed: %d, movement_range: %d" %
			[start_position, chess_start, grid_manager.player_instance.move_speed,
			grid_manager.player_instance.movement_range])
	
	# Exit current state
	match current_state:
		MovementState.HOVER:
			grid_manager.clear_movement_range()
		MovementState.PATH_PLANNED:
			grid_manager.clear_target_highlight()
		MovementState.MOVEMENT_EXECUTING:
			pass # Nothing special on exit
		MovementState.IMMOBILE:
			grid_manager.queue_redraw() # Force immediate redraw when exiting immobile state

	# Update state
	current_state = new_state
	
	# Update player's state if player instance exists
	if grid_manager.player_instance and grid_manager.player_instance.has_method("set_player_state"):
		# Convert MovementState enum to string
		var state_string = _state_to_string(new_state)
		grid_manager.player_instance.set_player_state(state_string)

	# Enter new state
	match new_state:
		MovementState.IDLE:
			current_path = []
			was_path_found = false

		MovementState.HOVER:
			hover_position = params.get("hover_pos", Vector2(-1, -1))
			
			# Only calculate path for valid hover positions
			if hover_position != Vector2(-1, -1):
				var max_distance = grid_manager.player_instance.movement_range
				
				# Print hover position in both grid and chess notation for debugging
				var chess_hover = grid_manager.grid_to_chess(hover_position)
				print("Mouse hover: %s (%s), max_distance: %d" % [hover_position, chess_hover, max_distance])
				
				# First check if the position is reachable at all
				if grid_manager.is_position_reachable(start_position, hover_position, max_distance):
					# Calculate path
					current_path = grid_manager.find_gridlocked_path(
						start_position,
						hover_position,
						max_distance
					)
					was_path_found = current_path.size() > 0
					
					# Debug the calculated path
					if was_path_found:
						var path_chess = []
						for pos in current_path:
							path_chess.append(grid_manager.grid_to_chess(pos))
						print("Valid path found: %s (%s)" % [current_path, path_chess])
					else:
						print("No valid path found to %s (%s)" % [hover_position, chess_hover])
					
					# Visualization
					grid_manager.update_path_visualization(current_path)
				else:
					# Clear any existing path
					current_path = []
					was_path_found = false
					grid_manager.clear_movement_range()
					print("Position %s (%s) is not reachable within distance %d" %
						[hover_position, chess_hover, max_distance])

		MovementState.PATH_PLANNED:
			target_position = params.get("target_pos", Vector2(-1, -1))
			
			# Use exactly the same path that was calculated during hover
			# or recalculate if we're jumping directly to this state
			if current_path.is_empty() or current_path[-1] != target_position:
				var max_distance = grid_manager.player_instance.movement_range
				
				# Print target position in both grid and chess notation for debugging
				var chess_target = grid_manager.grid_to_chess(target_position)
				print("Target: %s (%s), max_distance: %d" % [target_position, chess_target, max_distance])
				
				# First check if the position is reachable at all
				if grid_manager.is_position_reachable(start_position, target_position, max_distance):
					# Calculate path
					current_path = grid_manager.find_gridlocked_path(
						start_position,
						target_position,
						max_distance
					)
					was_path_found = current_path.size() > 0
					
					# Debug the calculated path
					if was_path_found:
						var path_chess = []
						for pos in current_path:
							path_chess.append(grid_manager.grid_to_chess(pos))
						print("Valid path found: %s (%s)" % [current_path, path_chess])
					else:
						print("No valid path found to %s (%s)" % [target_position, chess_target])
				else:
					# Clear any existing path
					current_path = []
					was_path_found = false
					print("Target position %s (%s) is not reachable within distance %d" %
						[target_position, chess_target, max_distance])

			if was_path_found:
				# Only visualize the path and show target highlight
				grid_manager.update_path_visualization(current_path)
				grid_manager.show_target_highlight(target_position)

				# If confirmation is required, show dialog
				if grid_manager.player_instance.MOVEMENT_CONFIRM and grid_manager.has_node("/root/Main/UI"):
					var main_ui = grid_manager.get_node("/root/Main/UI")
					main_ui.request_move_confirmation(
						start_position,
						target_position,
						grid_manager.get_grid_name(target_position)
					)
				else:
					# No confirmation needed, move directly to execution
					transition_to(MovementState.MOVEMENT_EXECUTING)
			else:
				# If no valid path, go back to IDLE
				transition_to(MovementState.IDLE)

		MovementState.MOVEMENT_EXECUTING:
			if not was_path_found or current_path.is_empty():
				transition_to(MovementState.IDLE)
				return
				
			# Start actual movement using the exact same path
			var screen_path = []
			for point in current_path:
				screen_path.append(grid_manager.grid_to_screen(point))

			# Direct path setting on player (CharacterBody2D implementation)
			grid_manager.player_instance.set_movement_path(screen_path)
			grid_manager.player_is_moving = true
			
			# Check if this is moving away from the initial start position
			if not has_moved_from_start and target_position != initial_start_position:
				has_moved_from_start = true
				print("Player has moved away from starting position")

		MovementState.MOVEMENT_COMPLETED:
			# Update player's grid position properties
			start_position = target_position
			grid_manager.player_instance.current_grid_pos = target_position
			grid_manager.player_instance.grid_position = target_position
			
			# Update the grid objects registry
			_update_player_grid_position(start_position, target_position)
			
			# Reset movement flag
			grid_manager.player_is_moving = false

			# Clear visualization
			grid_manager.clear_movement_range()
			grid_manager.clear_target_highlight()

			# Update fog of war or other grid-related signals
			SignalManager.emit_signal("player_moved", target_position)

			# Consume a turn
			if grid_manager.has_node("/root/Main/UI"):
				var main_ui = grid_manager.get_node("/root/Main/UI")
				main_ui.consume_turn(target_position)

			# Reset path data
			current_path = []
			was_path_found = false
			
			# Automatically transition back to IDLE state
			print("Automatically transitioning from MOVEMENT_COMPLETED to IDLE")
			call_deferred("transition_to", MovementState.IDLE)

		MovementState.IMMOBILE:
			# Clear any existing path or highlights
			current_path = []
			was_path_found = false
			grid_manager.clear_movement_range()
			grid_manager.clear_target_highlight()

	# Return true if transition was successful
	return true

# Helper method to update the player's position in the grid objects registry
func _update_player_grid_position(old_position, new_position):
	if old_position == new_position:
		return
		
	# Update the grid_objects dictionary without removing/recreating the player
	if grid_manager.grid_objects.has(old_position):
		var player_data = grid_manager.grid_objects[old_position]
		grid_manager.grid_objects.erase(old_position)
		grid_manager.grid_objects[new_position] = player_data
		
		# Update grid visualizer for both positions if available
		if grid_manager.grid_visualizer:
			grid_manager.grid_visualizer.update_grid_position(old_position)
			grid_manager.grid_visualizer.update_grid_position(new_position)
		
		print("Updated grid representation from %s to %s" % [old_position, new_position])
	else:
		print("Warning: Old player position not found in grid_objects at %s" % [old_position])
		
		# Fallback: Re-register player at new position
		if grid_manager.has_method("add_grid_object"):
			var success = grid_manager.add_grid_object(grid_manager.player_instance, new_position, "player")
			if success:
				print("Re-registered player at new position: %s" % [new_position])

# Helper function to get state name for debugging
func _state_to_string(state):
	match state:
		MovementState.IDLE: return "IDLE"
		MovementState.HOVER: return "HOVER"
		MovementState.PATH_PLANNED: return "PATH_PLANNED"
		MovementState.MOVEMENT_EXECUTING: return "MOVEMENT_EXECUTING"
		MovementState.MOVEMENT_COMPLETED: return "MOVEMENT_COMPLETED"
		MovementState.IMMOBILE: return "IMMOBILE"
		_: return "UNKNOWN"

# Handle movement confirmation response
func handle_movement_confirmation(confirmed):
	if current_state == MovementState.PATH_PLANNED:
		if confirmed:
			transition_to(MovementState.MOVEMENT_EXECUTING)
		else:
			transition_to(MovementState.IDLE)

# Reset player movement state for a new round/game
func reset():
	current_state = MovementState.IDLE
	current_path = []
	was_path_found = false
	has_moved_from_start = false
	
	# Update initial start position from grid if possible
	if grid_manager and grid_manager.player_instance:
		initial_start_position = grid_manager.player_instance.current_grid_pos
		start_position = initial_start_position
		
		# Reset player state to IDLE
		if grid_manager.player_instance.has_method("set_player_state"):
			grid_manager.player_instance.set_player_state("IDLE")

# Setter method to transition to IMMOBILE state
func set_immobile(is_immobile: bool = true):
	if is_immobile:
		transition_to(MovementState.IMMOBILE)
	else:
		transition_to(MovementState.IDLE)
