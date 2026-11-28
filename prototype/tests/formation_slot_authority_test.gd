extends SceneTree
## Actual BattleModel/FormationAgents command and slot-authority regression.
## Rendered motion and LOD quality remain separate existing gates.
const Battle := preload("res://scripts/battle/battle_model.gd")
const Agents := preload("res://scripts/formation/formation_agents.gd")
const Slots := preload("res://scripts/battle/formation_slots.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)

func _drive(model, agents, seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		model.tick(1.0 / 60.0)
		agents.advance(model)

func _valid_owners(model, agents, id: String) -> bool:
	var unit = agents.units[id]
	var roster: Array = model.soldiers(id)
	if unit.owners.size() != roster.size():
		return false
	var seen := {}
	for row: Dictionary in roster:
		var uid := Agents.uid_of(row)
		var slot := int(row.slot.index)
		if slot < 0 or slot >= unit.owners.size() or not agents.agents.has(uid) or seen.has(uid) or unit.owners[slot] != uid or agents.agents[uid].slot != slot:
			return false
		seen[uid] = true
	return true

func _run() -> void:
	var model := Battle.new()
	var agents := Agents.new()
	_drive(model, agents, 0.4)
	var id := "valley_spears"
	var initial: Array = model.squads[id].uids.duplicate()
	var initial_owners: Array = agents.units[id].owners.duplicate()
	var start_facing: float = model.squads[id].facing
	_check(_valid_owners(model, agents, id), "Initial living roster and visual slot ownership are identical")
	_check(model.order([id], "move", Vector2(9, 4)).ok, "Existing authority accepts an oblique move")
	var stable := true
	var aligned := true
	for i in 240:
		model.tick(1.0 / 60.0)
		agents.advance(model)
		stable = stable and model.squads[id].uids == initial and agents.units[id].owners == initial_owners
		aligned = aligned and _valid_owners(model, agents, id)
	_check(absf(angle_difference(start_facing, float(model.squads[id].facing))) > deg_to_rad(30.0), "The company really wheels")
	_check(stable, "Small front change preserves every actual rank owner")
	_check(aligned, "All displayed soldiers obey the same authoritative slot through movement")
	var resumed := Battle.new()
	_check(resumed.restore(model.snapshot()), "The mid-campaign rules snapshot restores")
	for i in 10:
		model.tick(Battle.STEP)
		resumed.tick(Battle.STEP)
	_check(model.snapshot() == resumed.snapshot(), "Continuing a saved formation remains deterministic")
	var reform := Battle.new()
	var views := Agents.new()
	_drive(reform, views, 0.4)
	var guard := "valley_guard"
	var original: Array = reform.squads[guard].uids.duplicate()
	original.sort()
	var old_tick: int = views.tick
	_check(reform.order([guard], "form", "line").ok, "The existing formation command is accepted")
	_drive(reform, views, 1.6)
	var record: Dictionary = views.last_match.get(guard, {})
	var current: Array = reform.squads[guard].uids.duplicate()
	current.sort()
	_check(reform.squads[guard].formation == "line" and current == original, "A new shape preserves every living UID")
	_check(_valid_owners(reform, views, guard), "New rank owners follow the rules roster")
	_check(record.get("source", "") == "authority" and int(record.get("tick", -1)) > old_tick and record.get("uids", []).size() == original.size() and record.get("from", []).size() == original.size() and record.get("to", []).size() == original.size(), "A real authoritative re-formation records every source and destination")
	# Malformed visual input cannot create two owners of the same slot.
	var unit = views.units[guard]
	views.agents[unit.members[0]].model_slot = views.agents[unit.members[1]].model_slot
	views._match(unit, unit.frame_center)
	var unique := {}
	for uid: String in unit.owners:
		if not uid.is_empty():
			unique[uid] = true
	_check(unique.size() == unit.members.size() and views.last_match[guard].source == "fallback", "Duplicate visual slot input triggers one-to-one fallback rather than hiding a soldier")
	_check(reform.squads[guard].uids.size() == original.size(), "Visual fallback cannot modify the authoritative roster")
	_test_casualty_rank_fill()
	_test_front_turn_contract()
	print("FORMATION_SLOT_AUTHORITY_RESULT checks=%d failures=%d" % [checks, failures])
	print("FORMATION_SLOT_AUTHORITY_PASS" if failures == 0 else "FORMATION_SLOT_AUTHORITY_FAIL")
	quit(0 if failures == 0 else 1)


## Controlled real rule casualty on a line already formed by a genuine
## command. No authored positions or hit outcome are rewritten afterward.
func _test_casualty_rank_fill() -> void:
	var battle := Battle.new()
	var actors := Agents.new()
	var id := "valley_guard"
	_check(battle.order([id], "form", "line").ok, "Gap fixture receives a real line order")
	_drive(battle, actors, 1.6)
	var unit: Dictionary = battle.squads[id]
	var previous := {}
	var victim := ""
	for row: Dictionary in battle.soldiers(id):
		previous[row.id] = {"rank":int(row.slot.rank), "position":Vector2(row.x, row.z)}
		if int(row.slot.rank) == 0 and int(row.slot.file) == 1:
			victim = str(row.id)
	if victim.is_empty():
		_check(false, "Fixture has the intended front-rank casualty")
		return
	var initial_count := int(unit.strength)
	var at := Vector2(float(unit.x), float(unit.z))
	battle._take_losses(unit, [victim], [{"damage":1.0,"at":at + Vector2(0,-4),"mode":"melee","from":"ridge_guard"}])
	_check(int(unit.strength) == initial_count - 1 and not victim in unit.uids and unit.people[victim].status != "active", "Real loss removes only the named living UID")
	var unchanged := true
	var kept_front := true
	var promoted: Array[String] = []
	for row: Dictionary in battle.soldiers(id):
		var old: Dictionary = previous[row.id]
		unchanged = unchanged and Vector2(row.x,row.z).is_equal_approx(old.position)
		kept_front = kept_front and (int(old.rank) != 0 or int(row.slot.rank) == 0)
		if int(old.rank) > 0 and int(row.slot.rank) == 0:
			promoted.append(str(row.id))
	_check(unchanged, "Dressing after a casualty reorders identities and positions together without teleporting any survivor")
	_check(kept_front and promoted.size() == 1, "The existing front keeps its survivors and exactly one rear soldier fills the vacant place")
	if promoted.size() != 1:
		return
	var uid := promoted[0]
	var settled := false
	var maximum_step := 0.0
	for frame in 8:
		var index: int = unit.uids.find(uid)
		if index < 0:
			break
		var before := Vector2(unit.members[index][0], unit.members[index][1])
		var slots := Slots.world_slots(unit.formation, unit.strength, unit.width, Vector2(unit.x,unit.z), unit.facing)
		if before.distance_to(slots[index]) < 0.05:
			settled = true
			break
		battle.tick(Battle.STEP)
		index = unit.uids.find(uid)
		if index >= 0:
			maximum_step = maxf(maximum_step, before.distance_to(Vector2(unit.members[index][0],unit.members[index][1])))
	_check(settled, "Promoted soldier reaches his assigned front place within the unchanged eight-step gate")
	_check(maximum_step <= Battle.MEMBER_STEP + 0.0001, "Gap closure respects the existing member speed cap")

## Real face and move commands exercise the distinction between accumulated
## presentation lag and an actual discrete turn in consecutive rule snapshots.
## The original formation_60 / formation_180 gates remain untouched.
func _test_front_turn_contract() -> void:
	var model := Battle.new()
	var agents := Agents.new()
	var id := "valley_spears"
	_drive(model, agents, 0.4)
	var unit = agents.units[id]
	var start: Vector2 = unit.center
	var owners: Array = unit.owners.duplicate()
	var initial_refiles: int = unit.refiles
	var initial_rematches: int = unit.rematches
	var max_lag := 0.0
	var max_rule_turn := 0.0
	var max_wheel_excess := 0.0
	var valid := true
	_check(model.order([id], "face", start + Vector2(0, 7)).ok, "A genuine face order starts a sustained wheel")
	for frame in 180:
		var old_rule: float = model.squads[id].facing
		var old_visual: float = unit.facing
		model.tick(1.0 / 60.0)
		var count: int = agents.advance(model)
		max_rule_turn = maxf(max_rule_turn, absf(angle_difference(old_rule, float(model.squads[id].facing))))
		max_lag = maxf(max_lag, absf(angle_difference(unit.facing, unit.model_facing)))
		if count > 0:
			var rate: float = float(unit.limits.run) * Agents.WHEEL_SHARE / maxf(1.0, unit.half_width)
			max_wheel_excess = maxf(max_wheel_excess, absf(angle_difference(old_visual, unit.facing)) - rate * Agents.DT * count)
		valid = valid and _valid_owners(model, agents, id) and unit.owners == owners
	_check(max_rule_turn <= deg_to_rad(Agents.REFILE_DEG), "Each authoritative face step is below the refile threshold")
	_check(max_lag > deg_to_rad(Agents.REFILE_DEG), "The sustained wheel actually creates visual lag beyond 75 degrees")
	_check(unit.refiles == initial_refiles and unit.rematches == initial_rematches and valid, "Visual lag does not refile, rematch or change rank authority")
	_check(max_wheel_excess <= 0.0001, "The original physical wheel rate bounds every visual substep")
	# A fresh battle and a move directly behind the front create the actual
	# discrete rule change. Inspect every snapshot, not only the final angle.
	var reverse_model := Battle.new()
	var reverse_agents := Agents.new()
	_drive(reverse_model, reverse_agents, 0.4)
	var reverse = reverse_agents.units[id]
	var before_refiles: int = reverse.refiles
	var discrete := 0
	var consistent := true
	var reverse_start: Vector2 = reverse.center
	_check(reverse_model.order([id], "move", reverse_start + Vector2(0, 6)).ok, "A genuine reverse movement order is accepted")
	for frame in 180:
		var previous_rule: float = reverse_model.squads[id].facing
		reverse_model.tick(1.0 / 60.0)
		if absf(angle_difference(previous_rule, float(reverse_model.squads[id].facing))) > deg_to_rad(Agents.REFILE_DEG):
			discrete += 1
		var count: int = reverse_agents.advance(reverse_model)
		if count > 0:
			consistent = consistent and reverse.refiles - before_refiles == discrete and _valid_owners(reverse_model, reverse_agents, id)
			if reverse.refile_snapshot == reverse_agents.snapshot_step:
				consistent = consistent and absf(angle_difference(reverse.facing, reverse.model_facing)) <= 0.0001
	_check(discrete > 0, "The reverse movement contains a real discrete rule turn")
	_check(consistent and reverse.refiles - before_refiles == discrete, "Each real discrete turn refiles exactly once; no rollback to old front and no duplicate owner")
	print("FORMATION_WHEEL_EVIDENCE ", JSON.stringify({"max_lag_deg":rad_to_deg(max_lag),"max_rule_turn_deg":rad_to_deg(max_rule_turn),"wheel_excess_rad":max_wheel_excess,"discrete_turns":discrete,"reverse_refiles":reverse.refiles-before_refiles,"global_refiles":agents.counters.refiles,"global_rematches":agents.counters.rematches}))
