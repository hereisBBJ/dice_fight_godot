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
	custom_minimum_size = Vector2(180, 112)
	expand_icon = true
	_apply_button_style(theme_color)


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


func _apply_button_style(theme_color: Color) -> void:
	var normal = UIAssetsScript.panel_style(theme_color.lightened(0.10), theme_color.darkened(0.20), 8)
	var hover = UIAssetsScript.panel_style(theme_color.lightened(0.20), theme_color.darkened(0.12), 8)
	var pressed = UIAssetsScript.panel_style(theme_color.darkened(0.08), theme_color.lightened(0.12), 8)
	var disabled_style = UIAssetsScript.panel_style(Color(0.34, 0.34, 0.32), Color(0.22, 0.22, 0.22), 8)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("disabled", disabled_style)
	add_theme_color_override("font_color", Color(0.98, 0.96, 0.88))
	add_theme_color_override("font_disabled_color", Color(0.66, 0.66, 0.62))
