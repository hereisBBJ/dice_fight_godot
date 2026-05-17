extends Control

const BattleStateScript = preload("res://scripts/rules/battle_state.gd")

var battle


func _ready() -> void:
	battle = BattleStateScript.new()
	battle.setup()
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
		child.queue_free()


func _render_character_select(root: VBoxContainer) -> void:
	_add_label(root, "单机双人热座：先为 P1 和 P2 选择角色。", 18)
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
			button.disabled = battle.players[selected_player_id].character_id == selected_character_id
			button.pressed.connect(func():
				battle.select_character(selected_player_id, selected_character_id)
				_render()
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
			button.pressed.connect(func():
				battle.pick_augment(selected_player_id, selected_augment_id)
				_render()
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
	accept.pressed.connect(func():
		battle.interactive_accept()
		_render()
	)
	row.add_child(accept)

	var reroll = Button.new()
	var reroll_cost = battle.get_reroll_cost(responder_id)
	reroll.text = "重掷判定骰（%d MP）" % reroll_cost
	reroll.disabled = battle.players[responder_id].mp < reroll_cost
	reroll.pressed.connect(func():
		battle.interactive_reroll()
		_render()
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
	modify.disabled = battle.players[responder_id].mp < modify_cost or bool(battle.players[responder_id].has_modified_this_turn)
	modify.pressed.connect(func():
		battle.interactive_modify(int(value_spin.value))
		_render()
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
	rematch.pressed.connect(func():
		battle.restart_match()
		_render()
	)
	buttons.add_child(rematch)

	var reset = Button.new()
	reset.text = "重新选角"
	reset.pressed.connect(func():
		battle.reset_to_character_select()
		_render()
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
		battle.reroll_dice(player_id)
		_render()
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
		battle.modify_die(player_id, int(die_index.value) - 1, int(die_value.value))
		_render()
	)
	tools.add_child(modify)

	var skip = Button.new()
	skip.text = "跳过回合"
	skip.pressed.connect(func():
		battle.submit_skip(player_id)
		_render()
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
		battle.submit_skill(player_id, selected_skill_id, selected_modes)
		_render()
	)
	parent.add_child(button)


func _render_log(root: VBoxContainer) -> void:
	var panel = _panel()
	root.add_child(panel)
	_add_label(panel, "战斗日志", 20)
	var log = TextEdit.new()
	log.editable = false
	log.custom_minimum_size = Vector2(0, 220)
	var start = max(0, battle.logs.size() - 40)
	var visible_logs = []
	for index in range(start, battle.logs.size()):
		visible_logs.append(str(battle.logs[index]))
	log.text = "\n".join(visible_logs)
	panel.add_child(log)


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
