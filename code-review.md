# Code review 3/21/25

## Signal manager

[IMPROVE] The signal connection helpers are well-designed, but could benefit from
more documentation on parameters, especially the 'flags' parameter which isn't used.

[STYLE] Some signals don't follow the verb_noun pattern (e.g., game_reset). Consider
standardizing to something like game_reset_requested or game_reset_triggered.

[IMPROVE] Consider implementing or removing the commented-out print_listeners() debug
method. If implementing, add a parameter to filter by signal name.

## Grid manager

[ARCH] The grid_manager.gd handles both grid visualization and POI generation.
Consider moving POI generation to a dedicated system to improve separation of concerns.
✅ all visualization is handled by grid_visualizer now, grid_objects and subclasses contain all visual prop info

[IMPROVE] The POI creation functionality creates POI instances directly. This would be
cleaner using a factory pattern or dependency injection.

[BUG] In screen_to_grid(), the conversion doesn't account for grid offset, which could
cause incorrect conversions if the grid is not centered.

[STYLE] Several large commented-out signal definitions should be removed now that
they've been moved to the signal manager.
✅ removed old signal references

## Grid visualizer

[ARCH] The grid_visualizer.gd connects directly to grid_manager signals rather than 
using SignalManager, creating a tight coupling between these components. This 
contradicts the architecture's goal of using a central signal bus.
✅ properly implemented signal bus

[IMPROVE] The update_grid_position() method has to handle multiple visual elements 
(sprites, highlights, shapes) in a single function. Consider splitting this into 
smaller, focused methods.
✅ works fine for our implementation

[STYLE] The method naming is inconsistent: some use camelCase for IDs while others use 
snake_case for similar purposes (e.g., "object_%s_%s" vs "test_highlight").

## Grid object

[BUG] The register_with_grid() method doesn't verify if grid_manager was successfully 
found before attempting to use it, which could lead to null reference errors.
✅ fixed

[IMPROVE] The _find_grid_manager() method traverses the hierarchy which is fragile if 
the scene structure changes. Consider using dependency injection or a singleton.


[OPTIM] The get_visual_properties() method creates a new dictionary every call. For 
frequently accessed objects, this could be cached.

## POI

[DRY] The POI class duplicates shape definitions that also exist in the grid_manager. 
Consider centralizing these definitions in a resource or shared constants file.
✅ fixed

[IMPROVE] The set_shape() method accepts a string parameter instead of using the 
defined ShapeType enum, losing type safety. Consider using the enum.

[STYLE] The _init() method sets shape_type to "square" but then immediately calls 
set_shape() with the same value, which is redundant.

## Overall 

[ARCH] The POI generation and management is currently split across GridManager, 
GridVisualizer, and the POI class. This violates the single responsibility principle and 
makes the system harder to modify. Consider implementing a dedicated POISystem that 
would manage all POI-related functionality.

[IMPROVE] GridVisualizer needs to understand the shape data from POIs to render them 
correctly. This tight coupling could be reduced by either moving shape data to a 
shared resource, or by having POIs expose a standardized method to get their visual 
representation.

[BUG] When a POI is collected, it updates its state but relies on re-registering with 
the grid manager to update its visual appearance. This indirect communication path 
could lead to synchronization issues.