extends Control
class_name GameOverScreen

signal global_command(command: Dictionary)
signal back_requested

@onready var result_label: Label = $Scroll/Margin/Column/Result
@onready var back_button: Button = $Scroll/Margin/Column/BackButton
@onready var p1_panel = $Scroll/Margin/Column/PlayerRow/P1Panel
@onready var p2_panel = $Scroll/Margin/Column/PlayerRow/P2Panel
@onready var rematch_button: Button = $Scroll/Margin/Column/Buttons/Rematch
@onready var reset_button: Button = $Scroll/Margin/Column/Buttons/Reset
@onready var log_view = $Scroll/Margin/Column/LogView

var battle
var network_controller


func _ready() -> void:
	back_button.pressed.connect(func():
		back_requested.emit()
	)
	rematch_button.pressed.connect(_on_rematch_pressed)
	reset_button.pressed.connect(_on_reset_pressed)


func setup(new_battle, new_network_controller) -> void:
	battle = new_battle
	network_controller = new_network_controller
	var result = "平局"
	if battle.winner_id >= 0:
		result = "P%d 获胜" % [battle.winner_id + 1]
	result_label.text = "对局结束：%s" % result
	p1_panel.set_player(0, battle, false)
	p2_panel.set_player(1, battle, false)
	rematch_button.disabled = not network_controller.can_control_any()
	reset_button.disabled = network_controller.mode == network_controller.MODE_CLIENT
	log_view.set_logs(battle.logs)


func _on_rematch_pressed() -> void:
	global_command.emit({"type": "restart_request"})


func _on_reset_pressed() -> void:
	global_command.emit({"type": "reset_to_character_select"})
