extends Control
class_name HeliVirtualJoystick

signal joystick_updated(output_vector: Vector2)

@export var max_radius: float = 50.0

@onready var base_ring: Control = $BaseRing
@onready var knob: Control = $BaseRing/Knob

var is_dragging: bool = false
var output: Vector2 = Vector2.ZERO
var center: Vector2 = Vector2.ZERO

func _ready() -> void:
	center = base_ring.size * 0.5
	_reset_knob()

func _reset_knob() -> void:
	if knob:
		knob.position = center - knob.size * 0.5
	output = Vector2.ZERO
	joystick_updated.emit(output)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				_update_joystick(event.position)
			else:
				is_dragging = false
				_reset_knob()
	elif event is InputEventMouseMotion and is_dragging:
		_update_joystick(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			is_dragging = true
			_update_joystick(event.position)
		else:
			is_dragging = false
			_reset_knob()
	elif event is InputEventScreenDrag and is_dragging:
		_update_joystick(event.position)

func _update_joystick(touch_pos: Vector2) -> void:
	var ring_center = base_ring.global_position + center
	var diff = touch_pos - ring_center
	var dist = diff.length()
	
	if dist > max_radius:
		diff = diff.normalized() * max_radius
	
	if knob:
		knob.position = center + diff - knob.size * 0.5
	
	output = diff / max_radius
	joystick_updated.emit(output)

func _process(_delta: float) -> void:
	if not is_dragging:
		# Fallback to keyboard visual sync
		var key_in = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if key_in.length_squared() > 0.01:
			output = key_in
			if knob:
				knob.position = center + (key_in * max_radius) - knob.size * 0.5
			joystick_updated.emit(output)
		elif output != Vector2.ZERO:
			_reset_knob()
