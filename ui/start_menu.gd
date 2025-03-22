extends Control

func _ready():
	$TitleAndButtons/MarginContainer/HBoxContainer/MarginContainer/VBoxContainer/VBoxContainer2/NormalMode.pressed.connect(_on_normal_mode_pressed)
	$TitleAndButtons/MarginContainer/HBoxContainer/MarginContainer/VBoxContainer/VBoxContainer2/TimedMode.pressed.connect(_on_timed_mode_pressed)

func _on_normal_mode_pressed():
	get_tree().change_scene_to_file("res://core/main.tscn")

func _on_timed_mode_pressed():
	# TODO: Implement timed mode logic
	pass
