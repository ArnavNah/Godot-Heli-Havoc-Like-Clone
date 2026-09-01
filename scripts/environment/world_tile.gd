extends Node3D
class_name WorldTile

@export var gold_pickup_scene: PackedScene = preload("res://scenes/pickups/gold_pickup.tscn")
@export var fuel_pickup_scene: PackedScene = preload("res://scenes/pickups/fuel_pickup.tscn")
@export var xp_pickup_scene: PackedScene = preload("res://scenes/pickups/xp_pickup.tscn")
@export var health_pickup_scene: PackedScene = preload("res://scenes/pickups/health_pickup.tscn")
@export var powerup_pickup_scene: PackedScene = preload("res://scenes/pickups/powerup_pickup.tscn")
@export var turret_scene: PackedScene = preload("res://scenes/enemies/tracking_turret.tscn")

@export var tile_size: float = 10.0
@export var spawn_density: float = 0.65

@onready var item_container: Node3D = $ItemContainer
@onready var pickup_spawns: Node3D = $PickupSpawns
@onready var turret_spawns: Node3D = $TurretSpawns

func _ready() -> void:
	pass

func repopulate(is_center_start: bool = false) -> void:
	# 1. Clean old spawned items on this tile
	if item_container:
		for child in item_container.get_children():
			child.queue_free()
	
	if is_center_start:
		return # Keep initial player tile clear
	
	# 2. Populate Pickups using Marker3D nodes in trail patterns
	if pickup_spawns and item_container:
		var markers = pickup_spawns.get_children()
		for i in range(markers.size()):
			var marker = markers[i]
			if marker is Marker3D:
				var roll = randf()
				if roll < spawn_density:
					var chosen_scene: PackedScene = null
					
					# Structured trail distribution: Coins (60%), Fuel (15%), XP (15%), Health (5%), Powerup (5%)
					var sub_roll = randf()
					if sub_roll < 0.55:
						chosen_scene = gold_pickup_scene
					elif sub_roll < 0.72:
						chosen_scene = fuel_pickup_scene
					elif sub_roll < 0.88:
						chosen_scene = xp_pickup_scene
					elif sub_roll < 0.94:
						chosen_scene = health_pickup_scene
					else:
						chosen_scene = powerup_pickup_scene
					
					if chosen_scene:
						var pickup_inst = chosen_scene.instantiate()
						item_container.add_child(pickup_inst)
						pickup_inst.global_position = marker.global_position
	
	# 3. Populate Turrets (Sparse: 20% chance per turret marker)
	if turret_spawns and item_container and turret_scene:
		var t_markers = turret_spawns.get_children()
		for t_marker in t_markers:
			if t_marker is Marker3D and randf() < 0.20:
				var turret_inst = turret_scene.instantiate()
				item_container.add_child(turret_inst)
				turret_inst.global_position = t_marker.global_position
