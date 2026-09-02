extends Node3D
class_name PlayerHelicopterVisual

@export var base_main_rotor_speed: float = 32.0
@export var boost_main_rotor_speed: float = 62.0
@export var base_tail_rotor_speed: float = 55.0
@export var auto_spin: bool = true

@onready var body_root: Node3D = $BodyRoot
@onready var main_rotor_pivot: Node3D = $MainRotorPivot
@onready var tail_rotor_pivot: Node3D = $TailRotorPivot
@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")

var current_main_speed: float = 32.0
var target_main_speed: float = 32.0
var is_spinning: bool = true

func _ready() -> void:
	current_main_speed = base_main_rotor_speed
	target_main_speed = base_main_rotor_speed
	if anim_player and anim_player.has_animation("rotors_running"):
		anim_player.play("rotors_running")

func set_rotor_boost(is_boosting: bool) -> void:
	target_main_speed = boost_main_rotor_speed if is_boosting else base_main_rotor_speed

func _process(delta: float) -> void:
	if not is_spinning or not auto_spin:
		return
	
	current_main_speed = move_toward(current_main_speed, target_main_speed, 100.0 * delta)
	
	# Main rotor spins around its own local Y axis
	if main_rotor_pivot:
		main_rotor_pivot.rotate_object_local(Vector3.UP, current_main_speed * delta)
	
	# Tail rotor spins around its own local Z axle
	if tail_rotor_pivot:
		var tail_speed = base_tail_rotor_speed * (current_main_speed / base_main_rotor_speed)
		tail_rotor_pivot.rotate_object_local(Vector3(0, 0, 1), tail_speed * delta)

func set_spinning(active: bool) -> void:
	is_spinning = active
	if anim_player:
		if active:
			anim_player.play("rotors_running")
		else:
			anim_player.stop()
