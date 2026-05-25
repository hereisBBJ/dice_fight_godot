extends PanelContainer
class_name PlayerStatePanel

const DiceViewScene = preload("res://scenes/ui/components/dice_view.tscn")
const StatusIconScene = preload("res://scenes/ui/components/status_icon.tscn")
const UIAssetsScript = preload("res://scripts/ui/components/ui_assets.gd")

const PANEL_BG = Color("#151925")
const TEXT_STRONG = Color("#F2E6C8")
const TEXT_MUTED = Color("#B8B0A3")
const GOLD = Color("#C9973F")
const GOLD_DARK = Color("#6F4B1E")
const PRIVATE_TEXT = "敌方行动：已隐藏"

@export var compact = false
@export var show_dice = true

@onready var portrait_frame: PanelContainer = $Margin/Column/Header/PortraitFrame
@onready var portrait: TextureRect = $Margin/Column/Header/PortraitFrame/PortraitMargin/Portrait
@onready var name_label: Label = $Margin/Column/Header/Info_Stats/Info/Name
@onready var role_label: Label = $Margin/Column/Header/Info_Stats/Info/Role
@onready var feedback_label: Label = $Margin/Column/Header/Info_Stats/Info/Feedback
@onready var hp_bar: ProgressBar = $Margin/Column/Header/Info_Stats/Stats/HpBar
@onready var mp_bar: ProgressBar = $Margin/Column/Header/Info_Stats/Stats/MpBar
@onready var shield_bar: ProgressBar = $Margin/Column/Header/Info_Stats/Stats/ShieldBar
#@onready var dice_slot: Control = $Margin/Column/DiceSlot
@onready var status_row: HFlowContainer = $Margin/Column/StatusRow
@onready var passive_label: Label = $Margin/Column/TextBlock/Passive
@onready var augment_label: Label = $Margin/Column/TextBlock/Augments
@onready var action_label: Label = $Margin/Column/TextBlock/Action
@onready var margin: NinePatchRect = $Margin
@onready var column: VBoxContainer = $Margin/Column
@onready var header: HBoxContainer = $Margin/Column/Header
@onready var stats: VBoxContainer = $Margin/Column/Header/Info_Stats/Stats
@onready var text_block: VBoxContainer = $Margin/Column/TextBlock

var _dice_view: DiceView
var _last_hp = 0
var _last_mp = 0
var _last_shield = 0
var _last_resources: Dictionary = {}
var _has_previous = false


func _ready() -> void:
	_apply_base_styles()
	_apply_layout_mode()
	_dice_view = DiceViewScene.instantiate()
	#dice_slot.add_child(_dice_view)


func set_player(player_id: int, battle, animate: bool = false, hide_private_info: bool = false) -> void:
	var player: Dictionary = battle.players[player_id]
	var character: Dictionary = player.get("character", {})
	var theme_color = UIAssetsScript.color_from_hex(String(character.get("theme_color", "")), Color(0.36, 0.45, 0.65))
	var character_name = "未选择" if character.is_empty() else String(character.get("name", ""))

	add_theme_stylebox_override("panel", UIAssetsScript.formal_panel_style(PANEL_BG, theme_color.lightened(0.18), 6, 2))
	portrait_frame.add_theme_stylebox_override("panel", UIAssetsScript.inset_panel_style(Color(0.07, 0.08, 0.11, 1.0), theme_color.lightened(0.25), 5))
	portrait.texture = UIAssetsScript.texture_from_path(String(character.get("portrait_path", "")), theme_color, Vector2i(192, 192))
	name_label.text = "P%d  %s" % [player_id + 1, character_name]

	var resource_text = battle.resource_text(player_id)
	role_label.text = battle.role_text(player_id) if resource_text.is_empty() else "%s | %s" % [battle.role_text(player_id), resource_text]

	_set_bar(hp_bar, "HP", int(player.get("hp", 0)), int(player.get("max_hp", 1)), Color("#D84A3A"))
	_set_bar(mp_bar, "MP", int(player.get("mp", 0)), int(player.get("max_mp", 1)), Color("#3D8BFF"))
	_set_bar(shield_bar, "护盾", int(player.get("shield", 0)), int(player.get("max_shield", 1)), Color("#9AA7B8"))
	#_render_dice(player, animate, hide_private_info)
	_render_statuses(player, battle.status_effects)
	_render_text_summary(player_id, player, battle, hide_private_info)
	_render_feedback(player)

	_last_hp = int(player.get("hp", 0))
	_last_mp = int(player.get("mp", 0))
	_last_shield = int(player.get("shield", 0))
	_last_resources = player.get("resources", {}).duplicate(true)
	_has_previous = true


func _apply_base_styles() -> void:
	add_theme_stylebox_override("panel", UIAssetsScript.formal_panel_style(PANEL_BG, GOLD, 6, 2))
	#dice_slot.add_theme_stylebox_override("panel", UIAssetsScript.inset_panel_style(Color(0.09, 0.11, 0.16, 0.96), GOLD_DARK, 4))
	UIAssetsScript.apply_label_color(name_label, TEXT_STRONG)
	UIAssetsScript.apply_label_color(role_label, GOLD)
	UIAssetsScript.apply_label_color(feedback_label, Color("#FFE08A"))
	UIAssetsScript.apply_label_color(passive_label, TEXT_MUTED)
	UIAssetsScript.apply_label_color(augment_label, TEXT_MUTED)
	UIAssetsScript.apply_label_color(action_label, TEXT_STRONG)


func _apply_layout_mode() -> void:
	#dice_slot.visible = show_dice
	if not compact:
		return
	custom_minimum_size = Vector2(320, 106)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	column.add_theme_constant_override("separation", 3)
	header.add_theme_constant_override("separation", 6)
	stats.add_theme_constant_override("separation", 2)
	text_block.add_theme_constant_override("separation", 2)
	portrait_frame.custom_minimum_size = Vector2(120, 120)
	name_label.add_theme_font_size_override("font_size", 15)
	role_label.add_theme_font_size_override("font_size", 13)
	feedback_label.custom_minimum_size = Vector2(0, 0)
	feedback_label.add_theme_font_size_override("font_size", 11)
	hp_bar.custom_minimum_size = Vector2(0, 14)
	mp_bar.custom_minimum_size = Vector2(0, 14)
	shield_bar.custom_minimum_size = Vector2(0, 14)
	status_row.custom_minimum_size = Vector2(0, 0)
	status_row.visible = true
	text_block.visible = false
	passive_label.add_theme_font_size_override("font_size", 11)
	augment_label.add_theme_font_size_override("font_size", 11)
	action_label.add_theme_font_size_override("font_size", 12)


func _render_dice(player: Dictionary, animate: bool, hide_private_info: bool) -> void:
	if not show_dice:
		return
	if hide_private_info:
		_dice_view.set_dice([], false)
		#dice_slot.tooltip_text = "联机对战中隐藏敌方骰子。"
	else:
		_dice_view.set_dice(player.get("dice", []), animate)
		#dice_slot.tooltip_text = ""


func _set_bar(bar: ProgressBar, label: String, value: int, maximum: int, color: Color) -> void:
	var display_maximum = max(1, maximum)
	bar.max_value = display_maximum
	bar.value = clamp(value, 0, display_maximum)
	bar.tooltip_text = "%s %d / %d" % [label, value, maximum]

	var background = StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.06, 0.09, 0.94)
	background.border_color = Color(0.49, 0.36, 0.16, 0.85)
	background.set_border_width_all(1)
	background.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)

	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	fill.border_color = color.lightened(0.22)
	fill.set_border_width_all(1)
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)

	var bar_label = bar.get_node("Label") as Label
	bar_label.text = "%s %d / %d" % [label, value, maximum]
	bar_label.add_theme_color_override("font_color", Color.WHITE)
	bar_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	bar_label.add_theme_constant_override("shadow_offset_x", 1)
	bar_label.add_theme_constant_override("shadow_offset_y", 1)


func _render_statuses(player: Dictionary, status_data: Dictionary) -> void:
	for child in status_row.get_children():
		child.queue_free()
	var passive: Dictionary = player.get("character", {}).get("passive", {})
	if not passive.is_empty():
		status_row.add_child(_make_passive_badge(passive))

	var statuses: Array = player.get("statuses", []).duplicate(true)
	if bool(player.get("per_game_flags", {}).get("eagle_eye", false)):
		statuses.append({"id": "eagle_eye"})
	if bool(player.get("per_game_flags", {}).get("flame_tide", false)):
		statuses.append({"id": "flame_tide"})
	if statuses.is_empty():
		if passive.is_empty():
			var label = Label.new()
			label.text = "无状态"
			label.modulate = TEXT_MUTED
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			status_row.add_child(label)
		return
	for status in statuses:
		var icon = StatusIconScene.instantiate()
		status_row.add_child(icon)
		icon.configure(status, status_data)


func _make_passive_badge(passive: Dictionary) -> Button:
	var passive_badge = Button.new()
	passive_badge.text = "被动: %s" % String(passive.get("name", "未命名被动"))
	passive_badge.tooltip_text = "%s\n%s" % [
		String(passive.get("name", "未命名被动")),
		String(passive.get("description", ""))
	]
	passive_badge.custom_minimum_size = Vector2(112, 34)
	if compact:
		passive_badge.custom_minimum_size = Vector2(112, 24)
		passive_badge.add_theme_font_size_override("font_size", 12)
	passive_badge.flat = true
	passive_badge.focus_mode = Control.FOCUS_NONE
	passive_badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	passive_badge.clip_text = true
	passive_badge.add_theme_color_override("font_color", Color(0.98, 0.83, 0.42))
	passive_badge.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.55))
	passive_badge.add_theme_color_override("font_pressed_color", Color(0.98, 0.83, 0.42))
	passive_badge.add_theme_stylebox_override("normal", UIAssetsScript.panel_style(Color(0.10, 0.09, 0.06, 0.90), GOLD_DARK, 5))
	passive_badge.add_theme_stylebox_override("hover", UIAssetsScript.panel_style(Color(0.16, 0.13, 0.07, 0.95), GOLD, 5))
	passive_badge.add_theme_stylebox_override("pressed", UIAssetsScript.panel_style(Color(0.08, 0.07, 0.05, 0.95), GOLD_DARK, 5))
	return passive_badge


func _render_text_summary(player_id: int, player: Dictionary, battle, hide_private_info: bool) -> void:
	var passive: Dictionary = player.get("character", {}).get("passive", {})
	if passive.is_empty():
		passive_label.text = "被动：无"
		passive_label.tooltip_text = ""
	else:
		passive_label.text = "被动：%s" % String(passive.get("name", "未命名被动"))
		passive_label.tooltip_text = String(passive.get("description", ""))

	var augment_text = battle.augment_text(player_id)
	augment_label.text = "强化：%s" % augment_text
	augment_label.tooltip_text = augment_label.text

	if hide_private_info:
		action_label.text = PRIVATE_TEXT
		action_label.tooltip_text = "联机对战中隐藏敌方待提交行动。"
	elif player.get("submitted_action", {}).is_empty():
		action_label.text = "行动：待选择"
		action_label.tooltip_text = ""
	else:
		action_label.text = "行动：%s" % _action_text(player.get("submitted_action", {}))
		action_label.tooltip_text = action_label.text


func _render_feedback(player: Dictionary) -> void:
	feedback_label.text = ""
	if not _has_previous:
		return
	var hp = int(player.get("hp", 0))
	var mp = int(player.get("mp", 0))
	var shield = int(player.get("shield", 0))
	var messages = []
	if hp < _last_hp:
		messages.append("-%d HP" % (_last_hp - hp))
	elif hp > _last_hp:
		messages.append("+%d HP" % (hp - _last_hp))
	if shield < _last_shield:
		messages.append("护盾 -%d" % (_last_shield - shield))
	elif shield > _last_shield:
		messages.append("护盾 +%d" % (shield - _last_shield))
	if mp > _last_mp:
		messages.append("+%d MP" % (mp - _last_mp))
	var resource_names = {}
	for resource in player.get("character", {}).get("resources", []):
		resource_names[String(resource.get("id", ""))] = String(resource.get("name", resource.get("id", "资源")))
	for resource_id in player.get("resources", {}).keys():
		var current_value = int(player.get("resources", {}).get(resource_id, 0))
		var previous_value = int(_last_resources.get(resource_id, 0))
		var resource_name = String(resource_names.get(String(resource_id), String(resource_id)))
		if current_value > previous_value:
			messages.append("%s +%d" % [resource_name, current_value - previous_value])
		elif current_value < previous_value:
			messages.append("%s -%d" % [resource_name, previous_value - current_value])
	if messages.is_empty():
		return
	feedback_label.text = "  ".join(messages)
	feedback_label.modulate = Color(1.0, 0.88, 0.46)
	feedback_label.scale = Vector2(0.95, 0.95)
	var tween = create_tween()
	tween.tween_property(feedback_label, "scale", Vector2.ONE, 0.16)


func _action_text(action: Dictionary) -> String:
	if action.is_empty():
		return "无"
	if String(action.get("type", "")) == "skip":
		return "跳过"
	if String(action.get("type", "")) == "skill":
		var modes: Array = action.get("modes", [])
		return "%s%s" % [String(action.get("skill_id", "")), "" if modes.is_empty() else " + " + ", ".join(modes)]
	return String(action.get("type", ""))
