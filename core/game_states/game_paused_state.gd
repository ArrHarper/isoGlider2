# res://core/game_states/game_paused_state.gd
extends GameState
class_name GamePausedState

var previous_state: int = -1

func enter() -> void:
    print("GamePausedState: Entering")
    
    # Store previous state to return to
    previous_state = state_machine.previous_state_id
    
    # Pause game logic
    if grid_manager and grid_manager.get_tree():
        grid_manager.get_tree().paused = true
    
    # Optional: Signal UI to show pause menu
    var signal_manager = state_machine.signal_manager
    if signal_manager:
        signal_manager.emit_signal("ui_state_changed", "GAME", "PAUSED")

func exit() -> void:
    print("GamePausedState: Exiting")
    
    # Resume game logic
    if grid_manager and grid_manager.get_tree():
        grid_manager.get_tree().paused = false
    
    # Optional: Signal UI to hide pause menu
    var signal_manager = state_machine.signal_manager
    if signal_manager:
        signal_manager.emit_signal("ui_state_changed", "PAUSED", "GAME")

func handle_input(event: InputEvent) -> void:
    # Check for unpause input (escape key)
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        # Return to previous state
        if previous_state != -1:
            state_machine.transition_to(previous_state)
        else:
            # Default to GAME_ACTIVE if previous state is unknown
            state_machine.transition_to(state_machine.States.GAME_ACTIVE)