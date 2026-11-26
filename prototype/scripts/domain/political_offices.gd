extends RefCounted
## Read-only directory and first-pass admission checks for the historical campaign.
## A positive candidacy result leaves elections, appointments and office holding to
## separate authoritative commands. Candidate facts must come from the world state.

const Calendar = preload("res://scripts/domain/world_calendar.gd")
const Eras = preload("res://scripts/domain/era_registry.gd")

const PATH := "res://assets/world/political_offices.json"
const FORMAT := "imperathen-political-offices"
const SCHEMA := 1
const PHASES := ["late_republic", "early_principate"]
const SCOPES := ["municipal", "rome"]
const CATEGORIES := ["election", "appointment", "status", "religion", "exception"]
const EVIDENCE := ["documented", "local_reconstruction"]
const AUGUSTAN_ERA := "political.rome.principate_augustus"
const TIBERIAN_ERA := "political.rome.principate_tiberius"
const ADULT_GAMEPLAY_AGE := 18

static var _catalog: Dictionary = {}


static func validation_errors() -> Array:
	return _data().errors.duplicate()


static func build(data: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var result := {"errors": errors, "offices": {}, "sources": {}}
	if not _matches_text(data.get("format"), FORMAT) or not Calendar.is_integral(data.get("schema")) or int(data.schema) != SCHEMA:
		errors.append("Unbekanntes Format oder Schema des Ämterkatalogs.")
		return result
	var sources: Variant = data.get("sources")
	var offices: Variant = data.get("offices")
	if not sources is Dictionary or sources.is_empty() or not offices is Array or offices.is_empty():
		errors.append("Quellen oder Ämter fehlen.")
		return result
	for key: Variant in sources:
		var source: Variant = sources[key]
		if not _has_text(key) or not source is Dictionary or not _has_text(source.get("title")) or not _has_text(source.get("url")) or not str(source.url).begins_with("https://"):
			errors.append("Ungültiger Quellenbeleg: " + str(key))
	var index := {}
	for record: Variant in offices:
		if not record is Dictionary or not _has_text(record.get("id")):
			errors.append("Amt ohne gültige ID.")
			continue
		var id: String = record.id
		if index.has(id):
			errors.append("Doppelte Amts-ID: " + id)
			continue
		index[id] = record.duplicate(true)
		_validate_office(record, sources, errors)
	for id: String in index:
		var prior: Variant = index[id].get("required_offices", [])
		if not prior is Array:
			errors.append("Ungültige Vorämter: " + id)
			continue
		for previous: Variant in prior:
			if not _has_text(previous) or previous == id or not index.has(previous) or index[previous].get("scope") != index[id].get("scope") or index[previous].get("category") == "exception":
				errors.append("Ungültiges Voramt für " + id + ": " + str(previous))
	if errors.is_empty():
		result.offices = index
		result.sources = sources.duplicate(true)
	return result


static func get_office(id: String, jdn: int) -> Dictionary:
	var data := _data()
	return _view(data.offices.get(id, {}), _phase(jdn), jdn, data.sources)


static func available(jdn: int, scope: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var data := _data()
	var phase := _phase(jdn)
	for id: String in data.offices:
		var record: Dictionary = data.offices[id]
		if not scope.is_empty() and record.scope != scope:
			continue
		var view := _view(record, phase, jdn, data.sources)
		if not view.is_empty():
			result.append(view)
	return result


static func candidacy(id: String, jdn: int, person: Dictionary, jurisdiction: String) -> Dictionary:
	## Eligibility here describes a precheck against the authenticated person's
	## known facts. Legal age, tenure, vacancies and competent authority still
	## need their own historical political rules before an office can be granted.
	var office := get_office(id, jdn)
	var reasons: Array[String] = []
	var absent: Array[String] = []
	var result := {"eligible": false, "reasons": reasons, "missing_offices": absent, "office": office}
	if office.is_empty():
		reasons.append("office_unavailable")
		return result
	if office.category == "exception":
		reasons.append("protected_historical_event")
		return result
	var locality := "aquileia" if office.scope == "municipal" else "rome"
	if jurisdiction != locality:
		reasons.append("wrong_jurisdiction")
	elif office.scope == "municipal" and not _matches_text(person.get("home_jurisdiction"), jurisdiction):
		reasons.append("no_local_membership")
	var birth: Variant = person.get("birth")
	var age := Calendar.age_on(birth, jdn) if birth is Dictionary else Calendar.INVALID
	if age == Calendar.INVALID:
		reasons.append("invalid_birth")
	elif age < ADULT_GAMEPLAY_AGE:
		reasons.append("under_campaign_age")
	var death: Variant = person.get("death_jdn")
	if death != null:
		if not Calendar.is_integral(death) or int(death) < 0 or int(death) > Calendar.max_jdn():
			reasons.append("invalid_death_date")
		elif int(death) <= jdn:
			reasons.append("person_deceased")
	if not _is_true(person.get("roman_citizen")):
		reasons.append("citizenship_required")
	if not _matches_text(person.get("sex"), "male"):
		reasons.append("historical_sex_rule")
	if office.get("plebeian_only", false) and not _is_true(person.get("plebeian")):
		reasons.append("plebeian_required")
	var held: Variant = person.get("held_offices", [])
	if not held is Array:
		reasons.append("invalid_prior_offices")
	else:
		for prior: String in office.get("required_offices", []):
			if not held.has(prior):
				absent.append(prior)
		if not absent.is_empty():
			reasons.append("prior_office_required")
	result.eligible = reasons.is_empty()
	return result


static func _data() -> Dictionary:
	if _catalog.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_catalog = build(parsed if parsed is Dictionary else {})
	return _catalog


static func _phase(jdn: int) -> String:
	var horizon := Eras.window(TIBERIAN_ERA)
	if horizon.is_empty() or jdn < Calendar.campaign_start_jdn() or jdn > int(horizon.to_jdn):
		return ""
	if Eras.state_at("rome.princeps", jdn) in [AUGUSTAN_ERA, TIBERIAN_ERA]:
		return "early_principate"
	return "late_republic"


static func _view(record: Dictionary, phase: String, jdn: int, sources: Dictionary) -> Dictionary:
	if record.is_empty() or not record.forms.has(phase):
		return {}
	if record.has("requires_era") and not Eras.available(record.requires_era, jdn):
		return {}
	var view := record.duplicate(true)
	view.erase("forms")
	view["phase"] = phase
	view["procedure"] = record.forms[phase]
	view["sources"] = []
	for id: String in record.sources:
		view.sources.append(sources[id].duplicate(true))
	return view


static func _validate_office(record: Dictionary, sources: Dictionary, errors: Array[String]) -> void:
	var id: String = record.id
	if record.get("scope") not in SCOPES or record.get("category") not in CATEGORIES or record.get("evidence") not in EVIDENCE:
		errors.append("Unbekannter Geltungsbereich, Typ oder Belegstatus: " + id)
	if not _has_text(record.get("label")) or not _has_text(record.get("duties")):
		errors.append("Beschreibung fehlt: " + id)
	var forms: Variant = record.get("forms")
	if not forms is Dictionary or forms.is_empty():
		errors.append("Besetzungsverfahren fehlen: " + id)
	else:
		for phase: Variant in forms:
			if phase not in PHASES or not _has_text(forms[phase]):
				errors.append("Ungültiges Besetzungsverfahren: " + id)
	var references: Variant = record.get("sources")
	if not references is Array or references.is_empty():
		errors.append("Amtsquellen fehlen: " + id)
	else:
		for source: Variant in references:
			if not _has_text(source) or not sources.has(source):
				errors.append("Unbekannte Amtsquelle: " + id)
	if record.has("requires_era") or record.get("category") == "exception":
		if not _has_text(record.get("requires_era")) or Eras.entry(record.requires_era).get("kind") != "political_state":
			errors.append("Politisches Epochenfenster fehlt oder ist ungültig: " + id)
	if record.has("plebeian_only") and not record.plebeian_only is bool:
		errors.append("Ungültige Standesvoraussetzung: " + id)


static func _has_text(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()



static func _matches_text(value: Variant, expected: String) -> bool:
	return value is String and value == expected


static func _is_true(value: Variant) -> bool:
	return value is bool and value
