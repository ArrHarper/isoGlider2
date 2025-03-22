extends Button

func _ready():
	# Ensure the button is visible and properly set up
	pass

# Called when the button is pressed
func _on_pressed():
	print("Refresh button pressed, regenerating grid objects...")
	
	# Find the GridManager node
	var grid_manager = get_node("/root/Main/GridManager")
	
	# Check if the GridManager was found
	if grid_manager and grid_manager.has_method("generate_grid_objects"):
		# Call the newer generate_grid_objects function instead of the deprecated one
		grid_manager.generate_grid_objects()
		print("Grid objects regenerated successfully.")
	else:
		push_error("Could not find GridManager or it doesn't have generate_grid_objects method!")