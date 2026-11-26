extends SceneTree
## Acceptance for the troop/command core: persistent soldiers, front-rank losses,
## closing up, speed cap, officer succession, determinism and legacy saves.

const Battle := preload("res://scripts/battle/battle_model.gd")
const Slots := preload("res://scripts/battle/formation_slots.gd")
const Catalog := preload("res://scripts/battle/troop_catalog.gd")
const LEGACY := "res://tests/fixtures/valley_schema2_60s.json"
const GUARD := "valley_guard"
const ENEMY := "ridge_guard"

var checks := 0
var failures := 0
var metrics := {}


func _initialize() -> void:
	_test_identity()
	_test_front_losses()
	_test_closing_up()
	_test_speed_cap()
	_test_officer_spread()
	_test_determinism()
	_test_legacy_save()
	print("BATTLE_COMMAND_RESULT checks=%d failures=%d metrics=%s" % [checks, failures, JSON.stringify(metrics)])
	quit(1 if failures else 0)


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", message)


func _place(m, changes: Dictionary, shapes: Dictionary = {}) -> bool:
	var save: Dictionary = m.snapshot()
	for id in changes:
		var squad: Dictionary = save.squads[id]
		var at: Vector2 = changes[id]
		if shapes.has(id):
			squad.formation = shapes[id]
		squad.x = at.x
		squad.z = at.y
		squad.goal_x = at.x
		squad.goal_z = at.y
		squad.members.clear()
		for p in Slots.world_slots(squad.formation, squad.strength, squad.width, at, squad.facing):
			squad.members.append([p.x, p.y])
	return m.restore(save)


func _test_identity() -> void:
	var m := Battle.new()
	var catalog := Catalog.load_default()
	var all := {}
	for s: Dictionary in m.squads.values():
		var seeds := {}
		var plan: Dictionary = m._plans[s.id]
		check(s.troop_id == plan.troop_id and Catalog.valid_at(catalog.troops[s.troop_id], -58), "Company uses its 58 BC catalog troop: " + s.id)
		check(s.people.size() == s.initial_strength and s.uids.size() == s.strength, "One identity per soldier: " + s.id)
		for uid in s.people:
			var person: Dictionary = s.people[uid]
			check(not all.has(uid), "Soldier uid is unique across the battle: " + uid)
			all[uid] = true
			seeds[person.appearance_seed] = true
			check(person.name != "" and person.origin.group_id == plan.origin and person.origin.place in catalog.groups[plan.origin].places,
				"Recruit comes from the named population group: " + uid)
			check(person.troop_id == s.troop_id and person.status == "active" and person.service[0].event == "mustered", "Fresh service record: " + uid)
		check(seeds.size() == s.initial_strength, "No two soldiers of a company share an appearance: " + s.id)
	for id in ["ridge_guard", "ridge_spears", "ridge_bows"]:
		check(catalog.troops[m.squads[id].troop_id].culture == "germanic" and m.squads[id].troop_id != "germanic_axe_shield",
			"Bench opponents are Germanic, never the rare axe variant by default: " + id)
	for id in ["valley_guard", "valley_bows"]:
		check(catalog.troops[m.squads[id].troop_id].service == "roman", "Bench allies serve Rome: " + id)
	var uid: String = m.squads[GUARD].uids[0]
	var record := m.soldier_record(uid)
	record.name = "Ersatz"
	var listed := m.roster(GUARD)
	listed[0].status = "dead"
	var shown := m.soldiers(GUARD)
	shown[0].id = "fake"
	check(m.soldier_record(uid).name != "Ersatz" and m.squads[GUARD].people[listed[0].uid].status == "active" and m.squads[GUARD].uids[0] == uid,
		"Views receive copies; the model stays the only authority")
	var fallen := {}
	var revived := false
	for i in 1500:
		m.tick(Battle.STEP)
		for s: Dictionary in m.squads.values():
			for f in fallen:
				revived = revived or f in s.uids
			for person: Dictionary in s.people.values():
				if person.status != "active":
					fallen[person.uid] = true
		if m.outcome != "ongoing":
			break
	check(not fallen.is_empty() and not revived, "A fallen soldier never returns to the ranks (%d fallen)" % fallen.size())
	var records_ok := true
	for s: Dictionary in m.squads.values():
		for person: Dictionary in s.people.values():
			if person.status != "active":
				records_ok = records_ok and not person.wound.is_empty() and person.service.back().event in ["killed", "wounded", "lost_comrade", "took_command"]
	check(records_ok, "Every casualty keeps a wound or death record and a service entry")
	var persisted := Battle.new()
	check(persisted.restore(JSON.parse_string(JSON.stringify(m.snapshot()))) and persisted.roster(GUARD) == m.roster(GUARD) and persisted.roster(ENEMY) == m.roster(ENEMY),
		"Identities, wounds and service records survive a JSON save")


func _front_share(entries: Array) -> Dictionary:
	var front := 0
	var melee := 0
	var melee_front := 0
	var threat_front := 0
	for entry: Dictionary in entries:
		front += int(entry.rank <= 1)
		threat_front += int(entry.band <= 2)
		if entry.mode == "melee":
			melee += 1
			melee_front += int(entry.rank <= 1)
	return {"losses": entries.size(), "front2": float(front) / maxi(1, entries.size()), "melee": melee,
		"melee_front2": float(melee_front) / maxi(1, melee), "threat_front2": float(threat_front) / maxi(1, entries.size())}


func _test_front_losses() -> void:
	var battle := Battle.new()
	battle.tick(300)
	var whole := _front_share(battle.casualty_log)
	metrics["default_battle"] = whole
	check(whole.losses >= 20 and whole.front2 >= 0.70, "Default battle: at least 70 %% of losses from the front two ranks (%.3f of %d)" % [whole.front2, whole.losses])
	var entries := []
	for run in range(1, 11):
		var m := Battle.new(run)
		check(_place(m, {GUARD: Vector2(-7, 8), ENEMY: Vector2(-7, 4.6)}, {GUARD: "line"}), "Frontal melee fixture loads (seed %d)" % run)
		m.squads[ENEMY].command = "hold"
		m.order(["valley_bows"], "cease_fire")
		m.tick(20)
		for entry: Dictionary in m.casualty_log:
			if entry.squad in [GUARD, ENEMY]:
				entries.append(entry)
	var frontal := _front_share(entries)
	metrics["frontal_melee_10_seeds"] = frontal
	check(frontal.losses >= 30 and frontal.front2 >= 0.70, "Frontal melee: at least 70 %% of losses from the front two ranks (%.3f of %d)" % [frontal.front2, frontal.losses])


func _ranks_by_uid(s: Dictionary) -> Dictionary:
	var ranks := Slots.ranks(s.formation, s.strength, s.width)
	var result := {}
	for i in range(s.uids.size()):
		result[s.uids[i]] = ranks[i]
	return result


func _test_closing_up() -> void:
	var m := Battle.new()
	check(_place(m, {GUARD: Vector2(-7, 8), ENEMY: Vector2(-7, 4.6)}, {GUARD: "line"}), "Closing-up fixture loads")
	m.squads[ENEMY].command = "hold"
	var guard: Dictionary = m.squads[GUARD]
	var before := {}
	var fallen := ""
	for i in 200:
		before = _ranks_by_uid(guard)
		var logged: int = m.casualty_log.size()
		m.tick(Battle.STEP)
		for j in range(logged, m.casualty_log.size()):
			var entry: Dictionary = m.casualty_log[j]
			if entry.squad == GUARD and entry.rank == 0 and guard.strength == guard.initial_strength - 1:
				fallen = entry.uid
		if fallen != "" or guard.strength < guard.initial_strength:
			break
	check(fallen != "", "A front-rank soldier falls first in frontal contact")
	if fallen == "":
		return
	var after := _ranks_by_uid(guard)
	var stepped_up := []
	var kept_front := true
	for uid in after:
		if after[uid] == 0 and before[uid] >= 1:
			stepped_up.append(uid)
		if before[uid] == 0 and after[uid] != 0:
			kept_front = false
	check(stepped_up.size() == 1 and kept_front, "Exactly one rear-rank soldier steps into the gap; the front rank keeps its men")
	var mover: String = stepped_up[0] if not stepped_up.is_empty() else ""
	var settled := -1
	for i in 8:
		var k: int = guard.uids.find(mover)
		var slots := Slots.world_slots(guard.formation, guard.strength, guard.width, Vector2(guard.x, guard.z), guard.facing)
		if k >= 0 and Vector2(guard.members[k][0], guard.members[k][1]).distance_to(slots[k]) < 0.05:
			settled = i
			break
		m.tick(Battle.STEP)
	metrics["closing_up_steps"] = settled
	check(settled >= 0, "The soldier stepping up reaches his new front slot within eight steps")


func _max_step(m, seconds: float) -> float:
	var worst := 0.0
	var last := {}
	for i in roundi(seconds / Battle.STEP):
		for s: Dictionary in m.squads.values():
			for k in range(s.uids.size()):
				last[s.uids[k]] = Vector2(s.members[k][0], s.members[k][1])
		m.tick(Battle.STEP)
		for s: Dictionary in m.squads.values():
			for k in range(s.uids.size()):
				if last.has(s.uids[k]):
					worst = maxf(worst, last[s.uids[k]].distance_to(Vector2(s.members[k][0], s.members[k][1])))
		if m.outcome != "ongoing":
			break
	return worst


func _test_speed_cap() -> void:
	var worst := _max_step(Battle.new(), 120)
	var fleeing := Battle.new()
	fleeing.order([GUARD, "valley_spears", "valley_bows"], "retreat")
	worst = maxf(worst, _max_step(fleeing, 30))
	var turning := Battle.new()
	turning.order([GUARD], "deploy", {"start": Vector2(-4, 14), "end": Vector2(-10, 14)})
	worst = maxf(worst, _max_step(turning, 10))
	metrics["max_member_step_m"] = snappedf(worst, 0.0001)
	check(worst <= Battle.MEMBER_STEP + 0.00001 and is_equal_approx(Battle.MEMBER_STEP, 0.53), "No soldier moves more than 0.53 m per step (max %.4f m)" % worst)


func _test_officer_spread() -> void:
	var at_loss := []
	var survived_three := 0
	for run in range(1, 13):
		var m := Battle.new(run)
		var counted := {}
		for i in 600:
			m.tick(Battle.STEP)
			for s: Dictionary in m.squads.values():
				if not counted.has(s.id) and not s.uids.has(s.commander_id) and s.strength < s.initial_strength:
					counted[s.id] = s.initial_strength - s.strength
			if m.outcome != "ongoing":
				break
		for s: Dictionary in m.squads.values():
			if s.initial_strength - s.strength >= 3 and (not counted.has(s.id) or counted[s.id] > 3):
				survived_three += 1
		at_loss.append_array(counted.values())
	var distinct := {}
	for v in at_loss:
		distinct[v] = true
	metrics["commander_falls_at_losses"] = at_loss
	check(distinct.size() >= 3 and survived_three > 0, "Commander death depends on the fight, not on exactly three losses (%s)" % str(distinct.keys()))


func _test_determinism() -> void:
	var a := Battle.new(7)
	var b := Battle.new(7)
	a.order([GUARD], "attack", ENEMY)
	b.order([GUARD], "attack", ENEMY)
	for half in 2:
		a.tick(30)
		b.tick(30)
	check(a.snapshot() == b.snapshot() and a.casualty_log == b.casualty_log, "Same seed and orders give the same battle")
	var c := Battle.new(8)
	c.order([GUARD], "attack", ENEMY)
	c.tick(30)
	c.tick(30)
	var fresh := Battle.new()
	check(a.casualty_log != c.casualty_log and fresh.restore(c.snapshot()) and fresh.battle_seed == 8, "Another seed gives another valid history")
	var resumed := Battle.new(7)
	resumed.order([GUARD], "attack", ENEMY)
	resumed.tick(30)
	var exact := Battle.new()
	var reloaded := Battle.new()
	check(exact.restore(resumed.snapshot()) and reloaded.restore(JSON.parse_string(JSON.stringify(resumed.snapshot(), "", true, true))), "Mid-battle save reloads")
	exact.tick(30)
	reloaded.tick(30)
	check(exact.snapshot() == a.snapshot(), "Restoring the mid-battle state reproduces the battle exactly")
	# Godot's JSON keeps doubles to about 14 digits, so the file round trip is compared
	# on the accounts and the surviving soldiers, as the re-entry check does.
	check(reloaded.summary() == a.summary() and reloaded.hierarchy() == a.hierarchy(), "A JSON reload in the middle reproduces outcome, losses and survivors")


func _test_legacy_save() -> void:
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LEGACY))
	check(legacy.schema == 2.0 and not legacy.has("seed") and not legacy.squads[GUARD].has("uids"), "Fixture is a genuine schema-2 save of the previous model")
	var m := Battle.new()
	check(m.restore(legacy.duplicate(true)), "Schema-2 save stays valid")
	var guard: Dictionary = m.squads[GUARD]
	var expected := []
	for i in range(int(legacy.squads[GUARD].strength)):
		expected.append("valley_guard_%02d" % i)
	check(guard.uids == expected and guard.officer_id == legacy.squads[GUARD].officer_id, "Legacy survivors keep their old ids and officer")
	var totals := m.summary()
	check(totals.ally.losses == 22 and totals.ally.dead == 6 and totals.enemy.losses == 21 and totals.enemy.dead == 6, "Legacy loss accounts are unchanged")
	var unrecorded := true
	for person: Dictionary in guard.people.values():
		if person.status != "active":
			unrecorded = unrecorded and person.wound.severity == "unrecorded" and person.service.back().event == "legacy_casualty"
	check(unrecorded, "Legacy casualties are marked unrecorded instead of inventing wounds")
	check(m.snapshot().schema == 3 and Battle.new().restore(JSON.parse_string(JSON.stringify(m.snapshot()))), "A migrated save is written as schema 3")
	m.tick(20)
	check(Battle.new().restore(m.snapshot()), "A migrated battle continues validly")
	var partial := legacy.duplicate(true)
	partial.squads[GUARD].uids = []
	check(not Battle.new().restore(partial), "A schema-2 save with only part of the schema-3 fields is rejected")
	var revived := legacy.duplicate(true)
	revived.squads[GUARD].strength = 5
	check(not Battle.new().restore(revived), "A legacy save cannot revive a soldier")
