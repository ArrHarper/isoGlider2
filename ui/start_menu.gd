# ui/start_menu.gd
extends Control

func _ready():
	# Connect button signals
	$TitleAndButtons/MarginContainer/HBoxContainer/MarginContainer/VBoxContainer/VBoxContainer2/NormalMode.pressed.connect(_on_normal_mode_pressed)
	$TitleAndButtons/MarginContainer/HBoxContainer/MarginContainer/VBoxContainer/VBoxContainer2/TimedMode.pressed.connect(_on_timed_mode_pressed)

func _on_normal_mode_pressed():
	# Get autoloaded mode manager and set mode
	var mode_manager = get_node_or_null("/root/ModeManager")
	if mode_manager:
		mode_manager.set_mode("normal")
	else:
		push_error("ModeManager autoload not found!")
		
	# Change to main scene
	get_tree().change_scene_to_file("res://core/main.tscn")

func _on_timed_mode_pressed():
	# Get autoloaded mode manager and set mode
	var mode_manager = get_node_or_null("/root/ModeManager")
	if mode_manager:
		mode_manager.set_mode("time_trial")
	else:
		push_error("ModeManager autoload not found!")
		
	# Change to main scene
	get_tree().change_scene_to_file("res://core/main.tscn")
