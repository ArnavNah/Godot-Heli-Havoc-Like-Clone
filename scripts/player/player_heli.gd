extends CharacterBody3D
class_name PlayerHeli

signal player_died()

@export_group("360-Degree Arcade Flight")
@export var max_speed: float = 32.0
@export var acceleration: float = 110.0
@export var deceleration: float = 125.0
@export var flight_altitude: float = 6.0
@export var altitude_responsiveness: float = 22.0

@export_group("Visual Banking & Yaw (Visual Only)")
@export var max_bank_deg: float = 30.0
@export var max_pitch_deg: float = 16.0
@export var bank_speed: float = 26.0
@export var yaw_speed: float = 20.0
@export var rotor_speed: float = 45.0

@export_group("Weapons")
@export var bullet_scene: PackedScene = preload("res://scenes/projectiles/player_bullet.tscn")
@export var fire_cooldown: float = 0.12
var fire_timer: float = 0.0
var fire_left_next: bool = true

const HealthCompClass = preload("res://scripts/components/health_component.gd")
const FuelCompClass = preload("res://scripts/components/fuel_component.gd")
const ProgCompClass = preload("res://scripts/components/progression_component.gd")

@onready var health_component: Node = $HealthComponent
@onready var fuel_component: Node = $FuelComponent
@onready var progression_component: Node = $ProgressionComponent

@onready var visual_root: Node3D = $VisualRoot
@onready var helicopter_visual: Node3D = $VisualRoot/PlayerHelicopterVisual
@onready var muzzle_raycast: RayCast3D = $MuzzleRayCast

var joystick_input: Vector2 = Vector2.ZERO
var is_alive: bool = true

func _ready() -> void:
	add_to_group("player")
	add_to_group("PlayerHeli")
	
	# Layer 1: Player (1), Mask 2: Environment (2), Mask 3: Enemy (4), Mask 5: EnemyProjectile (16)
	collision_layer = 1
	collision_mask = 22
	
	flight_altitude = global_position.y
	
	if health_component and health_component.has_signal("died"):
		health_component.died.connect(_on_death)
	if fuel_component and fuel_component.has_signal("fuel_depleted"):
		fuel_component.fuel_depleted.connect(_on_death)

func update_input(vector: Vector2) -> void:
	joystick_input = vector

func _process(delta: float) -> void:
	if not is_alive:
		return
	
	# Weapon cooldown & continuous fire on button hold
	fire_timer = maxf(0.0, fire_timer - delta)
	if (Input.is_action_pressed("shoot") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and fire_timer <= 0.0:
		shoot()

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	
	# 1. Read Raw 2D Input (WASD or Virtual Joystick)
	var input_2d = joystick_input
	if input_2d.length_squared() < 0.01:
		input_2d = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# 2. Get Camera-Relative Basis Projected on X/Z Plane
	var cam = get_viewport().get_camera_3d()
	var cam_forward = Vector3.FORWARD
	var cam_right = Vector3.RIGHT
	
	if cam:
		cam_forward = -cam.global_transform.basis.z
		cam_right = cam.global_transform.basis.x
	
	cam_forward.y = 0.0
	cam_forward = cam_forward.normalized()
	cam_right.y = 0.0
	cam_right = cam_right.normalized()
	
	# 3. Convert input into Camera-Relative 3D Movement Direction
	var move_dir = (cam_right * input_2d.x) + (cam_forward * (-input_2d.y))
	if move_dir.length() > 1.0:
		move_dir = move_dir.normalized()
	
	# 4. Immediate Fast Arcade Velocity
	var target_vel_x = move_dir.x * max_speed
	var target_vel_z = move_dir.z * max_speed
	
	var accel_x = acceleration if abs(move_dir.x) > 0.01 else deceleration
	var accel_z = acceleration if abs(move_dir.z) > 0.01 else deceleration
	
	velocity.x = move_toward(velocity.x, target_vel_x, accel_x * delta)
	velocity.z = move_toward(velocity.z, target_vel_z, accel_z * delta)
	
	# 5. Lock Flight Altitude
	velocity.y = (flight_altitude - global_position.y) * altitude_responsiveness
	
	# 6. Physical Movement (Body stays strictly upright)
	move_and_slide()
	
	rotation.x = 0.0
	rotation.z = 0.0
	
	# 7. Visual Model: Banking & Smooth Yaw (Visual Only)
	_apply_visual_model(cam_right, cam_forward, delta)

func _apply_visual_model(cam_right: Vector3, cam_forward: Vector3, delta: float) -> void:
	if not visual_root:
		return
	
	var horizontal_vel = Vector3(velocity.x, 0.0, velocity.z)
	var current_speed = horizontal_vel.length()
	
	# 1. Smooth Yaw towards movement direction
	if current_speed > 0.5:
		var target_heading = atan2(-horizontal_vel.x, -horizontal_vel.z)
		var blend_yaw = 1.0 - exp(-yaw_speed * delta)
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_heading, blend_yaw)
	
	# 2. Camera-Relative Screen Banking (Max 30 deg roll, 16 deg pitch)
	var screen_vx = velocity.dot(cam_right)
	var screen_vz = velocity.dot(cam_forward)
	
	var target_roll = -clamp(screen_vx / max_speed, -1.0, 1.0) * deg_to_rad(max_bank_deg)
	var target_pitch = -clamp(screen_vz / max_speed, -1.0, 1.0) * deg_to_rad(max_pitch_deg)
	
	var blend_bank = 1.0 - exp(-bank_speed * delta)
	visual_root.rotation.z = lerp_angle(visual_root.rotation.z, target_roll, blend_bank)
	visual_root.rotation.x = lerp_angle(visual_root.rotation.x, target_pitch, blend_bank)

func shoot() -> void:
	if not is_alive:
		return
	if fire_timer > 0.0:
		return
	
	fire_timer = fire_cooldown
	
	var fire_dir = -global_transform.basis.z
	if visual_root:
		fire_dir = -visual_root.global_transform.basis.z
	
	# Alternate between Left and Right weapon mounts
	var local_mount_offset = Vector3(-0.65, -0.15, -0.8) if fire_left_next else Vector3(0.65, -0.15, -0.8)
	fire_left_next = not fire_left_next
	
	var spawn_pos = global_position + (visual_root.global_transform.basis * local_mount_offset if visual_root else local_mount_offset)
	
	# RayCast check
	if muzzle_raycast and muzzle_raycast.is_colliding():
		var collider = muzzle_raycast.get_collider()
		if collider:
			if collider.has_method("take_hit"):
				collider.take_hit(25)
			elif collider.has_method("destroy_turret"):
				collider.destroy_turret()
			elif collider.get_parent() and collider.get_parent().has_method("take_hit"):
				collider.get_parent().take_hit(25)
	
	# Spawn visible bullet
	if bullet_scene:
		var bullet = bullet_scene.instantiate()
		get_tree().root.add_child(bullet)
		bullet.global_position = spawn_pos
		if bullet.has_method("setup"):
			bullet.setup(fire_dir)

func add_fuel(amount: float = 25.0) -> void:
	if fuel_component and fuel_component.has_method("add_fuel"):
		fuel_component.add_fuel(amount)

func add_xp(amount: int = 5) -> void:
	if progression_component and progression_component.has_method("add_xp"):
		progression_component.add_xp(amount)

func heal(amount: int = 25) -> void:
	if health_component and health_component.has_method("heal"):
		health_component.heal(amount)

func take_damage(amount: int = 15) -> void:
	if health_component and health_component.has_method("take_damage"):
		health_component.take_damage(amount)

func _on_death() -> void:
	if not is_alive:
		return
	is_alive = false
	player_died.emit()
