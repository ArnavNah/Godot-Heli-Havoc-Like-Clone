extends CharacterBody3D
class_name PlayerHelicopter

signal fuel_changed(current_fuel: float, max_fuel: float)
signal health_changed(current_hp: int, max_hp: int)
signal player_died()

@export_group("Arcade Flight Physics")
@export var cruise_speed: float = 28.0
@export var max_forward_speed: float = 42.0
@export var min_forward_speed: float = 14.0
@export var forward_acceleration: float = 85.0
@export var forward_deceleration: float = 70.0

@export var lateral_speed: float = 30.0
@export var lateral_acceleration: float = 120.0
@export var lateral_deceleration: float = 100.0

@export_group("Visual Banking & Yaw")
@export var max_bank_angle: float = 32.0
@export var max_yaw_angle: float = 18.0
@export var max_pitch_angle: float = 14.0
@export var bank_responsiveness: float = 26.0
@export var yaw_responsiveness: float = 22.0
@export var pitch_responsiveness: float = 20.0

@export_group("Altitude Stabilization")
@export var target_altitude: float = 15.0
@export var altitude_responsiveness: float = 15.0

@export_group("Collision Bouncing")
@export var bounce_strength: float = 12.0

@export_group("Fuel & Health")
@export var max_fuel: float = 100.0
@export var fuel_burn_rate: float = 1.5
@export var max_health: int = 100

@onready var visual_root: Node3D = $VisualRoot
@onready var helicopter_visual: Node3D = $VisualRoot/PlayerHelicopterVisual

var joystick_input: Vector2 = Vector2.ZERO
var current_forward_speed: float = 28.0
var current_lateral_speed: float = 0.0
var fuel: float = 100.0
var health: int = 100
var is_alive: bool = true

func _ready() -> void:
	add_to_group("player")
	add_to_group("PlayerHeli")
	
	target_altitude = global_position.y
	current_forward_speed = cruise_speed
	fuel = max_fuel
	health = max_health
	
	# Layer 1 (Player), Masks: 2 (Environment), 3 (Enemy), 5 (EnemyProjectile) -> 2 + 4 + 16 = 22
	collision_layer = 1
	collision_mask = 22
	
	if GameManager:
		GameManager._update_player_stats()

func update_input(vec: Vector2) -> void:
	joystick_input = vec

func _process(delta: float) -> void:
	if not is_alive:
		return
	
	# 1. Fuel consumption
	fuel = maxf(0.0, fuel - fuel_burn_rate * delta)
	fuel_changed.emit(fuel, max_fuel)
	if GameManager:
		GameManager.boost = fuel
		GameManager.boost_changed.emit(fuel, max_fuel)

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	
	# 1. Input detection (Joystick or Keyboard WASD)
	var forward_in = Input.get_axis("move_backward", "move_forward")
	var lateral_in = Input.get_axis("move_left", "move_right") # A: -1, D: +1
	
	if joystick_input.length_squared() > 0.01:
		lateral_in = joystick_input.x
		forward_in = -joystick_input.y
	
	_apply_flight_physics(forward_in, lateral_in, delta)
	_apply_visual_banking(delta)

func _apply_flight_physics(forward_in: float, lateral_in: float, delta: float) -> void:
	# 1. Forward Speed Calculation
	var target_fwd = cruise_speed
	if forward_in > 0.0:
		target_fwd = max_forward_speed
	elif forward_in < 0.0:
		target_fwd = min_forward_speed
	
	var fwd_rate = forward_acceleration if forward_in != 0.0 else forward_deceleration
	current_forward_speed = move_toward(current_forward_speed, target_fwd, fwd_rate * delta)
	
	# 2. Lateral Speed Calculation (Instant, agile A/D weaving)
	var target_lat = lateral_in * lateral_speed
	var lat_rate = lateral_acceleration if lateral_in != 0.0 else lateral_deceleration
	current_lateral_speed = move_toward(current_lateral_speed, target_lat, lat_rate * delta)
	
	# 3. Assemble Velocity Vector (Forward along -Z, Lateral along X)
	velocity.z = -current_forward_speed
	velocity.x = current_lateral_speed
	
	# 4. Altitude Stabilization
	var alt_diff = target_altitude - global_position.y
	velocity.y = alt_diff * altitude_responsiveness
	
	# 5. Move & Slide
	move_and_slide()
	
	# 6. Arcade Wall Deflection
	if get_slide_collision_count() > 0:
		for i in range(get_slide_collision_count()):
			var col = get_slide_collision(i)
			var normal = col.get_normal()
			if normal.dot(velocity) < 0.0:
				velocity = velocity.slide(normal) + normal * bounce_strength * delta

func _apply_visual_banking(delta: float) -> void:
	if not visual_root:
		return
	
	var lat_ratio = clamp(current_lateral_speed / lateral_speed, -1.0, 1.0)
	
	# 1. Body Yaw (Heading points subtly into turn)
	var target_yaw = -lat_ratio * deg_to_rad(max_yaw_angle)
	var yaw_blend = 1.0 - exp(-yaw_responsiveness * delta)
	rotation.y = lerp_angle(rotation.y, target_yaw, yaw_blend)
	rotation.x = 0.0
	rotation.z = 0.0
	
	# 2. Visual Banking (Roll): Strong dramatic tilt
	var target_roll = -lat_ratio * deg_to_rad(max_bank_angle)
	var bank_blend = 1.0 - exp(-bank_responsiveness * delta)
	visual_root.rotation.z = lerp_angle(visual_root.rotation.z, target_roll, bank_blend)
	
	# 3. Visual Pitch (Nose down on boost, nose up on brake)
	var fwd_ratio = (current_forward_speed - cruise_speed) / (max_forward_speed - cruise_speed)
	var target_pitch = -fwd_ratio * deg_to_rad(max_pitch_angle)
	var pitch_blend = 1.0 - exp(-pitch_responsiveness * delta)
	visual_root.rotation.x = lerp_angle(visual_root.rotation.x, target_pitch, pitch_blend)
	visual_root.rotation.y = 0.0

func add_fuel(amount: float = 25.0) -> void:
	fuel = minf(max_fuel, fuel + amount)
	fuel_changed.emit(fuel, max_fuel)
	if GameManager:
		GameManager.add_boost(amount)

func add_health(amount: int = 25) -> void:
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)
	if GameManager:
		GameManager.add_health(amount)

func take_damage(amount: int = 15) -> void:
	if not is_alive:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	if GameManager:
		GameManager.health = health
		GameManager.health_changed.emit(health, max_health)
	if health <= 0:
		is_alive = false
		player_died.emit()
