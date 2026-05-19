extends Control
class_name AugmentSelectScreen

signal player_command(player_id: int, command: Dictionary)
signal back_requested

@onready var status_label: Label = $Scroll/Margin/Column/NetworkStatus
@onready var back_button: Button = $Scroll/Margin/Column/BackButton
@onready var p1_list: VBoxContainer = $Scroll/Margin/Column/Players/P1Panel/Margin/Column/Options
@onready var p2_list: VBoxContainer = $Scroll/Margin/Column/Players/P2Panel/Margin/Column/Options
@onready var p1_title: Label = $Scroll/Margin/Column/Players/P1Panel/Margin/Column/Title
@onready var p2_title: Label = $Scroll/Margin/Column/Players/P2Panel/Margin/Column/Title
@onready var log_view = $Scroll/Margin/Column/LogView

var battle
var network_controller


func _ready() -> void:
	back_button.pressed.connect(func():
		back_requested.emit()
	)


func setup(new_battle, new_network_controller) -> void:
	battle = new_battle
	network_controller = new_network_controller
	status_label.text = _network_text()
	_render_player_column(0, p1_title, p1_list)
	_render_player_column(1, p2_title, p2_list)
	log_view.set_logs(battle.logs)


func _render_player_column(player_id: int, title: Label, options: VBoxContainer) -> void:
	var player: Dictionary = battle.players[player_id]
	title.text = "P%d %s" % [player_id + 1, String(player.character.name)]
	for child in options.get_children():
		child.queue_free()
	var picked = Label.new()
	picked.text = "已选：%s" % battle.augment_text(player_id)
	picked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	options.add_child(picked)
	var kind = battle.get_next_augment_kind(player_id)
	if kind == "done":
		var done = Label.new()
		done.text = "强化选择完成。"
		options.add_child(done)
		return
	var kind_name = "通用强化" if kind == "common" else "专属强化"
	var prompt = Label.new()
	prompt.text = "请选择 1 个%s：" % kind_name
	prompt.add_theme_font_size_override("font_size", 17)
	options.add_child(prompt)
	for augment in battle.augment_candidates[player_id].get(kind, []):
		var button = Button.new()
		button.custom_minimum_size = Vector2(0, 86)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s\n%s" % [String(augment.get("name", "")), String(augment.get("description", ""))]
		button.disabled = not network_controller.can_control_player(player_id)
		var selected_id = String(augment.get("id", ""))
		button.pressed.connect(func():
			player_command.emit(player_id, {
				"type": "pick_augment",
				"augment_id": selected_id
			})
		)
		options.add_child(button)


func _network_text() -> String:
	var player_text = "本机控制 P1/P2"
	if network_controller.mode != network_controller.MODE_LOCAL:
		player_text = "等待分配玩家编号"
		if network_controller.local_player_id >= 0:
			player_text = "本机控制 P%d" % [network_controller.local_player_id + 1]
	return "%s | %s" % [network_controller.status_message, player_text]
