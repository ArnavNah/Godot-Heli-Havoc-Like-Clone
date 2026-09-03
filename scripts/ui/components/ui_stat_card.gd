@tool
extends PanelContainer
class_name UIStatCard

@export var title: String = "Stat":
	set(val):
		title = val
		if title_label:
			title_label.text = val

@export var icon: Texture2D:
	set(val):
		icon = val
		if icon_rect:
			icon_rect.texture = val

@export var value: String = "0":
	set(val):
		value = val
		if value_label:
			value_label.text = val

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var icon_rect: TextureRect = $VBoxContainer/IconRect
@onready var value_label: Label = $VBoxContainer/ValueLabel

func _ready() -> void:
	if title_label:
		title_label.text = title
	if icon_rect and icon:
		icon_rect.texture = icon
	if value_label:
		value_label.text = value

func set_stat(title_text: String, icon_tex: Texture2D, val_text: String) -> void:
	title = title_text
	icon = icon_tex
	value = val_text
	if title_label:
		title_label.text = title
	if icon_rect:
		icon_rect.texture = icon
	if value_label:
		value_label.text = value
