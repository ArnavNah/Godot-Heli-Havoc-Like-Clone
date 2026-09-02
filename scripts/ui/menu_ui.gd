extends CanvasLayer
class_name MenuUI

@export var game_scene_path: String = "res://scenes/game/city_arena.tscn"
@export var countdown_step_duration: float = 1.0
@export var start_display_duration: float = 0.5

@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var high_score_label: Label = get_node_or_null("CenterContainer/VBoxContainer/HighScoreLabel")
@onready var loading_screen: CanvasLayer = get_node_or_null("../LoadingScreen")
@onready var loading_label: Label = get_node_or_null("../LoadingScreen/ColorRect/LoadingLabel")

var is_loading: bool = false
var loading_progress: Array = []

func _ready() -> void:
	set_process(false)
	
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	
	if high_score_label and GameManager:
		high_score_label.text = "🏆 HIGH SCORE: %d" % GameManager.high_score

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
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		set_process(false)
		if loading_label:
			loading_label.text = "ERROR LOADING GAME"

func _pulse_label(col: Color, target_scale: float = 1.3) -> void:
	if not loading_label:
		return
	loading_label.modulate = col
	loading_label.pivot_offset = loading_label.size * 0.5
	loading_label.scale = Vector2(target_scale, target_scale)
	
	var tw = create_tween()
	tw.tween_property(loading_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
