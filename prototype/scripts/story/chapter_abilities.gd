extends RefCounted
## Chapter I abilities: data-driven, stable IDs, persisted at village.abilities.
## An ability is earned only from saved story facts and is never removed again,
## so it stays usable in the free village after its mission has ended.

const CATALOG_PATH := "res://assets/story/chapter1_abilities.json"
const VERSION := 1
static var _catalog: Array = []


static func catalog() -> Array:
	if _catalog.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("abilities")) == TYPE_ARRAY:
			_catalog = parsed.abilities
	return _catalog


static func ids() -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in catalog():
		result.append(str(entry.id))
	return result


static func entry(id: String) -> Dictionary:
	for item: Dictionary in catalog():
		if item.id == id:
			return item
	return {}


## Abilities proven by the saved childhood facts, in catalog order.
static func derive(data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var child: Variant = data.get("village", {}).get("childhood")
	if typeof(child) != TYPE_DICTIONARY:
		return result
	var completed: Variant = child.get("completed", [])
	var screenplay: Variant = child.get("screenplay", {})
	for item: Dictionary in catalog():
		var grant: Dictionary = item.grant
		var earned := false
		if grant.has("completed"):
			earned = typeof(completed) == TYPE_ARRAY and completed.has(grant.completed)
		elif grant.has("screenplay_flag"):
			earned = typeof(screenplay) == TYPE_DICTIONARY and screenplay.get(grant.screenplay_flag, false) == true
		if earned:
			result.append(str(item.id))
	return result


## Adds the ability record to saves that predate it (schema v5 stays v5).
static func ensure(data: Dictionary) -> void:
	if typeof(data.get("village")) != TYPE_DICTIONARY or data.village.has("abilities"):
		return
	data.village.abilities = {"version":VERSION, "earned":derive(data)}


## Appends newly proven abilities. Never removes an earned one.
static func sync(data: Dictionary) -> Array[String]:
	var added: Array[String] = []
	ensure(data)
	if typeof(data.get("village")) != TYPE_DICTIONARY:
		return added
	var earned: Array = data.village.abilities.earned
	for id: String in derive(data):
		if not earned.has(id):
			earned.append(id)
			added.append(id)
	return added


static func has(data: Dictionary, id: String) -> bool:
	var record: Variant = data.get("village", {}).get("abilities")
	return typeof(record) == TYPE_DICTIONARY and typeof(record.get("earned")) == TYPE_ARRAY and record.earned.has(id)


static func effect_value(data: Dictionary, effect_type: String) -> float:
	var total := 0.0
	for item: Dictionary in catalog():
		if item.effect.type == effect_type and has(data, item.id):
			total += float(item.effect.value)
	return total


static func names(data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var record: Variant = data.get("village", {}).get("abilities")
	if typeof(record) != TYPE_DICTIONARY:
		return result
	for id in record.get("earned", []):
		var item := entry(str(id))
		if not item.is_empty():
			result.append(str(item.name))
	return result


static func validate(data: Dictionary) -> String:
	var record: Variant = data.get("village", {}).get("abilities")
	if record == null:
		return ""
	if typeof(record) != TYPE_DICTIONARY or record.size() != 2 or not record.has("version") or not record.has("earned"):
		return "Ungültiger Fähigkeitenbereich."
	if typeof(record.version) not in [TYPE_INT, TYPE_FLOAT] or int(record.version) != VERSION or typeof(record.earned) != TYPE_ARRAY:
		return "Unbekannte Fähigkeitenversion."
	var known := ids()
	var seen := {}
	for id: Variant in record.earned:
		if typeof(id) != TYPE_STRING or not known.has(id) or seen.has(id):
			return "Unbekannte oder doppelte Fähigkeit."
		seen[id] = true
	# Facts that prove an ability must never be outrun by a missing entry.
	for id: String in derive(data):
		if not seen.has(id):
			return "Eine belegte Fähigkeit fehlt im Spielstand."
	return ""
