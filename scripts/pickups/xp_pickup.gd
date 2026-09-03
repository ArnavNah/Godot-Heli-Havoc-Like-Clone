extends Area3D
class_name XPPickup

@export var xp_value: int = 5
@export var magnet_radius: float = 11.0 # 8-12m auto-pull range
@export var magnet_speed: float = 34.0
@export var bob_amplitude: float = 0.3
@export var bob_speed: float = 4.0
@export var spin_speed: float = 4.5

@onready var visual_node: Node3D = $VisualRoot

var time_elapsed: float = 0.0
var target_player: Node3D = null
var is_collected: bool = false

func _ready() -> void:
	# Layer 6: Pickup (32), Mask 1: Player (1)
	collision_layer = 32
	collision_mask = 1
	time_elapsed = randf() * 5.0
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if not is_inside_tree() or is_collected:
		return
	
	time_elapsed += delta
	
	# Find player if not tracked or left the tree
	if not target_player or not is_instance_valid(target_player) or not target_player.is_inside_tree():
		target_player = null
		var players = get_tree().get_nodes_in_group("PlayerHeli")
		if players.is_empty():
			players = get_tree().get_nodes_in_group("player")
		for p in players:
			if is_instance_valid(p) and p.is_inside_tree():
				target_player = p
				break
	
	# Magnet pull (scaled by magnet_radius upgrade)
	if target_player and is_instance_valid(target_player) and target_player.is_inside_tree():
		var effective_radius = magnet_radius * (GameManager.get_stat_multiplier("magnet_radius") if GameManager else 1.0)
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= effective_radius:
			var dir = (target_player.global_position - global_position).normalized()
			global_position += dir * magnet_speed * delta
			if dist < 1.0:
				collect()
				return
	
	# Visual bob & diagonal spin (isometric cube tumble)
	if visual_node:
		visual_node.rotation.y += spin_speed * delta
		visual_node.rotation.x += spin_speed * 0.7 * delta
		visual_node.position.y = sin(time_elapsed * bob_speed) * bob_amplitude

func _on_body_entered(body: Node3D) -> void:
	if (body.collision_layer & 1) != 0 or body.is_in_group("player") or body.is_in_group("PlayerHeli"):
		collect()

func _on_area_entered(_area: Area3D) -> void:
	collect()

func collect() -> void:
	if is_collected:
		return
	is_collected = true
	
	if GameManager:
		GameManager.add_xp(xp_value)
	
	queue_free()
