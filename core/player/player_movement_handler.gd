extends Node

# Reference to player movement state machine
var movement_state_machine = null
var player_instance = null
var grid_manager = null
var grid_visualizer = null
var player_is_moving = false
var path_tiles = []
var hover_grid_pos = Vector2(-1, -1)
var target_grid_pos = Vector2(-1, -1)

# Initialize with a reference to the grid manager
func _init(manager):
	grid_manager = manager

# Called when the node enters the scene tree for the first time
func _ready():
	grid_visualizer = grid_manager.grid_visualizer

# Movement and pathfinding functions

# Initialize the movement state machine
func initialize_movement_state_machine():
	if not movement_state_machine:
		movement_state_machine = load("res://core/player/player_movement_state_machine.gd").new(grid_manager)
		print("Movement state machine initialized")
	return movement_state_machine

# Get reference to movement state machine (creating if needed)
func get_movement_state_machine():
	if not movement_state_machine:
		initialize_movement_state_machine()
	return movement_state_machine

# Find a path that follows grid rules (only allows X/Y movement, not diagonal)
func find_gridlocked_path(start_pos: Vector2, end_pos: Vector2, max_distance: int) -> Array:
	# Ensure we're working with integer coordinates
	start_pos = Vector2(int(start_pos.x), int(start_pos.y))
	end_pos = Vector2(int(end_pos.x), int(end_pos.y))
	
	# If start and end are the same, return empty path
	if start_pos == end_pos:
		return []
	
	# Check if target tile is passable first
	if not is_tile_passable(end_pos):
		print("Target position is not passable: ", end_pos, " (", grid_manager.grid_to_chess(end_pos), ")")
		return []
		
	# Calculate Manhattan distance
	var manhattan_distance = abs(end_pos.x - start_pos.x) + abs(end_pos.y - start_pos.y)
	
	# Check if destination is beyond movement range
	if manhattan_distance > max_distance:
		print("Path exceeds max distance: ", manhattan_distance, " > ", max_distance)
		return []
	
	# Debug output
	var start_chess = grid_manager.grid_to_chess(start_pos)
	var end_chess = grid_manager.grid_to_chess(end_pos)
	print("Finding path from %s(%s) to %s(%s), max distance: %d" % [str(start_pos), start_chess, str(end_pos), end_chess, max_distance])
	
	# Simple path along X then Y
	var path = []
	var current = start_pos
	
	# First move along X axis
	while current.x != end_pos.x:
		var step = 1 if end_pos.x > current.x else -1
		current.x += step
		
		# Create the potential new position
		var next_pos = Vector2(current.x, current.y)
		
		# Check if position is valid (not blocked)
		if grid_manager.is_valid_grid_position(next_pos) and is_tile_passable(next_pos):
			path.append(next_pos)
			print("Added X step: %s (%s)" % [str(next_pos), grid_manager.grid_to_chess(next_pos)])
		else:
			# Try Y-first approach instead
			print("X-first approach blocked at %s (%s), trying Y-first" % [str(next_pos), grid_manager.grid_to_chess(next_pos)])
			path = []
			current = start_pos
			break
	
	# If X-first approach failed or wasn't completed, try Y-first
	if path.size() == 0 or current.y != end_pos.y:
		# If we already have a partial X path, continue with Y movement
		if path.size() > 0:
			# Continue Y movement from current X position
			while current.y != end_pos.y:
				var step = 1 if end_pos.y > current.y else -1
				current.y += step
				
				# Create the potential new position
				var next_pos = Vector2(current.x, current.y)
				
				# Check if position is valid (not blocked)
				if grid_manager.is_valid_grid_position(next_pos) and is_tile_passable(next_pos):
					path.append(next_pos)
					print("Added Y step (after X): %s (%s)" % [str(next_pos), grid_manager.grid_to_chess(next_pos)])
				else:
					# Path was valid until now but got blocked
					print("Y movement blocked at %s (%s) after X movement, path failed" % [str(next_pos), grid_manager.grid_to_chess(next_pos)])
					return []
		else:
			# Try Y-first approach from scratch
			current = start_pos
			
			# Move along Y axis first
			while current.y != end_pos.y:
				var step = 1 if end_pos.y > current.y else -1
				current.y += step
				
				# Create the potential new position
				var next_pos = Vector2(current.x, current.y)
				
				# Check if position is valid (not blocked)
				if grid_manager.is_valid_grid_position(next_pos) and is_tile_passable(next_pos):
					path.append(next_pos)
					print("Added Y step: %s (%s)" % [str(next_pos), grid_manager.grid_to_chess(next_pos)])
				else:
					# Both approaches failed, no valid path
					print("Y-first approach blocked at %s (%s), no valid path" % [str(next_pos), grid_manager.grid_to_chess(next_pos)])
					return []
			
			# Then move along X axis
			while current.x != end_pos.x:
				var step = 1 if end_pos.x > current.x else -1
				current.x += step
				
				# Create the potential new position
				var next_pos = Vector2(current.x, current.y)
				
				# Check if position is valid (not blocked)
				if grid_manager.is_valid_grid_position(next_pos) and is_tile_passable(next_pos):
					path.append(next_pos)
					print("Added X step (after Y): %s (%s)" % [str(next_pos), grid_manager.grid_to_chess(next_pos)])
				else:
					# No valid path
					print("X movement blocked at %s (%s) after Y movement, path failed" % [str(next_pos), grid_manager.grid_to_chess(next_pos)])
					return []
	
	# Ensure the path doesn't exceed max distance
	if path.size() > max_distance:
		print("Path found but exceeds max distance, trimming to %d steps" % max_distance)
		path = path.slice(0, max_distance)
	
	print("Final path: %s" % str(path))
	return path

# Check if a tile can be moved to
func is_tile_passable(grid_pos: Vector2) -> bool:
	# Get object at position
	var object_data = grid_manager.get_grid_object(grid_pos)
	
	# If no object, tile is passable
	if not object_data:
		return true
	
	# Check if object is in impassable_tiles list
	if grid_manager.impassable_tiles.has(grid_pos):
		return false
		
	# If it's a terrain object, check its passable property
	if object_data.type == "terrain" and object_data.object and object_data.object.has_method("get_is_passable"):
		return object_data.object.get_is_passable()
	
	# Default to passable for other objects (like POIs)
	return true

# Update path visualization on the grid
func update_path_visualization(path: Array) -> void:
	# Clear any existing path highlights
	clear_movement_range()
	
	# Skip if path is empty
	if path.size() == 0:
		return
		
	# Directly visualize the path if we have a visualizer reference
	if grid_visualizer:
		grid_visualizer.visualize_path(path)
	# Otherwise emit signal through grid manager
	elif grid_manager:
		grid_manager.update_path_visualization(path)

# Clear movement range visualization
func clear_movement_range() -> void:
	if grid_visualizer:
		for i in range(50): # Clear up to 50 path tiles (arbitrary limit)
			var highlight_id = "path_" + str(i)
			grid_visualizer.remove_highlight(highlight_id)
	
	# Clear stored path
	path_tiles = []

# Show target highlight for selected destination
func show_target_highlight(grid_pos: Vector2) -> void:
	if grid_visualizer:
		var highlight_id = "target_highlight"
		var highlight_color = Color(0.9, 0.2, 0.2, 0.6)
		grid_visualizer.add_highlight(grid_pos, highlight_color, Color.RED, highlight_id)

# Clear target highlight
func clear_target_highlight() -> void:
	if grid_visualizer:
		grid_visualizer.remove_highlight("target_highlight")

# Set up signal connections for player movement
func connect_movement_signals():
	if player_instance:
		if not player_instance.is_connected("movement_completed", Callable(self, "_on_player_movement_completed")):
			player_instance.connect("movement_completed", Callable(self, "_on_player_movement_completed"))

# Handler for player movement completed
func _on_player_movement_completed():
	# Get movement state machine
	var state_machine = get_movement_state_machine()
	if state_machine:
		# Transition to MOVEMENT_COMPLETED state
		state_machine.transition_to(state_machine.MovementState.MOVEMENT_COMPLETED)

# Check if a target position is reachable within the movement range
func is_position_reachable(start_pos: Vector2, target_pos: Vector2, max_distance: int) -> bool:
	# Calculate Manhattan distance
	var manhattan_distance = abs(target_pos.x - start_pos.x) + abs(target_pos.y - start_pos.y)
	
	# Check if distance is within range
	if manhattan_distance > max_distance:
		var start_chess = grid_manager.grid_to_chess(start_pos)
		var target_chess = grid_manager.grid_to_chess(target_pos)
		print("Position %s (%s) is too far from %s (%s): %d > %d" %
			[str(target_pos), target_chess, str(start_pos), start_chess, manhattan_distance, max_distance])
		return false
	
	# Check if there's a valid path
	var path = find_gridlocked_path(start_pos, target_pos, max_distance)
	var has_path = path.size() > 0
	
	# Debug output
	if not has_path:
		var start_chess = grid_manager.grid_to_chess(start_pos)
		var target_chess = grid_manager.grid_to_chess(target_pos)
		print("No valid path from %s (%s) to %s (%s)" %
			[str(start_pos), start_chess, str(target_pos), target_chess])
	
	return has_path

# Player handling functions

# Create and add player to starting position
func add_player_to_grid() -> Node:
	# First, clean up any existing player instance to prevent duplicates
	if player_instance and is_instance_valid(player_instance):
		print("Removing existing player instance")
		# Find current grid position of player
		var old_pos = player_instance.grid_position
		# Remove from grid tracking
		if grid_manager.grid_objects.has(old_pos):
			grid_manager.grid_objects.erase(old_pos)
			# Update grid visualizer for the old position
			if grid_visualizer:
				grid_visualizer.update_grid_position(old_pos)
		# Free the instance
		player_instance.queue_free()
		player_instance = null
	
	# Use our new chained method to get valid grid position from chess notation
	var start_pos = grid_manager.get_valid_grid_position(grid_manager.player_starting_tile)
	
	if start_pos == Vector2(-1, -1):
		push_error("Invalid player starting position: " + grid_manager.player_starting_tile)
		# Fallback to a valid position
		start_pos = Vector2(0, 0)
		grid_manager.player_starting_tile = grid_manager.grid_to_chess(start_pos)
	
	# Make sure grid_visualizer is properly set up before emitting the signal
	if grid_visualizer == null:
		print("WARNING: GridVisualizer not found when adding player, attempting to find it...")
		grid_visualizer = grid_manager.get_node_or_null("GridVisualizer")
		if grid_visualizer:
			print("GridVisualizer found!")
		else:
			print("ERROR: GridVisualizer still not found!")
	
	# Set the starting tile using the dedicated method
	grid_manager.set_starting_tile(start_pos)
	
	# Instantiate player scene instead of creating a new class instance
	var player_scene = load("res://core/objects/player.tscn")
	var player = player_scene.instantiate()
	grid_manager.add_child(player)
	
	# Set position and register
	player.grid_position = start_pos
	player.position = grid_manager.grid_to_screen(start_pos)
	
	# Register with the grid system
	grid_manager.add_grid_object(player, start_pos)
	
	# Store reference for easy access
	player_instance = player
	
	# Emit signal that player was added
	grid_manager.emit_signal("player_spawned", player, start_pos)
	
	print("Player added at " + grid_manager.player_starting_tile + " (Grid: " + str(start_pos) + ")")
	
	# Initialize the movement state machine
	initialize_movement_state_machine()
	
	# Connect movement signals
	connect_movement_signals()
	
	return player

# Helper function to check if the starting tile highlight is properly applied
func _check_starting_tile_highlight(start_pos: Vector2) -> void:
	# Wait a frame to ensure all deferred calls are processed
	await grid_manager.get_tree().process_frame
	
	print("GridManager: Checking if starting tile highlight was applied at: ", start_pos)
	
	if grid_visualizer and grid_visualizer.active_highlights.has(grid_visualizer.starting_tile_highlight_id):
		print("GridManager: Starting tile highlight is active!")
	else:
		print("GridManager: Starting tile highlight is NOT active, forcing it...")
		if grid_visualizer and grid_visualizer.has_method("force_set_starting_tile"):
			grid_visualizer.force_set_starting_tile(start_pos)
		else:
			print("GridManager: Can't force starting tile highlight - visualizer not found or missing method")

# Set the player to immobilized state
func set_player_immobilized(immobilized: bool = true) -> void:
	var state_machine = get_movement_state_machine()
	if state_machine and state_machine.has_method("set_immobile"):
		state_machine.set_immobile(immobilized)
		print("Player immobilized state set to: %s" % immobilized)
	else:
		print("Failed to set player immobilized state: State machine not found or missing method")

# Get the current player state
func get_player_state() -> String:
	if player_instance and player_instance.has_method("get_player_state"):
		return player_instance.get_player_state()
	
	# If player has a state property, return it
	if player_instance and player_instance.get("player_state"):
		return player_instance.player_state
	
	# Otherwise get it from the state machine
	var state_machine = get_movement_state_machine()
	if state_machine:
		return state_machine._state_to_string(state_machine.current_state)
	
	return "UNKNOWN"

# Check if player is on the starting tile
func is_player_on_starting_tile() -> bool:
	if player_instance and player_instance.has_method("check_if_on_starting_tile"):
		return player_instance.check_if_on_starting_tile()
	
	# Otherwise calculate manually
	if player_instance:
		var start_pos = grid_manager.get_valid_grid_position(grid_manager.player_starting_tile)
		return player_instance.grid_position == start_pos
	
	return false

# Signal handlers for grid events
func on_grid_mouse_hover(grid_pos: Vector2):
	# Update hover tracking
	hover_grid_pos = grid_pos
	
	print("PlayerMovementHandler: Processing grid_mouse_hover at ", grid_pos)
	
	# If player is moving, don't process hover
	if player_is_moving:
		print("PlayerMovementHandler: Ignoring hover because player is currently moving")
		return
	
	# Get movement state machine
	var state_machine = get_movement_state_machine()
	if state_machine:
		# Get current state as string for debugging
		var current_state_str = state_machine._state_to_string(state_machine.current_state)
		
		# Transition to HOVER state if we're in IDLE or already in HOVER
		if state_machine.current_state == state_machine.MovementState.IDLE or \
		   state_machine.current_state == state_machine.MovementState.HOVER:
			if state_machine.current_state != state_machine.MovementState.HOVER:
				print("PlayerMovementHandler: Transitioning to HOVER state from ", current_state_str)
			var success = state_machine.transition_to(state_machine.MovementState.HOVER, {"hover_pos": grid_pos})
			if not success:
				print("PlayerMovementHandler: Failed to transition to HOVER state")
		else:
			print("PlayerMovementHandler: Not transitioning to HOVER state from current state: ", current_state_str)
	else:
		print("PlayerMovementHandler: Error - Movement state machine not found!")

func on_grid_mouse_exit():
	# Clear hover tracking
	hover_grid_pos = Vector2(-1, -1)
	
	# Get movement state machine
	var state_machine = get_movement_state_machine()
	if state_machine:
		# If we're in HOVER state, go back to IDLE
		if state_machine.current_state == state_machine.MovementState.HOVER:
			state_machine.transition_to(state_machine.MovementState.IDLE)

func on_grid_tile_clicked(grid_pos: Vector2):
	# Update target tracking
	target_grid_pos = grid_pos
	
	print("PlayerMovementHandler: Processing grid_tile_clicked at ", grid_pos)
	
	# If player is moving, don't process click
	if player_is_moving:
		print("PlayerMovementHandler: Ignoring click because player is currently moving")
		return
	
	# Check if we have a player instance
	if not player_instance:
		print("PlayerMovementHandler: Error - Player instance not found!")
		return
	
	# Get movement state machine
	var state_machine = get_movement_state_machine()
	if state_machine:
		# Get current state as string for debugging
		var current_state_str = state_machine._state_to_string(state_machine.current_state)
		
		print("PlayerMovementHandler: Current movement state before click: ", current_state_str)
		
		# Only process click if we're in HOVER or IDLE state
		if state_machine.current_state == state_machine.MovementState.HOVER or \
		   state_machine.current_state == state_machine.MovementState.IDLE:
			print("PlayerMovementHandler: Transitioning to PATH_PLANNED state")
			var success = state_machine.transition_to(state_machine.MovementState.PATH_PLANNED, {"target_pos": grid_pos})
			print("PlayerMovementHandler: Transition success: ", success)
		else:
			print("PlayerMovementHandler: Cannot transition to PATH_PLANNED from current state: ", current_state_str)
	else:
		print("PlayerMovementHandler: Error - Movement state machine not found!")

# Set up connection to grid manager signals
func connect_grid_signals():
	if grid_manager:
		if not grid_manager.is_connected("grid_mouse_hover", Callable(self, "on_grid_mouse_hover")):
			grid_manager.connect("grid_mouse_hover", Callable(self, "on_grid_mouse_hover"))
		if not grid_manager.is_connected("grid_mouse_exit", Callable(self, "on_grid_mouse_exit")):
			grid_manager.connect("grid_mouse_exit", Callable(self, "on_grid_mouse_exit"))
		if not grid_manager.is_connected("grid_tile_clicked", Callable(self, "on_grid_tile_clicked")):
			grid_manager.connect("grid_tile_clicked", Callable(self, "on_grid_tile_clicked"))
