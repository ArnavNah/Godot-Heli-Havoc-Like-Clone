@tool
extends Control
class_name UIBarHealth

@export var max_value: float = 100.0:
	set(val):
		max_value = maxf(1.0, val)
		if progress_bar:
			progress_bar.max_value = max_value
		_update_text()

@export var current_value: float = 100.0:
	set(val):
		current_value = clampf(val, 0.0, max_value)
		if progress_bar:
			progress_bar.value = current_value
		_update_text()

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var value_label: Label = $ProgressBar/ValueLabel
@onready var heart_icon: TextureRect = $HeartIcon

func _ready() -> void:
	if progress_bar:
		progress_bar.max_value = max_value
		progress_bar.value = current_value
	_update_text()

func set_health(cur: float, max_hp: float) -> void:
	max_value = maxf(1.0, max_hp)
	current_value = clampf(cur, 0.0, max_value)
	if progress_bar:
		progress_bar.max_value = max_value
		progress_bar.value = current_value
	_update_text()

func _update_text() -> void:
	if value_label:
		value_label.text = str(int(round(current_value)))
