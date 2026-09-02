extends Node3D
class_name MenuBackgroundScroller

@export var scroll_speed: float = 24.0
@export var row_count: int = 7
@export var col_count: int = 5
@export var cell_spacing_x: float = 12.0
@export var cell_spacing_z: float = 14.0
@export var recycle_z_threshold: float = 12.0

const PillarMat = preload("res://resources/materials/building_near.tres")

var cells: Array[MeshInstance3D] = []
var total_length_z: float = 0.0

func _ready() -> void:
	total_length_z = row_count * cell_spacing_z
	_generate_treadmill_cells()

func _generate_treadmill_cells() -> void:
	for r in range(row_count):
		for c in range(col_count):
			var cell = _create_cell()
			add_child(cell)
			cells.append(cell)
			
			var x_pos = (c - (col_count - 1) * 0.5) * cell_spacing_x
			var z_pos = -r * cell_spacing_z
			var h = randf_range(10.0, 26.0)
			
			cell.position = Vector3(x_pos, h * 0.5 - 12.0, z_pos)
			_set_cell_height(cell, h)

func _process(delta: float) -> void:
	var move_dist = scroll_speed * delta
	
	for cell in cells:
		cell.position.z += move_dist
		
		# If cell passes behind camera, reset to far distance
		if cell.position.z > recycle_z_threshold:
			cell.position.z -= total_length_z
			var new_h = randf_range(10.0, 26.0)
			cell.position.y = new_h * 0.5 - 12.0
			_set_cell_height(cell, new_h)

func _create_cell() -> MeshInstance3D:
	var mesh_inst = MeshInstance3D.new()
	var box_m = BoxMesh.new()
	box_m.size = Vector3(8.0, 20.0, 8.0)
	mesh_inst.mesh = box_m
	mesh_inst.material_override = PillarMat
	return mesh_inst

func _set_cell_height(cell: MeshInstance3D, h: float) -> void:
	if cell.mesh is BoxMesh:
		var bm = cell.mesh as BoxMesh
		bm.size = Vector3(7.5, h + 30.0, 7.5)
