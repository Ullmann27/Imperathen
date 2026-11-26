extends SceneTree
## Acceptance for the troop/command core: persistent soldiers, front-rank losses,
## closing up, speed cap, officer succession, determinism and legacy saves.

const Battle := preload("res://scripts/battle/battle_model.gd")
const Slots := preload("res://scripts/battle/formation_slots.gd")
const Catalog := preload("res://scripts/battle/troop_catalog.gd")
const Roster := preload("res://scripts/battle/soldier_roster.gd")
const Formula := preload("res://scripts/battle/combat_formula.gd")
const LEGACY := "res://tests/fixtures/valley_schema2_60s.json"
const GUARD := "valley_guard"
const ENEMY := "ridge_guard"
const SPEARS := "valley_spears"
const BOWS := "valley_bows"

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
	_test_rally()
	_test_rally_conditions()
	_test_contagion()
	_test_rear_and_banner()
	_test_rights()
	_test_fall_back()
	_test_advance()
	_test_charge()
	_test_face_and_fire()
	_test_pila()
	_test_orbis_and_testudo()
	_test_invalid_orders()
	_test_order_determinism()
	_test_wounds_and_recovery()
	_test_formula_battle()
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
	check(m.snapshot().schema == Battle.SCHEMA and Battle.new().restore(JSON.parse_string(JSON.stringify(m.snapshot()))), "A migrated save is written in the current schema")
	m.tick(20)
	check(Battle.new().restore(m.snapshot()), "A migrated battle continues validly")
	var partial := legacy.duplicate(true)
	partial.squads[GUARD].uids = []
	check(not Battle.new().restore(partial), "A schema-2 save with only part of the schema-3 fields is rejected")
	var revived := legacy.duplicate(true)
	revived.squads[GUARD].strength = 5
	check(not Battle.new().restore(revived), "A legacy save cannot revive a soldier")


func _source(m, target: String, at: Vector2) -> Array:
	return [{"from": ENEMY, "at": at, "damage": 1.0, "mode": "melee"}]


func _test_rally() -> void:
	var m := Battle.new()
	check(_place(m, {GUARD: Vector2(-18, 15)}), "Rally fixture loads")
	var g: Dictionary = m.squads[GUARD]
	g.status = "routed"
	g.morale = 20.0
	var start := Vector2(g.x, g.z)
	check(m.order([GUARD], "rally").ok and g.status == "rallying" and not m._active(g), "Rally at morale 20 starts a rally but the company still flees")
	var ordered: int = m.steps
	var fled := false
	var ready_at := -1
	var never_early := true
	for i in 60:
		m.tick(Battle.STEP)
		fled = fled or g.z > start.y + 0.3
		if g.status == "ready":
			ready_at = m.steps
			break
		never_early = never_early and g.status in ["rallying", "routed"] and not m._active(g)
		if m.steps - ordered < Battle.RALLY_STEPS:
			never_early = never_early and g.status != "ready"
	metrics["rally_from_20_seconds"] = (ready_at - ordered) * Battle.STEP if ready_at > 0 else -1.0
	check(fled, "Until the order arrives the routed company keeps running")
	check(never_early and ready_at > 0 and ready_at - ordered >= Battle.RALLY_STEPS and g.morale >= Battle.RALLY_MORALE,
		"Routing ends only with morale >= 40 after at least 5 s (%.1f s, morale %.1f)" % [(ready_at - ordered) * Battle.STEP, g.morale])
	check(ready_at - ordered <= 45 and g.command == "hold" and m._active(g) and g.memories.back().event == "rallied", "A rallied company holds and counts again")
	var saved := Battle.new()
	m.order([GUARD], "retreat")
	check(saved.restore(JSON.parse_string(JSON.stringify(m.snapshot()))), "Rallied state saves")


func _rallying(m) -> Dictionary:
	var g: Dictionary = m.squads[GUARD]
	g.status = "rallying"
	g.command = "rally"
	g.morale = 60.0
	g.rally_from = maxi(1, m.steps - 30)
	return g


func _test_rally_conditions() -> void:
	var m := Battle.new()
	m.steps = 40
	var near := {"x": m.squads[GUARD].x, "z": m.squads[GUARD].z + 6.0}
	var far := {"x": m.squads[GUARD].x, "z": m.squads[GUARD].z + 9.0}
	var g := _rallying(m)
	m._rally_step(g, near)
	check(g.status == "rallying", "No rally while a fighting enemy is within 8 m")
	m._rally_step(g, far)
	check(g.status == "ready", "Rally completes once the nearest enemy is beyond 8 m")
	g = _rallying(m)
	g.officer_id = ""
	m._rally_step(g, {})
	check(g.status == "rallying", "No rally without a living commander or deputy")
	g = _rallying(m)
	g.rally_from = m.steps - Battle.RALLY_STEPS + 1
	m._rally_step(g, {})
	check(g.status == "rallying", "No rally before 5 s have passed")
	g = _rallying(m)
	g.morale = 30.0
	m._rally_step(g, {})
	check(g.status == "rallying", "No rally below morale 40")
	var save := Battle.new()
	var snap: Dictionary = Battle.new().snapshot()
	snap.squads[GUARD].status = "rallying"
	snap.squads[GUARD].command = "rally"
	check(not save.restore(snap), "A rallying company without a rally start is rejected")
	snap.squads[GUARD].rally_from = 2
	snap.steps = 1
	check(save.restore(snap), "A consistent rallying company is accepted")
	var still := Battle.new()
	check(_place(still, {GUARD: Vector2(-18, 15)}), "Unrallied fixture loads")
	still.squads[GUARD].status = "routed"
	still.squads[GUARD].morale = 70.0
	var recovered := false
	for i in 50:
		still.tick(Battle.STEP)
		recovered = recovered or still.squads[GUARD].status == "ready"
	check(not recovered, "Without a rally order routing never ends by itself")


func _test_contagion() -> void:
	var m := Battle.new()
	check(_place(m, {"valley_spears": Vector2(3, 8), "valley_bows": Vector2(12, 12)}), "Contagion fixture loads")
	var g: Dictionary = m.squads[GUARD]
	var spears: Dictionary = m.squads["valley_spears"]
	var bows: Dictionary = m.squads["valley_bows"]
	g.morale = 27.0
	var spear_morale: float = spears.morale
	var bow_morale: float = bows.morale
	m._apply_hits({GUARD: {"damage": 1.0, "sources": _source(m, GUARD, Vector2(g.x, g.z - 3))}})
	check(g.status == "routed", "A company that falls below morale 24 routs")
	check(is_equal_approx(spears.morale, spear_morale - Battle.CONTAGION_SHOCK) and is_equal_approx(bows.morale, bow_morale),
		"A rout costs neighbours within 12 m exactly 8 morale and leaves those further away alone")
	var chain := Battle.new()
	check(_place(chain, {"valley_spears": Vector2(3, 8), "valley_bows": Vector2(12, 12)}), "Cascade fixture loads")
	chain.squads[GUARD].morale = 27.0
	chain.squads["valley_spears"].morale = 30.0
	var before: float = chain.squads["valley_bows"].morale
	chain._apply_hits({GUARD: {"damage": 1.0, "sources": _source(chain, GUARD, Vector2(-7, 5))}})
	check(chain.squads["valley_spears"].status == "routed" and is_equal_approx(chain.squads["valley_bows"].morale, before - Battle.CONTAGION_SHOCK)
		and chain.squads["valley_spears"].memories.back().ref == GUARD, "Panic cascades through a company that breaks from it")


func _test_rear_and_banner() -> void:
	var m := Battle.new()
	m.steps = 10
	var g: Dictionary = m.squads[GUARD]
	var front := Vector2(g.x, g.z) + m._front(g) * 3.0
	var rear := Vector2(g.x, g.z) - m._front(g) * 3.0
	var side := Vector2(g.x, g.z) + m._front(g).orthogonal() * 3.0
	var one: float = 84.0 / g.initial_strength
	check(is_equal_approx(m.casualty_morale(g, 1, _source(m, GUARD, front)), one) and is_equal_approx(m.casualty_morale(g, 1, _source(m, GUARD, side)), one),
		"Front and flank casualties cost the base morale")
	check(is_equal_approx(m.casualty_morale(g, 1, _source(m, GUARD, rear)), one * 1.5), "Casualties from behind weigh 1.5x")
	var mixed := _source(m, GUARD, front) + _source(m, GUARD, rear)
	check(is_equal_approx(m.casualty_morale(g, 1, mixed), one * 1.25), "Mixed attacks weigh by their damage share")
	var banner: String = g.signifer_id
	check(banner == "valley_guard_10" and Slots.ranks(g.formation, g.strength, g.width)[g.uids.find(banner)] == 1, "The standard bearer stands in the second rank")
	var morale: float = g.morale
	m._take_losses(g, [banner], _source(m, GUARD, front))
	check(is_equal_approx(g.morale, morale - one - Battle.BANNER_SHOCK) and g.signifer_id == "" and g.memories.back().event == "banner_lost",
		"Losing the standard costs 15 morale on top of the casualty")
	morale = g.morale
	var next: String = g.uids[3] if g.uids[3] != g.commander_id else g.uids[4]
	m._take_losses(g, [next], _source(m, GUARD, front))
	check(is_equal_approx(g.morale, morale - one), "The banner shock applies only once")
	var revived: Dictionary = m.snapshot()
	revived.squads[GUARD].signifer_id = banner
	check(not Battle.new().restore(revived), "A save cannot raise a fallen standard bearer")
	check(Battle.new().restore(m.snapshot()), "A company without its standard saves validly")


func _test_rights() -> void:
	var m := Battle.new()
	var catalog := Catalog.load_default()
	for s: Dictionary in m.squads.values():
		var valid: bool = not s.commandable_by.is_empty()
		for post in s.commandable_by:
			var kind: String = m.scenario.appointments[post].type
			valid = valid and Catalog.valid_at(catalog.appointments[kind], -58) and m.scenario.appointments[post].side == s.side
		check(valid, "Command rights name appointments valid in 58 BC: " + s.id)
	check(m.commander == "legatus_valdora" and m.order([GUARD, SPEARS, BOWS], "hold").ok, "The bench legate commands every allied company")
	var before := m.snapshot()
	check(m.set_commander("centurio_valley_guard") and m.order([GUARD], "hold").ok, "A centurion commands his own company")
	before = m.snapshot()
	check(not m.order([BOWS], "hold").ok and not m.order([GUARD, BOWS], "hold").ok and m.snapshot() == before, "A centurion cannot command another company; mixed selections fail atomically")
	check(not m.set_commander("imperator") and m.commander == "centurio_valley_guard", "Unknown appointments are refused")
	check(m.set_commander("") and not m.order([GUARD], "hold").ok and m.snapshot() == before, "Without an appointment (the twelve-year-old) nothing can be commanded")
	check(not m.order([GUARD], "hold", null, "dux_hoehenbund").ok and not m.order([GUARD], "hold", null, "praefectus_valley_bows").ok and m.snapshot() == before,
		"Foreign or unrelated appointments are refused")
	check(m.order([BOWS], "cease_fire", null, "praefectus_valley_bows").ok and not m.squads[BOWS].fire, "An explicit appointment can be named per order")


func _test_fall_back() -> void:
	var m := Battle.new()
	var g: Dictionary = m.squads[GUARD]
	var start := Vector2(g.x, g.z)
	var facing: float = g.facing
	check(m.order([GUARD], "fall_back").ok, "Fall back accepted")
	var anchor_step := 0.0
	var worst := 0.0
	for i in 100:
		var at := Vector2(g.x, g.z)
		var last := []
		for k in range(g.uids.size()):
			last.append(Vector2(g.members[k][0], g.members[k][1]))
		m.tick(Battle.STEP)
		anchor_step = maxf(anchor_step, at.distance_to(Vector2(g.x, g.z)))
		for k in range(mini(last.size(), g.uids.size())):
			worst = maxf(worst, last[k].distance_to(Vector2(g.members[k][0], g.members[k][1])))
		if g.command == "hold":
			break
	var moved := start.distance_to(Vector2(g.x, g.z))
	var turned := absf(angle_difference(facing, g.facing))
	metrics["fall_back"] = {"meters": snappedf(moved, 0.001), "facing_error_rad": snappedf(turned, 0.0001), "anchor_step_m": snappedf(anchor_step, 0.0001)}
	check(g.command == "hold" and absf(moved - 10.0) <= 0.3 and turned <= 0.1, "Fall back covers 10 +- 0.3 m and keeps the facing within 0.1 rad (%.3f m, %.4f rad)" % [moved, turned])
	check(anchor_step <= Battle.FALL_BACK_SPEED * Battle.STEP + 0.0001 and worst <= Battle.MEMBER_STEP + 0.00001, "Fall back moves at 1 m/s; no soldier exceeds 0.53 m per step")
	check(Vector2(g.x, g.z).distance_to(start + Vector2(0, 10)) < 0.31, "The company backs away from where it faces")
	var blocked := Battle.new()
	check(_place(blocked, {GUARD: Vector2(-12, -6)}), "Blocked fall-back fixture loads")
	var before := blocked.snapshot()
	check(not blocked.order([GUARD], "fall_back").ok and blocked.snapshot() == before, "A rock behind the company rejects the fall back atomically")
	var edge := Battle.new()
	check(_place(edge, {GUARD: Vector2(-7, 18)}), "Edge fixture loads")
	before = edge.snapshot()
	check(not edge.order([GUARD], "fall_back").ok and edge.snapshot() == before, "No falling back off the valley")


func _test_advance() -> void:
	var m := Battle.new()
	check(_place(m, {GUARD: Vector2(6, 9), BOWS: Vector2(14, 16)}), "Advance fixture loads")
	var g: Dictionary = m.squads[GUARD]
	check(m.order([GUARD], "advance").ok and g.target == "ridge_spears", "Advance without a target picks the nearest enemy")
	var halted := -1.0
	var crept := false
	for i in 150:
		var foe: Dictionary = m.squads[g.target] if g.target != "" else {}
		if foe.is_empty() or g.command != "advance" or g.status in ["routed", "rallying"]:
			break
		var before := Vector2(g.x, g.z)
		var gap := before.distance_to(Vector2(foe.x, foe.z))
		m.tick(Battle.STEP)
		var still := before.distance_to(Vector2(g.x, g.z)) < 0.0001
		if gap <= Battle.ADVANCE_STANDOFF + 0.3 and not still and g.status in ["ready", "moving"]:
			crept = true
		if still and g.status == "ready" and halted < 0 and m.steps > g.ready_at:
			halted = Vector2(g.x, g.z).distance_to(Vector2(foe.x, foe.z))
	metrics["advance_halt_m"] = snappedf(halted, 0.001)
	check(halted >= 5.6 and halted <= 6.35 and not crept, "Advance stops about 6 m short and never creeps closer on its own (%.2f m)" % halted)
	var archers := Battle.new()
	check(_place(archers, {BOWS: Vector2(0, 2)}), "Archer advance fixture loads")
	check(archers.order([BOWS], "advance", "ridge_bows").ok, "Archers advance on a named enemy")
	var shot_at := -1.0
	for i in 100:
		archers.tick(Battle.STEP)
		var b: Dictionary = archers.squads[BOWS]
		if b.ammo < 18:
			shot_at = Vector2(b.x, b.z).distance_to(Vector2(archers.squads.ridge_bows.x, archers.squads.ridge_bows.z))
			break
	check(shot_at > Battle.ADVANCE_STANDOFF and shot_at <= 11.5, "Advancing archers open fire at bow range before the standoff (%.2f m)" % shot_at)


func _strike(m, cmd: String) -> Dictionary:
	var g: Dictionary = m.squads[GUARD]
	var foe: Dictionary = m.squads[ENEMY]
	m.order([GUARD], cmd, ENEMY)
	var cohesion := 0.0
	for i in 20:
		cohesion = g.cohesion
		var dealt: float = foe.initial_strength - foe.strength + foe.damage
		m.tick(Battle.STEP)
		if g.action_step == m.steps:
			return {"damage": foe.initial_strength - foe.strength + foe.damage - dealt, "cohesion": cohesion, "step": m.steps}
	return {}


func _test_charge() -> void:
	var a := Battle.new()
	var b := Battle.new()
	for m in [a, b]:
		check(_place(m, {GUARD: Vector2(-7, 8), ENEMY: Vector2(-7, 5.2)}), "Charge contact fixture loads")
		m.order([BOWS], "cease_fire")
	var charged := _strike(a, "charge")
	var plain := _strike(b, "attack")
	var cfg := Formula.balance()
	var expected: float = float(cfg.unit.charge) * Formula.unit_factor(cfg, "cohesion", {"attackers": {"cohesion": charged.get("cohesion", 0.0)}}) \
		/ Formula.unit_factor(cfg, "cohesion", {"attackers": {"cohesion": plain.get("cohesion", 0.0)}})
	check(not charged.is_empty() and not plain.is_empty() and charged.step == plain.step and absf(charged.damage / plain.damage - expected) < 0.000001,
		"The first charge strike hits by the configured charge factor harder, less what the loosened ranks cost")
	var g: Dictionary = a.squads[GUARD]
	var impacts := 0
	for memory: Dictionary in g.memories:
		impacts += int(memory.event == "charge_impact")
	check(impacts == 1 and g.command == "attack" and not g.charge_bonus, "The charge bonus applies once; then the melee continues")
	var run := Battle.new()
	var r: Dictionary = run.squads[GUARD]
	check(run.order([GUARD], "charge", ENEMY).ok and r.charge_bonus, "Charge accepted")
	var fastest := 0.0
	var loosest := 100.0
	for i in 40:
		var at := Vector2(r.x, r.z)
		run.tick(Battle.STEP)
		fastest = maxf(fastest, at.distance_to(Vector2(r.x, r.z)))
		if r.command == "charge" and r.status == "moving":
			loosest = minf(loosest, r.cohesion)
		if r.command != "charge":
			break
	metrics["charge"] = {"anchor_step_m": snappedf(fastest, 0.0001), "lowest_cohesion": snappedf(loosest, 0.01)}
	check(is_equal_approx(fastest, Battle.CHARGE_SPEED * Battle.STEP) and loosest <= 85.0, "A charge runs at 2.65 m/s with loosened ranks (cohesion %.1f)" % loosest)


func _test_face_and_fire() -> void:
	var m := Battle.new()
	var g: Dictionary = m.squads[GUARD]
	var start := Vector2(g.x, g.z)
	check(m.order([GUARD], "face", start + Vector2(10, 0)).ok, "Face accepted")
	for i in 20:
		m.tick(Battle.STEP)
		if g.command == "hold":
			break
	check(g.command == "hold" and is_equal_approx(g.facing, -PI / 2) and start.distance_to(Vector2(g.x, g.z)) < 0.0001, "Face turns in place to the given point")
	var bows: Dictionary = m.squads[BOWS]
	check(m.order([BOWS], "cease_fire").ok and not bows.fire, "Cease fire")
	check(m.order([BOWS], "focus_fire", ENEMY).ok and m.order([BOWS], "fire_at_will").ok and bows.fire and bows.command == "hold" and bows.target == "",
		"Fire at will drops the focus target and keeps shooting freely")
	var free := Battle.new()
	check(_place(free, {ENEMY: Vector2(1, 4)}), "Fire-at-will fixture loads")
	free.order([BOWS], "cease_fire")
	free.tick(2.0)
	check(free.squads[BOWS].ammo == 18, "No volleys while fire is ceased")
	free.order([BOWS], "fire_at_will")
	free.tick(2.0)
	check(free.squads[BOWS].ammo < 18, "Fire at will resumes volleys on the nearest enemy in range")


func _test_pila() -> void:
	var m := Battle.new()
	check(_place(m, {GUARD: Vector2(-5, 8), ENEMY: Vector2(-5, -2)}, {ENEMY: "shield_wall"}), "Pila fixture loads")
	var g: Dictionary = m.squads[GUARD]
	var foe: Dictionary = m.squads[ENEMY]
	foe.facing = m._bearing(foe, Vector2(g.x, g.z))
	var guarded := m._shield_factor(g, foe, true)
	check(g.pila == 2 and m.order([GUARD], "pila", ENEMY).ok, "A legionary company carries two pila and may throw")
	var thrown := -1
	for i in 40:
		m.tick(Battle.STEP)
		if g.pila < 2:
			thrown = m.steps
			break
	check(thrown > 0 and g.pila == 1 and g.last_action == "throw" and g.command == "hold", "One pila order throws exactly one volley")
	check(foe.shields_fouled_until == thrown + Battle.PILA_FOUL_STEPS and guarded < 1.0 and m._shield_factor(g, foe, true) == 1.0, "Pila foul the target's shields for 10 s")
	for i in 25:
		m.tick(Battle.STEP)
	check(g.pila == 1, "No further throw without a new order")
	m.steps = foe.shields_fouled_until
	var restored := m._shield_factor(g, foe, true)
	metrics["shield_after_pila"] = {"before": snappedf(guarded, 0.0001), "after_10s": snappedf(restored, 0.0001), "shield_wear": snappedf(foe.wear.shield, 0.0001)}
	check(restored < 1.0 and restored >= guarded and restored - guarded < 0.01, "Shields work again after 10 s, only a little worn (%.4f -> %.4f)" % [guarded, restored])
	var far := Battle.new()
	check(_place(far, {GUARD: Vector2(-7, 8), ENEMY: Vector2(-7, -14)}), "Distant pila fixture loads")
	var fg: Dictionary = far.squads[GUARD]
	far.order([GUARD], "pila", ENEMY)
	var range_at := -1.0
	for i in 120:
		far.tick(Battle.STEP)
		if fg.pila < 2:
			range_at = Vector2(fg.x, fg.z).distance_to(Vector2(far.squads[ENEMY].x, far.squads[ENEMY].z))
			break
	check(range_at > 0.0 and range_at <= Battle.PILA_RANGE, "Out of range the company closes to 12 m before throwing (%.2f m)" % range_at)
	far.order([GUARD], "pila", ENEMY)
	for i in 60:
		far.tick(Battle.STEP)
		if fg.pila == 0:
			break
	var spent := far.snapshot()
	check(fg.pila == 0 and not far.order([GUARD], "pila", ENEMY).ok and far.snapshot() == spent, "With no pila left the order is refused atomically")
	check(Battle.new().restore(JSON.parse_string(JSON.stringify(spent))), "Spent pila save validly")


func _test_orbis_and_testudo() -> void:
	var m := Battle.new()
	var g: Dictionary = m.squads[GUARD]
	check(m.order([GUARD], "form", "orbis").ok, "A drilled legionary company forms the orbis")
	var mid := m.snapshot()
	check(not m.order([GUARD], "move", Vector2(-7, 2)).ok and not m.order([GUARD], "charge", ENEMY).ok and not m.order([GUARD], "fall_back").ok and m.snapshot() == mid,
		"No marching out of the circle; refusals are atomic")
	m.tick(1.4)
	check(g.formation == "orbis" and m.preview(GUARD, Vector2(-10, 12), Vector2(-4, 12)).is_empty(), "The orbis is formed in place, not drawn along a front")
	m.tick(2.0)
	var outward := true
	for man: Dictionary in m.soldiers(GUARD):
		var out := Vector2(man.x, man.z) - Vector2(g.x, g.z)
		outward = outward and Vector2(-sin(man.facing), -cos(man.facing)).dot(out.normalized()) > 0.95
	check(outward, "Every soldier of the orbis faces outwards")
	var behind := Vector2(g.x, g.z) - m._front(g) * 3.0
	var ring := {"shield": m._shield(g), "formation": "orbis"}
	var b := Formula.balance()
	check(not m._from_rear(g, behind) and Formula.shield_cover(b, ring, -1.0, false) == Formula.shield_cover(b, ring, 1.0, false) and m._shield_factor(m.squads[ENEMY], g, false) < 1.0,
		"The orbis has no rear and its shields cover every side")
	check(Battle.new().restore(JSON.parse_string(JSON.stringify(m.snapshot()))), "The orbis saves")
	check(m.order([GUARD], "form", "line").ok, "The orbis can be left by re-forming")
	check(not m.order([SPEARS], "form", "orbis").ok and not m.order([BOWS], "form", "orbis").ok, "Undrilled militia and archers cannot form the orbis")
	check(m.order([GUARD], "form", "testudo").ok and m._form_problem(m.squads[ENEMY], "testudo") != "" and not m.order([SPEARS], "form", "testudo").ok,
		"Testudo needs scuta and drill: legionaries yes, Germanic round shields and militia no")
	var recruits := VALLEY_WITH("roman_tiro")
	var tiro := Battle.new(58, recruits)
	check(tiro.squads[GUARD].troop_id == "roman_tiro" and not tiro.order([GUARD], "form", "testudo").ok and tiro.order([GUARD], "form", "shield_wall").ok,
		"Recruits (drill 1) cannot yet form the testudo")
	var veterans := Battle.new(58, VALLEY_WITH("roman_veteranus"))
	check(veterans.order([GUARD], "form", "testudo").ok, "Veterans form the testudo")


func VALLEY_WITH(troop: String) -> Dictionary:
	var scenario: Dictionary = Battle.VALLEY_SCENARIO.duplicate(true)
	scenario.companies[0].troop_id = troop
	return scenario


func _test_invalid_orders() -> void:
	var m := Battle.new()
	var g: Dictionary = m.squads[GUARD]
	var before := m.snapshot()
	for attempt in [[[GUARD], "follow", GUARD], [[GUARD], "follow", ENEMY], [[GUARD], "follow", "nobody"], [[GUARD, SPEARS], "follow", SPEARS],
			[[GUARD], "advance", BOWS], [[GUARD], "charge", null], [[BOWS], "charge", ENEMY], [[BOWS], "pila", ENEMY], [[SPEARS], "pila", ENEMY],
			[[GUARD, BOWS], "pila", ENEMY], [[GUARD], "face", null], [[GUARD], "face", Vector2(INF, 0)], [[GUARD], "face", Vector2(g.x, g.z)],
			[[GUARD], "fire_at_will", null], [[GUARD, BOWS], "fire_at_will", null], [[SPEARS], "form", "orbis"], [[GUARD], "advance", "nobody"]]:
		var reply := m.order(attempt[0], attempt[1], attempt[2])
		check(not reply.ok and reply.message != "" and m.snapshot() == before, "Invalid order rejected atomically: %s %s" % [attempt[1], str(attempt[2])])
	check(m.order([SPEARS], "follow", GUARD).ok, "A company may follow another")
	var following := m.snapshot()
	check(not m.order([GUARD], "follow", SPEARS).ok and m.snapshot() == following, "Following in a circle is refused")
	m.tick(12)
	var lead: Dictionary = m.squads[GUARD]
	var spears: Dictionary = m.squads[SPEARS]
	var spot: Vector2 = m._follow_spot(spears, lead)
	check(spears.command == "follow" and Vector2(spears.x, spears.z).distance_to(spot) <= 0.6, "The follower takes its place behind the leading company")
	for change in [["pila", 5], ["charge_bonus", true], ["shields_fouled_until", 999], ["command", "fire_at_will"], ["commandable_by", ["dux_hoehenbund"]]]:
		var bad := Battle.new().snapshot()
		bad.squads[GUARD][change[0]] = change[1]
		check(not Battle.new().restore(bad), "Reject invalid snapshot field " + change[0])
	var wrong := Battle.new().snapshot()
	wrong.squads[GUARD].command = "follow"
	wrong.squads[GUARD].target = ENEMY
	check(not Battle.new().restore(wrong), "Reject following an enemy in a save")
	var throwing := Battle.new().snapshot()
	throwing.squads[BOWS].last_action = "throw"
	throwing.squads[BOWS].action_step = 1
	throwing.steps = 2
	check(not Battle.new().restore(throwing), "Reject a pila throw by archers in a save")


func _test_order_determinism() -> void:
	var runs := []
	for k in 2:
		var m := Battle.new(11)
		m.order([GUARD], "pila", ENEMY)
		m.order([SPEARS], "follow", GUARD)
		m.order([BOWS], "advance")
		m.tick(12)
		m.order([GUARD], "charge", ENEMY)
		m.tick(10)
		m.order([GUARD], "fall_back")
		m.tick(10)
		runs.append(m.snapshot())
	check(runs[0] == runs[1], "New orders keep the battle deterministic")
	check(Battle.new().restore(runs[0]), "The resulting state validates")


func _test_wounds_and_recovery() -> void:
	var counts := {"dead": 0, "light": 0, "serious": 0, "crippling": 0, "impaired": 0}
	for i in 2000:
		var fate := Roster.casualty(58, "probe_%04d" % i, 37)
		if fate.status == "dead":
			counts.dead += 1
		else:
			counts[fate.wound.severity] += 1
			counts.impaired += int(fate.wound.impairment != "")
	metrics["wound_outcomes_2000"] = counts
	check(absf(counts.dead / 2000.0 - Roster.KILLED_SHARE) < 0.04 and counts.light > counts.serious and counts.serious > counts.crippling and counts.crippling > 0,
		"Casualty fates follow the design shares (killed %d, light %d, serious %d, crippling %d)" % [counts.dead, counts.light, counts.serious, counts.crippling])
	check(Roster.casualty(58, "probe_0001", 37) == Roster.casualty(58, "probe_0001", 37), "A fate is reproducible from seed, soldier and step")
	var m := Battle.new()
	var person: Dictionary = m.squads[GUARD].people.values()[3]
	person.status = "wounded"
	person.wound = {"severity": "serious", "recovery_days": 40, "impairment": "Hinken", "outcome": "return_impaired", "step": 5}
	var half := Roster.recover(person, 25, -58)
	check(half.status == "wounded" and half.wound.recovery_days == 15 and person.wound.recovery_days == 40, "Recovery advances on a copy")
	var healed := Roster.recover(half, 20, -58)
	check(healed.status == "active" and healed.wound.is_empty() and healed.impairments == ["Hinken"] and healed.service.back().event == "recovered",
		"A seriously wounded soldier returns with a permanent impairment")
	person.wound = {"severity": "crippling", "recovery_days": 60, "impairment": "Verlust eines Auges", "outcome": "retire", "step": 5}
	var retired := Roster.recover(person, 60, -57)
	check(retired.status == "retired" and retired.impairments == ["Verlust eines Auges"] and retired.service.back() == {"event": "retired", "ref": "Verlust eines Auges", "year": -57, "step": -1},
		"A crippled soldier leaves the service and keeps his record")
	person.status = "dead"
	person.wound = {"severity": "fatal", "recovery_days": 0, "impairment": "", "outcome": "dead", "step": 5}
	check(Roster.recover(person, 400, -50).status == "dead", "The dead do not recover")


func _duel_scenario(ally: Dictionary, enemy: Dictionary) -> Dictionary:
	var scenario: Dictionary = Battle.VALLEY_SCENARIO.duplicate(true)
	scenario.id = "duel_bench"
	scenario.companies = [
		{"id": GUARD, "title": "Veteranen", "side": "ally", "kind": "infantry", "shape": "line", "at": Vector2(-7, 8), "count": 12,
			"troop_id": ally.troop, "kit_quality": ally.q, "origin": "gallia_cisalpina", "commandable_by": ["legatus_valdora"]},
		{"id": ENEMY, "title": "Rekruten", "side": "enemy", "kind": "infantry", "shape": "line", "at": Vector2(-7, 4.6), "count": 12,
			"troop_id": enemy.troop, "kit_quality": enemy.q, "origin": "gallia_cisalpina", "commandable_by": ["dux_hoehenbund"]},
	]
	return scenario


func _fight(ally: Dictionary, enemy: Dictionary, seed_value: int) -> Dictionary:
	var m := Battle.new(seed_value, _duel_scenario(ally, enemy))
	m.order([GUARD], "attack", ENEMY)
	m.tick(120)
	return {"outcome": m.outcome, "ally_left": m.squads[GUARD].strength, "enemy_left": m.squads[ENEMY].strength, "seconds": m.steps * Battle.STEP}


func _test_formula_battle() -> void:
	var m := Battle.new()
	check(_place(m, {GUARD: Vector2(-7, 8), ENEMY: Vector2(-7, 5.2)}), "Formula contact fixture loads")
	m.order([BOWS], "cease_fire")
	var g: Dictionary = m.squads[GUARD]
	var foe: Dictionary = m.squads[ENEMY]
	m.order([GUARD], "attack", ENEMY)
	var matched := false
	for i in 20:
		var expected: float = Formula.unit_strike(m.strike_input(g, foe, "melee")).casualties
		var dealt: float = foe.initial_strength - foe.strength + foe.damage
		m.tick(Battle.STEP)
		if g.action_step == m.steps:
			matched = absf(foe.initial_strength - foe.strength + foe.damage - dealt - expected) < 0.000001
			break
	check(matched, "A company's strike deals exactly what the combat formula returns (no other multiplier in the battle)")
	check(g.wear.weapon > 0.0 and foe.wear.shield > 0.0, "Strikes wear the attacker's weapons and the defender's shields")
	var duels := {}
	var won := true
	for seed_value in [3, 17, 58]:
		var forward := _fight({"troop": "roman_veteranus", "q": 1}, {"troop": "roman_tiro", "q": 4}, seed_value)
		var mirrored := _fight({"troop": "roman_tiro", "q": 4}, {"troop": "roman_veteranus", "q": 1}, seed_value)
		duels["seed_%d" % seed_value] = [forward, mirrored]
		won = won and forward.outcome == "victory" and mirrored.outcome == "defeat"
	metrics["veterans_q1_vs_recruits_q4"] = duels
	check(won, "Veterans in ordinary kit beat as many recruits in master kit, on either side of the bench")
	var gear := true
	for seed_value in [3, 17]:
		gear = gear and _fight({"troop": "roman_tiro", "q": 4}, {"troop": "roman_tiro", "q": 1}, seed_value).outcome == "victory"
		gear = gear and _fight({"troop": "roman_tiro", "q": 1}, {"troop": "roman_tiro", "q": 4}, seed_value).outcome == "defeat"
	check(gear, "Between equally trained companies the better kit wins")
	check(_fight({"troop": "roman_veteranus", "q": 1}, {"troop": "roman_tiro", "q": 4}, 3) == duels.seed_3[0], "Company duels are reproducible")
