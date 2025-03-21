# Isometric Grid Game

Rebuilding the artictecture of Iso Move prototype. We're prioritizing simplicity and speed of iteration for our structure, while doing our best to build things in a clean, decoupled manner.

# Pragmatic Game Architecture Redesign for Godot 4.4

After considering the needs of a prototype that prioritizes iteration speed and simplicity, here's a practical architecture redesign that addresses your specific pain points while leveraging Godot 4.4's features.

## Core Design Patterns to Implement

### 1. Simple Inheritance + Composition

- **Core Benefit**: Simplicity of inheritance with flexibility when needed
- **Implementation**: Base `GridObject` class with specialized derived classes, using composition for unique behaviors
- **Godot Approach**: Use scene inheritance and `@tool` scripts for editor visibility

### 2. State Pattern (Already Present, But Expand)

- **Core Benefit**: Encapsulates state-specific behaviors and transitions
- **Implementation**: Keep your existing movement state machine, add game state machine
- **Godot Approach**: Use resource-based states with clean transitions

### 3. Strategy Pattern for Game Modes

- **Core Benefit**: Swappable game rules and mechanics
- **Implementation**: Define interfaces for core game rules that modes can implement
- **Godot Approach**: Use Resource subclasses for mode configurations

### 4. Observer Pattern (Via Centralized Signals)

- **Core Benefit**: Decouple systems while maintaining communication
- **Implementation**: Structured signal management to reduce tangled dependencies
- **Godot Approach**: Leverage Godot 4.4's improved signal syntax and Autoloads

## Revised System Architecture

### 1. Core Game Framework

```
/core
  /grid
    grid_manager.gd       # @tool script for grid handling and visualization
    grid_manager.tscn     # Scene with configurable grid properties
  /objects
    grid_object.gd        # Base class for anything on the grid
    player.gd/tscn        # Player specialization
    poi.gd/tscn           # Point of Interest specialization
    terrain.gd/tscn       # Terrain obstacle specialization
  /state
    game_state_machine.gd # Controls high-level game states
    game_state.gd         # Base state interface
  /signal
    signal_manager.gd     # Autoload for structured signal management
  /game_manager.gd        # Autoload for global game coordination
```

### 2. Game Mode Framework

```
/modes
  game_mode.gd            # Base class for all game modes (Resource)
  mode_manager.gd         # Manages loading/switching between modes
  /standard
    standard_mode.gd      # Implementation of the base game
    standard_config.tres  # Configuration data for this mode
  /challenge
    challenge_mode.gd     # Time trial implementation
    challenge_config.tres # Configuration for challenge mode
```

### 3. Systems (Instead of Components)

```
/systems
  movement_system.gd/tscn # Handles movement and pathfinding
  visibility_system.gd    # Handles fog of war
  collection_system.gd    # Handles POI interaction
  turn_system.gd          # Manages turns and limits
```

### 4. UI System

```
/ui
  ui_manager.gd/tscn      # Coordinates UI screens and elements
  /screens
    game_ui.gd/tscn       # In-game interface
    mode_select_ui.gd/tscn # Mode selection screen
```

## Godot-Specific Implementation

### @tool Scripts for Editor Visualization

```gdscript
@tool
extends Node2D

@export var grid_size: int = 8:
    set(value):
        grid_size = value
        if Engine.is_editor_hint():
            update_grid_visual()

@export var show_grid_lines: bool = true:
    set(value):
        show_grid_lines = value
        queue_redraw()

func _draw():
    if Engine.is_editor_hint() and show_grid_lines:
        draw_grid()

func draw_grid():
    # Grid drawing code here
    pass
```

### Scene Inheritance for Grid Objects

```gdscript
# Base grid_object.tscn with grid_object.gd attached
# Other objects inherit from this scene:

# In poi.tscn:
# - Inherits from grid_object.tscn
# - Adds poi.gd as script
# - Adds custom visual elements

# In terrain.tscn:
# - Inherits from grid_object.tscn
# - Adds terrain.gd as script
# - Adds custom visual elements
```

### Resource-Based Game Modes

```gdscript
# game_mode.gd
class_name GameMode
extends Resource

@export var mode_name: String = ""
@export var turn_limit: int = 20
@export var poi_count: int = 3

# Abstract methods
func initialize_map(): pass
func check_win_condition(player_pos): pass

# standard_mode.gd
class_name StandardMode
extends GameMode

func initialize_map():
    # Standard mode map setup

func check_win_condition(player_pos):
    # Standard win logic
```

### Improved Signal Management with Godot 4.4

```gdscript
# signal_manager.gd
extends Node

# Player signals
signal player_moved(grid_position)
signal player_collected(poi_id, reward)

# Game flow signals
signal turn_started(turn_number)
signal turn_ended(turns_remaining)

# Helper methods
func connect_player_signals(target):
    player_moved.connect(target._on_player_moved)
    player_collected.connect(target._on_player_collected)
```

### Autoloads for Global Access

```
Project Settings > Autoload:
- SignalManager -> /core/signal/signal_manager.gd
- GameManager -> /core/game_manager.gd
```

## Key Improvements

### 1. Centralized State Management

- Game state machine with clear states: SETUP, PLAYING, ROUND_END, GAME_OVER
- Each state has enter/exit methods to ensure proper cleanup
- States delegate to game modes for mode-specific behavior

```gdscript
# Example game state
class_name PlayingState
extends GameState

func enter():
    # Enable player input
    # Start turn tracking
    current_mode.start_round()

func exit():
    # Disable player input
    # Save any needed state

func update(delta):
    # Check win conditions
    if current_mode.check_win_condition():
        state_machine.transition_to("RoundEnd")
```

### 2. Simplified Object Model

- Base `GridObject` class with common properties (position, visibility)
- Derived classes for specific object types
- Use composition for behaviors that don't fit the inheritance model

```gdscript
# Base class with common properties
class_name GridObject
extends Node2D

var grid_position: Vector2
var is_visible: bool = false
var is_passable: bool = true

# Methods common to all grid objects
func initialize(pos: Vector2):
    grid_position = pos
    position = GridManager.grid_to_screen(pos)

# Simple POI class example
class_name POI
extends GridObject

var reward: int
var collected: bool = false

func collect():
    if not collected:
        collected = true
        SignalManager.poi_collected.emit(reward)
        # Handle visual changes
```

### 3. Strategy Pattern for Game Modes

- Each game mode implements the same interface
- Game modes define:
  - Win/loss conditions
  - Turn management
  - Map generation
  - Special mechanics

```gdscript
# Base game mode
class_name GameMode
extends Resource

func initialize_map():
    # Abstract method to be implemented by specific modes
    pass

func check_win_condition(player_pos: Vector2) -> bool:
    # Abstract method to be implemented by specific modes
    return false

func on_turn_end():
    # Abstract method to be implemented by specific modes
    pass

# Challenge mode implementation
class_name ChallengeMode
extends GameMode

var time_remaining: float = 30.0

func initialize_map():
    # Challenge-specific map setup
    GridManager.spawn_objects({
        "poi": 4,
        "terrain": 6
    })

func check_win_condition(player_pos: Vector2) -> bool:
    # Challenge-specific win logic
    return player_pos == PlayerManager.start_position and time_remaining > 0

func on_turn_end():
    time_remaining -= 1
    if time_remaining <= 0:
        SignalManager.game_over.emit(false)
```

### 4. Editor Visualization

- `@tool` scripts for live updates in the editor
- Scene composition for visual editing
- Property exports for configuration
- Placeholder objects for procedural content

```gdscript
@tool
class_name POI
extends GridObject

@export var reward_min: int = 10
@export var reward_max: int = 100
@export var poi_type: String = "coin":
    set(value):
        poi_type = value
        if Engine.is_editor_hint():
            update_visual()

func _ready():
    if Engine.is_editor_hint():
        update_visual()
    else:
        # Runtime initialization
        reward = randi_range(reward_min, reward_max)

func update_visual():
    # Update appearance based on poi_type
```

## Implementation Plan

1. **Start with core framework**:

   - Implement the Grid Manager with editor visualization
   - Create the `GridObject` base class and key derived scenes
   - Set up the Signal Manager as an autoload

2. **Implement game state machine**:

   - Create the game state base class and concrete states
   - Move existing state logic into appropriate state classes
   - Ensure proper state transitions and lifecycle management

3. **Implement the mode system**:

   - Create the base GameMode resource class with clear interfaces
   - Port existing standard mode logic to this structure
   - Add the challenge mode as a second implementation

4. **Refine existing systems**:

   - Maintain the existing movement state machine but connect it to the new architecture
   - Refactor POI and Terrain classes to extend GridObject
   - Adapt Fog of War to work with the visibility system

5. **Improve UI management**:
   - Centralize UI management and state
   - Create clear interfaces between game state and UI

This architecture strikes a balance between clean design and pragmatic simplicity, while leveraging Godot 4.4's features to make development more efficient. It addresses your specific pain points without introducing unnecessary complexity:

- **State fragmentation**: Solved with clear state machine and delegation to game modes
- **Redundant functions**: Reduced by centralizing core functionality in base classes and systems
- **Signal chain**: Organized through structured signal management
- **Editor visibility**: Enhanced with @tool scripts and scene composition

By taking this pragmatic middle-ground approach, you'll be able to iterate quickly while still having a foundation that can be extended as your prototype evolves.
