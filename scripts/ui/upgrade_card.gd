extends Button
class_name UpgradeCard

signal upgrade_chosen(upgrade_resource: Resource)
signal upgrade_selected(upgrade_resource: Resource)

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var icon_label: Label = $MarginContainer/VBoxContainer/CenterContainer/IconLabel
@onready var desc_label: Label = $MarginContainer/VBoxContainer/DescLabel
@onready var level_label: Label = $MarginContainer/VBoxContainer/LevelLabel

var upgrade_data: Resource = null

func _ready() -> void:
	pressed.connect(_on_pressed)

func setup(data_dict: Dictionary) -> void:
	# data_dict: {"upgrade": UpgradeData, "next_level": int, "max_level": int}
	upgrade_data = data_dict.get("upgrade")
	if not upgrade_data:
		return
	
	var next_lvl = int(data_dict.get("next_level", 1))
	var max_lvl = int(data_dict.get("max_level", 5))
	
	# 1. Title with tier (e.g. "Movement Speed II")
	var title_text = str(upgrade_data.get("title"))
	if upgrade_data.has_method("get_title_for_level"):
		title_text = upgrade_data.get_title_for_level(next_lvl)
	if title_label:
		title_label.text = title_text
	
	# 2. Icon
	var icon_str = str(upgrade_data.get("icon_text"))
	if icon_label and not icon_str.is_empty():
		icon_label.text = icon_str
	
	# 3. Description
	var desc = ""
	if upgrade_data.has_method("get_description_for_level"):
		desc = upgrade_data.get_description_for_level(next_lvl)
	elif upgrade_data.get("description"):
		desc = str(upgrade_data.get("description"))
	if desc_label:
		desc_label.text = desc
	
	# 4. Level indicator (e.g. "LEVEL 2 / 5")
	if level_label:
		level_label.text = "LEVEL %d / %d" % [next_lvl, max_lvl]
	
	# 5. Styling
	var color = upgrade_data.get("card_color") as Color
	if color:
		_apply_card_color(color)

func _apply_card_color(col: Color) -> void:
	var base_style = get_theme_stylebox("normal")
	if base_style:
		var normal_dup = base_style.duplicate() as StyleBoxFlat
		if normal_dup:
			normal_dup.bg_color = Color(col.r * 0.22, col.g * 0.22, col.b * 0.22, 0.95)
			normal_dup.border_color = col
			add_theme_stylebox_override("normal", normal_dup)
			
			var hover_dup = normal_dup.duplicate() as StyleBoxFlat
			hover_dup.bg_color = Color(col.r * 0.42, col.g * 0.42, col.b * 0.42, 0.98)
			hover_dup.border_color = Color(1, 1, 1, 1)
			add_theme_stylebox_override("hover", hover_dup)
			add_theme_stylebox_override("pressed", hover_dup)

func _on_pressed() -> void:
	if upgrade_data:
		upgrade_chosen.emit(upgrade_data)
		upgrade_selected.emit(upgrade_data)
