extends CharacterBody3D
class_name PlayerHeli

signal player_died()

const ExplosionScene = preload("res://scenes/effects/explosion_effect.tscn")
const MuzzleFlashScene = preload("res://scenes/effects/muzzle_flash.tscn")

# ==============================================================================
# 🎮 TUNABLE FEEL PARAMETERS (Godot Inspector)
# ==============================================================================

@export_group("1. Horizontal Speed & Acceleration")
@export var max_speed: float = 27.0
@export var forward_acceleration: float = 48.0
@export var steering_acceleration: float = 62.0
@export var reverse_acceleration: float = 85.0
@export var coast_deceleration: float = 38.0

@export_group("2. Vertical Lift & Descent")
@export var max_rise_speed: float = 8.5
@export var max_fall_speed: float = 2.4
@export var dive_speed: float = 4.0
@export var neutral_sink_speed: float = 0.6
@export var lift_acceleration: float = 16.0
@export var sink_acceleration: float = 4.2

@export_group("3. Visual Yaw & Heading")
@export var yaw_speed: float = 7.5 # rad/sec
@export var min_yaw_velocity_threshold: float = 0.35 # m/s

@export_group("4. Visual Banking & Pitch")
@export var max_roll_deg: float = 34.0
@export var max_pitch_deg: float = 14.0
@export var bank_enter_response: float = 18.0
@export var bank_return_response: float = 9.5

@export_group("5. Cosmetic Hover Feel")
@export var cosmetic_bob_amplitude: float = 0.16
@export var cosmetic_bob_frequency: float = 3.5

@export_group("6. Weapons & Auto-Aim")
@export var bullet_scene: PackedScene = preload("res://scenes/projectiles/player_bullet.tscn")
@export var target_marker_scene: PackedScene = preload("res://scenes/effects/target_marker.tscn")
@export var fire_cooldown: float = 0.11
@export var auto_aim_radius: float = 24.0

@export_group("7. Fuel Economy")
@export var base_fuel_drain_rate: float = 2.0
@export var lift_fuel_drain_rate: float = 3.6

# ==============================================================================
# 🌲 NODE REFERENCES
# ==============================================================================

@onready var visual_yaw_root: Node3D = $VisualYawRoot
@onready var banking_root: Node3D = $VisualYawRoot/BankingRoot
@onready var hover_visual_root: Node3D = get_node_or_null("VisualYawRoot/BankingRoot/HoverVisualRoot")
@onready var player_visual: PlayerHelicopterVisual = get_node_or_null("VisualYawRoot/BankingRoot/HoverVisualRoot/PlayerHelicopterVisual")
@onready var left_muzzle: Marker3D = get_node_or_null("VisualYawRoot/BankingRoot/HoverVisualRoot/WeaponMounts/LeftGunMuzzle")
@onready var right_muzzle: Marker3D = get_node_or_null("VisualYawRoot/BankingRoot/HoverVisualRoot/WeaponMounts/RightGunMuzzle")

@onready var health_component: Node = $HealthComponent
@onready var fuel_component: Node = $FuelComponent
@onready var progression_component: Node = $ProgressionComponent

# ==============================================================================
# ⏱️ RUNTIME STATE
# ==============================================================================

var horizontal_velocity: Vector3 = Vector3.ZERO
var vertical_velocity: float = 0.0
var _prev_horizontal_velocity: Vector3 = Vector3.ZERO
var _recoil_offset_z: float = 0.0

var joystick_input: Vector2 = Vector2.ZERO
var is_alive: bool = true
var is_lifting: bool = false
var controls_locked: bool = false
var spawn_invuln_timer: float = 2.0
var distance_traveled: float = 0.0
var last_pos: Vector3 = Vector3.ZERO
var motion_time: float = 0.0

var fire_timer: float = 0.0
var fire_left_next: bool = true
var current_target: Node3D = null
var target_marker_instance: Node3D = null
var building_contact_cooldown: float = 0.0

var instakill_timer: float = 0.0
var double_coins_timer: float = 0.0

func lock_controls() -> void:
	controls_locked = true

func unlock_controls() -> void:
	controls_locked = false

func update_input(vector: Vector2) -> void:
	joystick_input = vector

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	add_to_group("player")
	add_to_group("PlayerHeli")
	
	# Floating motion mode for 3D aerial flight
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 1
	collision_mask = 22
	
	last_pos = global_position
	
	# Fallback for motion juice node naming
	if not hover_visual_root:
		hover_visual_root = get_node_or_null("VisualYawRoot/BankingRoot/MotionJuiceRoot")
	
	if health_component:
		if health_component.has_signal("health_changed"):
			health_component.health_changed.connect(func(cur, mx):
				if GameManager:
					GameManager.health = cur
					GameManager.max_health = mx
					GameManager.health_changed.emit(cur, mx)
			)
		if health_component.has_signal("died"):
			health_component.died.connect(_on_death)
			
	if fuel_component:
		if fuel_component.has_signal("fuel_changed"):
			fuel_component.fuel_changed.connect(func(cur, mx):
				if GameManager:
					GameManager.boost = cur
					GameManager.max_boost = mx
					GameManager.boost_changed.emit(cur, mx)
			)
		if fuel_component.has_signal("fuel_depleted"):
			fuel_component.fuel_depleted.connect(_on_death)
	
	if GameManager:
		var init_hp = health_component.current_health if health_component else GameManager.health
		var init_max = health_component.max_health if health_component else GameManager.max_health
		GameManager.health = init_hp
		GameManager.max_health = init_max
		GameManager.health_changed.emit(init_hp, init_max)
		
		var init_fuel = fuel_component.current_fuel if fuel_component else GameManager.boost
		var init_max_fuel = fuel_component.max_fuel if fuel_component else GameManager.max_boost
		GameManager.boost = init_fuel
		GameManager.max_boost = init_max_fuel
		GameManager.boost_changed.emit(init_fuel, init_max_fuel)
	
	var crash_detector = get_node_or_null("CrashDetector") as Area3D
	if crash_detector:
		crash_detector.body_entered.connect(_on_crash_detector_body_entered)

# ==============================================================================
# 🎮 GAMEPLAY PROCESS (Targeting, Timers & Shooting)
# ==============================================================================

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	if not is_alive:
		if target_marker_instance and is_instance_valid(target_marker_instance):
			target_marker_instance.visible = false
		return
	
	motion_time += delta
	
	# Decay cosmetic weapon recoil
	_recoil_offset_z = move_toward(_recoil_offset_z, 0.0, 1.4 * delta)
	
	# Timers
	if building_contact_cooldown > 0.0:
		building_contact_cooldown = maxf(0.0, building_contact_cooldown - delta)
	if spawn_invuln_timer > 0.0:
		spawn_invuln_timer = maxf(0.0, spawn_invuln_timer - delta)
	if instakill_timer > 0.0:
		instakill_timer = maxf(0.0, instakill_timer - delta)
	if double_coins_timer > 0.0:
		double_coins_timer = maxf(0.0, double_coins_timer - delta)
		if GameManager:
			GameManager.gold_multiplier = 2 if double_coins_timer > 0.0 else 1
	
	# Auto-Aim Target Detection
	_update_auto_aim()
	
	# Firing
	if controls_locked:
		return
		
	fire_timer = maxf(0.0, fire_timer - delta)
	if (Input.is_action_pressed("shoot") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and fire_timer <= 0.0:
		shoot()

func _update_auto_aim() -> void:
	if not is_inside_tree():
		return
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_enemy: Node3D = null
	var closest_dist: float = auto_aim_radius
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.get("is_destroyed") == true:
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= closest_dist:
			closest_dist = dist
			closest_enemy = enemy
	
	current_target = closest_enemy
	
	if current_target and is_instance_valid(current_target):
		if not target_marker_instance and target_marker_scene:
			target_marker_instance = target_marker_scene.instantiate()
			get_tree().root.add_child(target_marker_instance)
		
		if target_marker_instance:
			target_marker_instance.visible = true
			target_marker_instance.global_position = current_target.global_position + Vector3(0, 0.9, 0)
	else:
		if target_marker_instance:
			target_marker_instance.visible = false

# ==============================================================================
# 🚁 AUTHORITATIVE PHYSICS LOOP (Movement, Steering & Visuals)
# ==============================================================================

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_alive:
		return
	
	# 1. Gather Camera-Relative 360° Movement Input
	var input_2d = joystick_input
	if input_2d.length_squared() < 0.01:
		input_2d = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	var cam = get_viewport().get_camera_3d()
	var cam_forward = -cam.global_transform.basis.z if cam else Vector3.FORWARD
	var cam_right = cam.global_transform.basis.x if cam else Vector3.RIGHT
	cam_forward.y = 0.0
	cam_forward = cam_forward.normalized()
	cam_right.y = 0.0
	cam_right = cam_right.normalized()
	
	var move_dir = (cam_right * input_2d.x) + (cam_forward * (-input_2d.y))
	if move_dir.length() > 1.0:
		move_dir = move_dir.normalized()
	
	# 2. Horizontal Velocity Steering (Multi-Stage Acceleration & Counter-Steering)
	if controls_locked:
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, coast_deceleration * 1.5 * delta)
	elif move_dir.length_squared() < 0.001:
		# Released controls: gentle coast deceleration (0.4-0.7s glide to stop)
		horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, coast_deceleration * delta)
	else:
		var desired_velocity = move_dir * max_speed
		var selected_accel = forward_acceleration
		
		var cur_h_speed_sq = horizontal_velocity.length_squared()
		if cur_h_speed_sq > 0.2:
			var cur_h_dir = horizontal_velocity.normalized()
			var dot = cur_h_dir.dot(move_dir)
			
			if dot >= 0.65:
				# Holding same general direction
				selected_accel = forward_acceleration
			elif dot >= 0.0:
				# Turning sideways / curving
				selected_accel = steering_acceleration
			else:
				# Reversing / counter-steering (fast responsive dodge)
				selected_accel = reverse_acceleration
		else:
			# Starting from rest
			selected_accel = forward_acceleration
		
		# Full Vector3 steering move_toward (preserves smooth diagonal curvature)
		horizontal_velocity = horizontal_velocity.move_toward(desired_velocity, selected_accel * delta)
	
	# 3. Vertical Flight (Continuous Smooth Buoyant Lift & Descent)
	var wants_lift = not controls_locked and (Input.is_action_pressed("fly_up") or Input.is_key_pressed(KEY_SPACE))
	var wants_descend = not controls_locked and (Input.is_action_pressed("fly_down") or Input.is_key_pressed(KEY_CTRL))
	is_lifting = wants_lift
	
	var has_fuel = true
	if fuel_component and fuel_component.get("current_fuel") != null:
		has_fuel = fuel_component.current_fuel > 0.0
	elif GameManager:
		has_fuel = GameManager.boost > 0.0
	
	if wants_lift and has_fuel:
		vertical_velocity = move_toward(vertical_velocity, max_rise_speed, lift_acceleration * delta)
		_drain_fuel(lift_fuel_drain_rate * delta)
	elif wants_descend:
		# Controlled descent without plunging
		vertical_velocity = move_toward(vertical_velocity, -dive_speed, sink_acceleration * 1.5 * delta)
		_drain_fuel(base_fuel_drain_rate * delta)
	else:
		# Buoyant continuous float with very gentle settling
		vertical_velocity = move_toward(vertical_velocity, -neutral_sink_speed, sink_acceleration * delta)
		_drain_fuel(base_fuel_drain_rate * delta)
	
	# 4. Construct Authoritative Velocity & Execute Floating Physics Slide
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	velocity.y = vertical_velocity
	
	move_and_slide()
	
	# Update internal velocities from slide results for natural wall interaction
	horizontal_velocity = Vector3(velocity.x, 0.0, velocity.z)
	vertical_velocity = velocity.y
	
	# Keep base physics CharacterBody3D rotation strictly upright
	rotation = Vector3.ZERO
	
	# Track distance
	var h_dist = Vector2(global_position.x - last_pos.x, global_position.z - last_pos.z).length()
	distance_traveled += h_dist
	last_pos = global_position
	
	# 5. Apply Visual Heading, Dynamic Acceleration Banking & Cosmetic Hover
	_apply_visual_presentation(cam_right, cam_forward, delta)

func _drain_fuel(amount: float) -> void:
	if fuel_component and fuel_component.has_method("consume_fuel"):
		fuel_component.consume_fuel(amount)
	if GameManager:
		GameManager.use_boost(amount)

# ==============================================================================
# 🎨 VISUAL PRESENTATION & ROTATION (Decoupled Node Hierarchy)
# ==============================================================================

func _apply_visual_presentation(cam_right: Vector3, cam_forward: Vector3, delta: float) -> void:
	var h_speed = horizontal_velocity.length()
	
	# --- A. VisualYawRoot: Shortest-Angle Yaw Follows Actual Velocity ---
	if visual_yaw_root and h_speed > min_yaw_velocity_threshold:
		var target_yaw = atan2(-horizontal_velocity.x, -horizontal_velocity.z)
		var diff = wrapf(target_yaw - visual_yaw_root.rotation.y, -PI, PI)
		var max_step = yaw_speed * delta
		if abs(diff) <= max_step:
			visual_yaw_root.rotation.y = target_yaw
		else:
			visual_yaw_root.rotation.y += sign(diff) * max_step
	
	# --- B. BankingRoot: Roll & Pitch Driven Dominantly by Acceleration Change ---
	if banking_root:
		# Calculate actual horizontal acceleration vector
		var h_accel = (horizontal_velocity - _prev_horizontal_velocity) / maxf(0.0001, delta)
		_prev_horizontal_velocity = horizontal_velocity
		
		# Project velocity and acceleration onto screen-relative axes
		var screen_vx = horizontal_velocity.dot(cam_right) / max_speed
		var screen_vz = horizontal_velocity.dot(cam_forward) / max_speed
		
		var screen_accel_x = h_accel.dot(cam_right)
		var screen_accel_z = h_accel.dot(cam_forward)
		
		# Quick smooth tilt: direct velocity bank + snappy acceleration kick into turns
		var direct_roll = -clamp(screen_vx, -1.0, 1.0) * deg_to_rad(max_roll_deg * 0.72)
		var accel_roll = -clamp(screen_accel_x / 28.0, -1.0, 1.0) * deg_to_rad(max_roll_deg * 0.48)
		var target_roll = clamp(direct_roll + accel_roll, -deg_to_rad(max_roll_deg), deg_to_rad(max_roll_deg))
		
		# Pitch: Forward velocity dips nose down, braking/reversing pitches up
		var direct_pitch = -clamp(screen_vz, -1.0, 1.0) * deg_to_rad(max_pitch_deg * 0.65)
		var accel_pitch = -clamp(screen_accel_z / 25.0, -1.0, 1.0) * deg_to_rad(max_pitch_deg * 0.5)
		var target_pitch = clamp(direct_pitch + accel_pitch, -deg_to_rad(max_pitch_deg), deg_to_rad(max_pitch_deg))
		
		# Asymmetric fast exponential smoothing (quick enter, buttery return)
		var cur_roll = banking_root.rotation.z
		var cur_pitch = banking_root.rotation.x
		
		var roll_rate = bank_enter_response if abs(target_roll) > abs(cur_roll) else bank_return_response
		var pitch_rate = bank_enter_response if abs(target_pitch) > abs(cur_pitch) else bank_return_response
		
		banking_root.rotation.z = lerp_angle(cur_roll, target_roll, 1.0 - exp(-roll_rate * delta))
		banking_root.rotation.x = lerp_angle(cur_pitch, target_pitch, 1.0 - exp(-pitch_rate * delta))
	
	# --- C. HoverVisualRoot: Purely Cosmetic Hover Breathing (No Physics Tampering) ---
	if hover_visual_root:
		var speed_factor = clampf(h_speed / max_speed, 0.0, 1.0)
		var bob_amp = lerp(cosmetic_bob_amplitude, cosmetic_bob_amplitude * 0.35, speed_factor)
		var bob_y = sin(motion_time * cosmetic_bob_frequency) * bob_amp
		hover_visual_root.position = Vector3(0.0, bob_y, _recoil_offset_z)
	
	# --- D. Rotor Speed Scaling ---
	if player_visual and player_visual.has_method("set_rotor_boost"):
		player_visual.set_rotor_boost(is_lifting)

# ==============================================================================
# 💥 SHOOTING & WEAPONS
# ==============================================================================

func shoot() -> void:
	if not is_alive or not bullet_scene:
		return
	
	fire_timer = fire_cooldown
	
	var muzzle = left_muzzle if fire_left_next else right_muzzle
	fire_left_next = not fire_left_next
	
	var spawn_pos = muzzle.global_position if muzzle else global_position
	
	var fire_dir = Vector3.ZERO
	if current_target and is_instance_valid(current_target) and current_target.get("is_destroyed") != true:
		var target_aim_point = current_target.global_position + Vector3(0, 0.6, 0)
		fire_dir = (target_aim_point - spawn_pos).normalized()
	else:
		fire_dir = -visual_yaw_root.global_transform.basis.z if visual_yaw_root else -global_transform.basis.z
	
	# Spawn muzzle flash locked to active gun muzzle
	if MuzzleFlashScene:
		var flash = MuzzleFlashScene.instantiate()
		if muzzle:
			muzzle.add_child(flash)
			flash.position = Vector3.ZERO
			flash.rotation = Vector3.ZERO
		else:
			get_tree().root.add_child(flash)
			flash.global_position = spawn_pos
			if fire_dir.length_squared() > 0.001:
				var up_v = Vector3.UP if abs(fire_dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
				flash.look_at(spawn_pos + fire_dir, up_v)
	
	# Spawn bullet tracer in world space
	var bullet = bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	bullet.global_position = spawn_pos
	
	var damage = 9999 if instakill_timer > 0.0 else 10
	if bullet.has_method("setup"):
		bullet.setup(fire_dir, damage)
	
	# Snappy cosmetic recoil kick
	_recoil_offset_z = 0.08
	
	var cam_rig = get_parent().get_node_or_null("CameraRig") if get_parent() else null
	if cam_rig and cam_rig.has_method("add_shake"):
		cam_rig.add_shake(0.04)

# ==============================================================================
# 🛡️ POWERUPS, HEALTH & DAMAGE
# ==============================================================================

func apply_powerup(type: String, duration: float = 10.0) -> void:
	match type:
		"INSTAKILL":
			instakill_timer = duration
			if GameManager:
				GameManager.notification_triggered.emit("INSTAKILL ACTIVE (10s)!")
		"DOUBLE_COINS":
			double_coins_timer = duration
			if GameManager:
				GameManager.gold_multiplier = 2
				GameManager.notification_triggered.emit("2X COINS ACTIVE (15s)!")
		"NUKE":
			_trigger_nuke()

func _trigger_nuke() -> void:
	var turrets = get_tree().get_nodes_in_group("enemies")
	for t in turrets:
		if is_instance_valid(t) and t.has_method("destroy_turret"):
			var dist = global_position.distance_to(t.global_position)
			if dist <= 55.0:
				t.destroy_turret()
	
	var bullets = get_tree().get_nodes_in_group("enemy_projectiles")
	for b in bullets:
		if is_instance_valid(b):
			b.queue_free()

func add_fuel(amount: float = 35.0) -> void:
	if fuel_component and fuel_component.has_method("add_fuel"):
		fuel_component.add_fuel(amount)
	if GameManager:
		GameManager.add_boost(amount)

func add_xp(amount: int = 5) -> void:
	if progression_component and progression_component.has_method("add_xp"):
		progression_component.add_xp(amount)
	if GameManager:
		GameManager.add_xp(amount)

func heal(amount: int = 25) -> void:
	if not is_alive or amount <= 0:
		return
	if health_component and health_component.has_method("heal"):
		health_component.heal(amount)
	elif GameManager:
		GameManager.health = mini(GameManager.max_health, GameManager.health + amount)
		GameManager.health_changed.emit(GameManager.health, GameManager.max_health)

func take_damage(amount: int = 15) -> void:
	if not is_alive or spawn_invuln_timer > 0.0 or amount <= 0:
		return
		
	if health_component and health_component.has_method("take_damage"):
		health_component.take_damage(amount)
	elif GameManager:
		GameManager.health = max(0, GameManager.health - amount)
		GameManager.health_changed.emit(GameManager.health, GameManager.max_health)
	
	var cam_rig = get_parent().get_node_or_null("CameraRig") if get_parent() else null
	if cam_rig and cam_rig.has_method("add_shake"):
		cam_rig.add_shake(0.35)
	
	var curr_hp = health_component.current_health if health_component else (GameManager.health if GameManager else 0)
	if curr_hp <= 0:
		crash()

func _on_crash_detector_body_entered(body: Node3D) -> void:
	if not is_alive or controls_locked or spawn_invuln_timer > 0.0:
		return
	
	if (body.collision_layer & 2) != 0 or body.is_in_group("environment") or body.is_in_group("buildings") or body.has_method("get_roof_y"):
		if building_contact_cooldown <= 0.0:
			building_contact_cooldown = 0.8
			take_damage(15)

func crash() -> void:
	if not is_alive:
		return
	is_alive = false
	
	if target_marker_instance and is_instance_valid(target_marker_instance):
		target_marker_instance.queue_free()
		target_marker_instance = null
	
	if ExplosionScene:
		var boom = ExplosionScene.instantiate()
		get_tree().root.add_child(boom)
		boom.global_position = global_position
	
	if visual_yaw_root:
		visual_yaw_root.visible = false
	
	player_died.emit()

func _on_death() -> void:
	crash()
