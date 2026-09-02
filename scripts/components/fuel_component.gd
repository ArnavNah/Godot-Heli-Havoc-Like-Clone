extends Node
class_name FuelComponent

signal fuel_changed(current_fuel: float, max_fuel: float)
signal fuel_depleted()

@export var max_fuel: float = 100.0
@export var current_fuel: float = 100.0
@export var drain_multiplier: float = 1.0
@export var auto_drain: bool = false
@export var fuel_drain_rate: float = 2.0

var is_active: bool = true
var is_depleted: bool = false

func _ready() -> void:
	current_fuel = max_fuel
	fuel_changed.emit(current_fuel, max_fuel)

func _process(delta: float) -> void:
	if not auto_drain or not is_active or is_depleted:
		return
	consume_fuel(fuel_drain_rate * delta)

func consume_fuel(amount: float) -> void:
	if not is_active or is_depleted:
		return
	
	var actual_drain = amount * drain_multiplier
	current_fuel = maxf(0.0, current_fuel - actual_drain)
	fuel_changed.emit(current_fuel, max_fuel)
	
	if current_fuel <= 0.0 and not is_depleted:
		is_depleted = true
		fuel_depleted.emit()

func add_fuel(amount: float = 35.0) -> void:
	current_fuel = minf(max_fuel, current_fuel + amount)
	if current_fuel > 0.0:
		is_depleted = false
	fuel_changed.emit(current_fuel, max_fuel)

func set_max_fuel(new_max: float) -> void:
	var diff = new_max - max_fuel
	max_fuel = new_max
	current_fuel = minf(max_fuel, current_fuel + maxf(0.0, diff))
	if current_fuel > 0.0:
		is_depleted = false
	fuel_changed.emit(current_fuel, max_fuel)
