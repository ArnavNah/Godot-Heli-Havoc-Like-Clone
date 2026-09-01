extends Control
class_name GameHUD

@onready var distance_label: Label = $TopLeft/VBoxContainer/DistanceRow/DistanceLabel
@onready var gold_label: Label = $TopLeft/VBoxContainer/GoldRow/GoldLabel
@onready var kills_label: Label = $TopLeft/VBoxContainer/KillsRow/KillsLabel

@onready var xp_progress_bar: ProgressBar = $TopCenter/VBoxContainer/XPBarRow/XPProgressBar
@onready var timer_label: Label = $TopCenter/VBoxContainer/StatsRow/TimeRow/TimerLabel
@onready var score_label: Label = $TopCenter/VBoxContainer/StatsRow/ScoreRow/ScoreLabel
@onready var wave_label: Label = $TopCenter/VBoxContainer/WaveBadge/WaveLabel

@onready var pause_button: Button = $TopRight/PauseButton

@onready var health_bar: ProgressBar = $BottomCenter/HBoxContainer/HealthContainer/HealthBar
@onready var health_label: Label = $BottomCenter/HBoxContainer/HealthContainer/HealthBar/HealthLabel

@onready var boost_bar: ProgressBar = $BottomCenter/HBoxContainer/BoostContainer/BoostBar
@onready var boost_label: Label = $BottomCenter/HBoxContainer/BoostContainer/BoostBar/BoostLabel

@onready var center_banner: Label = $CenterBanner
@onready var banner_anim: AnimationPlayer = $CenterBanner/AnimationPlayer

var elapsed_time: float = 0.0
var initial_player_z: float = 0.0
var target_player: Node3D = null
var current_wave: int = 1
var total_waves: int = 5

func _ready() -> void:
	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)
	
	_find_player()
	
	if GameManager:
		GameManager.gold_changed.connect(_on_gold_changed)
		GameManager.xp_updated.connect(_on_xp_updated)
		GameManager.score_changed.connect(_on_score_changed)
		GameManager.kills_changed.connect(_on_kills_changed)
		GameManager.health_changed.connect(_on_health_changed)
		GameManager.boost_changed.connect(_on_boost_changed)
		GameManager.notification_triggered.connect(_show_banner_notification)
		
		_on_gold_changed(GameManager.gold)
		_on_xp_updated(GameManager.current_xp, GameManager.xp_required, GameManager.level)
		_on_score_changed(GameManager.score)
		_on_kills_changed(GameManager.kills)
		_on_health_changed(GameManager.health, GameManager.max_health)
		_on_boost_changed(GameManager.boost, GameManager.max_boost)

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("PlayerHeli")
	if players.is_empty():
		players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target_player = players[0]
		initial_player_z = target_player.global_position.z

func _process(delta: float) -> void:
	elapsed_time += delta
	if timer_label:
		timer_label.text = "%.1f" % elapsed_time
	
	if not target_player or not is_instance_valid(target_player):
		_find_player()
	elif distance_label:
		# Distance in meters based on travel along -Z
		var dist = maxf(0.0, initial_player_z - target_player.global_position.z)
		distance_label.text = "%.1fm" % dist

func _on_gold_changed(new_gold: int) -> void:
	if gold_label:
		gold_label.text = str(new_gold)

func _on_kills_changed(new_kills: int) -> void:
	if kills_label:
		kills_label.text = str(new_kills)

func _on_score_changed(new_score: int) -> void:
	if score_label:
		score_label.text = "%s" % _format_number(new_score)

func _format_number(val: int) -> String:
	var s = str(val)
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count == 3 and i > 0:
			result = "," + result
			count = 0
	return result

func _on_xp_updated(curr_xp: int, req_xp: int, _lvl: int) -> void:
	if xp_progress_bar:
		xp_progress_bar.max_value = req_xp
		xp_progress_bar.value = curr_xp

func _on_health_changed(current_hp: int, max_hp: int) -> void:
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp
	if health_label:
		health_label.text = "%d" % current_hp

func _on_boost_changed(current_boost: float, max_b: float) -> void:
	if boost_bar:
		boost_bar.max_value = max_b
		boost_bar.value = current_boost
	if boost_label:
		boost_label.text = "%d%%" % int((current_boost / max_b) * 100.0)

func _show_banner_notification(msg: String) -> void:
	if center_banner:
		center_banner.text = msg
		if banner_anim and banner_anim.has_animation("show_banner"):
			banner_anim.stop()
			banner_anim.play("show_banner")

func _on_pause_pressed() -> void:
	get_tree().paused = not get_tree().paused
