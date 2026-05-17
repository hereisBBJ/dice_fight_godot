extends Control

const BattleStateScript = preload("res://scripts/rules/battle_state.gd")
const NetworkControllerScript = preload("res://scripts/network/network_controller.gd")

var battle
var network_controller
var app_screen = "menu"
var default_join_ip = "127.0.0.1"


func _ready() -> void:
	battle = BattleStateScript.new()
	battle.setup()
	network_controller = NetworkControllerScript.new()
	network_controller.name = "NetworkController"
	add_child(network_controller)
	network_controller.bind_battle_state(battle)
	network_controller.state_changed.connect(_render)
	network_controller.status_changed.connect(_render)
	_render()


func _render() -> void:
	_clear()
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var root = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	scroll.add_child(root)

	_add_title(root, "Dice Fight Demo")
	if app_screen == "menu":
		_render_network_menu(root)
		return
	_render_network_status(root)
	match battle.phase:
		BattleStateScript.PHASE_CHARACTER_SELECT:
			_render_character_select(root)
		BattleStateScript.PHASE_AUGMENT_SELECT:
			_render_augment_select(root)
		BattleStateScript.PHASE_GAME_OVER:
			_render_game_over(root)
		_:
			_render_battle(root)


func _clear() -> void:
	for child in get_children():
		if child == network_controller:
			continue
		child.queue_free()


func _render_network_menu(root: VBoxContainer) -> void:
	var panel = _panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(panel)
	_add_label(panel, "选择运行模式", 24)
	_add_label(panel, "Milestone 2：LAN 主机权威同步。单机热座仍保留，方便本机规则测试。", 16)

	var local_button = Button.new()
	local_button.text = "单机热座"
	local_button.custom_minimum_size = Vector2(0, 54)
	local_button.pressed.connect(func():
		battle.reset_to_character_select()
		network_controller.start_local(battle)
		app_screen = "game"
		_render()
	)
	panel.add_child(local_button)

	var host_button = Button.new()
	host_button.text = "创建 LAN 房间（端口 %d）" % NetworkControllerScript.DEFAULT_PORT
	host_button.custom_minimum_size = Vector2(0, 54)
	host_button.pressed.connect(func():
		battle.reset_to_character_select()
		if network_controller.host(battle):
			app_screen = "game"
		_render()
	)
	panel.add_child(host_button)

	var join_row = HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	panel.add_child(join_row)

	var ip_input = LineEdit.new()
	ip_input.text = default_join_ip
	ip_input.placeholder_text = "主机 IP，例如 192.168.1.10"
	ip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(ip_input)

	var join_button = Button.new()
	join_button.text = "加入 LAN 房间"
	join_button.pressed.connect(func():
		default_join_ip = ip_input.text.strip_edges()
		if default_join_ip.is_empty():
			default_join_ip = "127.0.0.1"
		battle.reset_to_character_select()
		if network_controller.join(battle, default_join_ip):
			app_screen = "game"
		_render()
	)
	join_row.add_child(join_button)

	_add_label(panel, "状态：%s" % network_controller.status_message, 15)
	_render_log(root)


func _render_network_status(root: VBoxContainer) -> void:
	var panel = _panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(panel)
	var player_text = "本机控制 P1/P2"
	if network_controller.mode != NetworkControllerScript.MODE_LOCAL:
		player_text = "等待分配玩家编号"
		if network_controller.local_player_id >= 0:
			player_text = "本机控制 P%d" % [network_controller.local_player_id + 1]
	_add_label(panel, "%s | %s" % [network_controller.status_message, player_text], 15)
	var back = Button.new()
	back.text = "返回模式选择 / 断开连接"
	back.pressed.connect(func():
		network_controller.stop_network()
		battle.reset_to_character_select()
		app_screen = "menu"
		_render()
	)
	panel.add_child(back)


func _render_character_select(root: VBoxContainer) -> void:
	_add_label(root, "为 P1 和 P2 选择角色。联网模式下只能选择自己的角色。", 18)
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)
	for player_id in range(2):
		var selected_player_id = player_id
		var panel = _panel()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(panel)
		_add_label(panel, "P%d 角色" % [selected_player_id + 1], 22)
		if battle.players[selected_player_id].character_id != "":
			_add_label(panel, "已选择：%s" % battle.players[selected_player_id].character.name, 16)
		for character_id in ["swordsman", "archer"]:
			var selected_character_id = character_id
			var character: Dictionary = battle.characters[character_id]
			var button = Button.new()
			button.text = "%s\nHP %d / MP %d / 护盾上限 %d\n%s" % [
				character.name,
				int(character.max_hp),
				int(character.max_mp),
				int(character.max_shield),
				character.passive.description
			]
			button.custom_minimum_size = Vector2(0, 96)
			button.disabled = not _can_control_player(selected_player_id) or battle.players[selected_player_id].character_id == selected_character_id
			button.pressed.connect(func():
				_submit_player_command(selected_player_id, {
					"type": "select_character",
					"character_id": selected_character_id
				})
			)
			panel.add_child(button)
	_render_log(root)


func _render_augment_select(root: VBoxContainer) -> void:
	_add_label(root, "强化选择：每名玩家先选通用强化，再选专属强化。", 18)
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)
	for player_id in range(2):
		var selected_player_id = player_id
		var panel = _panel()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(panel)
		var player: Dictionary = battle.players[selected_player_id]
		_add_label(panel, "P%d %s" % [selected_player_id + 1, player.character.name], 22)
		_add_label(panel, "已选：%s" % battle.augment_text(selected_player_id), 15)
		var kind = battle.get_next_augment_kind(selected_player_id)
		if kind == "done":
			_add_label(panel, "强化选择完成。", 16)
			continue
		var kind_name = "通用强化" if kind == "common" else "专属强化"
		_add_label(panel, "请选择 1 个%s：" % kind_name, 17)
		for augment in battle.augment_candidates[selected_player_id].get(kind, []):
			var selected_augment_id = String(augment.id)
			var button = Button.new()
			button.text = "%s\n%s" % [augment.name, augment.description]
			button.custom_minimum_size = Vector2(0, 78)
			button.disabled = not _can_control_player(selected_player_id)
			button.pressed.connect(func():
				_submit_player_command(selected_player_id, {
					"type": "pick_augment",
					"augment_id": selected_augment_id
				})
			)
			panel.add_child(button)
	_render_log(root)


func _render_battle(root: VBoxContainer) -> void:
	_add_label(root, "第 %d 回合 | P%d %s，P%d %s" % [
		battle.round_num,
		battle.attacker_id + 1,
		battle.role_text(battle.attacker_id),
		(1 - battle.attacker_id) + 1,
		battle.role_text(1 - battle.attacker_id)
	], 18)

	var state_row = HBoxContainer.new()
	state_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_row.add_theme_constant_override("separation", 12)
	root.add_child(state_row)
	for player_id in range(2):
		state_row.add_child(_player_state_panel(player_id))

	if battle.phase == BattleStateScript.PHASE_INTERACTIVE:
		_render_interactive(root)
	else:
		var action_row = HBoxContainer.new()
		action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_row.add_theme_constant_override("separation", 12)
		root.add_child(action_row)
		for player_id in range(2):
			action_row.add_child(_action_panel(player_id))

	_render_log(root)


func _render_interactive(root: VBoxContainer) -> void:
	var request: Dictionary = battle.pending_interactive_request
	var responder_id = int(request.responder_id)
	var kind = String(request.kind)
	var title = "射击闪避判定" if kind == "shot_evasion" else "后跳判定"
	var panel = _panel()
	root.add_child(panel)
	_add_label(panel, "%s：P%d 当前判定骰为 %d" % [title, responder_id + 1, int(request.die)], 22)
	_add_label(panel, "可接受结果，或支付 MP 重掷/修改判定骰。", 15)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var accept = Button.new()
	accept.text = "接受结果"
	accept.disabled = not _can_control_player(responder_id)
	accept.pressed.connect(func():
		_submit_player_command(responder_id, {"type": "interactive_accept"})
	)
	row.add_child(accept)

	var reroll = Button.new()
	var reroll_cost = battle.get_reroll_cost(responder_id)
	reroll.text = "重掷判定骰（%d MP）" % reroll_cost
	reroll.disabled = not _can_control_player(responder_id) or battle.players[responder_id].mp < reroll_cost
	reroll.pressed.connect(func():
		_submit_player_command(responder_id, {"type": "interactive_reroll"})
	)
	row.add_child(reroll)

	var value_spin = SpinBox.new()
	value_spin.min_value = 1
	value_spin.max_value = 6
	value_spin.step = 1
	value_spin.value = clamp(int(request.die), 1, 6)
	row.add_child(value_spin)

	var modify = Button.new()
	var modify_cost = battle.get_modify_cost(responder_id)
	modify.text = "修改判定骰（%d MP）" % modify_cost
	modify.disabled = not _can_control_player(responder_id) or battle.players[responder_id].mp < modify_cost or bool(battle.players[responder_id].has_modified_this_turn)
	modify.pressed.connect(func():
		_submit_player_command(responder_id, {
			"type": "interactive_modify",
			"value": int(value_spin.value)
		})
	)
	row.add_child(modify)


func _render_game_over(root: VBoxContainer) -> void:
	var result = "平局"
	if battle.winner_id >= 0:
		result = "P%d 获胜" % [battle.winner_id + 1]
	_add_label(root, "对局结束：%s" % result, 28)
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)
	for player_id in range(2):
		row.add_child(_player_state_panel(player_id))

	var buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	root.add_child(buttons)
	var rematch = Button.new()
	rematch.text = "再来一局（保留角色与强化）"
	rematch.disabled = not network_controller.can_control_any()
	rematch.pressed.connect(func():
		_submit_global_command({"type": "restart_request"})
	)
	buttons.add_child(rematch)

	var reset = Button.new()
	reset.text = "重新选角"
	reset.disabled = network_controller.mode == NetworkControllerScript.MODE_CLIENT
	reset.pressed.connect(func():
		_submit_global_command({"type": "reset_to_character_select"})
	)
	buttons.add_child(reset)
	_render_log(root)


func _player_state_panel(player_id: int) -> VBoxContainer:
	var player: Dictionary = battle.players[player_id]
	var panel = _panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var character_name = "未选择" if player.character_id == "" else String(player.character.name)
	_add_label(panel, "P%d %s | %s" % [player_id + 1, character_name, battle.role_text(player_id)], 21)
	_add_label(panel, "HP %d / %d    MP %d / %d    护盾 %d / %d" % [
		int(player.hp), int(player.max_hp), int(player.mp), int(player.max_mp), int(player.shield), int(player.max_shield)
	], 16)
	_add_label(panel, "骰子：%s" % _dice_text(player.dice), 16)
	_add_label(panel, "状态：%s" % battle.status_text(player_id), 15)
	_add_label(panel, "强化：%s" % battle.augment_text(player_id), 14)
	if not player.submitted_action.is_empty():
		_add_label(panel, "已提交：%s" % _action_text(player.submitted_action), 15)
	return panel


func _action_panel(player_id: int) -> VBoxContainer:
	var player: Dictionary = battle.players[player_id]
	var panel = _panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_label(panel, "P%d 行动 | %s" % [player_id + 1, battle.role_text(player_id)], 20)
	if not _can_control_player(player_id):
		_add_label(panel, "联网模式下等待对方操作。", 16)
		return panel
	if not player.submitted_action.is_empty():
		_add_label(panel, "本回合行动已锁定。", 16)
		return panel

	var tools = HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	panel.add_child(tools)

	var reroll = Button.new()
	reroll.text = "重掷（%d MP）" % battle.get_reroll_cost(player_id)
	reroll.disabled = player.mp < battle.get_reroll_cost(player_id)
	reroll.pressed.connect(func():
		_submit_player_command(player_id, {"type": "reroll_dice"})
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
	modify.text = "修改（%d MP）" % battle.get_modify_cost(player_id)
	modify.disabled = player.mp < battle.get_modify_cost(player_id) or bool(player.has_modified_this_turn)
	modify.pressed.connect(func():
		_submit_player_command(player_id, {
			"type": "modify_die",
			"die_index": int(die_index.value) - 1,
			"value": int(die_value.value)
		})
	)
	tools.add_child(modify)

	var skip = Button.new()
	skip.text = "跳过回合"
	skip.pressed.connect(func():
		_submit_player_command(player_id, {"type": "skip_turn"})
	)
	tools.add_child(skip)

	_add_label(panel, "可用技能：", 16)
	for skill in battle.get_allowed_skills(player_id):
		_add_skill_buttons(panel, player_id, skill)
	return panel


func _add_skill_buttons(parent: VBoxContainer, player_id: int, skill: Dictionary) -> void:
	var skill_box = VBoxContainer.new()
	skill_box.add_theme_constant_override("separation", 4)
	parent.add_child(skill_box)
	_add_label(skill_box, "%s | %s" % [skill.name, skill.description], 14)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	skill_box.add_child(row)
	_add_skill_button(row, player_id, skill, [])
	for mode in skill.get("modes", []):
		_add_skill_button(row, player_id, skill, [String(mode.id)])


func _add_skill_button(parent: HBoxContainer, player_id: int, skill: Dictionary, modes: Array) -> void:
	var button = Button.new()
	var mode_name = ""
	if not modes.is_empty():
		for mode in skill.get("modes", []):
			if String(mode.id) == modes[0]:
				mode_name = " + %s" % String(mode.name)
	var cost = battle.get_skill_cost(player_id, skill, modes)
	button.text = "%s%s（%d MP）" % [skill.name, mode_name, cost]
	var reason = battle.get_skill_block_reason(player_id, skill, modes)
	button.disabled = reason != ""
	button.tooltip_text = "可使用" if reason == "" else reason
	var selected_skill_id = String(skill.id)
	var selected_modes = modes.duplicate()
	button.pressed.connect(func():
		_submit_player_command(player_id, {
			"type": "use_skill",
			"skill_id": selected_skill_id,
			"modes": selected_modes
		})
	)
	parent.add_child(button)


func _render_log(root: VBoxContainer) -> void:
	var panel = _panel()
	root.add_child(panel)
	_add_label(panel, "战斗日志", 20)
	var log_view = TextEdit.new()
	log_view.editable = false
	log_view.custom_minimum_size = Vector2(0, 220)
	var start = max(0, battle.logs.size() - 40)
	var visible_logs = []
	for index in range(start, battle.logs.size()):
		visible_logs.append(str(battle.logs[index]))
	log_view.text = "\n".join(visible_logs)
	panel.add_child(log_view)


func _panel() -> VBoxContainer:
	var panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 8)
	panel.custom_minimum_size = Vector2(360, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.12, 0.14, 0.92)
	style.border_color = Color(0.24, 0.27, 0.31)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _add_title(parent: VBoxContainer, text: String) -> Label:
	var label = _add_label(parent, text, 34)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _add_label(parent: VBoxContainer, text: String, font_size: int = 16) -> Label:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _dice_text(dice: Array) -> String:
	if dice.is_empty():
		return "[]"
	var parts = []
	for die in dice:
		parts.append(str(die))
	return "[" + ", ".join(parts) + "]"


func _action_text(action: Dictionary) -> String:
	if action.is_empty():
		return "无"
	if String(action.type) == "skip":
		return "跳过"
	if String(action.type) == "skill":
		var modes: Array = action.get("modes", [])
		return "%s%s" % [String(action.skill_id), "" if modes.is_empty() else " + " + ", ".join(modes)]
	return String(action.type)


func _can_control_player(player_id: int) -> bool:
	return network_controller.can_control_player(player_id)


func _submit_player_command(player_id: int, command: Dictionary) -> void:
	network_controller.submit_command(player_id, command)
	_render()


func _submit_global_command(command: Dictionary) -> void:
	network_controller.submit_global_command(command)
	_render()
