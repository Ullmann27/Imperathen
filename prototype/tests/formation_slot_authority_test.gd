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
