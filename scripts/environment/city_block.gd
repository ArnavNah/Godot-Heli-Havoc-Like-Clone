extends Node3D
class_name CityBlock

const BLOCK_SIZE: float = 44.0
const BuildingScene = preload("res://scenes/environment/building.tscn")
const TurretScene = preload("res://scenes/enemies/tracking_turret.tscn")
const CoinScene = preload("res://scenes/pickups/gold_pickup.tscn")
const FuelScene = preload("res://scenes/pickups/fuel_pickup.tscn")
const HealthScene = preload("res://scenes/pickups/health_pickup.tscn")
const PowerupScene = preload("res://scenes/pickups/power_up.tscn")

@onready var buildings_root: Node3D = $Buildings
@onready var dynamic_root: Node3D = $Dynamic

var current_layout: int = -1
var grid_coords: Vector2i = Vector2i.ZERO

func _ready() -> void:
	if not buildings_root:
		buildings_root = Node3D.new()
		buildings_root.name = "Buildings"
		add_child(buildings_root)
	if not dynamic_root:
		dynamic_root = Node3D.new()
		dynamic_root.name = "Dynamic"
		add_child(dynamic_root)

func reset_and_generate(layout_type: int = -1, difficulty: float = 1.0) -> void:
	_cleanup()
	
	if layout_type < 0:
		layout_type = randi() % 10
	current_layout = layout_type
	
	match layout_type:
		0: _build_layout_a_parallel_corridor(difficulty)
		1: _build_layout_b_four_block_plaza(difficulty)
		2: _build_layout_c_central_tower(difficulty)
		3: _build_layout_d_low_rooftop_arena(difficulty)
		4: _build_layout_e_l_shaped_blocks(difficulty)
		5: _build_layout_f_t_shaped_geometry(difficulty)
		6: _build_layout_g_bridge_arch(difficulty)
		7: _build_layout_h_narrow_trench(difficulty)
		8: _build_layout_i_rooftop_combat(difficulty)
		9: _build_layout_j_open_pickup_zone(difficulty)
		_: _build_layout_a_parallel_corridor(difficulty)

func _cleanup() -> void:
	if not buildings_root:
		buildings_root = get_node_or_null("Buildings")
	if not dynamic_root:
		dynamic_root = get_node_or_null("Dynamic")
		
	if buildings_root:
		for child in buildings_root.get_children():
			child.queue_free()
	if dynamic_root:
		for child in dynamic_root.get_children():
			child.queue_free()

# --- LAYOUT 0 (A): Two Large Parallel Blocks + Clear Corridor ---
func _build_layout_a_parallel_corridor(difficulty: float) -> void:
	var h1 = randf_range(22.0, 32.0)
	var h2 = randf_range(22.0, 32.0)
	var allow_turrets = difficulty > 0.0
	_spawn_pillar(Vector3(-14, 0, 0), 14, 38, h1, allow_turrets)
	_spawn_pillar(Vector3(14, 0, 0), 14, 38, h2, allow_turrets)
	_spawn_coin_trail(Vector3(0, 18, -18), Vector3(0, 18, 18), 8)
	if randf() < 0.4:
		_spawn_fuel(Vector3(0, 18, 0))

# --- LAYOUT 1 (B): Four Blocks around Central Opening ---
func _build_layout_b_four_block_plaza(_difficulty: float) -> void:
	var h1 = randf_range(20.0, 28.0)
	var h2 = randf_range(20.0, 28.0)
	var h3 = randf_range(20.0, 28.0)
	var h4 = randf_range(20.0, 28.0)
	_spawn_pillar(Vector3(-12, 0, -12), 14, 14, h1, true)
	_spawn_pillar(Vector3(12, 0, -12), 14, 14, h2, true)
	_spawn_pillar(Vector3(-12, 0, 12), 14, 14, h3, false)
	_spawn_pillar(Vector3(12, 0, 12), 14, 14, h4, true)
	# Central circular/diamond coin trail
	_spawn_coin_trail(Vector3(0, 18, -8), Vector3(8, 18, 0), 3)
	_spawn_coin_trail(Vector3(8, 18, 0), Vector3(0, 18, 8), 3)
	_spawn_coin_trail(Vector3(0, 18, 8), Vector3(-8, 18, 0), 3)
	_spawn_coin_trail(Vector3(-8, 18, 0), Vector3(0, 18, -8), 3)
	if randf() < 0.35:
		_spawn_powerup(Vector3(0, 18, 0))

# --- LAYOUT 2 (C): Large Central Tower with Two Side Routes ---
func _build_layout_c_central_tower(difficulty: float) -> void:
	var h = randf_range(26.0, 36.0)
	_spawn_pillar(Vector3(0, 0, 0), 18, 18, h, true)
	if difficulty > 1.2 or randf() < 0.4:
		_spawn_turret(Vector3(4, h, 4))
	_spawn_coin_trail(Vector3(-15, 18, -16), Vector3(-15, 18, 16), 5)
	_spawn_coin_trail(Vector3(15, 18, -16), Vector3(15, 18, 16), 5)
	if randf() < 0.35:
		_spawn_fuel(Vector3(-15, 18, 0))

# --- LAYOUT 3 (D): Low Rooftops + Wide Open Movement Area ---
func _build_layout_d_low_rooftop_arena(_difficulty: float) -> void:
	var h1 = randf_range(12.0, 16.0)
	var h2 = randf_range(12.0, 16.0)
	_spawn_pillar(Vector3(-14, 0, -14), 12, 12, h1, true)
	_spawn_pillar(Vector3(14, 0, 14), 12, 12, h2, true)
	_spawn_coin_trail(Vector3(-16, 18, 0), Vector3(16, 18, 0), 8)
	if randf() < 0.4:
		_spawn_fuel(Vector3(0, 18, 0))

# --- LAYOUT 4 (E): L-Shaped Block Layout ---
func _build_layout_e_l_shaped_blocks(_difficulty: float) -> void:
	var h1 = randf_range(22.0, 30.0)
	var h2 = randf_range(20.0, 28.0)
	_spawn_pillar(Vector3(-10, 0, -10), 16, 26, h1, true)
	_spawn_pillar(Vector3(6, 0, -15), 18, 14, h2, true)
	_spawn_coin_trail(Vector3(14, 18, -16), Vector3(14, 18, 16), 6)
	_spawn_coin_trail(Vector3(-14, 18, 14), Vector3(14, 18, 14), 6)
	if randf() < 0.3:
		_spawn_health(Vector3(10, 18, 10))
	if randf() < 0.35:
		_spawn_fuel(Vector3(-10, 18, 14))

# --- LAYOUT 5 (F): T-Shaped Geometry ---
func _build_layout_f_t_shaped_geometry(_difficulty: float) -> void:
	var h1 = randf_range(22.0, 32.0)
	var h2 = randf_range(20.0, 28.0)
	_spawn_pillar(Vector3(0, 0, -12), 34, 12, h1, true)
	_spawn_pillar(Vector3(0, 0, 6), 12, 22, h2, true)
	_spawn_coin_trail(Vector3(-14, 18, 0), Vector3(-14, 18, 18), 5)
	_spawn_coin_trail(Vector3(14, 18, 0), Vector3(14, 18, 18), 5)
	if randf() < 0.4:
		_spawn_fuel(Vector3(0, 18, 18))

# --- LAYOUT 6 (G): Simple Bridge / Arch Area ---
func _build_layout_g_bridge_arch(_difficulty: float) -> void:
	var h1 = 26.0
	var h2 = 26.0
	_spawn_pillar(Vector3(-15, 0, 0), 10, 30, h1, true)
	_spawn_pillar(Vector3(15, 0, 0), 10, 30, h2, true)
	# Overhead bridge arch block
	_spawn_pillar(Vector3(0, 24, 0), 22, 10, 28, false)
	# Flight tunnel through the arch
	_spawn_coin_trail(Vector3(0, 18, -18), Vector3(0, 18, 18), 9)
	if randf() < 0.45:
		_spawn_powerup(Vector3(0, 18, 0))
	elif randf() < 0.4:
		_spawn_fuel(Vector3(0, 18, 0))

# --- LAYOUT 7 (H): Narrow Trench ---
func _build_layout_h_narrow_trench(_difficulty: float) -> void:
	var h1 = randf_range(24.0, 34.0)
	var h2 = randf_range(24.0, 34.0)
	_spawn_pillar(Vector3(-11, 0, 0), 18, 40, h1, true)
	_spawn_pillar(Vector3(11, 0, 0), 18, 40, h2, true)
	# Rapid coin run along narrow 8m trench
	_spawn_coin_trail(Vector3(0, 18, -18), Vector3(0, 18, 18), 10)
	if randf() < 0.4:
		_spawn_fuel(Vector3(0, 18, 0))

# --- LAYOUT 8 (I): Large Rooftop Combat Area ---
func _build_layout_i_rooftop_combat(difficulty: float) -> void:
	var h = randf_range(16.0, 24.0)
	_spawn_pillar(Vector3(-10, 0, -8), 16, 22, h, true)
	_spawn_pillar(Vector3(10, 0, 8), 16, 22, h, true)
	if difficulty > 1.1 or randf() < 0.5:
		_spawn_turret(Vector3(-10, h, -14))
		_spawn_turret(Vector3(10, h, 14))
	_spawn_coin_trail(Vector3(0, 18, -16), Vector3(0, 18, 16), 7)
	if randf() < 0.35:
		_spawn_health(Vector3(0, 18, 0))

# --- LAYOUT 9 (J): Open Pickup Zone ---
func _build_layout_j_open_pickup_zone(_difficulty: float) -> void:
	var h1 = randf_range(18.0, 24.0)
	_spawn_pillar(Vector3(0, 0, 0), 10, 10, h1, true)
	_spawn_coin_trail(Vector3(-16, 18, -16), Vector3(-16, 18, 16), 6)
	_spawn_coin_trail(Vector3(16, 18, -16), Vector3(16, 18, 16), 6)
	_spawn_coin_trail(Vector3(-16, 18, 0), Vector3(16, 18, 0), 6)
	_spawn_fuel(Vector3(0, 18, -14))
	_spawn_powerup(Vector3(0, 18, 14))

# --- HELPER SPAWNERS ---
func _spawn_pillar(pos: Vector3, width: float, depth: float, roof_h: float, force_turret: bool = true) -> Building:
	var bld = BuildingScene.instantiate() as Building
	buildings_root.add_child(bld)
	bld.position = pos
	bld.setup(width, depth, roof_h, false, 0)
	
	if force_turret:
		_spawn_turret(Vector3(pos.x, roof_h, pos.z))
	
	return bld

func _spawn_turret(pos: Vector3) -> void:
	if not TurretScene:
		return
	var turret = TurretScene.instantiate()
	dynamic_root.add_child(turret)
	turret.position = pos

func _spawn_coin_trail(from: Vector3, to: Vector3, count: int) -> void:
	if not CoinScene or count <= 0:
		return
	for i in range(count):
		var t = float(i) / float(max(1, count - 1)) if count > 1 else 0.5
		var p = from.lerp(to, t)
		var coin = CoinScene.instantiate()
		dynamic_root.add_child(coin)
		coin.position = p

func _spawn_fuel(pos: Vector3) -> void:
	if not FuelScene:
		return
	var fuel = FuelScene.instantiate()
	dynamic_root.add_child(fuel)
	fuel.position = pos

func _spawn_health(pos: Vector3) -> void:
	if not HealthScene:
		return
	var hp = HealthScene.instantiate()
	dynamic_root.add_child(hp)
	hp.position = pos

func _spawn_powerup(pos: Vector3) -> void:
	if not PowerupScene:
		return
	var pwr = PowerupScene.instantiate()
	dynamic_root.add_child(pwr)
	pwr.position = pos
