# res://core/game_states/round_won_state.gd
extends GameState
class_name RoundWonState

var celebration_timer: float = 2.0

func enter() -> void:
    print("RoundWonState: Entering")
    
    # Immobilize player during win celebration
    if grid_manager:
        grid_manager.set_player_immobilized(true)
    
    # Calculate score or other rewards
    var score = 0
    if game_mode and game_mode.has_method("calculate_round_score"):
        score = game_mode.calculate_round_score()
    
    # Signal round completion
    var signal_manager = state_machine.signal_manager
    if signal_manager:
        signal_manager.emit_signal("round_completed", true, score)
    
    # Start celebration timer
    celebration_timer = 2.0

func exit() -> void:
    print("RoundWonState: Exiting")

func update(delta: float) -> void:
    # Wait for celebration to complete
    if celebration_timer > 0:
        celebration_timer -= delta
        
        # Transition to next round when celebration ends
        if celebration_timer <= 0:
            state_machine.transition_to(state_machine.States.ROUND_RESTARTING)