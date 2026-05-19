extends PanelContainer
class_name InteractiveDialog

signal interactive_command(player_id: int, command: Dictionary)

@onready var title_label: Label = $Margin/Column/Title
@onready var description_label: Label = $Margin/Column/Description
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
	if battle.pending_interactive_request.is_empty():
		visible = false
		return
	visible = true
	var request: Dictionary = battle.pending_interactive_request
	responder_id = int(request.get("responder_id", -1))
	var kind = String(request.get("kind", ""))
	var title = "射击闪避判定" if kind == "shot_evasion" else "后跳判定"
	var die = int(request.get("die", 1))
	title_label.text = "%s：P%d 掷出 %d" % [title, responder_id + 1, die]
	description_label.text = "可接受当前结果，或支付 MP 重掷/修改判定骰。"
	value_spin.value = clamp(die, 1, 6)
	var can_control = network_controller.can_control_player(responder_id)
	var reroll_cost = battle.get_reroll_cost(responder_id)
	var modify_cost = battle.get_modify_cost(responder_id)
	accept_button.disabled = not can_control
	reroll_button.text = "重掷（%d MP）" % reroll_cost
	reroll_button.disabled = not can_control or battle.players[responder_id].mp < reroll_cost
	modify_button.text = "修改（%d MP）" % modify_cost
	modify_button.disabled = not can_control or battle.players[responder_id].mp < modify_cost or bool(battle.players[responder_id].has_modified_this_turn)


func _on_accept_pressed() -> void:
	interactive_command.emit(responder_id, {"type": "interactive_accept"})


func _on_reroll_pressed() -> void:
	interactive_command.emit(responder_id, {"type": "interactive_reroll"})


func _on_modify_pressed() -> void:
	interactive_command.emit(responder_id, {
		"type": "interactive_modify",
		"value": int(value_spin.value)
	})
