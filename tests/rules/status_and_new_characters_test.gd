extends SceneTree

const BattleStateScript = preload("res://scripts/rules/battle_state.gd")

var failures: Array = []


func _init() -> void:
	_run()
	if failures.is_empty():
		print("STATUS_AND_NEW_CHARACTERS_TEST_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(str(failure))
		quit(1)


func _run() -> void:
	_test_new_character_data_loads()
	_test_poison_ticks_at_round_start()
	_test_life_drain_heals_actual_life_damage()
	_test_burn_layers_clear_at_round_start()
	_test_fire_shield_reflects_burn_on_break()
	_test_pyromancer_rebirth_prevents_first_death()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _make_battle(p1_character: String, p2_character: String):
	var battle = BattleStateScript.new()
	battle.setup()
	_expect(battle.select_character(0, p1_character), "P1 should select %s" % p1_character)
	_expect(battle.select_character(1, p2_character), "P2 should select %s" % p2_character)
	_auto_pick_augments(battle, 0)
	_auto_pick_augments(battle, 1)
	_expect(battle.phase == BattleStateScript.PHASE_BATTLE, "battle should start")
	return battle


func _auto_pick_augments(battle, player_id: int) -> void:
	var common = battle.augment_candidates[player_id].get("common", [])
	var character = battle.augment_candidates[player_id].get("character", [])
	if not common.is_empty():
		battle.pick_augment(player_id, String(common[0].id))
	if not character.is_empty():
		battle.pick_augment(player_id, String(character[0].id))


func _test_new_character_data_loads() -> void:
	var battle = BattleStateScript.new()
	battle.setup()
	_expect(battle.characters.has("witch_doctor"), "witch doctor data should load")
	_expect(battle.characters.has("pyromancer"), "pyromancer data should load")
	_expect(battle.character_augments.has("witch_doctor"), "witch doctor augments should load")
	_expect(battle.character_augments.has("pyromancer"), "pyromancer augments should load")


func _test_poison_ticks_at_round_start() -> void:
	var battle = _make_battle("witch_doctor", "swordsman")
	battle.attacker_id = 0
	battle.players[0].dice = [6, 5, 4, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	var hp_before = int(battle.players[1].hp)
	_expect(battle.submit_skip(1), "defender should skip")
	_expect(battle.submit_skill(0, "witch_poison_bottle"), "witch doctor should use poison bottle")
	_expect(int(battle.players[1].hp) <= hp_before - 20, "poison bottle should deal hit damage and a poison tick by next round start")


func _test_life_drain_heals_actual_life_damage() -> void:
	var battle = _make_battle("witch_doctor", "swordsman")
	battle.attacker_id = 0
	battle.players[0].hp = 40
	battle.players[0].dice = [5, 3, 2, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	_expect(battle.submit_skip(1), "defender should skip before life drain")
	_expect(battle.submit_skill(0, "witch_life_drain"), "witch doctor should use life drain")
	_expect(int(battle.players[0].hp) > 40, "life drain should heal when life damage is dealt")


func _test_burn_layers_clear_at_round_start() -> void:
	var battle = _make_battle("pyromancer", "swordsman")
	battle._add_burn(0, 1, 2)
	_expect(_has_status(battle, 1, "burn"), "burn should be applied")
	battle._resolve_round_start_statuses()
	_expect(not _has_status(battle, 1, "burn"), "burn should clear after round start settlement")


func _test_fire_shield_reflects_burn_on_break() -> void:
	var battle = _make_battle("swordsman", "pyromancer")
	battle.players[1].shield = 5
	battle._add_status(1, "fire_shield", 1, 1, 1)
	battle._apply_damage(0, 1, 20, 10, "test_break")
	_expect(_has_status(battle, 0, "burn"), "breaking fire shield should reflect burn to attacker")


func _test_pyromancer_rebirth_prevents_first_death() -> void:
	var battle = _make_battle("swordsman", "pyromancer")
	battle._deal_direct_life_loss(0, 1, 999, "测试")
	_expect(int(battle.players[1].hp) == 10, "pyromancer should rebirth to 10 HP")
	_expect(bool(battle.players[1].per_game_flags.get("rebirth_used", false)), "rebirth flag should be set")
	battle._deal_direct_life_loss(0, 1, 999, "测试")
	_expect(int(battle.players[1].hp) <= 0, "second lethal loss should not rebirth")


func _has_status(battle, player_id: int, status_id: String) -> bool:
	for status in battle.players[player_id].statuses:
		if String(status.id) == status_id:
			return true
	return false
