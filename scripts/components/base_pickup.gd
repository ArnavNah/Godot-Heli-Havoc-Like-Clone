extends Area3D
class_name BasePickup

enum PickupType { COIN, XP, HEALTH, BOOST, POWERUP }

@export var pickup_type: PickupType = PickupType.COIN
@export var value: int = 1
@export var magnet_radius: float = 4.5
@export var magnet_speed: float = 18.0
@export var rotation_speed: float = 3.5
@export var bob_amplitude: float = 0.25
@export var bob_frequency: float = 3.0
@export var effect_color: Color = Color(1, 0.85, 0.1, 1)

@export var effect_scene: PackedScene = preload("res://scenes/effects/pickup_effect.tscn")

@onready var visual_root: Node3D = $VisualRoot

var is_collected: bool = false
var initial_y: float = 0.0
var time_elapsed: float = 0.0
var target_player: Node3D = null

func _ready() -> void:
	initial_y = position.y
	collision_layer = 32 # Layer 6: Pickup
	collision_mask = 3   # Layer 1: Player (1) + Layer 2: Player (2)
	monitoring = true
	monitorable = true
	
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_collected:
		return
	
	time_elapsed += delta
	
	# 1. Rotate & Bob
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
	
	var effective_radius = magnet_radius
	if GameManager:
		effective_radius *= GameManager.get_stat_multiplier("magnet_radius")
	
	var dist = global_position.distance_to(target_player.global_position)
	if dist <= effective_radius:
		if dist <= 1.0:
			_collect(target_player)
			return
		global_position = global_position.move_toward(target_player.global_position, magnet_speed * delta)

func _on_body_entered(body: Node3D) -> void:
	if is_collected:
		return
	
	if body is CharacterBody3D or body.is_in_group("player") or body.is_in_group("PlayerHeli") or (body.collision_layer & 3) != 0:
		_collect(body)

func _collect(collector: Node3D = null) -> void:
	is_collected = true
	var spawn_pos = global_position
	
	# 1. Apply reward via GameManager
	if GameManager:
		match pickup_type:
			PickupType.COIN:
				GameManager.add_gold(value)
			PickupType.XP:
				GameManager.add_xp(value)
			PickupType.HEALTH:
				if collector and collector.has_method("add_health"):
					collector.add_health(value)
				else:
					GameManager.add_health(value)
			PickupType.BOOST:
				if collector and collector.has_method("add_fuel"):
					collector.add_fuel(float(value))
				else:
					GameManager.add_boost(float(value))
			PickupType.POWERUP:
				GameManager.add_powerup("FIREPOWER")
	
	# 2. Spawn Particle Effect
	if effect_scene and get_parent():
		var eff = effect_scene.instantiate()
		get_parent().add_child(eff)
		eff.global_position = spawn_pos
		if eff.has_method("set_color"):
			eff.set_color(effect_color)
	
	# 3. Destroy Pickup
	queue_free()
