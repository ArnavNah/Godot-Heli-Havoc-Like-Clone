extends Area3D
class_name EnemyBullet

@export var speed: float = 24.0
@export var base_speed: float = 24.0
@export var damage: int = 15
@export var lifespan: float = 3.5

var direction: Vector3 = Vector3.FORWARD
var time_alive: float = 0.0

func _ready() -> void:
	# Layer 5: EnemyProjectile (16), Mask 1: Player (1), Mask 2: Environment (2) -> 1 + 2 = 3
	collision_layer = 16
	collision_mask = 3
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(dir: Vector3, speed_mult: float = 1.0) -> void:
	direction = dir.normalized()
	speed = base_speed * speed_mult
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	time_alive += delta
	if time_alive >= lifespan:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	elif body.has_method("take_hit"):
		body.take_hit(damage)
	queue_free()

func _on_area_entered(area: Area3D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
	elif area.get_parent() and area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(damage)
	queue_free()
