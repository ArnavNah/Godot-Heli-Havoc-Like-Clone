extends Area3D
class_name FuelPickup

@export var fuel_amount: float = 30.0
@export var magnet_radius: float = 4.5
@export var magnet_speed: float = 20.0
@export var rotation_speed: float = 3.5

@onready var visual_root: Node3D = $VisualRoot

var is_collected: bool = false
var time_elapsed: float = 0.0
var target_player: Node3D = null

func _ready() -> void:
	collision_layer = 32 # Pickup layer
	collision_mask = 1   # Player layer
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_collected:
		return
	
	time_elapsed += delta
	if visual_root:
		visual_root.rotate_y(rotation_speed * delta)
		visual_root.position.y = sin(time_elapsed * 4.0) * 0.2
	
	# Magnetic pull
	if not target_player or not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target_player = players[0]
	
	if target_player:
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= magnet_radius:
			global_position = global_position.move_toward(target_player.global_position, magnet_speed * delta)

func _on_body_entered(body: Node3D) -> void:
	if is_collected:
		return
	if body.has_method("add_fuel") or body.is_in_group("player") or body.is_in_group("PlayerHeli"):
		is_collected = true
		if body.has_method("add_fuel"):
			body.add_fuel(fuel_amount)
		elif GameManager:
			GameManager.add_boost(fuel_amount)
		queue_free()
