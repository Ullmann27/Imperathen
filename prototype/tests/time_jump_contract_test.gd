extends SceneTree
## Time-jump contract: planning on the calendar, protected events, atomic and
## deterministic orchestration, no silent removal, calendar-derived ageing.
## The domain participants below are test stubs, not simulations.

const Calendar = preload("res://scripts/domain/world_calendar.gd")
const Contract = preload("res://scripts/domain/time_jump_contract.gd")
const Ageing = preload("res://scripts/domain/calendar_ageing_participant.gd")
const Base = preload("res://scripts/domain/time_jump_participant.gd")
var checks := 0
var failures := 0


class DriftStub extends "res://scripts/domain/time_jump_participant.gd":
	var name := ""
	func _init(domain_name: String) -> void:
		name = domain_name
	func domain() -> String:
		return name
	func advance(state: Dictionary, step: Dictionary, context: Dictionary) -> Dictionary:
		var before := int(state.get("value", 0))
		state["value"] = before + int(context.seed % 5) - 2
		state["steps"] = int(state.get("steps", 0)) + 1
		context.domains["characters"] = {"tampered": true}
		return {"ok": true, "state": state, "changes": [{"subject_id": name, "summary": "%d -> %d" % [before, int(state.value)], "cause": "stub_step_%d" % int(step.index)}], "removed": []}


class RemovalStub extends "res://scripts/domain/time_jump_participant.gd":
	var event_id := ""
	func _init(event: String) -> void:
		event_id = event
	func domain() -> String:
		return "property"
	func advance(state: Dictionary, step: Dictionary, _context: Dictionary) -> Dictionary:
		var removed := []
		if int(step.index) == 2 and state.get("items", []).has("old_cart"):
			state.items.erase("old_cart")
			removed.append({"id": "old_cart", "reason": "verkauft", "event_id": event_id})
		return {"ok": true, "state": state, "changes": [], "removed": removed}


class FailingStub extends "res://scripts/domain/time_jump_participant.gd":
	func domain() -> String:
		return "politics"
	func advance(state: Dictionary, step: Dictionary, _context: Dictionary) -> Dictionary:
		state["touched"] = true
		if int(step.index) == 3:
			return {"ok": false, "reason": "succession_unresolved"}
		return {"ok": true, "state": state, "changes": [], "removed": []}


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func _initialize() -> void:
	_planning()
	_orchestration()
	_ageing()
	print("TIME_JUMP_CONTRACT checks=%d failures=%d" % [checks, failures])
	if failures == 0:
		print("TIME_JUMP_CONTRACT_PASS")
	quit(1 if failures else 0)


func _start_clock() -> Dictionary:
	return Calendar.new_clock(Calendar.campaign_start_jdn(), 21600)


func _planning() -> void:
	var clock := _start_clock()
	var target := Calendar.add_calendar_years(Calendar.campaign_start_jdn(), 6)
	var plan := Contract.plan(clock, target, {"reason": "Sechs Jahre später"})
	check(bool(plan.ok) and int(plan.calendar_years) == 6 and int(plan.days) == Calendar.days_between(Calendar.campaign_start_jdn(), target), "six-year plan")
	check((plan.steps as Array).size() == 25, "six years from 1 May are integrated in 25 season steps")
	var contiguous := int(plan.steps[0].from_jdn) == Calendar.campaign_start_jdn() and int(plan.steps[-1].to_jdn) == target
	var total := 0
	for index in (plan.steps as Array).size():
		total += int(plan.steps[index].days)
		if index > 0 and int(plan.steps[index].from_jdn) != int(plan.steps[index - 1].to_jdn):
			contiguous = false
	check(contiguous and total == int(plan.days), "steps are contiguous and cover the window exactly")
	check(int(plan.steps[0].to_jdn) == Calendar.to_jdn(-58, 6, 1) and plan.steps[0].season == "summer", "first step ends at the next season start")
	var yearly := Contract.plan(clock, target, {"reason": "Sechs Jahre später", "step": "year"})
	check((yearly.steps as Array).size() == 7 and int(yearly.steps[1].from_jdn) == Calendar.to_jdn(-57, 1, 1), "year steps")
	var crossing := Contract.plan(Calendar.new_clock(Calendar.to_jdn(-2, 1, 1)), Calendar.to_jdn(3, 1, 1), {"reason": "Reise", "step": "year"})
	check(bool(crossing.ok) and (crossing.steps as Array).size() == 4 and int(crossing.calendar_years) == 4 and int(crossing.steps[1].year) == 1, "a jump over 1 v. -> 1 n. Chr. has no year zero step")
	var levy := false
	for change: Dictionary in plan.era_changes:
		if change.id == "troops.rome.cisalpine_levy_57" and change.change == "begins":
			levy = true
	check(levy, "the plan lists era transitions inside the window")
	check(Contract.plan(clock, Calendar.campaign_start_jdn(), {"reason": "x"}).reason == "jump_must_move_forward", "zero-length jump rejected")
	check(Contract.plan(clock, target, {}).reason == "visible_reason_required", "a jump needs a visible reason")
	check(Contract.plan({}, target, {"reason": "x"}).reason == "invalid_clock", "invalid clock rejected")
	check(Contract.plan(clock, Calendar.add_calendar_years(target, 60), {"reason": "x"}).reason == "jump_too_long", "overlong jump rejected")
	var raid := {"id": "I-10", "jdn": Calendar.to_jdn(-58, 9, 20)}
	var blocked := Contract.plan(clock, target, {"reason": "x", "pending_protected": [raid]})
	check(not bool(blocked.ok) and blocked.reason == "protected_event_inside_jump" and blocked.event_id == "I-10", "a pending I-10 cannot be skipped")
	var after := {"id": "I-10", "jdn": Calendar.add_days(target, 1)}
	check(bool(Contract.plan(clock, target, {"reason": "x", "pending_protected": [after]}).ok), "a protected event after the window does not block")
	check(Contract.plan(clock, target, {"reason": "x", "era_overrides": {"building.basilica_iulia": {"from": -58}}}).reason == "invalid_era_overrides", "unmarked divergences rejected")
	check(Contract.step_seed("w", "relations", 0) == Contract.step_seed("w", "relations", 0) and Contract.step_seed("w", "relations", 0) != Contract.step_seed("w", "relations", 1), "seeds are stable and vary per step")
	check(Contract.step_seed("w", "relations", 0) >= 0 and Contract.step_seed("w", "relations", 0) < (1 << 60), "seeds are 60-bit")


func _world(world_id: String = "world-a") -> Dictionary:
	var actors := {
		"player": {"birth": Calendar.PROTAGONIST_BIRTH.duplicate(), "death_jdn": null, "age": 12, "life_phase": "child"},
		"marcus": {"birth": {"year": -70}, "death_jdn": null, "age": 12, "life_phase": "child"},
		"julia": {"birth": {"year": -92, "month": 6, "day": 10}, "death_jdn": null, "age": 33, "life_phase": "adult"},
		"silvanus": {"birth": {"year": -95}, "death_jdn": Calendar.to_jdn(-58, 9, 21), "age": 37, "life_phase": "adult"},
	}
	return {"world_id": world_id, "domains": {"characters": {"actors": actors}, "relations": {}, "settlements": {}, "property": {"items": ["old_cart", "tools"]}, "politics": {}, "equipment": {}}}


func _participants(property: Object = null) -> Array:
	return [DriftStub.new("equipment"), Ageing.new(), DriftStub.new("relations"), DriftStub.new("settlements"), DriftStub.new("politics"),
		property if property != null else RemovalStub.new("ledger:sale-1")]


func _orchestration() -> void:
	var plan := Contract.plan(_start_clock(), Calendar.add_calendar_years(Calendar.campaign_start_jdn(), 6), {"reason": "Sechs Jahre später"})
	var world := _world()
	var snapshot := JSON.stringify(world, "", true)
	var result := Contract.run(world, _participants(), plan)
	check(bool(result.ok), "complete jump runs: %s" % str(result.get("reason", "")))
	check(JSON.stringify(world, "", true) == snapshot, "the input world is never mutated")
	check(int(result.clock.jdn) == Calendar.to_jdn(-52, 5, 1) and int(result.clock.second) == 21600, "the clock lands on 1 May 52 v. Chr. at the same time of day")
	var actors: Dictionary = result.world.domains.characters.actors
	check(int(actors.player.age) == 18 and actors.player.life_phase == "adult" and int(actors.marcus.age) == 18, "protagonist and Marcus are 18 after six years")
	check(int(actors.julia.age) == 39 and int(actors.silvanus.age) == 37, "Julia ages; Silvanus, dead since I-12, does not")
	check(int(result.world.domains.relations.steps) == 25 and not result.world.domains.characters.has("tampered"), "participants run once per step; read-only context cannot overwrite other domains")
	check(result.world.domains.property["items"] == ["tools"], "property change applied")
	var removal := (result.ledger as Array).filter(func(entry: Dictionary) -> bool: return entry.type == "removed")
	check(removal.size() == 1 and removal[0].subject_id == "old_cart" and removal[0].cause == "ledger:sale-1", "removal is ledgered with reason and event")
	var phases := (result.ledger as Array).filter(func(entry: Dictionary) -> bool: return entry.subject_id == "player" and str(entry.summary).begins_with("Lebensphase"))
	check(phases.size() == 2 and int(phases[0].jdn) <= Calendar.to_jdn(-54, 3, 1) and str(phases[1].summary).ends_with("adult"), "child -> youth in 54 v. Chr., youth -> adult in 52 v. Chr.")
	var statuses := {}
	for line: Dictionary in result.summary:
		statuses[line.domain] = line.status
	check(statuses == {"characters": "simulated", "relations": "simulated", "settlements": "simulated", "property": "simulated", "politics": "simulated", "equipment": "simulated"}, "summary covers every required domain")
	var again := Contract.run(_world(), _participants(), plan)
	check(again.digest == result.digest and JSON.stringify(again) == JSON.stringify(result), "same input, same result and digest")
	var other := Contract.run(_world("world-b"), _participants(), plan)
	check(bool(other.ok) and other.digest != result.digest, "seeds depend on the world id")
	var partial := [Ageing.new(), DriftStub.new("relations")]
	var missing := Contract.run(_world(), partial, plan)
	check(not bool(missing.ok) and missing.reason == "missing_domain" and missing.domain == "settlements", "a required domain cannot be skipped silently")
	var declared := Contract.run(_world(), partial, plan, {"allow_missing": {"settlements": "Stadtsimulation fehlt", "property": "Besitzsystem fehlt", "politics": "Politiksimulation fehlt", "equipment": "Ausrüstungsalterung fehlt"}})
	var not_simulated := (declared.summary as Array).filter(func(line: Dictionary) -> bool: return line.status == "not_simulated")
	check(bool(declared.ok) and not_simulated.size() == 4 and not_simulated[0].reason == "Stadtsimulation fehlt", "missing simulations are declared visibly in the summary")
	var silent := Contract.run(_world(), _participants(RemovalStub.new("")), plan)
	check(not bool(silent.ok) and silent.reason == "silent_removal" and silent.domain == "property", "removal without event id rejects the jump")
	var failing := [Ageing.new(), DriftStub.new("relations"), DriftStub.new("settlements"), FailingStub.new(), RemovalStub.new("ledger:sale-1"), DriftStub.new("equipment")]
	var world_before := JSON.stringify(world, "", true)
	var failed := Contract.run(world, failing, plan)
	check(not bool(failed.ok) and failed.reason == "participant_rejected:succession_unresolved" and int(failed.step) == 3 and failed.domain == "politics", "a failing participant rejects the whole jump")
	check(not failed.has("world") and JSON.stringify(world, "", true) == world_before, "a rejected jump leaves the world untouched")
	check(Contract.run(world, [DriftStub.new("relations"), DriftStub.new("relations")], plan).reason == "duplicate_domain", "one participant per domain")
	check(Contract.run(world, [DriftStub.new("magic")], plan).reason == "unknown_domain", "unknown domains rejected")
	check(Contract.run(world, [Base.new()], plan).reason == "unknown_domain", "the bare interface is not a participant")
	check(Contract.run(world, _participants(), {"ok": false}).reason == "invalid_plan", "invalid plan rejected")
	var no_state := _world()
	no_state.domains.erase("politics")
	check(Contract.run(no_state, _participants(), plan).reason == "domain_state_missing", "every participating domain needs state")


func _ageing() -> void:
	check(Contract.life_phase(11) == "early_child" and Contract.life_phase(12) == "child" and Contract.life_phase(16) == "youth" and Contract.life_phase(18) == "adult" and Contract.life_phase(-1) == "unborn", "life phases from the handbook")
	var hero := {"birth": Calendar.PROTAGONIST_BIRTH, "death_jdn": null}
	var varus := Contract.actor_time(hero, Calendar.to_jdn(9, 9, 9))
	check(int(varus.age) == 78 and bool(varus.alive), "a living protagonist would be 78 at the Varus battle")
	var dead := {"birth": {"year": -70}, "death_jdn": Calendar.to_jdn(-30, 1, 1)}
	check(int(Contract.actor_time(dead, Calendar.to_jdn(9, 1, 1)).age) == 40 and not bool(Contract.actor_time(dead, Calendar.to_jdn(9, 1, 1)).alive), "the dead stop ageing")
	var child := {"birth": {"year": -10, "month": 4, "day": 2}, "death_jdn": null}
	check(not bool(Contract.actor_time(child, Calendar.to_jdn(-11, 1, 1)).alive) and int(Contract.actor_time(child, Calendar.to_jdn(1, 4, 2)).age) == 10, "an heir born 10 v. Chr. is 10 in 1 n. Chr.")
