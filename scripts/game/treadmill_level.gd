extends Node3D

@onready var player_heli: PlayerHeli = $PlayerHeli
@onready var heli_hud: HeliHUD = $HeliHUD
@onready var level_up_screen: LevelUpScreen = $LevelUpCanvasLayer/LevelUpScreen

func _ready() -> void:
	if player_heli:
		# Wire Virtual Joystick to PlayerHeli
		if heli_hud and heli_hud.virtual_joystick and heli_hud.virtual_joystick.has_signal("joystick_updated"):
			heli_hud.virtual_joystick.joystick_updated.connect(player_heli.update_input)
		
		# Wire ProgressionComponent to GameManager
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
