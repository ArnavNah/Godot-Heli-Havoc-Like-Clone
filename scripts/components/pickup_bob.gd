extends Node3D
class_name PickupBob

@export var rotation_speed: float = 2.5
@export var bob_amplitude: float = 0.25
@export var bob_frequency: float = 2.0

var initial_y: float = 0.0
var time_elapsed: float = 0.0

func _ready() -> void:
	initial_y = position.y

func _process(delta: float) -> void:
	time_elapsed += delta
	rotate_y(rotation_speed * delta)
	position.y = initial_y + sin(time_elapsed * bob_frequency) * bob_amplitude
