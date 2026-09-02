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
		
		# Wire ProgressionComponent to GameManager if present
		if player_heli.progression_component and GameManager:
			player_heli.progression_component.level_up.connect(_on_player_level_up)
			player_heli.progression_component.xp_updated.connect(_on_player_xp_updated)

func _on_player_level_up(_new_lvl: int) -> void:
	if GameManager:
		GameManager._trigger_level_up()

func _on_player_xp_updated(curr_xp: int, req_xp: int, lvl: int) -> void:
	if GameManager:
		GameManager.current_xp = curr_xp
		GameManager.xp_required = req_xp
		GameManager.level = lvl
		GameManager.xp_updated.emit(curr_xp, req_xp, lvl)

func _on_player_died() -> void:
	# Handled cleanly by HeliHUD Game Over modal (Restart / Menu buttons)
	pass
