# res://core/game_states/round_starting_state.gd
extends GameState
class_name RoundStartingState

var start_timer: float = 3.0 # 3 second countdown

func enter() -> void:
    print("RoundStartingState: Entering")
    
    # Make player immobile during countdown
    if grid_manager:
        grid_manager.set_player_immobilized(true)
    
    # Start countdown
    start_timer = 3.0
    
    # Optional: Signal UI to show countdown
    var signal_manager = state_machine.signal_manager
    if signal_manager:
        signal_manager.emit_signal("countdown_changed", int(start_timer))

func exit() -> void:
    print("RoundStartingState: Exiting")
    
    # Make player mobile again
    if grid_manager:
        grid_manager.set_player_immobilized(false)

func update(delta: float) -> void:
    # Update countdown timer
    if start_timer > 0:
        start_timer -= delta
        
        # Update UI every second
        var signal_manager = state_machine.signal_manager
        if signal_manager and int(start_timer + delta) != int(start_timer):
            signal_manager.emit_signal("countdown_changed", int(start_timer))
        
        # Transition to active gameplay when timer expires
        if start_timer <= 0:
            state_machine.transition_to(state_machine.States.GAME_ACTIVE)