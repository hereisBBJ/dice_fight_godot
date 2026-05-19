extends SceneTree

const BattleStateScript = preload("res://scripts/rules/battle_state.gd")
const NetworkControllerScript = preload("res://scripts/network/network_controller.gd")

var failures: Array = []


func _init() -> void:
	var battle = BattleStateScript.new()
	battle.setup()
	var network = NetworkControllerScript.new()
	root.add_child(network)
	network.bind_battle_state(battle)

	_expect(network.host(battle, 17877), "network host should start on test port")
	_expect(network.mode == NetworkControllerScript.MODE_HOST, "mode should be host")
	_expect(network.local_player_id == 0, "host should control P1")

	network.stop_network()
	_expect(network.mode == NetworkControllerScript.MODE_LOCAL, "stop_network should return to local mode")

	_prepare_battle_for_redaction(battle)
	battle.append_log("P1 提交技能：斩击。")
	battle.append_log("P2 提交技能：射击。")
	battle.players[0].submitted_action = {"type": "skill", "skill_id": "swordsman_slash"}
	battle.players[1].submitted_action = {"type": "skill", "skill_id": "archer_shot"}
	var p2_snapshot = network._snapshot_for_player(1)
	_expect(p2_snapshot.players[0].dice.is_empty(), "p2 snapshot should hide p1 dice")
	_expect(p2_snapshot.players[0].submitted_action.is_empty(), "p2 snapshot should hide p1 submitted action")
	_expect(not _logs_contain(p2_snapshot.logs, "P1 提交技能"), "p2 snapshot should hide p1 submitted skill log")
	_expect(_logs_contain(p2_snapshot.logs, "P2 提交技能"), "p2 snapshot should keep own submitted skill log")

	if failures.is_empty():
		print("NETWORK_CONTROLLER_SMOKE_TEST_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(str(failure))
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _prepare_battle_for_redaction(battle) -> void:
	battle.reset_to_character_select()
	battle.select_character(0, "swordsman")
	battle.select_character(1, "archer")
	for player_id in range(2):
		for _index in range(2):
			var kind = battle.get_next_augment_kind(player_id)
			if kind == "done":
				continue
			var candidates: Array = battle.augment_candidates[player_id].get(kind, [])
			if not candidates.is_empty():
				battle.pick_augment(player_id, String(candidates[0].id))


func _logs_contain(logs: Array, pattern: String) -> bool:
	for entry in logs:
		if String(entry).contains(pattern):
			return true
	return false
