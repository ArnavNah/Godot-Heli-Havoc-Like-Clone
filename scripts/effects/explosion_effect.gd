extends Node3D
class_name ExplosionEffect

@onready var fire_particles: CPUParticles3D = get_node_or_null("FireParticles")
@onready var smoke_particles: CPUParticles3D = get_node_or_null("SmokeParticles")
@onready var flash_light: OmniLight3D = get_node_or_null("FlashLight")
@onready var shockwave_mesh: MeshInstance3D = get_node_or_null("ShockwaveMesh")

func _ready() -> void:
	if fire_particles:
		fire_particles.emitting = true
	if smoke_particles:
		smoke_particles.emitting = true
	
	# Animate Flash Light
	if flash_light:
		var tween = create_tween()
		tween.tween_property(flash_light, "light_energy", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Animate Shockwave Expansion
	if shockwave_mesh:
		shockwave_mesh.scale = Vector3(0.2, 0.2, 0.2)
		var tween_wave = create_tween()
		tween_wave.tween_property(shockwave_mesh, "scale", Vector3(4.5, 4.5, 4.5), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween_wave.parallel().tween_property(shockwave_mesh, "transparency", 1.0, 0.35)
	
	# Clean up after particles complete
	get_tree().create_timer(1.3).timeout.connect(queue_free)
