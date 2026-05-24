extends PanelContainer
class_name InteractiveDialog

signal interactive_command(player_id: int, command: Dictionary)

@onready var title_label: Label = $Margin/Column/Title
@onready var description_label: Label = $Margin/Column/Description
@onready var actions_row: HBoxContainer = $Margin/Column/Actions
@onready var accept_button: Button = $Margin/Column/Actions/Accept
@onready var reroll_button: Button = $Margin/Column/Actions/Reroll
@onready var value_spin: SpinBox = $Margin/Column/Actions/ValueSpin
@onready var modify_button: Button = $Margin/Column/Actions/Modify

var battle
var network_controller
var responder_id = -1


func _ready() -> void:
	accept_button.pressed.connect(_on_accept_pressed)
	reroll_button.pressed.connect(_on_reroll_pressed)
	modify_button.pressed.connect(_on_modify_pressed)


func setup(new_battle, new_network_controller) -> void:
	battle = new_battle
	network_controller = new_network_controller
	_clear_dynamic_buttons()
	if battle.pending_interactive_request.is_empty():
		visible = false
		return
	visible = true
	var request: Dictionary = battle.pending_interactive_request
	responder_id = int(request.get("responder_id", -1))
	var kind = String(request.get("kind", ""))
	var can_control = network_controller.can_control_player(responder_id)
	if kind == "skill_disable_select":
		_setup_skill_disable_select(request, can_control)
		return
	if kind == "effect_choice":
		_setup_effect_choice(request, can_control)
		return
	var title = "射击闪避判定" if kind == "shot_evasion" else "后跳判定"
	var die = int(request.get("die", 1))
	title_label.text = "%s：P%d 掷出 %d" % [title, responder_id + 1, die]
	description_label.text = "可接受当前结果，或支付 MP 重掷/修改判定骰。"
	value_spin.value = clamp(die, 1, 6)
	var reroll_cost = battle.get_reroll_cost(responder_id)
	var modify_cost = battle.get_modify_cost(responder_id)
	accept_button.disabled = not can_control
	reroll_button.text = "重掷（%d MP）" % reroll_cost
	reroll_button.disabled = not can_control or battle.players[responder_id].mp < reroll_cost
	modify_button.text = "修改（%d MP）" % modify_cost
	modify_button.disabled = not can_control or battle.players[responder_id].mp < modify_cost or bool(battle.players[responder_id].has_modified_this_turn)
	accept_button.visible = true
	reroll_button.visible = true
	value_spin.visible = true
	modify_button.visible = true


func _on_accept_pressed() -> void:
	interactive_command.emit(responder_id, {"type": "interactive_accept"})


func _on_reroll_pressed() -> void:
	interactive_command.emit(responder_id, {"type": "interactive_reroll"})


func _on_modify_pressed() -> void:
	interactive_command.emit(responder_id, {
		"type": "interactive_modify",
		"value": int(value_spin.value)
	})


func _setup_skill_disable_select(request: Dictionary, can_control: bool) -> void:
	title_label.text = "缚魂选技"
	var target_id = int(request.get("target_id", -1))
	description_label.text = "为 P%d 选择本回合不可用的技能。" % [target_id + 1]
	accept_button.visible = false
	reroll_button.visible = false
	value_spin.visible = false
	modify_button.visible = false
	for skill_id in request.get("candidate_skill_ids", []):
		var button = Button.new()
		button.text = String(battle.get_skill(target_id, String(skill_id)).get("name", skill_id))
		button.disabled = not can_control
		button.pressed.connect(func(selected_skill_id := String(skill_id)):
			interactive_command.emit(responder_id, {
				"type": "interactive_select_skill",
				"skill_id": selected_skill_id
			})
		)
		actions_row.add_child(button)


func _setup_effect_choice(request: Dictionary, can_control: bool) -> void:
	title_label.text = String(request.get("title", "效果选择"))
	description_label.text = String(request.get("description", "请选择一项效果。"))
	accept_button.visible = false
	reroll_button.visible = false
	value_spin.visible = false
	modify_button.visible = false
	for option in request.get("options", []):
		var button = Button.new()
		button.text = String(option.get("label", option.get("id", "选项")))
		button.tooltip_text = String(option.get("description", ""))
		button.disabled = not can_control
		button.pressed.connect(func(selected_option_id := String(option.get("id", ""))):
			interactive_command.emit(responder_id, {
				"type": "interactive_select_option",
				"option_id": selected_option_id
			})
		)
		actions_row.add_child(button)


func _clear_dynamic_buttons() -> void:
	for child in actions_row.get_children():
		if child in [accept_button, reroll_button, value_spin, modify_button]:
			continue
		child.queue_free()
