extends PanelContainer
class_name BattleLogView

@onready var log_text: TextEdit = $Margin/Column/LogText


func set_logs(logs: Array) -> void:
	var start = max(0, logs.size() - 44)
	var visible_logs = []
	for index in range(start, logs.size()):
		visible_logs.append(str(logs[index]))
	log_text.text = "\n".join(visible_logs)
	log_text.scroll_vertical = max(0, log_text.get_line_count())
