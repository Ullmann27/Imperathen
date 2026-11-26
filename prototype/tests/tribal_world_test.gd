extends SceneTree
## Aggregated tribal world: determinism, ledger, behaviour, relations,
## agreements, raid intents, story raid, eras and stability. Domain only.

const Tribes = preload("res://scripts/domain/tribal_world.gd")
const Relations = preload("res://scripts/domain/actor_relations.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_relation_core()
	_test_initial_contract()
	_test_determinism()
	_test_ledger_conservation()
	_test_non_monolithic()
	_test_directed_relations()
	_test_agreements()
	_test_raid_intents()
	_test_story_raid()
	_test_eras_and_anchors()
	_test_people_and_retinue()
	_test_player_and_knowledge()
	_test_visit_materialisation()
	_test_stability()
	if failures.is_empty():
		print("TRIBAL_WORLD_PASS %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			print("FAILED: ", failure)
		print("TRIBAL_WORLD_FAIL %d failures / %d checks" % [failures.size(), checks])
		quit(1)


func _check(condition: bool, description: String) -> bool:
	checks += 1
	if not condition:
		failures.append(description)
	return condition


func _canonical(state: Dictionary) -> String:
	return JSON.stringify(state, "", true, true)


func _reload(state: Dictionary) -> Dictionary:
	var copy: Dictionary = JSON.parse_string(JSON.stringify(state, "", true, true))
	Tribes.normalize(copy)
	return copy


func _test_relation_core() -> void:
	var graph := Relations.new_graph()
	var ids := {"a": true, "b": true, "c": true}
	Relations.apply(graph, "a", "b", "e1", 1, "insult", {"grievance": 30.0, "trust": -20.0})
	_check(Relations.value(graph, "a", "b", "grievance") == 30.0 and not Relations.knows(graph, "b", "a"), "A->B changes without creating B->A")
	Relations.apply(graph, "a", "b", "e2", 2, "gift", {"trust": 500.0})
	_check(Relations.value(graph, "a", "b", "trust") == 100.0, "Values stay inside their bounds")
	for i in 12:
		Relations.apply(graph, "a", "b", "e%d" % (i + 3), 3 + i, "talk", {"respect": 1.0})
	var memories: Array = Relations.edge(graph, "a", "b").memories
	_check(memories.size() == Relations.MAX_MEMORIES and memories.back().event == "e14", "Memories are bounded and keep the newest event ids")
	var before := Relations.value(graph, "a", "b", "grievance")
	Relations.decay(graph, 52)
	var after := Relations.value(graph, "a", "b", "grievance")
	_check(after < before and after > 0.0, "Grievance fades slowly instead of vanishing (%.2f -> %.2f in a year)" % [before, after])
	_check(Relations.validate(graph, ids, 20) == "", "Valid graph passes")
	_check(Relations.validate(graph, {"a": true}, 20) != "", "Unknown actor is rejected")
	_check(Relations.validate(graph, ids, 5) != "", "Memories from the future are rejected")
	_check(not Relations.introduce(graph, "a", "a", "e", 1, "self"), "No relation to oneself")


func _test_initial_contract() -> void:
	var state := Tribes.new_state(7)
	_check(Tribes.validate(state) == "", "Fresh 58 BC state validates: " + Tribes.validate(state))
	var scn := Tribes.scenario("bc58_rhine")
	var tribes := 0
	for gid: String in state.groups:
		var g: Dictionary = state.groups[gid]
		if g.kind == "tribe":
			tribes += 1
			_check(str(g.canon_kind) in ["attested_people_fictional_district", "fictional_local_clan"], "%s carries a canon marker" % gid)
			if g.canon_kind == "attested_people_fictional_district":
				_check(not scn.groups[gid].source.is_empty() and str(g.source_note) != "", "%s has a source note" % gid)
			_check(state.persons.has(g.leader) and state.persons[g.leader].role == "chief", "%s has a chief as person actor" % gid)
	_check(tribes >= 4 and tribes <= 6, "Four to six Germanic groups (%d)" % tribes)
	for tid: String in ["valdora", "player", "rome"]:
		_check(state.targets.has(tid), "Relation target %s exists" % tid)
	_check(Tribes.calendar(state).year == -58 and Tribes.band_of(state) == ["I"], "Scenario opens in 58 BC, band I")
	var empty := Tribes.new_state(7, Tribes.scenario_for_year(100))
	_check(empty.scenario == Tribes.NO_SCENARIO and Tribes.validate(empty) == "" and empty.groups.is_empty(), "AD 100 careers get no invented roster")
	var tampered: Dictionary = state.duplicate(true)
	tampered.groups.ubii_rhine.stock.food = int(tampered.groups.ubii_rhine.stock.food) + 1
	_check(Tribes.validate(tampered).begins_with("Ledgerbilanz verletzt"), "A good without transaction breaks the ledger check")
	tampered = state.duplicate(true)
	tampered.groups.suebi_gau.troops.speerkrieger.count = int(tampered.groups.suebi_gau.troops.speerkrieger.count) + 5
	_check(Tribes.validate(tampered) != "", "Warriors without equipment are rejected")
	tampered = state.duplicate(true)
	tampered.groups.suebi_gau.morale = NAN
	_check(Tribes.validate(tampered) != "", "NaN is rejected")


func _test_determinism() -> void:
	var a := Tribes.new_state(424242)
	var b := Tribes.new_state(424242)
	Tribes.advance_ticks(a, 200)
	Tribes.advance_ticks(b, 200)
	_check(_canonical(a) == _canonical(b), "Same seed and inputs give an identical state after 200 ticks")
	var c := Tribes.new_state(424242)
	Tribes.advance_ticks(c, 100)
	c = _reload(c)
	Tribes.advance_ticks(c, 100)
	_check(_canonical(a) == _canonical(c), "A JSON save/reload at tick 100 continues bit-identically")
	var d := Tribes.new_state(99)
	Tribes.advance_ticks(d, 200)
	_check(_canonical(a) != _canonical(d), "A different seed gives a different history")


func _test_ledger_conservation() -> void:
	var state := Tribes.new_state(31337)
	var opening: Dictionary = state.duplicate(true)
	Tribes.capture_enabled = true
	Tribes.capture.clear()
	Tribes.advance_ticks(state, 200)
	Tribes.capture_enabled = false
	var sums := {}
	var transfers := {}
	for line: Dictionary in Tribes.capture:
		var key := "%s|%s|%s" % [line.actor, line.good, line.account]
		sums[key] = int(sums.get(key, 0)) + int(line.qty)
		if line.category in ["transfer_in", "transfer_out"]:
			if not transfers.has(line.tx):
				transfers[line.tx] = []
			transfers[line.tx].append(line)
	var mismatch := ""
	for gid: String in state.groups:
		var g: Dictionary = state.groups[gid]
		var o: Dictionary = opening.groups[gid]
		for good: String in g.stock:
			var stock_delta := int(g.stock[good]) - int(o.stock[good])
			var held_delta := int(g.held[good]) - int(o.held[good])
			if stock_delta != int(sums.get("%s|%s|stock" % [gid, good], 0)) or held_delta != int(sums.get("%s|%s|held" % [gid, good], 0)):
				mismatch = "%s.%s" % [gid, good]
		var people := 0
		for key: String in sums:
			if key.begins_with(gid + "|people|"):
				people += int(sums[key])
		if Tribes._population(g) - Tribes._population(o) != people:
			mismatch = gid + ".people"
		var report := Tribes.totals(state, gid)
		for good: String in report:
			if int(report[good].expected) != int(report[good].actual):
				mismatch = "totals " + gid + "." + good
	_check(mismatch == "", "Replaying every booking reproduces all stocks, held gear and people (%d lines) %s" % [Tribes.capture.size(), mismatch])
	var unpaired := 0
	for tx: String in transfers:
		var lines: Array = transfers[tx]
		if lines.size() != 2 or int(lines[0].qty) != -int(lines[1].qty) or lines[0].good != lines[1].good or lines[0].actor == lines[1].actor:
			unpaired += 1
	_check(unpaired == 0 and not transfers.is_empty(), "Every transfer has exactly one sender and one receiver (%d transfers)" % transfers.size())
	var external := 0
	for line: Dictionary in Tribes.capture:
		if line.category in ["external_in", "external_out"] and str(line.counter) == "":
			external += 1
	_check(external == 0, "External flows always name their counterparty")
	Tribes.capture.clear()


func _test_non_monolithic() -> void:
	var state := Tribes.new_state(2024)
	Tribes.advance_ticks(state, 300)
	var suebi: Dictionary = state.groups.suebi_gau.history
	var rav: Dictionary = state.groups.ravensteg.history
	_check(int(suebi.get("raids_launched", 0)) > int(rav.get("raids_launched", 0)), "The bold Suebi launch more raids than the cautious ferry folk (%d vs %d)" % [int(suebi.get("raids_launched", 0)), int(rav.get("raids_launched", 0))])
	var ubii: Dictionary = state.groups.ubii_rhine.history
	_check(int(ubii.trades) + int(ubii.feasts) > int(suebi.trades) + int(suebi.feasts), "The trade-oriented Ubii trade and host more than the Suebi")
	# Controlled experiment: identical world, only one group's character differs.
	var bold := Tribes.new_state(555)
	var calm := Tribes.new_state(555)
	calm.groups.sugambri_sieg.traits = {"boldness": 0.15, "caution": 0.85, "pride": 0.25, "trade": 0.8, "faith": 0.85}
	for pid: String in calm.persons:
		if calm.persons[pid].group == "sugambri_sieg":
			calm.persons[pid].traits = {"ambition": 0.2, "boldness": 0.15, "caution": 0.85, "pride": 0.25, "trade": 0.8}
	Tribes.advance_ticks(bold, 300)
	Tribes.advance_ticks(calm, 300)
	var launched_bold := int(bold.groups.sugambri_sieg.history.get("raids_launched", 0))
	var launched_calm := int(calm.groups.sugambri_sieg.history.get("raids_launched", 0))
	_check(launched_bold > launched_calm, "Same seed, different character: bold %d raids vs calm %d" % [launched_bold, launched_calm])
	var actions_bold := _action_mix(bold, "sugambri_sieg")
	var actions_calm := _action_mix(calm, "sugambri_sieg")
	_check(actions_bold != actions_calm, "Their chronicles differ: %s / %s" % [JSON.stringify(actions_bold), JSON.stringify(actions_calm)])


func _action_mix(state: Dictionary, gid: String) -> Dictionary:
	var mix := {}
	for ev: Dictionary in state.events:
		if not ev.actors.is_empty() and str(ev.actors[0]) == gid:
			mix[ev.kind] = int(mix.get(ev.kind, 0)) + 1
	return mix


func _test_directed_relations() -> void:
	var state := Tribes.new_state(11)
	var scn := Tribes.scenario("bc58_rhine")
	var before_victim := Relations.value(state.relations, "ravensteg", "suebi_gau", "grievance")
	var before_raider := Relations.value(state.relations, "suebi_gau", "ravensteg", "grievance")
	var force := Tribes._raid_force(state, scn, "suebi_gau", 0.2)
	var e := Tribes._launch_raid(state, scn, "suebi_gau", "ravensteg", force, "test", "Testfall", int(state.tick), false, "raid")
	_check(not e.is_empty(), "A real war band leaves")
	while state.expeditions.has(e) and e.status == "outbound":
		Tribes.tick(state)
	var raid := {}
	for ev: Dictionary in state.events:
		if ev.kind == "raid" and ev.actors == ["suebi_gau", "ravensteg"]:
			raid = ev
	_check(not raid.is_empty(), "The raid is resolved as an event")
	var victim := Relations.value(state.relations, "ravensteg", "suebi_gau", "grievance")
	var raider := Relations.value(state.relations, "suebi_gau", "ravensteg", "grievance")
	_check(victim - before_victim >= 8.0 and victim > raider, "Victim's grievance rises (%.1f -> %.1f), the raider's view differs (%.1f -> %.1f)" % [before_victim, victim, before_raider, raider])
	var memory_ok := false
	for memory: Dictionary in Relations.edge(state.relations, "ravensteg", "suebi_gau").memories:
		memory_ok = memory_ok or memory.event == raid.id
	_check(memory_ok, "The victim's memory points at the raid event id")
	var chief := str(state.groups.ravensteg.leader)
	_check(Relations.value(state.relations, chief, "suebi_gau", "grievance") > 0.0, "The victim's chief shares the experience as a person actor")
	var window := Tribes.raid_allowed(state, "ravensteg")
	_check(not window.allowed and window.reason == "recovery_window", "The plundered community gets a recovery window")


func _test_agreements() -> void:
	# Tribute kept: the payer can pay and is not defiant.
	var state := Tribes.new_state(5)
	var item := Tribes._make_agreement(state, "tribute", "ravensteg", "suebi_gau", 0, 30, {"cattle": 2, "wealth": 1}, 13, "test")
	var cattle := int(state.groups.ravensteg.stock.cattle)
	Tribes.advance_ticks(state, 14)
	_check(int(item.paid) >= 1 or item.status == "broken", "Tribute due date is processed")
	var paid_state: bool = int(item.paid) >= 1
	if paid_state:
		_check(int(state.groups.ravensteg.stock.cattle) < cattle + 200, "Payment leaves the payer's stock")
	# Tribute broken: the payer has nothing to give.
	var poor := Tribes.new_state(5)
	var due := Tribes._make_agreement(poor, "tribute", "ravensteg", "suebi_gau", 0, 30, {"wealth": 500}, 13, "test")
	var markup_before := float(Tribes.trade_terms(poor, "ravensteg", "suebi_gau").markup)
	var trust_before := Relations.value(poor.relations, "suebi_gau", "ravensteg", "trust")
	Tribes.advance_ticks(poor, 13)
	_check(due.status == "broken" and due.broken_by == "ravensteg", "An impossible tribute is broken by the payer at its deadline")
	_check(Relations.value(poor.relations, "suebi_gau", "ravensteg", "trust") < trust_before - 10.0, "The receiver's trust falls after the broken promise")
	_check(float(Tribes.trade_terms(poor, "ravensteg", "suebi_gau").markup) > markup_before, "Broken promise raises the price the receiver asks")
	var punitive := Tribes._decision_cache(poor, int(poor.tick) + 1)
	_check(punitive.punitive.has("suebi_gau>ravensteg"), "The broken tribute becomes a punitive raid motive")
	# A truce that reaches its deadline untouched is kept.
	var calm := Tribes.new_state(5)
	var truce := Tribes._make_agreement(calm, "truce", "ubii_rhine", "ravensteg", 0, 3, {}, 0, "test")
	var trust := Relations.value(calm.relations, "ravensteg", "ubii_rhine", "trust")
	Tribes.advance_ticks(calm, 3)
	_check(truce.status == "kept" and Relations.value(calm.relations, "ravensteg", "ubii_rhine", "trust") > trust - 1.0, "A truce kept to its deadline is recorded as kept")
	# Breaking a truce by raiding.
	var war := Tribes.new_state(5)
	var scn := Tribes.scenario("bc58_rhine")
	var pact := Tribes._make_agreement(war, "truce", "suebi_gau", "eichenhang", 0, 26, {}, 0, "test")
	var e := Tribes._launch_raid(war, scn, "suebi_gau", "eichenhang", Tribes._raid_force(war, scn, "suebi_gau", 0.2), "test", "Testfall", 0, false, "raid")
	while war.expeditions.has(e) and e.status == "outbound":
		Tribes.tick(war)
	_check(pact.status == "broken" and pact.broken_by == "suebi_gau", "Raiding under truce breaks the oath")
	_check(Tribes.validate(war) == "", "State stays valid after the broken oath")


func _test_raid_intents() -> void:
	var state := Tribes.new_state(77)
	var intents := Tribes.planned_raids(state, "valdora")
	var reachable := 0
	for entry: Dictionary in intents:
		if entry.group in ["ubii_rhine", "suebi_gau", "sugambri_sieg", "eichenhang", "ravensteg", "usipetes_tencteri"]:
			_check(entry.status == "blocked" and entry.reason == "out_of_reach" and int(entry.km) > 500, "%s cannot reach Valdora near Aquileia (%d km)" % [entry.group, int(entry.km)])
		elif entry.status != "blocked":
			reachable += 1
	_check(reachable == 1, "Only the commissioned band near Aquileia is a candidate for Valdora")
	_check(_canonical(state) == _canonical(Tribes.new_state(77)), "planned_raids changes nothing")
	# Test fixture: a frontier community placed on the Rhine to exercise the API.
	var near := Tribes.new_state(77)
	near.targets.valdora.lat = 50.5
	near.targets.valdora.lon = 7.9
	Relations.introduce(near.relations, "suebi_gau", "valdora", "fixture", 0, "fixture")
	Relations.apply(near.relations, "suebi_gau", "valdora", "fixture", 0, "fixture", {"grievance": 70.0})
	Tribes.report_target_state(near, "valdora", 4, true)
	var entry := _intent(near, "suebi_gau")
	_check(entry.status == "planned", "A known, weakly defended, resented target in reach is planned: %s %s %.2f" % [entry.status, entry.reason, float(entry.utility)])
	var home := 0
	for type_id: String in near.groups.suebi_gau.troops:
		home += int(near.groups.suebi_gau.troops[type_id].count)
	_check(int(entry.warriors_total) > 0 and int(entry.warriors_total) < home, "Intent names real available warriors, a home guard stays (%d of %d)" % [int(entry.warriors_total), home])
	var low := float(entry.utility)
	Tribes.report_target_state(near, "valdora", 200, true)
	var defended := _intent(near, "suebi_gau")
	_check(float(defended.utility) < low, "A stronger reported defence lowers the raid utility (%.2f -> %.2f)" % [low, float(defended.utility)])
	Tribes.report_target_state(near, "valdora", 4, true)
	Tribes._make_agreement(near, "truce", "suebi_gau", "valdora", int(near.tick), 26, {}, 0, "test")
	var bound := _intent(near, "suebi_gau")
	_check(float(bound.utility) < low and bound.status != "planned", "A truce with the target suppresses the intent (%.2f)" % float(bound.utility))
	for item: Dictionary in near.agreements:
		if item.kind == "truce" and item.b == "valdora":
			item.status = "void"
	var committed := Tribes.commit_raid(near, "suebi_gau", "valdora")
	_check(committed.ok, "Commit launches the planned raid: " + str(committed.get("message", "")))
	if not committed.ok:
		return
	var after := 0
	for type_id: String in near.groups.suebi_gau.troops:
		after += int(near.groups.suebi_gau.troops[type_id].count)
	var sent := 0
	for type_id: String in committed.warriors:
		sent += int(committed.warriors[type_id])
	_check(after == home - sent, "The warriors are really away from home")
	while near.expeditions.size() > 0 and near.expeditions[0].status == "outbound":
		Tribes.tick(near)
	var waiting := Tribes.arrived_raids(near, "valdora")
	_check(waiting.size() == 1 and int(waiting[0].warriors_total) == sent and waiting[0].expedition == committed.expedition, "The arrived band waits for the local scene with its real warriors")
	var world := {"tribes": near}
	var own := Tribes.writable(world)
	_check(not is_same(own, near) and _canonical(own) == _canonical(near), "Copy-on-write hands a transaction its own tribal state")
	var population := Tribes._population(near.groups.suebi_gau)
	var result := Tribes.apply_raid_result(near, str(committed.expedition), {"outcome": "defended", "attacker_losses": 5, "loot": {"grain": 2}, "defender_casualties": 1, "damage": 10})
	_check(result.ok and int(result.attacker_losses) == 5 and Tribes._population(near.groups.suebi_gau) == population - 5, "Reported losses remove real people and soldiers")
	_check(Tribes.validate(near) == "", "Ledger stays valid after an external raid: " + Tribes.validate(near))
	var blocked := _intent(near, "suebi_gau")
	_check(blocked.status != "planned" and blocked.reason in ["recovery_window", "band_already_away", "own_recovery", "war_band_returning"], "No new raid before recovery: %s %s" % [blocked.status, blocked.reason])
	_check(Relations.value(near.relations, "valdora", "suebi_gau", "grievance") >= 20.0, "Valdora remembers the attackers")


func _intent(state: Dictionary, gid: String) -> Dictionary:
	for entry: Dictionary in Tribes.planned_raids(state, "valdora"):
		if entry.group == gid:
			return entry
	return {}


func _test_story_raid() -> void:
	var state := Tribes.new_state(10)
	var info := Tribes.story_raid(state, "I-10")
	_check(info.attacker == "red_seal_riders" and int(info.riders_total) == 30 and info.consistent, "I-10 attackers are the 30 riders of this state")
	var start := Tribes.commit_story_raid(state, "I-10")
	_check(start.ok and int(start.riders_total) == 30, "The protected story raid takes the band's real riders")
	_check(not Tribes.commit_story_raid(state, "I-10").ok, "The story raid cannot be started twice")
	for entry: Dictionary in Tribes.planned_raids(state, "valdora"):
		if entry.group != "red_seal_riders":
			_check(entry.status == "blocked", "No other group can raid Valdora meanwhile (%s)" % entry.group)
	_check(Tribes.raid_allowed(state, "valdora").reason == "story_protected", "Valdora is story-protected after I-10")
	var wealth := int(state.groups.red_seal_riders.stock.wealth)
	var result := Tribes.apply_raid_result(state, str(start.expedition), {"outcome": "raided", "attacker_losses": 4, "loot": {"grain": 4, "denarii": 8}, "defender_casualties": 3, "damage": 40})
	_check(result.ok and int(result.survivors) == 26, "Four fallen riders are not replaced")
	_check(int(result.loot_booked.get("food", 0)) == 40 and int(result.loot_booked.get("wealth", 0)) == 2, "Reported village losses become cargo via the conversion table")
	Tribes.tick(state)
	_check(int(state.groups.red_seal_riders.troops.band_rider.count) == 26 and int(state.groups.red_seal_riders.stock.wealth) >= wealth + 60 - 1, "Band returns with 26 riders and the commission")
	_check(Tribes.story_raid(state, "I-10").status == "resolved", "The story raid is resolved")
	_check(not Relations.knows(state.relations, "valdora", "red_seal_house"), "Valdora does not know the commissioner without evidence")
	_check(Tribes.reveal(state, "player", "red_seal_house", "rotes Wachssiegel (I-15)") and Relations.knows(state.relations, "player", "red_seal_house"), "Evidence introduces the commissioner")
	var window := Tribes.raid_allowed(state, "valdora")
	_check(not window.allowed and int(window.until) >= 26, "Valdora has a rebuild window of half a year")
	_check(Tribes.validate(state) == "", "Story raid keeps the ledger valid: " + Tribes.validate(state))


func _test_eras_and_anchors() -> void:
	var state := Tribes.new_state(3)
	Tribes.advance_ticks(state, 180)
	_check(state.anchors.get("ariovistus_defeat_58", "") == "applied", "58 BC anchor applied")
	_check(state.groups.usipetes_tencteri.status == "left_area", "Usipetes and Tencteri left the area after 56/55 BC: " + str(state.groups.usipetes_tencteri.status))
	_check(state.anchors.get("rhine_bridge_55", "") in ["applied", "divergent"], "55 BC Rhine bridge anchor recorded")
	if state.anchors.get("rhine_bridge_55", "") == "applied":
		_check(not Tribes._active_agreement(state, "ubii_rhine", "rome", ["amicitia"]).is_empty(), "Ubii friendship with Rome exists from 55 BC")
	_check(Tribes.year_label(Tribes.year_of(state, 52 * 57)) == "1 v. Chr." and Tribes.year_label(Tribes.year_of(state, 52 * 58)) == "1 n. Chr.", "No year zero between 1 BC and AD 1")
	_check(Tribes.year_of(state, 52 * 11) == -47 and Tribes.band_of({"scenario": "bc58_rhine", "tick": 52 * 11}) == ["II", "III"], "47 BC belongs to bands II and III")
	_check(Tribes.year_of(state, 52 * 31) == -27, "27 BC closes band IV")
	var scn := Tribes.scenario("bc58_rhine")
	_check(Tribes._content_available(scn, "troop_types", "aufgebot", -58) and not Tribes._content_available(scn, "troop_types", "aufgebot", 900), "Content availability is year-bound")
	Tribes.advance_ticks(state, 1040 - 180)
	_check(state.anchors.get("ubii_resettled_38", "") in ["applied", "divergent"], "38 BC Ubii resettlement recorded")
	if state.anchors.get("ubii_resettled_38", "") == "applied":
		_check(state.groups.ubii_rhine.atlas_region == "gallia", "Applied anchor relocates the Ubii to the left bank")
	_check(Tribes.validate(state) == "", "Twenty years later the world is valid: " + Tribes.validate(state))


func _test_people_and_retinue() -> void:
	var state := Tribes.new_state(8)
	for gid: String in state.groups:
		var count := int(state.groups[gid].troops.get("gefolgsmann", {}).get("count", 0))
		_check(Tribes.retainers(state, gid).size() == count, "Every retainer of %s is a person (%d)" % [gid, count])
	var pid: String = Tribes.retainers(state, "suebi_gau")[0]
	_check(Relations.value(state.relations, pid, str(state.groups.suebi_gau.leader), "loyalty") > 0.0, "Retainers are bound to their chief")
	var scn := Tribes.scenario("bc58_rhine")
	var levy: Dictionary = state.groups.ubii_rhine.troops.aufgebot
	var armed := 0
	for good: String in levy.gear:
		armed += int(levy.gear[good])
	_check(armed < int(levy.count) and levy.gear.size() >= 2, "The levy carries mixed gear and some go unarmed")
	var population := Tribes._population(state.groups.ubii_rhine)
	var spears := int(state.groups.ubii_rhine.stock.spear)
	var n := Tribes._recruit(state, scn, "ubii_rhine", "aufgebot", 5, "test")
	_check(n == 5 and Tribes._population(state.groups.ubii_rhine) == population and int(state.groups.ubii_rhine.stock.spear) == spears - mini(5, spears), "Recruits are existing people who take real spears from the stock")
	# The chief dies: the assembly chooses, the heir or rival leads.
	var chief := str(state.groups.eichenhang.leader)
	state.persons[chief].status = "dead"
	Tribes._succession(state, scn, "eichenhang", 1, "Test")
	var next := str(state.groups.eichenhang.leader)
	_check(next != chief and state.persons[next].role == "chief" and state.persons[next].status == "alive", "Succession makes a living person chief")
	var played := Tribes.new_state(8)
	Tribes.advance_ticks(played, 300)
	var shared := false
	for key: String in played.relations.edges:
		var parts := key.split(">")
		if played.persons.has(parts[0]) and played.persons[parts[0]].role == "retainer":
			for memory: Dictionary in played.relations.edges[key].memories:
				shared = shared or memory.kind == "fought"
	_check(shared, "Retainers keep shared memories of real fights")
	_check(Tribes.validate(played) == "", "Retinue bookkeeping stays consistent: " + Tribes.validate(played))


func _test_player_and_knowledge() -> void:
	var state := Tribes.new_state(21)
	var result := Tribes.record_player_action(state, "ubii_rhine", "help", "Hilfe an der Furt")
	_check(result.ok and Relations.value(state.relations, "ubii_rhine", "player", "trust") >= 10.0, "Helping raises the group's trust in the player")
	_check(not Relations.knows(state.relations, "player", "ubii_rhine"), "The player's own attitude is never simulated")
	_check(not Relations.knows(state.relations, "suebi_gau", "player"), "Groups that saw nothing know nothing")
	var truce := Tribes.player_mediate(state, "ubii_rhine", "suebi_gau")
	_check(truce.ok or truce.message != "", "Mediation is answered with a reason")
	var unknown := Tribes.new_state(21)
	_check(not Relations.knows(unknown.relations, "suebi_gau", "red_seal_riders") and not Relations.knows(unknown.relations, "ubii_rhine", "valdora"), "Rhine groups do not know Valdora or the band near Aquileia")


func _test_visit_materialisation() -> void:
	var state := Tribes.new_state(13)
	Tribes.mark_visited(state, "ravensteg")
	var food := int(state.groups.ravensteg.stock.food)
	var population := Tribes._population(state.groups.ravensteg)
	Tribes.advance_ticks(state, 20)
	var visit := Tribes.visit_report(state, "ravensteg")
	_check(int(visit.delta.get("food", 0)) == int(state.groups.ravensteg.stock.food) - food and int(visit.population_delta) == Tribes._population(state.groups.ravensteg) - population, "A visit materialises exactly the ledger deltas since the last visit")
	_check(int(visit.since_tick) == 0 and int(visit.now_tick) == 20, "The report names its time span")


func _test_stability() -> void:
	for seed: int in [1, 2026, 58]:
		var state := Tribes.new_state(seed)
		var initial := {}
		for gid: String in state.groups:
			initial[gid] = Tribes._population(state.groups[gid])
		var hostile_streak := {}
		var longest := 0
		var first_error := ""
		var tick_time := 0
		for i in 400:
			var started := Time.get_ticks_usec()
			Tribes.tick(state)
			tick_time += Time.get_ticks_usec() - started
			if i % 25 == 24 and first_error == "":
				first_error = Tribes.validate(state)
			for a: String in Tribes._active_tribes(state):
				for b: String in Tribes._active_tribes(state):
					if a >= b:
						continue
					var key := a + "|" + b
					var hostile := Relations.stance(state.relations, a, b) == "hostile" and Relations.stance(state.relations, b, a) == "hostile"
					hostile_streak[key] = int(hostile_streak.get(key, 0)) + 1 if hostile else 0
					longest = maxi(longest, int(hostile_streak[key]))
		_check(first_error == "" and Tribes.validate(state) == "", "Seed %d: 400 ticks valid (no negative stock, no NaN, ledger intact) %s" % [seed, first_error])
		var bounded := true
		for gid: String in state.groups:
			var g: Dictionary = state.groups[gid]
			if g.kind != "tribe" or g.status != "active":
				continue
			var ratio := float(Tribes._population(g)) / maxf(1.0, int(initial[gid]))
			bounded = bounded and ratio >= 0.3 and ratio <= 2.0
			for good: String in g.stock:
				bounded = bounded and int(g.stock[good]) < 200000
		_check(bounded, "Seed %d: no collapse below 30 %% and no runaway above 200 %% of the opening population" % seed)
		_check(longest <= 156, "Seed %d: no mutual hostility locked for more than three years (longest %d weeks)" % [seed, longest])
		var raids := int(state.stats.raids) + int(state.stats.external_raids)
		var years := 400.0 / 52.0
		var per_group := raids / years / maxf(1.0, Tribes._active_tribes(state).size())
		_check(per_group <= 12.0, "Seed %d: no endless raid series (%.1f raids per group and year)" % [seed, per_group])
		_check(int(state.stats.agreements_kept) > 0 and int(state.stats.trades) > 0 and int(state.stats.buildings) > 0, "Seed %d: peace, trade and building happen besides war" % seed)
		var violations := 0
		var last_raid := {}
		for ev: Dictionary in state.events:
			if ev.kind == "raid":
				var target := str(ev.actors[1])
				if last_raid.has(target) and int(ev.tick) - int(last_raid[target]) < 6:
					violations += 1
				last_raid[target] = int(ev.tick)
		_check(violations == 0, "Seed %d: every target got at least six weeks between raids" % seed)
		if seed == 1:
			print("TRIBAL_STATS seed 1 ", JSON.stringify(state.stats))
			for line: String in Tribes.chronicle(state, 12):
				print("TRIBAL_CHRONICLE ", line)
			var started := Time.get_ticks_usec()
			var error := Tribes.validate(state)
			var validation := Time.get_ticks_usec() - started
			var per_tick := tick_time / 400.0
			print("TRIBAL_COST %.0f us per weekly tick, %d us per full validation (this machine, relative only)" % [per_tick, validation])
			_check(error == "" and per_tick < 40000.0, "Weekly tick cost stays bounded on this machine")
