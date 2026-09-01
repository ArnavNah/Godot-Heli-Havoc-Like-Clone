extends Area3D
class_name CoinPickup

@export var gold_value: int = 1
@export var magnet_radius: float = 4.5
@export var magnet_speed: float = 18.0
@export var rotation_speed: float = 3.5
@export var bob_amplitude: float = 0.25
@export var bob_frequency: float = 3.0

@export var effect_scene: PackedScene = preload("res://scenes/effects/pickup_effect.tscn")

@onready var visual_root: Node3D = $VisualRoot

var is_collected: bool = false
var initial_y: float = 0.0
var time_elapsed: float = 0.0
var target_player: Node3D = null

func _ready() -> void:
	initial_y = position.y
	# Ensure correct collision mask to detect Player (Layer 2)
	collision_layer = 32 # Layer 6: Pickup
	collision_mask = 2   # Layer 2: Player
	monitoring = true
	monitorable = true
	
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_collected:
		return
	
	time_elapsed += delta
	
	# 1. Rotate & Bob VisualRoot
	if visual_root:
		visual_root.rotate_y(rotation_speed * delta)
		visual_root.position.y = sin(time_elapsed * bob_frequency) * bob_amplitude
	
	# 2. Magnetic Attraction
	_handle_magnet(delta)

func _handle_magnet(delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target_player = players[0]
		else:
			return
	
	var dist = global_position.distance_to(target_player.global_position)
	if dist <= magnet_radius:
		# Pull smoothly toward player center of mass
		global_position = global_position.move_toward(target_player.global_position, magnet_speed * delta)

func _on_body_entered(body: Node3D) -> void:
	if is_collected:
		return
	
	# Verify body is the player
	if body is CharacterBody3D or body.is_in_group("player") or (body.collision_layer & 2) != 0:
		_collect()

func _collect() -> void:
	is_collected = true
	var spawn_pos = global_position
	
	# 1. Increase gold via GameManager
	if GameManager:
		GameManager.add_gold(gold_value)
	
	# 2. Spawn collection particle effect (parent first, then position)
	if effect_scene and get_parent():
		var eff = effect_scene.instantiate()
		get_parent().add_child(eff)
		eff.global_position = spawn_pos
	
	# 3. Remove coin
	queue_free()
