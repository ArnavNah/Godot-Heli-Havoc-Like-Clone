extends Node3D
class_name WorldGridManager

# Spawner scenes configuration
@export var spawn_scenes: Array[PackedScene] = []
@export var power_up_scene: PackedScene = preload("res://scenes/pickups/power_up.tscn")
@export var tracking_turret_scene: PackedScene = preload("res://scenes/enemies/tracking_turret.tscn")
@export var cloud_scene: PackedScene = preload("res://scenes/environment/cloud.tscn")

@export var player_node_path: NodePath
@export var grid_dimension: int = 5
@export var tile_size: float = 34.0

var planes: Array[Node3D] = []
var player_ref: Node3D = null
var center_tile_x: float = 0.0
var center_tile_z: float = 0.0

var dark_blue_material: StandardMaterial3D

func _ready() -> void:
	_create_materials()
	_generate_initial_grid()
	
	if not player_node_path.is_empty():
		player_ref = get_node_or_null(player_node_path)
	if not player_ref:
		var players = get_tree().get_nodes_in_group("PlayerHeli")
		if players.is_empty():
			players = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			player_ref = players[0]

func _create_materials() -> void:
	# Flat, unshaded solid dark blue material for all floating maze blocks
	dark_blue_material = StandardMaterial3D.new()
	dark_blue_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark_blue_material.albedo_color = Color(0.04, 0.16, 0.52, 1.0) # Solid dark blue

func _generate_initial_grid() -> void:
	planes.clear()
	var half_grid: int = int((grid_dimension - 1) * 0.5) # for 5x5: -2 to +2
	
	for gx in range(-half_grid, half_grid + 1):
		for gz in range(-half_grid, half_grid + 1):
			var tile_node = Node3D.new()
			tile_node.name = "Tile_%d_%d" % [gx, gz]
			add_child(tile_node)
			tile_node.position = Vector3(gx * tile_size, 0.0, gz * tile_size)
			
			# Spawns Container (No flat floor plane - completely open void)
			var spawns_node = Node3D.new()
			spawns_node.name = "Spawns"
			tile_node.add_child(spawns_node)
			
			planes.append(tile_node)
			
			# Populate maze blocks & clouds
			if abs(gx) > 0 or abs(gz) > 0:
				populate_grid_cell(tile_node)

func _physics_process(_delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		var players = get_tree().get_nodes_in_group("PlayerHeli")
		if players.is_empty():
			players = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			player_ref = players[0]
		else:
			return
	
	var p_pos = player_ref.global_position
	var diff_x = p_pos.x - center_tile_x
	var diff_z = p_pos.z - center_tile_z
	
	var threshold = tile_size * 0.5
	var total_span = grid_dimension * tile_size
	
	# Shift X
	while diff_x > threshold:
		_shift_grid_x(total_span, true)
		center_tile_x += tile_size
		diff_x = p_pos.x - center_tile_x
		
	while diff_x < -threshold:
		_shift_grid_x(-total_span, false)
		center_tile_x -= tile_size
		diff_x = p_pos.x - center_tile_x
	
	# Shift Z
	while diff_z > threshold:
		_shift_grid_z(total_span, true)
		center_tile_z += tile_size
		diff_z = p_pos.z - center_tile_z
		
	while diff_z < -threshold:
		_shift_grid_z(-total_span, false)
		center_tile_z -= tile_size
		diff_z = p_pos.z - center_tile_z

# Treadmill Shifting & Recycle Cleanup
func _shift_grid_x(offset: float, moving_positive: bool) -> void:
	var extreme_x = planes[0].position.x
	for p in planes:
		if moving_positive:
			extreme_x = minf(extreme_x, p.position.x)
		else:
			extreme_x = maxf(extreme_x, p.position.x)
	
	for p in planes:
		if is_equal_approx(p.position.x, extreme_x):
			p.position.x += offset
			_clear_cell_spawns(p)
			populate_grid_cell(p)

func _shift_grid_z(offset: float, moving_positive: bool) -> void:
	var extreme_z = planes[0].position.z
	for p in planes:
		if moving_positive:
			extreme_z = minf(extreme_z, p.position.z)
		else:
			extreme_z = maxf(extreme_z, p.position.z)
	
	for p in planes:
		if is_equal_approx(p.position.z, extreme_z):
			p.position.z += offset
			_clear_cell_spawns(p)
			populate_grid_cell(p)

func _clear_cell_spawns(cell_node: Node3D) -> void:
	var container = cell_node.get_node_or_null("Spawns")
	if container:
		for child in container.get_children():
			child.queue_free()

# Step 2: Floating Block Generation
func populate_grid_cell(cell_node: Node3D) -> void:
	var container = cell_node.get_node_or_null("Spawns")
	if not container:
		container = Node3D.new()
		container.name = "Spawns"
		cell_node.add_child(container)
	
	var block_tops: Array[Vector3] = []
	
	# Spawn 2 to 4 floating maze blocks of highly variable scales (pillars, wide walls, floating arches)
	var block_count = randi_range(2, 4)
	for i in range(block_count):
		var block_type = randi() % 3
		var b_size: Vector3
		var b_pos: Vector3
		
		match block_type:
			0:
				# Tall vertical pillar
				var w = randf_range(5.0, 8.0)
				var d = randf_range(5.0, 8.0)
				var h = randf_range(20.0, 36.0)
				b_size = Vector3(w, h, d)
				b_pos = Vector3(randf_range(-tile_size * 0.35, tile_size * 0.35), h * 0.5, randf_range(-tile_size * 0.35, tile_size * 0.35))
				block_tops.append(Vector3(b_pos.x, h, b_pos.z))
			1:
				# Wide horizontal wall
				var is_wide_x = randf() < 0.5
				var w = randf_range(16.0, 22.0) if is_wide_x else randf_range(4.5, 6.5)
				var d = randf_range(4.5, 6.5) if is_wide_x else randf_range(16.0, 22.0)
				var h = randf_range(14.0, 26.0)
				b_size = Vector3(w, h, d)
				b_pos = Vector3(randf_range(-tile_size * 0.25, tile_size * 0.25), h * 0.5, randf_range(-tile_size * 0.25, tile_size * 0.25))
				block_tops.append(Vector3(b_pos.x, h, b_pos.z))
			2:
				# Floating arch / bridge block suspended high up in the air
				var is_span_x = randf() < 0.5
				var w = randf_range(14.0, 20.0) if is_span_x else randf_range(5.0, 7.0)
				var d = randf_range(5.0, 7.0) if is_span_x else randf_range(14.0, 20.0)
				var h = randf_range(4.0, 6.0)
				var arch_y = randf_range(20.0, 28.0)
				b_size = Vector3(w, h, d)
				b_pos = Vector3(randf_range(-tile_size * 0.2, tile_size * 0.2), arch_y, randf_range(-tile_size * 0.2, tile_size * 0.2))
				block_tops.append(Vector3(b_pos.x, arch_y + h * 0.5, b_pos.z))
		
		# Create Floating Cube Node
		var block_body = StaticBody3D.new()
		block_body.collision_layer = 2 # Layer 2: Environment
		block_body.collision_mask = 0
		block_body.position = b_pos
		
		var mesh_inst = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = b_size
		mesh_inst.mesh = box_mesh
		mesh_inst.material_override = dark_blue_material
		block_body.add_child(mesh_inst)
		
		var col_shape = CollisionShape3D.new()
		var box_col = BoxShape3D.new()
		box_col.size = b_size
		col_shape.shape = box_col
		block_body.add_child(col_shape)
		
		container.add_child(block_body)
	
	# 60% chance to spawn a TrackingTurret on top of a floating block
	if randf() < 0.60 and not block_tops.is_empty() and tracking_turret_scene:
		var target_top = block_tops.pick_random()
		var turret = tracking_turret_scene.instantiate()
		container.add_child(turret)
		turret.position = target_top
	
	# 40% chance to spawn a line of COIN PowerUps in gaps / under arches
	if randf() < 0.40 and power_up_scene:
		var coin_count = randi_range(4, 7)
		var is_along_x = randf() < 0.5
		var start_offset = -tile_size * 0.35
		var step = (tile_size * 0.7) / float(coin_count)
		var fixed_lane = randf_range(-tile_size * 0.15, tile_size * 0.15)
		var coin_y = randf_range(16.0, 22.0)
		
		for c in range(coin_count):
			var coin = power_up_scene.instantiate()
			if coin.get("pickup_type") != null:
				coin.pickup_type = PowerUp.PickupType.COIN
			container.add_child(coin)
			
			var c_x = (start_offset + c * step) if is_along_x else fixed_lane
			var c_z = fixed_lane if is_along_x else (start_offset + c * step)
			coin.position = Vector3(c_x, coin_y, c_z)
	
	# Rare 10% chance to spawn special PowerUp
	if randf() < 0.10 and power_up_scene:
		var special_types = [
			PowerUp.PickupType.FUEL,
			PowerUp.PickupType.INSTAKILL,
			PowerUp.PickupType.NUKE,
			PowerUp.PickupType.DOUBLE_COIN
		]
		var special_pup = power_up_scene.instantiate()
		if special_pup.get("pickup_type") != null:
			special_pup.pickup_type = special_types.pick_random()
		container.add_child(special_pup)
		special_pup.position = Vector3(randf_range(-2.0, 2.0), randf_range(17.0, 23.0), randf_range(-2.0, 2.0))
	
	# Step 3: Atmospheric Clouds high in the sky (y = 42m - 58m)
	if cloud_scene and randf() < 0.75:
		var cloud_inst = cloud_scene.instantiate()
		container.add_child(cloud_inst)
		cloud_inst.position = Vector3(
			randf_range(-tile_size * 0.4, tile_size * 0.4),
			randf_range(42.0, 58.0),
			randf_range(-tile_size * 0.4, tile_size * 0.4)
		)
		var scale_rnd = randf_range(0.8, 1.4)
		cloud_inst.scale = Vector3(scale_rnd, scale_rnd, scale_rnd)
