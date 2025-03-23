# core/state/states/game_active_state.gd
class_name GameActiveState
extends GameState

var turns_remaining: int = 0
var timer: float = 0.0

func enter() -> void:
    # Get game configuration from mode
    turns_remaining = game_mode.turn_limit
    
    # Connect signals
    var signal_manager = state_machine.signal_manager
    if signal_manager:
        signal_manager.connect_signal("player_moved", self, "_on_player_moved")
        signal_manager.connect_signal("poi_collected", self, "_on_poi_collected")
        
    # Start the timer if this is time trial mode
    if game_mode.has_timer:
        timer = game_mode.time_limit

func exit() -> void:
    # Disconnect signals
    var signal_manager = state_machine.signal_manager
    if signal_manager:
        signal_manager.disconnect_signal("player_moved", self, "_on_player_moved")
        signal_manager.disconnect_signal("poi_collected", self, "_on_poi_collected")

func update(delta: float) -> void:
    # Update timer for time trial mode
    if game_mode.has_timer and timer > 0:
        timer -= delta
        
        # Update UI
        var signal_manager = state_machine.signal_manager
        if signal_manager:
            signal_manager.emit_signal("timer_updated", timer)
            
        # Check if timer expired
        if timer <= 0:
            state_machine.transition_to(state_machine.States.GAME_OVER)

func _on_player_moved(grid_position) -> void:
    # Decrease turns
    turns_remaining -= 1
    
    # Update UI
    var signal_manager = state_machine.signal_manager
    if signal_manager:
        signal_manager.emit_signal("turn_used")
        signal_manager.emit_signal("turn_ended", turns_remaining)
    
    # Check win condition
    if game_mode.check_win_condition(grid_position):
        state_machine.transition_to(state_machine.States.ROUND_WON)
        return
        
    # Check loss condition
    if turns_remaining <= 0:
        state_machine.transition_to(state_machine.States.GAME_OVER)

func _on_poi_collected(value, position) -> void:
    # Delegate to game mode for handling
    if game_mode.has_method("on_poi_collected"):
        game_mode.on_poi_collected(value, position)