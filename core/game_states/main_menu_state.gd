extends GameState
class_name MainMenuState

# Called when entering this state
func enter() -> void:
    print("MainMenuState: Entering")
    
    # This state is mostly handled by the start menu scene
    # But we could add any additional menu logic here if needed

# Called when exiting this state
func exit() -> void:
    print("MainMenuState: Exiting")

# Called during _process if this is the current state
func update(delta: float) -> void:
    # No need for continuous updates in menu state
    pass

# Called during _input if this is the current state
func handle_input(event: InputEvent) -> void:
    # Input handling is done by the UI directly
    pass