extends RefCounted
## Read-only timeline of the 113 original mission sheets (year, age, place,
## canon kind, PDF page) and its validation against the owner's band ranges.
##
## The data is extracted literally from the Masterhandbuch 3.0 by
## tools/story/extract_mission_timeline.py. Nothing here repairs a value:
## validate() lists every inconsistency as a finding. Structural defects are
## errors; contradictions, notation differences and integration facts are
## findings with a severity. The registry never completes or unlocks missions.

const Calendar = preload("res://scripts/domain/world_calendar.gd")
const PATH := "res://assets/story/mission_timeline.json"
const FORMAT := "imperathen-mission-timeline"
const SCHEMA := 1
const MISSION_COUNT := 113
const BAND_ROMANS := ["I", "II", "III", "IV"]
const DATE_KINDS := ["exact_year", "exact_date", "split_year", "year_range", "open_after", "from_year", "alternative", "epilogue"]
## Kinds that sit on the campaign's chronological spine.
const SPINE_KINDS := ["exact_year", "exact_date", "split_year", "year_range", "open_after"]
const CANON_KINDS := ["HISTORICAL CORE", "HISTORICAL FRAME", "FICTIONAL THREAD", "FICTIONAL FRAME", "FICTIONAL ENDING", "COUNTERFACTUAL", "SYSTEMIC EPILOG"]
const SEVERITIES := ["conflict", "convention", "info"]
const REQUIRED := ["id", "band", "band_roman", "number", "title", "date_text", "date_kind", "year_from", "year_to", "date",
	"age_text", "age_min", "age_max", "age_open", "age_variable", "place", "canon_kind", "pdf_page", "sheet_page",
	"register_ref", "register_pdf_page", "continuity"]

static var _loaded := false
static var _data: Dictionary = {}
static var _by_id: Dictionary = {}


static func data() -> Dictionary:
	_load()
	return _data


static func mission(mission_id: String) -> Dictionary:
	_load()
	return (_by_id.get(mission_id, {}) as Dictionary).duplicate(true)


static func missions() -> Array:
	_load()
	return (_data.get("missions", []) as Array).duplicate(true)


static func band_missions(band: int) -> Array:
	var result := []
	for item: Dictionary in missions():
		if int(item.band) == band:
			result.append(item)
	return result


static func mission_window(mission_id: String) -> Dictionary:
	## Earliest and latest JDN of a mission's dated period; -1 marks an open end.
	var item := mission(mission_id)
	if item.is_empty() or item.year_from == null:
		return {}
	if item.date is Dictionary:
		var day := Calendar.date_to_jdn(item.date)
		return {"from_jdn": day, "to_jdn": day}
	var end := Calendar.INVALID if item.year_to == null else Calendar.last_day_of_year(int(item.year_to))
	return {"from_jdn": Calendar.first_day_of_year(int(item.year_from)), "to_jdn": end}


static func protected_ids() -> Array:
	var ids := []
	for item: Variant in data().get("protected_story_events", []):
		if item is Dictionary:
			ids.append(str(item.get("id", "")))
	return ids


static func reset_cache_for_tests() -> void:
	_loaded = false
	_data = {}
	_by_id = {}


static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


# --- Validation ---------------------------------------------------------------

static func validate(source: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var findings: Array[Dictionary] = []
	var report := {"ok": false, "errors": errors, "findings": findings, "birth_years": [], "birth_year": 0, "counts": {}}
	if source.get("format") != FORMAT or not _int_like(source.get("schema")) or int(source.schema) != SCHEMA:
		errors.append("unknown format or schema")
		return report
	var offset := int(source.get("page_offset", 0)) if _int_like(source.get("page_offset")) else 0
	var ranges := _band_ranges(source.get("band_ranges"), errors)
	var list: Variant = source.get("missions")
	if not list is Array:
		errors.append("missions missing")
		return report
	var by_id := {}
	var counts := {1: 0, 2: 0, 3: 0, 4: 0}
	for value: Variant in list:
		var item := _mission_errors(value, offset, errors)
		if item.is_empty():
			continue
		if by_id.has(item.id):
			errors.append("duplicate mission id %s" % item.id)
			continue
		by_id[item.id] = item
		counts[int(item.band)] += 1
	report.counts = counts
	if by_id.size() != MISSION_COUNT:
		errors.append("expected %d missions, found %d" % [MISSION_COUNT, by_id.size()])
	for band in range(1, 5):
		for number in counts[band]:
			if not by_id.has("%s-%02d" % [BAND_ROMANS[band - 1], number]):
				errors.append("band %s numbering has a gap at %02d" % [BAND_ROMANS[band - 1], number])
	if not errors.is_empty():
		return report
	var ordered := _ordered(by_id)
	_check_band_ranges(ordered, ranges, findings)
	var births := _birth_years(ordered, findings)
	report.birth_years = births
	report.birth_year = births[0] if births.size() == 1 else 0
	var start: Dictionary = source.get("protagonist", {})
	if _int_like(start.get("start_year")) and _int_like(start.get("start_age")):
		var expected := Calendar.birth_year_for_age(int(start.start_age), int(start.start_year))
		if expected not in births:
			findings.append(_finding("conflict", "start_age_birth_year", [], "Start %s mit Alter %d ergibt Geburtsjahr %s, die Missionsblätter erlauben %s." % [Calendar.format_year(int(start.start_year)), int(start.start_age), Calendar.format_year(expected), str(births)]))
	if report.birth_year != 0:
		_check_split_years(ordered, report.birth_year, findings)
		_check_birthday_window(ordered, report.birth_year, findings)
	_check_chronology(ordered, findings)
	_check_band_boundaries(ordered, findings)
	_check_time_jumps(ordered, findings)
	for item: Dictionary in ordered:
		if item.date_kind in ["alternative", "epilogue"]:
			findings.append(_finding("info", "undated", [item], "%s „%s“ trägt keine Jahresangabe (%s, Alter %s); Datum und Alter entstehen zur Laufzeit." % [item.id, item.title, item.date_text, item.age_text]))
	for protected: Variant in source.get("protected_story_events", []):
		if not protected is Dictionary or not by_id.has(str(protected.get("id", ""))):
			errors.append("protected story event references an unknown mission")
	report.ok = errors.is_empty()
	return report


static func finding_keys(report: Dictionary) -> Array:
	var keys := []
	for item: Dictionary in report.get("findings", []):
		keys.append(item.key)
	keys.sort()
	return keys


# --- Checks ---------------------------------------------------------------------

static func _check_band_ranges(ordered: Array, ranges: Dictionary, findings: Array[Dictionary]) -> void:
	for item: Dictionary in ordered:
		var band: Dictionary = ranges.get(int(item.band), {})
		if band.is_empty() or item.year_from == null:
			continue
		var low := int(band.from)
		var high := int(band.to)
		var first := int(item.year_from)
		if item.date_kind == "open_after":
			if first != high or not bool(band.get("sandbox_after", false)):
				findings.append(_finding("conflict", "outside_band_range", [item], "%s beginnt %s, Band %s endet %s ohne Sandbox." % [item.id, item.date_text, item.band_roman, Calendar.format_year(high)]))
			else:
				findings.append(_finding("info", "sandbox_open_end", [item], "%s gilt „%s“: Ende von Band %s mit anschließender Sandbox; Alter %s nur zum Eintritt." % [item.id, item.date_text, item.band_roman, item.age_text]))
			continue
		if item.date_kind == "from_year":
			var inside := first >= low and first <= high
			findings.append(_finding("info" if inside else "conflict", "counterfactual_open" if inside else "outside_band_range", [item], "%s (%s) gilt „%s“ mit Alter %s nur im Divergenzmodus." % [item.id, item.canon_kind, item.date_text, item.age_text]))
			continue
		if first < low or int(item.year_to) > high:
			findings.append(_finding("conflict", "outside_band_range", [item], "%s liegt mit %s außerhalb von Band %s (%s bis %s)." % [item.id, item.date_text, item.band_roman, Calendar.format_year(low), Calendar.format_year(high)]))


static func _birth_years(ordered: Array, findings: Array[Dictionary]) -> Array:
	## Feasible historical birth years under the sheet convention age = year - birth year.
	var feasible: Variant = null
	var votes := {}
	for item: Dictionary in ordered:
		if item.year_from == null or item.age_min == null:
			continue
		var candidates := _candidates(item)
		for birth: int in candidates:
			votes[birth] = int(votes.get(birth, 0)) + 1
		if feasible == null:
			feasible = candidates
		else:
			var next := []
			for birth: int in feasible:
				if birth in candidates:
					next.append(birth)
			feasible = next
	var result: Array = [] if feasible == null else feasible
	result.sort()
	if result.is_empty() and not votes.is_empty():
		var best := 0
		for birth: int in votes:
			if best == 0 or int(votes[birth]) > int(votes[best]):
				best = birth
		for item: Dictionary in ordered:
			if item.year_from != null and item.age_min != null and best not in _candidates(item):
				findings.append(_finding("conflict", "age_birth_year", [item], "%s (%s, Alter %s) passt nicht zum häufigsten Geburtsjahr %s." % [item.id, item.date_text, item.age_text, Calendar.format_year(best)]))
	return result


static func _candidates(item: Dictionary) -> Array:
	var first := int(item.year_from)
	var last := first if item.year_to == null else int(item.year_to)
	var low_age := int(item.age_min)
	var high_age := low_age + 120 if item.age_max == null else int(item.age_max)
	var result := []
	for span in Calendar.years_between(first, last) + 1:
		var year := Calendar.add_years(first, span)
		for age in range(low_age, high_age + 1):
			var birth := Calendar.birth_year_for_age(age, year)
			if Calendar.is_valid_year(birth) and birth not in result:
				result.append(birth)
	return result


static func _check_split_years(ordered: Array, birth: int, findings: Array[Dictionary]) -> void:
	## A split year ("57/56 v. Chr.") may name the age of either year. Both fit
	## one birth year; the less common notation is reported, never rewritten.
	var earlier := []
	var later := []
	for item: Dictionary in ordered:
		if item.date_kind != "split_year":
			continue
		if Calendar.age_in_year(birth, int(item.year_from)) == int(item.age_min):
			earlier.append(item)
		elif Calendar.age_in_year(birth, int(item.year_to)) == int(item.age_min):
			later.append(item)
	var minority_is_later := later.size() <= earlier.size()
	var minority := later if minority_is_later else earlier
	var majority_count := earlier.size() if minority_is_later else later.size()
	for item: Dictionary in minority:
		findings.append(_finding("convention", "split_year_age_convention", [item], "%s „%s“: Alter %s gilt nur für das %s Jahr; die %d übrigen Doppeljahresangaben nennen das Alter des %s Jahres. Beide Schreibweisen passen zum Geburtsjahr (%s)." % [item.id, item.date_text, item.age_text, "spätere" if minority_is_later else "frühere", majority_count, "früheren" if minority_is_later else "späteren", Calendar.format_year(birth)]))


static func _check_birthday_window(ordered: Array, birth: int, findings: Array[Dictionary]) -> void:
	var exact := []
	for item: Dictionary in ordered:
		if item.date is Dictionary and Calendar.age_in_year(birth, int(item.year_from)) == int(item.age_min):
			exact.append(item)
	if exact.is_empty():
		return
	var earliest: Dictionary = exact[0]
	for item: Dictionary in exact:
		if Calendar.date_to_jdn(item.date) < Calendar.date_to_jdn(earliest.date):
			earliest = item
	var limit: Dictionary = earliest.date
	var limit_text := "%d. %s" % [int(limit.day), Calendar.MONTH_NAMES_DE[int(limit.month) - 1]]
	findings.append(_finding("info", "birthday_window", exact, "Mit Geburtsjahr %s und Alter %s am %s liegt der Geburtstag zwischen 1. Januar und %s, sofern „ca.“ wörtlich gilt." % [Calendar.format_year(birth), earliest.age_text, Calendar.format_date(Calendar.date_to_jdn(limit)), limit_text]))


static func _check_chronology(ordered: Array, findings: Array[Dictionary]) -> void:
	var previous: Dictionary = {}
	for item: Dictionary in ordered:
		if item.date_kind not in SPINE_KINDS:
			continue
		if not previous.is_empty() and int(previous.band) == int(item.band) and Calendar.years_between(int(previous.year_from), int(item.year_from)) < 0:
			findings.append(_finding("conflict", "chronology_order", [previous, item], "%s (%s) steht nach %s (%s), liegt aber früher." % [item.id, item.date_text, previous.id, previous.date_text]))
		if not previous.is_empty() and int(previous.band) == int(item.band) and item.date is Dictionary and previous.date is Dictionary and Calendar.date_to_jdn(item.date) < Calendar.date_to_jdn(previous.date):
			findings.append(_finding("conflict", "chronology_order", [previous, item], "%s liegt vor %s." % [item.id, previous.id]))
		previous = item


static func _check_band_boundaries(ordered: Array, findings: Array[Dictionary]) -> void:
	for band in range(1, 4):
		var shared := {}
		for item: Dictionary in ordered:
			if item.date_kind not in SPINE_KINDS or int(item.band) not in [band, band + 1]:
				continue
			for span in Calendar.years_between(int(item.year_from), int(item.year_from if item.year_to == null else item.year_to)) + 1:
				var year := Calendar.add_years(int(item.year_from), span)
				if not shared.has(year):
					shared[year] = {}
				shared[year][int(item.band)] = true
		for year: int in shared:
			if (shared[year] as Dictionary).size() == 2:
				var involved := []
				for item: Dictionary in ordered:
					if int(item.band) in [band, band + 1] and item.date_kind in SPINE_KINDS and _covers(item, year):
						involved.append(item)
				var names := PackedStringArray()
				for item: Dictionary in involved:
					names.append(str(item.id))
				findings.append(_finding("info", "band_boundary_year", involved, "%s gehört zu Band %s und Band %s (%s); das Band folgt aus der Missions-ID, nicht aus dem Jahr." % [Calendar.format_year(year), BAND_ROMANS[band - 1], BAND_ROMANS[band], ", ".join(names)]))


static func _check_time_jumps(ordered: Array, findings: Array[Dictionary]) -> void:
	var previous: Dictionary = {}
	for item: Dictionary in ordered:
		if item.date_kind not in SPINE_KINDS:
			continue
		if not previous.is_empty():
			var end := int(previous.year_from if previous.year_to == null else previous.year_to)
			var gap := Calendar.years_between(end, int(item.year_from))
			if gap >= 2:
				findings.append(_finding("info", "time_jump", [previous, item], "Zwischen %s (%s) und %s (%s) liegen %d Jahre ohne Mission; der Zeitsprung muss die Welt fortschreiben." % [previous.id, previous.date_text, item.id, item.date_text, gap]))
		previous = item


# --- Helpers ----------------------------------------------------------------------

static func _band_ranges(value: Variant, errors: Array[String]) -> Dictionary:
	var result := {}
	if not value is Array or (value as Array).size() != 4:
		errors.append("band_ranges must list four bands")
		return result
	for entry: Variant in value:
		if not entry is Dictionary or not _int_like(entry.get("band")) or not _int_like(entry.get("from")) or not _int_like(entry.get("to")):
			errors.append("invalid band range")
			continue
		var from_year := int(entry.from)
		var to_year := int(entry.to)
		if not Calendar.is_valid_year(from_year) or not Calendar.is_valid_year(to_year) or from_year > to_year:
			errors.append("band range %s has year 0 or from > to" % str(entry.band))
			continue
		result[int(entry.band)] = entry
	return result


static func _mission_errors(value: Variant, offset: int, errors: Array[String]) -> Dictionary:
	if not value is Dictionary:
		errors.append("mission entry is not an object")
		return {}
	var item: Dictionary = value
	for key: String in REQUIRED:
		if not item.has(key):
			errors.append("%s lacks %s" % [str(item.get("id", "?")), key])
			return {}
	var id := str(item.id)
	var parts := id.split("-")
	if parts.size() != 2 or parts[0] not in BAND_ROMANS or not parts[1].is_valid_int() or parts[1].length() != 2:
		errors.append("invalid mission id %s" % id)
		return {}
	if not _int_like(item.band) or int(item.band) != BAND_ROMANS.find(parts[0]) + 1 or item.band_roman != parts[0] or not _int_like(item.number) or int(item.number) != int(parts[1]):
		errors.append("%s band or number does not match its id" % id)
		return {}
	if item.date_kind not in DATE_KINDS or item.canon_kind not in CANON_KINDS:
		errors.append("%s has unknown date or canon kind" % id)
		return {}
	var dated: bool = item.date_kind not in ["alternative", "epilogue"]
	if dated != _int_like(item.year_from) or (item.year_from != null and not Calendar.is_valid_year(int(item.year_from))):
		errors.append("%s has an invalid start year (year 0 does not exist)" % id)
		return {}
	var open_end: bool = item.date_kind in ["open_after", "from_year"] or not dated
	if open_end != (item.year_to == null) or (item.year_to != null and (not _int_like(item.year_to) or not Calendar.is_valid_year(int(item.year_to)) or int(item.year_to) < int(item.year_from))):
		errors.append("%s has an invalid end year or from > to" % id)
		return {}
	if item.date_kind in ["exact_year", "exact_date"] and int(item.year_to) != int(item.year_from):
		errors.append("%s exact year spans several years" % id)
		return {}
	if item.date_kind in ["split_year", "year_range"] and int(item.year_to) <= int(item.year_from):
		errors.append("%s split or range does not span years" % id)
		return {}
	if (item.date_kind == "exact_date") != (item.date is Dictionary) or (item.date is Dictionary and (Calendar.date_to_jdn(item.date) == Calendar.INVALID or int(item.date.year) != int(item.year_from))):
		errors.append("%s exact date invalid" % id)
		return {}
	if bool(item.age_variable) != (item.age_min == null) or (item.age_min != null and (not _int_like(item.age_min) or int(item.age_min) < 0)):
		errors.append("%s age invalid" % id)
		return {}
	if (item.age_max == null) != (bool(item.age_open) or bool(item.age_variable)) or (item.age_max != null and (not _int_like(item.age_max) or int(item.age_max) < int(item.age_min))):
		errors.append("%s age range invalid" % id)
		return {}
	if not _int_like(item.pdf_page) or not _int_like(item.sheet_page) or int(item.pdf_page) != int(item.sheet_page) + offset:
		errors.append("%s PDF page does not equal sheet page + %d" % [id, offset])
		return {}
	if item.register_ref != "S. %03d" % int(item.sheet_page) or not _int_like(item.register_pdf_page) or int(item.register_pdf_page) < 49 or int(item.register_pdf_page) > 56:
		errors.append("%s continuity register reference does not match its sheet" % id)
		return {}
	if str(item.title).strip_edges().is_empty() or str(item.place).strip_edges().is_empty():
		errors.append("%s lacks title or place" % id)
		return {}
	return item


static func _ordered(by_id: Dictionary) -> Array:
	var ordered: Array = by_id.values()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.band) < int(b.band) or (int(a.band) == int(b.band) and int(a.number) < int(b.number)))
	return ordered


static func _covers(item: Dictionary, year: int) -> bool:
	var last := int(item.year_from) if item.year_to == null else int(item.year_to)
	return Calendar.years_between(int(item.year_from), year) >= 0 and Calendar.years_between(year, last) >= 0


static func _finding(severity: String, code: String, items: Array, detail: String) -> Dictionary:
	var ids := PackedStringArray()
	var pages := []
	for item: Dictionary in items:
		ids.append(str(item.id))
		pages.append(int(item.pdf_page))
	return {"severity": severity, "code": code, "mission_ids": Array(ids), "pdf_pages": pages,
		"key": "%s:%s" % [code, "+".join(ids)], "detail": detail}


static func _int_like(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_data = load_file(PATH)
	_by_id = {}
	for item: Variant in _data.get("missions", []):
		if item is Dictionary:
			_by_id[str(item.get("id", ""))] = item
