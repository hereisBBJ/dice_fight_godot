extends Node
class_name NetworkController

signal state_changed
signal status_changed

const DEFAULT_PORT = 7777
const MODE_LOCAL = "local"
const MODE_HOST = "host"
const MODE_CLIENT = "client"

var mode = MODE_LOCAL
var local_player_id = -1
var status_message = "单机热座"
var battle

var _peer_to_player: Dictionary = {}
var _standalone_peer: ENetMultiplayerPeer


func bind_battle_state(new_battle) -> void:
	battle = new_battle


func start_local(new_battle = null) -> void:
	if new_battle != null:
		battle = new_battle
	_close_peer()
	mode = MODE_LOCAL
	local_player_id = -1
	status_message = "单机热座：本机控制 P1/P2"
	status_changed.emit()
	state_changed.emit()


func host(new_battle, port: int = DEFAULT_PORT) -> bool:
	battle = new_battle
	_close_peer()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, 1)
	if error != OK:
		status_message = "创建房间失败：%s" % error_string(error)
		status_changed.emit()
		return false
	var multiplayer_api = _get_multiplayer_api()
	if multiplayer_api == null:
		_standalone_peer = peer
	else:
		multiplayer_api.multiplayer_peer = peer
	mode = MODE_HOST
	local_player_id = 0
	_peer_to_player = {1: 0}
	_connect_multiplayer_signals()
	status_message = "已创建 LAN 房间，端口 %d。本机为 P1，等待 P2 加入。" % port
	status_changed.emit()
	state_changed.emit()
	return true


func join(new_battle, address: String, port: int = DEFAULT_PORT) -> bool:
	battle = new_battle
	_close_peer()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	if error != OK:
		status_message = "加入房间失败：%s" % error_string(error)
		status_changed.emit()
		return false
	var multiplayer_api = _get_multiplayer_api()
	if multiplayer_api == null:
		_standalone_peer = peer
	else:
		multiplayer_api.multiplayer_peer = peer
	mode = MODE_CLIENT
	local_player_id = -1
	_connect_multiplayer_signals()
	status_message = "正在连接 %s:%d ..." % [address, port]
	status_changed.emit()
	state_changed.emit()
	return true


func stop_network() -> void:
	start_local(battle)


func can_control_player(player_id: int) -> bool:
	if mode == MODE_LOCAL:
		return true
	return player_id == local_player_id


func can_control_any() -> bool:
	return mode == MODE_LOCAL or local_player_id >= 0


func submit_command(player_id: int, command: Dictionary) -> bool:
	if not can_control_player(player_id):
		return false
	if mode == MODE_LOCAL:
		_execute_command(player_id, command)
		state_changed.emit()
		return true
	if mode == MODE_HOST:
		var ok = _execute_command(player_id, command)
		_broadcast_snapshot()
		return ok
	if mode == MODE_CLIENT:
		server_submit_command.rpc_id(1, command)
		return true
	return false


func submit_global_command(command: Dictionary) -> bool:
	if mode == MODE_LOCAL:
		_execute_global_command(command)
		state_changed.emit()
		return true
	if mode == MODE_HOST:
		var ok = _execute_global_command(command)
		_broadcast_snapshot()
		return ok
	if mode == MODE_CLIENT:
		server_submit_command.rpc_id(1, command)
		return true
	return false


func _execute_global_command(command: Dictionary) -> bool:
	if command.get("type", "") == "restart_request":
		battle.restart_match()
		return true
	if command.get("type", "") == "reset_to_character_select":
		battle.reset_to_character_select()
		return true
	return false


func _execute_command(player_id: int, command: Dictionary) -> bool:
	var command_type = String(command.get("type", ""))
	match command_type:
		"select_character":
			return battle.select_character(player_id, String(command.get("character_id", "")))
		"pick_augment":
			return battle.pick_augment(player_id, String(command.get("augment_id", "")))
		"reroll_dice":
			return battle.reroll_dice(player_id)
		"modify_die":
			return battle.modify_die(player_id, int(command.get("die_index", -1)), int(command.get("value", 1)))
		"use_skill":
			return battle.submit_skill(player_id, String(command.get("skill_id", "")), command.get("modes", []))
		"skip_turn":
			return battle.submit_skip(player_id)
		"cleanse_poison":
			return battle.submit_cleanse(player_id)
		"interactive_accept":
			if _interactive_belongs_to(player_id):
				return battle.interactive_accept()
		"interactive_reroll":
			if _interactive_belongs_to(player_id):
				return battle.interactive_reroll()
		"interactive_modify":
			if _interactive_belongs_to(player_id):
				return battle.interactive_modify(int(command.get("value", 1)))
		"interactive_select_skill":
			if _interactive_belongs_to(player_id):
				return battle.interactive_select_skill(String(command.get("skill_id", "")))
		"restart_request", "reset_to_character_select":
			return _execute_global_command(command)
	return false


func _interactive_belongs_to(player_id: int) -> bool:
	if battle.pending_interactive_request.is_empty():
		return false
	return int(battle.pending_interactive_request.get("responder_id", -1)) == player_id


func _connect_multiplayer_signals() -> void:
	var multiplayer_api = _get_multiplayer_api()
	if multiplayer_api == null:
		return
	if not multiplayer_api.peer_connected.is_connected(_on_peer_connected):
		multiplayer_api.peer_connected.connect(_on_peer_connected)
	if not multiplayer_api.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer_api.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer_api.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer_api.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer_api.connection_failed.is_connected(_on_connection_failed):
		multiplayer_api.connection_failed.connect(_on_connection_failed)
	if not multiplayer_api.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer_api.server_disconnected.connect(_on_server_disconnected)


func _close_peer() -> void:
	var multiplayer_api = _get_multiplayer_api()
	if multiplayer_api != null and multiplayer_api.multiplayer_peer != null:
		multiplayer_api.multiplayer_peer.close()
		multiplayer_api.multiplayer_peer = null
	if _standalone_peer != null:
		_standalone_peer.close()
		_standalone_peer = null
	_peer_to_player = {}


func _get_multiplayer_api():
	if multiplayer != null:
		return multiplayer
	if not is_inside_tree():
		return null
	var tree = get_tree()
	if tree == null:
		return null
	return tree.get_multiplayer()


func _on_peer_connected(peer_id: int) -> void:
	if mode != MODE_HOST:
		return
	if _peer_to_player.has(peer_id):
		return
	if _peer_to_player.size() >= 2:
		var multiplayer_api = _get_multiplayer_api()
		if multiplayer_api != null and multiplayer_api.multiplayer_peer != null:
			multiplayer_api.multiplayer_peer.disconnect_peer(peer_id)
		return
	_peer_to_player[peer_id] = 1
	status_message = "P2 已加入。主机为 P1，客户端为 P2。"
	battle.append_log("P2 加入了 LAN 房间。")
	client_receive_assignment.rpc_id(peer_id, 1)
	client_receive_snapshot.rpc_id(peer_id, _snapshot_for_player(1))
	_broadcast_snapshot()
	status_changed.emit()


func _on_peer_disconnected(peer_id: int) -> void:
	if mode == MODE_HOST:
		var player_id = int(_peer_to_player.get(peer_id, -1))
		_peer_to_player.erase(peer_id)
		status_message = "P%d 已断开连接。" % [player_id + 1]
		battle.append_log(status_message)
		_broadcast_snapshot()
		status_changed.emit()


func _on_connected_to_server() -> void:
	status_message = "已连接主机，等待玩家编号和状态同步。"
	status_changed.emit()


func _on_connection_failed() -> void:
	status_message = "连接失败，请检查 IP、端口和防火墙。"
	local_player_id = -1
	status_changed.emit()
	state_changed.emit()


func _on_server_disconnected() -> void:
	status_message = "主机已断开。"
	local_player_id = -1
	status_changed.emit()
	state_changed.emit()


func _broadcast_snapshot() -> void:
	if mode != MODE_HOST:
		return
	for peer_id in _peer_to_player.keys():
		if int(peer_id) != 1:
			var player_id = int(_peer_to_player.get(peer_id, -1))
			client_receive_snapshot.rpc_id(int(peer_id), _snapshot_for_player(player_id))
	state_changed.emit()


func _snapshot_for_player(player_id: int) -> Dictionary:
	var snapshot: Dictionary = battle.to_snapshot()
	if player_id < 0:
		return snapshot
	var hidden_player_id = 1 - player_id
	if hidden_player_id >= 0 and hidden_player_id < snapshot.players.size():
		var hidden_player: Dictionary = snapshot.players[hidden_player_id]
		hidden_player.dice = []
		hidden_player.submitted_action = {}
		snapshot.players[hidden_player_id] = hidden_player
	if hidden_player_id >= 0 and hidden_player_id < snapshot.pending_actions.size():
		snapshot.pending_actions[hidden_player_id] = {}
	if not snapshot.pending_interactive_request.is_empty() and int(snapshot.pending_interactive_request.get("responder_id", -1)) != player_id:
		snapshot.pending_interactive_request = {}
	snapshot.logs = _redacted_logs_for_player(snapshot.logs, hidden_player_id)
	return snapshot


func _redacted_logs_for_player(logs: Array, hidden_player_id: int) -> Array:
	var filtered = []
	for entry in logs:
		var text = String(entry)
		if _is_private_log_for_player(text, hidden_player_id):
			continue
		filtered.append(text)
	return filtered


func _is_private_log_for_player(text: String, player_id: int) -> bool:
	if player_id < 0:
		return false
	var prefix = "P%d " % [player_id + 1]
	return text.begins_with("%s提交技能" % prefix) \
		or text.begins_with("%s选择跳过回合" % prefix) \
		or text.begins_with("%s重掷骰子" % prefix) \
		or text.begins_with("%s修改 1 颗骰子" % prefix) \
		or text.begins_with("%s重掷判定骰" % prefix) \
		or text.begins_with("%s修改判定骰" % prefix)


@rpc("any_peer", "reliable")
func server_submit_command(command: Dictionary) -> void:
	var multiplayer_api = _get_multiplayer_api()
	if mode != MODE_HOST or multiplayer_api == null or not multiplayer_api.is_server():
		return
	var sender = multiplayer_api.get_remote_sender_id()
	var player_id = int(_peer_to_player.get(sender, -1))
	if player_id < 0:
		return
	_execute_command(player_id, command)
	_broadcast_snapshot()


@rpc("authority", "reliable")
func client_receive_assignment(player_id: int) -> void:
	if mode != MODE_CLIENT:
		return
	local_player_id = player_id
	status_message = "已加入房间：你是 P%d。" % [local_player_id + 1]
	status_changed.emit()
	state_changed.emit()


@rpc("authority", "reliable")
func client_receive_snapshot(snapshot: Dictionary) -> void:
	if mode != MODE_CLIENT:
		return
	battle.apply_snapshot(snapshot)
	state_changed.emit()
