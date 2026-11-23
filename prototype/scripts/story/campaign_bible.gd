extends RefCounted
## Read-only access to the authored four-volume IMPERATHEN campaign order.
##
## The registry is descriptive. It never completes missions or unlocks
## historical divergences; authoritative runtime state remains in WorldModel.

const PATH := "res://assets/story/campaign_arc.json"

static var _loaded := false
static var _data: Dictionary = {}
static var _missions: Dictionary = {}
static var _side_quests: Dictionary = {}


static func project() -> String:
	_load()
	return str(_data.get("project", ""))


static func rules() -> Dictionary:
	_load()
	return (_data.get("campaign_rules", {}) as Dictionary).duplicate(true)


static func canonical_actor(role: String) -> Dictionary:
	_load()
	var cast: Dictionary = _data.get("canonical_childhood_cast", {})
	if not cast.has(role):
		return {}
	return (cast[role] as Dictionary).duplicate(true)


static func mission(mission_id: String) -> Dictionary:
	_load()
	if not _missions.has(mission_id):
		return {}
	return (_missions[mission_id] as Dictionary).duplicate(true)


static func side_quest(quest_id: String) -> Dictionary:
	_load()
	if not _side_quests.has(quest_id):
		return {}
	return (_side_quests[quest_id] as Dictionary).duplicate(true)


static func band(number: int) -> Dictionary:
	_load()
	for value: Variant in _data.get("bands", []):
		if value is Dictionary and int(value.get("band", 0)) == number:
			return (value as Dictionary).duplicate(true)
	return {}


static func main_mission_count() -> int:
	_load()
	return _missions.size()


static func side_quest_count() -> int:
	_load()
	return _side_quests.size()


static func reset_cache_for_tests() -> void:
	_loaded = false
	_data.clear()
	_missions.clear()
	_side_quests.clear()


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_data.clear()
	_missions.clear()
	_side_quests.clear()
	if not FileAccess.file_exists(PATH):
		push_error("Campaign bible missing: " + PATH)
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("Campaign bible cannot be opened: " + PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Campaign bible is not a JSON object")
		return
	_data = (parsed as Dictionary).duplicate(true)
	for band_value: Variant in _data.get("bands", []):
		if not band_value is Dictionary:
			continue
		var band_data := band_value as Dictionary
		var band_number := int(band_data.get("band", 0))
		for mission_value: Variant in band_data.get("main_missions", []):
			if mission_value is Dictionary:
				var row := (mission_value as Dictionary).duplicate(true)
				var mission_id := str(row.get("id", ""))
				if not mission_id.is_empty() and not _missions.has(mission_id):
					row["band"] = band_number
					_missions[mission_id] = row
		for quest_value: Variant in band_data.get("side_quests", []):
			if quest_value is Dictionary:
				var row := (quest_value as Dictionary).duplicate(true)
				var quest_id := str(row.get("id", ""))
				if not quest_id.is_empty() and not _side_quests.has(quest_id):
					row["band"] = band_number
					_side_quests[quest_id] = row
