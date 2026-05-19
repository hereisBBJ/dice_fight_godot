extends Control

const BattleStateScript = preload("res://scripts/rules/battle_state.gd")
const NetworkControllerScript = preload("res://scripts/network/network_controller.gd")

const MenuScreenScene = preload("res://scenes/ui/screens/menu_screen.tscn")
const CharacterSelectScreenScene = preload("res://scenes/ui/screens/character_select_screen.tscn")
const AugmentSelectScreenScene = preload("res://scenes/ui/screens/augment_select_screen.tscn")
const BattleScreenScene = preload("res://scenes/ui/screens/battle_screen.tscn")
const GameOverScreenScene = preload("res://scenes/ui/screens/game_over_screen.tscn")

var battle
var network_controller
var app_screen = "menu"
var default_join_ip = "127.0.0.1"

var _current_screen: Control
var _current_screen_key = ""
var _audio_feedback: AudioFeedback


func _ready() -> void:
	battle = BattleStateScript.new()
	battle.setup()
	_audio_feedback = $AudioFeedback
	network_controller = NetworkControllerScript.new()
	network_controller.name = "NetworkController"
	add_child(network_controller)
	network_controller.bind_battle_state(battle)
	network_controller.state_changed.connect(_render)
	network_controller.status_changed.connect(_render)
	_render()


func _render() -> void:
	var screen_key = _screen_key()
	if _current_screen == null or _current_screen_key != screen_key:
		_replace_screen(screen_key)
	_configure_current_screen()


func _screen_key() -> String:
	if app_screen == "menu":
		return "menu"
	match battle.phase:
		BattleStateScript.PHASE_CHARACTER_SELECT:
			return "character_select"
		BattleStateScript.PHASE_AUGMENT_SELECT:
			return "augment_select"
		BattleStateScript.PHASE_GAME_OVER:
			return "game_over"
	return "battle"


func _replace_screen(screen_key: String) -> void:
	if _current_screen != null and is_instance_valid(_current_screen):
		_current_screen.queue_free()
	_current_screen_key = screen_key
	_current_screen = _instantiate_screen(screen_key)
	_current_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_current_screen)
	move_child(network_controller, 0)
	_connect_screen_signals(_current_screen)
	if screen_key == "game_over":
		_audio_feedback.play_event("win")


func _instantiate_screen(screen_key: String) -> Control:
	match screen_key:
		"menu":
			return MenuScreenScene.instantiate()
		"character_select":
			return CharacterSelectScreenScene.instantiate()
		"augment_select":
			return AugmentSelectScreenScene.instantiate()
		"game_over":
			return GameOverScreenScene.instantiate()
	return BattleScreenScene.instantiate()


func _connect_screen_signals(screen: Control) -> void:
	if screen.has_signal("start_local_requested"):
		screen.start_local_requested.connect(_on_start_local_requested)
	if screen.has_signal("host_requested"):
		screen.host_requested.connect(_on_host_requested)
	if screen.has_signal("join_requested"):
		screen.join_requested.connect(_on_join_requested)
	if screen.has_signal("player_command"):
		screen.player_command.connect(_submit_player_command)
	if screen.has_signal("global_command"):
		screen.global_command.connect(_submit_global_command)
	if screen.has_signal("back_requested"):
		screen.back_requested.connect(_return_to_menu)


func _configure_current_screen() -> void:
	match _current_screen_key:
		"menu":
			_current_screen.setup(network_controller.status_message, default_join_ip, NetworkControllerScript.DEFAULT_PORT)
		"character_select", "augment_select", "battle", "game_over":
			_current_screen.setup(battle, network_controller)


func _on_start_local_requested() -> void:
	_audio_feedback.play_event("click")
	battle.reset_to_character_select()
	network_controller.start_local(battle)
	app_screen = "game"
	_render()


func _on_host_requested() -> void:
	_audio_feedback.play_event("click")
	battle.reset_to_character_select()
	if network_controller.host(battle):
		app_screen = "game"
	_render()


func _on_join_requested(address: String) -> void:
	_audio_feedback.play_event("click")
	default_join_ip = address.strip_edges()
	if default_join_ip.is_empty():
		default_join_ip = "127.0.0.1"
	battle.reset_to_character_select()
	if network_controller.join(battle, default_join_ip):
		app_screen = "game"
	_render()


func _return_to_menu() -> void:
	_audio_feedback.play_event("click")
	network_controller.stop_network()
	battle.reset_to_character_select()
	app_screen = "menu"
	_render()


func _submit_player_command(player_id: int, command: Dictionary) -> void:
	_audio_feedback.play_event(_audio_event_for_command(command))
	network_controller.submit_command(player_id, command)
	_render()


func _submit_global_command(command: Dictionary) -> void:
	_audio_feedback.play_event("click")
	network_controller.submit_global_command(command)
	_render()


func _audio_event_for_command(command: Dictionary) -> String:
	match String(command.get("type", "")):
		"reroll_dice", "modify_die", "interactive_reroll", "interactive_modify":
			return "dice"
		"use_skill":
			return "skill"
		"interactive_accept":
			return "status"
	return "click"
