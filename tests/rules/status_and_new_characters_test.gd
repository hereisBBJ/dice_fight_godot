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
	_test_arcanist_skip_passive_recovers_mp()
	_test_arcanist_mana_shield_uses_precast_mp()
	_test_arcanist_drain_recovers_mp_from_hp_damage()
	_test_arcanist_storm_spends_all_mp_for_damage()
	_test_arcanist_overflow_mode_spends_mp_for_bonus_damage()
	_test_arcanist_damage_augment_buffs_blast_and_storm()
	_test_arcanist_shield_augment_buffs_mana_shield()


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
	_reset_augments_to_baseline(battle, 0)
	_reset_augments_to_baseline(battle, 1)
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
	_expect(battle.characters.has("arcanist"), "arcanist data should load")
	_expect(battle.character_augments.has("witch_doctor"), "witch doctor augments should load")
	_expect(battle.character_augments.has("pyromancer"), "pyromancer augments should load")
	_expect(battle.character_augments.has("arcanist"), "arcanist augments should load")


func _test_poison_ticks_at_round_start() -> void:
	var battle = _make_battle("witch_doctor", "swordsman")
	battle.first_player_id = 0
	battle.players[0].dice = [6, 5, 4, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	var hp_before = int(battle.players[1].hp)
	_expect(battle.submit_skip(1), "second player should skip")
	_expect(battle.submit_skill(0, "witch_poison_bottle"), "witch doctor should use poison bottle")
	_expect(int(battle.players[1].hp) <= hp_before - 20, "poison bottle should deal hit damage and a poison tick by next round start")


func _test_life_drain_heals_actual_life_damage() -> void:
	var battle = _make_battle("witch_doctor", "swordsman")
	battle.first_player_id = 0
	battle.players[0].hp = 40
	battle.players[0].dice = [5, 3, 2, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	_expect(battle.submit_skip(1), "second player should skip before life drain")
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


func _test_arcanist_skip_passive_recovers_mp() -> void:
	var battle = _make_battle("arcanist", "swordsman")
	battle.players[0].mp = 50
	battle.players[0].dice = [3, 1, 1, 1]
	var before = int(battle.players[0].mp)
	battle._resolve_skip(0)
	_expect(int(battle.players[0].mp) >= before + 20, "arcanist skip passive should add at least 20 MP including base skip recovery")


func _test_arcanist_mana_shield_uses_precast_mp() -> void:
	var battle = _make_battle("arcanist", "swordsman")
	battle.players[0].mp = 60
	battle.players[0].dice = [3, 2, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	_expect(battle.submit_skip(1), "second player should skip before mana shield")
	_expect(battle.submit_skill(0, "arcanist_mana_shield"), "arcanist should cast mana shield")
	_expect(int(battle.players[0].shield) == 30, "mana shield should grant 30 shield when precast MP >= 50")


func _test_arcanist_drain_recovers_mp_from_hp_damage() -> void:
	var battle = _make_battle("arcanist", "swordsman")
	battle.first_player_id = 0
	battle.players[0].mp = 20
	battle.players[1].shield = 0
	battle.players[0].dice = [6, 5, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	_expect(battle.submit_skip(1), "second player should skip before drain")
	_expect(battle.submit_skill(0, "arcanist_drain"), "arcanist should cast drain")
	_expect(int(battle.players[0].mp) == 30, "drain should restore MP equal to actual life damage dealt")


func _test_arcanist_storm_spends_all_mp_for_damage() -> void:
	var battle = _make_battle("arcanist", "swordsman")
	battle.first_player_id = 0
	battle.players[0].mp = 60
	battle.players[0].dice = [6, 6, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	var hp_before = int(battle.players[1].hp)
	_expect(battle.submit_skip(1), "second player should skip before storm")
	_expect(battle.submit_skill(0, "arcanist_storm"), "arcanist should cast storm")
	_expect(int(battle.players[0].mp) == 0, "storm should spend all remaining MP")
	_expect(int(battle.players[1].hp) == hp_before - 40, "storm should deal base 10 plus half of spent MP")


func _test_arcanist_overflow_mode_spends_mp_for_bonus_damage() -> void:
	var battle = _make_battle("arcanist", "swordsman")
	battle.first_player_id = 0
	battle.players[0].mp = 30
	battle.players[0].dice = [3, 2, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	var hp_before = int(battle.players[1].hp)
	_expect(battle.submit_skip(1), "second player should skip before overflow blast")
	_expect(battle.submit_skill(0, "arcanist_arcane_blast", ["overflow"]), "arcanist should cast overflow blast")
	_expect(int(battle.players[0].mp) == 0, "overflow blast should spend 30 MP")
	_expect(int(battle.players[1].hp) == hp_before - 40, "overflow blast should deal 40 damage")


func _test_arcanist_damage_augment_buffs_blast_and_storm() -> void:
	var battle = _make_battle("arcanist", "swordsman")
	_grant_character_augment(battle, 0, "arcane_overload")
	battle.first_player_id = 0
	battle.players[0].mp = 30
	battle.players[0].dice = [3, 2, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	var hp_before = int(battle.players[1].hp)
	_expect(battle.submit_skip(1), "second player should skip before buffed blast")
	_expect(battle.submit_skill(0, "arcanist_arcane_blast"), "arcanist should cast blast with damage augment")
	_expect(int(battle.players[1].hp) == hp_before - 35, "arcane overload should increase arcane blast damage by 15")

	battle = _make_battle("arcanist", "swordsman")
	_grant_character_augment(battle, 0, "arcane_overload")
	battle.first_player_id = 0
	battle.players[0].mp = 60
	battle.players[0].dice = [6, 6, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	hp_before = int(battle.players[1].hp)
	_expect(battle.submit_skip(1), "second player should skip before buffed storm")
	_expect(battle.submit_skill(0, "arcanist_storm"), "arcanist should cast storm with damage augment")
	_expect(int(battle.players[1].hp) == hp_before - 55, "arcane overload should also increase storm damage by 15")


func _test_arcanist_shield_augment_buffs_mana_shield() -> void:
	var battle = _make_battle("arcanist", "swordsman")
	_grant_character_augment(battle, 0, "mana_shield_matrix")
	battle.players[0].mp = 60
	battle.players[0].dice = [3, 2, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	_expect(battle.submit_skip(1), "second player should skip before buffed mana shield")
	_expect(battle.submit_skill(0, "arcanist_mana_shield"), "arcanist should cast mana shield with shield augment")
	_expect(int(battle.players[0].shield) == 45, "mana shield matrix should increase mana shield by 15")


func _grant_character_augment(battle, player_id: int, augment_id: String) -> void:
	var augment = battle._find_augment_for_player(player_id, augment_id)
	_expect(not augment.is_empty(), "augment %s should exist" % augment_id)
	if not augment.is_empty():
		battle._apply_augment(player_id, augment)


func _reset_augments_to_baseline(battle, player_id: int) -> void:
	var player: Dictionary = battle.players[player_id]
	var character: Dictionary = player.get("character", {})
	player.augments = []
	player.augment_ids = []
	player.max_hp = int(character.get("max_hp", player.max_hp))
	player.hp = min(int(player.hp), int(player.max_hp))
	player.max_mp = int(character.get("max_mp", player.max_mp))
	player.mp = min(int(player.mp), int(player.max_mp))
	player.max_shield = int(character.get("max_shield", player.max_shield))
	player.common_augment_picked = true
	player.character_augment_picked = true
	battle.players[player_id] = player


func _has_status(battle, player_id: int, status_id: String) -> bool:
	for status in battle.players[player_id].statuses:
		if String(status.id) == status_id:
			return true
	return false
