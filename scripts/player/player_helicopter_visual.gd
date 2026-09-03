extends Node3D
class_name PlayerHelicopterVisual

@export var base_main_rotor_speed: float = 32.0
@export var boost_main_rotor_speed: float = 62.0
@export var base_tail_rotor_speed: float = 55.0
@export var auto_spin: bool = true

@onready var body_root: Node3D = $BodyRoot
@onready var main_rotor_pivot: Node3D = $MainRotorPivot
@onready var tail_rotor_pivot: Node3D = $TailRotorPivot

var current_main_speed: float = 32.0
var target_main_speed: float = 32.0
var is_spinning: bool = true

func update_wing_effects(_speed_ratio: float, _roll_ratio: float = 0.0, _turn_boost: float = 0.0) -> void:
	# Wing flare and trail effects completely removed per design specification
	pass

func _ready() -> void:
	current_main_speed = base_main_rotor_speed
	target_main_speed = base_main_rotor_speed

func _process(delta: float) -> void:
	if not is_spinning or not auto_spin:
		return
		
	current_main_speed = lerpf(current_main_speed, target_main_speed, 5.0 * delta)
	
	if main_rotor_pivot:
		main_rotor_pivot.rotate_y(current_main_speed * delta)
		
	if tail_rotor_pivot:
		# The back propeller mesh lies in its local XY plane, so its shaft is Z.
		tail_rotor_pivot.rotate_z(base_tail_rotor_speed * delta)

func set_boost(active: bool) -> void:
	target_main_speed = boost_main_rotor_speed if active else base_main_rotor_speed

func stop_rotors() -> void:
	is_spinning = false

func start_rotors() -> void:
	is_spinning = true
