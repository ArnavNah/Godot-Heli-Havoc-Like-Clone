extends Node3D
class_name MainMenu

@export var hover_amplitude: float = 0.18
@export var hover_speed: float = 2.0
@export var turn_speed: float = 0.45 # Slow smooth rotation
@export var rotor_spin_speed: float = 40.0

@onready var helicopter_model: Node3D = $HelicopterRoot
@onready var visual_heli: PlayerHelicopterVisual = get_node_or_null("HelicopterRoot/PlayerHelicopterVisual")

var time_elapsed: float = 0.0
var base_y: float = 0.7

func _ready() -> void:
	if helicopter_model:
		base_y = helicopter_model.position.y

func _process(delta: float) -> void:
	time_elapsed += delta
	
	if helicopter_model:
		# Slow rotation and gentle flying hover
		helicopter_model.rotate_y(turn_speed * delta)
		
		var bob_y = base_y + sin(time_elapsed * hover_speed) * hover_amplitude
		var sway_z = sin(time_elapsed * hover_speed * 0.8) * 0.04
		var sway_x = cos(time_elapsed * hover_speed * 0.6) * 0.03
		helicopter_model.position.y = bob_y
		helicopter_model.rotation.z = sway_z
		helicopter_model.rotation.x = sway_x
