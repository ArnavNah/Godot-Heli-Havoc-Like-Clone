extends StaticBody3D
class_name TrackingTurret

@export var bullet_scene: PackedScene = preload("res://scenes/projectiles/bullet.tscn")
@export var detection_range: float = 20.0
@export var fire_rate_interval: float = 1.5
@export var turn_speed: float = 6.0
@export var score_reward: int = 10

@onready var rotating_top: Node3D = $RotatingTop
@onready var raycast: RayCast3D = $RotatingTop/RayCast3D
@onready var muzzle_point: Marker3D = $RotatingTop/MuzzlePoint
@onready var hurt_area: Area3D = $HurtArea

var target_player: Node3D = null
var fire_timer: float = 0.0
var is_destroyed: bool = false

func _ready() -> void:
	# Layer 3: Enemy (4), Mask 1: Player (1), Mask 4: PlayerProjectile (8) -> 1 + 8 = 9
	collision_layer = 4
	collision_mask = 9
	
	if raycast:
		raycast.target_position = Vector3(0, 0, -detection_range)
		raycast.collision_mask = 1 # Detects Player (Layer 1)
		raycast.enabled = true
	
	if hurt_area:
		hurt_area.collision_layer = 4
		hurt_area.collision_mask = 8 # Detects PlayerProjectile (Layer 4)
		hurt_area.area_entered.connect(_on_projectile_entered)
		hurt_area.body_entered.connect(_on_projectile_body_entered)

func _physics_process(delta: float) -> void:
	if is_destroyed:
		return
	
	# 1. Locate player
	if not target_player or not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("PlayerHeli")
		if players.size() > 0:
			target_player = players[0]
		else:
			return
	
	# 2. Smoothly rotate on the Y-axis toward the PlayerHeli
	if rotating_top and target_player:
		var target_pos = target_player.global_position
		var flat_target = Vector3(target_pos.x, rotating_top.global_position.y, target_pos.z)
		
		if global_position.distance_to(target_pos) <= detection_range * 1.5:
			var current_rot = rotating_top.rotation.y
			var look_dir = (flat_target - rotating_top.global_position).normalized()
			if look_dir.length_squared() > 0.001:
				var target_rot = atan2(-look_dir.x, -look_dir.z)
				var blend = 1.0 - exp(-turn_speed * delta)
				rotating_top.rotation.y = lerp_angle(current_rot, target_rot, blend)
	
	# 3. Raycast detection & firing
	fire_timer += delta
	if raycast and raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider and (collider.is_in_group("PlayerHeli") or (collider.collision_layer & 1) != 0):
			if fire_timer >= fire_rate_interval:
				fire_timer = 0.0
				shoot()
	elif target_player and global_position.distance_to(target_player.global_position) <= detection_range:
		if fire_timer >= fire_rate_interval:
			fire_timer = 0.0
			shoot()

func shoot() -> void:
	if is_destroyed or not bullet_scene:
		return
	
	var spawn_pos = muzzle_point.global_position if muzzle_point else rotating_top.global_position
	var fire_dir = -rotating_top.global_transform.basis.z
	
	var bullet = bullet_scene.instantiate()
	get_tree().root.add_child(bullet)
	bullet.global_position = spawn_pos
	if bullet.has_method("setup"):
		bullet.setup(fire_dir)

func take_hit(_damage: int = 25) -> void:
	destroy_turret()

func _on_projectile_entered(area: Area3D) -> void:
	if (area.collision_layer & 8) != 0 or area.is_in_group("PlayerProjectile"):
		destroy_turret()

func _on_projectile_body_entered(body: Node3D) -> void:
	if (body.collision_layer & 8) != 0:
		destroy_turret()

func destroy_turret() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	
	# Add 10 to global score variable
	if GameManager:
		GameManager.score += score_reward
		GameManager.kills += 1
		GameManager.score_changed.emit(GameManager.score)
		GameManager.kills_changed.emit(GameManager.kills)
	
	queue_free()
