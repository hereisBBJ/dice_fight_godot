extends Button
class_name SkillButton

const UIAssetsScript = preload("res://scripts/ui/components/ui_assets.gd")

var skill_id = ""
var modes: Array = []


func configure(skill: Dictionary, selected_modes: Array, cost: int, block_reason: String, theme_color: Color) -> void:
	skill_id = String(skill.get("id", ""))
	modes = selected_modes.duplicate()
	var mode_name = _mode_name(skill, selected_modes)
	var skill_name = String(skill.get("name", skill_id))
	text = "%s%s\n%d MP" % [skill_name, mode_name, cost]
	tooltip_text = "%s\n骰子要求：%s\n%s" % [
		String(skill.get("description", "")),
		_requirement_text(skill.get("dice_requirements", [])),
		"可使用" if block_reason == "" else block_reason
	]
	disabled = block_reason != ""
	icon = UIAssetsScript.texture_from_path(String(skill.get("icon_path", "")), theme_color, Vector2i(64, 64))
	custom_minimum_size = Vector2(170, 72)
	expand_icon = true


func _mode_name(skill: Dictionary, selected_modes: Array) -> String:
	if selected_modes.is_empty():
		return ""
	for mode in skill.get("modes", []):
		if String(mode.get("id", "")) == String(selected_modes[0]):
			return " · %s" % String(mode.get("name", ""))
	return ""


func _requirement_text(requirements: Array) -> String:
	if requirements.is_empty():
		return "无"
	var parts = []
	for requirement in requirements:
		parts.append(_single_requirement_text(requirement))
	return "、".join(parts)


func _single_requirement_text(requirement) -> String:
	if requirement is int or requirement is float:
		return "≥%d" % int(requirement)
	var text = String(requirement)
	if text == "odd":
		return "奇数"
	if text == "even":
		return "偶数"
	if text.begins_with("="):
		return "=%s" % text.substr(1)
	return text
