extends RefCounted
## Begleitregie aus Missionsmetadaten. Fortschritt und Beziehung stammen aus
## vorhandenen Save-Fakten; dieses Modul erzeugt keinen weiteren Spielstand.

const MissionData = preload("res://scripts/story/mission_data.gd")
const MISSIONS := ["I-04", "I-06", "I-08", "I-09"]
const ACTORS := ["marcus", "silvanus"]
static var _catalog: Dictionary = {}


static func _entries() -> Dictionary:
	if _catalog.is_empty():
		for mission: String in MISSIONS:
			var source := MissionData._json(MissionData.ROOT + "band1/" + mission + ".json")
			_catalog[mission] = source.get("companions", [])
	return _catalog


static func available(data: Dictionary, id: String) -> bool:
	if not data.get("village", {}).has("childhood") or id not in ACTORS:
		return false
	if id == "marcus":
		return bool(data.get("companion", {}).get("met", false))
	for person: Dictionary in data.village.economy.people:
		if person.id == id:
			return bool(person.alive) and person.assignment == "idle" and not data.village.get("militia", []).has(id)
	return false


static func for_step(data: Dictionary, mission: String, step: String) -> Dictionary:
	var result := {}
	for entry: Dictionary in _entries().get(mission, []):
		var id := str(entry.get("id", ""))
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


static func observed_position(data: Dictionary, id: String) -> Variant:
	if not available(data, id):
		return null
	var observed: Dictionary = data.village.get("behavior", {}).get("people", {}).get(id, {})
	var coordinates: Variant = observed.get("position")
	if not observed.get("observed", false) or typeof(coordinates) != TYPE_ARRAY or coordinates.size() != 3:
		return null
	return Vector2(float(coordinates[0]), float(coordinates[2]))


static func restored_position(data: Dictionary, id: String, fallback: Vector3) -> Vector3:
	if observed_position(data, id) == null:
		return fallback
	var coordinates: Array = data.village.behavior.people[id].position
	# Marcus' vorhandene Beobachtungen speichern seit Build 7 den Figurenmittelpunkt.
	# Diese Konvention bleibt erhalten; nur der bewegliche Körper hat einen Fußursprung.
	return Vector3(float(coordinates[0]), float(coordinates[1]) - (0.9 if id == "marcus" else 0.0), float(coordinates[2]))


static func display_name(data: Dictionary, id: String, fallback: String) -> String:
	return "Wachmann" if id == "severus" and data.get("village", {}).has("childhood") else fallback
