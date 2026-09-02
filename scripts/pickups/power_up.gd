@tool
extends Area3D
class_name PowerUp

enum PickupType { FUEL, COIN, INSTAKILL, NUKE, DOUBLE_COIN }

@export var pickup_type: PickupType = PickupType.COIN:
	set(val):
		pickup_type = val
		_apply_visual_style()
@export var spin_speed: float = 4.0
@export var bob_amplitude: float = 0.2
@export var bob_speed: float = 3.5
@export var magnet_radius: float = 3.5
@export var magnet_speed: float = 28.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var time_elapsed: float = 0.0
var base_y: float = 0.0
var is_collected: bool = false
var target_player: Node3D = null

func _ready() -> void:
	collision_layer = 32 # Layer 6: Pickup (32)
	collision_mask = 1   # Layer 1: Player (1)
	
	base_y = position.y
	time_elapsed = randf() * 10.0
	
	_apply_visual_style()
	body_entered.connect(_on_body_entered)

func _apply_visual_style() -> void:
	if not mesh_instance:
		mesh_instance = get_node_or_null("MeshInstance3D")
	if not mesh_instance:
		return
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	
	match pickup_type:
		PickupType.COIN:
			# Yellow for COIN
			mat.albedo_color = Color(1.0, 0.88, 0.1, 1.0)
		PickupType.FUEL:
			# Red for FUEL
			mat.albedo_color = Color(0.95, 0.2, 0.18, 1.0)
		PickupType.INSTAKILL:
			# Purple for INSTAKILL
			mat.albedo_color = Color(0.78, 0.2, 1.0, 1.0)
		PickupType.NUKE:
			# Black/Orange for NUKE
			mat.albedo_color = Color(1.0, 0.4, 0.05, 1.0)
		PickupType.DOUBLE_COIN:
			# Gold for DOUBLE_COIN
			mat.albedo_color = Color(1.0, 0.72, 0.05, 1.0)
	
	mesh_instance.material_override = mat

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if is_collected:
		return
	
	time_elapsed += delta
	
	# Rotation animation
	rotate_y(spin_speed * delta)
	
	# Sinusoidal hover bobbing
	position.y = base_y + sin(time_elapsed * bob_speed) * bob_amplitude
	
	# Magnet pull toward player if within range
	if not target_player or not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("PlayerHeli")
		if players.is_empty():
			players = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			target_player = players[0]
	
	if target_player and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= magnet_radius:
			var dir = (target_player.global_position - global_position).normalized()
			global_position += dir * magnet_speed * delta
			if dist < 1.0:
				_collect(target_player)

func _on_body_entered(body: Node3D) -> void:
	if is_collected:
		return
	
	if (body.collision_layer & 1) != 0 or body.is_in_group("player") or body.is_in_group("PlayerHeli") or body is PlayerHeli:
		_collect(body)

func _collect(player: Node3D) -> void:
	if is_collected:
		return
	is_collected = true
	collision_layer = 0
	collision_mask = 0
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	match pickup_type:
		PickupType.FUEL:
			# FUEL: Add 25 to the player's fuel variable
			if player.has_method("add_fuel"):
				player.add_fuel(25.0)
			elif GameManager:
				GameManager.add_boost(25.0)
		
		PickupType.COIN:
			# COIN: Add 1 to the player's coin score (or 2 if double coin buff is active)
			if GameManager:
				GameManager.add_gold(1)
		
		PickupType.INSTAKILL:
			# INSTAKILL: Call a function on player that temporarily sets weapon damage to infinity for 10 seconds
			if player.has_method("apply_powerup"):
				player.apply_powerup("INSTAKILL", 10.0)
		
		PickupType.NUKE:
			# NUKE: Find all nodes in the 'enemies' group (the tracking turrets) and destroy them, adding score
			var enemies = get_tree().get_nodes_in_group("enemies")
			for enemy in enemies:
				if is_instance_valid(enemy):
					if enemy.has_method("destroy_turret"):
						enemy.destroy_turret()
					else:
						if GameManager:
							GameManager.add_kill()
						enemy.queue_free()
			
			if GameManager:
				GameManager.notification_triggered.emit("NUKE DETONATED! ALL ENEMIES DESTROYED!")
		
		PickupType.DOUBLE_COIN:
			# DOUBLE_COIN: Start a 15-second Timer on the player that multiplies all collected coins by 2
			if player.has_method("apply_powerup"):
				player.apply_powerup("DOUBLE_COINS", 15.0)
			elif GameManager:
				GameManager.notification_triggered.emit("2X COINS ACTIVE (15s)!")
	
	queue_free()
