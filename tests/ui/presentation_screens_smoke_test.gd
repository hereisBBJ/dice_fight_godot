extends SceneTree

const MainScene = preload("res://scenes/main/main.tscn")
const UIAssetsScript = preload("res://scripts/ui/components/ui_assets.gd")
const BattleScreenScene = preload("res://scenes/ui/screens/battle_screen.tscn")
const BattleStateScript = preload("res://scripts/rules/battle_state.gd")
const NetworkControllerScript = preload("res://scripts/network/network_controller.gd")

var failures: Array = []


func _init() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	_expect(UIAssetsScript.texture_from_path("res://assets/characters/pyromancer/pyromancer_portrait.svg", Color.WHITE) is Texture2D, "pyromancer portrait should load as texture")
	_expect(UIAssetsScript.texture_from_path("res://assets/characters/arcanist/arcanist_portrait.svg", Color.WHITE) is Texture2D, "arcanist portrait should load as texture")
	_expect(UIAssetsScript.texture_from_path("res://assets/characters/vampire/vampire_portrait.svg", Color.WHITE) is Texture2D, "vampire portrait should load as texture")
	_expect(UIAssetsScript.texture_from_path("res://assets/characters/stormcaller/stormcaller_portrait.svg", Color.WHITE) is Texture2D, "stormcaller portrait should load as texture")
	_expect(UIAssetsScript.texture_from_path("res://assets/skills/arcanist/arcanist_storm.svg", Color.WHITE) is Texture2D, "arcanist storm icon should load as texture")
	_expect(UIAssetsScript.texture_from_path("res://assets/skills/vampire/vampire_blood_disaster.svg", Color.WHITE) is Texture2D, "vampire blood disaster icon should load as texture")
	_expect(UIAssetsScript.texture_from_path("res://assets/skills/stormcaller/stormcaller_judgement.svg", Color.WHITE) is Texture2D, "stormcaller judgement icon should load as texture")

	main._on_start_local_requested()
	await process_frame
	_expect(main._current_screen_key == "character_select", "local start should show character select")

	main._submit_player_command(0, {"type": "select_character", "character_id": "swordsman"})
	main._submit_player_command(1, {"type": "select_character", "character_id": "archer"})
	await process_frame
	_expect(main._current_screen_key == "augment_select", "both selected characters should show augment select")

	_pick_all_augments(main)
	await process_frame
	_expect(main._current_screen_key == "battle", "picked augments should show battle screen")

	main.battle.players[1].hp = 0
	main.battle._check_game_over()
	main._render()
	await process_frame
	_expect(main._current_screen_key == "game_over", "game over phase should show game over screen")

	await _test_arcanist_battle_screen_assets_and_overflow_button()
	await _test_vampire_battle_screen_assets_and_buttons()
	await _test_archer_battle_screen_mode_buttons()
	await _test_stormcaller_battle_screen_resources_and_judgement()

	if failures.is_empty():
		print("PRESENTATION_SCREENS_SMOKE_TEST_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(str(failure))
		quit(1)


func _test_arcanist_battle_screen_assets_and_overflow_button() -> void:
	var battle = _make_battle("arcanist", "swordsman")
	battle.first_player_id = 0
	battle.players[0].mp = 30
	battle.players[0].dice = [3, 2, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	var network = NetworkControllerScript.new()
	network.bind_battle_state(battle)
	network.start_local(battle)
	var screen = BattleScreenScene.instantiate()
	root.add_child(screen)
	await process_frame
	screen.setup(battle, network)
	await process_frame
	_expect(screen.self_character_portrait.texture != null, "arcanist battle portrait should render in battle screen")
	var normal_blast_button = _find_button_with_text(screen, "奥术冲击\n0 MP")
	_expect(normal_blast_button != null, "normal arcane blast button should be present in battle screen")
	var overflow_button = _find_button_with_text(screen, "奥术冲击 · 溢出强化")
	_expect(overflow_button != null, "overflow mode button should be present in battle screen")
	if overflow_button != null:
		_expect(not overflow_button.disabled, "overflow mode button should be enabled with 30 MP and matching dice")
		_expect(overflow_button.text.find("30 MP") >= 0, "overflow mode button should display 30 MP cost")
	root.remove_child(screen)
	screen.free()
	network.free()
	await process_frame


func _test_vampire_battle_screen_assets_and_buttons() -> void:
	var battle = _make_battle("vampire", "swordsman")
	battle.first_player_id = 0
	battle.players[0].resources["blood_drops"] = 3
	battle.players[0].dice = [6, 3, 1, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	var network = NetworkControllerScript.new()
	network.bind_battle_state(battle)
	network.start_local(battle)
	var screen = BattleScreenScene.instantiate()
	root.add_child(screen)
	await process_frame
	screen.setup(battle, network)
	await process_frame
	_expect(screen.self_character_portrait.texture != null, "vampire battle portrait should render in battle screen")
	_expect(screen.self_panel.role_label.text.find("血滴 3") >= 0, "vampire resource should render in player panel")
	var blood_wall_10 = _find_button_with_text(screen, "血墙 · 失去 10 生命")
	var blood_wall_20 = _find_button_with_text(screen, "血墙 · 失去 20 生命")
	_expect(blood_wall_10 != null, "blood wall 10 mode button should be present")
	_expect(blood_wall_20 != null, "blood wall 20 mode button should be present")
	_expect(_count_buttons_with_text(screen, "血墙") == 2, "blood wall should only expose two mode buttons")
	_expect(_count_buttons_with_text(screen, "血灾") == 1, "blood disaster should only expose one button")
	root.remove_child(screen)
	screen.free()
	network.free()
	await process_frame


func _test_archer_battle_screen_mode_buttons() -> void:
	var battle = _make_battle("archer", "swordsman")
	battle.first_player_id = 0
	battle.players[0].mp = 40
	battle.players[0].dice = [6, 3, 2, 1]
	battle.players[1].dice = [1, 1, 1, 1]
	var network = NetworkControllerScript.new()
	network.bind_battle_state(battle)
	network.start_local(battle)
	var screen = BattleScreenScene.instantiate()
	root.add_child(screen)
	await process_frame
	screen.setup(battle, network)
	await process_frame
	_expect(_count_buttons_with_text(screen, "射击") == 2, "archer shot should expose normal and locked buttons")
	_expect(_count_buttons_with_text(screen, "后跳") == 2, "archer backstep should expose normal and empowered buttons")
	var normal_shot = _find_button_with_text(screen, "射击\n0 MP")
	var locked_shot = _find_button_with_text(screen, "射击 · 锁定攻击")
	var normal_backstep = _find_button_with_text(screen, "后跳\n20 MP")
	var empowered_backstep = _find_button_with_text(screen, "后跳 · 强化施法")
	_expect(normal_shot != null, "normal shot button should be present")
	_expect(locked_shot != null, "locked shot button should be present")
	_expect(normal_backstep != null, "normal backstep button should be present")
	_expect(empowered_backstep != null, "empowered backstep button should be present")
	root.remove_child(screen)
	screen.free()
	network.free()
	await process_frame


func _test_stormcaller_battle_screen_resources_and_judgement() -> void:
	var battle = _make_battle("stormcaller", "swordsman")
	battle.first_player_id = 0
	battle.players[0].mp = 60
	battle.players[0].resources["thunder_seals"] = 3
	battle.players[0].statuses.append({"id": "static_cage_active", "value": 10, "adjust_bonus": 10})
	battle.players[1].statuses.append({"id": "static_cage_active", "value": 20, "adjust_bonus": 0})
	battle.players[0].dice = [6, 6, 4, 4]
	battle.players[1].dice = [1, 1, 1, 1]
	var network = NetworkControllerScript.new()
	network.bind_battle_state(battle)
	network.start_local(battle)
	var screen = BattleScreenScene.instantiate()
	root.add_child(screen)
	await process_frame
	screen.setup(battle, network)
	await process_frame
	_expect(screen.self_character_portrait.texture != null, "stormcaller battle portrait should render in battle screen")
	_expect(screen.self_panel.role_label.text.find("雷印 3") >= 0, "stormcaller resource should render in player panel")
	var judgement_button = _find_button_with_text(screen, "天罚")
	_expect(judgement_button != null, "judgement button should be present")
	_expect(_status_tooltip_contains(screen.self_panel, "第一次重投或改点额外消耗 10 MP"), "stormcaller self static cage tooltip should show the second-player variant")
	_expect(_status_tooltip_contains(screen.enemy_panel, "技能额外消耗 20 MP。"), "enemy static cage tooltip should show the first-player variant")
	if judgement_button != null:
		_expect(not judgement_button.disabled, "judgement should be enabled when 3 thunder seals allow ignoring one requirement")
	root.remove_child(screen)
	screen.free()
	network.free()
	await process_frame


func _make_battle(p1_character: String, p2_character: String):
	var battle = BattleStateScript.new()
	battle.setup()
	_expect(battle.select_character(0, p1_character), "P1 should select %s" % p1_character)
	_expect(battle.select_character(1, p2_character), "P2 should select %s" % p2_character)
	_pick_augments_directly(battle, 0)
	_pick_augments_directly(battle, 1)
	_reset_augments_to_baseline(battle, 0)
	_reset_augments_to_baseline(battle, 1)
	_expect(battle.phase == BattleStateScript.PHASE_BATTLE, "direct battle setup should reach battle phase")
	return battle


func _pick_augments_directly(battle, player_id: int) -> void:
	for _index in range(2):
		var kind = battle.get_next_augment_kind(player_id)
		if kind == "done":
			continue
		var candidates: Array = battle.augment_candidates[player_id].get(kind, [])
		_expect(not candidates.is_empty(), "direct augment candidates should exist")
		if not candidates.is_empty():
			battle.pick_augment(player_id, String(candidates[0].id))


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
	battle.players[player_id] = player


func _find_button_with_text(root_node: Node, snippet: String) -> Button:
	for node in root_node.find_children("*", "Button", true, false):
		var button = node as Button
		if button != null and button.text.find(snippet) >= 0:
			return button
	return null


func _count_buttons_with_text(root_node: Node, snippet: String) -> int:
	var count = 0
	for node in root_node.find_children("*", "Button", true, false):
		var button = node as Button
		if button != null and button.text.find(snippet) >= 0:
			count += 1
	return count


func _status_tooltip_contains(panel, snippet: String) -> bool:
	for child in panel.status_row.get_children():
		if String(child.tooltip_text).find(snippet) >= 0:
			return true
	return false


func _pick_all_augments(main) -> void:
	for player_id in range(2):
		for _index in range(2):
			var kind = main.battle.get_next_augment_kind(player_id)
			if kind == "done":
				continue
			var candidates: Array = main.battle.augment_candidates[player_id].get(kind, [])
			_expect(not candidates.is_empty(), "augment candidates should exist")
			if candidates.is_empty():
				continue
			main._submit_player_command(player_id, {
				"type": "pick_augment",
				"augment_id": String(candidates[0].id)
			})


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
