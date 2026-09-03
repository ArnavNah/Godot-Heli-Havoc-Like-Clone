extends Node
class_name HealthComponent

signal health_changed(current_health: int, max_health: int)
signal damaged(amount: int)
signal died()

@export var max_health: int = 100
@export var current_health: int = 100

var is_dead: bool = false

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)

func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	
	current_health = maxi(0, current_health - amount)
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		is_dead = true
		died.emit()

func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	
	current_health = mini(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

func set_max_health(new_max: int, restore: bool = true) -> void:
	var old_max = max_health
	max_health = new_max
	if restore:
		var bonus = maxi(0, new_max - old_max)
		current_health = mini(current_health + bonus, max_health)
	current_health = mini(current_health, max_health)
	health_changed.emit(current_health, max_health)
