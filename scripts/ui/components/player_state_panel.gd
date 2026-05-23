extends PanelContainer
class_name PlayerStatePanel

const DiceViewScene = preload("res://scenes/ui/components/dice_view.tscn")
const StatusIconScene = preload("res://scenes/ui/components/status_icon.tscn")
const UIAssetsScript = preload("res://scripts/ui/components/ui_assets.gd")

@export var compact = false
@export var show_dice = true

@onready var portrait: TextureRect = $Margin/Column/Header/Portrait
@onready var name_label: Label = $Margin/Column/Header/Info/Name
@onready var role_label: Label = $Margin/Column/Header/Info/Role
@onready var hp_bar: ProgressBar = $Margin/Column/Stats/HpBar
@onready var mp_bar: ProgressBar = $Margin/Column/Stats/MpBar
@onready var shield_bar: ProgressBar = $Margin/Column/Stats/ShieldBar
@onready var dice_slot: Control = $Margin/Column/DiceSlot
@onready var status_row: HBoxContainer = $Margin/Column/StatusRow
@onready var augment_label: Label = $Margin/Column/Augments
@onready var action_label: Label = $Margin/Column/Action
@onready var feedback_label: Label = $Margin/Column/Header/Info/Feedback
@onready var margin: MarginContainer = $Margin
@onready var column: VBoxContainer = $Margin/Column
@onready var header: HBoxContainer = $Margin/Column/Header
@onready var stats: VBoxContainer = $Margin/Column/Stats

var _dice_view: DiceView
var _last_hp = 0
var _last_mp = 0
var _last_shield = 0
var _last_resources: Dictionary = {}
var _has_previous = false


func _ready() -> void:
	_apply_layout_mode()
	_dice_view = DiceViewScene.instantiate()
	dice_slot.add_child(_dice_view)


func set_player(player_id: int, battle, animate: bool = false, hide_private_info: bool = false) -> void:
	var player: Dictionary = battle.players[player_id]
	var character: Dictionary = player.get("character", {})
	var theme_color = UIAssetsScript.color_from_hex(String(character.get("theme_color", "")), Color(0.36, 0.45, 0.65))
	add_theme_stylebox_override("panel", UIAssetsScript.panel_style(Color(0.10, 0.11, 0.13, 0.94), theme_color.darkened(0.15), 7))
	portrait.texture = UIAssetsScript.texture_from_path(String(character.get("portrait_path", "")), theme_color, Vector2i(192, 192))
	name_label.text = "P%d  %s" % [player_id + 1, "未选择" if character.is_empty() else String(character.get("name", ""))]
	var resource_text = battle.resource_text(player_id)
	role_label.text = battle.role_text(player_id) if resource_text.is_empty() else "%s | %s" % [battle.role_text(player_id), resource_text]
	_set_bar(hp_bar, "HP", int(player.get("hp", 0)), int(player.get("max_hp", 1)), Color(0.86, 0.20, 0.22))
	_set_bar(mp_bar, "MP", int(player.get("mp", 0)), int(player.get("max_mp", 1)), Color(0.25, 0.48, 0.92))
	_set_bar(shield_bar, "护盾", int(player.get("shield", 0)), int(player.get("max_shield", 1)), Color(0.35, 0.68, 0.90))
	if show_dice:
		if hide_private_info:
			_dice_view.set_dice([], false)
			dice_slot.tooltip_text = "联机对战中隐藏敌方骰子。"
		else:
			_dice_view.set_dice(player.get("dice", []), animate)
			dice_slot.tooltip_text = ""
	_render_statuses(player, battle.status_effects)
	augment_label.text = "强化：%s" % battle.augment_text(player_id)
	if hide_private_info:
		action_label.text = "敌方行动：隐藏"
	elif player.get("submitted_action", {}).is_empty():
		action_label.text = ""
	else:
		action_label.text = "已提交：%s" % _action_text(player.get("submitted_action", {}))
	_render_feedback(player)
	_last_hp = int(player.get("hp", 0))
	_last_mp = int(player.get("mp", 0))
	_last_shield = int(player.get("shield", 0))
	_last_resources = player.get("resources", {}).duplicate(true)
	_has_previous = true


func _apply_layout_mode() -> void:
	dice_slot.visible = show_dice
	if not compact:
		return
	custom_minimum_size = Vector2(360, 118)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	column.add_theme_constant_override("separation", 4)
	header.add_theme_constant_override("separation", 8)
	stats.add_theme_constant_override("separation", 3)
	portrait.custom_minimum_size = Vector2(70, 70)
	name_label.add_theme_font_size_override("font_size", 18)
	role_label.add_theme_font_size_override("font_size", 12)
	feedback_label.add_theme_font_size_override("font_size", 14)
	hp_bar.custom_minimum_size = Vector2(0, 18)
	mp_bar.custom_minimum_size = Vector2(0, 18)
	shield_bar.custom_minimum_size = Vector2(0, 18)
	augment_label.add_theme_font_size_override("font_size", 11)
	action_label.add_theme_font_size_override("font_size", 12)


func _set_bar(bar: ProgressBar, label: String, value: int, maximum: int, color: Color) -> void:
	bar.max_value = max(1, maximum)
	bar.value = clamp(value, 0, max(1, maximum))
	bar.tooltip_text = "%s %d / %d" % [label, value, maximum]
	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	bar.get_node("Label").text = "%s %d / %d" % [label, value, maximum]


func _render_statuses(player: Dictionary, status_data: Dictionary) -> void:
	for child in status_row.get_children():
		child.queue_free()
	var statuses: Array = player.get("statuses", []).duplicate(true)
	if bool(player.get("per_game_flags", {}).get("eagle_eye", false)):
		statuses.append({"id": "eagle_eye"})
	if bool(player.get("per_game_flags", {}).get("flame_tide", false)):
		statuses.append({"id": "flame_tide"})
	if statuses.is_empty():
		var label = Label.new()
		label.text = "无状态"
		label.modulate = Color(0.62, 0.65, 0.72)
		status_row.add_child(label)
		return
	for status in statuses:
		var icon = StatusIconScene.instantiate()
		status_row.add_child(icon)
		icon.configure(status, status_data)


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
