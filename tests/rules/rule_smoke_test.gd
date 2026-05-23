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
	_test_shield_break_damage_rules()
	_test_swordsman_guard_rules()


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
	battle.first_player_id = 1
	battle.players[0].dice = [3, 3, 1, 1]
	battle.players[1].dice = [6, 3, 3, 1]
	var hp_before = int(battle.players[1].hp)
	_expect(battle.submit_skill(1, "archer_backstep", ["empowered"]), "first player should submit empowered backstep")
	_expect(battle.submit_skill(0, "swordsman_slash"), "second player should submit slash")
	_expect(battle.phase == BattleStateScript.PHASE_BATTLE or battle.phase == BattleStateScript.PHASE_GAME_OVER, "turn should resolve")
	_expect(int(battle.players[1].hp) == hp_before, "sure evasion should prevent slash damage")

	battle = _make_battle()
	battle.first_player_id = 0
	battle.players[0].dice = [3, 3, 1, 1]
	battle.players[1].dice = [6, 3, 3, 1]
	var target_hp_before = int(battle.players[1].hp)
	_expect(battle.submit_skill(1, "archer_backstep", ["empowered"]), "second player should still be able to queue backstep")
	_expect(battle.submit_skill(0, "swordsman_slash"), "first player should still submit slash")
	_expect(int(battle.players[1].hp) < target_hp_before, "first player action should resolve before second player backstep")

	battle.players[0].shield = 15
	battle.players[0].dice = [6, 3, 2, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	hp_before = int(battle.players[1].hp)
	_expect(battle.submit_skip(1), "second player should skip")
	_expect(battle.submit_skill(0, "swordsman_shield_bash"), "swordsman should submit shield bash")
	_expect(int(battle.players[1].hp) < hp_before, "shield bash should cause life damage when no shield blocks it")


func _test_archer_interactive() -> void:
	var battle = _make_battle()
	battle.first_player_id = 1
	battle.players[1].dice = [3, 3, 1, 1]
	battle.players[0].dice = [1, 1, 1, 1]
	var hp_before = int(battle.players[0].hp)
	_expect(battle.submit_skip(0), "swordsman should skip")
	_expect(battle.submit_skill(1, "archer_shot"), "archer should submit shot")
	_expect(battle.phase == BattleStateScript.PHASE_INTERACTIVE, "archer shot should ask for evasion")
	battle.pending_interactive_request.die = 1
	battle._interactive_context.die = 1
	battle.interactive_accept()
	_expect(int(battle.players[0].hp) < hp_before, "failed evasion should allow shot damage")


func _test_shield_break_damage_rules() -> void:
	var battle = _make_battle()
	battle.players[1].shield = 9
	var hp_before = int(battle.players[1].hp)
	battle._apply_damage(0, 1, 4, 0, "shield_small_hit")
	_expect(int(battle.players[1].shield) == 5, "damage not above half shield should only reduce shield")
	_expect(int(battle.players[1].hp) == hp_before, "damage not above half shield should not deal hp damage")

	battle = _make_battle()
	battle.players[1].shield = 9
	hp_before = int(battle.players[1].hp)
	battle._apply_damage(0, 1, 7, 0, "shield_break_no_hp")
	_expect(int(battle.players[1].shield) == 0, "damage above half shield should break shield")
	_expect(int(battle.players[1].hp) == hp_before, "damage not above shield should not deal hp damage after breaking shield")

	battle = _make_battle()
	battle.players[1].shield = 9
	hp_before = int(battle.players[1].hp)
	battle._apply_damage(0, 1, 12, 0, "shield_break_with_hp")
	_expect(int(battle.players[1].shield) == 0, "overflow damage should clear shield")
	_expect(int(battle.players[1].hp) == hp_before - 2, "overflow damage should deal ceil(overflow/2) hp damage")


func _test_swordsman_guard_rules() -> void:
	var battle = _make_battle()
	battle.first_player_id = 0
	battle.players[0].shield = 0
	battle.players[0].augments = []
	battle.players[0].augment_ids = []
	battle._try_sword_spirit(0, 20)
	_expect(int(battle.players[0].shield) == 5, "sword spirit should grant 5 shield")

	battle = _make_battle()
	battle._add_status(1, "guard", 1, 5)
	var hp_before = int(battle.players[1].hp)
	battle._apply_damage(0, 1, 9, 0, "guard_first_hit")
	battle._apply_damage(0, 1, 9, 0, "guard_second_hit")
	_expect(int(battle.players[1].hp) == hp_before - 8, "guard should reduce each hit in the same round by 5")
	_expect(battle._has_status(1, "guard"), "guard should persist until round end for multi-hit damage")

	battle = BattleStateScript.new()
	battle.setup()
	_expect(battle.select_character(0, "swordsman"), "P1 should select swordsman for guard timing test")
	_expect(battle.select_character(1, "swordsman"), "P2 should select swordsman for guard timing test")
	_auto_pick_augments(battle, 0)
	_auto_pick_augments(battle, 1)
	battle.first_player_id = 0
	battle.players[0].dice = [3, 3, 1, 1]
	battle.players[1].dice = [3, 3, 1, 1]
	var second_hp_before = int(battle.players[1].hp)
	_expect(battle.submit_skill(1, "swordsman_block"), "second player should be able to queue block")
	_expect(battle.submit_skill(0, "swordsman_slash"), "first player should submit slash")
	_expect(int(battle.players[1].hp) < second_hp_before, "late block should not reduce earlier first-player damage")
