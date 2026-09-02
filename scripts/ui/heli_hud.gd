extends CanvasLayer
class_name HeliHUD

@export var player_path: NodePath
var player: PlayerHeli = null

@onready var level_label: Label = $TopBar/Margin/HBox/LevelContainer/LevelLabel
@onready var xp_bar: ProgressBar = $TopBar/Margin/HBox/XPContainer/XPBar
@onready var xp_label: Label = $TopBar/Margin/HBox/XPContainer/XPBar/XPLabel
@onready var time_label: Label = $TopBar/Margin/HBox/TimeContainer/TimeLabel
@onready var coin_label: Label = $TopBar/Margin/HBox/CoinContainer/CoinLabel

@onready var health_bar: ProgressBar = $BottomBar/Margin/HBox/HealthContainer/HealthBar
@onready var health_label: Label = $BottomBar/Margin/HBox/HealthContainer/HealthBar/HealthLabel
@onready var fuel_bar: ProgressBar = $BottomBar/Margin/HBox/FuelContainer/FuelBar
@onready var fuel_label: Label = $BottomBar/Margin/HBox/FuelContainer/FuelBar/FuelLabel

@onready var game_over_modal: PanelContainer = get_node_or_null("GameOverModal")
@onready var restart_btn: Button = get_node_or_null("GameOverModal/Margin/VBox/BtnHBox/RestartButton")
@onready var menu_btn: Button = get_node_or_null("GameOverModal/Margin/VBox/BtnHBox/MenuButton")
@onready var game_over_stats: Label = get_node_or_null("GameOverModal/Margin/VBox/StatsLabel")

@onready var countdown_overlay: Control = get_node_or_null("CountdownOverlay")
@onready var countdown_label: Label = get_node_or_null("CountdownOverlay/CountdownLabel")
@onready var mobile_controls: HeliMobileControls = get_node_or_null("MobileControls")

var elapsed_time: float = 0.0
var countdown_running: bool = true

func _ready() -> void:
	if not player_path.is_empty():
		player = get_node_or_null(player_path) as PlayerHeli
	
	if not player:
		var players = get_tree().get_nodes_in_group("PlayerHeli")
		if not players.is_empty():
			player = players[0] as PlayerHeli
	
	if player and player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)
	
	if mobile_controls and mobile_controls.virtual_joystick and player:
		if not mobile_controls.virtual_joystick.joystick_updated.is_connected(player.update_input):
			mobile_controls.virtual_joystick.joystick_updated.connect(player.update_input)
	
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)
	if menu_btn:
		menu_btn.pressed.connect(_on_menu_pressed)
	
	if GameManager:
		GameManager.gold_changed.connect(_on_gold_changed)
		GameManager.xp_updated.connect(_on_xp_updated)
		GameManager.health_changed.connect(_on_health_changed)
		GameManager.boost_changed.connect(_on_boost_changed)
		
		_on_gold_changed(GameManager.gold)
		_on_xp_updated(GameManager.current_xp, GameManager.xp_required, GameManager.level)
		_on_health_changed(GameManager.health, GameManager.max_health)
		_on_boost_changed(GameManager.boost, GameManager.max_boost)
	
	# Start 3, 2, 1, START Countdown
	_start_countdown_sequence()

func _start_countdown_sequence() -> void:
	if not countdown_overlay or not countdown_label:
		if player:
			player.unlock_controls()
		return
	
	countdown_running = true
	countdown_overlay.visible = true
	
	if player:
		player.lock_controls()
	
	var sm = get_node_or_null("/root/SurvivalManager")
	if sm:
		sm.is_active = false
	
	# Step 3
	_animate_countdown_step("3", Color(1, 0.9, 0.2, 1))
	await get_tree().create_timer(0.75).timeout
	
	# Step 2
	_animate_countdown_step("2", Color(1, 0.65, 0.1, 1))
	await get_tree().create_timer(0.75).timeout
	
	# Step 1
	_animate_countdown_step("1", Color(1, 0.35, 0.1, 1))
	await get_tree().create_timer(0.75).timeout
	
	# Step START!
	_animate_countdown_step("START!", Color(0.2, 1.0, 0.4, 1), 2.2)
	
	# Unlock and start game
	countdown_running = false
	if player:
		player.unlock_controls()
	if sm:
		sm.is_active = true
	
	await get_tree().create_timer(0.6).timeout
	var fade_tw = create_tween()
	fade_tw.tween_property(countdown_overlay, "modulate:a", 0.0, 0.3)
	fade_tw.tween_callback(func(): countdown_overlay.visible = false)

func _animate_countdown_step(text: String, col: Color, scale_mult: float = 1.7) -> void:
	if not countdown_label:
		return
	countdown_label.text = text
	countdown_label.modulate = col
	countdown_label.pivot_offset = countdown_label.size * 0.5
	countdown_label.scale = Vector2(scale_mult, scale_mult)
	
	var tw = create_tween()
	tw.tween_property(countdown_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if countdown_running:
		return
		
	elapsed_time += delta
	
	# Update Time from SurvivalManager or local clock
	if time_label:
		var sm = get_node_or_null("/root/SurvivalManager")
		if sm and sm.has_method("get_formatted_time"):
			time_label.text = "⏱ TIME: %s" % sm.get_formatted_time()
		else:
			var total_sec = int(elapsed_time)
			time_label.text = "⏱ TIME: %02d:%02d" % [int(float(total_sec) / 60.0), total_sec % 60]

func _on_gold_changed(new_gold: int) -> void:
	if coin_label:
		coin_label.text = "🪙 COINS: %d" % new_gold

func _on_xp_updated(cur_xp: int, req_xp: int, lvl: int) -> void:
	if level_label:
		level_label.text = "LVL %d" % lvl
	if xp_bar:
		xp_bar.max_value = req_xp
		xp_bar.value = cur_xp
	if xp_label:
		xp_label.text = "XP %d / %d" % [cur_xp, req_xp]

func _on_health_changed(cur_hp: int, max_hp: int) -> void:
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = cur_hp
	if health_label:
		health_label.text = "❤️ %d / %d" % [cur_hp, max_hp]

func _on_boost_changed(cur_fuel: float, max_fuel: float) -> void:
	if fuel_bar:
		fuel_bar.max_value = max_fuel
		fuel_bar.value = cur_fuel
	if fuel_label:
		var pct = int(clampf((cur_fuel / maxf(1.0, max_fuel)) * 100.0, 0.0, 100.0))
		if pct <= 25:
			fuel_label.text = "⚠️ %d%%" % pct
			fuel_label.modulate = Color(1.0, 0.35, 0.3, 1.0)
		else:
			fuel_label.text = "⚡ %d%%" % pct
			fuel_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_player_died() -> void:
	if mobile_controls:
		mobile_controls.visible = false
		
	if countdown_overlay:
		countdown_overlay.visible = false
	
	if game_over_modal:
		var sm = get_node_or_null("/root/SurvivalManager")
		var time_str = sm.get_formatted_time() if sm else "00:00"
		var score_val = GameManager.score if GameManager else 0
		var coins_val = GameManager.gold if GameManager else 0
		
		if game_over_stats:
			game_over_stats.text = "SURVIVAL TIME: %s\nCOINS EARNED: %d\nFINAL SCORE: %d" % [time_str, coins_val, score_val]
		
		game_over_modal.visible = true
		game_over_modal.move_to_front()

func _on_restart_pressed() -> void:
	if GameManager:
		GameManager.reset()
	var sm = get_node_or_null("/root/SurvivalManager")
	if sm and sm.has_method("reset"):
		sm.reset()
	get_tree().change_scene_to_file("res://scenes/game/city_arena.tscn")

func _on_menu_pressed() -> void:
	if GameManager:
		GameManager.reset()
	var sm = get_node_or_null("/root/SurvivalManager")
	if sm and sm.has_method("reset"):
		sm.reset()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
