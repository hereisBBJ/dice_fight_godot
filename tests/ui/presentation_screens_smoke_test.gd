extends SceneTree

const MainScene = preload("res://scenes/main/main.tscn")

var failures: Array = []


func _init() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	_expect(load("res://assets/characters/pyromancer_portrait.svg") is Texture2D, "pyromancer portrait should load as texture")

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

	if failures.is_empty():
		print("PRESENTATION_SCREENS_SMOKE_TEST_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(str(failure))
		quit(1)


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
