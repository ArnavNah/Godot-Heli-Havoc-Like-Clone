extends Node3D
class_name MuzzleFlash

@onready var light: OmniLight3D = get_node_or_null("OmniLight3D")
@onready var core: MeshInstance3D = get_node_or_null("FlashCore")
@onready var star_flare: MeshInstance3D = get_node_or_null("StarFlare")
@onready var streak_flare: MeshInstance3D = get_node_or_null("StreakFlare")
@onready var cone_flare: MeshInstance3D = get_node_or_null("ConeFlare")
@onready var particles: CPUParticles3D = get_node_or_null("CPUParticles3D")

func _ready() -> void:
	if particles:
		particles.emitting = true
	
	var tw = create_tween()
	tw.set_parallel(true)
	
	if core:
		core.scale = Vector3(0.4, 0.4, 0.4)
		tw.tween_property(core, "scale", Vector3(1.6, 1.6, 1.6), 0.03).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(core, "scale", Vector3.ZERO, 0.05).set_delay(0.03)
	
	if star_flare:
		star_flare.scale = Vector3(0.3, 0.3, 0.3)
		star_flare.rotation.z = randf_range(0.0, PI)
		tw.tween_property(star_flare, "scale", Vector3(2.2, 2.2, 1.0), 0.03).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(star_flare, "scale", Vector3.ZERO, 0.06).set_delay(0.03)
	
	if streak_flare:
		streak_flare.scale = Vector3(0.4, 0.1, 0.4)
		tw.tween_property(streak_flare, "scale", Vector3(3.6, 0.35, 1.0), 0.025).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(streak_flare, "scale", Vector3.ZERO, 0.05).set_delay(0.025)
	
	if cone_flare:
		cone_flare.scale = Vector3(0.4, 0.4, 0.4)
		tw.tween_property(cone_flare, "scale", Vector3(1.5, 1.5, 2.0), 0.03).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(cone_flare, "scale", Vector3.ZERO, 0.05).set_delay(0.03)
	
	if light:
		tw.tween_property(light, "light_energy", 0.0, 0.09).set_ease(Tween.EASE_OUT)
	
	await get_tree().create_timer(0.10).timeout
	queue_free()
