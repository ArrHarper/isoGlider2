# core/main.gd
extends Node2D

@onready var grid_manager = $GridManager
@onready var game_state_machine = null

func _ready():
	print("Main: Ready")
	
	# First ensure grid manager is available
	if not grid_manager:
		push_error("Main: Grid manager not found!")
		return
	
	print("Main: Grid manager found")
	
	# Get the mode manager (should be autoloaded)
	var mode_manager = get_node_or_null("/root/ModeManager")
	if not mode_manager:
		push_error("Main: ModeManager autoload not found!")
		return
		
	# Add the state machine as a child if it doesn't exist yet
	game_state_machine = get_node_or_null("GameStateMachine")
	if not game_state_machine:
		print("Main: Creating game state machine")
		var state_machine_script = load("res://core/state/game_state_machine.gd")
		game_state_machine = state_machine_script.new()
		game_state_machine.name = "GameStateMachine"
		add_child(game_state_machine)
	
	# Initialize components in the correct order
	# 1. Initialize mode manager with grid manager
	mode_manager.initialize_with_grid_manager(grid_manager)
	
	# 2. Initialize the state machine with grid manager
	if game_state_machine:
		print("Main: Game state machine found, initializing")
		game_state_machine.initialize(grid_manager)
	else:
		push_error("Main: Game state machine still not found!")
