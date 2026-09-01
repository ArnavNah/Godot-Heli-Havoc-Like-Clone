extends Node3D
class_name PlayerHelicopterVisual

@export var main_rotor_speed: float = 35.0
@export var tail_rotor_speed: float = 55.0
@export var auto_spin: bool = true

@onready var body_root: Node3D = $BodyRoot
@onready var main_rotor_pivot: Node3D = $MainRotorPivot
@onready var tail_rotor_pivot: Node3D = $TailRotorPivot
@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")

var is_spinning: bool = true

func _ready() -> void:
	if anim_player and anim_player.has_animation("rotors_running"):
		anim_player.play("rotors_running")

func _process(delta: float) -> void:
	if not is_spinning or not auto_spin:
		return
	
	# Main rotor spins around local Y axis
	if main_rotor_pivot:
		main_rotor_pivot.rotate_y(main_rotor_speed * delta)
	
	# Tail rotor spins around local X axis
	if tail_rotor_pivot:
		tail_rotor_pivot.rotate_x(tail_rotor_speed * delta)

func set_spinning(active: bool) -> void:
	is_spinning = active
	if anim_player:
		if active:
			anim_player.play("rotors_running")
		else:
			anim_player.stop()
