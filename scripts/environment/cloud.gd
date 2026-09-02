extends Node3D
class_name LowPolyCloud

@export var drift_speed: float = 1.2

var drift_dir: Vector3 = Vector3.FORWARD

func _ready() -> void:
	drift_dir = Vector3(randf_range(-0.3, 0.3), 0, randf_range(0.8, 1.2)).normalized()

func _process(delta: float) -> void:
	position += drift_dir * drift_speed * delta
