extends Node3D
class_name CameraRig

@export var target_path: NodePath

@export_group("Decoupled World-Space Camera")
@export var follow_speed: float = 10.0
@export var pitch_degrees: float = -44.0
@export var height_offset: float = 8.5
@export var back_offset: float = 10.0
@export var base_fov: float = 68.0
@export var max_fov_kick: float = 5.0
@export var look_ahead_strength: float = 0.08

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var target: Node3D = null
var trauma: float = 0.0
var trauma_time: float = 0.0

func _ready() -> void:
	if not target_path.is_empty():
		target = get_node_or_null(target_path)
	
	if spring_arm:
		spring_arm.position = Vector3.ZERO
		spring_arm.spring_length = 0.0
		spring_arm.rotation_degrees = Vector3.ZERO
		spring_arm.margin = 0.2
		spring_arm.collision_mask = 0
	
	if camera:
		camera.fov = base_fov
		camera.near = 0.1
		camera.far = 1000.0
		camera.current = true
		camera.transform = Transform3D.IDENTITY
	
	_find_target()
	if target and is_instance_valid(target):
		global_position = target.global_position + Vector3(0, height_offset, back_offset)
	
	rotation_degrees = Vector3(pitch_degrees, 0.0, 0.0)

func _find_target() -> void:
	if not target or not is_instance_valid(target):
		var players = get_tree().get_nodes_in_group("PlayerHeli")
		if players.is_empty():
			players = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			target = players[0]

func add_shake(amount: float = 0.6) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func _physics_process(delta: float) -> void:
	_find_target()
	if not target or not is_instance_valid(target):
		return
	
	# Pure world-space follow: does NOT orbit or rotate when helicopter turns
	var target_pos = target.global_position + Vector3(0, height_offset, back_offset)
	var cur_speed = 0.0
	if target is CharacterBody3D:
		var cb = target as CharacterBody3D
		var h_vel = Vector3(cb.velocity.x, 0, cb.velocity.z)
		cur_speed = h_vel.length()
		target_pos += h_vel * look_ahead_strength
	
	# Exponential smoothing follow
	var follow_weight = 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(target_pos, follow_weight)
	
	# Fixed downward pitch
	rotation_degrees = Vector3(pitch_degrees, 0.0, 0.0)
	
	# Trauma Screen Shake
	if trauma > 0.0:
		trauma_time += delta * 25.0
		var shake_amount = trauma * trauma
		var offset_x = sin(trauma_time * 1.3) * shake_amount * 0.4
		var offset_y = cos(trauma_time * 1.7) * shake_amount * 0.4
		var offset_rot = sin(trauma_time * 2.1) * shake_amount * 0.05
		
		if spring_arm:
			spring_arm.position = Vector3(offset_x, offset_y, 0)
			spring_arm.rotation.z = offset_rot
		
		trauma = maxf(0.0, trauma - delta * 1.5)
	else:
		if spring_arm:
			spring_arm.position = Vector3.ZERO
			spring_arm.rotation.z = 0.0
	
	# Dynamic speed FOV kick
	if camera:
		var target_fov = base_fov + clampf(cur_speed / 30.0, 0.0, 1.0) * max_fov_kick
		camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-8.0 * delta))
