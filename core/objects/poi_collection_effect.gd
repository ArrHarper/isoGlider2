# poi_collection_effect.gd - Visual effect for POI collection
class_name POICollectionEffect
extends Node2D

# Signal when the effect is complete
signal effect_completed

# Properties for customizing the effect
@export var effect_color: Color = Color(1.0, 0.737, 0.259, 1.0) # Default to yellow
@export var auto_destroy: bool = true
@export var particles_amount: int = 30
var active: bool = false

# Reference to the particle system
@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var timer: Timer = $Timer

# Track if particles have started properly
var particles_started = false

func _ready():
	# Connect timer timeout signal
	if not timer.is_connected("timeout", _on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)
	
	# Set timer to match particle lifetime for automatic cleanup
	timer.wait_time = particles.lifetime + 0.2 # Add a small buffer
	
	# Log the initial position for debugging
	print("POI effect created at position: ", global_position)

# Trigger the collection effect
func play_effect(color: Color = effect_color):
	# Update particle color by modifying the material
	var material = particles.process_material as ParticleProcessMaterial
	if material:
		material.color = color
		print("Setting particle color to: ", color)
	else:
		print("WARNING: Could not get particle material")
	
	# Set the effect color property
	effect_color = color
	
	# Force immediate display of particles
	particles.emitting = true
	
	# Start cleanup timer
	timer.start()
	
	# Mark as active
	active = true
	
	# Print debug information
	print("Collection effect playing at position: ", global_position, " with color: ", color)

# Timer timeout handler - clean up effect
func _on_timer_timeout():
	active = false
	print("Effect completed, cleaning up")
	emit_signal("effect_completed")
	
	# Auto-destroy if set
	if auto_destroy:
		queue_free()

# Static helper method to create and play an effect at a position
static func create_at(position: Vector2, color: Color = Color(1.0, 0.737, 0.259, 1.0), parent: Node = null) -> POICollectionEffect:
	# Create the scene instance
	var scene = load("res://core/objects/poi_collection_effect.tscn")
	var effect = scene.instantiate()
	
	# Set position
	effect.position = position
	
	# Add to scene tree
	if parent:
		parent.add_child(effect)
	else:
		# Try to add to main scene
		var main = Engine.get_main_loop().get_current_scene()
		if main:
			main.add_child(effect)
		else:
			print("POICollectionEffect: Could not find parent to attach to")
			return null
	
	# Play the effect
	effect.play_effect(color)
	
	return effect

func _process(delta):
	if active:
		# Check if particles are active
		if particles.emitting and not particles_started:
			particles_started = true
			print("Particles started emitting")
		
		# Check if particles finished but timer is still running
		if particles_started and not particles.emitting and timer.time_left > 0:
			print("Particles finished emitting, time left: ", timer.time_left)
			
			# Force timer completion soon
			if timer.time_left > 0.1:
				timer.wait_time = 0.1
				timer.start()