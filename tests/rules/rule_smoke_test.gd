extends SceneTree

const BattleStateScript = preload("res://scripts/rules/battle_state.gd")
const DiceRulesScript = preload("res://scripts/rules/dice_rules.gd")

var failures: Array = []


func _init() -> void:
	_run()
	if failures.is_empty():
		print("RULE_SMOKE_TEST_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(str(failure))
		quit(1)


func _run() -> void:
	_test_dice_requirements()
	_test_battle_flow_and_damage()
	_test_archer_interactive()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _make_battle() -> RefCounted:
	var battle = BattleStateScript.new()
	battle.setup()
	_expect(battle.select_character(0, "swordsman"), "P1 should select swordsman")
	_expect(battle.select_character(1, "archer"), "P2 should select archer")
	_auto_pick_augments(battle, 0)
	_auto_pick_augments(battle, 1)
	_expect(battle.phase == BattleStateScript.PHASE_BATTLE, "battle should start after augments")
	return battle


func _auto_pick_augments(battle, player_id: int) -> void:
	var common = battle.augment_candidates[player_id].get("common", [])
	var character = battle.augment_candidates[player_id].get("character", [])
	if not common.is_empty():
		battle.pick_augment(player_id, String(common[0].id))
	if not character.is_empty():
		battle.pick_augment(player_id, String(character[0].id))


func _test_dice_requirements() -> void:
	_expect(DiceRulesScript.requirements_met([6, 4, 2, 1], [6, "4-6"]), "6 + 4-6 should match different dice")
	_expect(not DiceRulesScript.requirements_met([6, 3, 2, 1], [6, "4-6"]), "same die cannot satisfy two requirements")
	_expect(DiceRulesScript.requirements_met([5, 4, 2, 1], ["odd", "even"]), "odd + even should match")
	_expect(DiceRulesScript.requirements_met([6, 6, 3, 1], [6, 6, "1-3"]), "archer piercing requirement should match")


func _test_battle_flow_and_damage() -> void:
	var battle = _make_battle()
	battle.attacker_id = 0
	battle.players[0].dice = [3, 3, 1, 1]
	battle.players[1].dice = [6, 3, 3, 1]
	var hp_before = int(battle.players[1].hp)
	_expect(battle.submit_skill(1, "archer_backstep", ["empowered"]), "defender should submit empowered backstep")
	_expect(battle.submit_skill(0, "swordsman_slash"), "attacker should submit slash")
	_expect(battle.phase == BattleStateScript.PHASE_BATTLE or battle.phase == BattleStateScript.PHASE_GAME_OVER, "turn should resolve")
	_expect(int(battle.players[1].hp) == hp_before, "sure evasion should prevent slash damage")

	battle.players[0].shield = 15
	battle.players[0].dice = [6, 3, 2, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	hp_before = int(battle.players[1].hp)
	_expect(battle.submit_skip(1), "defender should skip")
	_expect(battle.submit_skill(0, "swordsman_shield_bash"), "swordsman should submit shield bash")
	_expect(int(battle.players[1].hp) < hp_before, "shield bash should cause life damage when no shield blocks it")


func _test_archer_interactive() -> void:
	var battle = _make_battle()
	battle.attacker_id = 1
	battle.players[1].dice = [3, 3, 1, 1]
	battle.players[0].dice = [1, 1, 1, 1]
	var hp_before = int(battle.players[0].hp)
	_expect(battle.submit_skip(0), "swordsman defender should skip")
	_expect(battle.submit_skill(1, "archer_shot"), "archer should submit shot")
	_expect(battle.phase == BattleStateScript.PHASE_INTERACTIVE, "archer shot should ask for evasion")
	battle.pending_interactive_request.die = 1
	battle.interactive_accept()
	_expect(int(battle.players[0].hp) < hp_before, "failed evasion should allow shot damage")
