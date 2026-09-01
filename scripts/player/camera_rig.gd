extends Node3D
class_name CameraRig

@export var target_path: NodePath

@export_group("High Angled Arcade Camera")
@export var follow_responsiveness: float = 24.0
@export var target_height_offset: float = 5.2
@export var spring_length: float = 9.8
@export var pitch_degrees: float = -44.0
@export var base_fov: float = 68.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var target: Node3D = null

func _ready() -> void:
	if not target_path.is_empty():
		target = get_node_or_null(target_path)
	
	if spring_arm:
		spring_arm.position.y = target_height_offset
		spring_arm.spring_length = spring_length
		spring_arm.rotation_degrees = Vector3(pitch_degrees, 0, 0)
		spring_arm.margin = 0.2
		spring_arm.collision_mask = 0
	
	if camera:
		camera.fov = base_fov
		camera.near = 0.1
		camera.far = 800.0
		camera.current = true
		camera.transform = Transform3D.IDENTITY
	
	if target and is_instance_valid(target):
		global_position = target.global_position
		rotation = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if not target or not is_instance_valid(target):
		var players = get_tree().get_nodes_in_group("PlayerHeli")
		if players.is_empty():
			players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0]
		else:
			return
	
	var target_pos = target.global_position
	var pos_blend = 1.0 - exp(-follow_responsiveness * delta)
	global_position = global_position.lerp(target_pos, pos_blend)
	rotation = Vector3.ZERO
