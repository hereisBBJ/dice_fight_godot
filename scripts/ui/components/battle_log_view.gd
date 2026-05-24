extends PanelContainer
class_name BattleLogView

const MAX_VISIBLE_LOGS: int = 44
const COLOR_TEXT: String = "#E9DDC4"
const COLOR_MUTED: String = "#B8B0A3"
const COLOR_GOLD: String = "#F0C36A"
const COLOR_P1: String = "#75B7FF"
const COLOR_P2: String = "#FF8E7F"
const COLOR_DANGER: String = "#F07A2A"
const COLOR_RECOVER: String = "#79D99A"
const COLOR_ARCANE: String = "#47C7D9"
const COLOR_WARNING: String = "#D9A447"

@onready var log_text: RichTextLabel = $Margin/Column/LogFrame/LogMargin/LogText


func set_logs(logs: Array) -> void:
	var start: int = logs.size() - MAX_VISIBLE_LOGS
	if start < 0:
		start = 0
	var visible_logs: Array = []
	for index in range(start, logs.size()):
		var raw_text: String = str(logs[index])
		visible_logs.append(_format_log_line(raw_text))
	log_text.text = "\n".join(visible_logs)
	_scroll_to_latest()


func _scroll_to_latest() -> void:
	if not is_node_ready():
		return
	call_deferred("_scroll_to_latest_deferred")


func _scroll_to_latest_deferred() -> void:
	if not is_instance_valid(log_text):
		return
	var last_line: int = log_text.get_line_count() - 1
	if last_line < 0:
		last_line = 0
	log_text.scroll_to_line(last_line)


func _format_log_line(raw_text: String) -> String:
	var line_color: String = _line_color(raw_text)
	var marker_color: String = _marker_color(raw_text)
	var formatted_line: String = ""
	if _has_player_prefix(raw_text):
		var prefix: String = raw_text.substr(0, 2)
		var body: String = _escape_bbcode(raw_text.substr(2))
		formatted_line = "[color=%s]◆[/color] [b][color=%s]%s[/color][/b][color=%s]%s[/color]" % [
			marker_color,
			_prefix_color(prefix),
			prefix,
			line_color,
			body,
		]
	else:
		formatted_line = "[color=%s]◆[/color] [color=%s]%s[/color]" % [
			marker_color,
			line_color,
			_escape_bbcode(raw_text),
		]
	if _is_major_event(raw_text):
		return "[b]%s[/b]" % formatted_line
	return formatted_line


func _has_player_prefix(text: String) -> bool:
	if text.length() < 2:
		return false
	if not text.begins_with("P1") and not text.begins_with("P2"):
		return false
	if text.length() == 2:
		return true
	var next_character: String = text.substr(2, 1)
	return next_character == " " or next_character == "的"


func _prefix_color(prefix: String) -> String:
	if prefix == "P1":
		return COLOR_P1
	return COLOR_P2


func _line_color(text: String) -> String:
	if _contains_any(text, ["对局结束", "获胜", "倒下", "战斗开始", "回合开始", "先手"]):
		return COLOR_GOLD
	if _contains_any(text, ["造成", "伤害", "生命损失", "真实伤害", "击破", "中毒", "灼烧", "寒冷"]):
		return COLOR_DANGER
	if _contains_any(text, ["回复", "获得", "清除", "净化", "护盾", "免疫", "闪避成功", "重生"]):
		return COLOR_RECOVER
	if _contains_any(text, ["提交技能", "重掷", "修改", "选择", "判定"]):
		return COLOR_ARCANE
	if _contains_any(text, ["无法", "失败", "不足", "无效", "没有"]):
		return COLOR_WARNING
	return COLOR_TEXT


func _marker_color(text: String) -> String:
	if _is_major_event(text):
		return COLOR_GOLD
	if _contains_any(text, ["造成", "伤害", "击破", "中毒", "灼烧", "寒冷"]):
		return COLOR_DANGER
	if _contains_any(text, ["回复", "获得", "清除", "净化", "护盾", "免疫", "重生"]):
		return COLOR_RECOVER
	if _contains_any(text, ["提交技能", "重掷", "修改", "选择", "判定"]):
		return COLOR_ARCANE
	if _contains_any(text, ["无法", "失败", "不足", "无效", "没有"]):
		return COLOR_WARNING
	return COLOR_MUTED


func _is_major_event(text: String) -> bool:
	return _contains_any(text, ["战斗开始", "回合开始", "对局结束", "获胜", "双方同时倒下"])


func _contains_any(text: String, keywords: Array) -> bool:
	for keyword in keywords:
		if text.contains(String(keyword)):
			return true
	return false


func _escape_bbcode(text: String) -> String:
	var escaped: String = ""
	for index in range(text.length()):
		var character: String = text.substr(index, 1)
		if character == "[":
			escaped += "[lb]"
		elif character == "]":
			escaped += "[rb]"
		else:
			escaped += character
	return escaped
