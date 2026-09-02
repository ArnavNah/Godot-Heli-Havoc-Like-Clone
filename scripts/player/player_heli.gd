extends CharacterBody3D
class_name PlayerHeli

signal player_died()

const ExplosionScene = preload("res://scenes/effects/explosion_effect.tscn")
const MuzzleFlashScene = preload("res://scenes/effects/muzzle_flash.tscn")

@export_group("360-Degree Horizontal Flight")
@export var horizontal_speed: float = 30.0
var max_speed: float:
	get: return horizontal_speed
	set(v): horizontal_speed = v
@export var acceleration: float = 110.0
@export var braking: float = 130.0

@export_group("Vertical Rotor / Lift Mechanics")
@export var lift_force: float = 22.0
@export var sink_force: float = 10.0
@export var max_rise_speed: float = 12.0
@export var max_fall_speed: float = 9.0
@export var min_height: float = 7.0
@export var max_height: float = 34.0

@export_group("Visual Banking & Dynamic Motion")
@export var max_bank_deg: float = 42.0
@export var max_pitch_deg: float = 15.0
@export var yaw_turn_speed: float = 10.0 # ~10 rad/sec
@export var bank_responsiveness: float = 12.0
@export var hover_bob_amplitude: float = 0.12
@export var hover_bob_frequency: float = 4.2

@export_group("Physics Tilt & Air Feel")
## How much the tilt overshoots target angle during quick direction changes (0 = none, 1 = doubles)
@export_range(0.0, 1.5) var tilt_overshoot: float = 0.35
## Speed at which overshoot decays back to true angle (higher = snappier recovery)
@export var overshoot_recovery: float = 6.0
## Extra nose-pitch degrees when rising or sinking vertically
@export var vertical_pitch_deg: float = 8.0
## Extra nose-pitch from horizontal acceleration/deceleration
@export var accel_pitch_deg: float = 6.0
## Subtle oscillating micro-tilt amplitude simulating rotor wash turbulence
@export var rotor_wash_amplitude: float = 0.6
## Frequency of rotor wash oscillation (Hz-ish)
@export var rotor_wash_frequency: float = 3.7
## How much altitude proximity to ground compresses the hover bob (settling feel)
@export var ground_settle_range: float = 3.0

@export_group("Weapons & Shooting")
@export var bullet_scene: PackedScene = preload("res://scenes/projectiles/player_bullet.tscn")
@export var fire_cooldown: float = 0.11 # 9 shots per second
var fire_timer: float = 0.0
var fire_left_next: bool = true

@export_group("Fuel Consumption")
@export var base_fuel_drain_rate: float = 2.2 # per second
@export var lift_fuel_drain_rate: float = 4.2 # per second while lifting

# Node References
@onready var visual_yaw_root: Node3D = $VisualYawRoot
@onready var banking_root: Node3D = $VisualYawRoot/BankingRoot
@onready var motion_juice_root: Node3D = $VisualYawRoot/BankingRoot/MotionJuiceRoot
@onready var player_visual: PlayerHelicopterVisual = get_node_or_null("VisualYawRoot/BankingRoot/MotionJuiceRoot/PlayerHelicopterVisual")
@onready var left_muzzle: Marker3D = get_node_or_null("VisualYawRoot/BankingRoot/MotionJuiceRoot/WeaponMounts/LeftGunMuzzle")
@onready var right_muzzle: Marker3D = get_node_or_null("VisualYawRoot/BankingRoot/MotionJuiceRoot/WeaponMounts/RightGunMuzzle")

@onready var health_component: Node = $HealthComponent
@onready var fuel_component: Node = $FuelComponent
@onready var progression_component: Node = $ProgressionComponent

# Runtime State
var vertical_velocity: float = 0.0
var joystick_input: Vector2 = Vector2.ZERO
var is_alive: bool = true
var is_lifting: bool = false
var distance_traveled: float = 0.0
var last_pos: Vector3 = Vector3.ZERO
var motion_time: float = 0.0

# Physics Tilt State (momentum & air feel)
var _prev_h_velocity: Vector3 = Vector3.ZERO  # previous frame horizontal velocity for accel detection
var _overshoot_roll: float = 0.0  # accumulated roll overshoot from sudden direction changes
var _overshoot_pitch: float = 0.0  # accumulated pitch overshoot
var _smoothed_vert_vel: float = 0.0  # smoothed vertical velocity for nose tilt

@export_group("Auto-Aim Targeting")
@export var auto_aim_radius: float = 20.0
@export var target_marker_scene: PackedScene = preload("res://scenes/effects/target_marker.tscn")
var current_target: Node3D = null
var target_marker_instance: Node3D = null
var building_contact_cooldown_timer: float = 0.0

# Powerup Active Timers
var instakill_timer: float = 0.0
var double_coins_timer: float = 0.0
var controls_locked: bool = false
var spawn_invuln_timer: float = 2.5

func lock_controls() -> void:
	controls_locked = true

func unlock_controls() -> void:
	controls_locked = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	add_to_group("player")
	add_to_group("PlayerHeli")
	
	collision_layer = 1
	collision_mask = 22
	
	if global_position.y < min_height:
		global_position.y = 18.0
	
	last_pos = global_position
	
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
	
	# Initial sync of health and fuel
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

func update_input(vector: Vector2) -> void:
	joystick_input = vector

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	if not is_alive:
		if target_marker_instance and is_instance_valid(target_marker_instance):
			target_marker_instance.visible = false
		return
	
	motion_time += delta
	
	# Building contact cooldown
	if building_contact_cooldown_timer > 0.0:
		building_contact_cooldown_timer = maxf(0.0, building_contact_cooldown_timer - delta)
	
	# Spawn invulnerability countdown
	if spawn_invuln_timer > 0.0:
		spawn_invuln_timer = maxf(0.0, spawn_invuln_timer - delta)
		
	# Powerup countdowns
	if instakill_timer > 0.0:
		instakill_timer = maxf(0.0, instakill_timer - delta)
	if double_coins_timer > 0.0:
		double_coins_timer = maxf(0.0, double_coins_timer - delta)
		if GameManager:
			GameManager.gold_multiplier = 2 if double_coins_timer > 0.0 else 1
	
	# Auto-Aim Target Detection (closest turret within 20m)
	_update_auto_aim()
	
	# Weapon firing
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
	
	# Update visual target reticle
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

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	if not is_alive:
		return
	
	if controls_locked:
		velocity = velocity.move_toward(Vector3.ZERO, braking * delta)
		move_and_slide()
		var cam_ref = get_viewport().get_camera_3d()
		var r_vec = cam_ref.global_transform.basis.x if cam_ref else Vector3.RIGHT
		var f_vec = -cam_ref.global_transform.basis.z if cam_ref else Vector3.FORWARD
		r_vec.y = 0; f_vec.y = 0
		_apply_dynamic_visuals(r_vec.normalized(), f_vec.normalized(), delta)
		return
	
	# --- 1. HORIZONTAL 360-DEGREE MOVEMENT (WASD / 2D VIRTUAL JOYSTICK) ---
	var input_2d = joystick_input
	if input_2d.length_squared() < 0.01:
		input_2d = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Project onto camera-relative XZ basis
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
	
	# Normalize diagonal movement so diagonals are not faster
	var move_dir = (cam_right * input_2d.x) + (cam_forward * (-input_2d.y))
	if move_dir.length() > 1.0:
		move_dir = move_dir.normalized()
	
	var desired_velocity = move_dir * horizontal_speed
	
	var accel_x = acceleration if abs(move_dir.x) > 0.01 else braking
	var accel_z = acceleration if abs(move_dir.z) > 0.01 else braking
	
	velocity.x = move_toward(velocity.x, desired_velocity.x, accel_x * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, accel_z * delta)
	
	# --- 2. VERTICAL ROTOR LIFT MECHANIC (SPACE / ALTITUDE) ---
	var wants_lift = Input.is_action_pressed("fly_up") or Input.is_key_pressed(KEY_SPACE)
	var wants_fast_descend = Input.is_action_pressed("fly_down") or Input.is_key_pressed(KEY_CTRL)
	is_lifting = wants_lift
	
	# Fuel check: if out of fuel, cannot lift
	var has_fuel = true
	if fuel_component and fuel_component.get("current_fuel") != null:
		has_fuel = fuel_component.current_fuel > 0.0
	elif GameManager:
		has_fuel = GameManager.boost > 0.0
	
	if wants_lift and has_fuel:
		vertical_velocity = move_toward(vertical_velocity, max_rise_speed, lift_force * delta)
		_drain_fuel(lift_fuel_drain_rate * delta)
	elif wants_fast_descend:
		vertical_velocity = move_toward(vertical_velocity, -max_fall_speed * 1.5, sink_force * 2.2 * delta)
		_drain_fuel(base_fuel_drain_rate * delta)
	else:
		# Gentle arcade sink
		vertical_velocity = move_toward(vertical_velocity, -max_fall_speed, sink_force * delta)
		_drain_fuel(base_fuel_drain_rate * delta)
	
	velocity.y = vertical_velocity
	
	# --- 3. EXECUTE PHYSICAL MOVEMENT (SLIDING ON WALLS) ---
	move_and_slide()
	
	# Altitude bounds clamping
	if global_position.y <= min_height:
		global_position.y = min_height
		vertical_velocity = maxf(0.0, vertical_velocity)
	elif global_position.y >= max_height:
		global_position.y = max_height
		vertical_velocity = minf(0.0, vertical_velocity)
	
	# Strictly keep CharacterBody3D rotation upright
	rotation = Vector3.ZERO
	
	# Track distance
	var h_dist = Vector2(global_position.x - last_pos.x, global_position.z - last_pos.z).length()
	distance_traveled += h_dist
	last_pos = global_position
	
	# --- 4. DYNAMIC VISUAL MOTION & HELICOPTER JUICE ---
	_apply_dynamic_visuals(cam_right, cam_forward, delta)

func _drain_fuel(amount: float) -> void:
	if fuel_component and fuel_component.has_method("consume_fuel"):
		fuel_component.consume_fuel(amount)
	if GameManager:
		GameManager.use_boost(amount)

func _apply_dynamic_visuals(cam_right: Vector3, cam_forward: Vector3, delta: float) -> void:
	var h_vel = Vector3(velocity.x, 0.0, velocity.z)
	var speed = h_vel.length()
	
	# 1. VisualYawRoot: Shortest-angle interpolation without ±PI snapping
	#    Added yaw lag — faster movement = slightly slower yaw catch-up for a skid feel
	if visual_yaw_root and speed > 0.5:
		var target_yaw = atan2(-h_vel.x, -h_vel.z)
		var yaw_speed = yaw_turn_speed * clampf(1.3 - (speed / horizontal_speed) * 0.4, 0.6, 1.3)
		visual_yaw_root.rotation.y = rotate_toward(visual_yaw_root.rotation.y, target_yaw, yaw_speed * delta)
	
	# 2. BankingRoot: Physics-based Roll and Pitch
	if banking_root:
		var screen_vx = velocity.dot(cam_right)
		var screen_vz = velocity.dot(cam_forward)
		
		# --- Base tilt from velocity direction ---
		var target_roll = -clamp(screen_vx / horizontal_speed, -1.0, 1.0) * deg_to_rad(max_bank_deg)
		var target_pitch = -clamp(screen_vz / horizontal_speed, -1.0, 1.0) * deg_to_rad(max_pitch_deg)
		
		# --- A. Momentum Overshoot (inertia on direction changes) ---
		# Detect horizontal acceleration by comparing current vs previous frame velocity
		var h_accel = (h_vel - _prev_h_velocity) / maxf(delta, 0.001)
		var accel_screen_x = h_accel.dot(cam_right)  # lateral acceleration
		var accel_screen_z = h_accel.dot(cam_forward)  # forward/back acceleration
		
		# Accumulate overshoot proportional to lateral acceleration spikes
		_overshoot_roll += -clamp(accel_screen_x / (acceleration * 0.5), -1.0, 1.0) * tilt_overshoot * deg_to_rad(max_bank_deg) * delta * 3.0
		_overshoot_pitch += -clamp(accel_screen_z / (acceleration * 0.5), -1.0, 1.0) * tilt_overshoot * deg_to_rad(max_pitch_deg) * delta * 3.0
		
		# Clamp overshoot so it doesn't go wild
		_overshoot_roll = clamp(_overshoot_roll, -deg_to_rad(max_bank_deg * 0.5), deg_to_rad(max_bank_deg * 0.5))
		_overshoot_pitch = clamp(_overshoot_pitch, -deg_to_rad(max_pitch_deg * 0.8), deg_to_rad(max_pitch_deg * 0.8))
		
		# Decay overshoot back toward zero (spring recovery)
		_overshoot_roll = move_toward(_overshoot_roll, 0.0, abs(_overshoot_roll) * overshoot_recovery * delta + 0.05 * delta)
		_overshoot_pitch = move_toward(_overshoot_pitch, 0.0, abs(_overshoot_pitch) * overshoot_recovery * delta + 0.05 * delta)
		
		target_roll += _overshoot_roll
		target_pitch += _overshoot_pitch
		
		# --- B. Vertical Velocity Nose Tilt ---
		# Smooth the vertical velocity to prevent jittery tilt
		_smoothed_vert_vel = move_toward(_smoothed_vert_vel, vertical_velocity, 18.0 * delta)
		var vert_ratio = clamp(_smoothed_vert_vel / max_rise_speed, -1.0, 1.0)
		target_pitch += vert_ratio * deg_to_rad(vertical_pitch_deg)
		
		# --- C. Acceleration Surge Pitch ---
		# When player is accelerating forward, helicopter dips its nose; when braking, it rears back
		var forward_accel_ratio = clamp(accel_screen_z / acceleration, -1.0, 1.0)
		target_pitch += -forward_accel_ratio * deg_to_rad(accel_pitch_deg) * 0.3
		
		# --- D. Rotor Wash Micro-Turbulence ---
		# Subtle multi-frequency oscillating tilt simulating unsteady air under the rotor disc
		var wash_roll = sin(motion_time * rotor_wash_frequency * TAU) * deg_to_rad(rotor_wash_amplitude)
		wash_roll += sin(motion_time * rotor_wash_frequency * 1.7 * TAU) * deg_to_rad(rotor_wash_amplitude * 0.4)
		var wash_pitch = cos(motion_time * rotor_wash_frequency * 0.8 * TAU) * deg_to_rad(rotor_wash_amplitude * 0.6)
		
		# Scale turbulence down when moving fast (laminar-ish flow) and up when hovering
		var turbulence_scale = clampf(1.0 - speed / (horizontal_speed * 0.7), 0.2, 1.0)
		target_roll += wash_roll * turbulence_scale
		target_pitch += wash_pitch * turbulence_scale
		
		# --- Apply with exponential smoothing ---
		var bank_weight = 1.0 - exp(-bank_responsiveness * delta)
		banking_root.rotation.z = lerp_angle(banking_root.rotation.z, target_roll, bank_weight)
		banking_root.rotation.x = lerp_angle(banking_root.rotation.x, target_pitch, bank_weight)
	
	# Store current horizontal velocity for next frame's acceleration detection
	_prev_h_velocity = h_vel
	
	# 3. MotionJuiceRoot: Hover Bobbing & Mechanical Shudder with Ground Settle
	if motion_juice_root:
		# Ground proximity compression: reduce bob amplitude near min_height for a "settling" feel
		var altitude_above_min = global_position.y - min_height
		var settle_factor = clampf(altitude_above_min / ground_settle_range, 0.1, 1.0)
		
		var bob_y = sin(motion_time * hover_bob_frequency) * hover_bob_amplitude * settle_factor
		
		# Mechanical shudder intensifies with speed
		var shudder_intensity = lerpf(0.008, 0.018, clampf(speed / horizontal_speed, 0.0, 1.0))
		var shudder_x = sin(motion_time * 32.0) * shudder_intensity
		var shudder_z = cos(motion_time * 28.0) * shudder_intensity
		
		# Add a micro vertical dip when near ground settle range (cushion compression)
		var cushion_dip = 0.0
		if altitude_above_min < ground_settle_range:
			cushion_dip = -sin(motion_time * 2.5) * 0.04 * (1.0 - settle_factor)
		
		motion_juice_root.position = Vector3(shudder_x, bob_y + cushion_dip, shudder_z)
	
	# 4. Rotor RPM scaling
	if player_visual and player_visual.has_method("set_rotor_boost"):
		player_visual.set_rotor_boost(is_lifting)

func shoot() -> void:
	if not is_alive or not bullet_scene:
		return
	
	fire_timer = fire_cooldown
	
	var muzzle = left_muzzle if fire_left_next else right_muzzle
	fire_left_next = not fire_left_next
	
	var spawn_pos = muzzle.global_position if muzzle else global_position
	
	# Auto-aim directed projectile:
	# If a turret is targeted within 20m, bullets travel directly toward its hurtbox!
	# If no target exists, fire straight forward.
	var fire_dir = Vector3.ZERO
	if current_target and is_instance_valid(current_target) and current_target.get("is_destroyed") != true:
		var target_aim_point = current_target.global_position + Vector3(0, 0.6, 0)
		fire_dir = (target_aim_point - spawn_pos).normalized()
	else:
		fire_dir = -visual_yaw_root.global_transform.basis.z if visual_yaw_root else -global_transform.basis.z
	
	# Spawn vibrant Muzzle Flash effect at gun barrel
	if MuzzleFlashScene:
		var flash = MuzzleFlashScene.instantiate()
		get_tree().root.add_child(flash)
		flash.global_position = spawn_pos
		if fire_dir.length_squared() > 0.01:
			flash.look_at(spawn_pos + fire_dir, Vector3.UP)
	
	var bullet = bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	bullet.global_position = spawn_pos
	
	var damage = 9999 if instakill_timer > 0.0 else 10
	if bullet.has_method("setup"):
		bullet.setup(fire_dir, damage)
	
	# Tactical micro-punch and camera feedback
	var cam_rig = get_parent().get_node_or_null("CameraRig") if get_parent() else null
	if cam_rig and cam_rig.has_method("add_shake"):
		cam_rig.add_shake(0.04)

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
		GameManager.health = maxi(0, GameManager.health - amount)
		GameManager.health_changed.emit(GameManager.health, GameManager.max_health)
	
	# Trigger camera shake on taking damage
	var cam_rig = get_parent().get_node_or_null("CameraRig")
	if cam_rig and cam_rig.has_method("add_shake"):
		cam_rig.add_shake(0.35)
	
	# Immediately crash ONLY if health drops to 0 or below
	var curr_hp = health_component.current_health if health_component else (GameManager.health if GameManager else 0)
	if curr_hp <= 0:
		crash()

func _on_crash_detector_body_entered(body: Node3D) -> void:
	if not is_alive or controls_locked or spawn_invuln_timer > 0.0:
		return
	
	# Only react to environment obstacles (Layer 2)
	if (body.collision_layer & 2) != 0 or body.is_in_group("environment") or body.is_in_group("buildings") or body is Building:
		# Apply damage once with a short cooldown, never instant kill
		if building_contact_cooldown_timer <= 0.0:
			building_contact_cooldown_timer = 0.8
			take_damage(15)

func crash() -> void:
	if not is_alive:
		return
	is_alive = false
	
	# Hide target marker
	if target_marker_instance and is_instance_valid(target_marker_instance):
		target_marker_instance.queue_free()
		target_marker_instance = null
	
	# Spawn Explosion Effect
	if ExplosionScene:
		var exp_effect = ExplosionScene.instantiate()
		get_tree().root.add_child(exp_effect)
		exp_effect.global_position = global_position
	
	# Hide visual helicopter
	if visual_yaw_root:
		visual_yaw_root.visible = false
	
	# Disable physical collisions safely deferred
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	
	# Trigger camera shake
	var cam_rig = get_parent().get_node_or_null("CameraRig")
	if cam_rig and cam_rig.has_method("add_shake"):
		cam_rig.add_shake(1.0)
	
	player_died.emit()
	
	# Freeze gameplay process mode safely deferred
	set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)

func _on_death() -> void:
	crash()
