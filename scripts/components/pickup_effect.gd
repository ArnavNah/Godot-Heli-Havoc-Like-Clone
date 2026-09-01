extends Node3D
class_name PickupEffect

@export var particle_color: Color = Color(1, 0.9, 0.2, 1)
@onready var particles: CPUParticles3D = $CPUParticles3D

func _ready() -> void:
	if particles:
		particles.emitting = true
		await get_tree().create_timer(particles.lifetime + 0.1).timeout
	queue_free()

func set_color(new_color: Color) -> void:
	particle_color = new_color
	if particles and particles.mesh and particles.mesh.material:
		var mat = particles.mesh.material.duplicate() as StandardMaterial3D
		if mat:
			mat.albedo_color = new_color
			mat.emission = new_color
			particles.mesh = particles.mesh.duplicate()
			particles.mesh.material = mat
