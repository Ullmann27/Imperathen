extends SceneTree

const Calendar = preload("res://scripts/domain/world_calendar.gd")
const Offices = preload("res://scripts/domain/political_offices.gd")

var _checks := 0
var _failed := 0


func _initialize() -> void:
	var start := Calendar.campaign_start_jdn()
	var augustan_start := Calendar.to_jdn(-27, 1, 16)
	var augustus_death := Calendar.to_jdn(14, 8, 19)
	_check(Offices.validation_errors().is_empty(), "catalog and source validation")
	_check(Offices.available(start - 1).is_empty(), "historical campaign start boundary")
	_check(Offices.available(Calendar.to_jdn(38, 1, 1)).is_empty(), "end of the authored early Principate")
	_check(Offices.available(Calendar.to_jdn(0, 1, 1)).is_empty(), "no year zero")
	_check(Offices.get_office("unknown", start).is_empty(), "unknown office")
	_check(Offices.available(start, "other").is_empty(), "unknown jurisdiction scope")
	_check(Offices.available(start, "municipal").size() == 3, "municipal scope")
	_check(Offices.get_office("municipal.aedile", start).get("evidence") == "local_reconstruction", "municipal uncertainty")
	_check(Offices.get_office("municipal.decurion", start).get("category") == "status", "council membership is a status")
	_check(Offices.get_office("rome.aedile", start).get("category") == "election", "Roman aedileship is elective")
	_check(Offices.get_office("rome.proconsul", start).get("category") == "appointment", "provincial mandate category")
	_check(Offices.get_office("rome.pontifex_maximus", start).get("category") == "religion", "pontificate category")
	_check(Offices.get_office("rome.dictator", start).is_empty(), "Caesar's dictatorship is outside the opening")
	_check(Offices.get_office("rome.dictator", Calendar.to_jdn(-46, 6, 1)).get("category") == "exception", "Caesar's dictatorship window")

	var previous := Offices.get_office("rome.consul", augustan_start - 1)
	var current := Offices.get_office("rome.consul", augustan_start)
	_check(previous.get("phase") == "late_republic" and current.get("phase") == "early_principate", "phase switch from the era registry")
	_check(previous.get("procedure") != current.get("procedure"), "surviving consulate with changed procedure")
	_check(not Offices.get_office("rome.tribune", augustus_death + 1).is_empty(), "tribunate survives under Tiberius")
	_check(Offices.get_office("rome.augustus", augustan_start - 1).is_empty(), "Augustus unavailable before the historical grant")
	_check(Offices.get_office("rome.augustus", augustan_start).get("category") == "exception", "Augustan grant on 16 January 27 BCE")
	_check(not Offices.get_office("rome.augustus", augustus_death).is_empty(), "last day of Augustus's historical window")
	_check(Offices.get_office("rome.augustus", augustus_death + 1).is_empty(), "Augustus unavailable under Tiberius")
	_check(not Offices.get_office("rome.consul", Calendar.to_jdn(1, 1, 1)).is_empty(), "early Principate continues through BCE to CE")

	var person := {"birth": {"year": -104, "month": 1, "day": 1}, "roman_citizen": true, "sex": "male", "home_jurisdiction": "aquileia"}
	_check(Offices.candidacy("municipal.decurion", start, person, "aquileia").eligible, "local candidate precheck")
	_check(Offices.candidacy("municipal.aedile", start, person, "valdora").reasons.has("wrong_jurisdiction"), "Valdora is not a municipality")
	_check(Offices.candidacy("municipal.aedile", start, person, "rome").reasons.has("wrong_jurisdiction"), "separate municipal and Roman state aedileships")
	person.home_jurisdiction = "valdora"
	_check(Offices.candidacy("municipal.aedile", start, person, "aquileia").reasons.has("no_local_membership"), "local membership required")
	_check(Offices.candidacy("rome.quaestor", start, person, "rome").eligible, "quaestorship precheck without municipal office")
	_check(Offices.candidacy("rome.consul", start, person, "rome").missing_offices == ["rome.praetor"], "praetorship before consulship")
	_check(Offices.candidacy("rome.tribune", start, person, "rome").reasons.has("plebeian_required"), "tribune requires plebeian status")
	person.plebeian = true
	_check(Offices.candidacy("rome.tribune", start, person, "rome").eligible, "tribune may be pursued independently")
	person.held_offices = ["rome.quaestor"]
	_check(Offices.candidacy("rome.praetor", start, person, "rome").eligible, "praetorship with no aedileship or tribunate requirement")
	_check(Offices.candidacy("rome.senator", start, person, "rome").eligible, "documented admission avenue via quaestorship")
	person.held_offices.append("rome.praetor")
	_check(Offices.candidacy("rome.consul", start, person, "rome").eligible, "preceding Roman office recognized")
	_check(Offices.candidacy("rome.proconsul", start, person, "rome").eligible, "prior office satisfies the appointment precheck")
	person.held_offices.append("rome.consul")
	_check(Offices.candidacy("rome.augustus", augustan_start, person, "rome").reasons == ["protected_historical_event"], "no automatic succession to Augustus even after consulate")
	_check(Offices.candidacy("rome.dictator", Calendar.to_jdn(-46, 6, 1), person, "rome").reasons == ["protected_historical_event"], "no automatic dictatorship")
	var child := person.merged({"birth": {"year": -70}}, true)
	_check(Offices.candidacy("rome.quaestor", start, child, "rome").reasons.has("under_campaign_age"), "twelve-year-old protagonist cannot stand")
	var no_citizenship := person.merged({"roman_citizen": "true"}, true)
	_check(Offices.candidacy("rome.quaestor", start, no_citizenship, "rome").reasons.has("citizenship_required"), "unverified citizenship denied")
	var deceased := person.merged({"death_jdn": start}, true)
	_check(Offices.candidacy("rome.quaestor", start, deceased, "rome").reasons.has("person_deceased"), "a deceased candidate is ineligible")
	var malformed := person.merged({"birth": {"year": 0}, "held_offices": "rome.praetor", "death_jdn": "unknown"}, true)
	var reasons: Array = Offices.candidacy("rome.consul", start, malformed, "rome").reasons
	_check(reasons == ["invalid_birth", "invalid_death_date", "invalid_prior_offices"], "malformed candidate facts fail safely")
	_check(Offices.candidacy("rome.quaestor", start, person.merged({"sex": "female"}, true), "rome").reasons.has("historical_sex_rule"), "historical rules for the covered offices")

	var copies := Offices.get_office("rome.praetor", start)
	copies.sources[0].url = "overwritten"
	copies.required_offices.clear()
	_check(Offices.get_office("rome.praetor", start).sources[0].url.begins_with("https://"), "read-only source metadata")
	_check(Offices.get_office("rome.praetor", start).required_offices == ["rome.quaestor"], "read-only prerequisites")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Offices.PATH))
	data.offices.append(data.offices[0].duplicate(true))
	data.offices[1].sources = ["nonexistent_source"]
	data.offices[2].required_offices = ["rome.quaestor"]
	var invalid_catalog := Offices.build(data)
	_check(invalid_catalog.offices.is_empty() and invalid_catalog.errors.size() == 3, "invalid references and duplicate ids fail closed")
	print("POLITICAL_OFFICES: %d/%d" % [_checks - _failed, _checks])
	quit(1 if _failed else 0)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failed += 1
		push_error(label)
