extends Control
class_name BattleScreen

signal player_command(player_id: int, command: Dictionary)
signal back_requested

const SkillButtonScene = preload("res://scenes/ui/components/skill_button.tscn")
const UIAssetsScript = preload("res://scripts/ui/components/ui_assets.gd")

@onready var status_label: Label = $Margin/Column/Header/NetworkStatus
@onready var back_button: Button = $Margin/Column/Header/BackButton
@onready var round_label: Label = $Margin/Column/Round
@onready var enemy_title: Label = $Margin/Column/GridScroll/GridMargin/BattleGrid/EnemyCell/EnemyTitle
@onready var self_title: Label = $Margin/Column/GridScroll/GridMargin/BattleGrid/SelfCell/SelfTitle
@onready var action_title: Label = $Margin/Column/GridScroll/GridMargin/BattleGrid/ActionCell/ActionTitle
@onready var enemy_panel = $Margin/Column/GridScroll/GridMargin/BattleGrid/EnemyCell/EnemyPanel
@onready var self_panel = $Margin/Column/GridScroll/GridMargin/BattleGrid/SelfCell/SelfPanel
@onready var action_slot: VBoxContainer = $Margin/Column/GridScroll/GridMargin/BattleGrid/ActionCell/ActionSlot
@onready var interactive_dialog = $Margin/Column/GridScroll/GridMargin/BattleGrid/ActionCell/InteractiveDialog
@onready var log_view = $Margin/Column/GridScroll/GridMargin/BattleGrid/LogCell/LogView

var battle
var network_controller
var _last_snapshot_text = ""


func _ready() -> void:
	back_button.pressed.connect(func():
		back_requested.emit()
	)


func setup(new_battle, new_network_controller) -> void:
	battle = new_battle
	network_controller = new_network_controller
	var snapshot_text = JSON.stringify(battle.to_snapshot())
	var animate = snapshot_text != _last_snapshot_text and not _last_snapshot_text.is_empty()
	_last_snapshot_text = snapshot_text
	var self_id = _self_player_id()
	var enemy_id = 1 - self_id
	status_label.text = _network_text()
	round_label.text = "第 %d 回合 | P%d %s，P%d %s" % [
		battle.round_num,
		battle.attacker_id + 1,
		battle.role_text(battle.attacker_id),
		(1 - battle.attacker_id) + 1,
		battle.role_text(1 - battle.attacker_id)
	]
	enemy_title.text = "敌方状态（P%d）" % [enemy_id + 1]
	self_title.text = "我方状态（P%d）" % [self_id + 1]
	action_title.text = "我方技能选择" if network_controller.mode != network_controller.MODE_LOCAL else "本机行动选择"
	enemy_panel.set_player(enemy_id, battle, animate, _should_hide_enemy_private_info(enemy_id))
	self_panel.set_player(self_id, battle, animate, false)
	interactive_dialog.setup(battle, network_controller)
	if not interactive_dialog.interactive_command.is_connected(_on_interactive_command):
		interactive_dialog.interactive_command.connect(_on_interactive_command)
	action_slot.visible = battle.phase != battle.PHASE_INTERACTIVE
	if action_slot.visible:
		_render_actions(self_id)
	log_view.set_logs(_visible_logs_for_local_player())


func _self_player_id() -> int:
	if network_controller.mode == network_controller.MODE_LOCAL:
		return 0
	return max(0, network_controller.local_player_id)


func _should_hide_enemy_private_info(enemy_id: int) -> bool:
	return network_controller.mode != network_controller.MODE_LOCAL and not network_controller.can_control_player(enemy_id)


func _render_actions(self_id: int) -> void:
	for child in action_slot.get_children():
		child.queue_free()
	if network_controller.mode == network_controller.MODE_LOCAL:
		var local_row = HBoxContainer.new()
		local_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		local_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		local_row.add_theme_constant_override("separation", 10)
		action_slot.add_child(local_row)
		_render_action_panel(0, local_row)
		_render_action_panel(1, local_row)
	else:
		_render_action_panel(self_id, action_slot)


func _render_action_panel(player_id: int, parent: Container) -> void:
	var player: Dictionary = battle.players[player_id]
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UIAssetsScript.panel_style(Color(0.09, 0.10, 0.12, 0.92)))
	parent.add_child(panel)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var title = Label.new()
	title.text = "P%d 行动 | %s" % [player_id + 1, battle.role_text(player_id)]
	title.add_theme_font_size_override("font_size", 18)
	column.add_child(title)
	if not network_controller.can_control_player(player_id):
		_add_hint(column, "联网模式下等待对方操作。")
		return
	if not player.get("submitted_action", {}).is_empty():
		_add_hint(column, "本回合行动已锁定。")
		return
	_render_tools(column, player_id)
	var skill_label = Label.new()
	skill_label.text = "可用技能"
	column.add_child(skill_label)
	var skill_grid = GridContainer.new()
	skill_grid.columns = 1
	skill_grid.add_theme_constant_override("h_separation", 8)
	skill_grid.add_theme_constant_override("v_separation", 8)
	column.add_child(skill_grid)
	for skill in battle.get_allowed_skills(player_id):
		_add_skill_buttons(skill_grid, player_id, skill)


func _render_tools(column: VBoxContainer, player_id: int) -> void:
	var player: Dictionary = battle.players[player_id]
	var tools = HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	column.add_child(tools)
	var reroll = Button.new()
	reroll.text = "重掷 %d MP" % battle.get_reroll_cost(player_id)
	reroll.disabled = player.mp < battle.get_reroll_cost(player_id)
	reroll.pressed.connect(func():
		player_command.emit(player_id, {"type": "reroll_dice"})
	)
	tools.add_child(reroll)
	var die_index = SpinBox.new()
	die_index.min_value = 1
	die_index.max_value = max(1, player.dice.size())
	die_index.step = 1
	die_index.value = 1
	tools.add_child(die_index)
	var die_value = SpinBox.new()
	die_value.min_value = 1
	die_value.max_value = 6
	die_value.step = 1
	die_value.value = 6
	tools.add_child(die_value)
	var modify = Button.new()
	modify.text = "修改 %d MP" % battle.get_modify_cost(player_id)
	modify.disabled = player.mp < battle.get_modify_cost(player_id) or bool(player.has_modified_this_turn)
	modify.pressed.connect(func():
		player_command.emit(player_id, {
			"type": "modify_die",
			"die_index": int(die_index.value) - 1,
			"value": int(die_value.value)
		})
	)
	tools.add_child(modify)
	var skip = Button.new()
	skip.text = "跳过"
	skip.pressed.connect(func():
		player_command.emit(player_id, {"type": "skip_turn"})
	)
	tools.add_child(skip)


func _add_skill_buttons(parent: GridContainer, player_id: int, skill: Dictionary) -> void:
	_add_skill_button(parent, player_id, skill, [])
	for mode in skill.get("modes", []):
		_add_skill_button(parent, player_id, skill, [String(mode.get("id", ""))])


func _add_skill_button(parent: GridContainer, player_id: int, skill: Dictionary, modes: Array) -> void:
	var character: Dictionary = battle.players[player_id].character
	var theme_color = UIAssetsScript.color_from_hex(String(character.get("theme_color", "")))
	var button = SkillButtonScene.instantiate()
	var reason = battle.get_skill_block_reason(player_id, skill, modes)
	button.configure(skill, modes, battle.get_skill_cost(player_id, skill, modes), reason, theme_color)
	var selected_skill_id = String(skill.get("id", ""))
	var selected_modes = modes.duplicate()
	button.pressed.connect(func():
		player_command.emit(player_id, {
			"type": "use_skill",
			"skill_id": selected_skill_id,
			"modes": selected_modes
		})
	)
	parent.add_child(button)


func _visible_logs_for_local_player() -> Array:
	if network_controller.mode == network_controller.MODE_LOCAL:
		return battle.logs
	var hidden_player_id = 1 - _self_player_id()
	var filtered = []
	for entry in battle.logs:
		var text = String(entry)
		if _is_private_log_for_player(text, hidden_player_id):
			continue
		filtered.append(text)
	return filtered


func _is_private_log_for_player(text: String, player_id: int) -> bool:
	var prefix = "P%d " % [player_id + 1]
	return text.begins_with("%s提交技能" % prefix) \
		or text.begins_with("%s选择跳过回合" % prefix) \
		or text.begins_with("%s重掷骰子" % prefix) \
		or text.begins_with("%s修改 1 颗骰子" % prefix) \
		or text.begins_with("%s重掷判定骰" % prefix) \
		or text.begins_with("%s修改判定骰" % prefix)


func _add_hint(parent: VBoxContainer, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.modulate = Color(0.67, 0.70, 0.78)
	parent.add_child(label)


func _on_interactive_command(player_id: int, command: Dictionary) -> void:
	player_command.emit(player_id, command)


func _network_text() -> String:
	var player_text = "本机控制 P1/P2"
	if network_controller.mode != network_controller.MODE_LOCAL:
		player_text = "等待分配玩家编号"
		if network_controller.local_player_id >= 0:
			player_text = "本机控制 P%d" % [network_controller.local_player_id + 1]
	return "%s | %s" % [network_controller.status_message, player_text]
