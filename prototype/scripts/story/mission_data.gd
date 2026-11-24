extends RefCounted
## Loads authored mission steps from res://assets/story/missions/<band>/.
## One file per mission, stable step IDs. The step order across files is
## save-relevant (childhood.completed indices) and comes from index.json.

const ROOT := "res://assets/story/missions/"
const SCHEMA_VERSION := 1
## Keys that describe a step's metadata, not its runtime dictionary.
const META_KEYS := ["source_mission", "carried"]


static func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("schema_version", 0)) != SCHEMA_VERSION:
		push_error("Mission data missing or unsupported: " + path)
		return {}
	return parsed


static func mission_files(band: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var index := _json(ROOT + band + "/index.json")
	for mission_id: Variant in index.get("order", []):
		var data := _json(ROOT + band + "/" + str(mission_id) + ".json")
		if data.get("mission", "") != str(mission_id):
			push_error("Mission file does not match its index entry: " + str(mission_id))
			continue
		result.append(data)
	return result


static func raw_steps(band: String) -> Array:
	var result := []
	for mission: Dictionary in mission_files(band):
		for step: Dictionary in mission.get("steps", []):
			result.append(step)
	return result


## Runtime step dictionaries, identical to the former hard-coded STEPS.
static func steps(band: String) -> Array:
	var result := []
	for step: Dictionary in raw_steps(band):
		var runtime := step.duplicate(true)
		for key: String in META_KEYS:
			runtime.erase(key)
		result.append(runtime)
	return result


static func carried_effects(band: String) -> Dictionary:
	var result := {}
	for step: Dictionary in raw_steps(band):
		if step.has("carried"):
			result[step.id] = step.carried.duplicate(true)
	return result


static func source_missions(band: String) -> Dictionary:
	var result := {}
	for step: Dictionary in raw_steps(band):
		if step.has("source_mission"):
			result[step.id] = step.source_mission
	return result


## Brücken besitzen einen eigenen gespeicherten Status und gehören deshalb
## niemals in die durch childhood.completed indizierte steps-Liste.
static func bridge_steps(band: String) -> Dictionary:
	var result := {}
	for mission: Dictionary in mission_files(band):
		for step: Dictionary in mission.get("bridges", []):
			var id := str(step.get("id", ""))
			if id.is_empty() or result.has(id) or step.get("mission", "") != mission.mission or step.get("screenplay", false) != true:
				push_error("Ungültiger oder doppelter Missionsbrückenschritt: " + id)
				return {}
			result[id] = step.duplicate(true)
	return result
