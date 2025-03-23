extends RefCounted
class_name GameState

var state_machine = null
var game_mode = null
var grid_manager = null

# Called when entering this state
func enter() -> void:
    pass

# Called when exiting this state
func exit() -> void:
    pass

# Called during _process if this is the current state
func update(delta: float) -> void:
    pass

# Called during _input if this is the current state
func handle_input(event: InputEvent) -> void:
    pass