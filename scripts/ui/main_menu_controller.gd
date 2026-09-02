extends Control
class_name MainMenuController

@export var game_scene_path: String = "res://scenes/game/city_arena.tscn"

@onready var play_button: Button = $CenterMenu/VBox/PlayButton
@onready var shop_button: Button = $CenterMenu/VBox/ShopButton
@onready var high_score_label: Label = $CenterMenu/VBox/HighScoreLabel
@onready var shop_modal: PanelContainer = get_node_or_null("ShopModal")

@onready var loading_overlay: ColorRect = get_node_or_null("LoadingOverlay")
@onready var loading_bar: ProgressBar = get_node_or_null("LoadingOverlay/Center/VBox/LoadingBar")
@onready var loading_status: Label = get_node_or_null("LoadingOverlay/Center/VBox/StatusLabel")

var is_loading: bool = false

func _ready() -> void:
	if loading_overlay:
		loading_overlay.visible = false
	
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
		_setup_button_hover(play_button)
	if shop_button:
		shop_button.pressed.connect(_on_shop_pressed)
		_setup_button_hover(shop_button)
	
	# Update High Score display
	if high_score_label:
		var hs = GameManager.high_score if GameManager else 0
		high_score_label.text = "🏆 HIGH SCORE: %d" % hs
	
	var shop_close = get_node_or_null("ShopModal/Margin/VBox/CloseButton")
	if shop_close:
		shop_close.pressed.connect(func(): shop_modal.visible = false)

func _setup_button_hover(btn: Button) -> void:
	btn.pivot_offset = btn.size * 0.5
	btn.mouse_entered.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw = create_tween()
		tw.tween_property(btn, "scale", Vector3(1.06, 1.06, 1.06), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func():
		var tw = create_tween()
		tw.tween_property(btn, "scale", Vector3.ONE, 0.12)
	)

func _on_play_pressed() -> void:
	if is_loading:
		return
	is_loading = true
	
	if loading_overlay and loading_bar:
		loading_overlay.visible = true
		loading_overlay.modulate.a = 0.0
		loading_bar.value = 0.0
		
		var tw = create_tween()
		tw.tween_property(loading_overlay, "modulate:a", 1.0, 0.2)
		tw.tween_property(loading_bar, "value", 100.0, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(_start_game)
	else:
		_start_game()

func _start_game() -> void:
	if GameManager:
		GameManager.reset()
	var sm = get_node_or_null("/root/SurvivalManager")
	if sm and sm.has_method("reset"):
		sm.reset()
	
	get_tree().change_scene_to_file(game_scene_path)

func _on_shop_pressed() -> void:
	if is_loading:
		return
	if shop_modal:
		shop_modal.visible = not shop_modal.visible
