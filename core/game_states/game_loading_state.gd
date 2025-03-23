# res://core/state/states/game_loading_state.gd
extends GameState
class_name GameLoadingState

# Called when entering this state
func enter() -> void:
    print("GameLoadingState: Entering")
    
    # Minimal check to ensure we have what we need
    if not grid_manager:
        push_error("GameLoadingState: Grid manager not available")
        return
    
    # Simply proceed to the next state after a very short delay
    # This gives time for any initialization that might be happening
    if grid_manager.get_tree():
        grid_manager.get_tree().create_timer(0.1).timeout.connect(_complete_loading)
    else:
        # Fallback if we can't create a timer
        _complete_loading()

# Called when exiting this state
func exit() -> void:
    print("GameLoadingState: Exiting")

# Complete the loading process and transition to gameplay
func _complete_loading() -> void:
    print("GameLoadingState: Moving to GAME_READY state")
    
    # Transition to GAME_READY state
    if state_machine:
        state_machine.transition_to(state_machine.States.GAME_READY)
    else:
        push_error("GameLoadingState: Missing state_machine reference")

# Called during _process if this is the current state
func update(delta: float) -> void:
    # No continuous updates needed for this simple pass-through state
    pass

func handle_input(event: InputEvent) -> void:
    # No input handling needed for loading state
    pass