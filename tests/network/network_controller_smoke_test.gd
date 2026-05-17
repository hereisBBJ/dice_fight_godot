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
