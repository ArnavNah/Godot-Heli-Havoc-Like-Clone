extends Node3D
class_name EndlessGridManager

@export var tile_scene: PackedScene = preload("res://scenes/environment/world_tile.tscn")
@export var player_node_path: NodePath
@export var grid_dimension: int = 5 # 5x5 grid
@export var tile_size: float = 10.0

var tiles: Array[Node3D] = []
var player_ref: Node3D = null
var center_tile_x: float = 0.0
var center_tile_z: float = 0.0

func _ready() -> void:
	_generate_initial_grid()
	
	if not player_node_path.is_empty():
		player_ref = get_node_or_null(player_node_path)
	if not player_ref:
		var players = get_tree().get_nodes_in_group("PlayerHeli")
		if players.size() > 0:
			player_ref = players[0]

func _generate_initial_grid() -> void:
	tiles.clear()
	var half_grid: int = int((grid_dimension - 1) * 0.5)
	
	for gx in range(-half_grid, half_grid + 1):
		for gz in range(-half_grid, half_grid + 1):
			var tile_inst = tile_scene.instantiate() if tile_scene else Node3D.new()
			tile_inst.name = "Tile_%d_%d" % [gx, gz]
			add_child(tile_inst)
			tile_inst.position = Vector3(gx * tile_size, 0.0, gz * tile_size)
			tiles.append(tile_inst)
			
			if tile_inst.has_method("repopulate"):
				var is_center = (gx == 0 and gz == 0)
				tile_inst.repopulate(is_center)

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

func _shift_grid_x(offset: float, moving_positive: bool) -> void:
	var extreme_x = tiles[0].position.x
	for t in tiles:
		if moving_positive:
			extreme_x = minf(extreme_x, t.position.x)
		else:
			extreme_x = maxf(extreme_x, t.position.x)
	
	for t in tiles:
		if is_equal_approx(t.position.x, extreme_x):
			t.position.x += offset
			if t.has_method("repopulate"):
				t.repopulate(false)

func _shift_grid_z(offset: float, moving_positive: bool) -> void:
	var extreme_z = tiles[0].position.z
	for t in tiles:
		if moving_positive:
			extreme_z = minf(extreme_z, t.position.z)
		else:
			extreme_z = maxf(extreme_z, t.position.z)
	
	for t in tiles:
		if is_equal_approx(t.position.z, extreme_z):
			t.position.z += offset
			if t.has_method("repopulate"):
				t.repopulate(false)
