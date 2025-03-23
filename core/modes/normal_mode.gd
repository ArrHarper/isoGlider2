# core/modes/normal_mode.gd
class_name NormalMode
extends BaseGameMode

func _init():
    mode_name = "Normal Mode"
    turn_limit = 20
    has_timer = false
    poi_count = 3
    terrain_count = 12
    print("NormalMode: Created with " + str(turn_limit) + " turn limit")

func initialize() -> void:
    print("NormalMode: Starting initialization")
    
    # Call parent implementation first
    super.initialize()
    
    # If already initialized by parent, stop here
    if not is_initialized:
        return
    
    # Normal mode specific initialization
    print("NormalMode: Generating grid objects")
    if grid_manager:
        grid_manager.generate_grid_objects()
        print("NormalMode: Grid objects generated successfully")

func check_win_condition(player_pos: Vector2) -> bool:
    print("NormalMode: Checking win condition at position " + str(player_pos))
    # Win by returning to starting tile
    return super.check_win_condition(player_pos)

func on_round_start() -> void:
    # Any normal mode specific setup
    print("NormalMode: Starting round")

func on_round_end(success: bool) -> void:
    print("NormalMode: Round ended with success: " + str(success))