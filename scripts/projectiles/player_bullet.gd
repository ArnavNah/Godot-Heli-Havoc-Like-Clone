extends Area3D
class_name PlayerBullet

@export var speed: float = 45.0
@export var damage: int = 25
@export var lifespan: float = 3.0

var direction: Vector3 = Vector3.FORWARD
var time_alive: float = 0.0

func _ready() -> void:
	collision_layer = 8 # Layer 4: PlayerProjectile
	collision_mask = 6  # Layer 2: Environment (2) + Layer 3: Enemy (4)
	
	body_entered.connect(_on_hit)
	area_entered.connect(_on_area_hit)

func setup(dir: Vector3) -> void:
	direction = dir.normalized()
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	time_alive += delta
	if time_alive >= lifespan:
		queue_free()

func _on_hit(body: Node3D) -> void:
	if body.has_method("take_hit"):
		body.take_hit(damage)
	elif body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()

func _on_area_hit(area: Area3D) -> void:
	if area.has_method("take_hit"):
		area.take_hit(damage)
	elif area.get_parent() and area.get_parent().has_method("take_hit"):
		area.get_parent().take_hit(damage)
	queue_free()
