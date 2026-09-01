extends Control
class_name LevelUpScreen

const UpgradeDataClass = preload("res://scripts/resources/upgrade_data.gd")

@export var card_scene: PackedScene = preload("res://scenes/ui/upgrade_card.tscn")

@onready var cards_container: HBoxContainer = $CenterPanel/MarginContainer/VBoxContainer/CardsContainer
@onready var title_label: Label = $CenterPanel/MarginContainer/VBoxContainer/TitleContainer/TitleLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if GameManager:
		GameManager.level_up_requested.connect(_on_level_up_requested)

func _on_level_up_requested(choices: Array) -> void:
	# 1. Pause gameplay
	get_tree().paused = true
	visible = true
	
	# 2. Clear old cards
	for child in cards_container.get_children():
		child.queue_free()
	
	# 3. Instantiate 3 upgrade cards
	for choice_data in choices:
		var card = card_scene.instantiate()
		cards_container.add_child(card)
		if card.has_method("setup"):
			card.setup(choice_data)
		if card.has_signal("upgrade_chosen"):
			card.upgrade_chosen.connect(_on_card_selected)
		elif card.has_signal("upgrade_selected"):
			card.upgrade_selected.connect(_on_card_selected)

func _on_card_selected(upgrade: Resource) -> void:
	# 1. Apply upgrade
	if GameManager:
		GameManager.apply_upgrade(upgrade)
	
	# 2. Resume gameplay
	visible = false
	get_tree().paused = false
