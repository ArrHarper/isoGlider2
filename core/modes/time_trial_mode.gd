# res://modes/time_trial_mode.gd
extends Resource
class_name TimeTrialMode

var mode_name: String = "Time Trial Mode"
var turn_limit: int = 25
var has_timer: bool = true
var time_limit: float = 60.0
var poi_count: int = 5
var terrain_count: int = 8

var score: int = 0
var timer_ui = null
var grid_manager = null

# Called after grid_manager is set
func initialize() -> void:
	# Reset score
	score = 0
	
	print("TimeTrialMode: Initializing")
	
	# Set up grid configuration
	if grid_manager and grid_manager.configuration:
		grid_manager.configuration.poi_count = poi_count
		grid_manager.configuration.terrain_count = terrain_count
	
	# Generate grid objects
	if grid_manager:
		grid_manager.generate_grid_objects()
	
	# Create timer UI if needed - we need to access the scene tree
	# through the grid_manager's get_tree() method
	if not timer_ui and grid_manager:
		var timer_scene = load("res://ui/time_trial_timer.tscn")
		if timer_scene:
			timer_ui = timer_scene.instantiate()
			
			# Get the current scene through the grid manager
			var main = grid_manager.get_tree().current_scene
			if main:
				main.add_child(timer_ui)
				print("TimeTrialMode: Added timer UI to scene")
			else:
				print("TimeTrialMode: Could not get current scene")
		else:
			print("TimeTrialMode: Could not load timer scene")

func on_poi_collected(value: int, position: Vector2) -> void:
	# Add to score
	score += value
	
	# Add time bonus
	time_limit += 5.0
	
	# Update UI
	if grid_manager:
		var signal_manager = grid_manager.get_node_or_null("/root/SignalManager")
		if signal_manager:
			signal_manager.emit_signal("timer_updated", time_limit)
			signal_manager.emit_signal("score_updated", score)

func check_win_condition(player_pos: Vector2) -> bool:
	# Win by returning to starting tile
	if grid_manager:
		return grid_manager.is_player_on_starting_tile()
	return false
