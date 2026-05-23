extends PanelContainer
class_name StatusIcon

const UIAssetsScript = preload("res://scripts/ui/components/ui_assets.gd")

@onready var icon_rect: TextureRect = $Margin/Row/Icon
@onready var name_label: Label = $Margin/Row/Name


func configure(status: Dictionary, status_data: Dictionary) -> void:
	var status_id = String(status.get("id", ""))
	var data: Dictionary = status_data.get(status_id, {})
	var display_name = String(data.get("name", status_id))
	var description = _status_description(status, String(data.get("description", "")))
	var color = _status_color(status_id)
	icon_rect.texture = UIAssetsScript.texture_from_path(String(data.get("icon_path", "")), color, Vector2i(48, 48))
	name_label.text = _status_label(display_name, status)
	tooltip_text = "%s\n%s" % [name_label.text, description]
	add_theme_stylebox_override("panel", UIAssetsScript.panel_style(Color(0.08, 0.09, 0.11, 0.86), color.darkened(0.15), 5))


func _status_label(display_name: String, status: Dictionary) -> String:
	var status_id = String(status.get("id", ""))
	if status_id == "burn":
		return "%s x%d" % [display_name, int(status.get("layers", 1))]
	if status_id == "poison":
		return "%s %d" % [display_name, int(status.get("duration", 1))]
	return display_name


func _status_description(status: Dictionary, fallback: String) -> String:
	var status_id = String(status.get("id", ""))
	if status_id == "static_cage_active":
		var skill_cost = int(status.get("value", 0))
		var adjust_cost = int(status.get("adjust_bonus", 0))
		if adjust_cost > 0:
			return "本回合技能额外消耗 %d MP，且第一次重投或改点额外消耗 %d MP。" % [skill_cost, adjust_cost]
		return "本回合技能额外消耗 %d MP。" % skill_cost
	if status_id == "static_cage_pending":
		var pending_skill_cost = int(status.get("value", 0))
		var pending_adjust_cost = int(status.get("adjust_bonus", 0))
		if pending_adjust_cost > 0:
			return "下回合开始时生效：技能额外消耗 %d MP，且第一次重投或改点额外消耗 %d MP。" % [pending_skill_cost, pending_adjust_cost]
		return "下回合开始时生效：技能额外消耗 %d MP。" % pending_skill_cost
	return fallback


func _status_color(status_id: String) -> Color:
	match status_id:
		"guard":
			return Color(0.33, 0.52, 0.87)
		"sure_evasion":
			return Color(0.35, 0.75, 0.55)
		"immune":
			return Color(0.70, 0.77, 0.96)
		"eagle_eye":
			return Color(0.33, 0.72, 0.42)
		"poison":
			return Color(0.55, 0.35, 0.80)
		"burn":
			return Color(0.88, 0.28, 0.18)
		"fire_shield":
			return Color(0.93, 0.42, 0.16)
		"flame_tide":
			return Color(0.95, 0.68, 0.22)
		"static_cage_pending":
			return Color(0.46, 0.64, 0.96)
		"static_cage_active":
			return Color(0.33, 0.56, 0.95)
	return Color(0.54, 0.58, 0.66)
