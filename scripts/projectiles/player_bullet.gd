extends Area3D
class_name PlayerBullet

@export var speed: float = 68.0
@export var damage: int = 10
@export var lifespan: float = 2.0

var direction: Vector3 = Vector3.FORWARD
var time_alive: float = 0.0

func _ready() -> void:
	# Layer 4: PlayerProjectile (8), Mask 2: Environment (2), Mask 3: Enemy (4) -> 2 + 4 = 6
	collision_layer = 8
	collision_mask = 6
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(dir: Vector3, p_damage: int = 10) -> void:
	direction = dir.normalized()
	damage = p_damage
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	time_alive += delta
	if time_alive >= lifespan:
		queue_free()

const ImpactFlashScene = preload("res://scenes/effects/bullet_impact_flash.tscn")

func _on_body_entered(body: Node3D) -> void:
	_spawn_impact_effect()
	_apply_damage_to(body)
	queue_free()

func _on_area_entered(area: Area3D) -> void:
	_spawn_impact_effect()
	_apply_damage_to(area)
	queue_free()

func _spawn_impact_effect() -> void:
	if ImpactFlashScene:
		var imp = ImpactFlashScene.instantiate()
		get_tree().root.add_child(imp)
		imp.global_position = global_position

func _apply_damage_to(target: Node) -> void:
	if target.has_method("take_hit"):
		target.take_hit(damage)
	elif target.has_method("take_damage"):
		target.take_damage(damage)
	elif target.get_parent() and target.get_parent().has_method("take_hit"):
		target.get_parent().take_hit(damage)
	elif target.get_parent() and target.get_parent().has_method("take_damage"):
		target.get_parent().take_damage(damage)
