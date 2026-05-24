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
		return "%s x%d" % [display_name, int(status.get("layers", 1))]
	if status_id == "soul_bind":
		return "%s x%d" % [display_name, int(status.get("layers", 1))]
	if status_id == "cold":
		return "%s x%d" % [display_name, int(status.get("layers", 1))]
	if status_id == "frost_tide":
		return "%s x%d" % [display_name, int(status.get("duration", 1))]
	if status_id == "ice_wind":
		return "%s x%d" % [display_name, int(status.get("duration", 1))]
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
	if status_id == "poison":
		return "当前有 %d 层中毒。回合结束时失去 5 点生命，之后层数减 1；可用净化行动清除全部中毒。" % int(status.get("layers", 1))
	if status_id == "soul_bind":
		return "当前有 %d 层缚魂。若仍带有中毒，回合开始时对方可指定同等数量的技能本回合无法使用。" % int(status.get("layers", 1))
	if status_id == "cold":
		return "当前有 %d 层寒冷。部分冰系技能会消耗或利用这些层数触发额外效果。" % int(status.get("layers", 1))
	if status_id == "frost_tide":
		return "寒潮强化剩余 %d 回合。使用霜刺或冰风后，若目标有寒冷，可消耗 1 层寒冷进行追击。" % int(status.get("duration", 1))
	if status_id == "ice_wind":
		var pending_rounds = int(status.get("pending_rounds", 0))
		if pending_rounds > 0:
			return "冰风将在 %d 个回合开始阶段后发动，随后还会持续 %d 次。" % [pending_rounds, int(status.get("duration", 1))]
		return "冰风剩余 %d 次发动：回合开始前造成 5 点伤害，并使双方各获得 1 层寒冷。" % int(status.get("duration", 1))
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
		"cold":
			return Color(0.47, 0.78, 0.96)
		"frost_tide":
			return Color(0.69, 0.87, 0.98)
		"ice_wind":
			return Color(0.60, 0.84, 0.98)
		"soul_bind":
			return Color(0.44, 0.22, 0.70)
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
