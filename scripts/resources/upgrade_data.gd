@tool
extends Resource
class_name UpgradeData

@export var id: String = ""
@export var title: String = ""
@export var icon_text: String = "⭐"
@export var card_color: Color = Color(0.2, 0.5, 0.9, 1.0)
@export var max_level: int = 5
@export var stat_type: String = ""

@export var base_multiplier_per_level: float = 0.10
@export var flat_value_per_level: float = 0.0
@export var description_template: String = "+%d%% to stat"

func get_title_for_level(lvl: int) -> String:
	var roman = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"]
	var suffix = roman[lvl - 1] if lvl > 0 and lvl <= roman.size() else str(lvl)
	return "%s %s" % [title, suffix]

func get_description_for_level(_lvl: int) -> String:
	if not description_template.is_empty():
		if "%d%%" in description_template or "%s" in description_template:
			var pct = int(base_multiplier_per_level * 100.0)
			return description_template % pct
		elif "%d" in description_template:
			return description_template % int(flat_value_per_level)
		return description_template
	return "+Bonus to " + title
