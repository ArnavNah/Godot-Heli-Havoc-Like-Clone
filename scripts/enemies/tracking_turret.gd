extends StaticBody3D
class_name TrackingTurret

const ExplosionScene = preload("res://scenes/effects/explosion_effect.tscn")

@export var max_health: int = 30
@export var current_health: int = 30
@export var bullet_scene: PackedScene = preload("res://scenes/projectiles/enemy_bullet.tscn")
@export var xp_pickup_scene: PackedScene = preload("res://scenes/pickups/xp_pickup.tscn")
@export var gold_pickup_scene: PackedScene = preload("res://scenes/pickups/gold_pickup.tscn")
@export var fuel_pickup_scene: PackedScene = preload("res://scenes/pickups/fuel_pickup.tscn")
@export var powerup_pickup_scene: PackedScene = preload("res://scenes/pickups/powerup_pickup.tscn")

@export var detection_range: float = 30.0
@export var fire_rate_interval: float = 1.5
@export var turn_speed: float = 6.0
@export var score_reward: int = 100

@onready var yaw_pivot: Node3D = $TurretYawPivot
@onready var pitch_pivot: Node3D = $TurretYawPivot/GunPitchPivot
@onready var muzzle_l: Marker3D = $TurretYawPivot/GunPitchPivot/Muzzle_L
@onready var muzzle_r: Marker3D = $TurretYawPivot/GunPitchPivot/Muzzle_R
@onready var ray_cast: RayCast3D = get_node_or_null("TurretYawPivot/GunPitchPivot/RayCast3D")
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var hurt_area: Area3D = $HurtArea

var target_player: Node3D = null
var fire_timer: float = 0.0
var fire_left_next: bool = true
var is_destroyed: bool = false

func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health
	collision_layer = 4
	collision_mask = 9
	
	if hurt_area:
		hurt_area.collision_layer = 4
		hurt_area.collision_mask = 8
		hurt_area.area_entered.connect(_on_hurt_area_entered)
		hurt_area.body_entered.connect(_on_hurt_body_entered)

func _physics_process(delta: float) -> void:
	if is_destroyed:
		return
	
	# Find player
	if not target_player or not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("PlayerHeli")
		if players.is_empty():
			players = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			target_player = players[0]
		else:
			return
	
	var to_player = target_player.global_position - global_position
	var dist = to_player.length()
	if dist > detection_range * 1.4:
		return
	
	# 1. Smooth Yaw Tracking (Horizontal)
	if yaw_pivot:
		var flat_dir = Vector3(to_player.x, 0.0, to_player.z).normalized()
		if flat_dir.length_squared() > 0.001:
			var target_yaw = atan2(-flat_dir.x, -flat_dir.z)
			var blend_yaw = 1.0 - exp(-turn_speed * delta)
			yaw_pivot.rotation.y = lerp_angle(yaw_pivot.rotation.y, target_yaw, blend_yaw)
	
	# 2. Smooth Pitch Aiming (Vertical towards helicopter)
	if pitch_pivot:
		var h_dist = Vector2(to_player.x, to_player.z).length()
		var target_pitch = atan2(to_player.y - 0.8, maxf(1.0, h_dist))
		var blend_pitch = 1.0 - exp(-turn_speed * delta)
		pitch_pivot.rotation.x = lerp_angle(pitch_pivot.rotation.x, target_pitch, blend_pitch)
	
	# 3. Fire at interval when within detection range
	fire_timer += delta
	if dist <= detection_range and fire_timer >= fire_rate_interval:
		fire_timer = 0.0
		shoot()

func shoot() -> void:
	if is_destroyed or not bullet_scene or not pitch_pivot:
		return
	
	var muzzle = muzzle_l if fire_left_next else muzzle_r
	if not muzzle:
		muzzle = pitch_pivot.get_node_or_null("Muzzle_L")
	fire_left_next = not fire_left_next
	
	var spawn_pos = muzzle.global_position if muzzle else pitch_pivot.global_position
	var fire_dir = -pitch_pivot.global_transform.basis.z
	
	var bullet = bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	bullet.global_position = spawn_pos
	
	var sm = get_node_or_null("/root/SurvivalManager")
	var speed_mult = sm.get_projectile_speed_multiplier() if sm else 1.0
	if bullet.has_method("setup"):
		bullet.setup(fire_dir, speed_mult)

func take_hit(damage: int = 10) -> void:
	take_damage(damage)

func take_damage(damage: int) -> void:
	if is_destroyed:
		return
	
	current_health -= damage
	_flash_hit()
	
	if current_health <= 0:
		destroy_turret()

func _flash_hit() -> void:
	if yaw_pivot:
		var tween = create_tween()
		tween.tween_property(yaw_pivot, "scale", Vector3(1.2, 1.2, 1.2), 0.05)
		tween.tween_property(yaw_pivot, "scale", Vector3.ONE, 0.08)

func _on_hurt_area_entered(area: Area3D) -> void:
	if area is PlayerBullet or (area.collision_layer & 8) != 0 or area.is_in_group("PlayerProjectile"):
		var dmg = 10
		if area.get("damage") != null:
			dmg = int(area.damage)
		take_damage(dmg)

func _on_hurt_body_entered(body: Node3D) -> void:
	if (body.collision_layer & 8) != 0 or body.is_in_group("PlayerProjectile"):
		take_damage(10)

func destroy_turret() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	
	collision_layer = 0
	collision_mask = 0
	if hurt_area:
		hurt_area.collision_layer = 0
		hurt_area.collision_mask = 0
	
	if GameManager:
		GameManager.add_kill()
	
	# Spawn explosion effect
	if ExplosionScene:
		var exp_effect = ExplosionScene.instantiate()
		get_tree().root.add_child(exp_effect)
		exp_effect.global_position = global_position + Vector3(0, 0.8, 0)
	
	# Spawn purple XP pickup
	if xp_pickup_scene:
		var xp_drop = xp_pickup_scene.instantiate()
		get_tree().root.add_child(xp_drop)
		xp_drop.global_position = global_position + Vector3(0, 1.2, 0)
	
	# Chance of gold or powerup drop
	var roll = randf()
	if roll < 0.40 and gold_pickup_scene:
		var coin = gold_pickup_scene.instantiate()
		get_tree().root.add_child(coin)
		coin.global_position = global_position + Vector3(randf_range(-0.8, 0.8), 1.2, randf_range(-0.8, 0.8))
	elif roll < 0.55 and powerup_pickup_scene:
		var pwr = powerup_pickup_scene.instantiate()
		get_tree().root.add_child(pwr)
		pwr.global_position = global_position + Vector3(0, 1.4, 0)
	
	# Fuel drop (higher priority when low on fuel)
	var player_fuel_pct = 1.0
	if GameManager:
		player_fuel_pct = GameManager.boost / maxf(1.0, GameManager.max_boost)
	var fuel_chance = 0.60 if player_fuel_pct < 0.4 else 0.30
	if randf() < fuel_chance and fuel_pickup_scene:
		var fuel = fuel_pickup_scene.instantiate()
		get_tree().root.add_child(fuel)
		fuel.global_position = global_position + Vector3(0.4, 1.3, 0)
	
	queue_free()
