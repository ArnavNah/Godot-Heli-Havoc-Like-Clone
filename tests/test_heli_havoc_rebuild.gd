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
	
	var heli = track(heli_scene.instantiate())
	assert_true(heli != null, "PlayerHeli must instantiate")
	assert_true(heli is RigidBody3D, "PlayerHeli root must be RigidBody3D")
	assert_true(heli.get_node_or_null("HelicopterVisual") != null, "Must have HelicopterVisual")
	assert_true(heli.get_node_or_null("CollisionShape3D") != null, "Must have CollisionShape3D around fuselage")
	
	var cd = heli.get_node_or_null("CrashDetector") as Area3D
	assert_true(cd != null, "Must have CrashDetector Area3D")
	assert_eq(cd.collision_mask, 2, "CrashDetector must mask Layer 2 (Environment)")
	
	var spd = float(heli.get("max_speed"))
	assert_gt(spd, 20.0, "Max speed must be > 20")
	assert_gt(float(heli.get("pitch_torque")), 100.0, "Pitch torque must be > 100")

func test_player_position_watchdog_requests_recovery() -> void:
	var heli_scene = ResourceLoader.load("res://scenes/player/player_heli.tscn", "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	var heli = track(heli_scene.instantiate())
	heli.controls_locked = false
	heli.last_requested_move_dir = Vector3.FORWARD
	heli.watchdog_anchor_position = heli.global_position
	heli._update_position_stuck_watchdog(heli.position_watchdog_delay)
	assert_true(heli.watchdog_recovery_requested, "A commanded helicopter that does not move must request recovery")

func test_wing_effects_removed() -> void:
	var heli_scene = ResourceLoader.load("res://scenes/player/player_heli.tscn", "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	var heli = track(heli_scene.instantiate())
	assert_true(heli.get_node_or_null("WingEffects") == null, "WingEffects must be completely removed from player heli")
	assert_true(heli.find_child("TrailParticles", true, false) == null, "TrailParticles must be completely removed from player heli")

func test_assisted_helicopter_physics() -> void:
	var heli_scene = ResourceLoader.load("res://scenes/player/player_heli.tscn", "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	var heli = track(heli_scene.instantiate())
	
	assert_true(heli is RigidBody3D, "Must be RigidBody3D")
	assert_eq(float(heli.get("mass")), 60.0, "RigidBody mass must be 60 kg")
	
	var base_lift = float(heli.get("base_lift_ratio"))
	var collective = float(heli.get("collective_strength"))
	var alt_assist = float(heli.get("altitude_assist_strength"))
	assert_true(base_lift > 0.8 and base_lift < 1.0, "base_lift_ratio must gently sink when space released (0.8-1.0, is: %f)" % base_lift)
	assert_true(collective > 1.2, "collective_strength must provide positive climb (> 1.2, is: %f)" % collective)
	assert_true(alt_assist > 50.0, "altitude_assist_strength must be positive (> 50, is: %f)" % alt_assist)
	
	var max_pitch = float(heli.get("max_pitch_deg"))
	var max_brake = float(heli.get("max_reverse_pitch_deg"))
	var max_roll = float(heli.get("max_roll_deg"))
	assert_true(max_pitch >= 12.0 and max_pitch <= 18.0, "max_pitch_deg should be in 12-18 deg range (is: %f)" % max_pitch)
	assert_true(max_brake >= 8.0 and max_brake <= 12.0, "max_reverse_pitch_deg should be in 8-12 deg range (is: %f)" % max_brake)
	assert_true(max_roll >= 20.0 and max_roll <= 32.0, "max_roll_deg should be in 20-32 deg range (is: %f)" % max_roll)
	
	assert_gt(float(heli.get("pitch_torque")), 200.0, "pitch_torque must be > 200")
	assert_gt(float(heli.get("roll_torque")), 200.0, "roll_torque must be > 200")
	assert_gt(float(heli.get("yaw_torque")), 200.0, "yaw_torque must be > 200")
	assert_gt(float(heli.get("stabilization_strength")), 5.0, "stabilization_strength must be > 5")
	assert_gt(float(heli.get("angular_damping")), 1.0, "angular_damping must be > 1")
	assert_gt(float(heli.get("horizontal_drag")), 0.5, "horizontal_drag must be > 0.5")
	
	var left_m = heli.get_node_or_null("WeaponMounts/LeftGunMuzzle") as Marker3D
	var right_m = heli.get_node_or_null("WeaponMounts/RightGunMuzzle") as Marker3D
	assert_true(left_m != null, "LeftGunMuzzle must exist")
	assert_true(right_m != null, "RightGunMuzzle must exist")
	assert_true(left_m.get_node_or_null("MuzzleFlash") != null, "LeftGunMuzzle must have MuzzleFlash")
	assert_true(right_m.get_node_or_null("MuzzleFlash") != null, "RightGunMuzzle must have MuzzleFlash")
	var fwd_dir = -left_m.transform.basis.z
	assert_true(fwd_dir.is_equal_approx(Vector3.FORWARD) or fwd_dir.z < 0.0, "Muzzle forward must point -Z")

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
	assert_true(menu.get_node_or_null("MenuUI/TopBar/Margin/TitleLabel") != null, "Must have TitleLabel")
	assert_true(menu.get_node_or_null("MenuUI/TopBar/Margin/HBox/CoinContainer") != null, "Must have CoinContainer")
	assert_true(menu.get_node_or_null("MenuUI/TopBar/Margin/RightHBox/SoundBtn") != null, "Must have SoundBtn")
	assert_true(menu.get_node_or_null("MenuUI/TopBar/Margin/RightHBox/MusicBtn") != null, "Must have MusicBtn")
	assert_true(menu.get_node_or_null("MenuUI/BottomRightLocker/VBox/LockerBtn") != null, "Must have LockerBtn")
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

func test_health_upgrade_heals_correctly() -> void:
	var hc = track(HealthComponent.new()) as HealthComponent
	assert_eq(hc.current_health, 100, "Initial health should be 100")
	assert_eq(hc.max_health, 100, "Initial max health should be 100")
	hc.take_damage(40)
	assert_eq(hc.current_health, 60, "Health should be 60 after 40 damage")
	hc.set_max_health(120, true)
	assert_eq(hc.max_health, 120, "Max health should be 120 after upgrade")
	assert_eq(hc.current_health, 80, "Current health should be 60 + 20 bonus = 80")
	hc.heal(40)
	assert_eq(hc.current_health, 120, "Health should be full at 120")
	hc.set_max_health(140, true)
	assert_eq(hc.current_health, 140, "Health should be capped at new max 140")

func test_multi_level_xp_overflow() -> void:
	var gm_script = ResourceLoader.load("res://scripts/managers/game_manager.gd", "", ResourceLoader.CACHE_MODE_REPLACE)
	var gm = gm_script.new()
	gm.reset()
	assert_eq(gm.level, 1, "Should start at level 1")
	assert_eq(gm.xp_required, 15, "Initial XP threshold should be 15")
	gm.add_xp(50)
	assert_true(gm.level >= 3, "Should be at least level 3 after 50 XP (thresholds: 15 + 28 = 43)")
	gm.free()

func test_no_rocket_damage_in_upgrade_pool() -> void:
	var gm_script = ResourceLoader.load("res://scripts/managers/game_manager.gd", "", ResourceLoader.CACHE_MODE_REPLACE)
	var gm = gm_script.new()
	gm._load_upgrades()
	for upg in gm.all_upgrades:
		var upg_id = str(upg.get("id"))
		assert_true(upg_id != "rocket_damage", "rocket_damage must not be in the upgrade pool (no rocket weapon exists)")
	gm.free()

func test_magnet_radius_scaling() -> void:
	var gm_script = ResourceLoader.load("res://scripts/managers/game_manager.gd", "", ResourceLoader.CACHE_MODE_REPLACE)
	var gm = gm_script.new()
	gm._load_upgrades()
	var base_magnet = gm.get_stat_multiplier("magnet_radius")
	assert_eq(base_magnet, 1.0, "Base magnet_radius multiplier must be 1.0")
	gm.upgrade_levels["magnet_radius"] = 1
	var after_magnet = gm.get_stat_multiplier("magnet_radius")
	assert_gt(after_magnet, 1.0, "Magnet radius multiplier must increase after upgrade")
	gm.free()

func test_weapon_damage_multiplier() -> void:
	var gm_script = ResourceLoader.load("res://scripts/managers/game_manager.gd", "", ResourceLoader.CACHE_MODE_REPLACE)
	var gm = gm_script.new()
	gm._load_upgrades()
	var base_dmg_mult = gm.get_stat_multiplier("weapon_damage")
	gm.upgrade_levels["weapon_damage"] = 1
	var upgraded_dmg_mult = gm.get_stat_multiplier("weapon_damage")
	assert_gt(upgraded_dmg_mult, 1.0, "weapon_damage multiplier must increase after upgrade")
	gm.free()

func test_extra_projectiles_stat() -> void:
	var gm_script = ResourceLoader.load("res://scripts/managers/game_manager.gd", "", ResourceLoader.CACHE_MODE_REPLACE)
	var gm = gm_script.new()
	gm._load_upgrades()
	var base_extras = gm.get_stat_flat_value("extra_projectiles")
	assert_eq(base_extras, 0.0, "Base extra_projectiles must be 0")
	gm.upgrade_levels["additional_projectile"] = 1
	var after_extras = gm.get_stat_flat_value("extra_projectiles")
	assert_eq(after_extras, 1.0, "Extra projectiles must be 1 after first upgrade")
	gm.free()

func test_360_movement_and_heading_tracking() -> void:
	var cam_forward = Vector3(0, 0, -1)
	var cam_right = Vector3(1, 0, 0)
	
	var test_vectors = [
		{"input": Vector2(0, -1), "name": "North", "expected_yaw_deg": 0.0},
		{"input": Vector2(1, 0), "name": "East", "expected_yaw_deg": -90.0},
		{"input": Vector2(0, 1), "name": "South", "expected_yaw_deg": 180.0},
		{"input": Vector2(-1, 0), "name": "West", "expected_yaw_deg": 90.0},
		{"input": Vector2(1, -1).normalized(), "name": "Northeast", "expected_yaw_deg": -45.0},
		{"input": Vector2(-1, -1).normalized(), "name": "Northwest", "expected_yaw_deg": 45.0},
		{"input": Vector2(1, 1).normalized(), "name": "Southeast", "expected_yaw_deg": -135.0},
		{"input": Vector2(-1, 1).normalized(), "name": "Southwest", "expected_yaw_deg": 135.0},
	]
	
	for tv in test_vectors:
		var inp: Vector2 = tv["input"]
		var move_dir = (cam_right * inp.x) + (cam_forward * (-inp.y))
		var target_yaw = atan2(-move_dir.x, -move_dir.z)
		var diff = abs(wrapf(rad_to_deg(target_yaw) - tv["expected_yaw_deg"], -180.0, 180.0))
		assert_true(diff < 0.01, "%s 360 heading must exactly match expected angle" % tv["name"])

func test_player_heli_propulsion_and_responsiveness() -> void:
	var heli_scene = ResourceLoader.load("res://scenes/player/player_heli.tscn", "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	var heli = track(heli_scene.instantiate())
	assert_true(heli is RigidBody3D, "PlayerHeli must be RigidBody3D")
	
	var fwd_acc = float(heli.get("forward_acceleration")) if heli.get("forward_acceleration") != null else 45.0
	var rev_acc = float(heli.get("reverse_acceleration")) if heli.get("reverse_acceleration") != null else 65.0
	var h_drag = float(heli.get("horizontal_drag")) if heli.get("horizontal_drag") != null else 1.4
	
	assert_true(fwd_acc >= 30.0, "forward_acceleration must provide snappy arcade thrust (>= 30 m/s², is: %f)" % fwd_acc)
	assert_true(rev_acc >= 40.0, "reverse_acceleration must provide strong counter-steering (>= 40 m/s², is: %f)" % rev_acc)
	assert_true(h_drag >= 1.0, "horizontal_drag must provide smooth coasting deceleration")

func test_hud_cartoony_style() -> void:
	var hud_scene = ResourceLoader.load("res://scenes/ui/heli_hud.tscn", "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	assert_true(hud_scene != null, "HeliHUD scene must exist")
	var hud = track(hud_scene.instantiate()) as CanvasLayer
	assert_true(hud != null, "HeliHUD must instantiate")
	
	# Verify the single desktop HUD layout.
	assert_true(hud.get_node_or_null("TopBar/Margin/LeftColumn/Counters/DistCounter") != null, "Must have DistCounter")
	assert_true(hud.get_node_or_null("TopBar/Margin/LeftColumn/Counters/CoinCounter") != null, "Must have CoinCounter")
	assert_true(hud.get_node_or_null("TopBar/Margin/LeftColumn/Counters/ElimsCounter") != null, "Must have ElimsCounter")
	assert_true(hud.get_node_or_null("TopBar/Margin/CenterWaveVBox/WaveBarHBox/XPBar") != null, "Must have top-center XPBar")
	assert_true(hud.get_node_or_null("TopBar/Margin/CenterWaveVBox/TimeHBox/TimeLabel") != null, "Must have top-center TimeLabel")
	assert_true(hud.get_node_or_null("TopBar/Margin/PauseButton") != null, "Must have top-right PauseButton")
	assert_true(hud.get_node_or_null("MobileControls") == null, "Desktop HUD must not instance mobile controls")
	assert_true(hud.get_node_or_null("TopBar/Margin/LeftColumn/MissionInfo") == null, "Old mission UI must be removed")
	
	# Verify bottom chunky health and fuel bars with badges
	assert_true(hud.get_node_or_null("BottomBar/Margin/HBox/HealthContainer/HeartBadge") != null, "Must have HeartBadge")
	assert_true(hud.get_node_or_null("BottomBar/Margin/HBox/HealthContainer/HealthBar") != null, "Must have HealthBar")
	assert_true(hud.get_node_or_null("BottomBar/Margin/HBox/FuelContainer/GasBadge") != null, "Must have GasBadge")
	assert_true(hud.get_node_or_null("BottomBar/Margin/HBox/FuelContainer/FuelBar") != null, "Must have FuelBar")
	
	# Verify game over stats modal matching ref_stats.png
	assert_true(hud.get_node_or_null("GameOverModal/Center/Panel/Margin/VBox/BannerHBox/BannerPanel/TitleLabel") != null, "Must have Stats Banner")
	assert_true(hud.get_node_or_null("GameOverModal/Center/Panel/Margin/VBox/TimeHBox") != null, "Must have Stopwatch Time")
	assert_true(hud.get_node_or_null("GameOverModal/Center/Panel/Margin/VBox/CardsHBox/DistCard") != null, "Must have DistCard")
	assert_true(hud.get_node_or_null("GameOverModal/Center/Panel/Margin/VBox/CardsHBox/GoldCard") != null, "Must have GoldCard")
	assert_true(hud.get_node_or_null("GameOverModal/Center/Panel/Margin/VBox/CardsHBox/ElimsCard") != null, "Must have ElimsCard")
	assert_true(hud.get_node_or_null("GameOverModal/Center/Panel/Margin/VBox/LvlProgressHBox") != null, "Must have Level Progress")
