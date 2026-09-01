extends Node
class_name FuelComponent

signal fuel_changed(current_fuel: float, max_fuel: float)
signal fuel_depleted()

@export var max_fuel: float = 100.0
@export var current_fuel: float = 100.0
@export var fuel_drain_rate: float = 2.0 # 2 fuel per second
@export var drain_multiplier: float = 1.0

var is_active: bool = true
var is_depleted: bool = false

func _ready() -> void:
	current_fuel = max_fuel
	fuel_changed.emit(current_fuel, max_fuel)

func _process(delta: float) -> void:
	if not is_active or is_depleted:
		return
	
	var actual_drain = fuel_drain_rate * drain_multiplier * delta
	current_fuel = maxf(0.0, current_fuel - actual_drain)
	fuel_changed.emit(current_fuel, max_fuel)
	
	if current_fuel <= 0.0 and not is_depleted:
		is_depleted = true
		fuel_depleted.emit()

func add_fuel(amount: float = 25.0) -> void:
	if is_depleted:
		return
	
	current_fuel = minf(max_fuel, current_fuel + amount)
	fuel_changed.emit(current_fuel, max_fuel)

func set_max_fuel(new_max: float) -> void:
	var diff = new_max - max_fuel
	max_fuel = new_max
	current_fuel = minf(max_fuel, current_fuel + maxf(0.0, diff))
	fuel_changed.emit(current_fuel, max_fuel)
