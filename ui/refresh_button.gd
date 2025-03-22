extends Button

func _ready():
	# Ensure the button is visible and properly set up
	pass

# Called when the button is pressed
func _on_pressed():
	print("Refresh button pressed, regenerating POIs...")
	
	# Find the GridManager node
	var grid_manager = get_node("/root/Main/GridManager")
	
	# Check if the GridManager was found
	if grid_manager and grid_manager.has_method("generate_pois"):
		# Call the generate_pois function
		grid_manager.generate_pois()
		print("POIs regenerated successfully.")
	else:
		push_error("Could not find GridManager or it doesn't have generate_pois method!")