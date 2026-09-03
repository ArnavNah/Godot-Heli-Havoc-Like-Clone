@tool
extends Node

const UpgradeDataClass = preload("res://scripts/resources/upgrade_data.gd")

signal gold_changed(new_amount: int)
signal xp_updated(current_xp: int, xp_required: int, current_level: int)
signal score_changed(new_amount: int)
signal kills_changed(new_amount: int)
signal health_changed(current_health: int, max_health: int)
signal boost_changed(current_boost: float, max_boost: float)
signal notification_triggered(message: String)
signal level_up_requested(choices: Array)

var gold: int = 0
var score: int = 0
var high_score: int = 0
var kills: int = 0
var gold_multiplier: int = 1

var level: int = 1
var current_xp: int = 0
var xp_required: int = 15

var health: int = 100
var max_health: int = 100

var boost: float = 100.0
var max_boost: float = 100.0

# Tracks current level of each upgrade during the run (e.g. {"movement_speed": 2})
var upgrade_levels: Dictionary = {}
var all_upgrades: Array = []

func _ready() -> void:
	_load_upgrades()
	reset()

func _load_upgrades() -> void:
	all_upgrades.clear()
	var upgrade_files = [
		"res://resources/upgrades/movement_speed.tres",
		"res://resources/upgrades/acceleration.tres",
		"res://resources/upgrades/turn_speed.tres",
		"res://resources/upgrades/boost_power.tres",
		"res://resources/upgrades/boost_duration.tres",
		"res://resources/upgrades/max_health.tres",
		"res://resources/upgrades/weapon_damage.tres",
		"res://resources/upgrades/fire_rate.tres",
		"res://resources/upgrades/additional_projectile.tres",
		"res://resources/upgrades/magnet_radius.tres",
		"res://resources/upgrades/xp_gain.tres",
		"res://resources/upgrades/coin_value.tres"
	]
	for path in upgrade_files:
		if ResourceLoader.exists(path):
			var res = load(path)
			if res:
				all_upgrades.append(res)

func reset() -> void:
	gold = 0
	score = 0
	kills = 0
	gold_multiplier = 1
	
	level = 1
	current_xp = 0
	xp_required = 15
	
	health = 100
	max_health = 100
	boost = 100.0
	max_boost = 100.0
	
	upgrade_levels.clear()
	pending_level_ups = 0
	is_leveling_up = false
	
	gold_changed.emit(gold)
	xp_updated.emit(current_xp, xp_required, level)
	score_changed.emit(score)
	kills_changed.emit(kills)
	health_changed.emit(health, max_health)
	boost_changed.emit(boost, max_boost)

func get_upgrade_level(upgrade_id: String) -> int:
	return upgrade_levels.get(upgrade_id, 0)

func get_stat_multiplier(stat_type: String) -> float:
	var mult = 1.0
	for upg in all_upgrades:
		if upg.get("stat_type") == stat_type:
			var lvl = get_upgrade_level(upg.get("id"))
			var step = upg.get("base_multiplier_per_level")
			if lvl > 0 and step > 0.0:
				mult += step * lvl
	return mult

func get_stat_flat_value(stat_type: String) -> float:
	var total = 0.0
	for upg in all_upgrades:
		if upg.get("stat_type") == stat_type:
			var lvl = get_upgrade_level(upg.get("id"))
			var flat = upg.get("flat_value_per_level")
			if lvl > 0 and flat > 0.0:
				total += flat * lvl
	return total

var pending_level_ups: int = 0
var is_leveling_up: bool = false

func add_gold(amount: int = 1) -> void:
	var coin_mult = get_stat_multiplier("coin_value")
	var total = int(amount * coin_mult * gold_multiplier)
	gold += total
	score += total * 10
	if score > high_score:
		high_score = score
	gold_changed.emit(gold)
	score_changed.emit(score)

func add_xp(amount: int = 1) -> void:
	var xp_mult = get_stat_multiplier("xp_gain")
	var total_xp = int(amount * xp_mult)
	current_xp += total_xp
	score += total_xp * 25
	if score > high_score:
		high_score = score
	score_changed.emit(score)
	
	# Check for level up threshold (support multi-level pickups)
	while current_xp >= xp_required:
		current_xp -= xp_required
		level += 1
		xp_required = int(xp_required * 1.35) + 8
		pending_level_ups += 1
	
	xp_updated.emit(current_xp, xp_required, level)
	
	if pending_level_ups > 0 and not is_leveling_up:
		_trigger_level_up()

func _trigger_level_up() -> void:
	# Filter available upgrades not yet maxed out
	var available: Array = []
	for upg in all_upgrades:
		var curr_lvl = get_upgrade_level(upg.get("id"))
		var max_lvl = int(upg.get("max_level"))
		if curr_lvl < max_lvl:
			available.append(upg)
	
	if available.is_empty():
		pending_level_ups = 0
		is_leveling_up = false
		return
	
	is_leveling_up = true
	available.shuffle()
	var choices: Array = []
	for i in range(mini(3, available.size())):
		var upg = available[i]
		var next_lvl = get_upgrade_level(upg.get("id")) + 1
		choices.append({
			"upgrade": upg,
			"next_level": next_lvl,
			"max_level": int(upg.get("max_level"))
		})
	
	level_up_requested.emit(choices)

func apply_upgrade(upgrade_resource: Resource) -> void:
	if not upgrade_resource:
		return
	
	var id = str(upgrade_resource.get("id"))
	var new_lvl = get_upgrade_level(id) + 1
	upgrade_levels[id] = new_lvl
	
	# Handle specific stats
	var stat_type = str(upgrade_resource.get("stat_type"))
	if stat_type == "max_health":
		var flat = float(upgrade_resource.get("flat_value_per_level"))
		max_health += int(flat)
		health = max_health # Full heal on health upgrade
		health_changed.emit(health, max_health)
	elif stat_type == "boost_duration":
		max_boost = 100.0 * get_stat_multiplier("boost_duration")
		boost = max_boost
		boost_changed.emit(boost, max_boost)
	
	_update_player_stats()
	
	var title = str(upgrade_resource.get("title"))
	if upgrade_resource.has_method("get_title_for_level"):
		title = upgrade_resource.get_title_for_level(new_lvl)
	notification_triggered.emit("%s UNLOCKED!" % title.to_upper())
	
	pending_level_ups = max(0, pending_level_ups - 1)
	is_leveling_up = false
	
	if pending_level_ups > 0:
		_trigger_level_up()

func _update_player_stats() -> void:
	if not is_inside_tree():
		return
	var tree = get_tree()
	if not tree:
		return
	
	var players = tree.get_nodes_in_group("PlayerHeli")
	if players.is_empty():
		players = tree.get_nodes_in_group("player")
	
	for p in players:
		if p is PlayerHeli:
			var speed_mult = get_stat_multiplier("move_speed")
			var fire_mult = get_stat_multiplier("fire_rate")
			var fuel_mult = get_stat_multiplier("max_fuel")
			var fuel_eff = get_stat_multiplier("fuel_efficiency")
			var turn_mult = get_stat_multiplier("turn_speed")
			var boost_mult = get_stat_multiplier("boost_power")
			var accel_mult = get_stat_multiplier("acceleration")
			
			p.max_speed = 27.0 * speed_mult
			p.forward_acceleration = 48.0 * accel_mult
			p.steering_acceleration = 62.0 * accel_mult
			p.reverse_acceleration = 85.0 * accel_mult
			p.fire_cooldown = 0.11 / maxf(1.0, fire_mult)
			p.yaw_speed = 7.5 * turn_mult
			p.lift_acceleration = 24.0 * boost_mult
			p.max_rise_speed = 10.0 * boost_mult
			
			if p.fuel_component:
				p.fuel_component.set_max_fuel(100.0 * fuel_mult)
				p.fuel_component.drain_multiplier = 1.0 / maxf(1.0, fuel_eff)
			if p.health_component:
				var bonus_hp = int(get_stat_flat_value("max_health"))
				p.health_component.set_max_health(100 + bonus_hp)
		elif p is PlayerHelicopter:
			var speed_mult = get_stat_multiplier("move_speed")
			var accel_mult = get_stat_multiplier("acceleration")
			var turn_mult = get_stat_multiplier("turn_speed")
			var boost_mult = get_stat_multiplier("boost_power")
			
			p.cruise_speed = 20.0 * speed_mult
			p.max_forward_speed = 32.0 * boost_mult * speed_mult
			p.forward_acceleration = 65.0 * accel_mult
			p.lateral_speed = 24.0 * turn_mult
			p.lateral_acceleration = 75.0 * accel_mult

func add_health(amount: int = 25) -> void:
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)
	notification_triggered.emit("+%d HEALTH!" % amount)

func add_boost(amount: float = 35.0) -> void:
	boost = minf(boost + amount, max_boost)
	boost_changed.emit(boost, max_boost)
	notification_triggered.emit("+BOOST RECHARGED!")

func use_boost(amount: float) -> void:
	boost = maxf(0.0, boost - amount)
	boost_changed.emit(boost, max_boost)

func add_powerup(powerup_name: String = "FIREPOWER") -> void:
	score += 200
	score_changed.emit(score)
	notification_triggered.emit("POWERUP: %s!" % powerup_name.to_upper())

func add_kill() -> void:
	kills += 1
	score += 100
	kills_changed.emit(kills)
	score_changed.emit(score)
