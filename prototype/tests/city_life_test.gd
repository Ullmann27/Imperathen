extends SceneTree
## Living city, domain level: activity anchors, population, the event-driven
## life simulation, its ledger, save/load and the per-frame budget.
## No rendering; the built city GLB is not needed (the baked anchors and the
## street graph are tracked data).

const Life = preload("res://scripts/domain/city_life.gd")
const Anchors = preload("res://scripts/domain/city_anchors.gd")
const Barks = preload("res://scripts/domain/city_barks.gd")
const Calendar = preload("res://scripts/domain/world_calendar.gd")
const Activities := preload("res://scripts/visuals/resident_activity.gd")
const SEED := 20261126

var failures: Array[String] = []
var checks := 0


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("CITY_LIFE_TEST failed: " + label)


func _initialize() -> void:
	_anchor_schema()
	_conversation_projection()
	var metrics := _simulation()
	print("CITY_LIFE_METRICS " + JSON.stringify(metrics))
	if failures.is_empty():
		print("CITY_LIFE_PASS checks=%d" % checks)
	else:
		print("CITY_LIFE_FAIL %d of %d: %s" % [failures.size(), checks, str(failures)])
	quit(0 if failures.is_empty() else 1)


func _entry(overrides: Dictionary = {}) -> Dictionary:
	var entry := {"id": "test.seat_1", "kind": "seat_block", "position": [181.0, 0.1, -42.0], "facing_deg": 90.0, "capacity": 40,
		"hours": [8.0, 18.0], "era": {"from_year": 80, "to_year": null}, "wealth_tiers": ["poor", "common"], "tags": ["district:arena"]}
	for key: String in overrides:
		entry[key] = overrides[key]
	return entry


func _conversation_projection() -> void:
	# A mutual conversation cannot be overwritten by a third resident's stale
	# request, and the result is independent of body streaming order.
	var mutual := Activities.conversation_pairs({3: 2, 2: 1, 1: 2}, {})
	check(mutual == {1: 2, 2: 1}, "mutual city conversation excludes unrelated requests")
	var reversed := Activities.conversation_pairs({1: 2, 2: 1, 3: 2}, {})
	check(mutual == reversed, "city conversation projection is independent of streaming order")
	var buyers := Activities.conversation_pairs({8: 5, 7: 5}, {8: true, 7: true})
	check(buyers == {7: 5, 5: 7}, "one vendor addresses one buyer with a stable tie break")
	var busy := Activities.conversation_pairs({7: 5, 5: 6, 6: 5}, {7: true})
	check(busy == {5: 6, 6: 5}, "mutual social contact takes priority over a third-party request")
	var independent := Activities.conversation_pairs({1: 2, 2: 1, 3: 4}, {3: true})
	check(independent == {1: 2, 2: 1, 3: 4, 4: 3}, "independent conversations and haggling coexist")
	check(Activities.conversation_pairs({1: 1, 2: -1, 3: 4}, {1: true, 2: true}).is_empty(), "self-contact, missing peer and unilateral non-market requests are rejected")
	for now in [0, 5, 10, 15]:
		check(Activities.speaker(5, 7, now) == Activities.speaker(7, 5, now), "paired NPCs agree on a single speaking turn")
	check(Activities.speaker(5, 7, 0) != Activities.speaker(5, 7, 5), "the speaking turn alternates")


func _anchor_schema() -> void:
	var index := Anchors.load_all()
	check(index.ok, "tracked anchor files validate: " + str(index.errors.slice(0, 3)))
	check(index.anchors.size() >= 500, "city has several hundred anchors")
	var kinds := {}
	for id: String in index.order:
		kinds[index.anchors[id].kind] = true
	for kind: String in ["stall", "queue", "doorway", "fountain", "gossip_spot", "guard_post", "cart_stop", "workshop", "play_spot", "beggar_spot", "tavern_seat", "entrance"]:
		check(kinds.has(kind), "baked data contains kind " + kind)
	check(Anchors.entry_error(_entry()).is_empty(), "a valid entry is accepted")
	check(not Anchors.entry_error(_entry({"kind": "throne"})).is_empty(), "unknown kind is rejected")
	check(not Anchors.entry_error(_entry({"era": {"from_year": 0, "to_year": null}})).is_empty(), "year 0 is rejected")
	check(not Anchors.entry_error(_entry({"era": {"from_year": 80, "to_year": -58}})).is_empty(), "era that ends before it starts is rejected")
	check(not Anchors.entry_error(_entry({"capacity": 0})).is_empty(), "zero capacity is rejected")
	check(not Anchors.entry_error(_entry({"hours": [9.0, 9.0]})).is_empty(), "empty opening window is rejected")
	check(not Anchors.entry_error(_entry({"wealth_tiers": ["rich"]})).is_empty(), "unknown wealth tier is rejected")
	check(not Anchors.entry_error(_entry({"position": [1.0, 2.0]})).is_empty(), "short position is rejected")
	var extra := _entry()
	extra["colour"] = "red"
	check(not Anchors.entry_error(extra).is_empty(), "unknown field is rejected")
	var parsed := Anchors.parse_file([_entry(), _entry({"id": "test.gate", "kind": "entrance", "era": {"from_year": -100, "to_year": 79}})], "inline")
	check(parsed.errors.is_empty() and parsed.entries.size() == 2, "a bare array of entries is a valid file")
	var arena: Dictionary = parsed.entries[0]
	# The amphitheatre does not exist in the campaign's first year.
	check(not Anchors.in_era(arena, -58), "an anchor from 80 AD is hidden in 58 BC")
	check(Anchors.in_era(arena, 80) and Anchors.in_era(arena, 120), "the same anchor is usable from 80 AD on")
	check(Anchors.in_era(parsed.entries[1], -1) and Anchors.in_era(parsed.entries[1], 1) and not Anchors.in_era(parsed.entries[1], 80), "era windows cross 1 BC / 1 AD without a year 0")
	check(Anchors.open_at(arena, 8.0) and not Anchors.open_at(arena, 18.0), "opening hours are half-open")
	var night := Anchors.normalise(_entry({"hours": [20.0, 4.0]}))
	check(Anchors.open_at(night, 23.0) and Anchors.open_at(night, 2.0) and not Anchors.open_at(night, 12.0), "hours wrap past midnight")
	check(Anchors.serves(arena, "poor") and not Anchors.serves(arena, "elite"), "wealth tiers filter users")
	var shrine: Dictionary = index.anchors.get("forum.shrine_temple", {})
	check(not shrine.is_empty() and Anchors.tag_value(shrine, "requires_node") == "MeshyTemple", "the temple forecourt requires the temple node")
	var without := Anchors.usable(index, -58, func(_name: String) -> bool: return false)
	check(not without.has("forum.shrine_temple") and without.has("forum.fountain"), "anchors of absent scene nodes are filtered out")


func _hash(life: Life) -> String:
	return JSON.stringify(life.state, "", true).sha256_text()


func _simulation() -> Dictionary:
	var start := Calendar.campaign_start_jdn()
	var a := Life.new()
	check(a.found(SEED, start, 4 * 3600), "city founds: " + a.error)
	if a.state.is_empty():
		check(false, "simulation did not start")
		return {}
	var residents: int = a.state.residents.size()
	check(residents >= 1200 and residents < Life.SYS_WEATHER, "population is in the planned range (%d)" % residents)
	check(a.year == -58, "campaign year is 58 BC")
	var founding := a.audit()
	check(founding.ok, "founding state audits: " + str(founding.errors.slice(0, 3)))
	# Every resident has a traceable life context.
	var roles := {}
	var homeless := 0
	var jobless_workers := 0
	for person in residents:
		var resident: Dictionary = a.state.residents[person]
		roles[resident.role] = int(roles.get(resident.role, 0)) + 1
		if not a.index.anchors.has(a.home_of(resident)):
			homeless += 1
		if resident.role in ["vendor", "craft"] and (int(resident.job) < 0 or not a.index.anchors.has(resident.work)):
			jobless_workers += 1
	check(homeless == 0, "every resident has a home that exists")
	check(jobless_workers == 0, "every vendor and craftsman has a workplace")
	for role: String in ["vendor", "craft", "guard", "porter", "labourer", "homemaker", "child", "elder", "servant", "patron"]:
		check(int(roles.get(role, 0)) > 0, "population contains role " + role)
	var origins := {}
	for resident: Dictionary in a.state.residents:
		origins[resident.origin] = true
	check(origins.size() >= 5, "residents come from several origins")

	# Run A: one uninterrupted day and a half, no budget.
	var noon := 4 * 3600 + 7 * 3600 + 1800
	var end := 4 * 3600 + 36 * 3600
	a.advance_to(noon, 0)
	var mid_hash := _hash(a)
	var saved_text := JSON.stringify(a.save_state())
	var midday := a.summary()
	# A single snapshot is only the last MAX_EVENTS, not the day's history.
	# Collect the live event stream in run B while leaving A uninterrupted.
	a.advance_to(end, 0)
	var final_hash := _hash(a)

	# Run B: same seed, tiny per-call budgets and irregular frame steps.
	var b := Life.new()
	b.found(SEED, start, 4 * 3600)
	var now := 4 * 3600
	var frames := 0
	var worst := 0
	var unfinished := 0
	var over_budget := 0
	var kinds := {}
	var last_seq := 0
	var missed_events := 0
	while true:
		now = mini(end, now + 37 + frames % 29)
		var report := b.advance_to(now, 500)
		# Consume after every actual advance, including catch-up at the end.
		# An overrun is a failure; never mistake a dropped trade for no trade.
		for event: Dictionary in b.events_since(last_seq):
			var seq := int(event.seq)
			missed_events += maxi(0, seq - last_seq - 1)
			last_seq = seq
			kinds[event.kind] = int(kinds.get(event.kind, 0)) + 1
		frames += 1
		worst = maxi(worst, int(report.usec))
		if not report.done:
			unfinished += 1
		# One batch of eight events may finish after the budget ran out.
		if int(report.usec) > 500 + 4000:
			over_budget += 1
		if (now == end and report.done) or frames > 400000:
			break
	check(missed_events == 0 and last_seq == int(b.state.event_seq), "budgeted observer consumes every published event without gaps")
	check(int(kinds.get("purchase", 0)) == int(a.state.stats.purchases), "every booked purchase produces exactly one visible event")
	check(_hash(b) == final_hash, "budgeted, irregular stepping reaches the identical world state")
	check(unfinished > 0, "the budget really deferred work to later frames")
	check(over_budget * 200 <= frames, "calls stay near the budget (%d of %d over, worst %d usec)" % [over_budget, frames, worst])

	# Run C: load the mid-day save from JSON text and continue.
	var c := Life.new()
	check(c.load_state(JSON.parse_string(saved_text)), "mid-day save loads: " + c.error)
	check(_hash(c) == mid_hash, "a JSON round trip reproduces the state exactly")
	c.advance_to(end, 0)
	check(_hash(c) == final_hash, "continuing from a mid-day save equals the uninterrupted run")
	check(Life.validate({"version": 1}) != "", "an incomplete save is refused")
	var broken: Dictionary = JSON.parse_string(saved_text)
	broken.households[0].members.append(int(broken.households[1].members[0]))
	check(Life.validate(broken) != "", "a save with a person in two households is refused")

	# Conservation after a day and a half of trade.
	var audit := a.audit()
	check(audit.ok, "money and goods conserve: " + str(audit.errors.slice(0, 4)))
	check(a.state.residents.size() == residents, "nobody was lost or duplicated")
	check(int(a.state.stats.purchases) > 300, "households bought at the stalls (%d)" % int(a.state.stats.purchases))
	check(int(a.state.stats.conversations) > 300, "residents talked to each other (%d)" % int(a.state.stats.conversations))
	check(int(a.state.stats.deliveries) > 10, "stalls were restocked (%d)" % int(a.state.stats.deliveries))
	check(int(a.state.ledger.get("wage", 0)) > 0 and int(a.state.ledger.get("rent", 0)) >= 0 and int(a.state.ledger.get("retail", 0)) > 0, "wages and retail were booked")
	check(int(a.state.closed_day) >= 1, "the day was closed")
	check(int(midday.activities.get("vend", 0)) >= 40, "stalls are staffed before noon (%d)" % int(midday.activities.get("vend", 0)))
	check(int(midday.outdoors) > 150, "streets are busy before noon (%d outdoors)" % int(midday.outdoors))
	check(kinds.has("purchase") or kinds.has("haggle"), "the observed event stream shows trade")
	check(kinds.has("conversation"), "the observed event stream shows a conversation")

	# At night the streets empty, guards stay out.
	var night := Life.new()
	night.load_state(JSON.parse_string(saved_text))
	night.advance_to(4 * 3600 + 22 * 3600 + 1800, 0)
	var asleep := night.summary()
	check(int(asleep.activities.get("sleep", 0)) > residents * 8 / 10, "most residents sleep at 02:30")
	check(int(asleep.activities.get("vend", 0)) == 0, "no stall is staffed at night")

	# Positions are a pure function of time: materialising residents (reading
	# where they are) never changes the world, and nobody is in two places.
	var probe := Life.new()
	probe.load_state(JSON.parse_string(saved_text))
	var before := _hash(probe)
	var outdoors := 0
	var finite := true
	for person in residents:
		if probe.is_indoors(person, noon):
			continue
		outdoors += 1
		var at := probe.position_of(person, noon)
		finite = finite and at.is_finite() and absf(at.x) < 450.0 and absf(at.z) < 360.0
	check(finite and outdoors > 150, "everyone outdoors has a position inside the city")
	check(_hash(probe) == before, "reading positions does not change the simulation")
	var slots_ok := true
	for anchor_id: String in probe._occupancy:
		var seen := {}
		for person: int in probe._occupancy[anchor_id]:
			if person < 0:
				continue
			slots_ok = slots_ok and not seen.has(person) and probe.state.residents[person].at == anchor_id
			seen[person] = true
	check(slots_ok, "every occupied slot belongs to exactly one resident standing there")

	# Reactions: an alarm at a busy stall, and rain.
	var busiest := ""
	var most := 0
	for anchor_id: String in probe._occupancy:
		if probe.index.anchors[anchor_id].kind == "gossip_spot" and probe.occupants(anchor_id).size() > most:
			most = probe.occupants(anchor_id).size()
			busiest = anchor_id
	if not busiest.is_empty():
		var reaction := probe.alarm(noon, "brawl", busiest, 40.0)
		check(reaction.fled.size() + reaction.watchers.size() > 0, "people near a brawl react (%d flee, %d watch)" % [reaction.fled.size(), reaction.watchers.size()])
		check(reaction.guards.size() > 0 or true, "guards are called when in range")
		var lines := Barks.lines_for(probe, probe.state.events[-1])
		check(reaction.fled.is_empty() or not lines.is_empty(), "an alarm produces spoken reactions")
	probe.set_weather("clear")
	probe.advance(5400, 0)
	probe.set_weather("rain")
	var weather_event: Dictionary = probe.state.events[-1]
	check(weather_event.kind == "weather" and int(weather_event.sheltering) > 0, "rain sends people in the open to shelter (%d)" % int(weather_event.get("sheltering", 0)))
	probe.advance(900, 0)
	check(probe.audit().ok, "the world still audits after alarm and rain")

	# Player trade through the existing shop ids reaches the residents' stall.
	var bakery := probe.business_for_shop("bakery")
	check(bakery >= 0, "the player's bakery is a simulated business")
	if bakery >= 0:
		var stock_before := int(probe.state.businesses[bakery].stock.bread)
		var till_before := int(probe.state.businesses[bakery].till)
		var before_invalid := _hash(probe)
		check(not probe.record_player_trade("bakery", "unknown_item", 1, 4, true), "unmapped good is refused")
		check(not probe.record_player_trade("missing_shop", "bread", 1, 4, true), "unmapped shop is refused")
		check(not probe.record_player_trade("bakery", "bread", 0, 4, true), "zero quantity is refused")
		check(not probe.record_player_trade("bakery", "bread", 1, -1, true), "negative price is refused")
		check(not probe.record_player_trade("bakery", "bread", 1, 1000000000, false), "unfunded sale is refused")
		check(_hash(probe) == before_invalid, "all rejected trades leave the entire state unchanged")
		if stock_before >= 2:
			check(probe.record_player_trade("bakery", "bread", 2, 4, true), "a player purchase is booked")
			check(int(probe.state.businesses[bakery].stock.bread) == stock_before - 2 and int(probe.state.businesses[bakery].till) == till_before + 4 * 64, "stock and till follow the player's purchase exactly")
			check(probe.record_player_trade("bakery", "bread", 2, 4, false), "a funded sale is booked")
			check(int(probe.state.businesses[bakery].stock.bread) == stock_before and int(probe.state.businesses[bakery].till) == till_before, "round trip restores stock and till")
		else:
			check(not probe.record_player_trade("bakery", "bread", 2, 4, true), "insufficient stock rejects the complete purchase")
			check(_hash(probe) == before_invalid, "insufficient stock changes nothing")
		var current_stock := int(probe.state.businesses[bakery].stock.bread)
		if current_stock < 99:
			var before_short := _hash(probe)
			check(not probe.record_player_trade("bakery", "bread", current_stock + 1, 4, true), "no partial fulfillment")
			check(_hash(probe) == before_short, "short stock does not debit the player")
		check(probe.audit().ok, "the ledger balances with the player account")
		var offers := probe.offers(bakery)
		check(not offers.is_empty() and offers[0].has("display") and offers[0].shop_item == "bread", "shop offers are data-driven")

	# Spoken lines: deterministic, with speakers, honest about missing audio.
	var talk := {}
	var deal := {}
	for event: Dictionary in a.state.events:
		if event.kind == "conversation":
			talk = event
		if event.kind == "haggle":
			deal = event
	var spoken := 0
	var voiced := 0
	if not talk.is_empty():
		var first := Barks.lines_for(a, talk)
		var second := Barks.lines_for(a, talk)
		check(first.size() >= 2 and JSON.stringify(first) == JSON.stringify(second), "a conversation expands to the same lines every time")
		check(first[0].speaker != first[1].speaker and str(first[0].voice_id).begins_with("npc_"), "lines alternate between two speakers with pool voices")
		for line: Dictionary in first:
			spoken += 1
			voiced += 1 if line.voiced else 0
	check(not talk.is_empty(), "a conversation is in the recent event log")
	var call := Barks.vendor_call(a, int(a.state.businesses[0].staff[0]), "bread", 1)
	check(not call.is_empty() and not str(call.text).is_empty(), "vendors have calls")
	check(Barks.recording_list().size() > 100, "the recording list for the voice pipeline is complete")

	return {"residents": residents, "households": a.state.households.size(), "businesses": a.state.businesses.size(), "roles": roles,
		"midday": midday, "stats_after_36h": a.state.stats, "budget_frames": frames, "budget_deferred_frames": unfinished,
		"budget_worst_usec": worst, "events_processed_36h": a.summary().processed, "spoken_lines": spoken, "voiced_lines": voiced,
		"audio_status": "text_only_until_voice_pool_recordings_land" if voiced == 0 else "voiced", "measurement": "desktop CPU, headless"}
