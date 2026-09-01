extends Area3D
class_name GoldPickup

signal collected(value: int)

@export var value: int = 1
@export var magnet_radius: float = 4.5
@export var magnet_speed: float = 22.0
@export var rotation_speed: float = 4.0
@export var bob_speed: float = 3.5
@export var bob_height: float = 0.25

@onready var visual_root: Node3D = $VisualRoot

var is_collected: bool = false
var time_elapsed: float = 0.0
var target_player: Node3D = null

func _ready() -> void:
	# Layer 6: Pickup (32), Mask 1: Player (1)
	collision_layer = 32
	collision_mask = 1
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_collected:
		return
	
	time_elapsed += delta
	if visual_root:
		visual_root.rotate_y(rotation_speed * delta)
		visual_root.position.y = sin(time_elapsed * bob_speed) * bob_height
	
	_handle_magnet(delta)

func _handle_magnet(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target_player = players[0]
		else:
			return
	
	var effective_radius = magnet_radius
	if GameManager:
		effective_radius *= GameManager.get_stat_multiplier("magnet_radius")
	
	var dist = global_position.distance_to(target_player.global_position)
	if dist <= effective_radius:
		global_position = global_position.move_toward(target_player.global_position, magnet_speed * delta)

func _on_body_entered(body: Node3D) -> void:
	if is_collected:
		return
	if body.is_in_group("player") or body.is_in_group("PlayerHeli") or (body.collision_layer & 1) != 0:
		_collect()

func _collect() -> void:
	is_collected = true
	var actual_value = value
	if GameManager:
		var mult = GameManager.get_stat_multiplier("gold_value")
		actual_value = int(value * mult)
		GameManager.add_gold(actual_value)
	
	collected.emit(actual_value)
	queue_free()
