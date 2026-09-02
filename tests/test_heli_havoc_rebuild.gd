@tool
class_name TestHeliHavocRebuild
extends McpTestSuite

func suite_name() -> String:
	return "heli_havoc_rebuild"

func test_materials_exist() -> void:
	var mat_near = load("res://resources/materials/building_near.tres")
	assert_true(mat_near != null, "building_near.tres must exist")
	
	var mat_mid = load("res://resources/materials/building_mid.tres")
	assert_true(mat_mid != null, "building_mid.tres must exist")
	
	var mat_gold = load("res://resources/materials/coin_gold.tres")
	assert_true(mat_gold != null, "coin_gold.tres must exist")
	
	var mat_xp = load("res://resources/materials/xp_purple.tres")
	assert_true(mat_xp != null, "xp_purple.tres must exist")

func test_player_bullet_specs() -> void:
	var bullet_scene = load("res://scenes/projectiles/player_bullet.tscn")
	assert_true(bullet_scene != null, "PlayerBullet scene must exist")
	
	var bullet = track(bullet_scene.instantiate()) as Area3D
	assert_true(bullet != null, "PlayerBullet must instantiate")
	assert_eq(bullet.get("damage"), 10, "Player bullet damage must be 10")
	assert_gt(bullet.get("speed"), 50.0, "Player bullet speed must be fast (> 50 m/s)")
	assert_eq(bullet.collision_layer, 8, "Player bullet collision layer must be 8 (PlayerProjectile)")

func test_enemy_bullet_specs() -> void:
	var bullet_scene = load("res://scenes/projectiles/enemy_bullet.tscn")
	assert_true(bullet_scene != null, "EnemyBullet scene must exist")
	
	var bullet = track(bullet_scene.instantiate()) as Area3D
	assert_true(bullet != null, "EnemyBullet must instantiate")
	assert_eq(bullet.get("damage"), 15, "Enemy bullet damage must be 15")
	assert_eq(bullet.collision_layer, 16, "Enemy bullet collision layer must be 16 (EnemyProjectile)")

func test_turret_scene_structure() -> void:
	var turret_scene = ResourceLoader.load("res://scenes/enemies/tracking_turret.tscn", "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	assert_true(turret_scene != null, "TrackingTurret scene must exist")
	
	var turret = track(turret_scene.instantiate()) as StaticBody3D
	assert_true(turret != null, "Turret must instantiate")
	assert_eq(turret.get("max_health"), 30, "Turret max health must be 30")
	assert_eq(turret.collision_layer, 4, "Turret collision layer must be 4 (Enemy)")
	
	var col = turret.get_node_or_null("CollisionShape3D")
	assert_true(col != null, "Turret must have CollisionShape3D")
	var yaw_p = turret.get_node_or_null("TurretYawPivot")
	assert_true(yaw_p != null, "Turret must have TurretYawPivot")
	var pitch_p = turret.get_node_or_null("TurretYawPivot/GunPitchPivot")
	assert_true(pitch_p != null, "Turret must have GunPitchPivot")

func test_pickups_and_powerups() -> void:
	var power_up_scene = ResourceLoader.load("res://scenes/pickups/power_up.tscn", "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	assert_true(power_up_scene != null, "PowerUp scene must exist")
	var pup = track(power_up_scene.instantiate()) as Area3D
	assert_true(pup != null, "PowerUp must instantiate")
	assert_eq(pup.collision_layer, 32, "PowerUp layer must be 32 (Pickup)")
	assert_eq(pup.collision_mask, 1, "PowerUp mask must be 1 (Player)")
	assert_true(pup.get_node_or_null("MeshInstance3D") != null, "PowerUp must have MeshInstance3D")
	assert_true(pup.get_node_or_null("CollisionShape3D") != null, "PowerUp must have CollisionShape3D")
	
	# Test all 5 enum values
	pup.pickup_type = PowerUp.PickupType.FUEL
	pup._apply_visual_style()
	assert_eq(pup.pickup_type, PowerUp.PickupType.FUEL)
	
	pup.pickup_type = PowerUp.PickupType.COIN
	pup._apply_visual_style()
	assert_eq(pup.pickup_type, PowerUp.PickupType.COIN)
	
	pup.pickup_type = PowerUp.PickupType.INSTAKILL
	pup._apply_visual_style()
	assert_eq(pup.pickup_type, PowerUp.PickupType.INSTAKILL)
	
	pup.pickup_type = PowerUp.PickupType.NUKE
	pup._apply_visual_style()
	assert_eq(pup.pickup_type, PowerUp.PickupType.NUKE)
	
	pup.pickup_type = PowerUp.PickupType.DOUBLE_COIN
	pup._apply_visual_style()
	assert_eq(pup.pickup_type, PowerUp.PickupType.DOUBLE_COIN)

func test_city_block_scene_and_layouts() -> void:
	var block_scene = ResourceLoader.load("res://scenes/environment/city_block.tscn", "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	assert_true(block_scene != null, "CityBlock scene must exist")
	
	var block = track(block_scene.instantiate()) as Node3D
	assert_true(block != null, "CityBlock must instantiate")
	assert_true(block.get_node_or_null("Buildings") != null, "CityBlock must have Buildings node")
	assert_true(block.get_node_or_null("Dynamic") != null, "CityBlock must have Dynamic node")

func test_player_heli_structure() -> void:
	var heli_scene = ResourceLoader.load("res://scenes/player/player_heli.tscn", "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	assert_true(heli_scene != null, "PlayerHeli scene must exist")
	
	var heli = track(heli_scene.instantiate()) as CharacterBody3D
	assert_true(heli != null, "PlayerHeli must instantiate")
	assert_true(heli.get_node_or_null("VisualYawRoot") != null, "Must have VisualYawRoot")
	assert_true(heli.get_node_or_null("VisualYawRoot/BankingRoot") != null, "Must have BankingRoot")
	assert_true(heli.get_node_or_null("VisualYawRoot/BankingRoot/MotionJuiceRoot") != null, "Must have MotionJuiceRoot")
	assert_true(heli.get_node_or_null("CameraTarget") != null, "Must have CameraTarget Node3D")
	var cd = heli.get_node_or_null("CrashDetector") as Area3D
	assert_true(cd != null, "Must have CrashDetector Area3D")
	assert_eq(cd.collision_mask, 2, "CrashDetector must mask Layer 2 (Environment)")
	assert_gt(heli.get("horizontal_speed"), 20.0, "Horizontal speed must be > 20")
	assert_gt(heli.get("lift_force"), 20.0, "Lift force must be > 20")

func test_explosion_effect() -> void:
	var exp_scene = ResourceLoader.load("res://scenes/effects/explosion_effect.tscn", "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	assert_true(exp_scene != null, "ExplosionEffect scene must exist")
	var exp = track(exp_scene.instantiate()) as Node3D
	assert_true(exp != null, "ExplosionEffect must instantiate")
	assert_true(exp.get_node_or_null("FireParticles") != null, "Must have FireParticles")
	assert_true(exp.get_node_or_null("SmokeParticles") != null, "Must have SmokeParticles")
	assert_true(exp.get_node_or_null("FlashLight") != null, "Must have FlashLight")

func test_main_menu_scene() -> void:
	var menu_scene = ResourceLoader.load("res://scenes/ui/main_menu.tscn", "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	assert_true(menu_scene != null, "MainMenu scene must exist")
	var menu = track(menu_scene.instantiate()) as Node3D
	assert_true(menu != null, "MainMenu must instantiate")
	assert_true(menu.get_node_or_null("Camera3D") != null, "Must have Camera3D")
	assert_true(menu.get_node_or_null("HelicopterRoot") != null, "Must have HelicopterRoot")
	assert_true(menu.get_node_or_null("MenuUI") != null, "Must have MenuUI")
	assert_true(menu.get_node_or_null("MenuUI/CenterContainer/VBoxContainer/PlayButton") != null, "Must have PlayButton")
	assert_true(menu.get_node_or_null("LoadingScreen") != null, "Must have LoadingScreen")
	assert_true(menu.get_node_or_null("LoadingScreen/ColorRect/LoadingLabel") != null, "Must have LoadingLabel")
	var loading_screen = menu.get_node_or_null("LoadingScreen") as CanvasLayer
	assert_false(loading_screen.visible, "LoadingScreen must start hidden")

func test_world_grid_manager() -> void:
	var wgm = track(WorldGridManager.new()) as WorldGridManager
	assert_true(wgm != null, "WorldGridManager must instantiate")
	assert_true(wgm.power_up_scene != null, "Must have power_up_scene slot")
	assert_true(wgm.tracking_turret_scene != null, "Must have tracking_turret_scene slot")
	assert_true(wgm.cloud_scene != null, "Must have cloud_scene slot")
	
	var cell = track(Node3D.new()) as Node3D
	wgm.populate_grid_cell(cell)
	var spawns = cell.get_node_or_null("Spawns")
	assert_true(spawns != null, "Cell must have Spawns node")
	assert_gt(spawns.get_child_count(), 0, "Cell must have spawned obstacle blocks and items")

func test_player_health_and_damage_death() -> void:
	var hc = track(HealthComponent.new()) as HealthComponent
	assert_true(hc != null, "HealthComponent must instantiate")
	assert_eq(hc.current_health, 100, "Initial health should be 100")
	
	# Test take damage on HealthComponent
	hc.take_damage(35)
	assert_eq(hc.current_health, 65, "Health should decrease to 65 after 35 damage")
	
	# Test heal
	hc.heal(20)
	assert_eq(hc.current_health, 85, "Health should increase to 85 after 20 heal")
	
	# Test lethal damage triggers death
	var died_box = [false]
	hc.died.connect(func(): died_box[0] = true)
	hc.take_damage(100)
	assert_eq(hc.current_health, 0, "Health should reach 0")
	assert_true(died_box[0], "died signal must be emitted when health reaches 0")

func test_auto_aim_and_xp_magnet() -> void:
	var xp_scene = ResourceLoader.load("res://scenes/pickups/xp_pickup.tscn", "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	assert_true(xp_scene != null, "XPPickup scene must exist")
	var xp = track(xp_scene.instantiate()) as XPPickup
	assert_true(xp != null, "XPPickup must instantiate")
	assert_true(xp.magnet_radius >= 10.0, "XP magnet radius must be at least 10m (8-12m range)")
	assert_gt(xp.magnet_speed, 25.0, "XP magnet speed must be fast (> 25 m/s)")
	
	var tm_scene = ResourceLoader.load("res://scenes/effects/target_marker.tscn", "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	assert_true(tm_scene != null, "TargetMarker scene must exist")
	var tm = track(tm_scene.instantiate()) as Node3D
	assert_true(tm != null, "TargetMarker must instantiate")
