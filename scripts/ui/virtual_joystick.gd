extends Control
class_name HeliVirtualJoystick

signal joystick_updated(output_vector: Vector2)

@export var max_radius: float = 50.0

@onready var base_ring: Control = $BaseRing
@onready var knob: Control = $BaseRing/Knob

var is_dragging: bool = false
var touch_index: int = -1
var output: Vector2 = Vector2.ZERO

func _ready() -> void:
	_reset_knob()

func _reset_knob() -> void:
	if base_ring and knob:
		knob.position = (base_ring.size * 0.5) - (knob.size * 0.5)
	output = Vector2.ZERO
	joystick_updated.emit(output)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if not is_dragging:
				is_dragging = true
				touch_index = event.index
				_update_joystick(event.position)
		elif event.index == touch_index:
			is_dragging = false
			touch_index = -1
			_reset_knob()
	elif event is InputEventScreenDrag:
		if is_dragging and (event.index == touch_index or touch_index == -1):
			_update_joystick(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				touch_index = -1
				_update_joystick(event.position)
			else:
				is_dragging = false
				_reset_knob()
	elif event is InputEventMouseMotion and is_dragging and touch_index == -1:
		_update_joystick(event.position)

func _update_joystick(local_touch_pos: Vector2) -> void:
	if not base_ring or not knob:
		return
		
	var ring_center = base_ring.position + (base_ring.size * 0.5)
	var diff = local_touch_pos - ring_center
	var dist = diff.length()
	
	if dist > max_radius:
		diff = diff.normalized() * max_radius
	
	knob.position = (base_ring.size * 0.5) + diff - (knob.size * 0.5)
	
	output = diff / max_radius
	joystick_updated.emit(output)

func _process(_delta: float) -> void:
	if not is_dragging:
		var key_in = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if key_in.length_squared() > 0.01:
			if base_ring and knob:
				knob.position = (base_ring.size * 0.5) + (key_in * max_radius) - (knob.size * 0.5)
		else:
			if base_ring and knob:
				knob.position = (base_ring.size * 0.5) - (knob.size * 0.5)
