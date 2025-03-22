# Signal Manager Autoload - defines all signals grouped by object type
extends Node

# Player-related signals
signal player_moved(grid_position)
signal player_movement_started(path)
signal player_movement_completed()
signal player_collected_poi(poi_id, reward)
signal player_state_changed(player_id, state, is_on_starting_tile)

# Grid Signals
signal grid_initialized()

signal grid_tile_clicked(grid_pos)
signal grid_object_added(object_type, grid_pos)
signal grid_object_removed(object_type, grid_pos)
signal grid_object_updated(object_type, grid_pos)
signal poi_generated(positions)
signal player_object_added(grid_pos)
signal starting_tile_added(grid_pos)

signal grid_hovered(grid_position)
signal grid_hover_exited()


# Game flow signals
signal turn_started(turn_number)
signal turn_ended(turns_remaining)
signal turn_used()
signal timer_updated(time_remaining)
signal countdown_changed(seconds)
signal game_state_changed(old_state, new_state)
signal round_started(round_number)
signal round_completed(success, score)
signal game_over(victory, score, round)
signal game_reset()

# Mode-related signals
signal mode_changed(old_mode, new_mode)
signal mode_initialized()

# Map-related signals
signal poi_collected(reward, position)
signal fog_revealed(positions)

# UI Signals
signal ui_state_changed(old_state, new_state)
signal high_score_recorded(position, score)


# Dictionary to track registered listeners for debugging
var _registered_listeners = {}

# Initialize
func _ready():
	# Any setup needed
	pass

# Helper method to connect a signal with error checking
func connect_signal(signal_name: String, target: Object, method: String,
				   binds: Array = [], flags: int = 0) -> int:
	if not has_signal(signal_name):
		push_error("SignalManager: Trying to connect to non-existent signal: " + signal_name)
		return ERR_DOES_NOT_EXIST
		
	var callable_target = Callable(target, method)
	if is_connected(signal_name, callable_target):
		# Already connected, skip
		return OK
		
	var result = connect(signal_name, callable_target)
	if result != OK:
		push_error("SignalManager: Failed to connect signal: " + signal_name + " Error: " + str(result))
	else:
		print("Successfully connected signal: " + signal_name + " to " + target.get_name() + "." + method)
	
	# Track connection for debugging
	if not _registered_listeners.has(signal_name):
		_registered_listeners[signal_name] = []
	_registered_listeners[signal_name].append({
		"target": target,
		"method": method
	})
	
	return result

# Helper method to disconnect a signal with error checking
func disconnect_signal(signal_name: String, target: Object, method: String) -> void:
	if is_connected(signal_name, Callable(target, method)):
		disconnect(signal_name, Callable(target, method))
		
		# Update tracking
		if _registered_listeners.has(signal_name):
			for i in range(_registered_listeners[signal_name].size()):
				var listener = _registered_listeners[signal_name][i]
				if listener.target == target and listener.method == method:
					_registered_listeners[signal_name].remove(i)
					break

# Helper method to get all registered listeners
func get_registered_listeners() -> Dictionary:
	return _registered_listeners

# Helper methods for common signal groups
func connect_player_signals(target: Object, method_prefix: String = "_on_") -> void:
	connect_signal("player_moved", target, method_prefix + "player_moved")
	connect_signal("player_movement_started", target, method_prefix + "player_movement_started")
	connect_signal("player_movement_completed", target, method_prefix + "player_movement_completed")
	connect_signal("player_collected_poi", target, method_prefix + "player_collected_poi")

func connect_turn_signals(target: Object, method_prefix: String = "_on_") -> void:
	connect_signal("turn_started", target, method_prefix + "turn_started")
	connect_signal("turn_ended", target, method_prefix + "turn_ended")
	connect_signal("turn_used", target, method_prefix + "turn_used")

	# Debug methods
# func print_listeners() -> void:
#     print("--- Signal Manager Registered Listeners ---")
#     for signal_name in _registered_listeners.keys():
#         var listeners = _registered_listeners[signal_name]
#         print(signal_name + " (" + str(listeners.size()) + " listeners):")
#         for listener in listeners:
#             print("  - " + str(listener.target) + " :: " + listener.method)
