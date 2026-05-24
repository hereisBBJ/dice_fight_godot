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
	_test_frost_armor_thorns_adds_cold_on_full_shield_block()
	_test_frost_thrust_bonus_requires_hp_damage()
	_test_frost_tide_enables_pursuit_choice()
	_test_ice_wind_applies_delayed_round_start_pressure()
	_test_witch_poison_ticks_at_round_end()
	_test_poison_round_end_only_consumes_one_total_layer()
	_test_poison_can_be_cleansed_by_action()
	_test_witch_soul_bind_disables_selected_skill()
	_test_witch_corruption_extract_converts_poison_to_mp_and_shield()
	_test_witch_recovery_drains_mp_and_deals_bonus_damage()
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
	_test_archer_base_mode_skills_still_resolve_normally()
	_test_vampire_passive_gains_blood_from_life_loss()
	_test_vampire_claw_gains_blood_on_hp_damage()
	_test_vampire_blood_wall_20_mode_self_damages_and_gains_shield()
	_test_vampire_blood_disaster_uses_current_blood_tier_at_resolution()
	_test_vampire_conversion_consumes_all_blood_for_heal()
	_test_stormcaller_skip_passive_gains_seal_and_mp()
	_test_stormcaller_arc_ray_gains_seal_on_hp_damage()
	_test_stormcaller_surge_uses_low_and_high_tiers()
	_test_stormcaller_static_cage_applies_next_turn_cost_penalties()
	_test_stormcaller_judgement_ignores_one_requirement_and_consumes_seals()
	_test_stormcaller_judgement_locks_next_turn_attack_skills()


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
	_expect(battle.characters.has("vampire"), "vampire data should load")
	_expect(battle.characters.has("stormcaller"), "stormcaller data should load")
	_expect(battle.characters.has("frost_swordsman"), "frost swordsman data should load")
	_expect(battle.character_augments.has("witch_doctor"), "witch doctor augments should load")
	_expect(battle.character_augments.has("pyromancer"), "pyromancer augments should load")
	_expect(battle.character_augments.has("arcanist"), "arcanist augments should load")
	_expect(battle.character_augments.has("vampire"), "vampire augments should load")
	_expect(battle.character_augments.has("stormcaller"), "stormcaller augments should load")
	_expect(battle.character_augments.has("frost_swordsman"), "frost swordsman augments should load")


func _test_frost_armor_thorns_adds_cold_on_full_shield_block() -> void:
	var battle = _make_battle("frost_swordsman", "swordsman")
	battle.players[0].shield = 20
	battle._apply_damage(1, 0, 10, 10, "test_block")
	_expect(int(battle._cold_layers(1)) == 1, "frost armor thorns should add 1 cold to the attacker when shield fully absorbs the hit")
	_expect(int(battle.players[0].hp) == int(battle.players[0].max_hp), "frost armor thorns should only trigger when no HP is lost")


func _test_frost_thrust_bonus_requires_hp_damage() -> void:
	var battle = _make_battle("frost_swordsman", "swordsman")
	battle.first_player_id = 0
	battle.players[0].dice = [3, 3, 2, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	var hp_before = int(battle.players[1].hp)
	_expect(battle.submit_skip(1), "second player should skip before frost thrust")
	_expect(battle.submit_skill(0, "frost_swordsman_frost_thrust"), "frost swordsman should cast frost thrust")
	_expect(int(battle.players[1].hp) == hp_before - 25, "frost thrust should deal bonus damage after causing HP loss")
	_expect(int(battle._cold_layers(0)) == 1, "frost thrust should add 1 cold to self")
	_expect(int(battle._cold_layers(1)) == 1, "frost thrust should add 1 cold to the target after HP damage")

	battle = _make_battle("frost_swordsman", "swordsman")
	battle.first_player_id = 0
	battle.players[1].shield = 40
	battle.players[0].dice = [3, 3, 2, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	_expect(battle.submit_skip(1), "second player should skip before blocked frost thrust")
	_expect(battle.submit_skill(0, "frost_swordsman_frost_thrust"), "frost swordsman should cast frost thrust into shield")
	_expect(int(battle._cold_layers(1)) == 0, "frost thrust should not add target cold when the main hit causes no HP loss")


func _test_frost_tide_enables_pursuit_choice() -> void:
	var battle = _make_battle("frost_swordsman", "swordsman")
	battle.players[0].statuses.append({"id": "frost_tide", "duration": 2, "pending_decay": 0, "source_id": 0})
	battle._add_cold(0, 1, 2)
	battle.first_player_id = 0
	battle.players[0].dice = [3, 3, 2, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	_expect(battle.submit_skip(1), "second player should skip before frost tide pursuit")
	_expect(battle.submit_skill(0, "frost_swordsman_frost_thrust"), "frost swordsman should cast frost thrust during frost tide")
	_expect(String(battle.pending_interactive_request.get("kind", "")) == "effect_choice", "frost tide should open the generic effect choice interaction")
	_expect(battle.interactive_select_option("gain_shield"), "frost swordsman should be able to choose the shield pursuit option")
	_expect(int(battle.players[0].shield) == 10, "shield pursuit should grant 10 shield")
	_expect(int(battle._cold_layers(1)) == 2, "pursuit should consume one layer of target cold after frost thrust adds one more")


func _test_ice_wind_applies_delayed_round_start_pressure() -> void:
	var battle = _make_battle("frost_swordsman", "swordsman")
	battle.first_player_id = 0
	battle.players[0].mp = 40
	battle.players[0].dice = [6, 6, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	var hp_before = int(battle.players[1].hp)
	_expect(battle.submit_skip(1), "second player should skip before ice wind")
	_expect(battle.submit_skill(0, "frost_swordsman_ice_wind"), "frost swordsman should cast ice wind")
	_expect(int(battle.players[1].hp) == hp_before, "ice wind should not deal damage on the cast round")
	_expect(_has_status(battle, 0, "ice_wind"), "ice wind should create a delayed status on the caster")

	battle.players[0].dice = [1, 1, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	_expect(battle.submit_skip(0), "caster should skip to advance ice wind")
	_expect(battle.submit_skip(1), "opponent should skip to advance ice wind")
	_expect(int(battle.players[1].hp) == hp_before - 5, "ice wind should deal 5 damage when it starts ticking")
	_expect(int(battle._cold_layers(0)) >= 1, "ice wind should add cold to the caster when it triggers")
	_expect(int(battle._cold_layers(1)) >= 1, "ice wind should add cold to the target when it triggers")
	battle.players[0].dice = [1, 1, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	_expect(battle.submit_skip(0), "caster should skip again so ice wind can trigger")
	_expect(battle.submit_skip(1), "opponent should skip again so ice wind can trigger")


func _test_witch_poison_ticks_at_round_end() -> void:
	var battle = _make_battle("witch_doctor", "swordsman")
	battle.first_player_id = 0
	battle.players[0].dice = [3, 2, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	var hp_before = int(battle.players[1].hp)
	_expect(battle.submit_skip(1), "second player should skip")
	_expect(battle.submit_skill(0, "witch_poison_mark"), "witch doctor should use poison mark")
	_expect(int(battle.players[1].hp) == hp_before - 10, "poison mark should deal 5 damage and poison should tick for 5 at round end")
	_expect(not _has_status(battle, 1, "poison"), "single-layer poison should decay away after round-end tick")


func _test_poison_round_end_only_consumes_one_total_layer() -> void:
	var battle = _make_battle("witch_doctor", "swordsman")
	battle.players[1].statuses.append({
		"id": "poison",
		"duration": 0,
		"value": 5,
		"layers": 2,
		"source_id": 0
	})
	battle.players[1].statuses.append({
		"id": "poison",
		"duration": 0,
		"value": 5,
		"layers": 1,
		"source_id": 1
	})
	var hp_before = int(battle.players[1].hp)
	battle._resolve_round_end_statuses()
	_expect(int(battle.players[1].hp) == hp_before - 5, "poison should only tick once per round regardless of stacked poison entries")
	_expect(int(battle._poison_layers(1)) == 2, "round-end poison decay should only remove one total layer")


func _test_poison_can_be_cleansed_by_action() -> void:
	var battle = _make_battle("witch_doctor", "swordsman")
	battle.players[0].mp = 40
	battle._add_poison(1, 0, 3)
	battle.players[0].dice = [1, 1, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	_expect(battle.submit_skip(1), "second player should skip before cleanse")
	_expect(battle.submit_cleanse(0), "poisoned player should be able to use cleanse action")
	_expect(not _has_status(battle, 0, "poison"), "cleanse should remove all poison layers")
	_expect(int(battle.players[0].mp) == 25, "cleanse should cost 5 MP per poison layer")


func _test_witch_soul_bind_disables_selected_skill() -> void:
	var battle = _make_battle("witch_doctor", "swordsman")
	battle.first_player_id = 0
	battle._add_poison(0, 1, 2)
	battle.players[0].dice = [6, 3, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	_expect(battle.submit_skip(1), "second player should skip before soul bind")
	_expect(battle.submit_skill(0, "witch_soul_bind"), "witch doctor should cast soul bind")
	_expect(String(battle.pending_interactive_request.get("kind", "")) == "witch_hex", "soul bind should enter interactive hex judgment")
	_expect(battle.interactive_modify(6), "witch doctor should be able to modify hex die to 6")
	_expect(battle.interactive_accept(), "witch doctor should accept the modified hex result")
	_expect(String(battle.pending_interactive_request.get("kind", "")) == "skill_disable_select", "bound target should trigger skill selection at next round start")
	_expect(battle.interactive_select_skill("swordsman_finish"), "witch doctor should select a disabled skill")
	battle.players[1].dice = [6, 6, 1, 1]
	var blocked_skill = battle.get_skill(1, "swordsman_finish")
	_expect(String(battle.get_skill_block_reason(1, blocked_skill)) == "本回合被缚魂禁用", "selected skill should be blocked for the turn")


func _test_witch_corruption_extract_converts_poison_to_mp_and_shield() -> void:
	var battle = _make_battle("witch_doctor", "swordsman")
	battle.first_player_id = 0
	battle._add_poison(0, 1, 4)
	battle.players[0].mp = 20
	battle.players[0].dice = [6, 3, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	_expect(battle.submit_skip(1), "second player should skip before corruption extract")
	_expect(battle.submit_skill(0, "witch_corruption_extract"), "witch doctor should cast corruption extract")
	_expect(int(battle.players[0].mp) == 20, "corruption extract should recover 10 MP plus 5 MP from the passive after paying 15 MP cost")
	_expect(int(battle.players[0].shield) == 10, "corruption extract should grant shield from poison extraction")
	_expect(int(battle._poison_layers(1)) == 1, "corruption extract should remove half of the target poison layers before round-end poison decay")


func _test_witch_recovery_drains_mp_and_deals_bonus_damage() -> void:
	var battle = _make_battle("witch_doctor", "swordsman")
	battle.first_player_id = 0
	battle._add_poison(0, 1, 2)
	battle._add_soul_bind(0, 1, 1)
	battle.players[0].dice = [3, 3, 2, 1]
	battle.players[1].dice = [6, 6, 1, 1]
	battle.players[1].mp = 30
	var hp_before = int(battle.players[1].hp)
	_expect(battle.submit_skill(1, "swordsman_finish"), "second player should queue finish before recovery")
	_expect(battle.submit_skill(0, "witch_recovery"), "witch doctor should cast recovery as first player")
	_expect(int(battle.players[1].mp) == 15, "recovery should drain 15 MP based on the removed marks")
	_expect(int(battle.players[1].hp) == hp_before - 15, "first-player recovery should deal bonus damage when it breaks the queued skill")


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
	battle.players[1].shield = 26
	battle.players[0].dice = [6, 5, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	_expect(battle.submit_skip(1), "second player should skip before drain")
	_expect(battle.submit_skill(0, "arcanist_drain"), "arcanist should cast drain")
	_expect(int(battle.players[0].mp) == 10, "drain should restore 10 MP when actual life damage reaches 12")


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


func _test_archer_base_mode_skills_still_resolve_normally() -> void:
	var battle = _make_battle("archer", "swordsman")
	battle.first_player_id = 0
	battle.players[0].mp = 20
	battle.players[0].dice = [6, 3, 2, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	_expect(battle.submit_skip(1), "second player should skip before normal shot")
	_expect(battle.submit_skill(0, "archer_shot"), "archer should cast normal shot without mode")
	_expect(battle.phase == BattleStateScript.PHASE_INTERACTIVE, "normal shot should still enter shot evasion judgment")
	_expect(String(battle.pending_interactive_request.get("kind", "")) == "shot_evasion", "normal shot should request shot_evasion interaction")

	battle = _make_battle("archer", "swordsman")
	battle.first_player_id = 0
	battle.players[0].mp = 20
	battle.players[0].dice = [6, 3, 2, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	_expect(battle.submit_skip(1), "second player should skip before normal backstep")
	_expect(battle.submit_skill(0, "archer_backstep"), "archer should cast normal backstep without mode")
	_expect(battle.phase == BattleStateScript.PHASE_INTERACTIVE, "normal backstep should still enter interactive judgment")


func _test_vampire_passive_gains_blood_from_life_loss() -> void:
	var battle = _make_battle("vampire", "swordsman")
	battle._deal_direct_life_loss(1, 0, 20, "测试自损")
	_expect(int(battle.players[0].resources.get("blood_drops", 0)) == 2, "vampire passive should gain 2 blood drops after losing 20 HP")


func _test_vampire_claw_gains_blood_on_hp_damage() -> void:
	var battle = _make_battle("vampire", "swordsman")
	battle.first_player_id = 0
	battle.players[0].dice = [3, 2, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	_expect(battle.submit_skip(1), "second player should skip before claw")
	_expect(battle.submit_skill(0, "vampire_claw"), "vampire should cast claw")
	_expect(int(battle.players[0].resources.get("blood_drops", 0)) == 1, "claw should gain 1 blood drop when it deals HP damage")


func _test_vampire_blood_wall_20_mode_self_damages_and_gains_shield() -> void:
	var battle = _make_battle("vampire", "swordsman")
	battle.first_player_id = 0
	battle.players[0].dice = [6, 3, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	_expect(battle.submit_skip(1), "second player should skip before blood wall")
	_expect(battle.submit_skill(0, "vampire_blood_wall", ["loss_20"]), "vampire should cast blood wall 20 mode")
	_expect(int(battle.players[0].hp) == 60, "blood wall 20 mode should cost 20 HP")
	_expect(int(battle.players[0].shield) == 40, "blood wall 20 mode should grant 40 shield")
	_expect(int(battle.players[0].resources.get("blood_drops", 0)) == 2, "blood wall self damage should trigger blood hunger")


func _test_vampire_blood_disaster_uses_current_blood_tier_at_resolution() -> void:
	var battle = _make_battle("vampire", "swordsman")
	battle.first_player_id = 0
	battle.players[0].dice = [6, 3, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	var self_hp_before = int(battle.players[0].hp)
	var enemy_hp_before = int(battle.players[1].hp)
	_expect(battle.submit_skip(1), "second player should skip before low-tier blood disaster")
	_expect(battle.submit_skill(0, "vampire_blood_disaster"), "vampire should cast blood disaster")
	_expect(int(battle.players[0].hp) == self_hp_before - 10, "low-tier blood disaster should self damage for 10")
	_expect(int(battle.players[1].hp) == enemy_hp_before - 20, "low-tier blood disaster should deal 20 damage")

	battle = _make_battle("vampire", "swordsman")
	battle.first_player_id = 0
	battle.players[0].resources["blood_drops"] = 6
	battle.players[1].shield = 30
	battle.players[0].dice = [6, 3, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	enemy_hp_before = int(battle.players[1].hp)
	_expect(battle.submit_skip(1), "second player should skip before high-tier blood disaster")
	_expect(battle.submit_skill(0, "vampire_blood_disaster"), "vampire should cast high-tier blood disaster")
	_expect(int(battle.players[1].hp) == enemy_hp_before - 30, "high-tier blood disaster should bypass shield and deal 30 HP damage")
	_expect(int(battle.players[1].shield) == 30, "high-tier blood disaster should leave shield intact")


func _test_vampire_conversion_consumes_all_blood_for_heal() -> void:
	var battle = _make_battle("vampire", "swordsman")
	battle.first_player_id = 0
	battle.players[0].hp = 50
	battle.players[0].resources["blood_drops"] = 4
	battle.players[0].dice = [6, 6, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	_expect(battle.submit_skip(1), "second player should skip before conversion")
	_expect(battle.submit_skill(0, "vampire_conversion"), "vampire should cast conversion")
	_expect(int(battle.players[0].hp) == 70, "conversion should heal 5 HP per blood drop consumed")
	_expect(int(battle.players[0].resources.get("blood_drops", 0)) == 0, "conversion should consume all blood drops")


func _test_stormcaller_skip_passive_gains_seal_and_mp() -> void:
	var battle = _make_battle("stormcaller", "swordsman")
	battle.players[0].mp = 20
	battle.players[0].dice = [1, 1, 1, 1]
	battle._resolve_skip(0)
	_expect(int(battle.players[0].resources.get("thunder_seals", 0)) == 1, "stormcaller skip passive should grant 1 thunder seal")
	_expect(int(battle.players[0].mp) == 30, "stormcaller skip passive should restore passive 10 MP when skip roll grants no base MP")


func _test_stormcaller_arc_ray_gains_seal_on_hp_damage() -> void:
	var battle = _make_battle("stormcaller", "swordsman")
	battle.first_player_id = 0
	battle.players[0].dice = [3, 2, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	_expect(battle.submit_skip(1), "second player should skip before arc ray")
	_expect(battle.submit_skill(0, "stormcaller_arc_ray"), "stormcaller should cast arc ray")
	_expect(int(battle.players[0].resources.get("thunder_seals", 0)) == 1, "arc ray should grant 1 thunder seal when it deals HP damage")


func _test_stormcaller_surge_uses_low_and_high_tiers() -> void:
	var battle = _make_battle("stormcaller", "swordsman")
	battle.first_player_id = 0
	battle.players[0].mp = 20
	battle.players[0].dice = [6, 3, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	_expect(battle.submit_skip(1), "second player should skip before low-tier surge")
	_expect(battle.submit_skill(0, "stormcaller_surge"), "stormcaller should cast low-tier surge")
	_expect(int(battle.players[0].mp) == 35, "low-tier surge should restore 15 MP")
	_expect(int(battle.players[0].shield) == 10, "low-tier surge should grant 10 shield")
	_expect(int(battle.players[0].resources.get("thunder_seals", 0)) == 1, "low-tier surge should grant 1 thunder seal")

	battle = _make_battle("stormcaller", "swordsman")
	battle.first_player_id = 0
	battle.players[0].mp = 20
	battle.players[0].resources["thunder_seals"] = 2
	battle.players[0].dice = [6, 3, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	_expect(battle.submit_skip(1), "second player should skip before high-tier surge")
	_expect(battle.submit_skill(0, "stormcaller_surge"), "stormcaller should cast high-tier surge")
	_expect(int(battle.players[0].mp) == 40, "high-tier surge should restore 20 MP")
	_expect(int(battle.players[0].shield) == 15, "high-tier surge should be capped by max shield 15")
	_expect(int(battle.players[0].resources.get("thunder_seals", 0)) == 3, "high-tier surge should still cap thunder seals at 3")


func _test_stormcaller_static_cage_applies_next_turn_cost_penalties() -> void:
	var battle = _make_battle("stormcaller", "swordsman")
	battle.first_player_id = 0
	battle.players[0].dice = [6, 3, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	battle.players[1].mp = 50
	_expect(battle.submit_skip(1), "second player should skip before first-player static cage")
	_expect(battle.submit_skill(0, "stormcaller_static_cage"), "stormcaller should cast static cage as first player")
	_expect(not _has_status(battle, 1, "static_cage_pending"), "static cage pending should resolve at next round start")
	_expect(_has_status(battle, 1, "static_cage_active"), "static cage should show an active status during the affected turn")
	_expect(int(battle.players[1].per_turn_flags.get("skill_cost_bonus", 0)) == 20, "first-player static cage should add 20 MP to next-turn skill costs")
	_expect(int(battle.get_reroll_cost(1)) == 10, "first-player static cage should not add reroll penalty")
	_expect(battle.reroll_dice(1), "target should still be able to reroll after paying penalty")
	_expect(int(battle.get_modify_cost(1)) == 20, "static cage adjust penalty should be consumed after first reroll")

	battle = _make_battle("swordsman", "stormcaller")
	battle.first_player_id = 0
	battle.players[1].dice = [6, 3, 1, 1]
	battle.players[0].dice = [1, 1, 1, 1]
	battle.players[0].mp = 50
	_expect(battle.submit_skip(0), "first player should skip before second-player static cage")
	_expect(battle.submit_skill(1, "stormcaller_static_cage"), "stormcaller should cast static cage as second player")
	_expect(_has_status(battle, 0, "static_cage_active"), "second-player static cage should also show an active status during the affected turn")
	_expect(int(battle.players[0].per_turn_flags.get("skill_cost_bonus", 0)) == 10, "second-player static cage should add 10 MP to next-turn skill costs")
	_expect(int(battle.get_reroll_cost(0)) == 20, "second-player static cage should add 10 MP to the first reroll")


func _test_stormcaller_judgement_ignores_one_requirement_and_consumes_seals() -> void:
	var battle = _make_battle("stormcaller", "swordsman")
	battle.first_player_id = 0
	battle.players[0].mp = 60
	battle.players[0].resources["thunder_seals"] = 3
	battle.players[0].dice = [6, 6, 4, 4]
	battle.players[1].dice = [1, 1, 1, 1]
	var skill = battle.get_skill(0, "stormcaller_judgement")
	_expect(battle.can_use_skill(0, skill), "judgement should ignore one requirement with 3 thunder seals")
	_expect(battle.submit_skip(1), "second player should skip before judgement")
	_expect(battle.submit_skill(0, "stormcaller_judgement"), "stormcaller should cast judgement")
	_expect(int(battle.players[0].resources.get("thunder_seals", 0)) == 0, "judgement should consume all thunder seals")


func _test_stormcaller_judgement_locks_next_turn_attack_skills() -> void:
	var battle = _make_battle("stormcaller", "swordsman")
	battle.first_player_id = 0
	battle.players[0].mp = 60
	battle.players[0].resources["thunder_seals"] = 3
	battle.players[0].dice = [6, 6, 4, 4]
	battle.players[1].dice = [1, 1, 1, 1]
	_expect(battle.submit_skip(1), "second player should skip before judgement lock test")
	_expect(battle.submit_skill(0, "stormcaller_judgement"), "stormcaller should cast judgement for lock test")
	battle.players[0].dice = [3, 2, 1, 1]
	var next_attack = battle.get_skill(0, "stormcaller_arc_ray")
	_expect(String(battle.get_skill_block_reason(0, next_attack)) == "本回合无法使用攻击技能", "stormcaller should be unable to use attack skills on the next turn after judgement")


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
