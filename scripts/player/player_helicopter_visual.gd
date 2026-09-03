extends Node3D
class_name PlayerHelicopterVisual

@export var base_main_rotor_speed: float = 32.0
@export var boost_main_rotor_speed: float = 62.0
@export var base_tail_rotor_speed: float = 55.0
@export var auto_spin: bool = true

@export_group("Wing Airflow FX")
@export var wing_fx_start_speed: float = 4.0
@export var wing_fx_full_speed: float = 38.0
@export var wing_fx_turn_acceleration: float = 35.0
@export var wing_fx_max_amount_ratio: float = 0.58
@export var wing_fx_turn_accent: float = 0.14
@export var wing_fx_min_lifetime: float = 0.06
@export var wing_fx_max_lifetime: float = 0.11

@onready var body_root: Node3D = $BodyRoot
@onready var main_rotor_pivot: Node3D = $MainRotorPivot
@onready var tail_rotor_pivot: Node3D = $TailRotorMount/TailRotorPivot
@onready var left_wing_fx: GPUParticles3D = $WingEffects/LeftWingFX
@onready var right_wing_fx: GPUParticles3D = $WingEffects/RightWingFX

var current_main_speed: float = 32.0
var target_main_speed: float = 32.0
var is_spinning: bool = true
var _physics_owner: RigidBody3D = null
var _previous_horizontal_velocity: Vector3 = Vector3.ZERO
var _left_fx_strength: float = 0.0
var _right_fx_strength: float = 0.0

func update_wing_effects(speed_ratio: float, right_turn_ratio: float = 0.0, turn_boost: float = 0.0) -> void:
	var speed_curve = smoothstep(0.0, 1.0, clampf(speed_ratio, 0.0, 1.0))
	var base_strength = speed_curve * wing_fx_max_amount_ratio
	var signed_turn = clampf(right_turn_ratio + turn_boost, -1.0, 1.0)
	var turn_gate = smoothstep(0.05, 0.35, speed_ratio)
	var left_target = base_strength + maxf(signed_turn, 0.0) * wing_fx_turn_accent * turn_gate
	var right_target = base_strength + maxf(-signed_turn, 0.0) * wing_fx_turn_accent * turn_gate
	var blend = 1.0 - exp(-10.0 * get_process_delta_time())
	_left_fx_strength = lerpf(_left_fx_strength, clampf(left_target, 0.0, 0.78), blend)
	_right_fx_strength = lerpf(_right_fx_strength, clampf(right_target, 0.0, 0.78), blend)
	_apply_emitter_strength(left_wing_fx, _left_fx_strength, speed_curve)
	_apply_emitter_strength(right_wing_fx, _right_fx_strength, speed_curve)

func _ready() -> void:
	current_main_speed = base_main_rotor_speed
	target_main_speed = base_main_rotor_speed
	if get_parent() is RigidBody3D:
		_physics_owner = get_parent() as RigidBody3D
		_previous_horizontal_velocity = Vector3(_physics_owner.linear_velocity.x, 0.0, _physics_owner.linear_velocity.z)

func _process(delta: float) -> void:
	_update_wing_airflow(delta)

	if not is_spinning or not auto_spin:
		return
		
	current_main_speed = lerpf(current_main_speed, target_main_speed, 5.0 * delta)
	
	if main_rotor_pivot:
		main_rotor_pivot.rotate_y(current_main_speed * delta)
		
	if tail_rotor_pivot:
		# The identity pivot sits inside the fixed side-facing mount, so its local
		# Z rotation spins around the propeller shaft without wobbling the rotor.
		tail_rotor_pivot.rotation.z = fmod(
			tail_rotor_pivot.rotation.z + base_tail_rotor_speed * delta,
			TAU
		)

func _update_wing_airflow(delta: float) -> void:
	if not _physics_owner or not is_instance_valid(_physics_owner):
		update_wing_effects(0.0)
		return

	var horizontal_velocity = Vector3(_physics_owner.linear_velocity.x, 0.0, _physics_owner.linear_velocity.z)
	var speed = horizontal_velocity.length()
	var speed_ratio = inverse_lerp(wing_fx_start_speed, wing_fx_full_speed, speed)
	var horizontal_acceleration = (horizontal_velocity - _previous_horizontal_velocity) / maxf(delta, 0.001)
	_previous_horizontal_velocity = horizontal_velocity

	var owner_basis = _physics_owner.global_transform.basis.orthonormalized()
	var flat_right = Vector3(owner_basis.x.x, 0.0, owner_basis.x.z).normalized()
	var lateral_acceleration = horizontal_acceleration.dot(flat_right)
	var max_roll = deg_to_rad(float(_physics_owner.get("max_roll_deg")))
	var current_roll = asin(clampf(owner_basis.x.y, -1.0, 1.0))
	var roll_turn = -current_roll / maxf(max_roll, 0.01)
	var acceleration_turn = lateral_acceleration / maxf(wing_fx_turn_acceleration, 0.01)
	var right_turn_ratio = clampf(roll_turn * 0.6 + acceleration_turn * 0.4, -1.0, 1.0)
	update_wing_effects(speed_ratio, right_turn_ratio)

	if speed > 1.0:
		# The process material emits along local +Z. Align +Z with the exact
		# opposite of horizontal travel; world-space particles then stay behind.
		var trail_direction = -horizontal_velocity.normalized()
		var airflow_basis = Basis.looking_at(-trail_direction, Vector3.UP)
		left_wing_fx.global_basis = airflow_basis
		right_wing_fx.global_basis = airflow_basis

func _apply_emitter_strength(emitter: GPUParticles3D, strength: float, speed_curve: float) -> void:
	if not emitter:
		return
	emitter.emitting = strength > 0.015
	emitter.amount_ratio = strength
	emitter.lifetime = lerpf(wing_fx_min_lifetime, wing_fx_max_lifetime, speed_curve)

func set_boost(active: bool) -> void:
	target_main_speed = boost_main_rotor_speed if active else base_main_rotor_speed

func stop_rotors() -> void:
	is_spinning = false

func start_rotors() -> void:
	is_spinning = true
