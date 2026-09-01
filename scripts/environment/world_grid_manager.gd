extends Node3D
class_name WorldGridManager

@export var player_node_path: NodePath
@export var turret_scene: PackedScene = preload("res://scenes/enemies/tracking_turret.tscn")
@export var fuel_scene: PackedScene = preload("res://scenes/pickups/fuel_pickup.tscn")

@export var grid_dimension: int = 5
@export var tile_size: float = 10.0
@export var spawn_chance: float = 0.35 # 35% chance to spawn hazard or pickup

var planes: Array[Node3D] = []
var player_ref: Node3D = null
var center_tile_x: float = 0.0
var center_tile_z: float = 0.0

var tile_material: StandardMaterial3D

func _ready() -> void:
	_create_tile_material()
	_generate_initial_grid()
	
	if not player_node_path.is_empty():
		player_ref = get_node_or_null(player_node_path)
	if not player_ref:
		var players = get_tree().get_nodes_in_group("PlayerHeli")
		if players.size() > 0:
			player_ref = players[0]

func _create_tile_material() -> void:
	tile_material = StandardMaterial3D.new()
	tile_material.albedo_color = Color(0.24, 0.74, 0.32, 1.0) # Solid green albedo
	tile_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	tile_material.roughness = 0.95
	tile_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

func _generate_initial_grid() -> void:
	planes.clear()
	var half_grid: int = int((grid_dimension - 1) * 0.5) # for 5x5, half is 2 (-2 to +2)
	
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(tile_size, tile_size)
	
	for gx in range(-half_grid, half_grid + 1):
		for gz in range(-half_grid, half_grid + 1):
			var tile_node = Node3D.new()
			tile_node.name = "Tile_%d_%d" % [gx, gz]
			add_child(tile_node)
			tile_node.position = Vector3(gx * tile_size, 0.0, gz * tile_size)
			
			# Mesh instance
			var mesh_inst = MeshInstance3D.new()
			mesh_inst.mesh = plane_mesh
			mesh_inst.material_override = tile_material
			tile_node.add_child(mesh_inst)
			
			# Collision floor on Layer 2 (Environment)
			var static_body = StaticBody3D.new()
			static_body.collision_layer = 2
			static_body.collision_mask = 0
			var col_shape = CollisionShape3D.new()
			var box_shape = BoxShape3D.new()
			box_shape.size = Vector3(tile_size, 0.2, tile_size)
			col_shape.shape = box_shape
			col_shape.position = Vector3(0, -0.1, 0)
			static_body.add_child(col_shape)
			tile_node.add_child(static_body)
			
			# Container for spawned items
			var spawn_container = Node3D.new()
			spawn_container.name = "Spawns"
			tile_node.add_child(spawn_container)
			
			planes.append(tile_node)
			
			# Spawn initial items (except center tile)
			if abs(gx) > 0 or abs(gz) > 0:
				_roll_spawns_for_tile(tile_node)

func _physics_process(_delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		var players = get_tree().get_nodes_in_group("PlayerHeli")
		if players.size() > 0:
			player_ref = players[0]
		else:
			return
	
	var p_pos = player_ref.global_position
	var diff_x = p_pos.x - center_tile_x
	var diff_z = p_pos.z - center_tile_z
	
	var threshold = tile_size * 0.5 # 5.0 units
	var total_span = grid_dimension * tile_size # 50.0 units
	
	# Shift X
	while diff_x > threshold:
		_shift_grid_x(total_span, true) # Move -X planes to +X
		center_tile_x += tile_size
		diff_x = p_pos.x - center_tile_x
		
	while diff_x < -threshold:
		_shift_grid_x(-total_span, false) # Move +X planes to -X
		center_tile_x -= tile_size
		diff_x = p_pos.x - center_tile_x
	
	# Shift Z
	while diff_z > threshold:
		_shift_grid_z(total_span, true) # Move -Z planes to +Z
		center_tile_z += tile_size
		diff_z = p_pos.z - center_tile_z
		
	while diff_z < -threshold:
		_shift_grid_z(-total_span, false) # Move +Z planes to -Z
		center_tile_z -= tile_size
		diff_z = p_pos.z - center_tile_z

func _shift_grid_x(offset: float, moving_positive: bool) -> void:
	# Find the extreme X bound of planes
	var extreme_x = planes[0].position.x
	for p in planes:
		if moving_positive:
			extreme_x = minf(extreme_x, p.position.x)
		else:
			extreme_x = maxf(extreme_x, p.position.x)
	
	for p in planes:
		if is_equal_approx(p.position.x, extreme_x):
			p.position.x += offset
			_clear_tile_spawns(p)
			_roll_spawns_for_tile(p)

func _shift_grid_z(offset: float, moving_positive: bool) -> void:
	# Find the extreme Z bound of planes
	var extreme_z = planes[0].position.z
	for p in planes:
		if moving_positive:
			extreme_z = minf(extreme_z, p.position.z)
		else:
			extreme_z = maxf(extreme_z, p.position.z)
	
	for p in planes:
		if is_equal_approx(p.position.z, extreme_z):
			p.position.z += offset
			_clear_tile_spawns(p)
			_roll_spawns_for_tile(p)

func _clear_tile_spawns(tile_node: Node3D) -> void:
	var container = tile_node.get_node_or_null("Spawns")
	if container:
		for child in container.get_children():
			child.queue_free()

func _roll_spawns_for_tile(tile_node: Node3D) -> void:
	if randf() > spawn_chance:
		return
	
	var container = tile_node.get_node_or_null("Spawns")
	if not container:
		return
	
	# Random local offset on the 10x10 plane
	var offset_x = randf_range(-3.5, 3.5)
	var offset_z = randf_range(-3.5, 3.5)
	var local_spawn_pos = Vector3(offset_x, 0, offset_z)
	
	# 50% Turret, 50% FuelPickup
	if randf() < 0.5:
		if turret_scene:
			var turret = turret_scene.instantiate()
			container.add_child(turret)
			turret.position = local_spawn_pos
	else:
		if fuel_scene:
			var fuel = fuel_scene.instantiate()
			container.add_child(fuel)
			fuel.position = local_spawn_pos + Vector3(0, 1.2, 0)
