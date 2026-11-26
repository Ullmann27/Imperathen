extends RefCounted
## Begleitregie aus Missionsmetadaten. Fortschritt und Beziehung stammen aus
## vorhandenen Save-Fakten; dieses Modul erzeugt keinen weiteren Spielstand.

const MissionData = preload("res://scripts/story/mission_data.gd")
const MISSIONS := ["I-04", "I-06", "I-08", "I-09"]
const ACTORS := ["marcus", "silvanus"]
static var _catalog: Dictionary = {}
static var _tasks: Dictionary = {}


static func _entries() -> Dictionary:
	if _catalog.is_empty():
		for mission: String in MISSIONS:
			var source := MissionData._json(MissionData.ROOT + "band1/" + mission + ".json")
			_catalog[mission] = source.get("companions", [])
			_tasks.merge(source.get("party_tasks", {}).get("steps", {}))
	return _catalog


static func actor_uid(data: Dictionary, id: String) -> String:
	return "pc:companion" if id in ["marcus", str(data.get("companion", {}).get("id", ""))] else "vil:" + id


static func member(data: Dictionary, id: String) -> Dictionary:
	return data.get("world_state", {}).get("party", {}).get("members", {}).get(actor_uid(data, id), {})


static func available(data: Dictionary, id: String) -> bool:
	if not data.get("village", {}).has("childhood") and member(data, id).is_empty():
		return false
	if actor_uid(data, id) == "pc:companion":
		return bool(data.get("companion", {}).get("met", false))
	if id not in ACTORS and member(data, id).is_empty():
		return false
	for person: Dictionary in data.village.economy.people:
		if person.id == id:
			return bool(person.alive) and int(person.health) > 30 and person.assignment == "idle" and not data.village.get("militia", []).has(id)
	return false


static func task_roles(step: String) -> Dictionary:
	_entries()
	return _tasks.get(step, {})


## Only called inside the successful original mission transaction. The physical
## observations are supplied by GameWorld, never by the issuing UI command.
static func credit(data: Dictionary, step: String, site: Vector2) -> String:
	var roles := task_roles(step)
	if roles.is_empty():
		return ""
	var feedback := PackedStringArray()
	var members: Dictionary = data.get("world_state", {}).get("party", {}).get("members", {})
	for uid: String in members:
		var id := str(data.companion.id) if uid == "pc:companion" else uid.trim_prefix("vil:")
		var person: Dictionary = members[uid]
		var role := str(person.assignment)
		if person.status != "active" or person.order != "assist" or not roles.has(role):
			continue
		var observed: Variant = observed_position(data, id)
		if observed == null or site.distance_to(observed) > 3.5:
			continue
		var details: Array = roles[role]
		var skill := str(details[0])
		var memory := "%s · %s" % [step, details[1]]
		if person.memories.has(memory):
			continue
		person.skills[skill] = mini(100, int(person.skills.get(skill, 0)) + 1)
		person.bond = mini(100, int(person.bond) + 1)
		person.memories.append(memory)
		if person.memories.size() > 32:
			person.memories.pop_front()
		feedback.append("%s %s." % [id.capitalize(), details[1]])
	return " ".join(feedback)


static func for_step(data: Dictionary, mission: String, step: String) -> Dictionary:
	var result := {}
	for entry: Dictionary in _entries().get(mission, []):
		var id := str(entry.get("id", ""))
		var membership := member(data, id)
		if not membership.is_empty() and (membership.status != "active" or membership.order in ["wait", "home", "train"]):
			continue
		if available(data, id) and entry.get("steps", []).has(step):
			result[id] = entry.duplicate(true)
	return result


static func tone(data: Dictionary, id: String) -> String:
	if id != "marcus":
		return "neutral"
	# Die konkrete I-03-Entscheidung zählt, nicht ein später veränderbarer Wert.
	var choice := str(data.get("companion", {}).get("choice", ""))
	return "friend" if choice == "help" else ("rival" if choice == "decline" else "neutral")


static func dialogue(data: Dictionary, id: String, mission: String, step: String) -> Dictionary:
	var entries := for_step(data, mission, step)
	if not entries.has(id):
		return {}
	var entry: Dictionary = entries[id]
	var variants: Dictionary = entry.get("dialogue", {})
	var manner := tone(data, id)
	var line: Dictionary = variants.get(manner, variants.get("neutral", {}))
	if line.is_empty():
		return {}
	var label: String = {"friend":"vertraut", "rival":"zurückhaltend", "neutral":"ruhig"}[manner]
	return {"title":"%s · %s" % ["Marcus" if id == "marcus" else "Silvanus", label],
		"text":"»%s«" % str(line.text), "choices":[], "tone":manner,
		"source":str(line.source), "companion_dialogue":true}


static func _coordinates(data: Dictionary, id: String) -> Array:
	if not available(data, id):
		return []
	var observed: Dictionary = data.village.get("behavior", {}).get("people", {}).get(id, {})
	if observed.get("observed", false):
		return observed.position
	return member(data, id).get("travel_position", [])


static func observed_position(data: Dictionary, id: String) -> Variant:
	var coordinates := _coordinates(data, id)
	return Vector2(coordinates[0], coordinates[2]) if coordinates.size() == 3 else null


static func restored_position(data: Dictionary, id: String, fallback: Vector3) -> Vector3:
	var coordinates := _coordinates(data, id)
	if coordinates.size() != 3:
		return fallback
	# Observations measure the common friend's centre, the other residents' feet.
	var centre_height := 0.9 if actor_uid(data, id) == "pc:companion" else 0.0
	return Vector3(coordinates[0], coordinates[1] - centre_height, coordinates[2])


static func display_name(data: Dictionary, id: String, fallback: String) -> String:
	return "Wachmann" if id == "severus" and data.get("village", {}).has("childhood") else fallback
