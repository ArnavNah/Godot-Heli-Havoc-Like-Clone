extends Area3D
class_name TurretBullet

@export var speed: float = 24.0
@export var damage: int = 15
@export var lifespan: float = 3.0

var direction: Vector3 = Vector3.FORWARD
var time_alive: float = 0.0

func _ready() -> void:
	collision_layer = 16 # Layer 5: EnemyProjectile
	collision_mask = 3   # Layer 1: Player (1) + Layer 2: Environment (2)
	body_entered.connect(_on_body_entered)

func setup(dir: Vector3) -> void:
	direction = dir.normalized()
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
		queue_free()
	elif (body.collision_layer & 2) != 0 or (body.collision_layer & 1) != 0:
		queue_free()
