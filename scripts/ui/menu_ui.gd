extends CanvasLayer
class_name MenuUI

@export var game_scene_path: String = "res://scenes/game/city_arena.tscn"
@export var countdown_step_duration: float = 1.0
@export var start_display_duration: float = 0.5

@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var high_score_label: Label = get_node_or_null("CenterContainer/VBoxContainer/HighScoreLabel")
@onready var loading_screen: CanvasLayer = get_node_or_null("../LoadingScreen")
@onready var loading_label: Label = get_node_or_null("../LoadingScreen/ColorRect/LoadingLabel")
@onready var coin_label: Label = get_node_or_null("TopBar/Margin/HBox/CoinContainer/CoinLabel")

var is_loading: bool = false
var loading_progress: Array = []
var sound_enabled: bool = true
var music_enabled: bool = true

func _ready() -> void:
	if not is_inside_tree():
		return
	set_process(false)
	
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	
	if high_score_label and GameManager:
		high_score_label.text = "🏆 HIGH SCORE: %d" % GameManager.high_score
	
	if coin_label and GameManager:
		coin_label.text = "%d" % GameManager.gold
	
	var sound_btn = get_node_or_null("TopBar/Margin/RightHBox/SoundBtn") as Button
	if sound_btn:
		sound_btn.pressed.connect(_on_sound_toggled)
		
	var music_btn = get_node_or_null("TopBar/Margin/RightHBox/MusicBtn") as Button
	if music_btn:
		music_btn.pressed.connect(_on_music_toggled)

func _on_sound_toggled() -> void:
	sound_enabled = not sound_enabled
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, not sound_enabled)

func _on_music_toggled() -> void:
	music_enabled = not music_enabled
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, not music_enabled)

func _on_play_pressed() -> void:
	if is_loading:
		return
	is_loading = true
	
	# Hide MenuUI and show LoadingScreen
	visible = false
	if loading_screen:
		loading_screen.visible = true
	if loading_label:
		loading_label.text = "LOADING..."
	
	# Safely begin background loading
	ResourceLoader.load_threaded_request(game_scene_path)
	set_process(true)

func _process(_delta: float) -> void:
	if not is_loading:
		return
	
	var status = ResourceLoader.load_threaded_get_status(game_scene_path, loading_progress)
	
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		# Stop polling and transition immediately into the game scene
		set_process(false)
		if GameManager:
			GameManager.reset()
		var sm = get_node_or_null("/root/SurvivalManager")
		if sm and sm.has_method("reset"):
			sm.reset()
		
		var packed_scene = ResourceLoader.load_threaded_get(game_scene_path) as PackedScene
		if packed_scene:
			get_tree().change_scene_to_packed(packed_scene)
		else:
			get_tree().change_scene_to_file(game_scene_path)
