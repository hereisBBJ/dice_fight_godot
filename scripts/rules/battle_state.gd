extends RefCounted
class_name BattleState

const DataRepositoryScript = preload("res://scripts/data/data_repository.gd")
const DiceRulesScript = preload("res://scripts/rules/dice_rules.gd")

const PHASE_CHARACTER_SELECT = "character_select"
const PHASE_AUGMENT_SELECT = "augment_select"
const PHASE_BATTLE = "battle"
const PHASE_RESOLVING = "resolving"
const PHASE_INTERACTIVE = "interactive"
const PHASE_GAME_OVER = "game_over"

const ACTION_NONE = "none"
const ACTION_SKILL = "skill"
const ACTION_SKIP = "skip"

var characters: Dictionary = {}
var common_augments: Array = []
var character_augments: Dictionary = {}
var status_effects: Dictionary = {}

var phase = PHASE_CHARACTER_SELECT
var players: Array = []
var round_num = 0
var attacker_id = 0
var winner_id = -1
var logs: Array = []
var pending_actions: Array = [{}, {}]
var augment_candidates: Array = [{}, {}]
var pending_interactive_request: Dictionary = {}

var rng = RandomNumberGenerator.new()

var _resolution_order: Array = []
var _resolution_index = 0
var _interactive_context: Dictionary = {}


func setup() -> void:
	rng.randomize()
	characters = DataRepositoryScript.load_characters()
	common_augments = DataRepositoryScript.load_common_augments()
	character_augments = DataRepositoryScript.load_character_augments()
	status_effects = DataRepositoryScript.load_status_effects()
	reset_to_character_select()


func reset_to_character_select() -> void:
	phase = PHASE_CHARACTER_SELECT
	players = [_empty_player(0), _empty_player(1)]
	round_num = 0
	attacker_id = 0
	winner_id = -1
	pending_actions = [{}, {}]
	augment_candidates = [{}, {}]
	pending_interactive_request = {}
	_interactive_context = {}
	logs = ["请选择 P1 和 P2 的角色。"]


func _empty_player(player_id: int) -> Dictionary:
	return {
		"player_id": player_id,
		"character_id": "",
		"character": {},
		"hp": 0,
		"max_hp": 0,
		"mp": 0,
		"max_mp": 0,
		"shield": 0,
		"max_shield": 0,
		"dice": [],
		"has_modified_this_turn": false,
		"has_rerolled_this_turn": false,
		"submitted_action": {},
		"statuses": [],
		"augments": [],
		"augment_ids": [],
		"common_augment_picked": false,
		"character_augment_picked": false,
		"per_turn_flags": {},
		"per_game_flags": {},
		"damage_taken_this_turn": 0,
		"damage_taken_last_turn": 0,
		"dealt_damage_this_turn": 0,
		"dealt_damage_last_turn": 0
	}


func select_character(player_id: int, character_id: String) -> bool:
	if phase != PHASE_CHARACTER_SELECT:
		return false
	if not _valid_player(player_id) or not characters.has(character_id):
		return false
	var character: Dictionary = characters[character_id]
	var player = players[player_id]
	player.character_id = character_id
	player.character = character
	player.hp = int(character.initial_hp)
	player.max_hp = int(character.max_hp)
	player.mp = int(character.initial_mp)
	player.max_mp = int(character.max_mp)
	player.shield = 0
	player.max_shield = int(character.max_shield)
	player.dice = []
	player.statuses = []
	player.augments = []
	player.augment_ids = []
	player.common_augment_picked = false
	player.character_augment_picked = false
	player.per_game_flags = {}
	players[player_id] = player
	_log("P%d 选择了 %s。" % [player_id + 1, character.name])
	if _all_characters_selected():
		_prepare_augment_candidates()
		phase = PHASE_AUGMENT_SELECT
		_log("进入强化选择：每名玩家先选 1 个通用强化，再选 1 个专属强化。")
	return true


func _all_characters_selected() -> bool:
	return players[0].character_id != "" and players[1].character_id != ""


func _prepare_augment_candidates() -> void:
	for player_id in range(2):
		var player: Dictionary = players[player_id]
		var character_id = String(player.character_id)
		augment_candidates[player_id] = {
			"common": _pick_random_items(common_augments, min(3, common_augments.size())),
			"character": _pick_random_items(character_augments.get(character_id, []), min(2, character_augments.get(character_id, []).size()))
		}


func _pick_random_items(source: Array, count: int) -> Array:
	var pool = source.duplicate(true)
	var result = []
	while result.size() < count and not pool.is_empty():
		var index = rng.randi_range(0, pool.size() - 1)
		result.append(pool[index])
		pool.remove_at(index)
	return result


func get_next_augment_kind(player_id: int) -> String:
	if not _valid_player(player_id):
		return ""
	var player: Dictionary = players[player_id]
	if not bool(player.common_augment_picked):
		return "common"
	if not bool(player.character_augment_picked):
		return "character"
	return "done"


func pick_augment(player_id: int, augment_id: String) -> bool:
	if phase != PHASE_AUGMENT_SELECT or not _valid_player(player_id):
		return false
	var kind = get_next_augment_kind(player_id)
	if kind == "done":
		return false
	var candidates: Array = augment_candidates[player_id].get(kind, [])
	for augment in candidates:
		if String(augment.id) == augment_id:
			_apply_augment(player_id, augment)
			if kind == "common":
				players[player_id].common_augment_picked = true
			else:
				players[player_id].character_augment_picked = true
			_log("P%d 选择强化：%s。" % [player_id + 1, augment.name])
			if _all_augments_selected():
				_start_battle()
			return true
	return false


func _all_augments_selected() -> bool:
	for player in players:
		if not bool(player.common_augment_picked) or not bool(player.character_augment_picked):
			return false
	return true


func _apply_augment(player_id: int, augment: Dictionary) -> void:
	var player: Dictionary = players[player_id]
	player.augments.append(augment)
	player.augment_ids.append(String(augment.id))
	match String(augment.effect):
		"max_hp":
			player.max_hp += int(augment.amount)
			player.hp = min(player.max_hp, player.hp + int(augment.amount))
		"max_mp":
			player.max_mp += int(augment.amount)
			player.mp = min(player.max_mp, player.mp + int(augment.amount))
		"max_shield":
			player.max_shield += int(augment.amount)
	players[player_id] = player


func _start_battle() -> void:
	attacker_id = rng.randi_range(0, 1)
	round_num = 1
	winner_id = -1
	phase = PHASE_BATTLE
	_log("战斗开始。P%d 为首个进攻方。" % [attacker_id + 1])
	_begin_round(false)


func _begin_round(carry_last_turn: bool) -> void:
	pending_actions = [{}, {}]
	for player_id in range(2):
		var player: Dictionary = players[player_id]
		if carry_last_turn:
			player.damage_taken_last_turn = int(player.damage_taken_this_turn)
			player.dealt_damage_last_turn = int(player.dealt_damage_this_turn)
		player.damage_taken_this_turn = 0
		player.dealt_damage_this_turn = 0
		player.has_modified_this_turn = false
		player.has_rerolled_this_turn = false
		player.submitted_action = {}
		player.per_turn_flags = {
			"used_skill": false,
			"used_attack_skill": false,
			"first_attack_bonus_used": false,
			"end_mp_refund": 0
		}
		player.dice = DiceRulesScript.roll_dice(rng, 4)
		players[player_id] = player
	_log("第 %d 回合开始。P%d 进攻，P%d 防守。" % [round_num, attacker_id + 1, _defender_id() + 1])


func _defender_id() -> int:
	return 1 - attacker_id


func reroll_dice(player_id: int) -> bool:
	if phase != PHASE_BATTLE or not _can_adjust_action_dice(player_id):
		return false
	var cost = get_reroll_cost(player_id)
	if players[player_id].mp < cost:
		_log("P%d MP 不足，无法重掷。" % [player_id + 1])
		return false
	players[player_id].mp -= cost
	players[player_id].has_rerolled_this_turn = true
	players[player_id].dice = DiceRulesScript.roll_dice(rng, 4)
	_log("P%d 重掷骰子，消耗 %d MP：%s。" % [player_id + 1, cost, _dice_text(players[player_id].dice)])
	return true


func modify_die(player_id: int, die_index: int, value: int) -> bool:
	if phase != PHASE_BATTLE or not _can_adjust_action_dice(player_id):
		return false
	if die_index < 0 or die_index >= players[player_id].dice.size() or value < 1 or value > 6:
		return false
	if bool(players[player_id].has_modified_this_turn):
		_log("P%d 本回合已经修改过点数。" % [player_id + 1])
		return false
	var cost = get_modify_cost(player_id)
	if players[player_id].mp < cost:
		_log("P%d MP 不足，无法修改点数。" % [player_id + 1])
		return false
	players[player_id].mp -= cost
	players[player_id].has_modified_this_turn = true
	players[player_id].dice[die_index] = value
	players[player_id].dice = DiceRulesScript.sort_desc(players[player_id].dice)
	_log("P%d 修改 1 颗骰子为 %d，消耗 %d MP：%s。" % [player_id + 1, value, cost, _dice_text(players[player_id].dice)])
	return true


func _can_adjust_action_dice(player_id: int) -> bool:
	return _valid_player(player_id) and players[player_id].submitted_action.is_empty()


func get_reroll_cost(player_id: int) -> int:
	var player: Dictionary = players[player_id]
	if _has_augment(player, "dice_luck_shift") and not bool(player.has_rerolled_this_turn):
		return 0
	return 10


func get_modify_cost(player_id: int) -> int:
	var player: Dictionary = players[player_id]
	if _has_augment(player, "mind_calibration") and not bool(player.has_modified_this_turn):
		return 10
	return 20


func submit_skip(player_id: int) -> bool:
	if phase != PHASE_BATTLE or not _valid_player(player_id) or not players[player_id].submitted_action.is_empty():
		return false
	var action = {"type": ACTION_SKIP}
	players[player_id].submitted_action = action
	pending_actions[player_id] = action
	_log("P%d 选择跳过回合。" % [player_id + 1])
	_try_resolve_turn()
	return true


func submit_skill(player_id: int, skill_id: String, modes: Array = []) -> bool:
	if phase != PHASE_BATTLE or not _valid_player(player_id) or not players[player_id].submitted_action.is_empty():
		return false
	var skill = get_skill(player_id, skill_id)
	if skill.is_empty():
		return false
	var reason = get_skill_block_reason(player_id, skill, modes)
	if reason != "":
		_log("P%d 无法使用 %s：%s。" % [player_id + 1, skill.name, reason])
		return false
	var action = {
		"type": ACTION_SKILL,
		"skill_id": skill_id,
		"modes": modes.duplicate()
	}
	players[player_id].submitted_action = action
	pending_actions[player_id] = action
	var mode_text = _mode_text(skill, modes)
	_log("P%d 提交技能：%s%s。" % [player_id + 1, skill.name, mode_text])
	_try_resolve_turn()
	return true


func _try_resolve_turn() -> void:
	if not pending_actions[0].is_empty() and not pending_actions[1].is_empty():
		phase = PHASE_RESOLVING
		_resolution_order = [_defender_id(), attacker_id]
		_resolution_index = 0
		_continue_resolution()


func _continue_resolution() -> void:
	while phase == PHASE_RESOLVING and _resolution_index < _resolution_order.size():
		var actor_id = int(_resolution_order[_resolution_index])
		if actor_id == attacker_id and players[attacker_id].hp <= 0:
			_log("进攻方已无法行动。")
			break
		var completed = _execute_action(actor_id)
		if not completed:
			return
		if phase == PHASE_GAME_OVER:
			return
		_resolution_index += 1
	if phase != PHASE_GAME_OVER:
		_finish_round()


func _execute_action(actor_id: int) -> bool:
	var action: Dictionary = pending_actions[actor_id]
	if action.is_empty():
		_log("P%d 没有提交行动。" % [actor_id + 1])
		return true
	if String(action.type) == ACTION_SKIP:
		_resolve_skip(actor_id)
		return true
	if String(action.type) != ACTION_SKILL:
		return true
	var skill = get_skill(actor_id, String(action.skill_id))
	if skill.is_empty():
		return true
	var modes: Array = action.get("modes", [])
	var reason = get_skill_block_reason(actor_id, skill, modes, true)
	if reason != "":
		_log("P%d 的 %s 结算失败：%s。" % [actor_id + 1, skill.name, reason])
		return true
	var cost = get_skill_cost(actor_id, skill, modes)
	if players[actor_id].mp < cost:
		_log("P%d 的 %s 结算失败：MP 不足。" % [actor_id + 1, skill.name])
		return true
	players[actor_id].mp -= cost
	players[actor_id].per_turn_flags.used_skill = true
	if String(skill.type) == "attack":
		players[actor_id].per_turn_flags.used_attack_skill = true
	_log("P%d 结算 %s，消耗 %d MP。" % [actor_id + 1, skill.name, cost])
	for effect in skill.effects:
		if not _resolve_effect(actor_id, skill, effect, modes):
			return false
		if phase == PHASE_GAME_OVER:
			return true
	return true


func _resolve_skip(player_id: int) -> void:
	var gained = 0
	for die in players[player_id].dice:
		if int(die) == 3:
			gained += 10
		elif int(die) == 6:
			gained += 20
	if _has_augment(players[player_id], "tactical_reserve"):
		gained += 10
	var before = int(players[player_id].mp)
	players[player_id].mp = min(players[player_id].max_mp, players[player_id].mp + gained)
	_log("P%d 跳过回合，回复 %d MP（%d -> %d）。" % [player_id + 1, players[player_id].mp - before, before, players[player_id].mp])


func _resolve_effect(actor_id: int, skill: Dictionary, effect: Dictionary, modes: Array) -> bool:
	var target_id = 1 - actor_id
	match String(effect.type):
		"damage":
			var amount = _modified_damage(actor_id, skill, int(effect.amount))
			_apply_damage(actor_id, target_id, amount, 10, String(skill.id))
		"shield":
			var amount = _modified_shield_gain(actor_id, skill, int(effect.amount))
			_gain_shield(actor_id, amount)
		"add_status":
			_add_status(actor_id, String(effect.status_id), int(effect.get("duration", 1)), int(effect.get("value", 0)))
		"damage_by_shield":
			var amount = _modified_damage(actor_id, skill, int(effect.base) + int(players[actor_id].shield))
			_apply_damage(actor_id, target_id, amount, 10, String(skill.id))
		"damage_by_last_taken":
			var amount = _modified_damage(actor_id, skill, int(effect.base) + int(players[actor_id].damage_taken_last_turn))
			_apply_damage(actor_id, target_id, amount, 10, String(skill.id))
		"evasion_attack":
			var amount = _modified_damage(actor_id, skill, int(effect.amount))
			if modes.has("locked") or bool(players[actor_id].per_game_flags.get("eagle_eye", false)):
				_apply_damage(actor_id, target_id, amount, 10, String(skill.id))
			else:
				_start_interactive("shot_evasion", target_id, actor_id, target_id, amount, 10, String(skill.id))
				return false
		"backstep":
			if modes.has("empowered"):
				_add_status(actor_id, "sure_evasion", 1, 0)
				_log("P%d 强化后跳，直接获得必定闪避。" % [actor_id + 1])
			else:
				_start_interactive("backstep", actor_id, actor_id, actor_id, 0, 0, String(skill.id))
				return false
		"piercing_damage":
			if int(players[actor_id].dealt_damage_last_turn) > 0:
				_log("P%d 上回合已经造成过伤害，穿甲箭失败。" % [actor_id + 1])
			else:
				var amount = _modified_damage(actor_id, skill, int(effect.amount))
				_apply_damage(actor_id, target_id, amount, int(effect.break_life_damage), String(skill.id))
		"eagle_eye":
			if bool(players[actor_id].per_game_flags.get("eagle_eye_used", false)):
				_log("P%d 已经使用过鹰眼，本次无效。" % [actor_id + 1])
			else:
				players[actor_id].per_game_flags.eagle_eye_used = true
				players[actor_id].per_game_flags.eagle_eye = true
				players[actor_id].mp = min(players[actor_id].max_mp, players[actor_id].mp + 20)
				_add_status(actor_id, "immune", 1, 0)
				_log("P%d 觉醒鹰眼，回复 20 MP，并获得本回合免疫。" % [actor_id + 1])
	return true


func _start_interactive(kind: String, responder_id: int, actor_id: int, target_id: int, damage: int, break_damage: int, skill_id: String) -> void:
	var die = rng.randi_range(1, 6)
	phase = PHASE_INTERACTIVE
	pending_interactive_request = {
		"kind": kind,
		"responder_id": responder_id,
		"actor_id": actor_id,
		"target_id": target_id,
		"die": die,
		"damage": damage,
		"break_life_damage": break_damage,
		"skill_id": skill_id
	}
	_interactive_context = pending_interactive_request.duplicate(true)
	var label = "射击闪避" if kind == "shot_evasion" else "后跳判定"
	_log("%s：P%d 掷出 %d，可接受、重掷或修改。" % [label, responder_id + 1, die])


func interactive_accept() -> bool:
	if phase != PHASE_INTERACTIVE:
		return false
	_apply_interactive_result()
	return true


func interactive_reroll() -> bool:
	if phase != PHASE_INTERACTIVE:
		return false
	var responder_id = int(pending_interactive_request.responder_id)
	var cost = get_reroll_cost(responder_id)
	if players[responder_id].mp < cost:
		_log("P%d MP 不足，无法重掷判定骰。" % [responder_id + 1])
		return false
	players[responder_id].mp -= cost
	players[responder_id].has_rerolled_this_turn = true
	pending_interactive_request.die = rng.randi_range(1, 6)
	_interactive_context.die = pending_interactive_request.die
	_log("P%d 重掷判定骰，消耗 %d MP，结果为 %d。" % [responder_id + 1, cost, pending_interactive_request.die])
	return true


func interactive_modify(value: int) -> bool:
	if phase != PHASE_INTERACTIVE or value < 1 or value > 6:
		return false
	var responder_id = int(pending_interactive_request.responder_id)
	if bool(players[responder_id].has_modified_this_turn):
		_log("P%d 本回合已经修改过点数。" % [responder_id + 1])
		return false
	var cost = get_modify_cost(responder_id)
	if players[responder_id].mp < cost:
		_log("P%d MP 不足，无法修改判定骰。" % [responder_id + 1])
		return false
	players[responder_id].mp -= cost
	players[responder_id].has_modified_this_turn = true
	pending_interactive_request.die = value
	_interactive_context.die = value
	_log("P%d 修改判定骰为 %d，消耗 %d MP。" % [responder_id + 1, value, cost])
	return true


func _apply_interactive_result() -> void:
	var kind = String(_interactive_context.kind)
	var die = int(_interactive_context.die)
	if kind == "shot_evasion":
		var dodged = die % 2 == 0
		if dodged:
			_log("P%d 闪避成功，射击没有造成伤害。" % [int(_interactive_context.responder_id) + 1])
		else:
			_log("P%d 闪避失败。" % [int(_interactive_context.responder_id) + 1])
			_apply_damage(int(_interactive_context.actor_id), int(_interactive_context.target_id), int(_interactive_context.damage), int(_interactive_context.break_life_damage), String(_interactive_context.skill_id))
	elif kind == "backstep":
		var actor_id = int(_interactive_context.actor_id)
		var success = die % 2 == 0
		if bool(players[actor_id].per_game_flags.get("eagle_eye", false)):
			success = die != 1
		if success:
			_add_status(actor_id, "sure_evasion", 1, 0)
			_log("P%d 后跳成功，获得必定闪避。" % [actor_id + 1])
		else:
			players[actor_id].per_turn_flags.end_mp_refund = int(players[actor_id].per_turn_flags.get("end_mp_refund", 0)) + 10
			_log("P%d 后跳失败，回合末返还 10 MP。" % [actor_id + 1])
	pending_interactive_request = {}
	_interactive_context = {}
	if phase != PHASE_GAME_OVER:
		phase = PHASE_RESOLVING
		_resolution_index += 1
		_continue_resolution()


func _apply_damage(attacker: int, target: int, amount: int, break_life_damage: int, skill_id: String) -> Dictionary:
	var result = {
		"hp_damage": 0,
		"shield_damage": 0,
		"broke_shield": false
	}
	if amount <= 0:
		_log("伤害为 0。")
		return result
	if _has_status(target, "immune"):
		_log("P%d 处于免疫状态，普通伤害无效。" % [target + 1])
		return result
	if _has_status(target, "sure_evasion"):
		_log("P%d 必定闪避，普通伤害无效。" % [target + 1])
		return result
	var reduced_amount = amount
	var guard_value = _consume_guard(target)
	if guard_value > 0:
		reduced_amount = max(0, reduced_amount - guard_value)
		_log("P%d 格挡减伤 %d，伤害变为 %d。" % [target + 1, guard_value, reduced_amount])
	if reduced_amount <= 0:
		return result
	if players[target].shield <= 0:
		result.hp_damage = _deal_life_damage(attacker, target, reduced_amount, skill_id)
	else:
		var shield_before = int(players[target].shield)
		if reduced_amount <= shield_before:
			players[target].shield -= reduced_amount
			result.shield_damage = reduced_amount
			_log("P%d 的护盾吸收 %d 伤害（剩余 %d）。" % [target + 1, reduced_amount, players[target].shield])
		else:
			result.broke_shield = true
			result.shield_damage = shield_before
			players[target].shield = 0
			var life_damage = break_life_damage + _augment_sum(players[attacker], "break_life_damage_bonus")
			_log("P%d 的护盾被击破，造成固定破盾生命伤害 %d。" % [target + 1, life_damage])
			result.hp_damage = _deal_life_damage(attacker, target, life_damage, skill_id)
	_check_game_over()
	return result


func _deal_life_damage(attacker: int, target: int, amount: int, _skill_id: String) -> int:
	var before = int(players[target].hp)
	players[target].hp -= amount
	var actual = before - int(players[target].hp)
	players[target].damage_taken_this_turn += actual
	players[attacker].dealt_damage_this_turn += actual
	_log("P%d 对 P%d 造成 %d 生命伤害（%d -> %d）。" % [attacker + 1, target + 1, amount, before, players[target].hp])
	_try_first_aid(target)
	_try_sword_spirit(attacker, actual)
	return actual


func _try_first_aid(player_id: int) -> void:
	var player: Dictionary = players[player_id]
	if _has_augment(player, "first_aid") and not bool(player.per_game_flags.get("first_aid_used", false)) and player.hp <= 30 and player.hp > 0:
		player.per_game_flags.first_aid_used = true
		player.hp = min(player.max_hp, player.hp + 15)
		players[player_id] = player
		_log("P%d 触发急救本能，回复 15 HP。" % [player_id + 1])


func _try_sword_spirit(attacker: int, hp_damage: int) -> void:
	if players[attacker].character_id == "swordsman" and attacker == attacker_id and hp_damage >= 20:
		_gain_shield(attacker, 10)
		_log("P%d 触发剑意激荡。" % [attacker + 1])


func _gain_shield(player_id: int, amount: int) -> void:
	if amount <= 0:
		return
	amount += _augment_sum(players[player_id], "shield_gain_bonus")
	var before = int(players[player_id].shield)
	players[player_id].shield = min(players[player_id].max_shield, players[player_id].shield + amount)
	_log("P%d 获得 %d 护盾（%d -> %d）。" % [player_id + 1, players[player_id].shield - before, before, players[player_id].shield])


func _add_status(player_id: int, status_id: String, duration: int, value: int) -> void:
	_remove_status(player_id, status_id)
	players[player_id].statuses.append({
		"id": status_id,
		"duration": duration,
		"value": value
	})
	_log("P%d 获得状态：%s。" % [player_id + 1, get_status_name(status_id)])


func _consume_guard(player_id: int) -> int:
	for index in range(players[player_id].statuses.size()):
		var status: Dictionary = players[player_id].statuses[index]
		if String(status.id) == "guard":
			var value = int(status.value)
			players[player_id].statuses.remove_at(index)
			return value
	return 0


func _has_status(player_id: int, status_id: String) -> bool:
	for status in players[player_id].statuses:
		if String(status.id) == status_id:
			return true
	return false


func _remove_status(player_id: int, status_id: String) -> void:
	for index in range(players[player_id].statuses.size() - 1, -1, -1):
		if String(players[player_id].statuses[index].id) == status_id:
			players[player_id].statuses.remove_at(index)


func _finish_round() -> void:
	for player_id in range(2):
		var refund = int(players[player_id].per_turn_flags.get("end_mp_refund", 0))
		if refund > 0:
			var before = int(players[player_id].mp)
			players[player_id].mp = min(players[player_id].max_mp, players[player_id].mp + refund)
			_log("P%d 回合末返还 %d MP（%d -> %d）。" % [player_id + 1, players[player_id].mp - before, before, players[player_id].mp])
		_clear_end_round_statuses(player_id)
	_check_game_over()
	if phase == PHASE_GAME_OVER:
		return
	attacker_id = _defender_id()
	round_num += 1
	phase = PHASE_BATTLE
	_begin_round(true)


func _clear_end_round_statuses(player_id: int) -> void:
	for index in range(players[player_id].statuses.size() - 1, -1, -1):
		var status_id = String(players[player_id].statuses[index].id)
		if status_id in ["guard", "immune", "sure_evasion"]:
			players[player_id].statuses.remove_at(index)


func _check_game_over() -> void:
	if players[0].hp <= 0 or players[1].hp <= 0:
		phase = PHASE_GAME_OVER
		if players[0].hp > 0 and players[1].hp <= 0:
			winner_id = 0
		elif players[1].hp > 0 and players[0].hp <= 0:
			winner_id = 1
		else:
			winner_id = -1
		if winner_id >= 0:
			_log("对局结束，P%d 获胜。" % [winner_id + 1])
		else:
			_log("对局结束，双方同时倒下。")


func restart_match() -> void:
	if phase != PHASE_GAME_OVER:
		return
	var selected = [players[0].character_id, players[1].character_id]
	var picked_augments = [players[0].augment_ids.duplicate(), players[1].augment_ids.duplicate()]
	reset_to_character_select()
	for player_id in range(2):
		select_character(player_id, selected[player_id])
	# Re-apply the same augment IDs for fast rematch when possible.
	for player_id in range(2):
		for augment_id in picked_augments[player_id]:
			var augment = _find_augment_for_player(player_id, String(augment_id))
			if not augment.is_empty():
				_apply_augment(player_id, augment)
		players[player_id].common_augment_picked = true
		players[player_id].character_augment_picked = true
	_start_battle()
	_log("再来一局：保留双方角色和强化。")


func to_snapshot() -> Dictionary:
	return {
		"phase": phase,
		"players": players.duplicate(true),
		"round_num": round_num,
		"attacker_id": attacker_id,
		"winner_id": winner_id,
		"logs": logs.duplicate(true),
		"pending_actions": pending_actions.duplicate(true),
		"augment_candidates": augment_candidates.duplicate(true),
		"pending_interactive_request": pending_interactive_request.duplicate(true)
	}


func apply_snapshot(snapshot: Dictionary) -> void:
	phase = String(snapshot.get("phase", PHASE_CHARACTER_SELECT))
	players = snapshot.get("players", [_empty_player(0), _empty_player(1)]).duplicate(true)
	round_num = int(snapshot.get("round_num", 0))
	attacker_id = int(snapshot.get("attacker_id", 0))
	winner_id = int(snapshot.get("winner_id", -1))
	logs = snapshot.get("logs", []).duplicate(true)
	pending_actions = snapshot.get("pending_actions", [{}, {}]).duplicate(true)
	augment_candidates = snapshot.get("augment_candidates", [{}, {}]).duplicate(true)
	pending_interactive_request = snapshot.get("pending_interactive_request", {}).duplicate(true)


func append_log(message: String) -> void:
	_log(message)


func _find_augment_for_player(player_id: int, augment_id: String) -> Dictionary:
	for augment in common_augments:
		if String(augment.id) == augment_id:
			return augment
	for augment in character_augments.get(players[player_id].character_id, []):
		if String(augment.id) == augment_id:
			return augment
	return {}


func get_skill(player_id: int, skill_id: String) -> Dictionary:
	if not _valid_player(player_id):
		return {}
	for skill in players[player_id].character.get("skills", []):
		if String(skill.id) == skill_id:
			return skill
	return {}


func get_allowed_skills(player_id: int) -> Array:
	if not _valid_player(player_id) or players[player_id].character.is_empty():
		return []
	var role_type = "attack" if player_id == attacker_id else "defense"
	var result = []
	for skill in players[player_id].character.get("skills", []):
		if String(skill.type) == role_type:
			result.append(skill)
	return result


func can_use_skill(player_id: int, skill: Dictionary, modes: Array = []) -> bool:
	return get_skill_block_reason(player_id, skill, modes) == ""


func get_skill_block_reason(player_id: int, skill: Dictionary, modes: Array = [], during_resolution: bool = false) -> String:
	if not _valid_player(player_id):
		return "玩家不存在"
	if not during_resolution and not players[player_id].submitted_action.is_empty():
		return "本回合已经提交行动"
	var expected_type = "attack" if player_id == attacker_id else "defense"
	if String(skill.type) != expected_type:
		return "当前身份不能使用该类型技能"
	if not DiceRulesScript.requirements_met(players[player_id].dice, skill.get("dice_requirements", [])):
		return "骰子需求不满足"
	if String(skill.id) == "archer_piercing_arrow" and int(players[player_id].dealt_damage_last_turn) > 0:
		return "上回合已经造成过伤害"
	if String(skill.id) == "archer_eagle_eye" and bool(players[player_id].per_game_flags.get("eagle_eye_used", false)):
		return "本局已经使用过鹰眼"
	var cost = get_skill_cost(player_id, skill, modes)
	if players[player_id].mp < cost:
		return "MP 不足（需要 %d）" % cost
	return ""


func get_skill_cost(player_id: int, skill: Dictionary, modes: Array = []) -> int:
	var base_cost = int(skill.get("cost", 0))
	if String(skill.id) == "archer_backstep" and players[player_id].hp <= 30:
		base_cost = 0
	var cost = base_cost
	for mode in modes:
		cost += _mode_extra_cost(skill, String(mode))
	for augment in players[player_id].augments:
		if String(augment.effect) == "skill_cost_delta" and String(augment.get("target_skill", "")) == String(skill.id):
			cost += int(augment.amount)
	if _has_augment(players[player_id], "precise_casting") and not bool(players[player_id].per_turn_flags.get("used_skill", false)):
		cost -= 10
	return max(0, cost)


func _mode_extra_cost(skill: Dictionary, mode_id: String) -> int:
	for mode in skill.get("modes", []):
		if String(mode.id) == mode_id:
			return int(mode.get("extra_cost", 0))
	return 0


func _mode_text(skill: Dictionary, modes: Array) -> String:
	if modes.is_empty():
		return ""
	var names = []
	for mode_id in modes:
		for mode in skill.get("modes", []):
			if String(mode.id) == String(mode_id):
				names.append(mode.name)
	return "（%s）" % ", ".join(names)


func _modified_damage(player_id: int, skill: Dictionary, base_amount: int) -> int:
	var amount = base_amount
	for augment in players[player_id].augments:
		if String(augment.effect) == "skill_damage_bonus" and String(augment.get("target_skill", "")) == String(skill.id):
			amount += int(augment.amount)
	amount += _augment_sum(players[player_id], "damage_bonus")
	if player_id == attacker_id and String(skill.type) == "attack" and _has_augment(players[player_id], "initiative_pressure") and not bool(players[player_id].per_turn_flags.get("first_attack_bonus_used", false)):
		amount += 10
		players[player_id].per_turn_flags.first_attack_bonus_used = true
	return max(0, amount)


func _modified_shield_gain(player_id: int, skill: Dictionary, base_amount: int) -> int:
	var amount = base_amount
	for augment in players[player_id].augments:
		if String(augment.effect) == "skill_shield_bonus" and String(augment.get("target_skill", "")) == String(skill.id):
			amount += int(augment.amount)
	return max(0, amount)


func _augment_sum(player: Dictionary, effect: String) -> int:
	var total = 0
	for augment in player.augments:
		if String(augment.effect) == effect:
			total += int(augment.amount)
	return total


func _has_augment(player: Dictionary, augment_id: String) -> bool:
	return player.get("augment_ids", []).has(augment_id)


func get_status_name(status_id: String) -> String:
	if status_effects.has(status_id):
		return String(status_effects[status_id].name)
	return status_id


func status_text(player_id: int) -> String:
	var names = []
	for status in players[player_id].statuses:
		names.append(get_status_name(String(status.id)))
	if bool(players[player_id].per_game_flags.get("eagle_eye", false)):
		names.append("鹰眼")
	return "无" if names.is_empty() else "、".join(names)


func augment_text(player_id: int) -> String:
	var names = []
	for augment in players[player_id].augments:
		names.append(String(augment.name))
	return "未选择" if names.is_empty() else "、".join(names)


func role_text(player_id: int) -> String:
	return "进攻方" if player_id == attacker_id else "防守方"


func _dice_text(dice: Array) -> String:
	var parts = []
	for die in dice:
		parts.append(str(die))
	return "[" + ", ".join(parts) + "]"


func _valid_player(player_id: int) -> bool:
	return player_id >= 0 and player_id < players.size()


func _log(message: String) -> void:
	logs.append(message)
	if logs.size() > 120:
		logs.pop_front()
