# res://core/game_states/round_restarting_state.gd
extends GameState
class_name RoundRestartingState

func enter() -> void:
    print("RoundRestartingState: Entering")
    
    # Refresh the map for the next round
    if grid_manager:
        # Clear existing POIs and terrain
        if grid_manager.has_method("clear_grid_objects"):
            grid_manager.clear_grid_objects()
        
        # Regenerate grid objects according to game mode
        if game_mode and game_mode.has_method("initialize"):
            game_mode.initialize()
        else:
            # Fallback to generic regeneration
            grid_manager.generate_grid_objects()
        
        # Reset player to starting position
        if grid_manager.player_instance:
            grid_manager.add_player_to_grid()
    
    # Signal round starting
    var signal_manager = state_machine.signal_manager
    if signal_manager:
        signal_manager.emit_signal("round_started", get_round_number())
    
    # Determine next state based on game mode
    var use_countdown = game_mode and game_mode.get("use_round_countdown", false)
    
    # Short delay before transitioning
    if grid_manager and grid_manager.get_tree():
        grid_manager.get_tree().create_timer(0.5).timeout.connect(
            func():
                if use_countdown:
                    state_machine.transition_to(state_machine.States.ROUND_START)
                else:
                    state_machine.transition_to(state_machine.States.GAME_READY)
        )

func exit() -> void:
    print("RoundRestartingState: Exiting")

# Helper function to get current round number
func get_round_number() -> int:
    if game_mode and game_mode.has("current_round"):
        return game_mode.current_round
    return 1