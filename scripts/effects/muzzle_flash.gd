extends Node3D
class_name MuzzleFlash

@export var auto_free_after_burst: bool = false

@onready var flash_mesh: MeshInstance3D = get_node_or_null("FlashMesh")
@onready var particles: GPUParticles3D = get_node_or_null("GPUParticles3D")
@onready var omni_light: OmniLight3D = get_node_or_null("OmniLight3D")
@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")

func _ready() -> void:
	if flash_mesh:
		flash_mesh.visible = false
	if omni_light:
		omni_light.light_energy = 0.0
	if auto_free_after_burst:
		fire()
		await get_tree().create_timer(0.08).timeout
		queue_free()

func fire() -> void:
	# Guarantee spark burst restart on every shot
	if particles:
		particles.restart()
	
	# Restart fast 0.05s scale/pop animation
	if anim_player:
		anim_player.stop()
		anim_player.play("fire")
