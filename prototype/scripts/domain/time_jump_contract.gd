extends RefCounted
## Time-jump contract. A jump (childhood -> adulthood, between missions, long
## travel) must carry the world forward instead of skipping it: characters age,
## relations develop or decay, settlements, property, politics and equipment
## progress. This script plans the jump on the calendar and orchestrates the
## participants deterministically and atomically. It implements no simulation:
## each domain is supplied by its own system (time_jump_participant.gd).
## Only calendar-derived ageing is provided here (calendar_ageing_participant.gd).
##
## Rules (Masterhandbuch PDF S. 64: "Kapitelzeit-Sprünge sind sichtbare
## Entscheidungen mit Zusammenfassung über Haus, Freunde, Besitz und Alter.
## Kein stiller Sprung, der offene Versprechen oder Inventar löscht."):
## 1. A jump needs a visible reason and moves strictly forward.
## 2. A pending protected story event (I-10, D-020) inside the window blocks it.
## 3. The window is integrated in calendar steps (season or year), never as one leap.
## 4. Every required domain is simulated or explicitly declared missing with a reason.
## 5. Participants run in DOMAIN_ORDER on deep copies; any failure rejects the whole jump.
## 6. Nothing is removed without reason and event id; every change is ledgered.
## 7. Same world, plan and participants give the same result and digest.

const Calendar = preload("res://scripts/domain/world_calendar.gd")
const Era = preload("res://scripts/domain/era_registry.gd")
const CONTRACT_VERSION := 1
const REQUIRED_DOMAINS := ["characters", "relations", "settlements", "property", "politics", "equipment"]
const OPTIONAL_DOMAINS := ["tribes", "troops", "economy"]
const DOMAIN_ORDER := ["characters", "relations", "politics", "tribes", "settlements", "economy", "property", "troops", "equipment"]
const STEP_SEASON := "season"
const STEP_YEAR := "year"
const MAX_JUMP_YEARS := 60
## Design bands from the handbook (PDF S. 64), not ancient law. "early_child"
## is an authored band for NPC children of the later dynasty system.
const LIFE_PHASES := [
	{"id": "early_child", "min_age": 0, "max_age": 11},
	{"id": "child", "min_age": 12, "max_age": 15},
	{"id": "youth", "min_age": 16, "max_age": 17},
	{"id": "adult", "min_age": 18, "max_age": -1},
]


static func plan(from_clock: Dictionary, to_jdn: int, options: Dictionary = {}) -> Dictionary:
	## options: reason (required), step ("season" | "year"), pending_protected
	## ([{"id", "jdn"}] still unresolved), era_overrides (marked divergences).
	if not Calendar.validate_clock(from_clock):
		return _rejected("invalid_clock")
	var start := int(from_clock.jdn)
	if to_jdn <= start or to_jdn > Calendar.max_jdn():
		return _rejected("jump_must_move_forward")
	var start_year := Calendar.year_of(start)
	var end_year := Calendar.year_of(to_jdn)
	if Calendar.years_between(start_year, end_year) > MAX_JUMP_YEARS:
		return _rejected("jump_too_long")
	var reason := str(options.get("reason", "")).strip_edges()
	if reason.is_empty():
		return _rejected("visible_reason_required")
	var step_kind := str(options.get("step", STEP_SEASON))
	if step_kind not in [STEP_SEASON, STEP_YEAR]:
		return _rejected("unknown_step")
	for pending: Variant in options.get("pending_protected", []):
		if not pending is Dictionary or not Calendar.is_integral(pending.get("jdn")):
			return _rejected("invalid_protected_event")
		var day := int(pending.jdn)
		if day > start and day <= to_jdn:
			var blocked := _rejected("protected_event_inside_jump")
			blocked["event_id"] = str(pending.get("id", ""))
			return blocked
	var overrides: Dictionary = options.get("era_overrides", {})
	if not Era.validate_overrides(overrides).is_empty():
		return _rejected("invalid_era_overrides")
	var boundaries := _boundaries(start, to_jdn, step_kind)
	var steps := []
	for index in boundaries.size() - 1:
		var step_from: int = boundaries[index]
		var step_to: int = boundaries[index + 1]
		steps.append({"index": index, "from_jdn": step_from, "to_jdn": step_to, "days": step_to - step_from,
			"year": Calendar.year_of(step_to), "season": Calendar.SEASON_IDS[Calendar.season_index(step_to)],
			"season_turn": Calendar.season_turn(step_to)})
	return {"ok": true, "contract": CONTRACT_VERSION, "from_jdn": start, "to_jdn": to_jdn,
		"second": int(from_clock.second), "days": to_jdn - start,
		"calendar_years": Calendar.years_between(start_year, end_year), "reason": reason,
		"step_kind": step_kind, "steps": steps, "era_overrides": overrides.duplicate(true),
		"era_changes": Era.changes_between(start, to_jdn, overrides)}


static func run(world: Dictionary, participants: Array, jump_plan: Dictionary, options: Dictionary = {}) -> Dictionary:
	## world: {"world_id": String, "domains": {domain: state}} built by the caller
	## from the save. options.allow_missing: {domain: reason} for domains whose
	## simulation does not exist yet; they appear as "not_simulated" in the summary.
	if not bool(jump_plan.get("ok", false)) or int(jump_plan.get("contract", 0)) != CONTRACT_VERSION:
		return _rejected("invalid_plan")
	if typeof(world.get("world_id")) != TYPE_STRING or str(world.world_id).is_empty() or not world.get("domains") is Dictionary:
		return _rejected("invalid_world")
	var by_domain := {}
	for participant: Variant in participants:
		if not participant is Object or not participant.has_method("domain") or not participant.has_method("advance"):
			return _rejected("invalid_participant")
		var name := str(participant.domain())
		if name not in REQUIRED_DOMAINS and name not in OPTIONAL_DOMAINS:
			return _rejected("unknown_domain")
		if by_domain.has(name):
			return _rejected("duplicate_domain")
		if not world.domains.has(name) or not world.domains[name] is Dictionary:
			var missing_state := _rejected("domain_state_missing")
			missing_state["domain"] = name
			return missing_state
		by_domain[name] = participant
	var allow_missing: Dictionary = options.get("allow_missing", {})
	for name: String in REQUIRED_DOMAINS:
		if not by_domain.has(name) and str(allow_missing.get(name, "")).strip_edges().is_empty():
			var missing := _rejected("missing_domain")
			missing["domain"] = name
			return missing
	var domains: Dictionary = (world.domains as Dictionary).duplicate(true)
	var ledger := []
	var counts := {}
	for name: String in DOMAIN_ORDER:
		counts[name] = {"changes": 0, "removed": 0}
	for step: Dictionary in jump_plan.steps:
		var step_changes := Era.changes_between(int(step.from_jdn), int(step.to_jdn), jump_plan.get("era_overrides", {}))
		for name: String in DOMAIN_ORDER:
			if not by_domain.has(name):
				continue
			var others := {}
			for other: String in domains:
				if other != name:
					others[other] = (domains[other] as Dictionary).duplicate(true) if domains[other] is Dictionary else domains[other]
			var context := {"world_id": str(world.world_id), "seed": step_seed(str(world.world_id), name, int(step.index)),
				"era_changes": step_changes.duplicate(true), "from_date": Calendar.from_jdn(int(step.from_jdn)),
				"to_date": Calendar.from_jdn(int(step.to_jdn)), "domains": others}
			var result: Variant = by_domain[name].advance((domains[name] as Dictionary).duplicate(true), step.duplicate(true), context)
			var problem := _result_problem(result)
			if not problem.is_empty():
				var failed := _rejected(problem)
				failed["domain"] = name
				failed["step"] = int(step.index)
				return failed
			domains[name] = result.state
			for change: Dictionary in result.changes:
				ledger.append({"step": int(step.index), "jdn": int(step.to_jdn), "domain": name, "type": "change",
					"subject_id": str(change.subject_id), "summary": str(change.summary), "cause": str(change.cause)})
			for removed: Dictionary in result.removed:
				ledger.append({"step": int(step.index), "jdn": int(step.to_jdn), "domain": name, "type": "removed",
					"subject_id": str(removed.id), "summary": str(removed.reason), "cause": str(removed.event_id)})
			counts[name].changes += (result.changes as Array).size()
			counts[name].removed += (result.removed as Array).size()
	var summary := []
	for name: String in REQUIRED_DOMAINS + OPTIONAL_DOMAINS:
		if by_domain.has(name):
			summary.append({"domain": name, "status": "simulated", "changes": counts[name].changes, "removed": counts[name].removed})
		elif name in REQUIRED_DOMAINS:
			summary.append({"domain": name, "status": "not_simulated", "reason": str(allow_missing[name])})
	var outcome := {"ok": true, "contract": CONTRACT_VERSION, "world": {"world_id": str(world.world_id), "domains": domains},
		"clock": Calendar.new_clock(int(jump_plan.to_jdn), int(jump_plan.get("second", 0))),
		"reason": str(jump_plan.reason), "ledger": ledger, "summary": summary,
		"era_changes": (jump_plan.get("era_changes", []) as Array).duplicate(true)}
	outcome["digest"] = JSON.stringify(outcome, "", true).sha256_text()
	return outcome


static func step_seed(world_id: String, domain_name: String, step_index: int) -> int:
	## Stable 60-bit seed per world, domain and step (SHA-256, platform independent).
	return ("%s|%s|%d" % [world_id, domain_name, step_index]).sha256_text().substr(0, 15).hex_to_int()


# --- Calendar-derived ageing (used by calendar_ageing_participant.gd) ----------------

static func life_phase(age: int) -> String:
	if age < 0:
		return "unborn"
	for phase: Dictionary in LIFE_PHASES:
		if age >= int(phase.min_age) and (int(phase.max_age) < 0 or age <= int(phase.max_age)):
			return str(phase.id)
	return "unborn"


static func actor_time(actor: Dictionary, jdn: int) -> Dictionary:
	## Age and life phase of an actor record {"birth": {...}, "death_jdn": int|null}.
	## Ages always derive from the birth date; a dead actor stops ageing.
	var death: Variant = actor.get("death_jdn", null)
	var alive := death == null or (Calendar.is_integral(death) and jdn < int(death))
	var reference := jdn if alive else int(death)
	var age := Calendar.age_on(actor.get("birth", {}), reference)
	return {"age": age, "life_phase": life_phase(age), "alive": alive and age >= 0}


# --- Internals -----------------------------------------------------------------------

static func _boundaries(start: int, finish: int, step_kind: String) -> Array:
	var points := [start]
	var cursor := start
	while true:
		var next := _next_boundary(cursor, step_kind)
		if next == Calendar.INVALID or next >= finish:
			break
		points.append(next)
		cursor = next
	points.append(finish)
	return points


static func _next_boundary(jdn: int, step_kind: String) -> int:
	if step_kind == STEP_YEAR:
		return Calendar.first_day_of_year(Calendar.add_years(Calendar.year_of(jdn), 1))
	var turn := Calendar.season_turn(jdn)
	return Calendar.season_turn_start(turn + 1)


static func _result_problem(result: Variant) -> String:
	if not result is Dictionary or typeof(result.get("ok")) != TYPE_BOOL:
		return "participant_result_invalid"
	if not result.ok:
		return "participant_rejected:" + str(result.get("reason", ""))
	if not result.get("state") is Dictionary or not result.get("changes") is Array or not result.get("removed") is Array:
		return "participant_result_incomplete"
	for change: Variant in result.changes:
		if not change is Dictionary or str(change.get("subject_id", "")).is_empty() or str(change.get("summary", "")).is_empty() or str(change.get("cause", "")).is_empty():
			return "change_without_subject_summary_or_cause"
	for removed: Variant in result.removed:
		if not removed is Dictionary or str(removed.get("id", "")).is_empty() or str(removed.get("reason", "")).is_empty() or str(removed.get("event_id", "")).is_empty():
			return "silent_removal"
	return ""


static func _rejected(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
