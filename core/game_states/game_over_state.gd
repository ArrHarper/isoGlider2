# res://core/game_states/game_over_state.gd
extends GameState
class_name GameOverState

var game_over_timer: float = 3.0

func enter() -> void:
    print("GameOverState: Entering")
    
    # Immobilize player
    if grid_manager:
        grid_manager.set_player_immobilized(true)
    
    # Get final score
    var score = 0
    if game_mode and game_mode.has_method("get_final_score"):
        score = game_mode.get_final_score()
    
    # Get round number
    var round_number = 1
    if game_mode and game_mode.has("current_round"):
        round_number = game_mode.current_round
    
    # Signal game over
    var signal_manager = state_machine.signal_manager
    if signal_manager:
        signal_manager.emit_signal("game_over", false, score, round_number)
    
    # Start game over timer
    game_over_timer = 3.0

func exit() -> void:
    print("GameOverState: Exiting")

func update(delta: float) -> void:
    # Wait before returning to menu
    if game_over_timer > 0:
        game_over_timer -= delta
        
        # Return to menu when timer expires
        if game_over_timer <= 0:
            # Return to main menu
            if grid_manager and grid_manager.get_tree():
                grid_manager.get_tree().change_scene_to_file("res://ui/start_menu.tscn")