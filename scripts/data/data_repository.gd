extends RefCounted
class_name DataRepository

const CHARACTER_IDS = ["swordsman", "archer", "witch_doctor", "pyromancer", "arcanist", "vampire"]

static func load_json(path: String) -> Variant:
	var raw = FileAccess.get_file_as_string(path)
	if raw.is_empty():
		push_error("Failed to read JSON: %s" % path)
		return null
	var parsed = JSON.parse_string(raw)
	if parsed == null:
		push_error("Failed to parse JSON: %s" % path)
	return parsed


static func load_characters() -> Dictionary:
	var result = {}
	for character_id in CHARACTER_IDS:
		var data = load_json("res://data/characters/%s.json" % character_id)
		if data != null:
			result[character_id] = data
	return result


static func load_common_augments() -> Array:
	var data = load_json("res://data/augments_common.json")
	return data if data is Array else []


static func load_character_augments() -> Dictionary:
	var data = load_json("res://data/augments_character.json")
	return data if data is Dictionary else {}


static func load_status_effects() -> Dictionary:
	var result = {}
	var data = load_json("res://data/status_effects.json")
	if data is Array:
		for item in data:
			result[item.id] = item
	return result
