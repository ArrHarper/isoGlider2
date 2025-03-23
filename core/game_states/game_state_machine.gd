# core/game_states/game_state_machine.gd
class_name GameStateMachine
extends Node

# Enum to easily reference states
enum States {MAIN_MENU, GAME_LOADING, GAME_READY, ROUND_START,
			 GAME_ACTIVE, GAME_PAUSED, ROUND_WON, ROUND_RESTARTING, GAME_OVER}

# State instances
var states = {}
var current_state_id: States = States.MAIN_MENU
var current_state: GameState = null
var previous_state_id: States = States.MAIN_MENU
var signal_manager = null
var game_mode = null
var grid_manager = null

# Flag to track initialization
var is_initialized: bool = false

func _ready():
	print("GameStateMachine: Ready")
	
	# We'll delay initialization until explicitly called
	# This prevents timing issues with other systems

# Initialize the state machine
func initialize(grid_mgr) -> void:
	if is_initialized:
		return
	
	print("GameStateMachine: Initializing")
	
	# Store grid manager reference
	grid_manager = grid_mgr
	
	# Create state instances
	states[States.MAIN_MENU] = load("res://core/game_states/main_menu_state.gd").new()
	states[States.GAME_LOADING] = load("res://core/game_states/game_loading_state.gd").new()
	states[States.GAME_READY] = load("res://core/game_states/game_ready_state.gd").new()
	states[States.ROUND_START] = load("res://core/game_states/round_starting_state.gd").new()
	states[States.GAME_ACTIVE] = load("res://core/game_states/game_active_state.gd").new()
	states[States.GAME_PAUSED] = load("res://core/game_states/game_paused_state.gd").new()
	states[States.ROUND_WON] = load("res://core/game_states/round_won_state.gd").new()
	states[States.ROUND_RESTARTING] = load("res://core/game_states/round_restarting_state.gd").new()
	states[States.GAME_OVER] = load("res://core/game_states/game_over_state.gd").new()
	
	# Initialize states
	for state_id in states:
		states[state_id].state_machine = self
		states[state_id].grid_manager = grid_manager
	
	# Get signal manager
	signal_manager = get_node_or_null("/root/SignalManager")
	
	# Get current mode from ModeManager
	var mode_manager = get_node_or_null("/root/ModeManager")
	if mode_manager:
		game_mode = mode_manager.get_mode()
	
	is_initialized = true
	
	# Start with GAME_LOADING state
	transition_to(States.GAME_LOADING)
	
	print("GameStateMachine: Initialized successfully with " + str(states.size()) + " states")

func transition_to(new_state_id: States) -> void:
	# Don't transition if not initialized
	if not is_initialized:
		push_warning("GameStateMachine: Cannot transition states - not initialized")
		return
	
	if current_state:
		print("GameStateMachine: Exiting state " + States.keys()[current_state_id])
		current_state.exit()
	
	# Store the previous state ID
	previous_state_id = current_state_id
	
	# Update the current state
	current_state_id = new_state_id
	
	# Check if the state exists in our dictionary
	if not states.has(new_state_id):
		push_error("GameStateMachine: State " + str(new_state_id) + " does not exist in states dictionary")
		return
		
	current_state = states[new_state_id]
	
	# Pass references to state
	current_state.game_mode = game_mode
	current_state.grid_manager = grid_manager
	
	# Enter the new state
	print("GameStateMachine: Entering state " + States.keys()[new_state_id])
	current_state.enter()
	
	# Emit state change signal
	if signal_manager:
		# Safely get the old state name
		var old_state_name = "None"
		if previous_state_id >= 0 and previous_state_id < States.size():
			old_state_name = States.keys()[previous_state_id]
			
		var new_state_name = States.keys()[new_state_id]
		signal_manager.emit_signal("game_state_changed", old_state_name, new_state_name)
		
	print("GameStateMachine: Completed transition to " + States.keys()[new_state_id])

func _process(delta):
	if is_initialized and current_state:
		current_state.update(delta)
		
func _input(event):
	if is_initialized and current_state:
		current_state.handle_input(event)
		
# Set the current game mode
func set_game_mode(mode) -> void:
	game_mode = mode
	print("GameStateMachine: Game mode set to " + mode.mode_name)
	
	# Update game mode for current state
	if current_state:
		current_state.game_mode = game_mode
