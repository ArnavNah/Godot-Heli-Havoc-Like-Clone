extends Node3D
class_name BulletImpactFlash

@onready var light: OmniLight3D = get_node_or_null("OmniLight3D")
@onready var particles: CPUParticles3D = get_node_or_null("CPUParticles3D")

func _ready() -> void:
	if particles:
		particles.emitting = true
	
	if light:
		var tw = create_tween()
		tw.tween_property(light, "light_energy", 0.0, 0.12).set_ease(Tween.EASE_OUT)
	
	await get_tree().create_timer(0.18).timeout
	queue_free()
