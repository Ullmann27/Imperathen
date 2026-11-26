extends RefCounted
## Activity anchors: the places city residents use, as data.
##
## One JSON file per area in res://assets/city/activity_anchors/<area>.json.
## Other work packages (Colosseum plaza, architecture families, street
## decoration) only add data files; this script owns schema, loading and
## validation. A file is either a bare array of entries or an object
## {"format": FORMAT, "schema": SCHEMA, "area": "...", "anchors": [entries]}.
##
## Entry: {id, kind, position:[x,y,z], facing_deg, capacity, hours:[from,to],
##         era:{from_year,to_year}, wealth_tiers:[...], tags:[...]}
## - position is in Godot metres in the city scene (y up).
## - facing_deg: 0 looks along -Z, positive turns toward -X (Godot yaw).
## - hours are local clock hours 0..24; from > to wraps past midnight.
## - era years are historical integers: negative = BC, there is no year 0.
##   null means an open bound.
## - wealth_tiers lists who uses the place; all four tiers = everyone.
## - tags are free-form. Reserved prefixes understood by the simulation:
##     "requires_node:<Name>"  only usable when the scene node exists
##     "business:<type>"       stall/workshop trade type (see CityGoods)
##     "district:<name>"       grouping for households and patrols
##     "shelter"               roofed place used when it rains

const Calendar = preload("res://scripts/domain/world_calendar.gd")
const FORMAT := "imperathen-activity-anchors"
const SCHEMA := 1
const DIR := "res://assets/city/activity_anchors"
const KINDS := ["stall", "workshop", "bench", "fountain", "shrine", "gossip_spot", "tavern_seat",
	"doorway", "entrance", "seat_block", "queue", "cart_stop", "guard_post", "beggar_spot", "play_spot"]
const WEALTH_TIERS := ["poor", "common", "prosperous", "elite"]
const FIELDS := ["id", "kind", "position", "facing_deg", "capacity", "hours", "era", "wealth_tiers", "tags"]
const MAX_CAPACITY := 512
const MAX_COORDINATE := 4000.0
const ID_CHARACTERS := "abcdefghijklmnopqrstuvwxyz0123456789_.-"


## Validates one parsed file. Returns the normalised entries and every error.
static func parse_file(data: Variant, label: String) -> Dictionary:
	var errors: Array[String] = []
	var entries: Array[Dictionary] = []
	var list: Variant = data
	if data is Dictionary:
		if data.has("format") and data.format != FORMAT:
			errors.append("%s: unknown format" % label)
		if data.has("schema") and (not _is_int(data.schema) or int(data.schema) != SCHEMA):
			errors.append("%s: unknown schema" % label)
		list = data.get("anchors")
	if not list is Array:
		errors.append("%s: no anchor list" % label)
		return {"errors": errors, "entries": entries}
	for index in list.size():
		var problem := entry_error(list[index])
		if not problem.is_empty():
			errors.append("%s[%d]: %s" % [label, index, problem])
			continue
		entries.append(normalise(list[index]))
	return {"errors": errors, "entries": entries}


static func entry_error(value: Variant) -> String:
	if not value is Dictionary:
		return "entry is not an object"
	for field: String in FIELDS:
		if not value.has(field):
			return "missing field " + field
	for field: Variant in value:
		if not field in FIELDS:
			return "unknown field " + str(field)
	if typeof(value.id) != TYPE_STRING or value.id.is_empty() or value.id.length() > 96:
		return "id must be a non-empty string"
	for character: String in value.id:
		if not ID_CHARACTERS.contains(character):
			return "id %s has characters outside [a-z0-9_.-]" % value.id
	if not value.kind in KINDS:
		return "%s: unknown kind %s" % [value.id, str(value.kind)]
	if not value.position is Array or value.position.size() != 3:
		return "%s: position must be [x,y,z]" % value.id
	for coordinate: Variant in value.position:
		if not _is_number(coordinate) or absf(float(coordinate)) > MAX_COORDINATE:
			return "%s: position is not finite or outside the world" % value.id
	if not _is_number(value.facing_deg) or absf(float(value.facing_deg)) > 360.0:
		return "%s: facing_deg outside -360..360" % value.id
	if not _is_int(value.capacity) or int(value.capacity) < 1 or int(value.capacity) > MAX_CAPACITY:
		return "%s: capacity outside 1..%d" % [value.id, MAX_CAPACITY]
	if not value.hours is Array or value.hours.size() != 2:
		return "%s: hours must be [from,to]" % value.id
	for hour: Variant in value.hours:
		if not _is_number(hour) or float(hour) < 0.0 or float(hour) > 24.0:
			return "%s: hours outside 0..24" % value.id
	if float(value.hours[0]) == float(value.hours[1]):
		return "%s: hours describe an empty window" % value.id
	if not value.era is Dictionary or value.era.size() != 2 or not value.era.has_all(["from_year", "to_year"]):
		return "%s: era must be {from_year,to_year}" % value.id
	for bound: String in ["from_year", "to_year"]:
		var year: Variant = value.era[bound]
		if year == null:
			continue
		if not _is_int(year) or not Calendar.is_valid_year(int(year)):
			return "%s: era.%s is not a historical year (no year 0)" % [value.id, bound]
	if value.era.from_year != null and value.era.to_year != null \
			and Calendar.to_astronomical(int(value.era.from_year)) > Calendar.to_astronomical(int(value.era.to_year)):
		return "%s: era ends before it starts" % value.id
	if not value.wealth_tiers is Array or value.wealth_tiers.is_empty():
		return "%s: wealth_tiers must list at least one tier" % value.id
	var seen := {}
	for tier: Variant in value.wealth_tiers:
		if not tier in WEALTH_TIERS or seen.has(tier):
			return "%s: unknown or repeated wealth tier %s" % [value.id, str(tier)]
		seen[tier] = true
	if not value.tags is Array:
		return "%s: tags must be a list" % value.id
	for tag: Variant in value.tags:
		if typeof(tag) != TYPE_STRING or tag.is_empty() or tag.length() > 96:
			return "%s: tags must be non-empty strings" % value.id
	return ""


static func normalise(value: Dictionary) -> Dictionary:
	var tiers: Array[String] = []
	for tier: String in WEALTH_TIERS:
		if tier in value.wealth_tiers:
			tiers.append(tier)
	var tags: Array[String] = []
	for tag: String in value.tags:
		tags.append(tag)
	return {
		"id": str(value.id), "kind": str(value.kind),
		"position": Vector3(float(value.position[0]), float(value.position[1]), float(value.position[2])),
		"facing_deg": float(value.facing_deg), "capacity": int(value.capacity),
		"hours": [float(value.hours[0]), float(value.hours[1])],
		"era": {"from_year": null if value.era.from_year == null else int(value.era.from_year),
			"to_year": null if value.era.to_year == null else int(value.era.to_year)},
		"wealth_tiers": tiers, "tags": tags}


## Loads every *.json in the directory, in file-name order. Ids must be unique
## across all files. Invalid entries are reported and left out.
static func load_all(directory: String = DIR) -> Dictionary:
	var result := {"ok": false, "errors": [], "anchors": {}, "order": [], "files": []}
	var names: Array[String] = []
	var folder := DirAccess.open(directory)
	if folder == null:
		result.errors.append("anchor directory missing: " + directory)
		return result
	for name: String in folder.get_files():
		if name.ends_with(".json"):
			names.append(name)
	names.sort()
	for name: String in names:
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(directory.path_join(name))) != OK:
			result.errors.append("%s: JSON error in line %d: %s" % [name, parser.get_error_line(), parser.get_error_message()])
			continue
		var parsed := parse_file(parser.data, name)
		result.errors.append_array(parsed.errors)
		var area := name.get_basename()
		for entry: Dictionary in parsed.entries:
			if result.anchors.has(entry.id):
				result.errors.append("%s: duplicate anchor id %s" % [name, entry.id])
				continue
			entry["area"] = area
			result.anchors[entry.id] = entry
			result.order.append(entry.id)
		result.files.append(name)
	result.order.sort()
	result.ok = result.errors.is_empty() and not result.anchors.is_empty()
	return result


static func in_era(anchor: Dictionary, year: int) -> bool:
	var at := Calendar.to_astronomical(year)
	var from: Variant = anchor.era.from_year
	var to: Variant = anchor.era.to_year
	if from != null and at < Calendar.to_astronomical(int(from)):
		return false
	return to == null or at <= Calendar.to_astronomical(int(to))


static func open_at(anchor: Dictionary, hour: float) -> bool:
	var from := float(anchor.hours[0])
	var to := float(anchor.hours[1])
	if from < to:
		return hour >= from and hour < to
	return hour >= from or hour < to


static func serves(anchor: Dictionary, tier: String) -> bool:
	return tier in anchor.wealth_tiers


static func tag_value(anchor: Dictionary, prefix: String) -> String:
	for tag: String in anchor.tags:
		if tag.begins_with(prefix + ":"):
			return tag.substr(prefix.length() + 1)
	return ""


static func has_tag(anchor: Dictionary, tag: String) -> bool:
	return tag in anchor.tags


## Ids usable in the given year. `present_nodes` answers "requires_node" tags:
## pass a Callable(name) -> bool, or leave empty to accept every requirement.
static func usable(index: Dictionary, year: int, present_nodes: Callable = Callable()) -> Array[String]:
	var ids: Array[String] = []
	for id: String in index.order:
		var anchor: Dictionary = index.anchors[id]
		if not in_era(anchor, year):
			continue
		var needed := tag_value(anchor, "requires_node")
		if not needed.is_empty() and present_nodes.is_valid() and not present_nodes.call(needed):
			continue
		ids.append(id)
	return ids


static func to_json_entry(anchor: Dictionary) -> Dictionary:
	var at: Vector3 = anchor.position
	return {"id": anchor.id, "kind": anchor.kind,
		"position": [snappedf(at.x, 0.001), snappedf(at.y, 0.001), snappedf(at.z, 0.001)],
		"facing_deg": snappedf(float(anchor.facing_deg), 0.1), "capacity": int(anchor.capacity),
		"hours": anchor.hours, "era": anchor.era, "wealth_tiers": anchor.wealth_tiers, "tags": anchor.tags}


static func _is_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _is_int(value: Variant) -> bool:
	return _is_number(value) and float(value) == floorf(float(value))
