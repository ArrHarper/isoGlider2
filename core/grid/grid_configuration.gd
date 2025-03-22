@tool
class_name GridConfiguration
extends Resource

# Generic property change handler for all properties
signal property_changed

@export_category("Grid Dimensions")
@export var grid_size_x: int = 8:
	set(value):
		grid_size_x = value
		emit_signal("property_changed")
@export var grid_size_y: int = 8:
	set(value):
		grid_size_y = value
		emit_signal("property_changed")

@export_category("Tile Properties")
@export var tile_width: int = 64:
	set(value):
		tile_width = value
		emit_signal("property_changed")
@export var tile_height: int = 32:
	set(value):
		tile_height = value
		emit_signal("property_changed")

@export_category("Visual Settings")
@export var show_grid_lines: bool = true:
	set(value):
		show_grid_lines = value
		emit_signal("property_changed")
@export var grid_color: Color = Color(0.5, 0.5, 0.5, 0.5):
	set(value):
		grid_color = value
		emit_signal("property_changed")
@export var show_tile_coordinates: bool = false:
	set(value):
		show_tile_coordinates = value
		emit_signal("property_changed")
@export var highlight_origin: bool = true:
	set(value):
		highlight_origin = value
		emit_signal("property_changed")
@export var show_chess_coordinates: bool = true:
	set(value):
		show_chess_coordinates = value
		emit_signal("property_changed")
@export var show_chess_labels: bool = true:
	set(value):
		show_chess_labels = value
		emit_signal("property_changed")
@export var enable_grid_glow: bool = false:
	set(value):
		enable_grid_glow = value
		emit_signal("property_changed")
@export var grid_glow_color: Color = Color(0.5, 0.5, 0.5, 0.5):
	set(value):
		grid_glow_color = value
		emit_signal("property_changed")
@export var grid_glow_width: float = 3.0:
	set(value):
		grid_glow_width = value
		emit_signal("property_changed")
@export var grid_glow_intensity: int = 3:
	set(value):
		grid_glow_intensity = value
		emit_signal("property_changed")

@export_category("Grid Object Generation")
@export var poi_count: int = 3:
	set(value):
		poi_count = value
		emit_signal("property_changed")
@export var terrain_count: int = 12:
	set(value):
		terrain_count = value
		emit_signal("property_changed")
@export var min_poi_distance: int = 3:
	set(value):
		min_poi_distance = value
		emit_signal("property_changed")

@export_category("Player Settings")
@export var player_starting_tile: String = "A1":
	set(value):
		player_starting_tile = value
		emit_signal("property_changed")