extends Node3D
class_name TargetMarker

@export var pulse_speed: float = 6.0
@export var spin_speed: float = 3.0

@onready var visual_root: Node3D = $VisualRoot

var time_elapsed: float = 0.0

func _process(delta: float) -> void:
	time_elapsed += delta
	if visual_root:
		visual_root.rotate_y(spin_speed * delta)
		var s = 1.0 + sin(time_elapsed * pulse_speed) * 0.12
		visual_root.scale = Vector3(s, s, s)
