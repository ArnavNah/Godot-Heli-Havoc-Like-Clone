extends Node3D
class_name CityGridManager

const BLOCK_SIZE: float = 44.0
const GRID_RADIUS: int = 3 # 7x7 grid (-3 to +3, 49 cells)
const CityBlockScene = preload("res://scenes/environment/city_block.tscn")
const CityBlockClass = preload("res://scripts/environment/city_block.gd")
const CloudScene = preload("res://scenes/environment/cloud.tscn")

@export var target_player_path: NodePath
var target_player: Node3D = null

# Dictionary mapping Vector2i(gx, gz) -> CityBlock
var active_blocks: Dictionary = {}
var active_clouds: Dictionary = {}
var center_gx: int = 0
var center_gz: int = 0
var is_initialized: bool = false

func _ready() -> void:
	if not target_player_path.is_empty():
		target_player = get_node_or_null(target_player_path)
	
	_initialize_grid()

func _physics_process(_delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("PlayerHeli")
		if players.is_empty():
			players = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			target_player = players[0]
		else:
			return
	
	var player_pos = target_player.global_position
	var diff_x = player_pos.x - (float(center_gx) * BLOCK_SIZE)
	var diff_z = player_pos.z - (float(center_gz) * BLOCK_SIZE)
	
	# Solid hysteresis: only shift when a full block distance has been traversed
	if abs(diff_x) >= BLOCK_SIZE:
		var step_x = int(sign(diff_x))
		_shift_grid(center_gx + step_x, center_gz)
		
	if abs(diff_z) >= BLOCK_SIZE:
		var step_z = int(sign(diff_z))
		_shift_grid(center_gx, center_gz + step_z)

func _initialize_grid() -> void:
	if is_initialized:
		return
	is_initialized = true
	
	center_gx = 0
	center_gz = 0
	
	for gx in range(-GRID_RADIUS, GRID_RADIUS + 1):
		for gz in range(-GRID_RADIUS, GRID_RADIUS + 1):
			var coord = Vector2i(gx, gz)
			var block = CityBlockScene.instantiate()
			add_child(block)
			block.position = Vector3(gx * BLOCK_SIZE, 0, gz * BLOCK_SIZE)
			block.grid_coords = coord
			
			# Starting 3x3 core area uses open / clear corridors so the player has lots of breathing room
			var is_near_start = (abs(gx) <= 1 and abs(gz) <= 1)
			var diff = 0.0 if is_near_start else _calc_difficulty(coord)
			var layout = 0 if (gx == 0 and gz == 0) else (0 if is_near_start else randi() % 10)
			block.reset_and_generate(layout, diff)
			active_blocks[coord] = block
			
			# Sparse atmospheric clouds high in the sky (Y = 44 to 58m)
			if randf() < 0.20 and CloudScene:
				var cloud = CloudScene.instantiate()
				add_child(cloud)
				cloud.position = Vector3(
					gx * BLOCK_SIZE + randf_range(-12, 12),
					randf_range(44.0, 58.0),
					gz * BLOCK_SIZE + randf_range(-12, 12)
				)
				active_clouds[coord] = cloud

func _shift_grid(new_gx: int, new_gz: int) -> void:
	center_gx = new_gx
	center_gz = new_gz
	
	var recycled_blocks: Array = []
	var keys_to_remove: Array[Vector2i] = []
	
	# Find blocks outside the new 7x7 bounds
	for coord in active_blocks.keys():
		if abs(coord.x - new_gx) > GRID_RADIUS or abs(coord.y - new_gz) > GRID_RADIUS:
			recycled_blocks.append(active_blocks[coord])
			keys_to_remove.append(coord)
			if active_clouds.has(coord):
				var old_cloud = active_clouds[coord]
				if is_instance_valid(old_cloud):
					old_cloud.queue_free()
				active_clouds.erase(coord)
	
	for k in keys_to_remove:
		active_blocks.erase(k)
	
	# Assign recycled blocks to newly needed coordinates
	var recycle_idx = 0
	for gx in range(new_gx - GRID_RADIUS, new_gx + GRID_RADIUS + 1):
		for gz in range(new_gz - GRID_RADIUS, new_gz + GRID_RADIUS + 1):
			var target_coord = Vector2i(gx, gz)
			if not active_blocks.has(target_coord):
				var block: CityBlock = null
				if recycle_idx < recycled_blocks.size():
					block = recycled_blocks[recycle_idx]
					recycle_idx += 1
				else:
					block = CityBlockScene.instantiate()
					add_child(block)
				
				block.position = Vector3(gx * BLOCK_SIZE, 0, gz * BLOCK_SIZE)
				block.grid_coords = target_coord
				var diff = _calc_difficulty(target_coord)
				block.reset_and_generate(randi() % 10, diff)
				active_blocks[target_coord] = block
				
				# Spawn cloud in new cell
				if randf() < 0.20 and CloudScene and not active_clouds.has(target_coord):
					var cloud = CloudScene.instantiate()
					add_child(cloud)
					cloud.position = Vector3(
						gx * BLOCK_SIZE + randf_range(-12, 12),
						randf_range(44.0, 58.0),
						gz * BLOCK_SIZE + randf_range(-12, 12)
					)
					active_clouds[target_coord] = cloud

func _calc_difficulty(coord: Vector2i) -> float:
	var dist = coord.length()
	return clampf(0.5 + dist * 0.1, 0.5, 1.8)
