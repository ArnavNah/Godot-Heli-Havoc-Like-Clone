extends Node3D
class_name MenuHelicopter

@export var hover_amplitude: float = 0.18
@export var hover_frequency: float = 3.2
@export var roll_sway_deg: float = 4.5
@export var pitch_sway_deg: float = 2.5
@export var base_yaw_deg: float = -32.0

var base_y: float = 0.0
var time_elapsed: float = 0.0

func _ready() -> void:
	base_y = position.y

func _process(delta: float) -> void:
	time_elapsed += delta
	
	# Smooth Sinusoidal Hovering on Y-axis
	var hover_offset = sin(time_elapsed * hover_frequency) * hover_amplitude
	position.y = base_y + hover_offset
	
	# Gentle 3D idle banking and yaw sway
	var roll = sin(time_elapsed * (hover_frequency * 0.7)) * deg_to_rad(roll_sway_deg)
	var pitch = cos(time_elapsed * (hover_frequency * 0.5)) * deg_to_rad(pitch_sway_deg)
	var yaw = deg_to_rad(base_yaw_deg) + sin(time_elapsed * 0.8) * deg_to_rad(8.0)
	
	rotation = Vector3(pitch, yaw, roll)
