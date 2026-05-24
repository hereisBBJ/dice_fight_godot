extends Control
class_name BattleScreen

signal player_command(player_id: int, command: Dictionary)
signal back_requested

const SkillButtonScene = preload("res://scenes/ui/components/skill_button.tscn")
const DiceViewScene = preload("res://scenes/ui/components/dice_view.tscn")
const UIAssetsScript = preload("res://scripts/ui/components/ui_assets.gd")

@onready var top_band: PanelContainer = $LayoutRoot/TopBand
@onready var arena_band: PanelContainer = $LayoutRoot/ArenaBand
@onready var bottom_band: PanelContainer = $LayoutRoot/BottomBand
@onready var status_label: Label = $LayoutRoot/TopBand/TopMargin/StatusRow/TopHud/NetworkStatus
@onready var back_button: Button = $LayoutRoot/TopBand/TopMargin/StatusRow/TopHud/BackButton
@onready var round_label: Label = $LayoutRoot/ArenaBand/ArenaMargin/ArenaRow/StageCenter/Round
@onready var scene_label: Label = $LayoutRoot/ArenaBand/ArenaMargin/ArenaRow/StageCenter/StageCenterFill/SceneLabel
@onready var enemy_panel = $LayoutRoot/TopBand/TopMargin/StatusRow/EnemyPanel
@onready var self_panel = $LayoutRoot/TopBand/TopMargin/StatusRow/SelfPanel
@onready var self_character_slot: PanelContainer = $LayoutRoot/ArenaBand/ArenaMargin/ArenaRow/SelfStageColumn/SelfCharacterHolder/SelfCharacterSlot
@onready var self_character_portrait: TextureRect = $LayoutRoot/ArenaBand/ArenaMargin/ArenaRow/SelfStageColumn/SelfCharacterHolder/SelfCharacterSlot/SelfCharacterMargin/SelfCharacterColumn/Portrait
@onready var self_character_name: Label = $LayoutRoot/ArenaBand/ArenaMargin/ArenaRow/SelfStageColumn/SelfCharacterHolder/SelfCharacterSlot/SelfCharacterMargin/SelfCharacterColumn/Name
@onready var enemy_character_slot: PanelContainer = $LayoutRoot/ArenaBand/ArenaMargin/ArenaRow/EnemyStageColumn/EnemyCharacterHolder/EnemyCharacterSlot
@onready var enemy_character_portrait: TextureRect = $LayoutRoot/ArenaBand/ArenaMargin/ArenaRow/EnemyStageColumn/EnemyCharacterHolder/EnemyCharacterSlot/EnemyCharacterMargin/EnemyCharacterColumn/Portrait
@onready var enemy_character_name: Label = $LayoutRoot/ArenaBand/ArenaMargin/ArenaRow/EnemyStageColumn/EnemyCharacterHolder/EnemyCharacterSlot/EnemyCharacterMargin/EnemyCharacterColumn/Name
@onready var dice_panel: PanelContainer = $LayoutRoot/BottomBand/BottomMargin/BottomRow/DicePanel
@onready var dice_slot: VBoxContainer = $LayoutRoot/BottomBand/BottomMargin/BottomRow/DicePanel/DiceMargin/DiceColumn/DiceSlot
@onready var action_cell: PanelContainer = $LayoutRoot/BottomBand/BottomMargin/BottomRow/ActionCell
@onready var action_title: Label = $LayoutRoot/BottomBand/BottomMargin/BottomRow/ActionCell/ActionMargin/ActionColumn/ActionTitle
@onready var action_slot: VBoxContainer = $LayoutRoot/BottomBand/BottomMargin/BottomRow/ActionCell/ActionMargin/ActionColumn/ActionSlot
@onready var interactive_dialog = $LayoutRoot/BottomBand/BottomMargin/BottomRow/ActionCell/ActionMargin/ActionColumn/InteractiveDialog
@onready var log_view = $LayoutRoot/BottomBand/BottomMargin/BottomRow/DicePanel/DiceMargin/DiceColumn/LogView

var battle
var network_controller
var _last_snapshot_text = ""
var _last_presentation_event_count = 0


func _ready() -> void:
	_apply_placeholder_styles()
	back_button.pressed.connect(func():
		back_requested.emit()
	)


func setup(new_battle, new_network_controller) -> void:
	battle = new_battle
	network_controller = new_network_controller
	var snapshot_text = JSON.stringify(battle.to_snapshot())
	var first_render = _last_snapshot_text.is_empty()
	var animate = snapshot_text != _last_snapshot_text and not _last_snapshot_text.is_empty()
	_last_snapshot_text = snapshot_text
	var self_id = _self_player_id()
	var enemy_id = 1 - self_id
	status_label.text = _network_text()
	round_label.text = "第 %d 回合 | P%d %s，P%d %s" % [
		battle.round_num,
		battle.first_player_id + 1,
		battle.role_text(battle.first_player_id),
		(1 - battle.first_player_id) + 1,
		battle.role_text(1 - battle.first_player_id)
	]
	scene_label.text = "场景"
	action_title.text = "我方技能选择" if network_controller.mode != network_controller.MODE_LOCAL else "本机行动选择"
	enemy_panel.set_player(enemy_id, battle, animate, _should_hide_enemy_private_info(enemy_id))
	self_panel.set_player(self_id, battle, animate, false)
	_render_stage_character(self_character_slot, self_character_portrait, self_character_name, self_id, "我方", false)
	_render_stage_character(enemy_character_slot, enemy_character_portrait, enemy_character_name, enemy_id, "敌方", true)
	_render_dice_area(self_id, animate)
	interactive_dialog.setup(battle, network_controller)
	if not interactive_dialog.interactive_command.is_connected(_on_interactive_command):
		interactive_dialog.interactive_command.connect(_on_interactive_command)
	action_slot.visible = battle.phase != battle.PHASE_INTERACTIVE
	if action_slot.visible:
		_render_actions(self_id)
	log_view.set_logs(_visible_logs_for_local_player())
	if first_render:
		_last_presentation_event_count = battle.presentation_events.size()
	else:
		_play_new_presentation_events(self_id, enemy_id)


func _apply_placeholder_styles() -> void:
	top_band.add_theme_stylebox_override("panel", UIAssetsScript.panel_style(Color(0.93, 0.42, 0.14), Color(0.12, 0.10, 0.08), 0))
	arena_band.add_theme_stylebox_override("panel", UIAssetsScript.panel_style(Color(0.23, 0.43, 0.72), Color(0.08, 0.15, 0.26), 0))
	bottom_band.add_theme_stylebox_override("panel", UIAssetsScript.panel_style(Color(0.93, 0.42, 0.14), Color(0.12, 0.10, 0.08), 0))
	dice_panel.add_theme_stylebox_override("panel", UIAssetsScript.panel_style(Color(0.58, 0.58, 0.56), Color(0.18, 0.18, 0.18), 0))
	action_cell.add_theme_stylebox_override("panel", UIAssetsScript.panel_style(Color(0.93, 0.42, 0.14, 0.0), Color(0.12, 0.10, 0.08, 0.0), 0))


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
	panel.custom_minimum_size = Vector2(260, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UIAssetsScript.panel_style(Color(0.10, 0.09, 0.07, 0.78), Color(0.97, 0.70, 0.10, 0.72), 8))
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
	title.add_theme_font_size_override("font_size", 16)
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
	skill_grid.columns = 2 if network_controller.mode == network_controller.MODE_LOCAL else 4
	skill_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skill_grid.add_theme_constant_override("h_separation", 8)
	skill_grid.add_theme_constant_override("v_separation", 8)
	column.add_child(skill_grid)
	for skill in battle.get_allowed_skills(player_id):
		_add_skill_buttons(skill_grid, player_id, skill)


func _render_stage_character(slot: PanelContainer, portrait: TextureRect, label: Label, player_id: int, prefix: String, flip_h: bool) -> void:
	var player: Dictionary = battle.players[player_id]
	var character: Dictionary = player.get("character", {})
	var theme_color = UIAssetsScript.color_from_hex(String(character.get("theme_color", "")), Color(0.18, 0.19, 0.22))
	slot.add_theme_stylebox_override("panel", UIAssetsScript.panel_style(Color(0.02, 0.02, 0.025), theme_color.darkened(0.2), 2))
	portrait.flip_h = flip_h
	if portrait.has_method("set_character_animation"):
		portrait.set_character_animation(character, theme_color, Vector2i(192, 192), "battle_idle")
	else:
		portrait.texture = UIAssetsScript.texture_from_path(String(character.get("portrait_path", "")), theme_color, Vector2i(192, 192))
	var character_name = "未选择" if character.is_empty() else String(character.get("name", ""))
	label.text = "%s P%d\n%s" % [prefix, player_id + 1, character_name]


func _play_new_presentation_events(self_id: int, enemy_id: int) -> void:
	var events: Array = battle.presentation_events
	if _last_presentation_event_count > events.size():
		_last_presentation_event_count = events.size()
	for index in range(_last_presentation_event_count, events.size()):
		var event: Dictionary = events[index]
		var animation_name = _animation_for_presentation_event(event)
		if animation_name.is_empty():
			continue
		var actor_id = int(event.get("player_id", -1))
		var portrait = _portrait_for_player(actor_id, self_id, enemy_id)
		if portrait != null and portrait.has_method("play_character_animation"):
			portrait.play_character_animation(animation_name, "battle_idle")
	_last_presentation_event_count = events.size()


func _animation_for_presentation_event(event: Dictionary) -> String:
	var skill_id = String(event.get("skill_id", ""))
	if skill_id == "archer_backstep":
		return "backstep"
	if String(event.get("skill_type", "")) == "attack":
		return "attack"
	return ""


func _portrait_for_player(player_id: int, self_id: int, enemy_id: int):
	if player_id == self_id:
		return self_character_portrait
	if player_id == enemy_id:
		return enemy_character_portrait
	return null


func _render_dice_area(self_id: int, animate: bool) -> void:
	for child in dice_slot.get_children():
		child.queue_free()
	if network_controller.mode == network_controller.MODE_LOCAL:
		_add_dice_row(0, animate)
		_add_dice_row(1, animate)
	else:
		_add_dice_row(self_id, animate)


func _add_dice_row(player_id: int, animate: bool) -> void:
	var player: Dictionary = battle.players[player_id]
	var row_panel = PanelContainer.new()
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.add_theme_stylebox_override("panel", UIAssetsScript.panel_style(Color(0.72, 0.72, 0.70, 0.75), Color(0.30, 0.30, 0.30), 4))
	dice_slot.add_child(row_panel)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	row_panel.add_child(margin)
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var label = Label.new()
	label.custom_minimum_size = Vector2(56, 0)
	label.text = "P%d" % [player_id + 1]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	row.add_child(label)
	var dice_view = DiceViewScene.instantiate()
	dice_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dice_view)
	dice_view.set_dice(player.get("dice", []), animate)


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
	if battle.get_poison_cleanse_cost(player_id) > 0:
		var cleanse = Button.new()
		cleanse.text = "净化 %d MP" % battle.get_poison_cleanse_cost(player_id)
		cleanse.disabled = player.mp < battle.get_poison_cleanse_cost(player_id)
		cleanse.pressed.connect(func():
			player_command.emit(player_id, {"type": "cleanse_poison"})
		)
		tools.add_child(cleanse)


func _add_skill_buttons(parent: GridContainer, player_id: int, skill: Dictionary) -> void:
	var modes: Array = skill.get("modes", [])
	if modes.is_empty():
		_add_skill_button(parent, player_id, skill, [])
		return
	if not bool(skill.get("hide_base_button", false)):
		_add_skill_button(parent, player_id, skill, [])
	for mode in modes:
		_add_skill_button(parent, player_id, skill, [String(mode.get("id", ""))])


func _add_skill_button(parent: GridContainer, player_id: int, skill: Dictionary, modes: Array) -> void:
	var character: Dictionary = battle.players[player_id].character
	var theme_color = UIAssetsScript.color_from_hex(String(character.get("theme_color", "")))
	var button = SkillButtonScene.instantiate()
	var reason = battle.get_skill_block_reason(player_id, skill, modes)
	button.configure(skill, modes, battle.get_skill_cost(player_id, skill, modes), reason, theme_color)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
