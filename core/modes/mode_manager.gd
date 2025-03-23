# modes/mode_manager.gd
extends Node

# Available modes dictionary
var modes = {}
var current_mode_name: String = "normal"
var current_mode = null

# Flag to track if we've loaded modes yet
var modes_initialized: bool = false
var grid_initialized: bool = false

func _ready():
	print("ModeManager: Ready")
	# Don't initialize modes yet, wait until explicitly called or needed

func initialize_modes() -> void:
	if modes_initialized:
		return
		
	print("ModeManager: Initializing modes")
	
	# Initialize modes
	modes["normal"] = load("res://core/modes/normal_mode.gd").new()
	modes["time_trial"] = load("res://core/modes/time_trial_mode.gd").new()
	
	# Set default mode
	current_mode = modes["normal"]
	modes_initialized = true
	
	print("ModeManager: Modes initialized successfully (" + str(modes.size()) + " modes available)")

func get_mode(mode_name: String = ""):
	# Initialize modes if not done yet
	if not modes_initialized:
		print("ModeManager: Lazy initialization of modes")
		initialize_modes()
	
	# Return requested mode or current mode
	if mode_name.is_empty():
		return current_mode
	elif modes.has(mode_name):
		return modes[mode_name]
	else:
		push_warning("ModeManager: Requested mode does not exist: " + mode_name)
		return current_mode

func set_mode(mode_name: String) -> void:
	# Initialize modes if not done yet
	if not modes_initialized:
		initialize_modes()
	
	if modes.has(mode_name):
		# Store previous mode for signaling
		var old_mode_name = current_mode_name
		
		# Update current mode
		current_mode_name = mode_name
		current_mode = modes[mode_name]
		
		print("ModeManager: Mode changed from '" + old_mode_name + "' to '" + mode_name + "'")
		
		# If grid is already initialized, initialize this mode too
		if grid_initialized and current_mode:
			current_mode.initialize()
			print("ModeManager: Initialized newly selected mode: " + mode_name)
			
		# Update mode label if it exists
		update_mode_label()
	else:
		push_error("ModeManager: Mode does not exist: " + mode_name)

# Updates the mode label in the UI
func update_mode_label() -> void:
	var mode_label = get_node_or_null("/root/Main/SimpleUI/VBoxContainer/ActiveGameMode")
	if mode_label:
		mode_label.text = current_mode_name

# Call this when the grid manager is available
func initialize_with_grid_manager(grid_manager) -> void:
	if not grid_manager:
		push_error("ModeManager: Cannot initialize - grid_manager is null")
		return
		
	print("ModeManager: Initializing with grid manager")
	
	# Make sure modes are loaded
	if not modes_initialized:
		initialize_modes()
	
	# Set grid manager for all modes
	for mode_key in modes:
		modes[mode_key].grid_manager = grid_manager
		print("ModeManager: Set grid manager for mode: " + mode_key)
	
	grid_initialized = true
	
	# Initialize current mode
	if current_mode:
		current_mode.initialize()
		
		# Emit signal for mode change if SignalManager is available
		var signal_manager = get_node_or_null("/root/SignalManager")
		if signal_manager:
			signal_manager.emit_signal("mode_initialized")
			
		print("ModeManager: Current mode '" + current_mode_name + "' initialized with grid manager")
		
		# Update the ActiveGameMode label
		update_mode_label()
