@tool
class_name GridObjectRegistry
extends Node

signal poi_generated(positions)
signal grid_objects_generated(object_counts)

# Reference to parent grid manager
var grid_manager = null

# Object type registry for extensible object types
var object_type_registry = {}
var object_positions = {} # Dictionary of arrays keyed by object type

func _init(parent_grid_manager):
	grid_manager = parent_grid_manager

# Initialize the object type registry
func initialize():
	# Register POI type
	register_object_type("poi", {
		"script_path": "res://core/objects/poi.gd",
		"needs_randomization": true,
		"min_distance": grid_manager.min_poi_distance,
		"count_property": "poi_count",
		"signal_on_generate": "poi_generated"
	})
	
	# Register terrain type
	register_object_type("terrain", {
		"script_path": "res://core/objects/terrain.gd",
		"needs_randomization": false,
		"min_distance": 0,
		"count_property": "terrain_count"
	})
	
	# Initialize position tracking
	for type_id in object_type_registry.keys():
		object_positions[type_id] = []

# Register an object type with the registry
func register_object_type(type_id: String, config: Dictionary):
	object_type_registry[type_id] = config

# Main coordinator function for full grid object generation flow
func generate_grid_objects():
	print("Generating grid objects...")
	
	# Clear existing objects
	clear_existing_objects()

	# Add player to grid (delegated to grid manager)
	grid_manager.add_player_to_grid()
	
	var object_counts = {}
	
	# Generate all registered object types
	for type_id in object_type_registry.keys():
		var config = object_type_registry[type_id]
		var count_property = config.get("count_property", "")
		
		if count_property and grid_manager.has_property(count_property):
			var count = grid_manager.get(count_property)
			generate_objects_of_type(type_id, count)
			object_counts[type_id] = object_positions[type_id].size()
	
	# Emit signal for all generated objects
	emit_signal("grid_objects_generated", object_counts)
	
	print("Grid object generation complete")

# Clear all existing generated objects
func clear_existing_objects():
	# Clear objects by type from the registry
	for type_id in object_positions.keys():
		for pos in object_positions[type_id]:
			var obj = grid_manager.get_grid_object(pos, true)
			if obj and is_instance_valid(obj):
				obj.queue_free()
			grid_manager.remove_grid_object(pos)
		
		# Clear the positions array
		object_positions[type_id].clear()

func generate_objects_of_type(object_type: String, count: int):
	var config = object_type_registry[object_type]
	print("Generating %d objects of type %s" % [count, object_type])
	
	var positions = generate_object_positions(object_type, count)
	var created_objects = []
	
	# Create objects at the valid positions
	for pos in positions:
		var instance = create_and_place_object(object_type, pos)
		if instance:
			created_objects.append(instance)
			object_positions[object_type].append(pos)
	
	# Emit type-specific signal if configured
	if config.has("signal_on_generate"):
		emit_signal(config.get("signal_on_generate"), positions)
		
	# Log a warning if we couldn't create all objects
	if positions.size() < count:
		push_warning("Could only create %d %s out of %d requested - try reducing constraints or increasing grid size."
			% [positions.size(), object_type, count])
		
	return created_objects

# Generate valid positions for objects of a specific type, placement logic only
func generate_object_positions(object_type: String, count: int) -> Array:
	# Get configuration for this type
	var config = object_type_registry[object_type]
	var min_distance = config.get("min_distance", 0)
	
	# Get already occupied positions
	var occupied_positions = []
	for pos in grid_manager.grid_objects.keys():
		occupied_positions.append(pos)
	
	var positions = []
	var max_attempts = grid_manager.grid_size_x * grid_manager.grid_size_y
	var attempts = 0
	
	while positions.size() < count and attempts < max_attempts:
		var x = randi() % grid_manager.grid_size_x
		var y = randi() % grid_manager.grid_size_y
		var pos = Vector2(x, y)
		
		# Skip if position is already occupied
		if occupied_positions.has(pos):
			attempts += 1
			continue
			
		# Check minimum distance requirement if needed
		if min_distance > 0:
			if not is_position_valid(pos, positions, min_distance):
				attempts += 1
				continue
		
		# Position is valid
		positions.append(pos)
		occupied_positions.append(pos)
		attempts += 1
	
	return positions

# Check if position is far enough from other positions based on min_distance
func is_position_valid(pos: Vector2, existing_positions: Array, min_distance: int) -> bool:
	for existing_pos in existing_positions:
		var distance = abs(existing_pos.x - pos.x) + abs(existing_pos.y - pos.y) # Manhattan distance
		if distance < min_distance:
			return false
	return true

# Create an instance of a grid object based on type
func create_grid_object_instance(object_type: String) -> Node:
	var config = object_type_registry[object_type]
	var instance = load(config.script_path).new()
	
	if instance:
		grid_manager.add_child(instance)
		
		# Apply type-specific initialization
		if config.get("needs_randomization", false) and instance.has_method("randomize_properties"):
			instance.randomize_properties()
	
	return instance

# Create, position, and register an object in one operation
func create_and_place_object(object_type: String, grid_pos: Vector2) -> Node:
	var instance = create_grid_object_instance(object_type)
	if instance:
		grid_manager.place_grid_object(instance, grid_pos)
	return instance