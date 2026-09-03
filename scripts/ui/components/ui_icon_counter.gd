@tool
extends HBoxContainer
class_name UIIconCounter

@export var icon: Texture2D:
	set(val):
		icon = val
		if icon_rect:
			icon_rect.texture = val

@export var value_text: String = "0":
	set(val):
		value_text = val
		if value_label:
			value_label.text = val

@onready var icon_rect: TextureRect = $IconRect
@onready var value_label: Label = $ValueLabel

func _ready() -> void:
	if icon and icon_rect:
		icon_rect.texture = icon
	if value_label:
		value_label.text = value_text

func set_value(val: Variant) -> void:
	value_text = str(val)
	if value_label:
		value_label.text = value_text
