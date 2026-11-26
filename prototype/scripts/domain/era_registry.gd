extends RefCounted
## Era registry: date ranges for content (buildings, equipment families, troop
## entries, clothing, political and regional states, calendar rules, anchors).
##
## Pure queries against res://assets/world/era_registry.json; nothing here
## changes the world. Dates use WorldCalendar (historical signed years, no
## year 0, JDN instants). A bare year as "from" starts on 1 January, as "to"
## ends on 31 December. A marked divergence (override with divergence_id) is
## the only way to change a window at runtime; unknown content is never
## available (callers decide their own fallback explicitly).

const Calendar = preload("res://scripts/domain/world_calendar.gd")
const PATH := "res://assets/world/era_registry.json"
const FORMAT := "imperathen-era-registry"
const SCHEMA := 1
const KINDS := ["building", "equipment_family", "troop_entry", "clothing", "political_state", "region_state", "calendar_rule", "historical_anchor"]
const STATUSES := ["documented", "authored_default", "provisional"]
const SOURCE_CHECKS := ["handbook", "repo", "literature_unverified", "none"]
## Window bound meaning "open" (no start or no end).
const OPEN := -1
const ID_CHARACTERS := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-"

static var _loaded := false
static var _registry: Dictionary = {}


static func registry() -> Dictionary:
	if not _loaded:
		_loaded = true
		var parsed: Variant = null
		if FileAccess.file_exists(PATH):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_registry = build(parsed if parsed is Dictionary else {})
	return _registry


static func reset_cache_for_tests() -> void:
	_loaded = false
	_registry = {}


static func build(data: Dictionary) -> Dictionary:
	## Validates registry data and builds the query index. Invalid data yields
	## ok = false with every error listed; queries on it find nothing.
	var errors: Array[String] = []
	var result := {"ok": false, "errors": errors, "entries": {}, "aliases": {}, "order": []}
	if data.get("format") != FORMAT or not _int_like(data.get("schema")) or int(data.schema) != SCHEMA:
		errors.append("unknown registry format or schema")
		return result
	var list: Variant = data.get("entries")
	if not list is Array:
		errors.append("entries missing")
		return result
	var entries := {}
	var aliases := {}
	var slots := {}
	for value: Variant in list:
		if not value is Dictionary:
			errors.append("entry is not an object")
			continue
		var entry: Dictionary = value
		var id := str(entry.get("id", ""))
		if not _valid_id(id):
			errors.append("invalid id '%s'" % id)
			continue
		if entries.has(id) or aliases.has(id):
			errors.append("duplicate id %s" % id)
			continue
		if entry.get("kind") not in KINDS:
			errors.append("%s has unknown kind" % id)
			continue
		if entry.get("status") not in STATUSES or entry.get("source_check") not in SOURCE_CHECKS:
			errors.append("%s has unknown status or source_check" % id)
			continue
		if typeof(entry.get("source")) != TYPE_STRING or (entry.status == "documented" and (str(entry.source).strip_edges().is_empty() or entry.source_check == "none")):
			errors.append("%s is documented without a source" % id)
			continue
		var start := _bound(entry.get("from", null), true)
		var finish := _bound(entry.get("to", null), false)
		if start.has("error") or finish.has("error"):
			errors.append("%s: %s" % [id, str(start.get("error", finish.get("error", "")))])
			continue
		if int(start.jdn) != OPEN and int(finish.jdn) != OPEN and int(start.jdn) > int(finish.jdn):
			errors.append("%s: from is after to" % id)
			continue
		var clean := entry.duplicate(true)
		clean["from_jdn"] = int(start.jdn)
		clean["to_jdn"] = int(finish.jdn)
		entries[id] = clean
		for alias: Variant in entry.get("aliases", []):
			var name := str(alias)
			if not _valid_id(name) or entries.has(name) or aliases.has(name) or name == id:
				errors.append("%s has an invalid or duplicate alias '%s'" % [id, name])
				continue
			aliases[name] = id
		if entry.has("slot"):
			if typeof(entry.slot) != TYPE_STRING or not _valid_id(entry.slot):
				errors.append("%s has an invalid slot" % id)
				continue
			if not slots.has(entry.slot):
				slots[entry.slot] = []
			slots[entry.slot].append(id)
	for name: String in aliases:
		if entries.has(name):
			errors.append("alias %s collides with an id" % name)
	for slot: String in slots:
		var members: Array = slots[slot]
		for i in members.size():
			for j in range(i + 1, members.size()):
				if _overlap(entries[members[i]], entries[members[j]]):
					errors.append("slot %s: %s overlaps %s" % [slot, members[i], members[j]])
	var order: Array = entries.keys()
	order.sort()
	result.entries = entries
	result.aliases = aliases
	result.order = order
	result.ok = errors.is_empty()
	if not result.ok:
		result.entries = {}
		result.aliases = {}
		result.order = []
	return result


static func validate_data(data: Dictionary) -> Array:
	return build(data).errors


static func resolve(content_id: String, reg: Dictionary = {}) -> String:
	var index := _index(reg)
	if index.entries.has(content_id):
		return content_id
	return str(index.aliases.get(content_id, ""))


static func entry(content_id: String, reg: Dictionary = {}) -> Dictionary:
	var id := resolve(content_id, reg)
	return (_index(reg).entries[id] as Dictionary).duplicate(true) if not id.is_empty() else {}


static func window(content_id: String, overrides: Dictionary = {}, reg: Dictionary = {}) -> Dictionary:
	## {"from_jdn", "to_jdn"} with OPEN for open ends; empty for unknown,
	## suppressed or invalidly overridden content.
	var id := resolve(content_id, reg)
	if id.is_empty():
		return {}
	var item: Dictionary = _index(reg).entries[id]
	var result := {"from_jdn": int(item.from_jdn), "to_jdn": int(item.to_jdn)}
	var change: Variant = overrides.get(id, overrides.get(content_id, null))
	if change == null:
		return result
	if not _override_errors(change).is_empty() or bool(change.get("suppressed", false)):
		return {}
	if change.has("from"):
		result.from_jdn = int(_bound(change.from, true).jdn)
	if change.has("to"):
		result.to_jdn = int(_bound(change.to, false).jdn)
	if result.from_jdn != OPEN and result.to_jdn != OPEN and result.from_jdn > result.to_jdn:
		return {}
	return result


static func available(content_id: String, jdn: int, overrides: Dictionary = {}, reg: Dictionary = {}) -> bool:
	var span := window(content_id, overrides, reg)
	if span.is_empty() or jdn < 0:
		return false
	return (int(span.from_jdn) == OPEN or jdn >= int(span.from_jdn)) and (int(span.to_jdn) == OPEN or jdn <= int(span.to_jdn))


static func active(kind: String, jdn: int, overrides: Dictionary = {}, reg: Dictionary = {}) -> Array:
	var ids := []
	var index := _index(reg)
	for id: String in index.order:
		if index.entries[id].kind == kind and available(id, jdn, overrides, reg):
			ids.append(id)
	return ids


static func state_at(slot: String, jdn: int, overrides: Dictionary = {}, reg: Dictionary = {}) -> String:
	## The single active entry of an exclusive slot, or "" when none applies.
	var index := _index(reg)
	for id: String in index.order:
		if index.entries[id].get("slot", "") == slot and available(id, jdn, overrides, reg):
			return id
	return ""


static func changes_between(from_jdn: int, to_jdn: int, overrides: Dictionary = {}, reg: Dictionary = {}) -> Array:
	## Era transitions in the half-open interval (from_jdn, to_jdn]: "begins" on
	## the first available day, "ends" on the first day no longer available.
	## Sorted by day, then id; this is the hook for world ticks and time jumps.
	var changes := []
	if to_jdn <= from_jdn:
		return changes
	var index := _index(reg)
	for id: String in index.order:
		var span := window(id, overrides, reg)
		if span.is_empty():
			continue
		var begins := int(span.from_jdn)
		if begins != OPEN and begins > from_jdn and begins <= to_jdn:
			changes.append({"jdn": begins, "id": id, "kind": index.entries[id].kind, "change": "begins"})
		var ends := int(span.to_jdn) + 1 if int(span.to_jdn) != OPEN else OPEN
		if ends != OPEN and ends > from_jdn and ends <= to_jdn:
			changes.append({"jdn": ends, "id": id, "kind": index.entries[id].kind, "change": "ends"})
	changes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.jdn) < int(b.jdn) or (int(a.jdn) == int(b.jdn) and (str(a.id) < str(b.id) or (a.id == b.id and str(a.change) < str(b.change)))))
	return changes


static func validate_overrides(overrides: Dictionary, reg: Dictionary = {}) -> Array:
	var errors := []
	for content_id: Variant in overrides:
		if resolve(str(content_id), reg).is_empty():
			errors.append("override for unknown content %s" % str(content_id))
			continue
		for message: String in _override_errors(overrides[content_id]):
			errors.append("%s: %s" % [str(content_id), message])
	return errors


# --- Hooks for other systems --------------------------------------------------------

static func era_min_visible(era_min_year: int, jdn: int) -> bool:
	## City builder GLB extras carry era_min_ce as a historical signed year
	## (-46 = 46 v. Chr.). Year 0 is invalid and never visible.
	if not Calendar.is_valid_year(era_min_year) or jdn < 0:
		return false
	return jdn >= Calendar.first_day_of_year(era_min_year)


static func asset_available(play_mode: String, jdn: int, earliest_year: int, latest_year: int = 0) -> bool:
	## Calendar-based form of LifePathPolicy.asset_available (0 = no upper bound).
	if play_mode == "sandbox":
		return true
	if play_mode != "story" or jdn < 0 or not Calendar.is_valid_year(earliest_year):
		return false
	if latest_year != 0 and (not Calendar.is_valid_year(latest_year) or latest_year < earliest_year):
		return false
	return jdn >= Calendar.first_day_of_year(earliest_year) and (latest_year == 0 or jdn <= Calendar.last_day_of_year(latest_year))


static func filter_available(content_ids: Array, jdn: int, overrides: Dictionary = {}, reg: Dictionary = {}) -> Array:
	## Troop catalogs and shops: keep catalog order, drop unavailable or unknown ids.
	var result := []
	for content_id: Variant in content_ids:
		if available(str(content_id), jdn, overrides, reg):
			result.append(content_id)
	return result


# --- Internals ------------------------------------------------------------------------

static func _index(reg: Dictionary) -> Dictionary:
	return reg if reg.has("entries") else registry()


static func _bound(value: Variant, is_start: bool) -> Dictionary:
	if value == null:
		return {"jdn": OPEN}
	if _int_like(value):
		var year := int(value)
		if year == 0:
			return {"error": "year 0 does not exist"}
		if not Calendar.is_valid_year(year):
			return {"error": "year out of range"}
		return {"jdn": Calendar.first_day_of_year(year) if is_start else Calendar.last_day_of_year(year)}
	if value is Dictionary:
		if _int_like(value.get("year")) and int(value.year) == 0:
			return {"error": "year 0 does not exist"}
		var keys: Array = (value as Dictionary).keys()
		keys.sort()
		if keys != ["day", "month", "year"]:
			return {"error": "date needs exactly year, month and day"}
		var day := Calendar.date_to_jdn(value)
		if day == Calendar.INVALID:
			return {"error": "invalid date"}
		return {"jdn": day}
	return {"error": "bound must be null, a year or a date"}


static func _override_errors(change: Variant) -> Array:
	var errors := []
	if not change is Dictionary:
		return ["override is not an object"]
	if typeof(change.get("divergence_id")) != TYPE_STRING or str(change.divergence_id).strip_edges().is_empty():
		errors.append("override needs a marked divergence_id")
	for key: String in ["from", "to"]:
		if change.has(key) and _bound(change[key], key == "from").has("error"):
			errors.append("invalid %s" % key)
	if change.has("suppressed") and typeof(change.suppressed) != TYPE_BOOL:
		errors.append("suppressed must be a boolean")
	return errors


static func _overlap(a: Dictionary, b: Dictionary) -> bool:
	var a_from := -INF if int(a.from_jdn) == OPEN else float(a.from_jdn)
	var a_to := INF if int(a.to_jdn) == OPEN else float(a.to_jdn)
	var b_from := -INF if int(b.from_jdn) == OPEN else float(b.from_jdn)
	var b_to := INF if int(b.to_jdn) == OPEN else float(b.to_jdn)
	return a_from <= b_to and b_from <= a_to


static func _valid_id(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or str(value).is_empty() or str(value).length() > 96:
		return false
	for character in str(value):
		if not ID_CHARACTERS.contains(character):
			return false
	return true


static func _int_like(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))
