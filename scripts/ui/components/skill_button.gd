extends Button
class_name SkillButton

const UIAssetsScript = preload("res://scripts/ui/components/ui_assets.gd")
const ICON_FRAME_SIZE = 44
const ICON_TEXTURE_SIZE = 34

var icon_frame: PanelContainer = null
var skill_icon: TextureRect = null
var name_label: Label = null
var requirement_label: Label = null
var description_label: Label = null
var cost_label: Label = null
var mode_label: Label = null
var reason_label: Label = null

var skill_id = ""
var modes: Array = []


func configure(skill: Dictionary, selected_modes: Array, cost: int, block_reason: String, theme_color: Color) -> void:
	_ensure_nodes()
	skill_id = String(skill.get("id", ""))
	modes = selected_modes.duplicate()

	var mode_name = _mode_name(skill, selected_modes)
	var skill_name = String(skill.get("name", skill_id))
	var description = String(skill.get("description", ""))
	var requirement_text = _requirement_text(skill.get("dice_requirements", []))
	var state_text = "可使用" if block_reason == "" else block_reason

	text = "%s%s\n%d MP" % [skill_name, mode_name, cost]
	tooltip_text = _detail_text(skill_name, mode_name, cost, requirement_text, description, state_text)
	disabled = block_reason != ""
	icon = null
	custom_minimum_size = Vector2(104, 116)
	expand_icon = false

	_apply_card_content(skill, "%s%s" % [skill_name, mode_name], cost, block_reason, theme_color)
	_apply_button_style(theme_color)


func _ready() -> void:
	_ensure_nodes()


func _ensure_nodes() -> void:
	icon_frame = _find_ui_node("IconFrame") as PanelContainer
	skill_icon = _find_ui_node("SkillIcon") as TextureRect
	name_label = _find_ui_node("NameLabel") as Label
	requirement_label = _find_ui_node("RequirementLabel") as Label
	description_label = _find_ui_node("DescriptionLabel") as Label
	cost_label = _find_ui_node("CostLabel") as Label
	mode_label = _find_ui_node("ModeLabel") as Label
	reason_label = _find_ui_node("ReasonLabel") as Label
	_apply_icon_constraints()


func _find_ui_node(node_name: String) -> Node:
	return find_child(node_name, true, false)


func _apply_icon_constraints() -> void:
	if icon_frame != null:
		icon_frame.clip_contents = true
		icon_frame.custom_minimum_size = Vector2(ICON_FRAME_SIZE, ICON_FRAME_SIZE)
		icon_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if skill_icon != null:
		skill_icon.custom_minimum_size = Vector2(ICON_TEXTURE_SIZE, ICON_TEXTURE_SIZE)
		skill_icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill_icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		skill_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		skill_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _apply_card_content(skill: Dictionary, display_name: String, cost: int, block_reason: String, theme_color: Color) -> void:
	_apply_icon_constraints()
	if skill_icon != null:
		skill_icon.texture = UIAssetsScript.texture_from_path(String(skill.get("icon_path", "")), theme_color, Vector2i(44, 44))
		skill_icon.modulate = Color(0.62, 0.62, 0.60) if block_reason != "" else Color.WHITE
	if icon_frame != null:
		var icon_style: StyleBoxFlat = UIAssetsScript.panel_style(theme_color.darkened(0.20), Color("#6F4B1E"), 5)
		icon_style.content_margin_left = 4
		icon_style.content_margin_right = 4
		icon_style.content_margin_top = 4
		icon_style.content_margin_bottom = 4
		icon_frame.add_theme_stylebox_override("panel", icon_style)

	if name_label != null:
		name_label.text = display_name
	if requirement_label != null:
		requirement_label.visible = false
	if description_label != null:
		description_label.visible = false
	if cost_label != null:
		cost_label.text = "%d MP" % cost
	if mode_label != null:
		mode_label.visible = false
	if reason_label != null:
		reason_label.visible = false

	_apply_label_colors(block_reason)


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
	var parts: Array = []
	for requirement in requirements:
		parts.append(_single_requirement_text(requirement))
	return "、".join(parts)


func _single_requirement_text(requirement) -> String:
	if requirement is int or requirement is float:
		return "≥%d" % int(requirement)
	var requirement_text = String(requirement)
	if requirement_text == "odd":
		return "奇数"
	if requirement_text == "even":
		return "偶数"
	if requirement_text.begins_with("="):
		return "=%s" % requirement_text.substr(1)
	return requirement_text


func _detail_text(skill_name: String, mode_name: String, cost: int, requirement_text: String, description: String, state_text: String) -> String:
	var lines: Array = []
	lines.append("%s%s" % [skill_name, mode_name])
	lines.append("MP 消耗：%d" % cost)
	lines.append("骰子需求：%s" % requirement_text)
	if not description.strip_edges().is_empty():
		lines.append(description.strip_edges())
	lines.append(state_text)
	return "\n".join(lines)


func _apply_label_colors(block_reason: String) -> void:
	var main_color = Color("#E8E2D6")
	var muted_color = Color("#B8B0A3")
	if block_reason != "":
		main_color = Color(0.68, 0.68, 0.64)
		muted_color = Color(0.54, 0.54, 0.50)

	if name_label != null:
		name_label.add_theme_color_override("font_color", main_color)
	if requirement_label != null:
		requirement_label.add_theme_color_override("font_color", muted_color)
	if description_label != null:
		description_label.add_theme_color_override("font_color", muted_color)
	if cost_label != null:
		cost_label.add_theme_color_override("font_color", Color("#8EC7FF") if block_reason == "" else muted_color)
	if mode_label != null:
		mode_label.add_theme_color_override("font_color", Color("#47C7D9") if block_reason == "" else muted_color)
	if reason_label != null:
		reason_label.add_theme_color_override("font_color", Color("#F0A08F"))


func _apply_button_style(theme_color: Color) -> void:
	var normal = UIAssetsScript.panel_style(Color("#1B2130"), Color("#C9973F"), 6)
	var hover = UIAssetsScript.panel_style(Color("#222C40"), theme_color.lightened(0.32), 6)
	var pressed_style = UIAssetsScript.panel_style(Color("#111722"), Color("#47C7D9"), 6)
	var disabled_style = UIAssetsScript.panel_style(Color("#24262A"), Color("#5D6470"), 6)
	var focus_style = UIAssetsScript.panel_style(Color("#1D2638"), Color("#47C7D9"), 6)
	normal.set_border_width_all(2)
	hover.set_border_width_all(2)
	pressed_style.set_border_width_all(2)
	focus_style.set_border_width_all(2)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed_style)
	add_theme_stylebox_override("disabled", disabled_style)
	add_theme_stylebox_override("focus", focus_style)
	add_theme_color_override("font_color", Color(1, 1, 1, 0))
	add_theme_color_override("font_hover_color", Color(1, 1, 1, 0))
	add_theme_color_override("font_pressed_color", Color(1, 1, 1, 0))
	add_theme_color_override("font_focus_color", Color(1, 1, 1, 0))
	add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0))
