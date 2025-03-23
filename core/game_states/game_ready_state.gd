# res://core/game_states/game_ready_state.gd
extends GameState
class_name GameReadyState

func enter() -> void:
    print("GameReadyState: Entering")
    
    # Connect to player movement signal to detect when gameplay begins
    var signal_manager = state_machine.signal_manager
    if signal_manager:
        signal_manager.connect_signal("player_moved", self, "_on_player_moved")
    
    # Make sure player is visible and responsive
    if grid_manager and grid_manager.player_instance:
        # Enable player movement
        if grid_manager.has_method("set_player_immobilized"):
            grid_manager.set_player_immobilized(false)

func exit() -> void:
    print("GameReadyState: Exiting")
    
    # Disconnect signals
    var signal_manager = state_machine.signal_manager
    if signal_manager:
        signal_manager.disconnect_signal("player_moved", self, "_on_player_moved")

func _on_player_moved(grid_position) -> void:
    # Player has moved, transition to active gameplay
    state_machine.transition_to(state_machine.States.GAME_ACTIVE)