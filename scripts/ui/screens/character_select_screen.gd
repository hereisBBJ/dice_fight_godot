extends Control
class_name CharacterSelectScreen

signal player_command(player_id: int, command: Dictionary)
signal back_requested

const UIAssetsScript = preload("res://scripts/ui/components/ui_assets.gd")

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
	title.text = "P%d 角色%s" % [player_id + 1, "" if String(player.get("character_id", "")).is_empty() else "：%s" % String(player.character.name)]
	for child in options.get_children():
		child.queue_free()
	var character_ids = battle.characters.keys()
	character_ids.sort()
	for character_id in character_ids:
		var character: Dictionary = battle.characters[character_id]
		var button = Button.new()
		button.custom_minimum_size = Vector2(0, 108)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s\nHP %d / MP %d / 护盾 %d\n%s：%s" % [
			String(character.get("name", character_id)),
			int(character.get("max_hp", 0)),
			int(character.get("max_mp", 0)),
			int(character.get("max_shield", 0)),
			String(character.get("passive", {}).get("name", "被动")),
			String(character.get("passive", {}).get("description", ""))
		]
		button.icon = UIAssetsScript.texture_from_path(String(character.get("portrait_path", "")), UIAssetsScript.color_from_hex(String(character.get("theme_color", ""))), Vector2i(64, 64))
		button.expand_icon = true
		button.disabled = not network_controller.can_control_player(player_id) or String(player.get("character_id", "")) == String(character_id)
		var selected_id = String(character_id)
		button.pressed.connect(func():
			player_command.emit(player_id, {
				"type": "select_character",
				"character_id": selected_id
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
