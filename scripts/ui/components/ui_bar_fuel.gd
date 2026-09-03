@tool
extends Control
class_name UIBarFuel

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
@onready var gas_icon: TextureRect = $GasIcon

func _ready() -> void:
	if progress_bar:
		progress_bar.max_value = max_value
		progress_bar.value = current_value
	_update_text()

func set_fuel(cur: float, max_f: float) -> void:
	max_value = maxf(1.0, max_f)
	current_value = clampf(cur, 0.0, max_value)
	if progress_bar:
		progress_bar.max_value = max_value
		progress_bar.value = current_value
	_update_text()

func _update_text() -> void:
	if value_label:
		var pct = int(round((current_value / max_value) * 100.0))
		value_label.text = "%d%%" % pct
