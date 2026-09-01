extends CanvasLayer
class_name HeliHUD

signal shoot_requested()

@export var player_path: NodePath

@onready var gold_label: Label = $TopLeft/GoldContainer/GoldLabel
@onready var level_label: Label = $TopCenter/VBoxContainer/LevelLabel
@onready var xp_bar: ProgressBar = $TopCenter/VBoxContainer/XPBar

@onready var fuel_bar: ProgressBar = $BottomCenter/HBoxContainer/FuelContainer/FuelBar
@onready var fuel_label: Label = $BottomCenter/HBoxContainer/FuelContainer/FuelBar/FuelLabel

@onready var health_bar: ProgressBar = $BottomCenter/HBoxContainer/HealthContainer/HealthBar
@onready var health_label: Label = $BottomCenter/HBoxContainer/HealthContainer/HealthBar/HealthLabel

@onready var virtual_joystick: Control = $VirtualJoystick
@onready var shoot_button: Button = $ShootButton

var target_player: Node3D = null

func _ready() -> void:
	if not player_path.is_empty():
		target_player = get_node_or_null(player_path) as PlayerHeli
	
	if not target_player:
		var players = get_tree().get_nodes_in_group("PlayerHeli")
		if players.size() > 0:
			target_player = players[0] as PlayerHeli
	
	_connect_player()
	
	if GameManager:
		GameManager.gold_changed.connect(_on_gold_changed)
		_on_gold_changed(GameManager.gold)
	
	if virtual_joystick and virtual_joystick.has_signal("joystick_updated"):
		virtual_joystick.joystick_updated.connect(_on_joystick_updated)
	
	if shoot_button:
		shoot_button.button_down.connect(_on_shoot_pressed)
		shoot_button.pressed.connect(_on_shoot_pressed)

func _process(_delta: float) -> void:
	if not target_player or not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("PlayerHeli")
		if players.size() > 0:
			target_player = players[0] as PlayerHeli
			_connect_player()

func _connect_player() -> void:
	if not target_player or not is_instance_valid(target_player):
		return
	
	# Connect FuelComponent
	if target_player.fuel_component:
		if not target_player.fuel_component.fuel_changed.is_connected(_on_fuel_changed):
			target_player.fuel_component.fuel_changed.connect(_on_fuel_changed)
		_on_fuel_changed(target_player.fuel_component.current_fuel, target_player.fuel_component.max_fuel)
	
	# Connect HealthComponent
	if target_player.health_component:
		if not target_player.health_component.health_changed.is_connected(_on_health_changed):
			target_player.health_component.health_changed.connect(_on_health_changed)
		_on_health_changed(target_player.health_component.current_health, target_player.health_component.max_health)
	
	# Connect ProgressionComponent
	if target_player.progression_component:
		if not target_player.progression_component.xp_updated.is_connected(_on_xp_updated):
			target_player.progression_component.xp_updated.connect(_on_xp_updated)
		_on_xp_updated(target_player.progression_component.current_xp, target_player.progression_component.xp_required, target_player.progression_component.level)

func _on_gold_changed(new_gold: int) -> void:
	if gold_label:
		gold_label.text = "GOLD: %d" % new_gold

func _on_xp_updated(curr_xp: int, req_xp: int, lvl: int) -> void:
	if xp_bar:
		xp_bar.max_value = req_xp
		xp_bar.value = curr_xp
	if level_label:
		level_label.text = "LEVEL %d  (%d / %d XP)" % [lvl, curr_xp, req_xp]

func _on_fuel_changed(curr_f: float, max_f: float) -> void:
	if fuel_bar:
		fuel_bar.max_value = max_f
		fuel_bar.value = curr_f
	if fuel_label:
		fuel_label.text = "FUEL: %d%%" % int((curr_f / max_f) * 100.0)

func _on_health_changed(curr_hp: int, max_hp: int) -> void:
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = curr_hp
	if health_label:
		health_label.text = "HP: %d / %d" % [curr_hp, max_hp]

func _on_joystick_updated(vec: Vector2) -> void:
	if target_player and is_instance_valid(target_player):
		target_player.update_input(vec)

func _on_shoot_pressed() -> void:
	shoot_requested.emit()
	if target_player and is_instance_valid(target_player):
		target_player.shoot()
