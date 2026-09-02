extends Control
class_name HeliMobileControls

@onready var virtual_joystick: HeliVirtualJoystick = $VirtualJoystick
@onready var fire_button: HeliTouchButton = get_node_or_null("ActionCluster/FireButton")
@onready var fly_up_button: HeliTouchButton = get_node_or_null("ActionCluster/FlyUpButton")
@onready var fly_down_button: HeliTouchButton = get_node_or_null("ActionCluster/FlyDownButton")

func _ready() -> void:
	pass
