extends Node3D
class_name CityArena

@onready var player_heli: PlayerHeli = $PlayerHeli
@onready var heli_hud: HeliHUD = $HeliHUD
@onready var level_up_screen: LevelUpScreen = get_node_or_null("LevelUpCanvasLayer/LevelUpScreen")
@onready var city_grid_manager: CityGridManager = $CityGridManager

func _ready() -> void:
	if GameManager:
		GameManager.reset()
	
	if player_heli:
		player_heli.player_died.connect(_on_player_died)

func _on_player_died() -> void:
	# Handled cleanly by HeliHUD Game Over modal (Restart / Menu buttons)
	pass
