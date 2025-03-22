extends AudioStreamPlayer2D

func _ready():
	# Play the music immediately when the scene loads
	play_music()

# Play the music
func play_music():
	# If it's not already playing, start it
	stream_paused = false
	
	if !playing:
		play()

# Pause the music
func pause_music():
	stream_paused = true

# Stop the music
func stop_music():
	stop()

# Set volume (0.0 to 1.0)
func set_volume(value):
	volume_db = linear_to_db(value)
