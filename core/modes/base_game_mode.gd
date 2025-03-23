class_name BaseGameMode
extends Resource

# Common properties
@export var mode_name: String = "Generic Mode"
@export var turn_limit: int = 20
@export var has_timer: bool = false
@export var time_limit: float = 0.0
@export var poi_count: int = 3
@export var terrain_count: int = 12

# Reference to grid manager for checking positions
var grid_manager = null

# Flag to track initialization
var is_initialized: bool = false

# Initialize the mode
func initialize() -> void:
	# Skip if already initialized or grid manager not set
	if is_initialized:
		print("GameMode: " + mode_name + " already initialized, skipping")
		return
		
	if not grid_manager:
		push_warning("GameMode: Cannot initialize " + mode_name + " - grid_manager not set")
		return
		
	print("GameMode: Initializing " + mode_name)
	
	# Set up grid configuration
	if grid_manager and grid_manager.configuration:
		grid_manager.configuration.poi_count = poi_count
		grid_manager.configuration.terrain_count = terrain_count
		print("GameMode: " + mode_name + " configured with " + str(poi_count) + " POIs and " + str(terrain_count) + " terrain objects")
	
	# Mark as initialized
	is_initialized = true
	
	# Runtime mode-specific setup
	setup()
	
	print("GameMode: " + mode_name + " initialization complete")
	
# Virtual method for mode-specific setup
func setup() -> void:
	pass

func check_win_condition(player_pos: Vector2) -> bool:
	# Default implementation - win by returning to starting tile
	if grid_manager:
		var result = grid_manager.is_player_on_starting_tile()
		if result:
			print("GameMode: " + mode_name + " win condition met")
		return result
	return false
	
# Other methods...