@tool
extends RigidBody3D
class_name PlayerHeli

signal player_died()

const ExplosionScene = preload("res://scenes/effects/explosion_effect.tscn")
const MuzzleFlashScene = preload("res://scenes/effects/muzzle_flash.tscn")

# ==============================================================================
# 🎮 EXPOSED TUNING PARAMETERS (Godot Inspector)
# ==============================================================================

@export_group("1. Mass & Lift Forces")
@export var mass_kg: float = 60.0
@export var base_lift_ratio: float = 0.98 # Nearly counters gravity for a gentle neutral descent
@export var collective_strength: float = 1.65 # Climb thrust multiplier when holding Space
@export var altitude_assist_strength: float = 140.0 # Sticky collective dampening during hover
@export var dive_lift_ratio: float = 0.25 # Thrust reduction when actively holding descend

@export_group("2. Horizontal Propulsion & Drag")
@export var forward_acceleration: float = 250.0 # Exaggerates tilted-rotor thrust for arcade response
@export var reverse_acceleration: float = 90.0 # Extra counter-steering brake in m/s²
@export var horizontal_drag: float = 1.35 # Air-drag coefficient; preserves a short amount of inertia
@export var max_speed: float = 42.0 # Horizontal top speed in m/s

@export_group("3. Cyclic Pitch, Roll & Yaw Torque")
@export var pitch_torque: float = 2300.0
@export var roll_torque: float = 2700.0
@export var yaw_torque: float = 1800.0
@export var max_pitch_deg: float = 18.0 # Target forward pitch ~12-18 deg
@export var max_reverse_pitch_deg: float = 11.0 # Target backward pitch ~8-12 deg
@export var max_roll_deg: float = 28.0 # Target roll ~20-30 deg

@export_group("4. Auto Stabilization & Limits")
@export var stabilization_strength: float = 24.0 # Physical leveling torque strength
@export var angular_damping: float = 6.0
@export var max_rise_speed: float = 10.0
@export var max_fall_speed: float = 7.5

@export_group("5. Weapons & Auto-Aim")
@export var bullet_scene: PackedScene = preload("res://scenes/projectiles/player_bullet.tscn")
@export var target_marker_scene: PackedScene = preload("res://scenes/effects/target_marker.tscn")
@export var fire_cooldown: float = 0.11
@export var auto_aim_radius: float = 24.0

@export_group("6. Fuel Economy")
@export var base_fuel_drain_rate: float = 2.0
@export var lift_fuel_drain_rate: float = 3.6

# ==============================================================================
# 🌲 NODE REFERENCES
# ==============================================================================

@onready var visual_heli: PlayerHelicopterVisual = get_node_or_null("HelicopterVisual")
@onready var left_muzzle: Marker3D = get_node_or_null("WeaponMounts/LeftGunMuzzle")
@onready var right_muzzle: Marker3D = get_node_or_null("WeaponMounts/RightGunMuzzle")
@onready var left_flash: MuzzleFlash = get_node_or_null("WeaponMounts/LeftGunMuzzle/MuzzleFlash")
@onready var right_flash: MuzzleFlash = get_node_or_null("WeaponMounts/RightGunMuzzle/MuzzleFlash")

@onready var health_component: Node = $HealthComponent
@onready var fuel_component: Node = $FuelComponent
@onready var progression_component: Node = $ProgressionComponent

# Backwards compatibility getters for test suites & inspection
var visual_yaw_root: Node3D:
	get:
		return self
var banking_root: Node3D:
	get:
		return self

# ==============================================================================
# ⏱️ RUNTIME STATE
# ==============================================================================

var joystick_input: Vector2 = Vector2.ZERO
var is_alive: bool = true
var is_lifting: bool = false
var controls_locked: bool = false
var is_simulating_in_test: bool = false
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
	mass = mass_kg
	
	if Engine.is_editor_hint() and not is_simulating_in_test:
		return
	
	add_to_group("player")
	add_to_group("PlayerHeli")
	
	collision_layer = 1
	collision_mask = 22
	
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
# 🎮 GAMEPLAY PROCESS (Targeting, Shooting & Timers)
# ==============================================================================

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not is_simulating_in_test:
		return
		
	if not is_alive:
		if target_marker_instance and is_instance_valid(target_marker_instance):
			target_marker_instance.visible = false
		return
	
	motion_time += delta
	
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
	
	# Track distance traveled
	var frame_dist = global_position.distance_to(last_pos)
	if frame_dist < 10.0:
		distance_traveled += frame_dist
	last_pos = global_position
	
	# Auto-targeting remains independent of the fire trigger.
	_update_targeting()
	
	var fire_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var current_fire_rate = fire_cooldown / (GameManager.get_stat_multiplier("fire_rate") if GameManager else 1.0)
	fire_timer = maxf(0.0, fire_timer - delta)
	if not controls_locked and fire_held and fire_timer <= 0.0:
		shoot()
		fire_timer = current_fire_rate
	elif not fire_held:
		# A fresh click fires immediately, and releasing stops fire this frame.
		fire_timer = 0.0

	# Target marker visual
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
# 🚁 ASSISTED RIGIDBODY FLIGHT FORCES (Integrate Forces)
# ==============================================================================

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if (Engine.is_editor_hint() and not is_simulating_in_test) or not is_alive:
		return
	
	var dt = state.step
	if dt <= 0.0:
		dt = 0.016
		
	var basis = state.transform.basis.orthonormalized()
	var local_up = basis.y
	var local_forward = -basis.z
	var local_right = basis.x
	
	# --------------------------------------------------------------------------
	# 1. Camera-Relative Input Reading (Keyboard WASD + Virtual Joystick)
	# --------------------------------------------------------------------------
	var input_2d = joystick_input
	if input_2d.length_squared() < 0.01:
		input_2d = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() and get_viewport() else null
	var cam_forward = -cam.global_transform.basis.z if cam else Vector3.FORWARD
	var cam_right = cam.global_transform.basis.x if cam else Vector3.RIGHT
	cam_forward.y = 0.0
	cam_forward = cam_forward.normalized()
	cam_right.y = 0.0
	cam_right = cam_right.normalized()
	
	var move_dir = (cam_right * input_2d.x) + (cam_forward * (-input_2d.y))
	if move_dir.length() > 1.0:
		move_dir = move_dir.normalized()
	
	var wants_lift = not controls_locked and (
		Input.is_action_pressed("fly_up") 
		or Input.is_key_pressed(KEY_SPACE) 
		or Input.is_key_pressed(KEY_UP)
	)
	var wants_descend = not controls_locked and (
		Input.is_action_pressed("fly_down") 
		or Input.is_key_pressed(KEY_CTRL) 
		or Input.is_key_pressed(KEY_SHIFT) 
		or Input.is_key_pressed(KEY_C) 
		or Input.is_key_pressed(KEY_DOWN)
	)
	is_lifting = wants_lift
	
	# Safety unlock if player is commanding movement
	if controls_locked and (move_dir.length_squared() > 0.05 or wants_lift) and motion_time > 3.0:
		controls_locked = false
	
	var has_fuel = true
	if fuel_component and fuel_component.get("current_fuel") != null:
		has_fuel = fuel_component.current_fuel > 0.0
	elif GameManager:
		has_fuel = GameManager.boost > 0.0
	
	# --------------------------------------------------------------------------
	# 2. Horizontal thrust comes from the physically tilted rotor axis.
	# The multiplier is deliberately exaggerated so 12-28 degree cyclic tilt
	# still produces fast arcade acceleration instead of simulator-like drift.
	# --------------------------------------------------------------------------
	var h_vel = Vector3(state.linear_velocity.x, 0.0, state.linear_velocity.z)
	var cyclic_horizontal = Vector3(local_up.x, 0.0, local_up.z)
	state.apply_central_force(cyclic_horizontal * forward_acceleration * mass)
	state.apply_central_force(-h_vel * horizontal_drag * mass)

	# Strong braking only when the pilot asks for the opposite direction.
	if not controls_locked and move_dir.length_squared() > 0.01 and h_vel.length_squared() > 1.0:
		var steering_alignment = h_vel.normalized().dot(move_dir.normalized())
		if steering_alignment < 0.0:
			var counter_amount = -steering_alignment
			state.apply_central_force(-h_vel.normalized() * reverse_acceleration * counter_amount * mass)

	if h_vel.length() > max_speed:
		var limited_h_vel = h_vel.normalized() * max_speed
		state.linear_velocity.x = limited_h_vel.x
		state.linear_velocity.z = limited_h_vel.z
	
	# --------------------------------------------------------------------------
	# 3. Continuous Rotor Lift along Local Up Axis
	# --------------------------------------------------------------------------
	var gravity_mag = state.total_gravity.length()
	if gravity_mag < 0.1:
		gravity_mag = 9.8
	var weight = mass * gravity_mag
	
	var lift_mult = base_lift_ratio
	if wants_lift and has_fuel:
		lift_mult = collective_strength
		_drain_fuel(lift_fuel_drain_rate * dt)
	elif wants_descend:
		lift_mult = dive_lift_ratio
		_drain_fuel(base_fuel_drain_rate * dt)
	else:
		lift_mult = base_lift_ratio
		_drain_fuel(base_fuel_drain_rate * dt)
	
	var total_lift = weight * lift_mult
	state.apply_central_force(local_up * total_lift)
	
	# Altitude assist / sticky collective near hover
	if not wants_lift and not wants_descend:
		if abs(state.linear_velocity.y) < 2.0:
			var alt_assist = -state.linear_velocity.y * altitude_assist_strength
			state.apply_central_force(Vector3.UP * alt_assist)
	
	# Cap maximum vertical rise & fall speed
	state.linear_velocity.y = clampf(state.linear_velocity.y, -max_fall_speed, max_rise_speed)
	
	# --------------------------------------------------------------------------
	# 4. Physical cyclic pitch and roll. Input selects a target attitude in the
	# helicopter's yaw frame; PD torque leans the actual RigidBody toward it.
	# --------------------------------------------------------------------------
	var flat_forward = Vector3(local_forward.x, 0.0, local_forward.z)
	var flat_right = Vector3(local_right.x, 0.0, local_right.z)
	if flat_forward.length_squared() < 0.01:
		flat_forward = Vector3.FORWARD
	else:
		flat_forward = flat_forward.normalized()
	if flat_right.length_squared() < 0.01:
		flat_right = Vector3.RIGHT
	else:
		flat_right = flat_right.normalized()

	var forward_input = move_dir.dot(flat_forward) if not controls_locked else 0.0
	var right_input = move_dir.dot(flat_right) if not controls_locked else 0.0
	var target_pitch = 0.0
	if forward_input > 0.0:
		target_pitch = deg_to_rad(-max_pitch_deg) * forward_input
	elif forward_input < 0.0:
		target_pitch = deg_to_rad(max_reverse_pitch_deg) * -forward_input
	var target_roll = deg_to_rad(-max_roll_deg) * right_input

	var current_pitch = asin(clampf(local_forward.y, -1.0, 1.0))
	var current_roll = asin(clampf(local_right.y, -1.0, 1.0))
	var pitch_gain = pitch_torque if abs(forward_input) > 0.02 else stabilization_strength * mass
	var roll_gain = roll_torque if abs(right_input) > 0.02 else stabilization_strength * mass
	var pitch_error = target_pitch - current_pitch
	var roll_error = target_roll - current_roll
	var pitch_damping = state.angular_velocity.dot(local_right) * angular_damping * mass
	var roll_axis = basis.z
	var roll_damping = state.angular_velocity.dot(roll_axis) * angular_damping * mass
	state.apply_torque(local_right * (pitch_error * pitch_gain - pitch_damping))
	state.apply_torque(roll_axis * (roll_error * roll_gain - roll_damping))
	
	# --------------------------------------------------------------------------
	# 5. 360° Direction / Yaw Alignment
	# --------------------------------------------------------------------------
	if not controls_locked and move_dir.length_squared() > 0.01:
		var desired_yaw = atan2(-move_dir.x, -move_dir.z)
		var cur_yaw = atan2(-flat_forward.x, -flat_forward.z)
		var yaw_error = wrapf(desired_yaw - cur_yaw, -PI, PI)
		var yaw_torque_val = (yaw_error * yaw_torque) - (state.angular_velocity.y * angular_damping * mass)
		state.apply_torque(Vector3.UP * yaw_torque_val)
	else:
		state.apply_torque(Vector3.UP * (-state.angular_velocity.y * angular_damping * mass))
	
	# Safety: prevent over-rotation / tumbling upside down
	if local_up.y < 0.55:
		var righting_axis = local_up.cross(Vector3.UP)
		state.apply_torque(righting_axis * stabilization_strength * mass * 4.0)

# ==============================================================================
# 💥 DAMAGE, FUEL, TARGETING & SHOOTING
# ==============================================================================

func _drain_fuel(amount: float) -> void:
	if fuel_component and fuel_component.has_method("drain_fuel"):
		fuel_component.drain_fuel(amount)
	elif GameManager:
		GameManager.boost = maxf(0.0, GameManager.boost - amount)
		GameManager.boost_changed.emit(GameManager.boost, GameManager.max_boost)

func take_damage(amount: int) -> void:
	if not is_alive or spawn_invuln_timer > 0.0:
		return
	
	var armor_mult = GameManager.get_stat_multiplier("armor") if GameManager else 1.0
	var final_amount = maxi(1, int(amount / maxf(0.2, armor_mult)))
	
	if health_component and health_component.has_method("take_damage"):
		health_component.take_damage(final_amount)
	elif GameManager:
		GameManager.health = maxi(0, GameManager.health - final_amount)
		GameManager.health_changed.emit(GameManager.health, GameManager.max_health)
		if GameManager.health <= 0:
			_on_death()

func take_hit(amount: int) -> void:
	take_damage(amount)

func heal(amount: int) -> void:
	if not is_alive:
		return
	if health_component and health_component.has_method("heal"):
		health_component.heal(amount)
	elif GameManager:
		GameManager.health = mini(GameManager.max_health, GameManager.health + amount)
		GameManager.health_changed.emit(GameManager.health, GameManager.max_health)

func shoot() -> void:
	if not bullet_scene:
		return
	
	var chosen_muzzle: Marker3D = left_muzzle if fire_left_next else right_muzzle
	var chosen_flash: MuzzleFlash = left_flash if fire_left_next else right_flash
	fire_left_next = not fire_left_next
	
	if not chosen_muzzle:
		chosen_muzzle = left_muzzle if left_muzzle else right_muzzle
	if not chosen_muzzle:
		return
	
	if chosen_flash and chosen_flash.has_method("fire"):
		chosen_flash.fire()
	
	var base_dmg = 10
	var dmg_mult = GameManager.get_stat_multiplier("weapon_damage") if GameManager else 1.0
	var damage = 9999 if instakill_timer > 0.0 else int(base_dmg * dmg_mult)
	
	# Determine bullet flight direction
	var shoot_dir: Vector3 = -chosen_muzzle.global_transform.basis.z
	if current_target and is_instance_valid(current_target):
		shoot_dir = (current_target.global_position + Vector3(0, 0.4, 0) - chosen_muzzle.global_position).normalized()
	
	var bullet = bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	bullet.global_position = chosen_muzzle.global_position
	
	if bullet.has_method("setup"):
		bullet.setup(shoot_dir, damage)
	
	# Extra Projectiles Upgrade
	var extra_bullets = GameManager.get_stat_flat_value("extra_projectiles") if GameManager else 0
	if extra_bullets > 0:
		for i in range(extra_bullets):
			var angle_deg = 5.0 * (i + 1) * (-1 if i % 2 == 0 else 1)
			var spread_dir = shoot_dir.rotated(Vector3.UP, deg_to_rad(angle_deg))
			var extra_b = bullet_scene.instantiate()
			get_tree().root.add_child(extra_b)
			extra_b.global_position = chosen_muzzle.global_position
			if extra_b.has_method("setup"):
				extra_b.setup(spread_dir, damage)

func _update_targeting() -> void:
	if current_target and is_instance_valid(current_target):
		var dist = global_position.distance_to(current_target.global_position)
		if dist > auto_aim_radius * 1.3:
			current_target = null
		elif current_target.has_method("is_dead") and current_target.is_dead():
			current_target = null
	
	if not current_target or not is_instance_valid(current_target):
		current_target = _find_best_target()

func _find_best_target() -> Node3D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var best_enemy: Node3D = null
	var closest_dist: float = auto_aim_radius
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		var d = global_position.distance_to(enemy.global_position)
		if d < closest_dist:
			closest_dist = d
			best_enemy = enemy
	
	return best_enemy

func _on_crash_detector_body_entered(body: Node3D) -> void:
	if building_contact_cooldown > 0.0 or not is_alive or spawn_invuln_timer > 0.0:
		return
	
	building_contact_cooldown = 0.5
	take_damage(20)
	
	var cam_rig = get_tree().root.find_child("CameraRig", true, false)
	if cam_rig and cam_rig.has_method("add_shake"):
		cam_rig.add_shake(0.4)

func _on_death() -> void:
	if not is_alive:
		return
	is_alive = false
	controls_locked = true
	
	if target_marker_instance and is_instance_valid(target_marker_instance):
		target_marker_instance.queue_free()
	
	var expl = ExplosionScene.instantiate()
	get_tree().root.add_child(expl)
	expl.global_position = global_position
	
	var cam_rig = get_tree().root.find_child("CameraRig", true, false)
	if cam_rig and cam_rig.has_method("add_shake"):
		cam_rig.add_shake(1.0)
	
	visible = false
	player_died.emit()
