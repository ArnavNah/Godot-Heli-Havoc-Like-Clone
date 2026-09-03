extends Node

signal time_updated(seconds: float)

var survival_time: float = 0.0
var is_active: bool = true

func _ready() -> void:
	reset()

func _process(delta: float) -> void:
	if not is_active or Engine.is_editor_hint():
		return
	
	survival_time += delta
	time_updated.emit(survival_time)

func reset() -> void:
	survival_time = 0.0
	is_active = true
	set_process(true)
	time_updated.emit(0.0)

func get_projectile_speed_multiplier() -> float:
	# Increase projectile speed by 5% every 30 seconds
	return 1.0 + (survival_time / 30.0) * 0.05

func get_extra_turret_chance() -> float:
	# Increase turret spawn density as time increases
	return clampf((survival_time / 60.0) * 0.4, 0.0, 1.0)

func get_formatted_time() -> String:
	var total_sec = int(survival_time)
	var mins = int(float(total_sec) / 60.0)
	var secs = total_sec % 60
	return "%02d:%02d" % [mins, secs]
