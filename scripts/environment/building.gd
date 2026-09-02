@tool
extends StaticBody3D
class_name Building

const BASE_Y: float = -60.0

@export var building_width: float = 12.0:
	set(val):
		building_width = val
		if Engine.is_editor_hint():
			_update_geometry()

@export var building_depth: float = 12.0:
	set(val):
		building_depth = val
		if Engine.is_editor_hint():
			_update_geometry()

@export var roof_height: float = 18.0:
	set(val):
		roof_height = val
		if Engine.is_editor_hint():
			_update_geometry()

@export var has_ledge: bool = false:
	set(val):
		has_ledge = val
		if Engine.is_editor_hint():
			_update_geometry()

@export var material_override_res: Material = null:
	set(val):
		material_override_res = val
		if Engine.is_editor_hint():
			_update_geometry()

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var ledge_mesh: MeshInstance3D = get_node_or_null("LedgeMesh")
@onready var ledge_collision: CollisionShape3D = get_node_or_null("LedgeCollision")

const MAT_NEAR = preload("res://resources/materials/building_near.tres")
const MAT_MID = preload("res://resources/materials/building_mid.tres")
const MAT_ROOF = preload("res://resources/materials/building_rooftop.tres")

func _ready() -> void:
	collision_layer = 2 # Environment
	collision_mask = 0
	_update_geometry()

func setup(p_width: float, p_depth: float, p_roof_height: float, p_has_ledge: bool = false, mat_type: int = 0) -> void:
	building_width = p_width
	building_depth = p_depth
	roof_height = p_roof_height
	has_ledge = p_has_ledge
	if mat_type == 1:
		material_override_res = MAT_MID
	elif mat_type == 2:
		material_override_res = MAT_ROOF
	else:
		material_override_res = MAT_NEAR
	_update_geometry()

func get_roof_position() -> Vector3:
	return global_position + Vector3(0, roof_height, 0)

func _update_geometry() -> void:
	if not mesh_instance:
		mesh_instance = get_node_or_null("MeshInstance3D")
	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape3D")
	
	if not mesh_instance or not collision_shape:
		return
	
	var total_h = roof_height - BASE_Y
	var center_y = (roof_height + BASE_Y) * 0.5
	var full_size = Vector3(building_width, total_h, building_depth)
	
	# Main Building Mesh - ALWAYS unique mesh instance
	var box_mesh = BoxMesh.new()
	box_mesh.size = full_size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = Vector3(0, center_y, 0)
	
	if material_override_res:
		mesh_instance.material_override = material_override_res
	else:
		mesh_instance.material_override = MAT_NEAR
	
	# Main Building Collision - ALWAYS unique collision shape instance
	var box_shape = BoxShape3D.new()
	box_shape.size = full_size
	collision_shape.shape = box_shape
	collision_shape.position = Vector3(0, center_y, 0)
	
	# Rooftop Ledge
	if not ledge_mesh:
		ledge_mesh = get_node_or_null("LedgeMesh")
	if not ledge_collision:
		ledge_collision = get_node_or_null("LedgeCollision")
		
	if has_ledge:
		if not ledge_mesh:
			ledge_mesh = MeshInstance3D.new()
			ledge_mesh.name = "LedgeMesh"
			add_child(ledge_mesh)
		if not ledge_collision:
			ledge_collision = CollisionShape3D.new()
			ledge_collision.name = "LedgeCollision"
			add_child(ledge_collision)
			
		var ledge_size = Vector3(building_width + 0.5, 0.35, building_depth + 0.5)
		var l_mesh = ledge_mesh.mesh as BoxMesh
		if not l_mesh:
			l_mesh = BoxMesh.new()
			ledge_mesh.mesh = l_mesh
		l_mesh.size = ledge_size
		ledge_mesh.position = Vector3(0, roof_height - 0.18, 0)
		ledge_mesh.material_override = MAT_ROOF
		
		var l_shape = ledge_collision.shape as BoxShape3D
		if not l_shape:
			l_shape = BoxShape3D.new()
			ledge_collision.shape = l_shape
		l_shape.size = ledge_size
		ledge_collision.position = Vector3(0, roof_height - 0.18, 0)
		
		ledge_mesh.visible = true
		ledge_collision.disabled = false
	else:
		if ledge_mesh:
			ledge_mesh.visible = false
		if ledge_collision:
			ledge_collision.disabled = true
