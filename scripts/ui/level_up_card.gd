extends Button
class_name LevelUpCard

signal upgrade_selected(upgrade: Resource)

const UpgradeDataClass = preload("res://scripts/resources/upgrade_data.gd")

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var icon_label: Label = $MarginContainer/VBoxContainer/CenterContainer/IconLabel
@onready var desc_label: Label = $MarginContainer/VBoxContainer/DescLabel
@onready var stars_label: Label = $MarginContainer/VBoxContainer/StarsLabel

var current_upgrade: Resource = null

func _ready() -> void:
	pressed.connect(_on_pressed)

func setup(upgrade: Resource) -> void:
	current_upgrade = upgrade
	if not upgrade:
		return
	
	var title = upgrade.get("title")
	var icon_text = upgrade.get("icon_text")
	var description = upgrade.get("description")
	var stars = int(upgrade.get("stars"))
	var card_color = upgrade.get("card_color") as Color
	
	if title_label and title:
		title_label.text = title
	if icon_label and icon_text:
		icon_label.text = icon_text
	if desc_label and description:
		desc_label.text = description
	if stars_label:
		var s = ""
		for i in range(stars):
			s += "★ "
		stars_label.text = s.strip_edges()
	
	# Apply card color to custom stylebox
	var normal_style = get_theme_stylebox("normal")
	if normal_style and card_color:
		var dup = normal_style.duplicate() as StyleBoxFlat
		if dup:
			dup.bg_color = card_color
			add_theme_stylebox_override("normal", dup)
			add_theme_stylebox_override("hover", dup)
			add_theme_stylebox_override("pressed", dup)

func _on_pressed() -> void:
	if current_upgrade:
		upgrade_selected.emit(current_upgrade)
