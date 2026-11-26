extends RefCounted
## Interface a simulation implements to take part in a time jump
## (see time_jump_contract.gd and docs/37_world_calendar/WORLD_CALENDAR.md).
##
## A participant owns exactly one domain of the world snapshot. advance() is
## called once per plan step, in the contract's fixed domain order, and must be
## a pure function of its arguments:
## - domain_state: deep copy of this domain's state at the start of the step;
## - step: {"index", "from_jdn", "to_jdn", "days", "year", "season", "season_turn"};
## - context: {"world_id", "seed", "era_changes", "from_date", "to_date",
##   "domains" (read-only deep copies of the other domains)}.
## Randomness may only come from context.seed. No engine time, no global state.
##
## It returns {"ok": true, "state": Dictionary, "changes": Array, "removed": Array}
## or {"ok": false, "reason": String}. Every change names subject_id, summary
## and cause; every removed object names id, reason and event_id. Nothing may
## disappear silently (open promises, inventory, property, people).


func domain() -> String:
	return ""


func advance(_domain_state: Dictionary, _step: Dictionary, _context: Dictionary) -> Dictionary:
	return {"ok": false, "reason": "not_implemented"}
