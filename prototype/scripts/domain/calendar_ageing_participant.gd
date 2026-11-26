extends "res://scripts/domain/time_jump_participant.gd"
## Reference participant for the "characters" domain: calendar-derived ageing
## only. It updates the cached age and life phase of every actor from the birth
## date and reports birthdays and phase changes. Personality, memories, health
## and death belong to the actor simulation (D-016, D-029), not to this file.
##
## Domain state: {"actors": {actor_id: {"birth": {"year"[, "month", "day"]},
##   "death_jdn": int|null, "age": int, "life_phase": String}}}

const Contract = preload("res://scripts/domain/time_jump_contract.gd")


func domain() -> String:
	return "characters"


func advance(domain_state: Dictionary, step: Dictionary, _context: Dictionary) -> Dictionary:
	if not domain_state.get("actors") is Dictionary:
		return {"ok": false, "reason": "actors_missing"}
	var actors: Dictionary = domain_state.actors
	var ids: Array = actors.keys()
	ids.sort()
	var changes := []
	for id: Variant in ids:
		var actor: Variant = actors[id]
		if not actor is Dictionary:
			return {"ok": false, "reason": "actor_invalid"}
		var before := Contract.actor_time(actor, int(step.from_jdn))
		var after := Contract.actor_time(actor, int(step.to_jdn))
		if int(after.age) < 0 and int(before.age) < 0:
			continue
		if int(after.age) != int(actor.get("age", -1)) or str(after.life_phase) != str(actor.get("life_phase", "")):
			actor.age = int(after.age)
			actor.life_phase = str(after.life_phase)
		if int(after.age) != int(before.age):
			changes.append({"subject_id": str(id), "summary": "Alter %d → %d" % [int(before.age), int(after.age)], "cause": "calendar_ageing"})
		if str(after.life_phase) != str(before.life_phase):
			changes.append({"subject_id": str(id), "summary": "Lebensphase %s → %s" % [before.life_phase, after.life_phase], "cause": "calendar_ageing"})
	return {"ok": true, "state": domain_state, "changes": changes, "removed": []}
