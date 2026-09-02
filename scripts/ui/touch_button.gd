extends Control
class_name HeliTouchButton

signal button_down()
signal button_up()

@export var action_name: String = ""
@export var is_toggle: bool = false

var is_pressed: bool = false
var touch_index: int = -1

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if not is_pressed:
				touch_index = event.index
				_press_button()
		elif event.index == touch_index:
			touch_index = -1
			_release_button()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if not is_pressed:
					touch_index = -1
					_press_button()
			else:
				if is_pressed and touch_index == -1:
					_release_button()

func _press_button() -> void:
	is_pressed = true
	if not action_name.is_empty():
		Input.action_press(action_name)
	button_down.emit()
	_apply_visual_press(true)

func _release_button() -> void:
	is_pressed = false
	if not action_name.is_empty():
		Input.action_release(action_name)
	button_up.emit()
	_apply_visual_press(false)

func _apply_visual_press(pressed: bool) -> void:
	pivot_offset = size * 0.5
	var tw = create_tween()
	if pressed:
		tw.tween_property(self, "scale", Vector2(0.9, 0.9), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		modulate = Color(1.3, 1.3, 1.3, 1.0)
	else:
		tw.tween_property(self, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		modulate = Color(1.0, 1.0, 1.0, 1.0)

func _exit_tree() -> void:
	if is_pressed and not action_name.is_empty():
		Input.action_release(action_name)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		if is_pressed and not action_name.is_empty():
			Input.action_release(action_name)
			is_pressed = false
