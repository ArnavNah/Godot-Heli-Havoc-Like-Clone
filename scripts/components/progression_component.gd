extends Node
class_name PlayerProgressionComponent

signal xp_updated(current_xp: int, xp_required: int, level: int)
signal level_up(new_level: int)

@export var level: int = 1
@export var current_xp: int = 0
@export var base_xp_required: int = 25

var xp_required: int = 25

func _ready() -> void:
	xp_required = base_xp_required
	xp_updated.emit(current_xp, xp_required, level)

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	
	current_xp += amount
	
	while current_xp >= xp_required:
		current_xp -= xp_required
		level += 1
		xp_required = int(xp_required * 1.45) + 10
		level_up.emit(level)
	
	xp_updated.emit(current_xp, xp_required, level)

func reset_progression() -> void:
	level = 1
	current_xp = 0
	xp_required = base_xp_required
	xp_updated.emit(current_xp, xp_required, level)
