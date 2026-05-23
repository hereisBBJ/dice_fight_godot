extends RefCounted
class_name DiceRules

static func roll_dice(rng: RandomNumberGenerator, count: int = 4) -> Array:
	var dice = []
	for _i in range(count):
		dice.append(rng.randi_range(1, 6))
	return sort_desc(dice)


static func sort_desc(dice: Array) -> Array:
	var result = dice.duplicate()
	result.sort()
	result.reverse()
	return result


static func requirements_met(dice: Array, requirements: Array) -> bool:
	if requirements == null or requirements.is_empty():
		return true
	var used = []
	used.resize(dice.size())
	used.fill(false)
	return _match_requirement(0, requirements, dice, used)


static func requirements_met_with_ignore(dice: Array, requirements: Array, ignore_count: int) -> bool:
	if requirements == null or requirements.is_empty():
		return true
	if ignore_count <= 0:
		return requirements_met(dice, requirements)
	var used = []
	used.resize(dice.size())
	used.fill(false)
	return _match_requirement_with_ignore(0, requirements, dice, used, ignore_count)


static func _match_requirement_with_ignore(index: int, requirements: Array, dice: Array, used: Array, ignore_count: int) -> bool:
	if index >= requirements.size():
		return true
	if ignore_count > 0 and _match_requirement_with_ignore(index + 1, requirements, dice, used, ignore_count - 1):
		return true
	for die_index in range(dice.size()):
		if used[die_index]:
			continue
		if matches_requirement(int(dice[die_index]), requirements[index]):
			used[die_index] = true
			if _match_requirement_with_ignore(index + 1, requirements, dice, used, ignore_count):
				return true
			used[die_index] = false
	return false


static func _match_requirement(index: int, requirements: Array, dice: Array, used: Array) -> bool:
	if index >= requirements.size():
		return true
	for die_index in range(dice.size()):
		if used[die_index]:
			continue
		if matches_requirement(int(dice[die_index]), requirements[index]):
			used[die_index] = true
			if _match_requirement(index + 1, requirements, dice, used):
				return true
			used[die_index] = false
	return false


static func matches_requirement(value: int, requirement: Variant) -> bool:
	if requirement is int or requirement is float:
		return value >= int(requirement)
	if not requirement is String:
		return false
	var text = String(requirement).strip_edges().to_lower()
	if text == "odd" or text == "奇数":
		return value % 2 == 1
	if text == "even" or text == "偶数":
		return value % 2 == 0
	if text == "any" or text == "任意":
		return true
	if text.begins_with("="):
		return value == int(text.substr(1))
	var dash_index = text.find("-")
	if dash_index > 0:
		var left = int(text.substr(0, dash_index))
		var right = int(text.substr(dash_index + 1))
		return value >= left and value <= right
	if text.is_valid_int():
		return value >= int(text)
	return false
