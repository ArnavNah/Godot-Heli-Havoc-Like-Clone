extends Node3D
class_name MuzzleFlash

@onready var light: OmniLight3D = get_node_or_null("OmniLight3D")
@onready var mesh: MeshInstance3D = get_node_or_null("FlashMesh")
@onready var streak_flare: MeshInstance3D = get_node_or_null("StreakFlare")
@onready var star_flare: MeshInstance3D = get_node_or_null("StarFlare")
@onready var ring_flare: MeshInstance3D = get_node_or_null("RingFlare")
@onready var particles: CPUParticles3D = get_node_or_null("CPUParticles3D")

func _ready() -> void:
	if particles:
		particles.emitting = true
	
	var tw = create_tween()
	tw.set_parallel(true)
	
	if mesh:
		mesh.scale = Vector3(0.3, 0.3, 0.3)
		tw.tween_property(mesh, "scale", Vector3(1.5, 1.5, 1.5), 0.04).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(mesh, "scale", Vector3.ZERO, 0.03).set_delay(0.04)
	
	if streak_flare:
		streak_flare.scale = Vector3(0.2, 0.1, 0.2)
		tw.tween_property(streak_flare, "scale", Vector3(3.4, 0.28, 1.0), 0.035).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(streak_flare, "scale", Vector3(0.0, 0.0, 0.0), 0.035).set_delay(0.035)
	
	if star_flare:
		star_flare.scale = Vector3(0.2, 0.2, 0.2)
		star_flare.rotation.z = randf_range(0.0, PI)
		tw.tween_property(star_flare, "scale", Vector3(1.8, 1.8, 1.0), 0.04).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(star_flare, "scale", Vector3.ZERO, 0.03).set_delay(0.04)
		
	if ring_flare:
		ring_flare.scale = Vector3(0.3, 0.3, 0.3)
		tw.tween_property(ring_flare, "scale", Vector3(2.2, 2.2, 2.2), 0.06).set_trans(Tween.TRANS_EXPO)
		tw.tween_property(ring_flare, "scale", Vector3.ZERO, 0.02).set_delay(0.05)
	
	if light:
		tw.tween_property(light, "light_energy", 0.0, 0.07).set_ease(Tween.EASE_OUT)
	
	await get_tree().create_timer(0.09).timeout
	queue_free()
