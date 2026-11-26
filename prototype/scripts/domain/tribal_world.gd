extends RefCounted
## Deterministic, aggregated simulation of independent groups (Germanic
## communities on the Rhine, a mounted band, a traders' market) and their
## relations to external actors (Valdora, the player, Rome).
##
## One tick is one calendar week. The world model derives the calendar day
## from its own clocks (village days, age jump, strategy seasons, reported
## travel/sleep days); this module never reads frames or wall-clock time.
## Every change of goods or people is a booked transaction with category,
## reason and counterparty. Stocks + equipment held by troops + cargo of war
## bands always equal opening balances plus booked inflows minus outflows.
## Feelings between actors live in the actor-generic relation core and change
## only through events with ids. Decisions are utility-based and seeded.

const Relations = preload("res://scripts/domain/actor_relations.gd")
const WorldCalendar = preload("res://scripts/domain/world_calendar.gd")
const VERSION := 2
const NO_SCENARIO := "none"
const SCENARIO_INDEX := {"bc58_rhine": "res://assets/world/tribes/bc58_rhine.json"}
## A roster is the default only inside its era window [first year, last year].
const SCENARIO_YEARS := {"bc58_rhine": [-60, -27]}
const TICK_DAYS := 7
const WEEKS := 52
const MAX_EVENTS := 240
const MAX_LEDGER := 320
const MAX_CATCHUP := 64
const MAX_EXPEDITIONS := 24
const MAX_AGREEMENTS := 96
const NEWS_AGE := 8
const OWN_RAID_COOLDOWN := 6
const MIN_RAID_WARRIORS := 12
const ACTION_THRESHOLD := 0.2
const EXTERNAL_AWAIT_TICKS := 2
const STALL_TICKS := 26
const INFLOW := ["produce", "transfer_in", "external_in"]
const OUTFLOW := ["consume", "destroy", "transfer_out", "external_out"]
const AGREEMENT_KINDS := ["truce", "alliance", "tribute", "trade_pact", "guest_friendship", "commission", "amicitia"]
const PEACE_KINDS := ["truce", "alliance", "trade_pact", "guest_friendship", "amicitia"]
const ACTIONS := ["build", "trade", "raid", "defend", "negotiate", "gift", "feast", "retreat", "idle"]
const GROUP_STATUS := ["active", "departed", "left_area", "dispersed"]
const SEASON_NAMES := ["Frühjahr", "Sommer", "Herbst", "Winter"]
const VULNERABILITY := {1: 1.3, 2: 1.0, 3: 0.7}
## Village goods reported by an external raid, converted to this ledger's goods.
const EXTERNAL_GOODS := {"grain": {"food": 10}, "denarii": {"wealth": 0.25}, "wood": {"wood": 1}}
const STATE_KEYS := ["version", "scenario", "seed", "rng", "tick", "extra_days", "next_id", "groups", "persons", "targets", "relations", "agreements", "expeditions", "events", "ledger", "flows", "opening", "intel", "anchors", "raid_windows", "story", "stats", "visits", "disputes"]
## D-048/D-049: the only recorded causes for a raid, feud, war or conquest.
## `need` (hunger, scarcity, strategic necessity) is recorded with its occasion.
const CONFLICT_CAUSES := ["quest_dispute", "natural_enemy", "alliance_call", "retaliation", "conquest", "need"]
const CONFLICT_EVENTS := ["war_band_departs", "raid", "raid_external"]
const MAX_DISPUTES := 128
const STAT_KEYS := ["raids", "plunders", "skirmishes", "repulsed", "trades", "agreements_made", "agreements_kept", "agreements_broken", "feasts", "gifts", "buildings", "settlements_founded", "leader_changes", "challenges", "starvation_deaths", "births", "external_raids"]

## Tests may capture every booking (unbounded) to replay the ledger.
static var capture_enabled := false
static var capture: Array = []
static var _scenarios := {}


# ---------------------------------------------------------------- scenario

static func scenario(id: String) -> Dictionary:
	if _scenarios.has(id):
		return _scenarios[id]
	if not SCENARIO_INDEX.has(id):
		return {}
	var text := FileAccess.get_file_as_string(SCENARIO_INDEX[id])
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	_scenarios[id] = parsed
	return parsed


static func scenario_for_year(year: int) -> String:
	var ids: Array = SCENARIO_YEARS.keys()
	ids.sort()
	for id: String in ids:
		var window: Array = SCENARIO_YEARS[id]
		if year >= int(window[0]) and year <= int(window[1]):
			return id
	return NO_SCENARIO


static func seed_from_text(text: String) -> int:
	return ("0x" + text.sha256_text().substr(0, 8)).hex_to_int() & 0x7FFFFFFF


static func _empty_state(seed: int, scenario_id: String) -> Dictionary:
	var stats := {}
	for key: String in STAT_KEYS:
		stats[key] = 0
	# Every seed maps to its own non-zero generator state (2 and 3 must differ).
	var mixed := seed_from_text("tribes:%d" % seed)
	return {"version": VERSION, "scenario": scenario_id, "seed": seed, "rng": mixed if mixed != 0 else 1,
		"tick": 0, "extra_days": 0, "next_id": 1, "groups": {}, "persons": {}, "targets": {},
		"relations": Relations.new_graph(), "agreements": [], "expeditions": [], "events": [],
		"ledger": [], "flows": {}, "opening": {}, "intel": {}, "anchors": {}, "raid_windows": {},
		"story": {}, "stats": stats, "visits": {}, "disputes": []}


static func new_state(seed: int, scenario_id: String = "bc58_rhine") -> Dictionary:
	var scn := scenario(scenario_id)
	if scn.is_empty():
		return _empty_state(seed, NO_SCENARIO)
	var state := _empty_state(seed, scenario_id)
	var goods: Array = scn.goods.keys()
	for gid: String in _sorted(scn.groups):
		var src: Dictionary = scn.groups[gid]
		var group := {"name": str(src.name), "people": str(src.people), "kind": str(src.kind), "culture": str(src.culture),
			"canon_kind": str(src.canon_kind), "source_note": str(src.source_note), "atlas_region": str(src.atlas_region),
			"status": "active", "leader": str(src.leader), "government": str(src.get("government", "assembly")), "war_leader": "", "war_until": -1,
			"families": (src.families as Dictionary).duplicate(true),
			"traits": {}, "goals": (src.goals as Array).duplicate(), "raid_range_km": float(src.raid_range_km),
			"settlements": [], "sites": [], "stock": {}, "held": {}, "troops": {}, "morale": float(src.morale),
			"project": {}, "acc": {}, "last_action": "idle", "last_action_tick": -1, "last_raid_tick": -100,
			"refuge_until": -1, "prepared_until": -1, "weariness": 0.0, "hunger_weeks": 0,
			"history": {"raids_won": 0, "raids_lost": 0, "raided": 0, "trades": 0, "feasts": 0, "gifts": 0, "built": 0, "founded": 0, "leaders": 1},
			"extra": {}}
		for trait_id: String in ["boldness", "caution", "pride", "trade", "faith"]:
			group.traits[trait_id] = _q(float(src.traits[trait_id]))
		for good: String in goods:
			group.stock[good] = int(src.stock.get(good, 0))
			group.held[good] = 0
		var index := 0
		for site: Dictionary in src.settlements:
			index += 1
			group.settlements.append(_new_settlement(scn, site, "s%d" % index, 0))
		for site: Dictionary in src.expansion_sites:
			group.sites.append({"name": str(site.name), "lat": float(site.lat), "lon": float(site.lon), "fields": int(site.fields), "ore": bool(site.ore), "food_bonus": float(site.food_bonus)})
		for type_id: String in _sorted(src.troops):
			var spec: Variant = src.troops[type_id]
			var count := int(spec.count) if typeof(spec) == TYPE_DICTIONARY else int(spec)
			var gear := {}
			if _mixed(scn, type_id):
				for good: String in _sorted((spec as Dictionary).get("gear", {}) if typeof(spec) == TYPE_DICTIONARY else {}):
					if int(spec.gear[good]) > 0:
						gear[good] = int(spec.gear[good])
			else:
				gear = _kit(scn, type_id, count)
			group.troops[type_id] = {"count": count, "xp": 0.0, "gear": gear}
			for good: String in gear:
				group.held[good] = int(group.held[good]) + int(gear[good])
		if src.has("seasonal_arrival"):
			group.extra = {"arrival": {}, "cap": {}}
			for good: String in src.seasonal_arrival:
				group.extra.arrival[good] = int(src.seasonal_arrival[good])
				group.extra.cap[good] = int(src.seasonal_cap[good])
		elif src.has("upkeep"):
			group.extra = {"wealth_per_week": float(src.upkeep.wealth_per_week)}
		state.groups[gid] = group
		state.flows[gid] = {}
		var opening := {"people": _population(group)}
		for good: String in goods:
			opening[good] = int(group.stock[good]) + int(group.held[good])
		state.opening[gid] = opening
		state.intel[gid] = {}
	for pid: String in _sorted(scn.persons):
		var p: Dictionary = scn.persons[pid]
		state.persons[pid] = {"name": str(p.name), "group": str(p.group), "family": str(p.family), "role": str(p.role),
			"born_tick": -roundi(float(p.age) * WEEKS), "traits": (p.traits as Dictionary).duplicate(), "prestige": float(p.prestige),
			"status": "alive", "canon_kind": "fictional_person", "since": 0, "with": "home", "deeds": 0, "fate": ""}
	# Every member of a leader's retinue is a person with identity and memory.
	for gid: String in _sorted(state.groups):
		var retinue := int(state.groups[gid].troops.get("gefolgsmann", {}).get("count", 0))
		for i in retinue:
			_new_retainer(state, scn, gid, "home", 0)
	for tid: String in _sorted(scn.targets):
		var src: Dictionary = scn.targets[tid]
		state.targets[tid] = {"name": str(src.name), "kind": str(src.kind), "canon_kind": str(src.canon_kind), "lat": float(src.lat), "lon": float(src.lon),
			"atlas_region": str(src.atlas_region), "raidable": bool(src.raidable), "defence": 0, "defender_strength": 2.0, "rebuilt": true, "story_lock_until": -1, "story_lock_reason": ""}
	_initial_relations(state, scn)
	for item: Dictionary in scn.get("natural_enemies", []):
		_open(state, str(item.a), str(item.b), "natural_enemy", "roster:" + str(item.get("source", "design")), str(item.note), -1, true)
	for item: Dictionary in scn.agreements:
		var terms := {}
		for good: String in item.terms:
			terms[good] = int(item.terms[good])
		var record := _make_agreement(state, str(item.kind), str(item.a), str(item.b), 0, int(item.duration), terms, int(item.every), str(item.canon_kind))
		if item.has("target"):
			record["target"] = str(item.target)
			record["story"] = str(item.story)
		if bool(item.get("hidden", false)):
			record["hidden"] = true
	state.stats.agreements_made = 0
	for story_id: String in _sorted(scn.story_raids):
		state.story[story_id] = {"status": "pending", "expedition": "", "result": ""}
	for gid: String in _sorted(state.groups):
		for other: String in _sorted(state.groups):
			if gid != other and Relations.knows(state.relations, gid, other):
				_observe(state, gid, other)
	return state


static func _new_settlement(scn: Dictionary, site: Dictionary, id: String, tick: int) -> Dictionary:
	var buildings := {}
	for b: String in _sorted(scn.buildings):
		buildings[b] = int((site.get("buildings", {}) as Dictionary).get(b, 0))
	return {"id": id, "name": str(site.name), "lat": float(site.lat), "lon": float(site.lon), "population": int(site.get("population", 0)),
		"fields": int(site.fields), "ore": bool(site.ore), "food_bonus": float(site.food_bonus), "buildings": buildings, "damage": 0.0, "founded": tick}


static func _initial_relations(state: Dictionary, scn: Dictionary) -> void:
	var graph: Dictionary = state.relations
	var ids := _sorted(state.groups)
	var radius := float(scn.contact_radius_km)
	for a: String in ids:
		for b: String in ids:
			if a != b and _distance_groups(state, a, b) <= radius:
				Relations.introduce(graph, a, b, "pre_scenario", 0, "neighbour")
	for gid: String in scn.rome_known_by:
		Relations.introduce(graph, gid, "rome", "pre_scenario", 0, "reports")
	for item: Dictionary in scn.relations:
		Relations.apply(graph, str(item.observer), str(item.subject), "pre_scenario", 0, "pre_scenario", item.values)
	for pid: String in _sorted(state.persons):
		var p: Dictionary = state.persons[pid]
		var chief := str(state.groups[p.group].leader)
		if p.role == "rival" and chief != "":
			Relations.apply(graph, pid, chief, "pre_scenario", 0, "family_rivalry", {"envy": 15.0, "respect": 10.0})
			Relations.apply(graph, chief, pid, "pre_scenario", 0, "family_rivalry", {"trust": 5.0, "respect": 10.0})
		elif p.role == "heir" and chief != "":
			Relations.apply(graph, pid, chief, "pre_scenario", 0, "kin", {"loyalty": 50.0, "trust": 40.0})
			Relations.apply(graph, chief, pid, "pre_scenario", 0, "kin", {"trust": 45.0})


# ---------------------------------------------------------------- calendar

static func year_of(state: Dictionary, tick: int = -1) -> int:
	var scn := scenario(str(state.scenario))
	if scn.is_empty():
		return 0
	var t: int = int(state.tick) if tick < 0 else tick
	var year := int(scn.era.start_year) + floori(float(t) / WEEKS)
	if int(scn.era.start_year) < 0 and year >= 0:
		year += 1 # There is no year zero between 1 BC and AD 1.
	return year


static func calendar(state: Dictionary) -> Dictionary:
	var t := int(state.tick)
	var week := t % WEEKS
	var year := year_of(state)
	return {"tick": t, "week": week + 1, "season": SEASON_NAMES[mini(3, floori(float(week) / 13.0))], "year": year,
		"label": "%s %s, Woche %d" % [SEASON_NAMES[mini(3, floori(float(week) / 13.0))], year_label(year), week + 1]}


static func year_label(year: int) -> String:
	if year == 0:
		return "—"
	return "%d v. Chr." % -year if year < 0 else "%d n. Chr." % year


static func day(state: Dictionary) -> int:
	return int(state.tick) * TICK_DAYS


## Chronicle and ledger keep their newest lines (balances live in `flows`).
## The week closes with it, and so does every write between two weeks (a
## played raid, a deed of the player), which would otherwise overflow a full
## ledger and make the whole world transaction invalid.
static func trim(state: Dictionary) -> void:
	while state.events.size() > MAX_EVENTS:
		state.events.pop_front()
	while state.ledger.size() > MAX_LEDGER:
		state.ledger.pop_front()


## Runs every full week between the consumed calendar and `target_day`, at most
## `max_ticks` per call so a long time jump cannot stall a frame. Returns ticks run.
static func advance_to_day(state: Dictionary, target_day: int, max_ticks: int = MAX_CATCHUP) -> int:
	var ran := 0
	while ran < max_ticks and (int(state.tick) + 1) * TICK_DAYS <= target_day:
		tick(state)
		ran += 1
	return ran


static func advance_ticks(state: Dictionary, ticks: int) -> void:
	for i in ticks:
		tick(state)


# ---------------------------------------------------------------- tick

static func tick(state: Dictionary) -> void:
	var runner := week_begin(state)
	while week_step(runner) > 0:
		pass


## A week in slices (see "sliced work"): anchors, war bands, the economy of
## one group per slice, agreements, leadership, news, the decision cache, one
## community's decision per slice, relation decay in edge slices, closing.
## The order of slices is the order of the monolithic week.
static func week_begin(state: Dictionary) -> Dictionary:
	var t := int(state.tick) + 1
	state.tick = t
	var scn := scenario(str(state.scenario))
	return {"kind": "week", "state": state, "t": t, "week": (t - 1) % WEEKS, "stage": 0, "index": 0, "items": [], "cache": {}, "done": scn.is_empty(), "entered": false}


static func week_step(runner: Dictionary) -> int:
	if bool(runner.done):
		return 0
	var state: Dictionary = runner.state
	var scn := scenario(str(state.scenario))
	var t := int(runner.t)
	var week := int(runner.week)
	var cost := next_units(runner)
	var stage: String = WEEK_STAGES[int(runner.stage)]
	var finished := true
	match stage:
		"anchors":
			_anchors(state, scn, t)
		"expeditions":
			_expeditions(state, scn, t)
		"economy":
			if not bool(runner.entered):
				runner.items = _sorted(state.groups)
				runner.index = 0
				runner.entered = true
			# One active group per slice; inactive groups cost nothing.
			while int(runner.index) < runner.items.size():
				var gid: String = runner.items[int(runner.index)]
				runner.index = int(runner.index) + 1
				var g: Dictionary = state.groups[gid]
				if g.status != "active":
					continue
				match str(g.kind):
					"tribe":
						_economy(state, scn, gid, t, week)
					"band":
						_band_economy(state, gid, t)
					"market":
						_market_economy(state, gid, week)
				break
			finished = int(runner.index) >= runner.items.size()
		"agreements":
			_agreements_tick(state, scn, t)
		"leadership":
			_leadership(state, scn, t)
		"news":
			_news(state, scn, t)
		"decision_cache":
			var tribes := _active_tribes(state)
			runner.items = []
			if not tribes.is_empty():
				# Decisions of one week read the situation at the start of the week.
				runner.cache = _decision_cache(state, t)
				var offset := t % tribes.size()
				for i in tribes.size():
					runner.items.append(tribes[(i + offset) % tribes.size()])
			runner.index = 0
		"decide":
			if int(runner.index) < runner.items.size():
				_decide(state, scn, runner.items[int(runner.index)], t, week, runner.cache)
				runner.index = int(runner.index) + 1
			finished = int(runner.index) >= runner.items.size()
		"decay":
			if int(runner.index) == 0:
				runner.items = state.relations.edges.keys()
			var stop := mini(runner.items.size(), int(runner.index) + EDGE_SLICE * 2)
			Relations.decay_keys(state.relations, runner.items.slice(int(runner.index), stop), 1)
			runner.index = stop
			finished = stop >= runner.items.size()
		"close":
			for gid: String in _sorted(state.groups):
				var g: Dictionary = state.groups[gid]
				g.weariness = _q(maxf(0.0, float(g.weariness) * 0.96))
			trim(state)
	if finished:
		runner.stage = int(runner.stage) + 1
		runner.index = 0
		runner.entered = false
		# A stage without work (no decisions this week) still ends cleanly.
		while int(runner.stage) < WEEK_STAGES.size() and WEEK_STAGES[int(runner.stage)] == "decide" and runner.items.is_empty():
			runner.stage = int(runner.stage) + 1
		if int(runner.stage) >= WEEK_STAGES.size():
			runner.done = true
	return cost


# ---------------------------------------------------------------- ledger

static func _next(state: Dictionary, prefix: String) -> String:
	var id := "%s%d" % [prefix, int(state.next_id)]
	state.next_id = int(state.next_id) + 1
	return id


## The single booking primitive. Positive categories add, negative remove.
## "move" relocates goods between an actor's own accounts and is not a flow.
static func _book(state: Dictionary, tx: String, actor: String, good: String, quantity: int, category: String, reason: String, counterparty: String, account: String = "stock", expedition: Dictionary = {}) -> void:
	if quantity == 0:
		return
	var g: Dictionary = state.groups[actor]
	var signed := quantity if category in INFLOW else -quantity
	if category == "move":
		signed = quantity
	match account:
		"stock":
			g.stock[good] = int(g.stock[good]) + signed
		"held":
			g.held[good] = int(g.held[good]) + signed
		"cargo":
			expedition.cargo[good] = int(expedition.cargo.get(good, 0)) + signed
	if category != "move":
		var flows: Dictionary = state.flows[actor]
		if not flows.has(good):
			flows[good] = {}
		flows[good][category] = int(flows[good].get(category, 0)) + absi(quantity)
	var line := {"tx": tx, "tick": int(state.tick), "actor": actor, "good": good, "qty": signed, "account": account, "category": category, "reason": reason, "counter": counterparty}
	state.ledger.append(line)
	if capture_enabled:
		capture.append(line.duplicate())


static func _tx(state: Dictionary, actor: String, good: String, quantity: int, category: String, reason: String, counterparty: String = "") -> void:
	if quantity <= 0:
		return
	_book(state, _next(state, "t"), actor, good, quantity, category, reason, counterparty)


static func _transfer(state: Dictionary, from: String, to: String, good: String, quantity: int, reason: String, from_account: String = "stock", to_account: String = "stock", from_exp: Dictionary = {}, to_exp: Dictionary = {}) -> int:
	if quantity <= 0:
		return 0
	var tx := _next(state, "t")
	_book(state, tx, from, good, quantity, "transfer_out", reason, to, from_account, from_exp)
	_book(state, tx, to, good, quantity, "transfer_in", reason, from, to_account, to_exp)
	return quantity


static func _move(state: Dictionary, actor: String, good: String, quantity: int, from_account: String, to_account: String, reason: String, expedition: Dictionary = {}) -> void:
	if quantity <= 0:
		return
	var tx := _next(state, "t")
	_book(state, tx, actor, good, -quantity, "move", reason, actor, from_account, expedition)
	_book(state, tx, actor, good, quantity, "move", reason, actor, to_account, expedition)


static func _people(state: Dictionary, gid: String, settlement: int, quantity: int, category: String, reason: String, counterparty: String = "", tx: String = "") -> void:
	if quantity <= 0:
		return
	var g: Dictionary = state.groups[gid]
	var s: Dictionary = g.settlements[settlement]
	var signed := quantity if category in INFLOW else -quantity
	s.population = int(s.population) + signed
	var flows: Dictionary = state.flows[gid]
	if not flows.has("people"):
		flows["people"] = {}
	flows.people[category] = int(flows.people.get(category, 0)) + quantity
	var line := {"tx": tx if tx != "" else _next(state, "t"), "tick": int(state.tick), "actor": gid, "good": "people", "qty": signed, "account": s.id, "category": category, "reason": reason, "counter": counterparty}
	state.ledger.append(line)
	if capture_enabled:
		capture.append(line.duplicate())


static func _accrue(g: Dictionary, key: String, amount: float) -> int:
	var value := float(g.acc.get(key, 0.0)) + maxf(0.0, amount)
	var whole := floori(value)
	g.acc[key] = _q6(value - whole)
	return whole


# ---------------------------------------------------------------- queries

static func _sorted(d: Dictionary) -> Array:
	var keys: Array = d.keys()
	keys.sort()
	return keys


static func _active_tribes(state: Dictionary) -> Array:
	var result := []
	for gid: String in _sorted(state.groups):
		var g: Dictionary = state.groups[gid]
		if g.kind == "tribe" and g.status == "active" and _population(g) > 0:
			result.append(gid)
	return result


static func _population(g: Dictionary) -> int:
	var total := 0
	for s: Dictionary in g.settlements:
		total += int(s.population)
	return total


static func _warriors_home(g: Dictionary) -> int:
	var total := 0
	for type_id: String in g.troops:
		total += int(g.troops[type_id].count)
	return total


static func _warriors_away(state: Dictionary, gid: String) -> int:
	var total := 0
	for e: Dictionary in state.expeditions:
		if e.group == gid:
			for type_id: String in e.troops:
				total += int(e.troops[type_id].count)
	return total


static func _expedition_of(state: Dictionary, gid: String) -> Dictionary:
	for e: Dictionary in state.expeditions:
		if e.group == gid:
			return e
	return {}


static func _building_count(g: Dictionary, building: String) -> int:
	var total := 0
	for s: Dictionary in g.settlements:
		total += int(s.buildings.get(building, 0))
	return total


static func _avg_damage(g: Dictionary) -> float:
	if g.settlements.is_empty():
		return 0.0
	var total := 0.0
	for s: Dictionary in g.settlements:
		total += float(s.damage)
	return total / g.settlements.size()


static func _housing(scn: Dictionary, g: Dictionary) -> int:
	var total := 0.0
	for s: Dictionary in g.settlements:
		total += int(s.buildings.get("longhouse", 0)) * float(scn.buildings.longhouse.housing) * (1.0 - float(s.damage) / 200.0)
	return floori(total)


static func _storage(scn: Dictionary, g: Dictionary) -> int:
	var total := 0
	for s: Dictionary in g.settlements:
		total += int(scn.economy.base_storage) + int(s.buildings.get("granary", 0)) * int(scn.buildings.granary.storage)
	return total


static func _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	var p1 := deg_to_rad(lat1)
	var p2 := deg_to_rad(lat2)
	var dp := p2 - p1
	var dl := deg_to_rad(lon2 - lon1)
	var a := sin(dp / 2.0) * sin(dp / 2.0) + cos(p1) * cos(p2) * sin(dl / 2.0) * sin(dl / 2.0)
	return 6371.0 * 2.0 * atan2(sqrt(a), sqrt(1.0 - a))


static func _position(state: Dictionary, actor: String) -> Vector2:
	if state.groups.has(actor):
		var s: Dictionary = state.groups[actor].settlements[0]
		return Vector2(float(s.lat), float(s.lon))
	if state.targets.has(actor):
		return Vector2(float(state.targets[actor].lat), float(state.targets[actor].lon))
	return Vector2.ZERO


static var _distance_cache := {}


static func _distance_groups(state: Dictionary, a: String, b: String) -> float:
	var pa := _position(state, a)
	var pb := _position(state, b)
	var key := Vector4(pa.x, pa.y, pb.x, pb.y)
	if _distance_cache.has(key):
		return _distance_cache[key]
	var km := _haversine(pa.x, pa.y, pb.x, pb.y)
	if _distance_cache.size() > 4096:
		_distance_cache.clear()
	_distance_cache[key] = km
	return km


static func travel_ticks(km: float) -> int:
	return maxi(1, ceili(km / 120.0))


## Persisted fractions are rounded to decimals that survive Godot's JSON
## save/load exactly, so a reloaded world continues bit-identically.
static func _q(x: float) -> float:
	return roundf(x * 10000.0) / 10000.0


static func _q2(x: float) -> float:
	return roundf(x * 100.0) / 100.0


static func _q6(x: float) -> float:
	return roundf(x * 1000000.0) / 1000000.0


static func _rand(state: Dictionary) -> float:
	var x := int(state.rng) & 0xFFFFFFFF
	x ^= (x << 13) & 0xFFFFFFFF
	x ^= x >> 17
	x ^= (x << 5) & 0xFFFFFFFF
	x &= 0xFFFFFFFF
	if x == 0:
		x = 0x2545F491
	state.rng = x
	return float(x) / 4294967296.0


static func traits(state: Dictionary, gid: String) -> Dictionary:
	## Group culture blended with the person who leads: the chief, or during a
	## campaign the elected war leader. The form of government sets the weight.
	var g: Dictionary = state.groups[gid]
	var result := {}
	var gov := government(state, gid)
	var leader: Dictionary = state.persons.get(str(g.leader), {})
	var weight := float(gov.get("blend", 0.4))
	if str(g.war_leader) != "" and state.persons.has(str(g.war_leader)):
		leader = state.persons[str(g.war_leader)]
		weight = float(gov.get("war_blend", weight))
	for trait_id: String in g.traits:
		var base := float(g.traits[trait_id])
		if not leader.is_empty() and leader.traits.has(trait_id):
			base = (1.0 - weight) * base + weight * float(leader.traits[trait_id])
		result[trait_id] = clampf(base, 0.0, 1.0)
	result["ambition"] = float(leader.traits.get("ambition", 0.4)) if not leader.is_empty() else 0.4
	return result


static func government(state: Dictionary, gid: String) -> Dictionary:
	var scn := scenario(str(state.scenario))
	var model := str(state.groups[gid].get("government", "assembly"))
	return scn.get("governments", {}).get(model, {"blend": 0.4, "challenge": 18, "heir_bonus": 10})


static func _drift(g: Dictionary, trait_id: String, amount: float) -> void:
	g.traits[trait_id] = _q(clampf(float(g.traits[trait_id]) + amount, 0.05, 0.95))


static func _equipment(scn: Dictionary, type_id: String) -> Dictionary:
	return scn.troop_types[type_id].equipment


static func troops_strength(scn: Dictionary, troops: Dictionary) -> float:
	var total := 0.0
	for type_id: String in _sorted(troops):
		var stack: Dictionary = troops[type_id]
		var spec: Dictionary = scn.troop_types[type_id]
		var base := int(stack.count) * float(spec.strength)
		if _mixed(scn, type_id):
			var armed := _gear_total(stack.gear)
			base = armed * float(spec.strength) + (int(stack.count) - armed) * float(spec.unarmed_strength)
		total += base * (1.0 + minf(0.5, float(stack.xp) / 40.0))
	return total


static func _morale_factor(morale: float) -> float:
	return 0.6 + clampf(morale, 0.0, 100.0) / 125.0


static func strength(state: Dictionary, gid: String) -> float:
	var scn := scenario(str(state.scenario))
	var g: Dictionary = state.groups[gid]
	return troops_strength(scn, g.troops) * _morale_factor(float(g.morale))


static func _fort(g: Dictionary, s: Dictionary) -> float:
	return 1.0 + 0.35 * int(s.buildings.get("palisade", 0)) * (1.0 - float(s.damage) / 100.0)


static func defence(state: Dictionary, gid: String, warned: bool = false) -> float:
	## Defenders are farmers spread over the farmsteads: how many gather before
	## the attackers arrive depends on warning. Prepared communities stand ready.
	var scn := scenario(str(state.scenario))
	var g: Dictionary = state.groups[gid]
	if g.settlements.is_empty():
		return 0.0
	var s: Dictionary = g.settlements[0]
	var civilians := maxi(0, roundi(_population(g) * float(scn.economy.adult_share)) - _warriors_home(g) - _warriors_away(state, gid))
	var muster := 0.5
	if int(g.prepared_until) >= int(state.tick):
		muster = 1.0
	elif warned or int(s.buildings.get("watchpost", 0)) > 0:
		muster = 0.8
	return (strength(state, gid) * _fort(g, s) + civilians * 0.25) * muster * (1.0 - float(s.damage) / 300.0)


static func settlement_class(population: int) -> String:
	if population < 150:
		return "Weiler"
	if population < 400:
		return "Dorf"
	return "Großsiedlung"


## What an attacker must expect: a community with a watch post will be warned
## and stand ready, one without it is caught on its farmsteads.
static func expected_defence(state: Dictionary, gid: String) -> float:
	var g: Dictionary = state.groups[gid]
	if g.settlements.is_empty():
		return 0.0
	var ready := int(g.settlements[0].buildings.get("watchpost", 0)) > 0
	return defence(state, gid) / (0.8 if ready else 0.5) * (1.0 if ready else 0.5) if int(g.prepared_until) < int(state.tick) else defence(state, gid)


static func strength_class(value: float) -> String:
	if value < 60.0:
		return "schwach"
	if value < 150.0:
		return "mittel"
	if value < 300.0:
		return "stark"
	return "sehr stark"


static func _active_agreement(state: Dictionary, a: String, b: String, kinds: Array) -> Dictionary:
	for item: Dictionary in state.agreements:
		if item.status == "active" and str(item.kind) in kinds and ((item.a == a and item.b == b) or (item.a == b and item.b == a)):
			return item
	return {}


static func _rel(state: Dictionary, a: String, b: String, dimension: String) -> float:
	return Relations.value(state.relations, a, b, dimension)


static func _affect(state: Dictionary, observer: String, subject: String, event_id: String, kind: String, deltas: Dictionary) -> void:
	Relations.apply(state.relations, observer, subject, event_id, int(state.tick), kind, deltas)
	# The group's chief shares the group's experience with the other side.
	if state.groups.has(observer):
		var chief := str(state.groups[observer].leader)
		if state.persons.has(chief) and state.persons[chief].status == "alive":
			Relations.apply(state.relations, chief, subject, event_id, int(state.tick), kind, deltas)


static func _event(state: Dictionary, kind: String, actors: Array, text: String, cause: String, known_by: Array, spread: bool = false, canon: String = "simulation", conflict: Dictionary = {}) -> String:
	var id := _next(state, "e")
	var knowers := []
	for actor: String in known_by:
		if actor not in knowers:
			knowers.append(actor)
	knowers.sort()
	var record := {"id": id, "tick": int(state.tick), "kind": kind, "actors": actors.duplicate(), "text": text, "cause": cause, "known_by": knowers, "spread": spread, "canon": canon}
	if not conflict.is_empty():
		record["conflict"] = {"cause": str(conflict.cause), "dispute": str(conflict.dispute), "source": str(conflict.source)}
	state.events.append(record)
	return id


# ---------------------------------------------------------------- disputes
# D-048: conflicts start only from a recorded dispute. A dispute allows its
# holder `a` to strike `b` (both ways when `mutual`) until `until` (-1: lasting).

static func _open(state: Dictionary, a: String, b: String, cause: String, source: String, note: String, weeks: int, mutual: bool = false) -> Dictionary:
	if not (cause in CONFLICT_CAUSES) or a == b:
		return {}
	var t := int(state.tick)
	for item: Dictionary in state.disputes:
		if item.status == "open" and item.cause == cause and item.a == a and item.b == b:
			item.until = -1 if weeks < 0 or int(item.until) < 0 else maxi(int(item.until), t + weeks)
			return item
	var record := {"id": _next(state, "d"), "a": a, "b": b, "cause": cause, "source": source, "note": note, "since": t, "until": -1 if weeks < 0 else t + weeks, "mutual": mutual, "status": "open"}
	state.disputes.append(record)
	while state.disputes.size() > MAX_DISPUTES:
		var dropped := false
		for i in state.disputes.size():
			if state.disputes[i].status != "open":
				state.disputes.remove_at(i)
				dropped = true
				break
		if not dropped:
			break
	return record


## The story or quest layer records a dispute that a mission created.
static func open_dispute(state: Dictionary, a: String, b: String, cause: String, source: String, note: String = "", weeks: int = 52) -> Dictionary:
	var ids := actor_ids(state)
	if not ids.has(a) or not ids.has(b) or not (cause in CONFLICT_CAUSES) or source.is_empty():
		return {}
	return _open(state, a, b, cause, source, note, weeks)


static func close_dispute(state: Dictionary, id: String, reason: String) -> bool:
	for item: Dictionary in state.disputes:
		if item.id == id and item.status == "open":
			item.status = "closed"
			item.note = str(item.note) + " · beendet: " + reason
			_next(state, "r")
			return true
	return false


## D-049: hunger, scarcity or strategic necessity as a cause, with the facts
## that made it one. Empty when the community is not in real need.
static func _need_occasion(state: Dictionary, gid: String, target: String, ctx: Dictionary) -> Dictionary:
	var g: Dictionary = state.groups[gid]
	if g.kind != "tribe":
		return {}
	var missing := []
	var level := 0.0
	if float(ctx.hunger) >= 0.5:
		missing.append("Nahrung")
		level = maxf(level, float(ctx.hunger))
	if float(ctx.land_pressure) >= 0.6 and g.sites.is_empty():
		missing.append("Land und Vieh")
		level = maxf(level, float(ctx.land_pressure) * 0.8)
	if not g.project.is_empty() and int(state.tick) - int(g.project.progress_tick) >= 8:
		for good: String in _sorted(g.project.cost_left):
			if int(g.project.cost_left[good]) > int(g.stock[good]):
				missing.append(str(good))
				level = maxf(level, 0.5)
	if missing.is_empty():
		return {}
	var tr: Dictionary = ctx.traits
	var occasion := "Hunger %.2f (%.1f Wochen Vorrat); fehlt: %s; Anführer kühn %.2f, vorsichtig %.2f; Vertrauen zu %s %.0f" % [float(ctx.hunger), float(ctx.food_weeks), ", ".join(missing), float(tr.boldness), float(tr.caution), _name(state, target), _rel(state, gid, target, "trust")]
	return {"level": clampf(level, 0.0, 1.0), "missing": missing, "occasion": occasion}


static func _natural_enemies(state: Dictionary, a: String, b: String) -> bool:
	for item: Dictionary in state.disputes:
		if item.status == "open" and item.cause == "natural_enemy" and ((item.a == a and item.b == b) or (item.a == b and item.b == a)):
			return true
	return false


## The open dispute that lets `attacker` strike `target`, strongest cause first.
static func dispute_for(state: Dictionary, attacker: String, target: String) -> Dictionary:
	var t := int(state.tick)
	var best := {}
	for item: Dictionary in state.disputes:
		if item.status != "open" or (int(item.until) >= 0 and int(item.until) < t):
			continue
		var matches: bool = (item.a == attacker and item.b == target) or (bool(item.mutual) and item.a == target and item.b == attacker)
		if matches and (best.is_empty() or CONFLICT_CAUSES.find(str(item.cause)) < CONFLICT_CAUSES.find(str(best.cause))):
			best = item
	return best


static func _expire_disputes(state: Dictionary, t: int) -> void:
	for item: Dictionary in state.disputes:
		if item.status == "open" and int(item.until) >= 0 and int(item.until) < t:
			item.status = "expired"


## After a peace kept to its end, the feud between the partners is over;
## a natural enmity remains.
static func _settle_disputes(state: Dictionary, a: String, b: String, reason: String) -> void:
	for item: Dictionary in state.disputes:
		if item.status == "open" and item.cause != "natural_enemy" and ((item.a == a and item.b == b) or (item.a == b and item.b == a)):
			item.status = "closed"
			item.note = str(item.note) + " · beendet: " + reason


static func _observe(state: Dictionary, observer: String, subject: String) -> void:
	if not state.groups.has(observer) or not state.groups.has(subject):
		return
	var h: Dictionary = state.groups[subject]
	state.intel[observer][subject] = {"tick": int(state.tick), "strength": _q2(strength(state, subject)), "defence": _q2(expected_defence(state, subject)),
		"food": int(h.stock.food), "cattle": int(h.stock.cattle), "wealth": int(h.stock.wealth), "warriors": _warriors_home(h)}


# ---------------------------------------------------------------- economy

static func _phase(eco: Dictionary, week: int) -> Array:
	for row: Array in eco.season_productivity:
		if week >= int(row[0]) and week <= int(row[1]):
			return [float(row[2]), float(row[3])]
	return [0.0, 0.0]


static func _most_populous(g: Dictionary) -> int:
	var best := 0
	for i in g.settlements.size():
		if int(g.settlements[i].population) > int(g.settlements[best].population):
			best = i
	return best


static func _economy(state: Dictionary, scn: Dictionary, gid: String, t: int, week: int) -> void:
	var g: Dictionary = state.groups[gid]
	var eco: Dictionary = scn.economy
	var pop := _population(g)
	if pop <= 0:
		return
	var away := _warriors_away(state, gid)
	var home_w := _warriors_home(g)
	var adults := roundi(pop * float(eco.adult_share))
	var civilians := maxi(0, adults - home_w - away)
	var labour := float(civilians) + float(home_w) * float(eco.warrior_labour)
	if int(g.refuge_until) >= t:
		labour *= 0.5
	labour *= 1.0 - _avg_damage(g) / 300.0
	# Fields: labour share and yield follow the season.
	var phase := _phase(eco, week)
	var fields := 0.0
	var weighted := 0.0
	for s: Dictionary in g.settlements:
		fields += float(s.fields)
		weighted += float(s.fields) * (1.0 + float(s.food_bonus))
	var farm := minf(labour, fields * float(phase[1]))
	labour -= farm
	var food_made := farm * float(phase[0]) * (weighted / maxf(1.0, fields))
	if week >= int(eco.dairy_weeks[0]) and week <= int(eco.dairy_weeks[1]):
		food_made += int(g.stock.cattle) * float(eco.dairy_per_cattle)
	_tx(state, gid, "food", _accrue(g, "food", food_made), "produce", "harvest_and_dairy")
	# Herds: calving in spring, slaughter of the surplus in late autumn.
	if week >= int(eco.calving_weeks[0]) and week <= int(eco.calving_weeks[1]):
		_tx(state, gid, "cattle", _accrue(g, "calves", int(g.stock.cattle) * float(eco.calving_rate_per_week)), "produce", "calving")
	var horses := int(g.stock.horse) + int(g.held.horse)
	if week >= int(eco.calving_weeks[0]) and week <= int(eco.calving_weeks[1]) and horses < pop * 0.25:
		_tx(state, gid, "horse", _accrue(g, "foals", horses * 0.03), "produce", "foaling")
	if week >= int(eco.slaughter_weeks[0]) and week <= int(eco.slaughter_weeks[1]):
		var target := roundi(pop * float(eco.herd_per_person))
		var surplus := int(g.stock.cattle) - target
		if surplus > 0:
			var slaughtered := maxi(1, ceili(surplus / 4.0))
			_tx(state, gid, "cattle", slaughtered, "consume", "autumn_slaughter")
			_tx(state, gid, "food", slaughtered * int(eco.slaughter_food), "produce", "autumn_slaughter")
	labour = _construction(state, scn, gid, labour, t)
	labour = _crafting(state, scn, gid, labour)
	# Extraction keeps bounded working stocks; leftover labour is rest and trade.
	var smithies := _building_count(g, "smithy")
	var has_ore := false
	for s: Dictionary in g.settlements:
		has_ore = has_ore or bool(s.ore)
	if has_ore and smithies > 0 and int(g.stock.ore) < 40:
		var ore_labour := minf(labour * 0.3, (40 - int(g.stock.ore)) / float(eco.ore_per_labour))
		labour -= ore_labour
		_tx(state, gid, "ore", _accrue(g, "ore", ore_labour * float(eco.ore_per_labour)), "produce", "bog_iron")
	var wood_target := 160 + int(g.project.get("cost_left", {}).get("wood", 0))
	if int(g.stock.wood) < wood_target:
		var wood_labour := minf(labour * 0.6, (wood_target - int(g.stock.wood)) / float(eco.wood_per_labour))
		labour -= wood_labour
		_tx(state, gid, "wood", _accrue(g, "wood", wood_labour * float(eco.wood_per_labour)), "produce", "woodcutting")
	# Rations: people at home plus the retinue's extra share at the hall table.
	var retinue := int(g.troops.get("gefolgsmann", {}).get("count", 0))
	var need := pop - away + retinue
	if int(g.stock.food) < need and int(g.stock.cattle) > 0:
		var emergency := mini(maxi(1, floori(int(g.stock.cattle) * 0.1)), ceili((need - int(g.stock.food)) / float(eco.slaughter_food)))
		_tx(state, gid, "cattle", emergency, "consume", "emergency_slaughter")
		_tx(state, gid, "food", emergency * int(eco.slaughter_food), "produce", "emergency_slaughter")
	var eaten := mini(int(g.stock.food), need)
	_tx(state, gid, "food", eaten, "consume", "rations")
	var shortfall := need - eaten
	g.hunger_weeks = int(g.hunger_weeks) + 1 if shortfall > 0 else 0
	var capacity := _storage(scn, g)
	var spoil := _accrue(g, "spoil", int(g.stock.food) * float(eco.spoilage_per_week) * (0.6 if _building_count(g, "granary") > 0 else 1.0))
	spoil += roundi(maxi(0, int(g.stock.food) - spoil - capacity) * float(eco.overflow_spoilage))
	_tx(state, gid, "food", mini(spoil, int(g.stock.food)), "destroy", "spoilage")
	# People: births, deaths, starvation, emigration beyond the housing.
	var housing := _housing(scn, g)
	var food_weeks := float(g.stock.food) / maxf(1.0, need)
	var birth_factor := (1.0 if shortfall == 0 and food_weeks > 4.0 else 0.3) * (1.0 if pop < housing else 0.25)
	var births := _accrue(g, "births", pop * float(eco.births_per_week) * birth_factor)
	if births > 0:
		var room := 0
		for i in g.settlements.size():
			if int(g.settlements[i].population) - int(g.settlements[room].population) < 0 and g.settlements[i].population > 0:
				room = i
		_people(state, gid, room, births, "produce", "births")
		state.stats.births = int(state.stats.births) + births
	var natural := _accrue(g, "deaths", pop * float(eco.deaths_per_week))
	var starved := _accrue(g, "starve", shortfall * float(eco.starvation_deaths))
	var emigrants := _accrue(g, "emigration", maxi(0, pop - housing) * float(eco.emigration_per_week))
	var crowded := _most_populous(g)
	_people(state, gid, crowded, mini(natural, int(g.settlements[crowded].population)), "destroy", "natural_death")
	_people(state, gid, crowded, mini(starved, int(g.settlements[crowded].population)), "destroy", "starvation")
	state.stats.starvation_deaths = int(state.stats.starvation_deaths) + starved
	_people(state, gid, crowded, mini(emigrants, int(g.settlements[crowded].population)), "external_out", "emigration", "beyond_area")
	_bound_warriors(state, scn, gid)
	_recruit_and_upgrade(state, scn, gid, t)
	# Retinue: the leader's gifts are real goods.
	# Gifts to the retinue are silver and ornaments, or cattle when silver runs out.
	var gifts_due := _accrue(g, "retinue", int(g.troops.get("gefolgsmann", {}).get("count", 0)) * float(eco.retinue_wealth_per_week))
	var paid := mini(gifts_due, int(g.stock.wealth))
	_tx(state, gid, "wealth", paid, "consume", "retinue_gifts")
	var cattle_gifts := mini(gifts_due - paid, int(g.stock.cattle))
	_tx(state, gid, "cattle", cattle_gifts, "consume", "retinue_gifts")
	paid += cattle_gifts
	var morale_target := 50.0 + 12.0 * (_chief_prestige(state, gid) - 40.0) / 40.0 - 30.0 * clampf(float(shortfall) / maxf(1.0, need), 0.0, 1.0) - (8.0 if pop > housing else 0.0) - 10.0 * _avg_damage(g) / 100.0
	if paid < gifts_due:
		morale_target -= 10.0
		var leaving := mini(int(g.troops.gefolgsmann.count), maxi(1, roundi(int(g.troops.gefolgsmann.count) * 0.1)))
		_desert(state, scn, gid, "gefolgsmann", leaving, "unpaid_retinue")
	g.morale = _q(clampf(float(g.morale) + (morale_target - float(g.morale)) * 0.1, 0.0, 100.0))
	for type_id: String in _sorted(g.troops):
		g.troops[type_id].xp = _q(minf(40.0, float(g.troops[type_id].xp) + 0.1))
	if not g.project.is_empty() and t - int(g.project.progress_tick) > STALL_TICKS:
		_event(state, "project_abandoned", [gid], "%s gibt das Vorhaben %s auf; Material und Arbeit fehlen seit Monaten." % [g.name, g.project.name], "stalled", [gid])
		g.project = {}


static func _bound_warriors(state: Dictionary, scn: Dictionary, gid: String) -> void:
	## Deaths can reduce a community below its warrior count; no phantom warriors.
	var g: Dictionary = state.groups[gid]
	var excess := _warriors_home(g) + _warriors_away(state, gid) - roundi(_population(g) * 0.6)
	for type_id: String in ["aufgebot", "plaenkler", "speerkrieger", "axtkrieger", "schwertkaempfer", "reiter", "gefolgsmann", "band_rider"]:
		if excess <= 0:
			return
		if not g.troops.has(type_id):
			continue
		var n := mini(excess, int(g.troops[type_id].count))
		_dismiss(state, scn, gid, type_id, n, "too_few_people")
		excess -= n


static func _mixed(scn: Dictionary, type_id: String) -> bool:
	return str(scn.troop_types[type_id].get("equipment_mode", "fixed")) == "mixed"


static func _kit(scn: Dictionary, type_id: String, count: int) -> Dictionary:
	var result := {}
	var need: Dictionary = scn.troop_types[type_id].equipment
	for good: String in _sorted(need):
		if count * int(need[good]) > 0:
			result[good] = count * int(need[good])
	return result


static func _new_stack() -> Dictionary:
	return {"count": 0, "xp": 0.0, "gear": {}}


static func _gear_total(gear: Dictionary) -> int:
	var total := 0
	for good: String in gear:
		total += int(gear[good])
	return total


## Detaches `n` soldiers with their own share of the stack's gear. Fixed kits
## scale exactly; a mixed levy hands over whole items so that no man carries
## more than one weapon and the rest keep what they had.
static func _split(scn: Dictionary, type_id: String, stack: Dictionary, n: int) -> Dictionary:
	n = clampi(n, 0, int(stack.count))
	var part := {"count": n, "xp": float(stack.xp), "gear": {}}
	if n == 0:
		return part
	if not _mixed(scn, type_id):
		part.gear = _kit(scn, type_id, n)
	elif n == int(stack.count):
		part.gear = (stack.gear as Dictionary).duplicate()
	else:
		for good: String in _sorted(stack.gear):
			var take := floori(int(stack.gear[good]) * float(n) / int(stack.count))
			if take > 0:
				part.gear[good] = take
		var remaining := _gear_total(stack.gear) - _gear_total(part.gear)
		while remaining > int(stack.count) - n:
			var most := ""
			for good: String in _sorted(stack.gear):
				var left := int(stack.gear[good]) - int(part.gear.get(good, 0))
				if left > 0 and (most == "" or left > int(stack.gear[most]) - int(part.gear.get(most, 0))):
					most = good
			part.gear[most] = int(part.gear.get(most, 0)) + 1
			remaining -= 1
	stack.count = int(stack.count) - n
	for good: String in part.gear:
		stack.gear[good] = int(stack.gear[good]) - int(part.gear[good])
		if int(stack.gear[good]) == 0:
			stack.gear.erase(good)
	if int(stack.count) == 0:
		stack.xp = 0.0
		stack.gear = {}
	return part


static func _merge(troops: Dictionary, type_id: String, part: Dictionary) -> void:
	if int(part.count) <= 0:
		return
	if not troops.has(type_id):
		troops[type_id] = _new_stack()
	var stack: Dictionary = troops[type_id]
	stack.xp = _q((float(stack.xp) * int(stack.count) + float(part.xp) * int(part.count)) / maxf(1.0, int(stack.count) + int(part.count)))
	stack.count = int(stack.count) + int(part.count)
	for good: String in _sorted(part.gear):
		stack.gear[good] = int(stack.gear.get(good, 0)) + int(part.gear[good])


## Recruits are civilians who take whatever arms the stock holds.
static func _recruit(state: Dictionary, scn: Dictionary, gid: String, type_id: String, n: int, reason: String) -> int:
	var g: Dictionary = state.groups[gid]
	if n <= 0:
		return 0
	var part := {"count": n, "xp": 0.0, "gear": {}}
	if _mixed(scn, type_id):
		var left := n
		for good: String in scn.troop_types[type_id].slots:
			var take := mini(left, int(g.stock[good]))
			if take > 0:
				part.gear[good] = take
				left -= take
	else:
		var need: Dictionary = scn.troop_types[type_id].equipment
		for good: String in need:
			n = mini(n, floori(int(g.stock[good]) / float(need[good])))
		if n <= 0:
			return 0
		part.count = n
		part.gear = _kit(scn, type_id, n)
	for good: String in _sorted(part.gear):
		_move(state, gid, good, int(part.gear[good]), "stock", "held", reason)
	_merge(g.troops, type_id, part)
	if bool(scn.troop_types[type_id].get("persons", false)):
		for i in n:
			_new_retainer(state, scn, gid, "home", int(state.tick))
	return n


## Soldiers return to civil life with their gear going back to the stock.
static func _dismiss(state: Dictionary, scn: Dictionary, gid: String, type_id: String, n: int, reason: String) -> void:
	var g: Dictionary = state.groups[gid]
	if n <= 0 or not g.troops.has(type_id):
		return
	var part := _split(scn, type_id, g.troops[type_id], n)
	for good: String in _sorted(part.gear):
		_move(state, gid, good, int(part.gear[good]), "held", "stock", reason)
	if bool(scn.troop_types[type_id].get("persons", false)):
		_retainers_leave(state, gid, "home", int(part.count), "alive", "veteran", reason)


static func _new_retainer(state: Dictionary, scn: Dictionary, gid: String, with: String, t: int) -> String:
	var pid := _new_person(state, scn, gid, "retainer", 19.0 + 14.0 * _rand(state), 5.0 + 10.0 * _rand(state))
	state.persons[pid].with = with
	var chief := str(state.groups[gid].leader)
	if state.persons.has(chief) and chief != pid:
		Relations.apply(state.relations, pid, chief, "oath_" + pid, t, "retinue_oath", {"loyalty": 35.0, "trust": 25.0})
	return pid


static func retainers(state: Dictionary, gid: String, with: String = "") -> Array:
	var result := []
	for pid: String in _sorted(state.persons):
		var p: Dictionary = state.persons[pid]
		if p.group == gid and p.role == "retainer" and p.status == "alive" and (with == "" or p.with == with):
			result.append(pid)
	return result


## Takes `n` retainers out of the retinue: fallen, deserted or retired. The
## chosen ones are drawn with the seeded generator, never re-created.
static func _retainers_leave(state: Dictionary, gid: String, with: String, n: int, status: String, role: String, cause: String) -> Array:
	var pool := retainers(state, gid, with)
	var chosen := []
	for i in mini(n, pool.size()):
		var index := floori(_rand(state) * pool.size()) % pool.size()
		var pid: String = pool[index]
		pool.remove_at(index)
		var p: Dictionary = state.persons[pid]
		p.status = status
		p.role = role
		p.since = int(state.tick)
		p["fate"] = cause
		chosen.append(pid)
	return chosen


static func _desert(state: Dictionary, scn: Dictionary, gid: String, type_id: String, count: int, reason: String) -> void:
	var g: Dictionary = state.groups[gid]
	if count <= 0 or not g.troops.has(type_id):
		return
	var part := _split(scn, type_id, g.troops[type_id], count)
	for good: String in _sorted(part.gear):
		_book(state, _next(state, "t"), gid, good, int(part.gear[good]), "external_out", reason, "beyond_area", "held")
	var where := _most_populous(g)
	_people(state, gid, where, mini(int(part.count), int(g.settlements[where].population)), "external_out", reason, "beyond_area")
	if bool(scn.troop_types[type_id].get("persons", false)):
		_retainers_leave(state, gid, "home", int(part.count), "left", "retainer", reason)


static func _recruit_and_upgrade(state: Dictionary, scn: Dictionary, gid: String, t: int) -> void:
	var g: Dictionary = state.groups[gid]
	var tr := traits(state, gid)
	var pop := _population(g)
	var adults := roundi(pop * float(scn.economy.adult_share))
	var warriors := _warriors_home(g) + _warriors_away(state, gid)
	var ratio := clampf(0.4 + 0.3 * float(tr.boldness) - 0.1 * float(tr.trade) + (0.08 if int(g.prepared_until) >= t else 0.0), 0.2, 0.6)
	var target := roundi(adults * ratio)
	var recruit_type := str(scn.troop_trees[g.culture].recruit)
	var year := year_of(state)
	if warriors < target and _content_available(scn, "troop_types", recruit_type, year):
		var gap := ceili((target - warriors) * (0.4 if int(g.prepared_until) >= t else 0.2))
		var armed := 0
		for good: String in scn.troop_types[recruit_type].get("slots", []):
			armed += int(g.stock[good])
		_recruit(state, scn, gid, recruit_type, mini(gap, armed + ceili(gap * 0.3)), "recruitment")
	elif warriors > roundi(target * 1.15) and int(g.hunger_weeks) > 2 and g.troops.has(recruit_type):
		_dismiss(state, scn, gid, recruit_type, mini(int(g.troops[recruit_type].count), ceili((warriors - target) * 0.2)), "demobilised_for_fields")
	# Upgrades: experience plus real equipment plus, for the retinue, a hall.
	warriors = maxi(1, _warriors_home(g) + _warriors_away(state, gid))
	var retinue_room := _building_count(g, "hall") * int(scn.buildings.hall.retinue) - _troop_total(state, gid, "gefolgsmann")
	# Each community keeps a mix that suits its character: a levy core, some
	# skirmishers, horsemen where horses and boldness allow, few specialists.
	var desired := {"speerkrieger": 0.5, "plaenkler": 0.12 + 0.1 * float(tr.caution), "reiter": 0.06 + 0.14 * float(tr.boldness), "gefolgsmann": 1.0, "axtkrieger": 1.0, "schwertkaempfer": 1.0}
	for type_id: String in _sorted(g.troops):
		var stack: Dictionary = g.troops[type_id]
		var options: Array = scn.troop_types[type_id].upgrades
		if options.is_empty() or int(stack.count) <= 0:
			continue
		if type_id == recruit_type and _troop_total(state, gid, type_id) <= roundi(warriors * 0.25):
			continue
		for option: Dictionary in _upgrade_order(g, tr, options):
			var to := str(option.to)
			if float(stack.xp) < float(option.xp) or not _content_available(scn, "troop_types", to, year):
				continue
			if _troop_total(state, gid, to) >= roundi(warriors * float(desired.get(to, 0.3))):
				continue
			if option.has("building") and _building_count(g, str(option.building)) == 0:
				continue
			var n := floori(int(stack.count) * 0.2)
			if option.has("rare"):
				n = mini(n, mini(1, ceili(warriors * float(option.rare)) - _troop_total(state, gid, to)))
			if to == "gefolgsmann":
				n = mini(n, retinue_room)
			while n > 0 and not _upgrade_affordable(scn, g, type_id, to, n):
				n -= 1
			if n <= 0:
				continue
			_upgrade(state, scn, gid, type_id, to, n, float(option.xp))
			if to == "gefolgsmann":
				retinue_room -= n
			break


static func _troop_total(state: Dictionary, gid: String, type_id: String) -> int:
	var total := int(state.groups[gid].troops.get(type_id, {}).get("count", 0))
	for e: Dictionary in state.expeditions:
		if e.group == gid:
			total += int(e.troops.get(type_id, {}).get("count", 0))
	return total


static func _upgrade_affordable(scn: Dictionary, g: Dictionary, from: String, to: String, n: int) -> bool:
	var preview := _split(scn, from, (g.troops[from] as Dictionary).duplicate(true), n)
	var kit := _kit(scn, to, n)
	for good: String in kit:
		if int(kit[good]) - mini(int(preview.gear.get(good, 0)), int(kit[good])) > int(g.stock[good]):
			return false
	return true


## A soldier keeps what fits his new role, takes the rest from the stock and
## hands back what he no longer carries.
static func _upgrade(state: Dictionary, scn: Dictionary, gid: String, from: String, to: String, n: int, xp_cost: float) -> void:
	var g: Dictionary = state.groups[gid]
	var part := _split(scn, from, g.troops[from], n)
	var kit := _kit(scn, to, n)
	var goods := {}
	for good: String in kit:
		goods[good] = true
	for good: String in part.gear:
		goods[good] = true
	for good: String in _sorted(goods):
		var have := int(part.gear.get(good, 0))
		var want := int(kit.get(good, 0))
		if want > have:
			_move(state, gid, good, want - have, "stock", "held", "upgrade_" + to)
		elif have > want:
			_move(state, gid, good, have - want, "held", "stock", "upgrade_" + to)
	part.gear = kit
	part.xp = _q(maxf(0.0, float(part.xp) - xp_cost))
	_merge(g.troops, to, part)
	if bool(scn.troop_types[to].get("persons", false)):
		for i in n:
			_new_retainer(state, scn, gid, "home", int(state.tick))


static func _upgrade_order(g: Dictionary, tr: Dictionary, options: Array) -> Array:
	## Preference follows the group's character, not a global best unit.
	var ordered := options.duplicate()
	var weights := {"speerkrieger": 1.0, "plaenkler": 0.4 + float(tr.caution) * 0.5, "axtkrieger": 0.15, "schwertkaempfer": 0.3 + float(tr.pride) * 0.3,
		"gefolgsmann": 0.6 + float(tr.pride), "reiter": 0.4 + float(tr.boldness) + (0.3 if int(g.stock.horse) > 4 else -0.5)}
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var wa := float(weights.get(str(a.to), 0.5))
		var wb := float(weights.get(str(b.to), 0.5))
		return wa > wb if wa != wb else str(a.to) < str(b.to))
	return ordered


static func _content_available(scn: Dictionary, section: String, id: String, year: int) -> bool:
	var item: Dictionary = scn[section].get(id, {})
	return not item.is_empty() and year >= int(item.get("from_year", -10000)) and year <= int(item.get("to_year", 10000))


static func _construction(state: Dictionary, scn: Dictionary, gid: String, labour: float, t: int) -> float:
	var g: Dictionary = state.groups[gid]
	if g.project.is_empty() or labour <= 0.0:
		return labour
	var p: Dictionary = g.project
	var use := minf(labour * 0.6, float(p.labour_left))
	var factor := 1.0
	var total := maxf(1.0, float(p.labour_total))
	for good: String in _sorted(p.cost_left):
		var left := int(p.cost_left[good])
		if left <= 0:
			continue
		var wanted := mini(left, ceili(float(p.cost_total[good]) * (use / total)) if float(p.labour_left) > 0.0 else left)
		if wanted > 0 and int(g.stock[good]) < wanted:
			factor = minf(factor, float(g.stock[good]) / wanted)
	use *= factor
	var progressed := false
	for good: String in _sorted(p.cost_left):
		var left := int(p.cost_left[good])
		if left <= 0:
			continue
		var wanted := mini(left, ceili(float(p.cost_total[good]) * (use / total)) if float(p.labour_left) > 0.0 else left)
		wanted = mini(wanted, int(g.stock[good]))
		if wanted > 0:
			_tx(state, gid, good, wanted, "consume", "construction_" + str(p.kind))
			p.cost_left[good] = left - wanted
			progressed = true
	if use > 0.000001:
		p.labour_left = _q(maxf(0.0, float(p.labour_left) - use))
		progressed = true
	if progressed:
		p.progress_tick = t
	var materials_done := true
	for good: String in p.cost_left:
		materials_done = materials_done and int(p.cost_left[good]) == 0
	if materials_done and float(p.labour_left) <= 0.0001:
		_complete_project(state, scn, gid, t)
	return labour - use


static func _complete_project(state: Dictionary, scn: Dictionary, gid: String, t: int) -> void:
	var g: Dictionary = state.groups[gid]
	var p: Dictionary = g.project
	g.project = {}
	var where: int = clampi(int(p.settlement), 0, g.settlements.size() - 1)
	match str(p.kind):
		"build":
			var s: Dictionary = g.settlements[where]
			s.buildings[p.building] = int(s.buildings.get(p.building, 0)) + 1
			g.history.built = int(g.history.built) + 1
			state.stats.buildings = int(state.stats.buildings) + 1
			_event(state, "building_completed", [gid], "%s: %s in %s fertig." % [g.name, scn.buildings[p.building].name, s.name], "Arbeit %d, Material %s" % [int(p.labour_total), JSON.stringify(p.cost_total)], [gid])
		"repair":
			g.settlements[where].damage = _q(maxf(0.0, float(g.settlements[where].damage) - float(p.repairs)))
			_event(state, "repaired", [gid], "%s bessert die Schäden in %s aus." % [g.name, g.settlements[where].name], "Schaden %.0f" % float(p.repairs), [gid])
		"found":
			if g.sites.is_empty() or g.settlements.size() >= int(scn.economy.max_settlements):
				return
			var site: Dictionary = g.sites.pop_front()
			var source := _most_populous(g)
			var migrants := mini(int(scn.projects.found_settlement.migrants), int(g.settlements[source].population) - 40)
			if migrants <= 0:
				return
			var fresh := _new_settlement(scn, site, "s%d" % (g.settlements.size() + 1), t)
			fresh.buildings.longhouse = int(scn.projects.found_settlement.longhouses)
			g.settlements.append(fresh)
			g.settlements[source].population = int(g.settlements[source].population) - migrants
			fresh.population = migrants
			state.ledger.append({"tx": _next(state, "t"), "tick": t, "actor": gid, "good": "people", "qty": migrants, "account": fresh.id, "category": "move", "reason": "settlers", "counter": g.settlements[source].id})
			g.history.founded = int(g.history.founded) + 1
			state.stats.settlements_founded = int(state.stats.settlements_founded) + 1
			_event(state, "settlement_founded", [gid], "%s gründet %s mit %d Siedlern." % [g.name, fresh.name, migrants], "Wohnraum und Felder reichten nicht mehr", [gid], true)


static func _crafting(state: Dictionary, scn: Dictionary, gid: String, labour: float) -> float:
	var g: Dictionary = state.groups[gid]
	var smithies := _building_count(g, "smithy")
	var capacity := minf(labour, smithies * float(scn.buildings.smithy.craft_labour))
	var spare := minf(labour - capacity, 4.0)
	var used := 0.0
	var desired := {"spear": 18, "shield": 16, "javelin": 8, "axe": 3, "blade": 4 if _building_count(g, "hall") > 0 else 0}
	for i in 24:
		var choice := ""
		if smithies > 0 and int(g.stock.iron) < 14 and int(g.stock.ore) >= 2 and int(g.stock.wood) >= 3 and capacity - used >= 2.0:
			choice = "smelt"
		else:
			var best := 0.0
			for good: String in ["spear", "shield", "javelin", "axe", "blade"]:
				var recipe: Dictionary = scn.recipes[good]
				var deficit := (int(desired[good]) - int(g.stock[good])) / maxf(1.0, int(desired[good]))
				if deficit <= best:
					continue
				var room := (capacity - used) if str(recipe.building) == "smithy" else spare
				if room < float(recipe.labour):
					continue
				var ok := true
				for input: String in recipe.inputs:
					ok = ok and int(g.stock[input]) >= int(recipe.inputs[input])
				if ok:
					best = deficit
					choice = good
		if choice == "":
			break
		var r: Dictionary = scn.recipes[choice]
		for input: String in _sorted(r.inputs):
			_tx(state, gid, input, int(r.inputs[input]), "consume", "craft_" + choice)
		_tx(state, gid, str(r.output), int(r.quantity), "produce", "craft_" + choice)
		if str(r.building) == "smithy":
			used += float(r.labour)
		else:
			spare -= float(r.labour)
			labour -= float(r.labour)
	return labour - used


static func _band_economy(state: Dictionary, gid: String, t: int) -> void:
	var g: Dictionary = state.groups[gid]
	var scn := scenario(str(state.scenario))
	var due := _accrue(g, "upkeep", float(g.extra.get("wealth_per_week", 0.0)))
	var paid := mini(due, int(g.stock.wealth))
	if paid > 0:
		_book(state, _next(state, "t"), gid, "wealth", paid, "external_out", "upkeep_purchase", "regional_market")
	var target := 55.0 if paid == due else 35.0
	g.morale = _q(clampf(float(g.morale) + (target - float(g.morale)) * 0.1, 0.0, 100.0))
	if float(g.morale) < 20.0:
		for type_id: String in _sorted(g.troops):
			_desert(state, scn, gid, type_id, maxi(1, roundi(int(g.troops[type_id].count) * 0.05)), "desertion")
	if _warriors_home(g) + _warriors_away(state, gid) == 0 and g.status == "active":
		g.status = "dispersed"
		_event(state, "band_dispersed", [gid], "%s löst sich auf." % g.name, "Keine Reiter mehr", [gid])


static func _market_economy(state: Dictionary, gid: String, week: int) -> void:
	var g: Dictionary = state.groups[gid]
	if week % 13 != 0:
		return
	# The traders leave with what they bought; new traders bring new goods.
	for good: String in _sorted(g.stock):
		if not g.extra.arrival.has(good) and int(g.stock[good]) > 0:
			_book(state, _next(state, "t"), gid, good, int(g.stock[good]), "external_out", "traders_depart", "gaul")
	for good: String in _sorted(g.extra.arrival):
		var room := int(g.extra.cap.get(good, 0)) - int(g.stock[good])
		var amount := mini(int(g.extra.arrival[good]), room)
		if amount > 0:
			_book(state, _next(state, "t"), gid, good, amount, "external_in", "traders_arrive", "gaul")


static func _chief_prestige(state: Dictionary, gid: String) -> float:
	var chief: Dictionary = state.persons.get(str(state.groups[gid].leader), {})
	return float(chief.get("prestige", 40.0)) if not chief.is_empty() else 30.0


static func _prestige(state: Dictionary, gid: String, amount: float) -> void:
	var chief: Dictionary = state.persons.get(str(state.groups[gid].leader), {})
	if not chief.is_empty():
		chief.prestige = _q(clampf(float(chief.prestige) + amount, 0.0, 100.0))
	var war_leader: Dictionary = state.persons.get(str(state.groups[gid].get("war_leader", "")), {})
	if not war_leader.is_empty() and str(state.groups[gid].war_leader) != str(state.groups[gid].leader):
		war_leader.prestige = _q(clampf(float(war_leader.prestige) + amount, 0.0, 100.0))


# ---------------------------------------------------------------- anchors

static func _anchors(state: Dictionary, scn: Dictionary, t: int) -> void:
	for anchor: Dictionary in scn.anchors:
		var id := str(anchor.id)
		if state.anchors.has(id) or int(anchor.tick) > t:
			continue
		var requires: Dictionary = anchor.get("requires", {})
		var met := true
		for gid: String in requires.get("active", []):
			met = met and state.groups.has(gid) and state.groups[gid].status == "active"
		for gid: String in requires.get("departed", []):
			met = met and state.groups.has(gid) and state.groups[gid].status == "departed"
		if requires.has("agreement"):
			var spec: Array = requires.agreement
			met = met and not _active_agreement(state, str(spec[1]), str(spec[2]), [str(spec[0])]).is_empty()
		if not met:
			state.anchors[id] = "divergent"
			_event(state, "anchor_divergent", [], "Historischer Anker %s ist wegen eines abweichenden Weltzustands nicht anwendbar." % id, "Voraussetzung nicht erfüllt", [], false, "divergence")
			continue
		state.anchors[id] = "applied"
		var touched := []
		var event := _event(state, "anchor", [], str(anchor.text), "%s · Quelle %s · Größen: %s" % [id, str(anchor.source), str(anchor.magnitude_kind)], [], true, "documented_anchor")
		for effect: Dictionary in anchor.effects:
			touched.append_array(_anchor_effect(state, scn, effect, event, t))
		var record: Dictionary = state.events.back()
		for gid: String in touched:
			if gid not in record.known_by:
				record.known_by.append(gid)
		record.known_by.sort()
		record.actors = record.known_by.duplicate()


static func _anchor_effect(state: Dictionary, scn: Dictionary, effect: Dictionary, event: String, t: int) -> Array:
	match str(effect.kind):
		"relation":
			var observers := []
			if str(effect.observer) == "*rome_known":
				for gid: String in _active_tribes(state):
					if Relations.knows(state.relations, gid, str(effect.subject)):
						observers.append(gid)
			elif state.groups.has(str(effect.observer)) and state.groups[effect.observer].status == "active":
				observers.append(str(effect.observer))
			for gid: String in observers:
				_affect(state, gid, str(effect.subject), event, "documented_anchor", effect.values)
			return observers
		"morale":
			var g: Dictionary = state.groups[effect.group]
			g.morale = _q(clampf(float(g.morale) + float(effect.amount), 0.0, 100.0))
			return [str(effect.group)]
		"depart":
			var gid := str(effect.group)
			state.groups[gid].status = "departed"
			for e: Dictionary in state.expeditions.duplicate():
				if e.group == gid:
					_return_home(state, scn, e, t)
			for item: Dictionary in state.agreements:
				if item.status == "active" and (item.a == gid or item.b == gid):
					item.status = "void"
					item.closed_tick = t
			return [gid]
		"refugees":
			var from := str(effect.from)
			var to := str(effect.to)
			var type_id := str(effect.troop)
			var g: Dictionary = state.groups[from]
			var count := int(g.troops.get(type_id, {}).get("count", 0))
			if count > 0:
				var part := _split(scn, type_id, g.troops[type_id], count)
				for good: String in _sorted(part.gear):
					_transfer(state, from, to, good, int(part.gear[good]), "refugee_warriors", "held", "held")
				_merge(state.groups[to].troops, type_id, part)
				var moved := mini(count, int(g.settlements[0].population))
				var tx := _next(state, "t")
				_people(state, from, 0, moved, "transfer_out", "refugees", to, tx)
				_people(state, to, 0, moved, "transfer_in", "refugees", from, tx)
				Relations.apply(state.relations, from, to, event, t, "shelter", {"obligation": 30.0, "trust": 15.0})
			return [from, to]
		"leave_area":
			var gid := str(effect.group)
			var g: Dictionary = state.groups[gid]
			for type_id: String in _sorted(g.troops):
				var part := _split(scn, type_id, g.troops[type_id], int(g.troops[type_id].count))
				for good: String in _sorted(part.gear):
					_book(state, _next(state, "t"), gid, good, int(part.gear[good]), "external_out", "left_area", "beyond_area", "held")
			for good: String in _sorted(g.stock):
				_book(state, _next(state, "t"), gid, good, int(g.stock[good]), "external_out", "left_area", "beyond_area")
			for i in g.settlements.size():
				_people(state, gid, i, int(g.settlements[i].population), "external_out", "left_area", "beyond_area")
			g.project = {}
			g.status = "left_area"
			for pid: String in _sorted(state.persons):
				if state.persons[pid].group == gid and state.persons[pid].status == "alive":
					state.persons[pid].status = "left_area"
					state.persons[pid].since = t
			return [gid]
		"agreement":
			_make_agreement(state, str(effect.agreement), str(effect.a), str(effect.b), t, int(effect.duration), {}, 0, "documented_anchor")
			return [str(effect.a)]
		"war_damage":
			var gid := str(effect.group)
			var g: Dictionary = state.groups[gid]
			for s: Dictionary in g.settlements:
				s.damage = _q(clampf(float(s.damage) + float(effect.damage), 0.0, 100.0))
			_book(state, _next(state, "t"), gid, "food", floori(int(g.stock.food) * float(effect.food_share)), "destroy", "war_damage", str(effect.by))
			return [gid]
		"refuge":
			state.groups[effect.group].refuge_until = t + int(effect.ticks)
			return [str(effect.group)]
		"relocate":
			var g: Dictionary = state.groups[effect.group]
			var s: Dictionary = g.settlements[0]
			s.name = str(effect.name)
			s.lat = float(effect.lat)
			s.lon = float(effect.lon)
			s.damage = _q(clampf(float(s.damage) + float(effect.damage), 0.0, 100.0))
			g.atlas_region = str(effect.atlas_region)
			return [str(effect.group)]
	return []


# ---------------------------------------------------------------- agreements

static func _make_agreement(state: Dictionary, kind: String, a: String, b: String, t: int, duration: int, terms: Dictionary, every: int, canon: String) -> Dictionary:
	var record := {"id": _next(state, "a"), "kind": kind, "a": a, "b": b, "start": t, "end": t + duration, "every": every,
		"terms": terms, "status": "active", "paid": 0, "missed": 0, "broken_by": "", "closed_tick": -1, "canon_kind": canon}
	state.agreements.append(record)
	state.stats.agreements_made = int(state.stats.agreements_made) + 1
	while state.agreements.size() > MAX_AGREEMENTS:
		var dropped := false
		for i in state.agreements.size():
			if state.agreements[i].status != "active":
				state.agreements.remove_at(i)
				dropped = true
				break
		if not dropped:
			break
	return record


static func _break_agreement(state: Dictionary, item: Dictionary, breaker: String, t: int, why: String) -> void:
	item.status = "broken"
	item.broken_by = breaker
	item.closed_tick = t
	state.stats.agreements_broken = int(state.stats.agreements_broken) + 1
	var victim := str(item.b) if item.a == breaker else str(item.a)
	var event := _event(state, "oath_broken", [breaker, victim], "%s bricht die Vereinbarung (%s) mit %s." % [_name(state, breaker), item.kind, _name(state, victim)], why, [breaker, victim], true)
	if state.groups.has(victim) or state.targets.has(victim):
		_affect(state, victim, breaker, event, "oath_broken", {"trust": -30.0, "grievance": 20.0, "respect": -10.0})
	if state.groups.has(breaker) and state.groups[breaker].kind == "tribe":
		_drift(state.groups[breaker], "faith", -0.02)


static func _agreements_tick(state: Dictionary, scn: Dictionary, t: int) -> void:
	_expire_disputes(state, t)
	for item: Dictionary in state.agreements.duplicate():
		if item.status != "active":
			continue
		var a := str(item.a)
		var b := str(item.b)
		if item.kind == "tribute" and int(item.every) > 0 and t > int(item.start) and (t - int(item.start)) % int(item.every) == 0:
			_tribute_due(state, item, t)
			if item.status != "active":
				continue
		if t >= int(item.end):
			if item.kind == "commission":
				item.status = "expired"
				item.closed_tick = t
				continue
			item.status = "kept"
			item.closed_tick = t
			state.stats.agreements_kept = int(state.stats.agreements_kept) + 1
			var event := _event(state, "agreement_kept", [a, b], "%s und %s haben die Vereinbarung (%s) eingehalten." % [_name(state, a), _name(state, b), item.kind], "Frist erreicht ohne Bruch", [a, b], true)
			var bonus := 8.0 if item.kind == "alliance" else 5.0
			if item.kind in ["truce", "alliance", "guest_friendship"]:
				_settle_disputes(state, a, b, "%s eingehalten" % item.kind)
			if item.kind == "tribute":
				_affect(state, b, a, event, "agreement_kept", {"trust": 3.0})
			else:
				for pair: Array in [[a, b], [b, a]]:
					if state.groups.has(pair[0]):
						_affect(state, str(pair[0]), str(pair[1]), event, "agreement_kept", {"trust": bonus, "respect": 3.0})
			# Friendly partners renew; a tributary must be pressed again.
			if item.kind in ["alliance", "trade_pact", "guest_friendship", "amicitia"] and state.groups.has(a) and state.groups[a].status == "active" and (not state.groups.has(b) or state.groups[b].status == "active"):
				if _rel(state, a, b, "trust") >= 15.0 and (not state.groups.has(b) or _rel(state, b, a, "trust") >= 15.0):
					_make_agreement(state, str(item.kind), a, b, t, int(item.end) - int(item.start), (item.terms as Dictionary).duplicate(), int(item.every), "simulation")
					_event(state, "agreement_renewed", [a, b], "%s und %s erneuern %s." % [_name(state, a), _name(state, b), item.kind], "Vertrauen beider Seiten", [a, b])


static func _tribute_due(state: Dictionary, item: Dictionary, t: int) -> void:
	var payer := str(item.a)
	var receiver := str(item.b)
	if not state.groups.has(payer) or state.groups[payer].status != "active" or not state.groups.has(receiver) or state.groups[receiver].status != "active":
		item.status = "void"
		item.closed_tick = t
		return
	var g: Dictionary = state.groups[payer]
	var tr := traits(state, payer)
	var can_pay := true
	for good: String in item.terms:
		can_pay = can_pay and int(g.stock[good]) >= int(item.terms[good])
	var defiant := strength(state, payer) >= strength(state, receiver) * 0.9 and float(tr.pride) >= 0.5
	defiant = defiant or (_rel(state, payer, receiver, "grievance") >= 60.0 and _rel(state, payer, receiver, "fear") < 30.0)
	if can_pay and not defiant:
		for good: String in _sorted(item.terms):
			_transfer(state, payer, receiver, good, int(item.terms[good]), "tribute")
		item.paid = int(item.paid) + 1
		var event := _event(state, "tribute_paid", [payer, receiver], "%s liefert den Tribut an %s (%s)." % [g.name, _name(state, receiver), JSON.stringify(item.terms)], "Frist %d" % t, [payer, receiver])
		_affect(state, receiver, payer, event, "tribute_paid", {"trust": 2.0})
		_affect(state, payer, receiver, event, "tribute_paid", {"grievance": 3.0})
		_prestige(state, receiver, 1.0)
	else:
		item.missed = int(item.missed) + 1
		_break_agreement(state, item, payer, t, "Tribut nicht geliefert (%s)" % ("Weigerung" if can_pay else "Mangel"))
		var event := str(state.events.back().id)
		_affect(state, receiver, payer, event, "tribute_refused", {"grievance": 15.0})
		# A broken tribute rekindles an existing feud; on its own it is no cause.
		if not dispute_for(state, receiver, payer).is_empty():
			_open(state, receiver, payer, "retaliation", "agreement:" + str(item.id), "Tribut verweigert", 26)


# ---------------------------------------------------------------- leadership

static func age_of(state: Dictionary, pid: String) -> float:
	return (int(state.tick) - int(state.persons[pid].born_tick)) / float(WEEKS)


static func _leadership(state: Dictionary, scn: Dictionary, t: int) -> void:
	for pid: String in _sorted(state.persons):
		var p: Dictionary = state.persons[pid]
		if p.status != "alive":
			continue
		var age := age_of(state, pid)
		var hazard := 0.0003 if age < 40.0 else (0.0008 if age < 55.0 else (0.002 if age < 65.0 else 0.006))
		if _rand(state) < hazard:
			p.status = "dead"
			p.since = t
			p.fate = "natural_death"
			var g: Dictionary = state.groups[p.group]
			if p.role == "retainer":
				_retainer_died(state, scn, str(p.group), str(p.with))
			var where := _most_populous(g)
			if int(g.settlements[where].population) > 0:
				_people(state, str(p.group), where, 1, "destroy", "death_of_named_person")
			_event(state, "person_died", [str(p.group), pid], "%s (%s) stirbt im Alter von %d Jahren." % [p.name, g.name, floori(age)], "Alter", [str(p.group)], g.kind == "tribe" and p.role in ["chief", "heir", "rival"])
			if g.leader == pid:
				_succession(state, scn, str(p.group), t, "Tod des Anführers")
	for gid: String in _sorted(state.groups):
		var g: Dictionary = state.groups[gid]
		var war_leader := str(g.war_leader)
		if war_leader == "":
			continue
		if not state.persons.has(war_leader) or state.persons[war_leader].status != "alive" or g.status != "active":
			g.war_leader = ""
			g.war_until = -1
		elif t > int(g.war_until):
			g.war_leader = ""
			g.war_until = -1
			_event(state, "war_leader_resigns", [gid, war_leader], "%s legt die Heerführung in %s nieder; der Krieg ist vorbei." % [state.persons[war_leader].name, g.name], "Wochen ohne Kampf", [gid])
	for gid: String in _active_tribes(state):
		_challenge(state, scn, gid, t)
	# The dead and the departed are remembered for two years, then pruned.
	for pid: String in _sorted(state.persons):
		var p: Dictionary = state.persons[pid]
		if p.status != "alive" and t - int(p.since) > 104 and state.groups[p.group].leader != pid:
			Relations.remove_actor(state.relations, pid)
			state.persons.erase(pid)


## A retainer who dies outside battle leaves the retinue; his horse and arms
## return to the household (or are carried home by the war band).
static func _retainer_died(state: Dictionary, scn: Dictionary, gid: String, location: String) -> void:
	var g: Dictionary = state.groups[gid]
	if location == "home":
		if int(g.troops.get("gefolgsmann", {}).get("count", 0)) > 0:
			var part := _split(scn, "gefolgsmann", g.troops.gefolgsmann, 1)
			for good: String in _sorted(part.gear):
				_move(state, gid, good, int(part.gear[good]), "held", "stock", "retainer_died")
		return
	for e: Dictionary in state.expeditions:
		if e.id == location and int(e.troops.get("gefolgsmann", {}).get("count", 0)) > 0:
			var part := _split(scn, "gefolgsmann", e.troops.gefolgsmann, 1)
			for good: String in _sorted(part.gear):
				_move(state, gid, good, int(part.gear[good]), "held", "cargo", "retainer_died", e)


static func _recently(state: Dictionary, observer: String, subject: String, kinds: Array, within: int) -> bool:
	var edge: Dictionary = state.relations.edges.get(Relations.key(observer, subject), {})
	for memory: Dictionary in edge.get("memories", []):
		if str(memory.kind) in kinds and int(state.tick) - int(memory.tick) <= within:
			return true
	return false


static func _members(state: Dictionary, gid: String, role: String = "") -> Array:
	var result := []
	for pid: String in _sorted(state.persons):
		var p: Dictionary = state.persons[pid]
		if p.group == gid and p.status == "alive" and (role == "" or p.role == role):
			result.append(pid)
	return result


static func _succession(state: Dictionary, scn: Dictionary, gid: String, t: int, why: String) -> void:
	var g: Dictionary = state.groups[gid]
	var gov := government(state, gid)
	var model := str(g.government)
	var old := str(g.leader)
	var family := str(state.persons[old].family) if state.persons.has(old) else ""
	var best := ""
	var best_score := -1000.0
	for pid: String in _members(state, gid):
		var p: Dictionary = state.persons[pid]
		if pid == old or age_of(state, pid) < 18.0 or p.role in ["exile", "elder", "retainer"]:
			continue
		var score := float(p.prestige) + float(p.traits.get("ambition", 0.5)) * 10.0
		match model:
			"hereditary":
				# The chief's own family keeps the seat; the heir first.
				score += (float(gov.heir_bonus) if p.role == "heir" else 0.0) + (25.0 if p.family == family else 0.0)
			"elders":
				# The council prefers age and a cool head over a famous name.
				score += age_of(state, pid) * 0.5 + float(p.traits.get("caution", 0.5)) * 15.0 - float(p.traits.get("ambition", 0.5)) * 10.0
			_:
				score += float(gov.get("heir_bonus", 10)) if p.role == "heir" else 0.0
		if score > best_score:
			best_score = score
			best = pid
	if best == "":
		best = _new_person(state, scn, gid, "chief", 25.0, 20.0)
	var previous_role := str(state.persons[best].role)
	state.persons[best].role = "chief"
	state.persons[best].since = t
	g.leader = best
	if str(g.war_leader) == best:
		g.war_leader = ""
		g.war_until = -1
	g.history.leaders = int(g.history.leaders) + 1
	state.stats.leader_changes = int(state.stats.leader_changes) + 1
	var bodies := {"assembly": "Die Versammlung", "hereditary": "Die Familie", "elders": "Der Ältestenrat", "war_leader": "Die Versammlung"}
	var event := _event(state, "leader_chosen", [gid, best], "%s von %s bestimmt %s zum Anführer." % [bodies.get(model, "Die Versammlung"), g.name, state.persons[best].name], why, [gid], true)
	if state.persons.has(old) and state.persons[old].status == "alive":
		Relations.apply(state.relations, old, best, event, t, "replaced", {"grievance": 30.0, "envy": 20.0})
	if _members(state, gid, "heir").is_empty() or previous_role == "heir":
		var heir := _new_person(state, scn, gid, "heir", 17.0, 10.0)
		state.persons[heir].family = str(state.persons[best].family)
		Relations.apply(state.relations, heir, best, event, t, "kin", {"loyalty": 40.0, "trust": 30.0})
	if _members(state, gid, "rival").is_empty():
		var rival := _new_person(state, scn, gid, "rival", 30.0, 25.0)
		Relations.apply(state.relations, rival, best, event, t, "family_rivalry", {"envy": 15.0})


## Caesar BG 6,23: a community at war elects leaders for that war. Only
## groups with this form of government do so; the campaign ends after weeks
## without fighting and the leader steps back.
static func _war_council(state: Dictionary, gid: String, t: int, cause: String) -> void:
	var g: Dictionary = state.groups[gid]
	if str(g.get("government", "")) != "war_leader" or g.status != "active":
		return
	var gov := government(state, gid)
	var weeks := int(gov.get("campaign_weeks", 26))
	if str(g.war_leader) != "" and state.persons.has(str(g.war_leader)) and state.persons[g.war_leader].status == "alive":
		g.war_until = maxi(int(g.war_until), t + weeks)
		return
	var best := ""
	var best_score := -1000.0
	for pid: String in _members(state, gid):
		var p: Dictionary = state.persons[pid]
		if age_of(state, pid) < 18.0 or p.role in ["exile", "retainer"]:
			continue
		var score := float(p.prestige) + float(p.traits.get("boldness", 0.5)) * 25.0 + mini(20, int(p.deeds)) * 1.0
		if score > best_score:
			best_score = score
			best = pid
	if best == "":
		return
	g.war_leader = best
	g.war_until = t + weeks
	_event(state, "war_leader_elected", [gid, best], "%s wählt %s zum Heerführer für diesen Krieg." % [g.name, state.persons[best].name], cause, [gid], true)


static func _new_person(state: Dictionary, scn: Dictionary, gid: String, role: String, age: float, prestige: float) -> String:
	var g: Dictionary = state.groups[gid]
	var pool: Array = scn.name_pools.get(str(g.culture), ["Unbenannt"])
	var name := str(pool[floori(_rand(state) * pool.size()) % pool.size()])
	var pid := _next(state, "p_gen_")
	var families: Array = _sorted(g.families)
	var family := str(families[floori(_rand(state) * maxf(1.0, families.size())) % maxi(1, families.size())]) if not families.is_empty() else "f1"
	var tr := {}
	for trait_id: String in ["ambition", "boldness", "caution", "pride", "trade"]:
		tr[trait_id] = _q(clampf(0.2 + 0.6 * _rand(state), 0.0, 1.0))
	state.persons[pid] = {"name": name, "group": gid, "family": family, "role": role, "born_tick": int(state.tick) - roundi(age * WEEKS),
		"traits": tr, "prestige": _q(prestige), "status": "alive", "canon_kind": "fictional_person", "since": int(state.tick), "with": "home", "deeds": 0, "fate": ""}
	return pid


static func _challenge(state: Dictionary, scn: Dictionary, gid: String, t: int) -> void:
	var g: Dictionary = state.groups[gid]
	var chief: Dictionary = state.persons.get(str(g.leader), {})
	if chief.is_empty() or t - int(chief.since) < 26:
		return
	var threshold := float(government(state, gid).get("challenge", 18))
	var contenders := _members(state, gid, "rival")
	if str(g.war_leader) != "" and str(g.war_leader) != str(g.leader) and not (str(g.war_leader) in contenders):
		contenders.append(str(g.war_leader)) # A victorious war leader can reach for lasting rule.
	for pid: String in contenders:
		var rival: Dictionary = state.persons[pid]
		if age_of(state, pid) < 18.0:
			continue
		var unrest := (25.0 if float(g.morale) < 35.0 else 0.0) + 15.0 * minf(1.0, int(g.hunger_weeks) / 6.0) + 20.0 * minf(1.0, float(g.weariness) / 0.3)
		var drive := float(rival.traits.get("ambition", 0.5)) * (float(rival.prestige) - float(chief.prestige) + unrest + _rel(state, pid, str(g.leader), "envy") * 0.3)
		if drive <= threshold:
			continue
		state.stats.challenges = int(state.stats.challenges) + 1
		var rival_support := float(rival.prestige) + unrest + 20.0 * _rand(state)
		var chief_support := float(chief.prestige) + 10.0 + 20.0 * _rand(state)
		if rival_support > chief_support:
			var old := str(g.leader)
			chief.role = "elder"
			chief.since = t
			rival.role = "chief"
			rival.since = t
			g.leader = pid
			if str(g.war_leader) == pid:
				g.war_leader = ""
				g.war_until = -1
			g.history.leaders = int(g.history.leaders) + 1
			state.stats.leader_changes = int(state.stats.leader_changes) + 1
			var event := _event(state, "power_struggle", [gid, pid, old], "In %s setzt sich %s gegen %s durch und führt nun die Gemeinschaft." % [g.name, rival.name, chief.name], "Unruhe %.0f, Ansehen %.0f gegen %.0f" % [unrest, float(rival.prestige), float(chief.prestige)], [gid], true)
			Relations.apply(state.relations, old, pid, event, t, "deposed", {"grievance": 40.0, "envy": 20.0, "trust": -20.0})
			Relations.apply(state.relations, pid, old, event, t, "deposed", {"respect": -10.0})
			if _members(state, gid, "rival").is_empty():
				_new_person(state, scn, gid, "rival", 28.0, 20.0)
		else:
			rival.prestige = _q(maxf(0.0, float(rival.prestige) - 10.0))
			chief.since = t
			var event := _event(state, "power_struggle", [gid, pid, str(g.leader)], "In %s scheitert %s mit dem Versuch, %s abzulösen." % [g.name, rival.name, chief.name], "Unruhe %.0f" % unrest, [gid])
			Relations.apply(state.relations, str(g.leader), pid, event, t, "challenge_failed", {"grievance": 25.0, "trust": -20.0})
			Relations.apply(state.relations, pid, str(g.leader), event, t, "challenge_failed", {"envy": 15.0})
		return


# ---------------------------------------------------------------- knowledge

static func _news(state: Dictionary, scn: Dictionary, t: int) -> void:
	var tribes := _active_tribes(state)
	for ev: Dictionary in state.events:
		if not ev.spread or t - int(ev.tick) > NEWS_AGE:
			continue
		var learners := {}
		for teller: String in ev.known_by:
			if teller not in tribes:
				continue
			for listener: String in tribes:
				if listener in ev.known_by or learners.has(listener):
					continue
				if Relations.knows(state.relations, listener, teller) and _rel(state, teller, listener, "trust") >= 10.0 and _distance_groups(state, teller, listener) <= 150.0:
					learners[listener] = teller
		for listener: String in _sorted(learners):
			ev.known_by.append(listener)
			_learn(state, listener, ev, str(learners[listener]))
		ev.known_by.sort()
	if t % 13 == 0:
		for gid: String in tribes:
			for other: String in _sorted(state.groups):
				if other != gid and Relations.knows(state.relations, gid, other) and state.groups[other].status == "active" and _distance_groups(state, gid, other) <= float(scn.contact_radius_km):
					_observe(state, gid, other)
		for item: Dictionary in state.agreements:
			if item.status == "active" and str(item.kind) in ["alliance", "trade_pact", "guest_friendship"] and state.groups.has(item.a) and state.groups.has(item.b):
				for pair: Array in [[str(item.a), str(item.b)], [str(item.b), str(item.a)]]:
					for actor: String in Relations.known_by(state.relations, pair[1]):
						if actor != pair[0] and (state.groups.has(actor) or state.targets.has(actor)) and not Relations.knows(state.relations, pair[0], actor):
							Relations.introduce(state.relations, pair[0], actor, "told_by_" + pair[1], t, "told_by")
							break


static func _learn(state: Dictionary, listener: String, ev: Dictionary, teller: String) -> void:
	for actor: String in ev.actors:
		if actor != listener and (state.groups.has(actor) or state.targets.has(actor)) and not Relations.knows(state.relations, listener, actor):
			Relations.introduce(state.relations, listener, actor, str(ev.id), int(state.tick), "told_by")
	if state.intel.has(teller):
		for actor: String in ev.actors:
			if state.intel[teller].has(actor) and actor != listener:
				var theirs: Dictionary = state.intel[teller][actor]
				if not state.intel[listener].has(actor) or int(state.intel[listener][actor].tick) < int(theirs.tick):
					state.intel[listener][actor] = theirs.duplicate()
	match str(ev.kind):
		"raid":
			if ev.actors.size() < 2:
				return
			var attacker := str(ev.actors[0])
			var victim := str(ev.actors[1])
			if listener == attacker or listener == victim:
				return
			if not _active_agreement(state, listener, victim, ["alliance"]).is_empty() or _rel(state, listener, victim, "trust") >= 30.0:
				_affect(state, listener, attacker, str(ev.id), "heard_raid_on_friend", {"grievance": 8.0, "trust": -5.0, "fear": 3.0})
			elif _rel(state, listener, victim, "trust") >= 10.0:
				_affect(state, listener, attacker, str(ev.id), "heard_raid", {"trust": -3.0, "fear": 2.0})
		"oath_broken":
			if ev.actors.size() < 1 or listener == str(ev.actors[0]):
				return
			_affect(state, listener, str(ev.actors[0]), str(ev.id), "heard_oath_broken", {"trust": -8.0, "respect": -5.0})
		"agreement_kept":
			for actor: String in ev.actors:
				if actor != listener:
					_affect(state, listener, actor, str(ev.id), "heard_agreement_kept", {"respect": 2.0})


# ---------------------------------------------------------------- decisions

static func _decision_cache(state: Dictionary, t: int) -> Dictionary:
	var cache := {"strength": {}, "defence": {}, "recent_raid": {}, "pacts": {}, "punitive": {}, "amicitia": {}, "tribes": _active_tribes(state), "trade": {}}
	for gid: String in _sorted(state.groups):
		if state.groups[gid].status == "active":
			cache.strength[gid] = strength(state, gid)
			cache.defence[gid] = defence(state, gid)
	for item: Dictionary in state.agreements:
		var pair := _pair(str(item.a), str(item.b))
		if item.status == "active":
			if not cache.pacts.has(pair):
				cache.pacts[pair] = []
			cache.pacts[pair].append(str(item.kind))
			if item.kind == "amicitia":
				cache.amicitia[str(item.a)] = true
				cache.amicitia[str(item.b)] = true
		elif item.status == "broken" and t - int(item.closed_tick) < 26:
			var victim := str(item.b) if item.a == item.broken_by else str(item.a)
			cache.punitive[victim + ">" + str(item.broken_by)] = true
	for ev: Dictionary in state.events:
		if ev.kind == "raid" and t - int(ev.tick) <= 26 and ev.actors.size() >= 2:
			cache.recent_raid[str(ev.actors[0]) + ">" + str(ev.actors[1])] = true
			cache.recent_raid[str(ev.actors[1]) + ">" + str(ev.actors[0])] = true
	return cache


static func _pair(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


static func _has_pact(cache: Dictionary, a: String, b: String, kinds: Array) -> bool:
	for kind: String in cache.pacts.get(_pair(a, b), []):
		if kind in kinds:
			return true
	return false


static func _trade_view(state: Dictionary, scn: Dictionary, cache: Dictionary, gid: String) -> Dictionary:
	if not cache.trade.has(gid):
		cache.trade[gid] = _surplus_and_need(state, scn, gid)
	return cache.trade[gid]


static func _context(state: Dictionary, scn: Dictionary, gid: String, t: int, week: int, cache: Dictionary = {}) -> Dictionary:
	var g: Dictionary = state.groups[gid]
	var pop := _population(g)
	var retinue := int(g.troops.get("gefolgsmann", {}).get("count", 0))
	var weekly := maxf(1.0, pop - _warriors_away(state, gid) + retinue)
	var food_weeks := float(g.stock.food) / weekly
	var hunger := clampf((16.0 - food_weeks) / 16.0, 0.0, 1.0)
	if week >= 14 and week <= 24:
		hunger *= 0.6 # The harvest is close.
	var housing := _housing(scn, g)
	var housing_pressure := clampf((float(pop) / maxf(1.0, housing) - 0.88) * 5.0, 0.0, 1.0)
	var fields := 0
	for s: Dictionary in g.settlements:
		fields += int(s.fields)
	var labour := roundi(pop * float(scn.economy.adult_share)) - _warriors_home(g) * float(scn.economy.warrior_labour)
	var land_pressure := clampf((labour / maxf(1.0, fields) - 0.9) * 3.0, 0.0, 1.0)
	var upkeep := retinue * float(scn.economy.retinue_wealth_per_week) * 13.0
	var wealth_need := clampf((upkeep + 10.0 - float(g.stock.wealth)) / maxf(10.0, upkeep + 10.0), 0.0, 1.0)
	var my_defence := float(cache.defence[gid]) if cache.has("defence") and cache.defence.has(gid) else defence(state, gid)
	var threat := 0.0
	var threat_source := ""
	for other: String in _sorted(state.intel[gid]):
		if not state.groups.has(other) or state.groups[other].status != "active" or state.groups[other].kind != "tribe":
			continue
		var info: Dictionary = state.intel[gid][other]
		var level := (_rel(state, gid, other, "fear") / 100.0 + _rel(state, gid, other, "grievance") / 200.0) * minf(2.0, float(info.strength) / maxf(1.0, my_defence))
		if level > threat:
			threat = level
			threat_source = other
	var incoming := {}
	for e: Dictionary in state.expeditions:
		if e.target == gid and e.status == "outbound":
			for ev: Dictionary in state.events:
				if ev.kind == "war_band_departs" and str(ev.actors[0]) == e.group and gid in ev.known_by:
					incoming = e
	if not incoming.is_empty():
		threat = maxf(threat, troops_strength(scn, incoming.troops) / maxf(1.0, my_defence))
	return {"traits": traits(state, gid), "pop": pop, "food_weeks": food_weeks, "hunger": hunger, "housing": housing,
		"housing_pressure": housing_pressure, "land_pressure": land_pressure, "wealth_need": wealth_need, "threat": clampf(threat, 0.0, 2.0),
		"threat_source": threat_source, "incoming": incoming, "defence": my_defence, "storage": _storage(scn, g), "weekly": weekly}


static func _raid_force(state: Dictionary, scn: Dictionary, gid: String, caution: float) -> Dictionary:
	## Real soldiers that would leave; a home guard stays according to caution.
	var g: Dictionary = state.groups[gid]
	var share := clampf(0.75 - 0.4 * caution, 0.3, 0.75)
	var force := {}
	for type_id: String in _sorted(g.troops):
		var n := floori(int(g.troops[type_id].count) * share)
		if n > 0:
			force[type_id] = _split(scn, type_id, (g.troops[type_id] as Dictionary).duplicate(true), n)
	return force


static func _force_count(force: Dictionary) -> int:
	var total := 0
	for type_id: String in force:
		total += int(force[type_id].count)
	return total


static func _raid_score(state: Dictionary, scn: Dictionary, gid: String, target: String, ctx: Dictionary, t: int, week: int) -> Dictionary:
	## Pure evaluation of one raid option. Returns {} when it is not possible.
	var g: Dictionary = state.groups[gid]
	var tr: Dictionary = ctx.traits
	var result := {"blocked": "", "utility": 0.0, "motive": "", "force": {}, "ratio": 0.0}
	var km := _distance_groups(state, gid, target)
	result["km"] = km
	if km > float(g.raid_range_km):
		result.blocked = "out_of_reach"
		return result
	if not Relations.knows(state.relations, gid, target):
		result.blocked = "unknown_target"
		return result
	# D-048/D-049: no attack without a recorded cause. Power alone is none;
	# real need is one, recorded with its occasion.
	var dispute := dispute_for(state, gid, target)
	var need := {}
	if dispute.is_empty():
		need = _need_occasion(state, gid, target, ctx)
		if need.is_empty():
			result.blocked = "no_cause"
			return result
		dispute = {"cause": "need", "id": "", "source": "need:" + str(need.occasion)}
	result["dispute"] = dispute
	result["need"] = need
	if not _expedition_of(state, gid).is_empty():
		result.blocked = "band_already_away"
		return result
	if t - int(g.last_raid_tick) < OWN_RAID_COOLDOWN:
		result.blocked = "own_recovery"
		return result
	var window: Dictionary = state.raid_windows.get(target, {})
	if not window.is_empty() and int(window.until) > t:
		result.blocked = "recovery_window"
		return result
	if state.targets.has(target) and int(state.targets[target].story_lock_until) >= t:
		result.blocked = "story_protected"
		return result
	var force: Dictionary = ctx.force
	result.force = force
	if _force_count(force) < MIN_RAID_WARRIORS:
		result.blocked = "too_few_warriors"
		return result
	var att := float(ctx.get("force_strength", troops_strength(scn, force))) * _morale_factor(float(g.morale))
	var def_est := 0.0
	var loot := 0.0
	if state.groups.has(target):
		var info: Dictionary = state.intel[gid].get(target, {})
		if info.is_empty():
			result.blocked = "no_intel"
			return result
		def_est = float(info.defence)
		loot = (float(info.food) * 0.2 * 0.04 * (1.0 + 3.0 * float(ctx.hunger)) + float(info.cattle) * 0.15 + float(info.wealth) * 0.2 * (1.0 + float(ctx.wealth_need))) / 60.0
	else:
		var target_info: Dictionary = state.targets[target]
		if not bool(target_info.raidable):
			result.blocked = "not_raidable"
			return result
		def_est = maxf(1.0, int(target_info.defence) * float(target_info.defender_strength))
		loot = 0.6
	var ratio := att / maxf(1.0, def_est)
	result.ratio = ratio
	# With a recorded cause a band accepts more risk than it would for loot.
	var success := 1.0 / (1.0 + exp(-3.0 * (ratio - 0.95)))
	var grievance := _rel(state, gid, target, "grievance") / 100.0
	var cache: Dictionary = ctx.cache
	var punitive := 0.5 if cache.punitive.has(gid + ">" + target) else 0.0
	# Renown comes from beating a worthy opponent, not from crushing the weak.
	var worth := clampf(def_est / maxf(1.0, att), 0.15, 1.0)
	# The cause carries the decision; need, feelings and renown only change its
	# urgency inside an existing dispute.
	var cause_drive := {"quest_dispute": 0.6, "natural_enemy": 0.45, "alliance_call": 0.45, "retaliation": 0.45, "conquest": 0.5, "need": 0.2 + 0.4 * float(need.get("level", 0.0))}
	var motives := {"cause": float(cause_drive.get(str(dispute.cause), 0.3)), "grievance": 0.6 * grievance + punitive,
		"need": 0.25 * clampf(loot, 0.0, 1.5) * float(ctx.hunger), "renown": (0.15 * float(tr.ambition) + 0.1 * float(tr.pride)) * worth}
	var drive := 0.0
	for key: String in _sorted(motives):
		drive += float(motives[key])
	var best := str(dispute.cause)
	var utility := float(tr.boldness) * drive * success - float(tr.caution) * (1.0 - success) - _rel(state, gid, target, "fear") / 100.0 * 0.4
	if not need.is_empty():
		# Need does not justify robbing friends; the faithful think twice.
		utility -= maxf(0.0, _rel(state, gid, target, "trust")) / 100.0 + float(g.traits.faith) * 0.2
	# Experience: raids that brought no plunder in the last year weigh on the next decision.
	var lessons := 0
	for memory: Dictionary in state.relations.edges.get(Relations.key(gid, target), {}).get("memories", []):
		if str(memory.kind) in ["raid_skirmish", "raid_repulsed"] and t - int(memory.tick) <= WEEKS:
			lessons += 1
	utility -= 0.15 * lessons
	if _has_pact(cache, gid, target, PEACE_KINDS + ["tribute"]):
		utility -= 0.4 + float(g.traits.faith) * 1.2
		result["breaks"] = true
	if cache.amicitia.has(target):
		utility -= _rel(state, gid, "rome", "fear") / 100.0 * 0.6
	if week >= 39:
		utility -= 0.1
	elif week >= 22 and week <= 31:
		utility -= 0.15
	result.utility = utility
	result.motive = best
	return result


static func _decide(state: Dictionary, scn: Dictionary, gid: String, t: int, week: int, cache: Dictionary) -> void:
	var g: Dictionary = state.groups[gid]
	var ctx := _context(state, scn, gid, t, week, cache)
	ctx["cache"] = cache
	ctx["force"] = _raid_force(state, scn, gid, float(ctx.traits.caution))
	ctx["force_strength"] = troops_strength(scn, ctx.force)
	var tr: Dictionary = ctx.traits
	var options := []
	options.append({"action": "idle", "utility": 0.15, "cause": "Gewöhnliche Arbeitswoche"})
	# Defend and retreat answer real threats.
	options.append({"action": "defend", "utility": float(ctx.threat) * (0.3 + float(tr.caution) * 0.6) + (0.15 if float(g.morale) < 35.0 else 0.0) + 0.05, "cause": "Bedrohung %.2f durch %s" % [float(ctx.threat), _name(state, str(ctx.threat_source))]})
	var away := _expedition_of(state, gid)
	if not ctx.incoming.is_empty():
		var ratio := troops_strength(scn, ctx.incoming.troops) / maxf(1.0, float(ctx.defence))
		if ratio > 1.2:
			options.append({"action": "retreat", "mode": "refuge", "utility": 0.6 + 0.4 * ratio * float(tr.caution), "cause": "Überlegener Kriegszug von %s gemeldet (%.2f)" % [_name(state, str(ctx.incoming.group)), ratio]})
		if not away.is_empty() and away.status == "outbound":
			options.append({"action": "retreat", "mode": "recall", "utility": 0.7 + 0.3 * ratio, "cause": "Heimat bedroht, eigener Zug unterwegs"})
	if _avg_damage(g) >= 70.0 and float(g.morale) < 25.0 and not g.sites.is_empty():
		options.append({"action": "retreat", "mode": "flee", "utility": 0.8 + float(tr.caution) * 0.4, "cause": "Siedlung zerstört, Moral %.0f" % float(g.morale)})
	_build_options(state, scn, gid, ctx, options)
	# Raids against known groups and raidable external targets in reach.
	var targets := []
	for other: String in Relations.known_by(state.relations, gid):
		if state.groups.has(other) and state.groups[other].status == "active" and state.groups[other].kind == "tribe":
			targets.append(other)
		elif state.targets.has(other) and bool(state.targets[other].raidable):
			targets.append(other)
	for other: String in targets:
		var score := _raid_score(state, scn, gid, other, ctx, t, week)
		if score.blocked == "":
			var motive := str(score.dispute.source) if str(score.dispute.cause) == "need" else str(score.motive)
			options.append({"action": "raid", "target": other, "utility": float(score.utility), "force": score.force, "motive": motive, "cause": "Anlass %s, Kräfteverhältnis %.2f" % [score.dispute.cause, float(score.ratio)]})
	_trade_options(state, scn, gid, ctx, options)
	_diplomacy_options(state, scn, gid, ctx, t, options)
	if int(g.stock.food) > float(ctx.weekly) * 25.0 and int(g.stock.wealth) >= 5 and ((week >= 30 and week <= 45) or float(g.morale) < 35.0) and t - int(g.history.get("last_feast", -100)) >= 20:
		var guest := ""
		var best_trust := 10.0
		for other: String in _active_tribes(state):
			if other != gid and Relations.knows(state.relations, gid, other) and _rel(state, gid, other, "trust") > best_trust and _rel(state, other, gid, "grievance") < 40.0:
				best_trust = _rel(state, gid, other, "trust")
				guest = other
		options.append({"action": "feast", "guest": guest, "utility": 0.22 + float(tr.pride) * 0.15 + (0.3 if float(g.morale) < 40.0 else 0.0) + (0.1 if guest != "" else 0.0), "cause": "Vorrat %.0f Wochen nach der Ernte" % float(ctx.food_weeks)})
	var best: Dictionary = {}
	var best_value := -1000.0
	for option: Dictionary in options:
		var value := float(option.utility) + 0.05 * _rand(state) + (0.05 if option.action == g.last_action else 0.0)
		if value > best_value:
			best_value = value
			best = option
	if best.action != "idle" and best_value < ACTION_THRESHOLD:
		best = options[0]
	g.last_action = best.action
	g.last_action_tick = t
	_execute(state, scn, gid, best, t)


static func _build_options(state: Dictionary, scn: Dictionary, gid: String, ctx: Dictionary, options: Array) -> void:
	var g: Dictionary = state.groups[gid]
	if not g.project.is_empty():
		return
	var tr: Dictionary = ctx.traits
	var year := year_of(state)
	var main: Dictionary = g.settlements[0]
	var wants := {
		"longhouse": float(ctx.housing_pressure) * 1.0,
		"granary": (0.7 if int(g.stock.food) > int(ctx.storage) * 0.85 else 0.0),
		"smithy": (0.6 if _building_count(g, "smithy") == 0 else (0.25 if _population(g) > 450 and _building_count(g, "smithy") < 2 else 0.0)),
		"palisade": float(ctx.threat) * (0.4 + float(tr.caution) * 0.6) * (1.0 if int(main.buildings.palisade) < 2 else 0.0),
		"hall": float(tr.pride) * 0.5 * (1.0 if _building_count(g, "hall") == 0 else 0.0),
		"watchpost": float(ctx.threat) * 0.5 * (1.0 if int(main.buildings.watchpost) == 0 else 0.0)}
	for b: String in _sorted(wants):
		var utility := float(wants[b])
		if utility <= 0.05 or not _content_available(scn, "buildings", b, year) or int(main.buildings.get(b, 0)) >= int(scn.buildings[b].max):
			continue
		var cost: Dictionary = scn.buildings[b].cost
		var affordable := true
		for good: String in cost:
			affordable = affordable and int(g.stock[good]) >= int(cost[good]) * 0.5
		if affordable:
			options.append({"action": "build", "kind": "build", "building": b, "settlement": 0, "utility": utility, "cause": "%s benötigt (%.2f)" % [scn.buildings[b].name, utility]})
	for i in g.settlements.size():
		var damage := float(g.settlements[i].damage)
		if damage >= 15.0:
			options.append({"action": "build", "kind": "repair", "settlement": i, "utility": damage / 100.0 * 1.2, "cause": "Schaden %.0f in %s" % [damage, g.settlements[i].name]})
	if not g.sites.is_empty() and g.settlements.size() < int(scn.economy.max_settlements):
		var cost: Dictionary = scn.projects.found_settlement.cost
		var need := float(ctx.housing_pressure) * 0.5 + float(ctx.land_pressure) * 0.6
		if int(g.stock.wood) >= int(cost.wood) and int(g.stock.food) >= int(cost.food) * 2 and float(ctx.threat) < 0.6 and _population(g) > 200 and need > 0.3:
			options.append({"action": "build", "kind": "found", "settlement": 0, "utility": need * (1.0 - float(ctx.threat)), "cause": "Land %.2f, Wohnraum %.2f" % [float(ctx.land_pressure), float(ctx.housing_pressure)]})


static func _surplus_and_need(state: Dictionary, scn: Dictionary, gid: String) -> Dictionary:
	var g: Dictionary = state.groups[gid]
	var surplus := {}
	var need := {}
	if g.kind == "market":
		for good: String in ["iron", "wealth", "blade"]:
			if int(g.stock[good]) > 0:
				surplus[good] = int(g.stock[good])
		need = {"cattle": 1.0, "wealth": 0.6, "horse": 0.5, "food": 0.3}
		return {"surplus": surplus, "need": need}
	var pop := _population(g)
	var weekly := maxf(1.0, pop)
	var herd := roundi(pop * float(scn.economy.herd_per_person))
	if float(g.stock.food) > weekly * 30.0:
		surplus["food"] = int(g.stock.food) - roundi(weekly * 30.0)
	# Trading communities keep a smaller reserve herd and sell the rest.
	var keep := herd * (1.2 - 0.3 * float(traits(state, gid).trade))
	if int(g.stock.cattle) > keep:
		surplus["cattle"] = int(g.stock.cattle) - roundi(keep)
	if int(g.stock.wealth) > 40:
		surplus["wealth"] = int(g.stock.wealth) - 30
	if int(g.stock.iron) > 40:
		surplus["iron"] = int(g.stock.iron) - 30
	if int(g.stock.horse) > 12:
		surplus["horse"] = int(g.stock.horse) - 8
	if float(g.stock.food) < weekly * 12.0:
		need["food"] = 1.0 - float(g.stock.food) / (weekly * 12.0)
	if _building_count(g, "smithy") > 0 and int(g.stock.iron) < 12:
		need["iron"] = 0.6
	if int(g.stock.cattle) < herd * 0.7:
		need["cattle"] = 0.5
	if int(g.stock.wealth) < 15:
		need["wealth"] = 0.4
	# Trading communities turn surplus into silver and ornaments even without
	# an emergency; the wish grows with their trade orientation.
	var trade := float(traits(state, gid).trade)
	var wealth_target := 30.0 + 60.0 * trade
	if float(g.stock.wealth) < wealth_target:
		need["wealth"] = maxf(float(need.get("wealth", 0.0)), 0.15 + 0.45 * trade * (1.0 - float(g.stock.wealth) / wealth_target))
	if int(g.stock.horse) < 4 and float(traits(state, gid).boldness) > 0.5:
		need["horse"] = 0.3
	return {"surplus": surplus, "need": need}


static func _route_detour(state: Dictionary, a: String, b: String) -> float:
	## A route passing a community hostile to the trader costs a detour (T13).
	var pa := _position(state, a)
	var pb := _position(state, b)
	for other: String in _active_tribes(state):
		if other == a or other == b:
			continue
		if Relations.stance(state.relations, other, a) != "hostile":
			continue
		var po := _position(state, other)
		var mid := (pa + pb) * 0.5
		if _haversine(po.x, po.y, mid.x, mid.y) <= 30.0:
			return 0.5
	return 0.0


static func _trade_options(state: Dictionary, scn: Dictionary, gid: String, ctx: Dictionary, options: Array) -> void:
	var tr: Dictionary = ctx.traits
	var cache: Dictionary = ctx.cache
	var mine := _trade_view(state, scn, cache, gid)
	if mine.surplus.is_empty() or mine.need.is_empty():
		return
	for other: String in Relations.known_by(state.relations, gid):
		if not state.groups.has(other) or state.groups[other].status != "active" or state.groups[other].kind == "band":
			continue
		if _distance_groups(state, gid, other) > 150.0 or _rel(state, other, gid, "trust") < -10.0 or _rel(state, other, gid, "grievance") >= 50.0:
			continue
		if str(state.groups[gid].people) == "Sueben" and state.groups[other].kind == "market" and not mine.surplus.has("cattle"):
			continue # BG 4,2: Suebian contact with traders was mainly to sell booty.
		var theirs := _trade_view(state, scn, cache, other)
		var deal := {}
		var best := 0.0
		for want: String in _sorted(mine.need):
			if not theirs.surplus.has(want):
				continue
			for give: String in _sorted(mine.surplus):
				if give == want or not theirs.need.has(give):
					continue
				var score := float(mine.need[want]) + float(theirs.need[give])
				if score > best:
					best = score
					deal = {"want": want, "give": give}
		if deal.is_empty():
			continue
		var pact := 0.1 if _has_pact(cache, gid, other, ["trade_pact"]) else 0.0
		options.append({"action": "trade", "partner": other, "want": deal.want, "give": deal.give, "utility": float(tr.trade) * best * 0.6 + pact, "cause": "Tausch %s gegen %s" % [deal.give, deal.want]})


static func _diplomacy_options(state: Dictionary, scn: Dictionary, gid: String, ctx: Dictionary, t: int, options: Array) -> void:
	var g: Dictionary = state.groups[gid]
	var tr: Dictionary = ctx.traits
	var cache: Dictionary = ctx.get("cache", {})
	var my_strength := float(cache.get("strength", {}).get(gid, strength(state, gid)))
	var tribes: Array = cache.tribes
	for other: String in tribes:
		if other == gid or not Relations.knows(state.relations, gid, other):
			continue
		var stance := Relations.stance(state.relations, gid, other)
		var their_stance := Relations.stance(state.relations, other, gid)
		var hostile := stance in ["hostile", "wary"] or their_stance in ["hostile", "wary"]
		var peace := _has_pact(cache, gid, other, ["truce", "alliance"])
		var recent := bool(cache.get("recent_raid", {}).get(gid + ">" + other, false))
		var trust := _rel(state, gid, other, "trust")
		if (hostile or recent) and not peace and not _recently(state, gid, other, ["refused_truce"], 8):
			var utility := float(tr.caution) * _rel(state, gid, other, "fear") / 100.0 + float(g.weariness) + float(ctx.hunger) * 0.4 - float(tr.pride) * _rel(state, gid, other, "grievance") / 100.0 * 0.5 + (0.15 if recent else 0.0) - (0.2 if _natural_enemies(state, gid, other) else 0.0)
			options.append({"action": "negotiate", "kind": "truce", "partner": other, "utility": utility, "cause": "Furcht %.0f, Erschöpfung %.2f" % [_rel(state, gid, other, "fear"), float(g.weariness)]})
		if trust >= 15.0 and not _has_pact(cache, gid, other, ["alliance"]) and not _recently(state, gid, other, ["refused_alliance"], 26):
			var shared := 0.0
			var enemy := ""
			for third: String in tribes:
				if third == gid or third == other:
					continue
				var level := (_rel(state, gid, third, "grievance") + _rel(state, gid, third, "fear")) / 200.0
				if level > shared:
					shared = level
					enemy = third
			if shared > 0.25:
				options.append({"action": "negotiate", "kind": "alliance", "partner": other, "enemy": enemy, "utility": shared * 0.8 * (1.0 - float(tr.pride) * 0.3) + 0.05, "cause": "Gemeinsame Gefahr durch %s" % _name(state, enemy)})
		var poor := int(state.intel[gid].get(other, {}).get("cattle", 0)) < 10 and int(state.intel[gid].get(other, {}).get("wealth", 0)) < 5
		if float(tr.pride) >= 0.5 and not poor and not _has_pact(cache, gid, other, ["tribute"] + PEACE_KINDS) and not _recently(state, gid, other, ["refused_tribute"], 26):
			var their_defence := float(state.intel[gid].get(other, {}).get("defence", 1000000.0))
			if my_strength / maxf(1.0, their_defence) >= 1.8:
				options.append({"action": "negotiate", "kind": "tribute", "partner": other, "utility": float(tr.pride) * 0.4 + float(ctx.wealth_need) * 0.3 + float(tr.ambition) * 0.2, "cause": "Überlegenheit %.2f" % (my_strength / maxf(1.0, their_defence))})
		if float(tr.trade) >= 0.5 and trust >= 20.0 and not _has_pact(cache, gid, other, ["trade_pact"]) and not _recently(state, gid, other, ["refused_trade_pact"], 26):
			options.append({"action": "negotiate", "kind": "trade_pact", "partner": other, "utility": float(tr.trade) * 0.45, "cause": "Vertrauen %.0f" % trust})
		if trust >= 30.0 and not _has_pact(cache, gid, other, ["guest_friendship"]) and not _recently(state, gid, other, ["refused_guest_friendship"], 26):
			options.append({"action": "negotiate", "kind": "guest_friendship", "partner": other, "utility": 0.25 + float(g.traits.faith) * 0.2, "cause": "Langes Vertrauen"})
		if t - int(g.history.get("last_gift", -100)) < 13:
			continue
		if int(g.stock.wealth) > 25 and _rel(state, gid, other, "fear") >= 40.0 and _rel(state, other, gid, "grievance") >= 20.0:
			options.append({"action": "gift", "partner": other, "utility": float(tr.caution) * _rel(state, gid, other, "fear") / 100.0 * 0.7, "cause": "Beschwichtigung aus Furcht"})
		elif int(g.stock.wealth) > 40 and trust >= 10.0 and not _has_pact(cache, gid, other, ["alliance"]) and float(cache.get("strength", {}).get(other, 0.0)) > my_strength:
			options.append({"action": "gift", "partner": other, "utility": 0.2 + float(g.traits.faith) * 0.1, "cause": "Werben um einen starken Nachbarn"})


static func _execute(state: Dictionary, scn: Dictionary, gid: String, option: Dictionary, t: int) -> void:
	var g: Dictionary = state.groups[gid]
	match str(option.action):
		"idle":
			return
		"defend":
			g.prepared_until = t + 3
			for type_id: String in _sorted(g.troops):
				g.troops[type_id].xp = _q(minf(40.0, float(g.troops[type_id].xp) + 0.6))
			g.morale = _q(clampf(float(g.morale) + 2.0, 0.0, 100.0))
		"retreat":
			match str(option.mode):
				"refuge":
					g.refuge_until = int(option.get("until", t + 2))
					_event(state, "refuge", [gid], "%s bringt Menschen und Vieh in die Wälder." % g.name, str(option.cause), [gid])
				"recall":
					var e := _expedition_of(state, gid)
					if not e.is_empty() and e.status == "outbound":
						e.status = "returning"
						e.return_tick = t + 1
						_event(state, "war_band_recalled", [gid, str(e.target)], "%s ruft den Kriegszug zurück." % g.name, str(option.cause), [gid])
				"flee":
					var site: Dictionary = g.sites.pop_front()
					var s: Dictionary = g.settlements[0]
					var old_name := str(s.name)
					s.name = str(site.name)
					s.lat = float(site.lat)
					s.lon = float(site.lon)
					s.fields = int(site.fields)
					s.ore = bool(site.ore)
					s.damage = 50.0
					for b: String in s.buildings:
						s.buildings[b] = floori(int(s.buildings[b]) / 2.0)
					_event(state, "fled", [gid], "%s verlässt das zerstörte %s und baut in %s neu auf." % [g.name, old_name, s.name], str(option.cause), [gid], true)
		"build":
			_start_project(state, scn, gid, option, t)
		"raid":
			_launch_raid(state, scn, gid, str(option.target), option.force, str(option.motive), str(option.cause), t, false, "raid")
		"trade":
			_trade(state, scn, gid, str(option.partner), str(option.give), str(option.want), t)
		"negotiate":
			_propose(state, scn, gid, str(option.partner), str(option.kind), t, str(option.get("enemy", "")))
		"gift":
			var amount := mini(int(g.stock.wealth) - 15, 6 + roundi(float(g.traits.pride) * 4.0))
			if amount > 0:
				var partner := str(option.partner)
				_transfer(state, gid, partner, "wealth", amount, "gift")
				g.history.gifts = int(g.history.gifts) + 1
				g.history["last_gift"] = t
				state.stats.gifts = int(state.stats.gifts) + 1
				var event := _event(state, "gift", [gid, partner], "%s schickt %s Geschenke (%d Wertgüter)." % [g.name, _name(state, partner), amount], str(option.cause), [gid, partner])
				_affect(state, partner, gid, event, "gift_received", {"trust": 3.0 + amount * 0.8, "obligation": amount * 1.5, "grievance": -amount * 1.0})
				_prestige(state, gid, 1.0)
				_observe(state, gid, partner)
				_observe(state, partner, gid)
		"feast":
			var guests := 40 if str(option.guest) != "" else 0
			var food := mini(int(g.stock.food), roundi(_population(g) * 0.5) + guests)
			_tx(state, gid, "food", food, "consume", "feast")
			_tx(state, gid, "wealth", mini(3, int(g.stock.wealth)), "consume", "feast_gifts")
			g.morale = _q(clampf(float(g.morale) + 12.0, 0.0, 100.0))
			g.history.feasts = int(g.history.feasts) + 1
			g.history["last_feast"] = t
			state.stats.feasts = int(state.stats.feasts) + 1
			_prestige(state, gid, 3.0)
			var guest := str(option.guest)
			var event := _event(state, "feast", [gid] + ([guest] if guest != "" else []), "%s lädt zum Fest%s." % [g.name, (" mit Gästen aus " + _name(state, guest)) if guest != "" else ""], str(option.cause), [gid] + ([guest] if guest != "" else []))
			if guest != "":
				_affect(state, guest, gid, event, "feast_guest", {"trust": 6.0, "obligation": 4.0})
				_affect(state, gid, guest, event, "feast_host", {"trust": 3.0})
				_observe(state, gid, guest)
				_observe(state, guest, gid)


static func _start_project(state: Dictionary, scn: Dictionary, gid: String, option: Dictionary, t: int) -> void:
	var g: Dictionary = state.groups[gid]
	var kind := str(option.kind)
	var cost := {}
	var labour := 0.0
	var name := ""
	var repairs := 0.0
	match kind:
		"build":
			var b: Dictionary = scn.buildings[option.building]
			cost = (b.cost as Dictionary).duplicate()
			labour = float(b.labour)
			name = str(b.name)
		"repair":
			repairs = float(g.settlements[int(option.settlement)].damage)
			cost = {"wood": ceili(repairs * float(scn.projects.repair.wood_per_damage))}
			labour = repairs * float(scn.projects.repair.labour_per_damage)
			name = str(scn.projects.repair.name)
		"found":
			cost = (scn.projects.found_settlement.cost as Dictionary).duplicate()
			labour = float(scn.projects.found_settlement.labour)
			name = "%s (%s)" % [scn.projects.found_settlement.name, g.sites[0].name]
	var total := {}
	for good: String in cost:
		total[good] = int(cost[good])
	g.project = {"kind": kind, "building": str(option.get("building", "")), "settlement": int(option.settlement), "name": name,
		"labour_total": _q(labour), "labour_left": _q(labour), "cost_total": total, "cost_left": total.duplicate(), "started": t, "progress_tick": t, "repairs": _q(repairs)}
	_event(state, "project_started", [gid], "%s beginnt: %s." % [g.name, name], str(option.cause), [gid])


static func _launch_raid(state: Dictionary, scn: Dictionary, gid: String, target: String, force: Dictionary, motive: String, cause: String, t: int, protected: bool, kind: String) -> Dictionary:
	var g: Dictionary = state.groups[gid]
	if state.expeditions.size() >= MAX_EXPEDITIONS:
		return {}
	var dispute := dispute_for(state, gid, target)
	if dispute.is_empty() and motive.begins_with("need:"):
		# D-049: the need and its occasion become the recorded cause.
		dispute = _open(state, gid, target, "need", motive, "Not", 4)
	if dispute.is_empty():
		return {} # D-048: no war band leaves without a recorded cause.
	var troops := {}
	var warriors := 0
	var id := _next(state, "x")
	for type_id: String in _sorted(force):
		var n := mini(int(force[type_id].count), int(g.troops.get(type_id, {}).get("count", 0)))
		if n <= 0:
			continue
		troops[type_id] = _split(scn, type_id, g.troops[type_id], n)
		warriors += n
		if bool(scn.troop_types[type_id].get("persons", false)):
			var going := retainers(state, gid, "home")
			for i in mini(n, going.size()):
				state.persons[going[i]].with = id
	if warriors == 0:
		return {}
	var km := _distance_groups(state, gid, target)
	var travel := travel_ticks(km)
	if kind == "story_raid":
		travel = 0
	_war_council(state, gid, t, "Kriegszug gegen " + _name(state, target))
	var provisions := mini(int(g.stock.food), warriors * travel * 4)
	_tx(state, gid, "food", provisions, "consume", "war_band_provisions")
	var conflict := {"cause": str(dispute.cause), "dispute": str(dispute.id), "source": str(dispute.source)}
	var expedition := {"id": id, "group": gid, "target": target, "target_kind": "group" if state.groups.has(target) else "external", "kind": kind,
		"troops": troops, "depart_tick": t, "arrive_tick": t + travel, "return_tick": -1, "status": "outbound", "cargo": {}, "motive": str(dispute.cause), "protected": protected, "outcome": "", "cause": conflict}
	if kind == "story_raid":
		expedition.status = "arrived"
	state.expeditions.append(expedition)
	g.last_raid_tick = t
	g.history["raids_launched"] = int(g.history.get("raids_launched", 0)) + 1
	var known := [gid]
	if state.groups.has(target) and int(state.groups[target].settlements[0].buildings.get("watchpost", 0)) > 0:
		known.append(target)
	_event(state, "war_band_departs", [gid, target], "%s zieht mit %d Kriegern gegen %s." % [g.name, warriors, _name(state, target)], "%s · Anlass %s" % [cause, str(dispute.cause)], known, false, "simulation", conflict)
	return expedition


## Price and access follow the partner's view of the trader: kept promises
## make goods cheaper, broken ones dearer or refused (handbook p. 11).
static func trade_terms(state: Dictionary, gid: String, partner: String) -> Dictionary:
	var trust := _rel(state, partner, gid, "trust")
	var access := trust >= -10.0 and _rel(state, partner, gid, "grievance") < 50.0
	var markup := 1.0 + maxf(0.0, 20.0 - trust) / 100.0 - (0.1 if not _active_agreement(state, gid, partner, ["trade_pact"]).is_empty() else 0.0) + _route_detour(state, gid, partner)
	return {"access": access, "markup": _q(markup), "detour": _route_detour(state, gid, partner) > 0.0}


static func _trade(state: Dictionary, scn: Dictionary, gid: String, partner: String, give: String, want: String, t: int) -> void:
	var g: Dictionary = state.groups[gid]
	var h: Dictionary = state.groups[partner]
	var theirs := _surplus_and_need(state, scn, partner)
	var mine := _surplus_and_need(state, scn, gid)
	if not theirs.surplus.has(want) or not mine.surplus.has(give) or _rel(state, partner, gid, "trust") < -10.0:
		_event(state, "trade_refused", [gid, partner], "%s findet bei %s keinen Handel." % [g.name, _name(state, partner)], "Kein Bedarf oder kein Zugang", [gid, partner])
		return
	var value_give := float(scn.goods[give].value)
	var value_want := float(scn.goods[want].value)
	var labour := roundi(_population(g) * float(scn.economy.adult_share)) - _warriors_home(g)
	var capacity := 8.0 + maxf(0.0, labour) * 0.06
	var markup := float(trade_terms(state, gid, partner).markup)
	var value := minf(capacity, minf(int(mine.surplus[give]) * value_give / markup, int(theirs.surplus[want]) * value_want))
	var receive := floori(value / value_want)
	var pay := ceili(receive * value_want * markup / value_give)
	if receive <= 0 or pay <= 0 or pay > int(g.stock[give]) or receive > int(h.stock[want]):
		return
	_transfer(state, gid, partner, give, pay, "trade")
	_transfer(state, partner, gid, want, receive, "trade")
	g.history.trades = int(g.history.trades) + 1
	state.stats.trades = int(state.stats.trades) + 1
	var event := _event(state, "trade", [gid, partner], "%s tauscht %d %s gegen %d %s mit %s." % [g.name, pay, scn.goods[give].name, receive, scn.goods[want].name, _name(state, partner)], "Aufschlag %.2f" % markup, [gid, partner])
	var bonus := 3.0 if markup < 1.0 else 2.0
	_affect(state, gid, partner, event, "trade", {"trust": bonus, "respect": 1.0})
	_affect(state, partner, gid, event, "trade", {"trust": bonus})
	_prestige(state, gid, 0.5)
	_drift(g, "trade", 0.002)
	_observe(state, gid, partner)
	_observe(state, partner, gid)


static func _propose(state: Dictionary, scn: Dictionary, gid: String, partner: String, kind: String, t: int, enemy: String) -> void:
	var g: Dictionary = state.groups[gid]
	var h: Dictionary = state.groups[partner]
	# Both sides may reach out in the same week; one agreement is enough.
	if not _active_agreement(state, gid, partner, ["truce", "alliance"] if kind == "truce" else [kind]).is_empty():
		return
	var htr := traits(state, partner)
	var accept := false
	match kind:
		"truce":
			var peace := float(htr.caution) * _rel(state, partner, gid, "fear") / 100.0 + float(h.weariness) + clampf((16.0 - float(h.stock.food) / maxf(1.0, _population(h))) / 16.0, 0.0, 1.0) * 0.4 - float(htr.pride) * _rel(state, partner, gid, "grievance") / 100.0 * 0.5 + 0.1
			# Natural enemies distrust each other's truces (D-048 natural_enemy).
			if _natural_enemies(state, gid, partner):
				peace -= 0.35
			accept = peace > 0.0
		"alliance":
			# The partner joins against the named enemy or against its own worst threat.
			var own := 0.0
			for third: String in _active_tribes(state):
				if third != gid and third != partner:
					own = maxf(own, _rel(state, partner, third, "grievance") + _rel(state, partner, third, "fear"))
			accept = _rel(state, partner, gid, "trust") >= 10.0 and enemy != "" and ((_rel(state, partner, enemy, "grievance") + _rel(state, partner, enemy, "fear")) >= 30.0 or own >= 40.0)
		"tribute":
			var ratio := strength(state, gid) / maxf(1.0, defence(state, partner))
			# Nobody agrees to a tribute it cannot pay twice from its own stock.
			var payable := int(h.stock.cattle) >= 2 * maxi(2, roundi(int(h.stock.cattle) * 0.03)) and int(h.stock.wealth) >= 2 * maxi(1, roundi(int(h.stock.wealth) * 0.08))
			accept = payable and (_rel(state, partner, gid, "fear") >= 30.0 or (ratio >= 2.5 and float(htr.pride) < 0.7))
		"trade_pact":
			accept = float(htr.trade) >= 0.3 and _rel(state, partner, gid, "trust") >= 10.0
		"guest_friendship":
			accept = _rel(state, partner, gid, "trust") >= 25.0
	var cause := "Vorschlag %s" % kind
	if accept:
		var duration: Variant = {"truce": 26, "alliance": 52, "tribute": 52, "trade_pact": 52, "guest_friendship": 156}[kind]
		var terms := {}
		var every := 0
		var a := gid
		var b := partner
		if kind == "tribute":
			a = partner
			b = gid
			every = 13
			terms = {"cattle": maxi(2, roundi(int(h.stock.cattle) * 0.03)), "wealth": maxi(1, roundi(int(h.stock.wealth) * 0.08))}
		var item := _make_agreement(state, kind, a, b, t, int(duration), terms, every, "simulation")
		var event := _event(state, "agreement_made", [gid, partner], "%s und %s schließen %s bis Woche %d." % [g.name, h.name, kind, int(item.end)], cause, [gid, partner], true)
		if kind in PEACE_KINDS or kind == "tribute":
			# A war band already on the way between the new partners turns back.
			for e: Dictionary in state.expeditions:
				if e.status == "outbound" and ((e.group == gid and e.target == partner) or (e.group == partner and e.target == gid)):
					e.status = "returning"
					e.return_tick = t + 1
					e.outcome = "recalled_by_agreement"
					_event(state, "war_band_recalled", [str(e.group), str(e.target)], "%s ruft den Kriegszug nach der Einigung zurück." % _name(state, str(e.group)), "Vereinbarung %s" % kind, [str(e.group), str(e.target)])
		var warmth: Variant = {"truce": 2.0, "alliance": 6.0, "tribute": 0.0, "trade_pact": 4.0, "guest_friendship": 6.0}[kind]
		if kind == "tribute":
			_affect(state, partner, gid, event, "tribute_imposed", {"grievance": 12.0, "fear": 8.0})
			_prestige(state, gid, 4.0)
			for record: Dictionary in state.disputes:
				if record.status == "open" and record.cause == "conquest" and record.a == gid and record.b == partner:
					record.status = "closed"
					record.note = str(record.note) + " · beendet: Tribut vereinbart"
		else:
			_affect(state, gid, partner, event, "agreement_made", {"trust": warmth})
			_affect(state, partner, gid, event, "agreement_made", {"trust": warmth})
		_observe(state, gid, partner)
		_observe(state, partner, gid)
	else:
		var event := _event(state, "proposal_refused", [gid, partner], "%s lehnt %s mit %s ab." % [h.name, kind, g.name], cause, [gid, partner])
		if kind == "tribute":
			_affect(state, gid, partner, event, "refused_tribute", {"grievance": 12.0})
			_affect(state, partner, gid, event, "demand_rejected", {"grievance": 8.0, "trust": -5.0})
		else:
			_affect(state, gid, partner, event, "refused_" + kind, {"trust": -1.0})


# ---------------------------------------------------------------- war bands

static func _expeditions(state: Dictionary, scn: Dictionary, t: int) -> void:
	for e: Dictionary in state.expeditions.duplicate():
		if e.status == "outbound" and t >= int(e.arrive_tick):
			if e.target_kind == "group":
				_battle(state, scn, e, t)
			else:
				e.status = "arrived"
				e["await_until"] = t + EXTERNAL_AWAIT_TICKS
		elif e.status == "arrived" and not e.protected and e.target_kind == "external" and t >= int(e.get("await_until", t)):
			# No local result arrived: the band finds no opening and turns back.
			e.status = "returning"
			e.outcome = "no_contact"
			e.return_tick = t + travel_ticks(_distance_groups(state, str(e.group), str(e.target)))
			_event(state, "war_band_turns_back", [str(e.group), str(e.target)], "%s kehrt ohne Zusammenstoß von %s zurück." % [_name(state, str(e.group)), _name(state, str(e.target))], "Kein gemeldetes Ergebnis", [str(e.group)])
		if e.status == "returning" and t >= int(e.return_tick):
			_return_home(state, scn, e, t)


static func _return_home(state: Dictionary, scn: Dictionary, e: Dictionary, t: int) -> void:
	var gid := str(e.group)
	var g: Dictionary = state.groups[gid]
	for type_id: String in _sorted(e.troops):
		_merge(g.troops, type_id, e.troops[type_id])
	for pid: String in retainers(state, gid, str(e.id)):
		state.persons[pid].with = "home"
	for good: String in _sorted(e.cargo):
		_move(state, gid, good, int(e.cargo[good]), "cargo", "stock", "war_band_unloads", e)
	state.expeditions.erase(e)


static func _kill(state: Dictionary, scn: Dictionary, gid: String, troops: Dictionary, fraction: float, settlement: int, location: String, cause: String) -> Dictionary:
	## Removes fallen soldiers; their gear stays on the held account until the
	## caller books it as loot or loss. Fallen retainers stay dead.
	var fallen := {"count": 0, "gear": {}, "retainers": []}
	for type_id: String in _sorted(troops):
		var stack: Dictionary = troops[type_id]
		var tier := int(scn.troop_types[type_id].tier)
		var n := mini(int(stack.count), roundi(int(stack.count) * fraction * float(VULNERABILITY.get(tier, 1.0))))
		if n <= 0:
			continue
		var part := _split(scn, type_id, stack, n)
		fallen.count = int(fallen.count) + n
		for good: String in part.gear:
			fallen.gear[good] = int(fallen.gear.get(good, 0)) + int(part.gear[good])
		if bool(scn.troop_types[type_id].get("persons", false)):
			fallen.retainers.append_array(_retainers_leave(state, gid, location, n, "dead", "retainer", cause))
	var g: Dictionary = state.groups[gid]
	var where := clampi(settlement, 0, g.settlements.size() - 1)
	_people(state, gid, where, mini(int(fallen.count), int(g.settlements[where].population)), "destroy", "killed_in_battle")
	return fallen


## Survivors of the retinue share the memory of the fight and of the fallen.
static func _retinue_memory(state: Dictionary, gid: String, location: String, enemy: String, event: String, outcome: String) -> void:
	var chief := str(state.groups[gid].leader)
	var won := outcome in ["plunder", "repulsed_defended"]
	for pid: String in retainers(state, gid, location):
		state.persons[pid].deeds = int(state.persons[pid].get("deeds", 0)) + 1
		Relations.apply(state.relations, pid, enemy, event, int(state.tick), "fought", {"grievance": 6.0, "respect": 3.0 if won else -2.0})
		if state.persons.has(chief) and chief != pid:
			Relations.apply(state.relations, pid, chief, event, int(state.tick), "fought_together", {"loyalty": 3.0 if won else -1.0})


static func _strip(state: Dictionary, loser: String, fallen: Dictionary, winner: String, share: float, to_account: String, expedition: Dictionary) -> void:
	for good: String in _sorted(fallen.gear):
		var total := int(fallen.gear[good])
		var taken := floori(total * share) if winner != "" else 0
		if taken > 0:
			var tx := _next(state, "t")
			_book(state, tx, loser, good, taken, "transfer_out", "battlefield_loot", winner, "held")
			_book(state, tx, winner, good, taken, "transfer_in", "battlefield_loot", loser, to_account, expedition)
		_book(state, _next(state, "t"), loser, good, total - taken, "destroy", "battle_loss", winner, "held")


static func _battle(state: Dictionary, scn: Dictionary, e: Dictionary, t: int) -> void:
	var gid := str(e.group)
	var hid := str(e.target)
	var g: Dictionary = state.groups[gid]
	var h: Dictionary = state.groups[hid]
	var travel := travel_ticks(_distance_groups(state, gid, hid))
	e.return_tick = t + travel
	e.status = "returning"
	if h.status != "active" or _population(h) <= 0:
		e.outcome = "target_gone"
		_event(state, "war_band_turns_back", [gid, hid], "%s findet die Höfe von %s verlassen." % [g.name, h.name], "Ziel verlassen", [gid])
		return
	var window: Dictionary = state.raid_windows.get(hid, {})
	if not window.is_empty() and int(window.until) > t:
		# Someone else struck first; there is nothing left worth the fight.
		e.outcome = "target_recovering"
		_event(state, "war_band_turns_back", [gid, hid], "%s findet %s bereits ausgeplündert und kehrt um." % [g.name, h.name], "Erholungsfrist nach %s" % _name(state, str(window.by)), [gid, hid])
		return
	_war_council(state, hid, t, "Angriff durch " + g.name)
	var htr := traits(state, hid)
	var tr := traits(state, gid)
	var att := troops_strength(scn, e.troops) * _morale_factor(float(g.morale))
	var warned := hid in _event_knowers(state, "war_band_departs", gid, int(e.depart_tick))
	var def := defence(state, hid, warned)
	var helpers := []
	for item: Dictionary in state.agreements:
		if item.status != "active" or item.kind != "alliance" or not (item.a == hid or item.b == hid):
			continue
		var ally := str(item.b) if item.a == hid else str(item.a)
		if ally == gid or not state.groups.has(ally) or state.groups[ally].status != "active":
			continue
		if _distance_groups(state, ally, hid) <= 60.0 and _rel(state, ally, hid, "trust") >= 10.0:
			def += 0.3 * strength(state, ally)
			helpers.append(ally)
		else:
			var failed := _event(state, "ally_failed", [hid, ally], "%s bleibt aus, als %s angegriffen wird." % [_name(state, ally), h.name], "Bündnispflicht nicht erfüllt", [hid, ally], true)
			_affect(state, hid, ally, failed, "ally_failed", {"trust": -12.0, "grievance": 8.0})
	var refuge := int(h.refuge_until) >= t
	if refuge:
		def *= 0.3
	var ratio := (att * (0.85 + 0.3 * _rand(state))) / maxf(1.0, def * (0.85 + 0.3 * _rand(state)))
	var outcome := "plunder" if ratio >= 1.3 else ("skirmish" if ratio >= 0.85 else "repulsed")
	e.outcome = outcome
	state.stats.raids = int(state.stats.raids) + 1
	var stat_key: Variant = {"plunder": "plunders", "skirmish": "skirmishes", "repulsed": "repulsed"}[outcome]
	state.stats[stat_key] = int(state.stats[stat_key]) + 1
	var base: Variant = {"plunder": [0.04, 0.12], "skirmish": [0.07, 0.06], "repulsed": [0.18, 0.04]}[outcome]
	var att_loss := float(base[0]) * clampf(1.3 / maxf(0.1, ratio), 0.6, 1.6)
	var def_loss := float(base[1]) * clampf(ratio, 0.6, 1.6) * (0.4 if refuge else 1.0)
	var target_settlement := 0
	var fallen_att := _kill(state, scn, gid, e.troops, att_loss, 0, str(e.id), "fell raiding " + hid)
	var fallen_def := _kill(state, scn, hid, h.troops, def_loss, target_settlement, "home", "fell defending against " + gid)
	if outcome == "plunder":
		_strip(state, hid, fallen_def, gid, 0.4, "cargo", e)
		_strip(state, gid, fallen_att, "", 0.0, "stock", {})
	elif outcome == "repulsed":
		_strip(state, gid, fallen_att, hid, 0.4, "stock", {})
		_strip(state, hid, fallen_def, "", 0.0, "stock", {})
	else:
		_strip(state, gid, fallen_att, "", 0.0, "stock", {})
		_strip(state, hid, fallen_def, "", 0.0, "stock", {})
	var s: Dictionary = h.settlements[target_settlement]
	var loot := {}
	if outcome == "plunder":
		var share := clampf(0.12 + 0.1 * (ratio - 1.3), 0.12, 0.35) * (0.4 if refuge else 1.0)
		var carriers := _force_count(e.troops)
		var settlement_share := float(s.population) / maxf(1.0, _population(h))
		loot = {"food": mini(carriers * 30, floori(int(h.stock.food) * share * settlement_share)), "cattle": mini(carriers * 3, floori(int(h.stock.cattle) * share * settlement_share)),
			"wealth": floori(int(h.stock.wealth) * share), "horse": floori(int(h.stock.horse) * share * 0.5), "iron": floori(int(h.stock.iron) * share * 0.5)}
		for good: String in _sorted(loot):
			_transfer(state, hid, gid, good, int(loot[good]), "plunder", "stock", "cargo", {}, e)
		var damage := (15.0 + 10.0 * (ratio - 1.3)) * (1.3 if refuge else 1.0) * (1.0 - 0.2 * int(s.buildings.get("palisade", 0)))
		s.damage = _q(clampf(float(s.damage) + clampf(damage, 5.0, 40.0), 0.0, 100.0))
		_people(state, hid, target_settlement, mini(roundi(int(s.population) * (0.0 if refuge else 0.005)), int(s.population)), "destroy", "killed_in_raid")
	elif outcome == "skirmish":
		loot = {"cattle": floori(int(h.stock.cattle) * 0.04)}
		_transfer(state, hid, gid, "cattle", int(loot.cattle), "cattle_raid", "stock", "cargo", {}, e)
	var xp: Variant = {"plunder": [4.0, 2.0], "skirmish": [2.5, 2.5], "repulsed": [1.5, 3.0]}[outcome]
	for type_id: String in e.troops:
		e.troops[type_id].xp = _q(minf(40.0, float(e.troops[type_id].xp) + float(xp[0])))
	for type_id: String in h.troops:
		h.troops[type_id].xp = _q(minf(40.0, float(h.troops[type_id].xp) + float(xp[1])))
	var morale: Variant = {"plunder": [8.0, -12.0], "skirmish": [2.0, -2.0], "repulsed": [-10.0, 8.0]}[outcome]
	g.morale = _q(clampf(float(g.morale) + float(morale[0]), 0.0, 100.0))
	h.morale = _q(clampf(float(h.morale) + float(morale[1]), 0.0, 100.0))
	var prestige: Variant = {"plunder": [6.0, -6.0], "skirmish": [1.0, 0.0], "repulsed": [-6.0, 5.0]}[outcome]
	_prestige(state, gid, float(prestige[0]))
	_prestige(state, hid, float(prestige[1]))
	g.weariness = _q(float(g.weariness) + float(fallen_att.count) / maxf(1.0, _warriors_home(g) + _warriors_away(state, gid)))
	h.weariness = _q(float(h.weariness) + float(fallen_def.count) / maxf(1.0, _warriors_home(h)))
	if outcome == "plunder":
		g.history.raids_won = int(g.history.raids_won) + 1
		_drift(g, "boldness", 0.01)
		_drift(h, "caution", 0.01)
	elif outcome == "repulsed":
		g.history.raids_lost = int(g.history.raids_lost) + 1
		_drift(g, "caution", 0.01)
	h.history.raided = int(h.history.raided) + 1
	var labels := {"plunder": "plündert", "skirmish": "liefert sich ein Gefecht mit", "repulsed": "wird abgewiesen von"}
	var text := "%s %s %s. Gefallene: %d Angreifer, %d Verteidiger%s." % [g.name, labels[outcome], h.name, int(fallen_att.count), int(fallen_def.count), (", Beute " + JSON.stringify(loot)) if not loot.is_empty() else ""]
	var event := _event(state, "raid", [gid, hid], text, "Anlass %s, Verhältnis %.2f%s%s" % [e.cause.cause, ratio, ", gewarnt" if warned else "", ", Zuflucht" if refuge else ""], [gid, hid] + helpers, true, "simulation", e.cause)
	_conflict_followups(state, gid, hid, event, outcome, ratio, helpers)
	var pride_h := float(htr.pride)
	var caution_h := float(htr.caution)
	var victim: Variant = {"plunder": {"grievance": 30.0 * (0.6 + pride_h * 0.8), "trust": -25.0, "fear": 15.0 * minf(2.0, ratio / 1.3) * (0.5 + caution_h), "respect": 5.0},
		"skirmish": {"grievance": 15.0 * (0.6 + pride_h * 0.8), "trust": -15.0, "fear": 5.0 * (0.5 + caution_h)},
		"repulsed": {"grievance": 10.0 * (0.6 + pride_h * 0.8), "trust": -10.0, "respect": -5.0}}[outcome]
	_affect(state, hid, gid, event, "raided", victim)
	var raider: Variant = {"plunder": {"fear": -5.0, "respect": -5.0}, "skirmish": {"grievance": 5.0},
		"repulsed": {"grievance": 12.0 * (0.5 + float(tr.pride)), "fear": 10.0 * (0.5 + float(tr.caution)), "respect": 8.0}}[outcome]
	_affect(state, gid, hid, event, "raid_" + outcome, raider)
	_retinue_memory(state, gid, str(e.id), hid, event, outcome)
	_retinue_memory(state, hid, "home", gid, event, "repulsed_defended" if outcome == "repulsed" else outcome + "_defended")
	for ally: String in helpers:
		_affect(state, hid, ally, event, "ally_helped", {"trust": 8.0, "obligation": 10.0})
		_affect(state, ally, gid, event, "fought_against", {"grievance": 8.0})
	var pact := _active_agreement(state, gid, hid, PEACE_KINDS)
	if pact.is_empty():
		for item: Dictionary in state.agreements:
			if item.status == "active" and item.kind == "tribute" and item.b == gid and item.a == hid:
				pact = item
	if not pact.is_empty():
		_break_agreement(state, pact, gid, t, "Überfall trotz Vereinbarung")
	var recovery := clampi(6 + roundi(float(s.damage) / 5.0) + roundi(float(fallen_def.count) / maxf(1.0, _warriors_home(h) + float(fallen_def.count)) * 20.0), 6, 26)
	state.raid_windows[hid] = {"until": t + recovery, "reason": "recovery_after_" + outcome, "by": gid}
	_observe(state, gid, hid)
	_observe(state, hid, gid)


## D-048 chains: the victim may answer (retaliation), its allies are called
## (alliance_call), and a clear victory can turn into a campaign (conquest).
static func _conflict_followups(state: Dictionary, attacker: String, victim: String, event: String, outcome: String, ratio: float, helpers: Array) -> void:
	if state.groups.has(victim) and state.groups[victim].kind == "tribe":
		_open(state, victim, attacker, "retaliation", "event:" + event, "Antwort auf den Überfall", 52)
	for item: Dictionary in state.agreements:
		if item.status == "active" and item.kind == "alliance" and (item.a == victim or item.b == victim):
			var ally := str(item.b) if item.a == victim else str(item.a)
			if ally != attacker and state.groups.has(ally):
				_open(state, ally, attacker, "alliance_call", "event:" + event, "Bündnispflicht gegenüber " + _name(state, victim), 26)
	for ally: String in helpers:
		_open(state, attacker, ally, "retaliation", "event:" + event, "Gegner im Kampf um " + _name(state, victim), 26)
	if outcome == "plunder" and ratio >= 2.0 and state.groups.has(victim):
		_open(state, attacker, victim, "conquest", "event:" + event, "Feldzug zur Unterwerfung", 52)


static func _event_knowers(state: Dictionary, kind: String, actor: String, tick: int) -> Array:
	for ev: Dictionary in state.events:
		if ev.kind == kind and int(ev.tick) == tick and ev.actors.size() > 0 and str(ev.actors[0]) == actor:
			return ev.known_by
	return []


static func _name(state: Dictionary, actor: String) -> String:
	if state.groups.has(actor):
		return str(state.groups[actor].name)
	if state.targets.has(actor):
		return str(state.targets[actor].name)
	if state.persons.has(actor):
		return str(state.persons[actor].name)
	return actor if actor != "" else "niemanden"


# ---------------------------------------------------------------- world clock

## Calendar days since the tribal epoch, read from the one world clock
## (WorldModel `calendar`, D-045): tick t is the week starting at
## epoch_jdn + 7 t. Worlds without a clock (unit fixtures) use the older
## derivation from the village, jump and season counters.
static func world_calendar_day(world: Dictionary) -> int:
	var clock: Variant = world.get("calendar", {}).get("clock") if world.get("calendar") is Dictionary else null
	if clock is Dictionary and WorldCalendar.validate_clock(clock) and world.has("tribes"):
		return maxi(0, int(clock.jdn) - epoch_jdn(world.tribes, int(world.calendar.get("origin_year", 100))))
	var economy_days := int(world.get("village", {}).get("economy", {}).get("day", 0))
	var years := int(world.get("progress", {}).get("years_elapsed", 0))
	var seasons := int(world.get("strategy", {}).get("turn", 0)) % 4
	var extra := int(world.get("tribes", {}).get("extra_days", 0))
	return economy_days + years * WEEKS * TICK_DAYS + seasons * 13 * TICK_DAYS + extra


## First day of tick 0: 1 March of the scenario year (the scenario's weeks and
## seasons start in March); without a roster, spring of the world's origin year.
static func epoch_jdn(state: Dictionary, origin_year: int = 100) -> int:
	var scn := scenario(str(state.get("scenario", NO_SCENARIO)))
	var year := int(scn.era.start_year) if not scn.is_empty() else origin_year
	return WorldCalendar.season_start(year, 0)


## The world date of a tick (start of its week) on the shared calendar.
static func tick_jdn(state: Dictionary, tick: int, origin_year: int = 100) -> int:
	return epoch_jdn(state, origin_year) + tick * TICK_DAYS


static func scenario_for_world(world: Dictionary) -> String:
	return scenario_for_year(int(world.get("village", {}).get("history", {}).get("start_year", 100)))


static func band_of(state: Dictionary) -> Array:
	var scn := scenario(str(state.scenario))
	var year := year_of(state)
	var result := []
	for band: Dictionary in scn.get("bands", []):
		if year >= int(band.from) and year <= int(band.to):
			result.append(str(band.roman))
	return result


# ---------------------------------------------------------------- raid API

static func _force_summary(troops: Dictionary) -> Dictionary:
	var result := {}
	for type_id: String in _sorted(troops):
		if int(troops[type_id].count) > 0:
			result[type_id] = int(troops[type_id].count)
	return result


## Copy-on-write for callers inside a WorldModel transaction: the world
## model shares the tribal dictionary between frames, so any caller that
## changes it (raid results, reports) must work on its own copy.
static func writable(world: Dictionary) -> Dictionary:
	world.tribes = (world.tribes as Dictionary).duplicate(true)
	return world.tribes


## War bands standing at an external target and waiting for the local scene
## (village_life) to play the attack. Pure.
static func arrived_raids(state: Dictionary, target_id: String) -> Array:
	var result := []
	var scn := scenario(str(state.scenario))
	for e: Dictionary in state.expeditions:
		if e.target == target_id and e.status == "arrived":
			result.append({"expedition": str(e.id), "group": str(e.group), "kind": str(e.kind), "protected": bool(e.protected),
				"warriors": _force_summary(e.troops), "warriors_total": _force_count(e.troops), "strength": _q2(troops_strength(scn, e.troops)),
				"await_until": int(e.get("await_until", -1))})
	return result


static func raid_allowed(state: Dictionary, target_id: String) -> Dictionary:
	var t := int(state.tick)
	var window: Dictionary = state.raid_windows.get(target_id, {})
	if state.targets.has(target_id) and int(state.targets[target_id].story_lock_until) >= t:
		return {"allowed": false, "reason": "story_protected", "until": int(state.targets[target_id].story_lock_until), "note": str(state.targets[target_id].story_lock_reason)}
	if not window.is_empty() and int(window.until) > t:
		return {"allowed": false, "reason": "recovery_window", "until": int(window.until), "note": str(window.reason)}
	return {"allowed": true, "reason": "", "until": t, "note": ""}


## Who intends to raid `target_id`, with which real soldiers, why and when.
## Pure: nothing in the world changes. Blocked entries keep their reason.
static func planned_raids(state: Dictionary, target_id: String) -> Array:
	var result := []
	var scn := scenario(str(state.scenario))
	if scn.is_empty():
		return result
	var t := int(state.tick) + 1
	var week := int(state.tick) % WEEKS
	var allowed := raid_allowed(state, target_id)
	for gid: String in _sorted(state.groups):
		var g: Dictionary = state.groups[gid]
		if g.status != "active" or not (str(g.kind) in ["tribe", "band"]) or gid == target_id:
			continue
		var km := _distance_groups(state, gid, target_id)
		var entry := {"group": gid, "name": str(g.name), "status": "", "reason": "", "warriors": {}, "warriors_total": 0, "strength": 0.0,
			"motive": "", "utility": 0.0, "earliest_tick": -1, "earliest_day": -1, "km": roundi(km), "travel_ticks": travel_ticks(km)}
		var e := _expedition_of(state, gid)
		if not e.is_empty() and e.target == target_id:
			entry.status = "en_route" if e.status == "outbound" else str(e.status)
			entry.reason = "war_band_" + str(e.status)
			entry.warriors = _force_summary(e.troops)
			entry.strength = _q2(troops_strength(scn, e.troops))
			entry.motive = str(e.motive)
			entry.earliest_tick = int(e.arrive_tick)
		elif g.kind == "band":
			var commission := {}
			for item: Dictionary in state.agreements:
				if item.status == "active" and item.kind == "commission" and item.b == gid and str(item.get("target", "")) == target_id:
					commission = item
			entry.warriors = _force_summary(g.troops)
			entry.strength = _q2(troops_strength(scn, g.troops))
			# D-040: who pays the riders is not an observable fact.
			if commission.is_empty():
				entry.status = "blocked"
				entry.reason = "no_cause"
			else:
				entry.status = "story_bound"
				entry.reason = "story_event_" + str(commission.get("story", ""))
				entry.motive = "unknown"
		else:
			var cache := _decision_cache(state, t)
			var ctx := _context(state, scn, gid, t, week, cache)
			ctx["cache"] = cache
			ctx["force"] = _raid_force(state, scn, gid, float(ctx.traits.caution))
			var score := _raid_score(state, scn, gid, target_id, ctx, t, week)
			entry.warriors = _force_summary(score.force)
			entry.strength = _q2(troops_strength(scn, score.force) * _morale_factor(float(g.morale)))
			entry.motive = str(score.motive)
			entry["occasion"] = str(score.get("dispute", {}).get("source", ""))
			entry.utility = _q(float(score.utility))
			if score.blocked != "":
				entry.status = "blocked"
				entry.reason = str(score.blocked)
			elif float(score.utility) < ACTION_THRESHOLD:
				entry.status = "no_intent"
				entry.reason = "utility_below_threshold"
			else:
				entry.status = "planned"
			var ready := maxi(t, int(g.last_raid_tick) + OWN_RAID_COOLDOWN)
			if not bool(allowed.allowed):
				ready = maxi(ready, int(allowed.until) + 1)
			entry.earliest_tick = ready + travel_ticks(km)
		for type_id: String in entry.warriors:
			entry.warriors_total = int(entry.warriors_total) + int(entry.warriors[type_id])
		entry.earliest_day = int(entry.earliest_tick) * TICK_DAYS
		result.append(entry)
	return result


## Launches a planned raid on an external target with the group's real men.
static func commit_raid(state: Dictionary, gid: String, target_id: String) -> Dictionary:
	var scn := scenario(str(state.scenario))
	for entry: Dictionary in planned_raids(state, target_id):
		if entry.group == gid and entry.status == "planned":
			var force := _raid_force(state, scn, gid, float(traits(state, gid).caution))
			var motive := str(entry.get("occasion", "")) if str(entry.motive) == "need" else str(entry.motive)
			var e := _launch_raid(state, scn, gid, target_id, force, motive, "Geplanter Zug (Nutzen %.2f)" % float(entry.utility), int(state.tick), false, "raid")
			if e.is_empty():
				return {"ok": false, "message": "Kein Kriegszug möglich."}
			return {"ok": true, "expedition": str(e.id), "warriors": _force_summary(e.troops), "arrive_tick": int(e.arrive_tick)}
	return {"ok": false, "message": "Diese Gruppe plant keinen Zug gegen dieses Ziel."}


static func story_raid(state: Dictionary, story_id: String) -> Dictionary:
	var scn := scenario(str(state.scenario))
	if scn.is_empty() or not scn.story_raids.has(story_id) or not state.story.has(story_id):
		return {}
	var spec: Dictionary = scn.story_raids[story_id]
	var gid := str(spec.attacker)
	var g: Dictionary = state.groups.get(gid, {})
	var riders := _force_summary(g.get("troops", {})) if not g.is_empty() else {}
	var total := 0
	for type_id: String in riders:
		total += int(riders[type_id])
	var e := _expedition_of(state, gid)
	if not e.is_empty():
		riders = _force_summary(e.troops)
		total = _force_count(e.troops)
	return {"story": story_id, "attacker": gid, "attacker_name": str(g.get("name", "")), "target": str(spec.target), "status": str(state.story[story_id].status),
		"riders": riders, "riders_total": total, "visible_raiders": int(spec.visible_raiders), "consistent": total >= int(spec.visible_raiders),
		"expedition": str(state.story[story_id].expedition), "protected": bool(spec.protected), "recovery_ticks": int(spec.recovery_ticks)}


## The protected story raid uses the band's actual riders. Its outcome is the
## screenplay's; this model only books what `apply_raid_result` reports.
static func commit_story_raid(state: Dictionary, story_id: String) -> Dictionary:
	var scn := scenario(str(state.scenario))
	var info := story_raid(state, story_id)
	if info.is_empty() or info.status != "pending":
		return {"ok": false, "message": "Dieses Storyereignis ist nicht offen."}
	var gid := str(info.attacker)
	var g: Dictionary = state.groups[gid]
	if g.status != "active" or _warriors_home(g) == 0:
		return {"ok": false, "message": "Die Reitergruppe existiert in diesem Weltzustand nicht mehr."}
	var force := {}
	for type_id: String in _sorted(g.troops):
		force[type_id] = {"count": int(g.troops[type_id].count)}
	# The mission is the cause (D-048); who stands behind it stays hidden (D-040).
	_open(state, gid, str(info.target), "quest_dispute", "mission:" + story_id, "Storyereignis " + story_id, 26)
	var e := _launch_raid(state, scn, gid, str(info.target), force, "quest_dispute", "Storyereignis " + story_id, int(state.tick), true, "story_raid")
	if e.is_empty():
		return {"ok": false, "message": "Kein Kriegszug möglich."}
	state.story[story_id].status = "committed"
	state.story[story_id].expedition = str(e.id)
	var target: Dictionary = state.targets[str(info.target)]
	target.story_lock_until = int(state.tick) + int(info.recovery_ticks)
	target.story_lock_reason = story_id
	trim(state)
	return {"ok": true, "expedition": str(e.id), "riders": _force_summary(e.troops), "riders_total": _force_count(e.troops)}


static func _kill_exact(state: Dictionary, scn: Dictionary, gid: String, troops: Dictionary, n: int, location: String, cause: String) -> Dictionary:
	var fallen := {"count": 0, "gear": {}, "retainers": []}
	var total := _force_count(troops)
	n = clampi(n, 0, total)
	var shares := {}
	var assigned := 0
	for type_id: String in _sorted(troops):
		shares[type_id] = floori(n * float(troops[type_id].count) / maxf(1.0, total))
		assigned += int(shares[type_id])
	for type_id: String in _sorted(troops):
		if assigned >= n:
			break
		if int(troops[type_id].count) > int(shares[type_id]):
			shares[type_id] = int(shares[type_id]) + 1
			assigned += 1
	for type_id: String in _sorted(shares):
		var part := _split(scn, type_id, troops[type_id], int(shares[type_id]))
		fallen.count = int(fallen.count) + int(part.count)
		for good: String in part.gear:
			fallen.gear[good] = int(fallen.gear.get(good, 0)) + int(part.gear[good])
		if bool(scn.troop_types[type_id].get("persons", false)):
			fallen.retainers.append_array(_retainers_leave(state, gid, location, int(part.count), "dead", "retainer", cause))
	_people(state, gid, 0, mini(int(fallen.count), int(state.groups[gid].settlements[0].population)), "destroy", "killed_in_battle")
	return fallen


## Feeds a locally played raid (village_life) back into this world: real
## attacker losses, the goods the village ledger lost, relations and the
## recovery window. Village goods convert through EXTERNAL_GOODS.
static func apply_raid_result(state: Dictionary, expedition_id: String, result: Dictionary) -> Dictionary:
	var scn := scenario(str(state.scenario))
	var e := {}
	for item: Dictionary in state.expeditions:
		if item.id == expedition_id:
			e = item
	if e.is_empty() or e.status != "arrived" or e.target_kind != "external":
		return {"ok": false, "message": "Kein angekommener Kriegszug mit dieser Kennung."}
	var outcome := str(result.get("outcome", ""))
	if not (outcome in ["defended", "raided", "wounded", "hidden"]):
		return {"ok": false, "message": "Unbekanntes Ergebnis."}
	var t := int(state.tick)
	var gid := str(e.group)
	var target := str(e.target)
	var g: Dictionary = state.groups[gid]
	var fallen := _kill_exact(state, scn, gid, e.troops, int(result.get("attacker_losses", 0)), str(e.id), "fell at " + target)
	for good: String in _sorted(fallen.gear):
		var category := "external_out" if outcome == "defended" else "destroy"
		_book(state, _next(state, "t"), gid, good, int(fallen.gear[good]), category, "left_on_field_at_" + target, target, "held")
	var booked := {}
	var loot: Dictionary = result.get("loot", {})
	for village_good: String in _sorted(loot):
		if not EXTERNAL_GOODS.has(village_good):
			continue
		var map: Dictionary = EXTERNAL_GOODS[village_good]
		for good: String in map:
			var quantity := floori(int(loot[village_good]) * float(map[good]))
			if quantity > 0:
				_book(state, _next(state, "t"), gid, good, quantity, "external_in", "plunder_reported", target, "cargo", e)
				booked[good] = int(booked.get(good, 0)) + quantity
	var hidden := [gid]
	if e.kind == "story_raid":
		for item: Dictionary in state.agreements:
			if item.status == "active" and item.kind == "commission" and item.b == gid and str(item.get("target", "")) == target:
				var pay := int(item.terms.get("wealth", 0))
				_book(state, _next(state, "t"), gid, "wealth", pay, "external_in", "commission_payment", str(item.a))
				item.status = "fulfilled"
				item.closed_tick = t
				hidden.append(str(item.a))
				_event(state, "commission_paid", [str(item.a), gid], "Der Auftraggeber bezahlt %s (%d Wertgüter)." % [g.name, pay], "Auftrag nach dem Überfall erfüllt", hidden)
		for story_id: String in _sorted(state.story):
			if state.story[story_id].expedition == expedition_id:
				state.story[story_id].status = "resolved"
				state.story[story_id].result = outcome
	var survivors := _force_count(e.troops)
	var won := outcome != "defended"
	g.morale = _q(clampf(float(g.morale) + (6.0 if won else -12.0), 0.0, 100.0))
	_prestige(state, gid, 4.0 if won else -5.0)
	for type_id: String in e.troops:
		e.troops[type_id].xp = _q(minf(40.0, float(e.troops[type_id].xp) + (3.0 if won else 1.5)))
	var text := "%s überfällt %s (%s). Gefallene Angreifer: %d, gemeldete Beute: %s." % [g.name, _name(state, target), outcome, int(fallen.count), JSON.stringify(booked)]
	var event := _event(state, "raid_external", [gid, target], text, "Lokal gespieltes Ergebnis · Anlass " + str(e.cause.cause), [gid, target], false, "simulation", e.cause)
	var felt: Variant = {"defended": {"grievance": 20.0, "trust": -20.0, "fear": 5.0}, "raided": {"grievance": 40.0, "trust": -30.0, "fear": 20.0},
		"wounded": {"grievance": 35.0, "trust": -30.0, "fear": 15.0}, "hidden": {"grievance": 40.0, "trust": -30.0, "fear": 25.0}}[outcome]
	Relations.apply(state.relations, target, gid, event, t, "raided", felt)
	Relations.apply(state.relations, gid, target, event, t, "raid_" + outcome, {"fear": 5.0} if outcome == "defended" else {"respect": -5.0})
	_retinue_memory(state, gid, str(e.id), target, event, "plunder" if won else "repulsed")
	var recovery := 0
	for story_id: String in _sorted(state.story):
		if state.story[story_id].expedition == expedition_id:
			recovery = int(scn.story_raids[story_id].recovery_ticks)
	if recovery == 0:
		recovery = clampi(6 + roundi(float(result.get("damage", 0)) / 5.0) + int(result.get("defender_casualties", 0)) * 2, 6, 26)
	state.raid_windows[target] = {"until": t + recovery, "reason": "recovery_after_" + outcome, "by": gid}
	e.status = "returning"
	e.outcome = outcome
	e.return_tick = t + (1 if e.kind == "story_raid" else travel_ticks(_distance_groups(state, gid, target)))
	g.last_raid_tick = t
	state.stats.external_raids = int(state.stats.external_raids) + 1
	trim(state)
	return {"ok": true, "message": text, "attacker_losses": int(fallen.count), "survivors": survivors, "loot_booked": booked, "recovery_until": t + recovery}


static func report_target_state(state: Dictionary, target_id: String, defenders: int, rebuilt: bool) -> bool:
	if not state.targets.has(target_id) or defenders < 0:
		return false
	var target: Dictionary = state.targets[target_id]
	target.defence = defenders
	target.rebuilt = rebuilt
	if not rebuilt:
		var window: Dictionary = state.raid_windows.get(target_id, {"until": 0, "reason": "", "by": ""})
		window.until = maxi(int(window.until), int(state.tick) + 4)
		window.reason = "rebuilding"
		state.raid_windows[target_id] = window
	_next(state, "r")
	return true


static func set_story_lock(state: Dictionary, target_id: String, until_tick: int, reason: String) -> bool:
	if not state.targets.has(target_id):
		return false
	state.targets[target_id].story_lock_until = maxi(int(state.targets[target_id].story_lock_until), until_tick)
	state.targets[target_id].story_lock_reason = reason
	_next(state, "r")
	return true


# ---------------------------------------------------------------- player API

const PLAYER_EFFECTS := {
	"trade": {"trust": 3.0}, "gift": {"trust": 6.0, "obligation": 5.0}, "help": {"trust": 10.0, "obligation": 10.0, "respect": 5.0},
	"insult": {"grievance": 15.0, "trust": -10.0}, "attack": {"grievance": 35.0, "trust": -30.0, "fear": 10.0},
	"broke_promise": {"trust": -25.0, "grievance": 10.0, "respect": -10.0}}


## What a group feels about the player follows the player's real deeds. The
## player's own attitude is never simulated.
static func record_player_action(state: Dictionary, gid: String, kind: String, note: String = "") -> Dictionary:
	if not state.groups.has(gid) or not PLAYER_EFFECTS.has(kind):
		return {"ok": false, "message": "Unbekannte Gruppe oder Handlung."}
	var spread := kind in ["help", "attack", "broke_promise"]
	var event := _event(state, "player_" + kind, ["player", gid], "Die Spielfigur: %s bei %s. %s" % [kind, _name(state, gid), note], "Spielerhandlung", ["player", gid], spread)
	_affect(state, gid, "player", event, "player_" + kind, PLAYER_EFFECTS[kind])
	trim(state)
	return {"ok": true, "event": event, "stance": Relations.stance(state.relations, gid, "player")}


## Campaign grain and tribal food use the existing external-goods conversion.
static func receive_delegation(state: Dictionary, gid: String, grain: int) -> void:
	var amount := floori(grain * float(EXTERNAL_GOODS.grain.food))
	_tx(state,gid,"food",amount,"external_in","Gesandtschaft aus Valdora","player")
	record_player_action(state,gid,"gift","Eine bestätigte Getreidelieferung aus Valdora.")


static func player_mediate(state: Dictionary, a: String, b: String) -> Dictionary:
	if not state.groups.has(a) or not state.groups.has(b) or a == b:
		return {"ok": false, "message": "Unbekannte Gruppen."}
	if not _active_agreement(state, a, b, ["truce", "alliance"]).is_empty():
		return {"ok": false, "message": "Zwischen beiden gilt bereits Frieden."}
	var willing := true
	for pair: Array in [[a, b], [b, a]]:
		var tr := traits(state, str(pair[0]))
		var h: Dictionary = state.groups[pair[0]]
		var peace := float(tr.caution) * _rel(state, str(pair[0]), str(pair[1]), "fear") / 100.0 + float(h.weariness) + 0.25 + _rel(state, str(pair[0]), "player", "trust") / 100.0 - float(tr.pride) * _rel(state, str(pair[0]), str(pair[1]), "grievance") / 100.0 * 0.5
		willing = willing and peace > 0.0 and _rel(state, str(pair[0]), "player", "trust") >= 0.0
	var t := int(state.tick)
	if not willing:
		var refused := _event(state, "mediation_failed", ["player", a, b], "Die Vermittlung zwischen %s und %s scheitert." % [_name(state, a), _name(state, b)], "Kein Friedenswille", ["player", a, b])
		trim(state)
		return {"ok": false, "message": "Keine Einigung.", "event": refused}
	var item := _make_agreement(state, "truce", a, b, t, 26, {}, 0, "player_mediated")
	var event := _event(state, "agreement_made", [a, b, "player"], "Durch Vermittlung der Spielfigur schließen %s und %s Waffenruhe bis Woche %d." % [_name(state, a), _name(state, b), int(item.end)], "Vermittlung", ["player", a, b], true)
	for gid: String in [a, b]:
		_affect(state, gid, "player", event, "mediated", {"trust": 5.0, "respect": 5.0})
	_affect(state, a, b, event, "agreement_made", {"trust": 2.0})
	_affect(state, b, a, event, "agreement_made", {"trust": 2.0})
	trim(state)
	return {"ok": true, "agreement": str(item.id), "event": event}


## Knowledge from evidence or testimony: the observer now knows the subject.
static func reveal(state: Dictionary, observer: String, subject: String, evidence: String) -> bool:
	var ids := actor_ids(state)
	if not ids.has(observer) or not ids.has(subject) or evidence.is_empty():
		return false
	var event := _event(state, "evidence", [observer, subject], "%s erfährt durch %s von %s." % [_name(state, observer), evidence, _name(state, subject)], evidence, [observer])
	trim(state)
	return Relations.introduce(state.relations, observer, subject, event, int(state.tick), "evidence")


# ---------------------------------------------------------------- views

static func actor_ids(state: Dictionary) -> Dictionary:
	var ids := {}
	for section: String in ["groups", "persons", "targets"]:
		for id: String in state[section]:
			ids[id] = section
	return ids


## Materialisation on a visit: what changed since the last visit, from the
## same ledger the remote simulation used. Pure; `mark_visited` records it.
static func visit_report(state: Dictionary, gid: String) -> Dictionary:
	if not state.groups.has(gid):
		return {}
	var g: Dictionary = state.groups[gid]
	var last: Dictionary = state.visits.get(gid, {"tick": 0, "stock": state.opening[gid], "population": int(state.opening[gid].people), "warriors": -1})
	var delta := {}
	for good: String in _sorted(g.stock):
		var then := int(last.stock.get(good, 0))
		var now := int(g.stock[good]) + (int(g.held[good]) if not state.visits.has(gid) else 0)
		if state.visits.has(gid):
			now = int(g.stock[good])
		if now != then:
			delta[good] = now - then
	var events := []
	for ev: Dictionary in state.events:
		if int(ev.tick) > int(last.tick) and gid in ev.actors:
			events.append({"tick": int(ev.tick), "text": str(ev.text), "cause": str(ev.cause)})
	return {"group": gid, "since_tick": int(last.tick), "now_tick": int(state.tick), "delta": delta, "population": _population(g),
		"population_delta": _population(g) - int(last.population), "warriors": _warriors_home(g) + _warriors_away(state, gid),
		"buildings": g.settlements.map(func(s: Dictionary) -> Dictionary: return {"name": s.name, "buildings": (s.buildings as Dictionary).duplicate(), "damage": snappedf(float(s.damage), 0.1)}),
		"events": events}


static func mark_visited(state: Dictionary, gid: String) -> void:
	if not state.groups.has(gid):
		return
	var g: Dictionary = state.groups[gid]
	state.visits[gid] = {"tick": int(state.tick), "stock": (g.stock as Dictionary).duplicate(), "population": _population(g), "warriors": _warriors_home(g) + _warriors_away(state, gid)}


const CLASS_COLOURS := {"schwach": "#b9c7a5", "mittel": "#e3c46f", "stark": "#e0894a", "sehr stark": "#c2412f"}


## What a viewer can know: a fictional band stays hidden until the viewer
## has met it or seen evidence (I-08: no people named before the raid).
static func atlas_view(state: Dictionary, viewer: String = "") -> Array:
	var result := []
	var scn := scenario(str(state.scenario))
	if scn.is_empty():
		return result
	for gid: String in _sorted(state.groups):
		var g: Dictionary = state.groups[gid]
		if g.kind == "market":
			continue
		if viewer != "" and g.kind == "band" and not Relations.knows(state.relations, viewer, gid):
			continue
		var total := {}
		for type_id: String in g.troops:
			if int(g.troops[type_id].count) > 0:
				total[type_id] = int(g.troops[type_id].count)
		var e := _expedition_of(state, gid)
		if not e.is_empty():
			for type_id: String in e.troops:
				total[type_id] = int(total.get(type_id, 0)) + int(e.troops[type_id].count)
		var power := strength(state, gid) + (troops_strength(scn, e.troops) * _morale_factor(float(g.morale)) if not e.is_empty() else 0.0)
		var relations := []
		for other: String in Relations.known_by(state.relations, gid):
			if state.groups.has(other) and state.groups[other].kind == "tribe" or other in ["rome", "valdora", "player"]:
				relations.append({"other": other, "name": _name(state, other), "stance": Relations.stance(state.relations, gid, other)})
		var pacts := []
		for item: Dictionary in state.agreements:
			if item.status == "active" and (item.a == gid or item.b == gid) and item.kind != "commission":
				var other := str(item.b) if item.a == gid else str(item.a)
				pacts.append({"kind": str(item.kind), "other": other, "name": _name(state, other), "until": int(item.end), "role": "payer" if item.kind == "tribute" and item.a == gid else ""})
		var leader: Dictionary = state.persons.get(str(g.leader), {})
		var war_leader: Dictionary = state.persons.get(str(g.get("war_leader", "")), {})
		var tributaries := 0
		var allies := 0
		var pacts_of_trade := 0
		for item: Dictionary in state.agreements:
			if item.status != "active":
				continue
			if item.kind == "tribute" and item.b == gid:
				tributaries += 1
			elif item.kind == "alliance" and (item.a == gid or item.b == gid):
				allies += 1
			elif item.kind == "trade_pact" and (item.a == gid or item.b == gid):
				pacts_of_trade += 1
		var profile := []
		if tributaries >= 2:
			profile.append("Machtzentrum")
		if pacts_of_trade >= 2 or int(g.history.get("trades", 0)) >= 20:
			profile.append("Handelsgemeinschaft")
		if allies >= 1:
			profile.append("Bündnispartner")
		var labels := []
		for type_id: String in _sorted(total):
			labels.append("%d %s" % [int(total[type_id]), str(scn.troop_types[type_id].name)])
		result.append({"id": gid, "name": str(g.name), "people": str(g.people), "kind": str(g.kind), "canon_kind": str(g.canon_kind), "status": str(g.status),
			"atlas_region": str(g.atlas_region), "settlements": g.settlements.map(func(s: Dictionary) -> Dictionary: return {"name": s.name, "lat": float(s.lat), "lon": float(s.lon), "population": int(s.population), "size": settlement_class(int(s.population))}),
			"population": _population(g), "warriors": total, "warriors_total": _force_count(g.troops) + (_force_count(e.troops) if not e.is_empty() else 0), "troop_labels": labels,
			"strength": snappedf(power, 0.1), "strength_class": strength_class(power), "away": not e.is_empty(), "leader": str(leader.get("name", "")), "relations": relations, "agreements": pacts,
			"project": str(g.project.get("name", "")), "last_action": str(g.last_action),
			"government": str(g.get("government", "")), "government_name": str(scn.get("governments", {}).get(str(g.get("government", "")), {}).get("name", "")),
			"war_leader": str(war_leader.get("name", "")), "profile": profile, "tributaries": tributaries})
	return result


static func settlement_points(state: Dictionary, viewer: String = "") -> Array:
	var points := []
	for item: Dictionary in atlas_view(state, viewer):
		if item.status != "active":
			continue
		for s: Dictionary in item.settlements:
			points.append({"lat": float(s.lat), "lon": float(s.lon), "color": CLASS_COLOURS[item.strength_class], "label": "%s · %s" % [s.name, item.name], "group": item.id})
	return points


## The chronicle as the simulation knows it, or (with `viewer`) as that
## actor knows it: only events it took part in, saw or was told about.
static func chronicle(state: Dictionary, limit: int = 20, viewer: String = "") -> Array:
	var result := []
	var events: Array = state.events if viewer == "" else observed_facts(state, viewer)
	var start := maxi(0, events.size() - limit)
	for i in range(start, events.size()):
		var ev: Dictionary = events[i]
		result.append("[%s] %s (Anlass: %s)" % [calendar_at(state, int(ev.tick)), str(ev.text), str(ev.cause)])
	return result


## D-040 / handbook p. 11: an actor knows what it observed or was told.
## Hidden facts (who commissioned the riders) never leave the state this way.
static func observed_facts(state: Dictionary, observer: String) -> Array:
	var result := []
	for ev: Dictionary in state.events:
		if observer in ev.known_by:
			result.append(ev.duplicate(true))
	return result


static func calendar_at(state: Dictionary, tick: int) -> String:
	var week := maxi(0, tick - 1) % WEEKS
	return "%s %s, W%d" % [SEASON_NAMES[mini(3, floori(week / 13.0))], year_label(year_of(state, maxi(0, tick - 1))), week + 1]


## Conservation report: what the ledger says each actor must hold.
static func totals(state: Dictionary, gid: String) -> Dictionary:
	var g: Dictionary = state.groups[gid]
	var result := {}
	var cargo := {}
	for e: Dictionary in state.expeditions:
		if e.group == gid:
			for good: String in e.cargo:
				cargo[good] = int(cargo.get(good, 0)) + int(e.cargo[good])
	var flows: Dictionary = state.flows[gid]
	for good: String in _sorted(state.opening[gid]):
		var inflow := 0
		var outflow := 0
		var f: Dictionary = flows.get(good, {})
		for category: String in INFLOW:
			inflow += int(f.get(category, 0))
		for category: String in OUTFLOW:
			outflow += int(f.get(category, 0))
		var actual := _population(g) if good == "people" else int(g.stock[good]) + int(g.held[good]) + int(cargo.get(good, 0))
		result[good] = {"opening": int(state.opening[gid][good]), "inflow": inflow, "outflow": outflow, "expected": int(state.opening[gid][good]) + inflow - outflow, "actual": actual}
	return result


# ---------------------------------------------------------------- validation

const GROUP_KEYS := ["name", "people", "kind", "culture", "canon_kind", "source_note", "atlas_region", "status", "leader", "government", "war_leader", "war_until", "families", "traits", "goals", "raid_range_km", "settlements", "sites", "stock", "held", "troops", "morale", "project", "acc", "last_action", "last_action_tick", "last_raid_tick", "refuge_until", "prepared_until", "weariness", "hunger_weeks", "history", "extra"]
const PERSON_KEYS := ["name", "group", "family", "role", "born_tick", "traits", "prestige", "status", "canon_kind", "since", "with", "deeds", "fate"]
const PERSON_ROLES := ["chief", "heir", "rival", "elder", "retainer", "veteran", "exile"]
const PERSON_STATUS := ["alive", "dead", "left", "left_area"]
const AGREEMENT_STATUS := ["active", "kept", "broken", "expired", "void", "fulfilled"]
const EXPEDITION_STATUS := ["outbound", "arrived", "returning"]
## Recently validated states, compared by identity and by a mark that changes
## with every tick, booking and event. Several slots, so that the committed
## world and a freshly finished week never evict each other.
const VALIDATED_SLOTS := 4
static var _validated: Array = []


static func _num(v: Variant, low: float, high: float) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)) and float(v) >= low and float(v) <= high


static func _int(v: Variant, low: int, high: int) -> bool:
	return _num(v, low, high) and float(v) == floorf(float(v))


static func _keys(v: Variant, keys: Array) -> bool:
	return typeof(v) == TYPE_DICTIONARY and v.size() == keys.size() and v.has_all(keys)


static func _mark(state: Dictionary) -> String:
	# Integers on purpose: a loaded state (JSON floats, then normalised) keeps its mark.
	return "%d:%d:%d" % [int(state.get("tick", -1)), int(state.get("next_id", -1)), int(state.get("extra_days", -1))]


static func is_validated(state: Variant) -> bool:
	if typeof(state) != TYPE_DICTIONARY:
		return false
	for slot: Array in _validated:
		if is_same(slot[0], state) and slot[1] == _mark(state):
			return true
	return false


## Records a state whose complete validation has passed (all slices of a
## check runner). Only callers that ran that validation may use it.
static func mark_validated(state: Dictionary) -> void:
	for i in range(_validated.size() - 1, -1, -1):
		if is_same(_validated[i][0], state):
			_validated.remove_at(i)
	_validated.append([state, _mark(state)])
	while _validated.size() > VALIDATED_SLOTS:
		_validated.pop_front()


## Validation is pure but not free; the world model calls this cached form
## every frame and pays for a full check only for a state it has not seen.
static func validate_cached(state: Variant) -> String:
	if is_validated(state):
		return ""
	var error := validate(state)
	if error.is_empty():
		mark_validated(state)
	return error


## A shallow copy that differs from an already validated state only in its
## calendar offset needs no new full check.
static func with_extra_days(state: Dictionary, days: int) -> Dictionary:
	var next := state.duplicate(false)
	next.extra_days = int(state.extra_days) + days
	if is_validated(state) and days >= 0:
		mark_validated(next)
	return next


static func validate(state: Variant) -> String:
	var runner := check_begin(state)
	while check_step(runner) > 0:
		pass
	return str(runner.error)


# ---------------------------------------------------------------- sliced work
# Three resumable runners share one contract: `*_step` performs exactly one
# slice and returns its cost in work units (0 once the runner is done);
# `next_units` says what the next slice will cost. One unit stands for a
# fixed slice size, not for measured time, so budgets are reproducible.
# Running all slices of a runner equals the monolithic operation exactly.

## Calibrated so that one unit is about 0.25 ms at the 95th percentile of
## each slice on the development desktop (headless, loaded machine).
const UNITS := {"copy_base": 3, "copy_persons": 3, "copy_events": 2, "copy_ledger": 3, "copy_edges": 2,
	"anchors": 1, "expeditions": 1, "economy": 4, "agreements": 1, "leadership": 3, "news": 6,
	"decision_cache": 2, "decide": 4, "decay": 2, "close": 1,
	"check_header": 1, "check_expeditions": 1, "check_group": 1, "check_persons": 3, "check_targets": 1,
	"check_edges": 2, "check_records": 2}
const MAX_SLICE_UNITS := 6
const EDGE_SLICE := 48
const CHECK_EDGE_SLICE := 24
const WEEK_STAGES := ["anchors", "expeditions", "economy", "agreements", "leadership", "news", "decision_cache", "decide", "decay", "close"]


static func next_units(runner: Dictionary) -> int:
	if bool(runner.done):
		return 0
	match str(runner.kind):
		"copy":
			return int(UNITS[["copy_base", "copy_persons", "copy_events", "copy_ledger", "copy_edges"][mini(4, int(runner.stage))]])
		"week":
			return int(UNITS[WEEK_STAGES[int(runner.stage)]])
		"check":
			return int(UNITS[str(runner.steps[int(runner.index)]).get_slice(":", 0)]) if int(runner.index) < runner.steps.size() else 1
	return 1


static func step(runner: Dictionary) -> int:
	match str(runner.kind):
		"copy":
			return copy_step(runner)
		"week":
			return week_step(runner)
		"check":
			return check_step(runner)
	return 0


## Deep copy in slices; the result is independent of the source afterwards.
static func copy_begin(source: Dictionary) -> Dictionary:
	return {"kind": "copy", "source": source, "target": {}, "stage": 0, "keys": [], "index": 0, "done": false}


static func copy_step(runner: Dictionary) -> int:
	if bool(runner.done):
		return 0
	var source: Dictionary = runner.source
	var target: Dictionary = runner.target
	var cost := next_units(runner)
	match int(runner.stage):
		0:
			for key: String in source:
				var value: Variant = source[key]
				if key in ["persons", "events", "ledger", "relations"]:
					target[key] = null # keeps the key order of the source
				elif typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY]:
					target[key] = value.duplicate(true)
				else:
					target[key] = value
			runner.stage = 1
		1:
			target.persons = (source.persons as Dictionary).duplicate(true)
			runner.stage = 2
		2:
			target.events = (source.events as Array).duplicate(true)
			runner.stage = 3
		3:
			target.ledger = (source.ledger as Array).duplicate(true)
			target.relations = {"version": source.relations.version, "edges": {}}
			runner.keys = source.relations.edges.keys()
			runner.stage = 4
			if runner.keys.is_empty():
				runner.done = true
		_:
			var edges: Dictionary = target.relations.edges
			var keys: Array = runner.keys
			var stop := mini(keys.size(), int(runner.index) + EDGE_SLICE)
			for i in range(int(runner.index), stop):
				edges[keys[i]] = (source.relations.edges[keys[i]] as Dictionary).duplicate(true)
			runner.index = stop
			if stop >= keys.size():
				runner.done = true
	return cost


static func copy_state(source: Dictionary) -> Dictionary:
	var runner := copy_begin(source)
	while copy_step(runner) > 0:
		pass
	return runner.target


static func check_begin(state: Variant) -> Dictionary:
	return {"kind": "check", "state": state, "steps": ["check_header"], "index": 0, "ctx": {}, "error": "", "done": false}


static func check_step(runner: Dictionary) -> int:
	if bool(runner.done):
		return 0
	var cost := next_units(runner)
	var step := str(runner.steps[int(runner.index)])
	var error := _check(runner, step)
	runner.index = int(runner.index) + 1
	if error != "":
		runner.error = error
		runner.done = true
	elif int(runner.index) >= runner.steps.size():
		runner.done = true
	return cost


static func _check(runner: Dictionary, step: String) -> String:
	var state: Variant = runner.state
	var ctx: Dictionary = runner.ctx
	var kind := step.get_slice(":", 0)
	if kind == "check_header":
		return _check_header(runner, state)
	var scn := scenario(str(state.scenario))
	var t := int(state.tick)
	match kind:
		"check_expeditions":
			return _check_expeditions(state, scn, t, ctx)
		"check_group":
			return _check_group(state, scn, t, ctx, step.get_slice(":", 1))
		"check_persons":
			return _check_persons(state, t, ctx)
		"check_targets":
			for tid: Variant in state.targets:
				var target: Variant = state.targets[tid]
				if not _keys(target, ["name", "kind", "canon_kind", "lat", "lon", "atlas_region", "raidable", "defence", "defender_strength", "rebuilt", "story_lock_until", "story_lock_reason"]) or not _int(target.defence, 0, 100000) or not _int(target.story_lock_until, -1, 100000000):
					return "Ungültiges Ziel %s." % tid
			var header := Relations.validate_header(state.relations)
			if header != "":
				return header
			ctx["ids"] = actor_ids(state)
			var keys: Array = state.relations.edges.keys()
			ctx["edges"] = keys
			# The relation check is appended now that the graph size is known.
			var insert := int(runner.index) + 1
			for start in range(0, keys.size(), CHECK_EDGE_SLICE):
				runner.steps.insert(insert, "check_edges:%d" % start)
				insert += 1
			return ""
		"check_edges":
			var keys: Array = ctx.edges
			var start := int(step.get_slice(":", 1))
			return Relations.validate_edges(state.relations, keys.slice(start, mini(keys.size(), start + CHECK_EDGE_SLICE)), ctx.ids, t)
		"check_records":
			return _check_records(state, t, ctx)
	return "Unbekannter Prüfschritt %s." % step


static func _check_header(runner: Dictionary, state: Variant) -> String:
	if not _keys(state, STATE_KEYS):
		return "Unvollständiger Stammesweltvertrag."
	if not _int(state.version, VERSION, VERSION) or typeof(state.scenario) != TYPE_STRING:
		return "Unbekannte Version der Stammeswelt."
	for key: String in ["seed", "rng", "tick", "extra_days", "next_id"]:
		if not _int(state[key], 0, 9007199254740990):
			return "Ungültiger Zähler %s." % key
	var scn := scenario(str(state.scenario))
	if state.scenario == NO_SCENARIO:
		for section: String in ["groups", "persons", "targets", "agreements", "expeditions"]:
			if not state[section].is_empty():
				return "Eine Welt ohne Szenario enthält Akteure."
		return ""
	if scn.is_empty():
		return "Unbekanntes Szenario %s." % state.scenario
	if typeof(state.groups) != TYPE_DICTIONARY or typeof(state.persons) != TYPE_DICTIONARY or typeof(state.targets) != TYPE_DICTIONARY:
		return "Akteurlisten fehlen."
	if typeof(state.expeditions) != TYPE_ARRAY or typeof(state.relations) != TYPE_DICTIONARY:
		return "Kriegszüge oder Beziehungen fehlen."
	var steps: Array = ["check_header", "check_expeditions"]
	for gid: Variant in state.groups:
		steps.append("check_group:%s" % gid)
	steps.append_array(["check_persons", "check_targets", "check_records"])
	runner.steps = steps
	return ""


static func _check_expeditions(state: Dictionary, scn: Dictionary, t: int, ctx: Dictionary) -> String:
	var goods: Array = scn.goods.keys()
	var cargo := {}
	var away_gear := {}
	var away_retinue := {}
	for e: Variant in state.expeditions:
		var fields := ["id", "group", "target", "target_kind", "kind", "troops", "depart_tick", "arrive_tick", "return_tick", "status", "cargo", "motive", "protected", "outcome", "cause"]
		if not _keys(e, fields) and not _keys(e, fields + ["await_until"]):
			return "Ungültiger Kriegszug."
		if typeof(e.cause) != TYPE_DICTIONARY or not (str(e.cause.get("cause", "")) in CONFLICT_CAUSES) or str(e.cause.get("dispute", "")).is_empty():
			return "Kriegszug ohne gebuchten Anlass (D-048)."
		if not state.groups.has(e.group) or not (e.status in EXPEDITION_STATUS) or not (state.groups.has(e.target) or state.targets.has(e.target)):
			return "Kriegszug ohne gültige Gruppe, Ziel oder Status."
		if not _int(e.depart_tick, 0, t) or not _int(e.arrive_tick, int(e.depart_tick), t + 100):
			return "Kriegszug mit ungültiger Zeit."
		var troop_error := _validate_troops(scn, e.troops)
		if troop_error != "":
			return troop_error
		for good: Variant in e.cargo:
			if not (good in goods) or not _int(e.cargo[good], 0, 100000000):
				return "Ungültige Beute im Kriegszug."
			cargo[str(e.group) + ":" + str(good)] = int(cargo.get(str(e.group) + ":" + str(good), 0)) + int(e.cargo[good])
		for type_id: String in e.troops:
			for good: String in e.troops[type_id].gear:
				away_gear[str(e.group) + ":" + good] = int(away_gear.get(str(e.group) + ":" + good, 0)) + int(e.troops[type_id].gear[good])
		away_retinue[str(e.id)] = int(e.troops.get("gefolgsmann", {}).get("count", 0))
	ctx["cargo"] = cargo
	ctx["away_gear"] = away_gear
	ctx["away_retinue"] = away_retinue
	return ""


static func _check_group(state: Dictionary, scn: Dictionary, t: int, ctx: Dictionary, gid: String) -> String:
	var goods: Array = scn.goods.keys()
	var cargo: Dictionary = ctx.cargo
	var away_gear: Dictionary = ctx.away_gear
	var g: Variant = state.groups[gid]
	if not _keys(g, GROUP_KEYS):
		return "Unvollständige Gruppe %s." % gid
	if not (g.status in GROUP_STATUS) or not (g.kind in ["tribe", "band", "market"]):
		return "Ungültiger Gruppenstatus %s." % gid
	if not _num(g.morale, 0.0, 100.0) or not _num(g.weariness, 0.0, 100.0) or not _int(g.hunger_weeks, 0, 100000):
		return "Ungültige Moral oder Erschöpfung in %s." % gid
	if not scn.get("governments", {}).has(g.government) or not _int(g.war_until, -1, 100000000) or typeof(g.war_leader) != TYPE_STRING:
		return "Ungültige Herrschaftsform oder Heerführung in %s." % gid
	if str(g.war_leader) != "" and (not state.persons.has(g.war_leader) or state.persons[g.war_leader].group != gid or state.persons[g.war_leader].status != "alive"):
		return "Heerführer von %s ist keine lebende Person der Gruppe." % gid
	for trait_id: Variant in g.traits:
		if not _num(g.traits[trait_id], 0.0, 1.0):
			return "Ungültige Eigenschaft in %s." % gid
	for key: Variant in g.acc:
		if not _num(g.acc[key], 0.0, 1.0):
			return "Ungültiger Restbetrag in %s." % gid
	if not _keys(g.stock, goods) or not _keys(g.held, goods):
		return "Unvollständiger Güterbestand in %s." % gid
	for good: String in goods:
		if not _int(g.stock[good], 0, 100000000) or not _int(g.held[good], 0, 100000000):
			return "Negativer oder ungültiger Bestand %s.%s." % [gid, good]
	var troop_error := _validate_troops(scn, g.troops)
	if troop_error != "":
		return troop_error
	var home_gear := {}
	for type_id: String in g.troops:
		for good: String in g.troops[type_id].gear:
			home_gear[good] = int(home_gear.get(good, 0)) + int(g.troops[type_id].gear[good])
	for good: String in goods:
		if int(g.held[good]) != int(home_gear.get(good, 0)) + int(away_gear.get(gid + ":" + good, 0)):
			return "Getragene Ausrüstung %s.%s entspricht nicht den Kriegern." % [gid, good]
	if typeof(g.settlements) != TYPE_ARRAY or g.settlements.is_empty() or g.settlements.size() > int(scn.economy.max_settlements):
		return "Ungültige Siedlungen in %s." % gid
	for s: Variant in g.settlements:
		if not _keys(s, ["id", "name", "lat", "lon", "population", "fields", "ore", "food_bonus", "buildings", "damage", "founded"]) or not _int(s.population, 0, 10000000) or not _num(s.damage, 0.0, 100.0) or not _num(s.lat, -90.0, 90.0) or not _num(s.lon, -180.0, 180.0):
			return "Ungültige Siedlung in %s." % gid
		for b: Variant in s.buildings:
			if not scn.buildings.has(b) or not _int(s.buildings[b], 0, 1000):
				return "Ungültiges Gebäude in %s." % gid
	var warriors := _warriors_home(g)
	for e: Dictionary in state.expeditions:
		if e.group == gid:
			warriors += _force_count(e.troops)
	if warriors > _population(g):
		return "Mehr Krieger als Menschen in %s." % gid
	# The ledger proves every quantity: opening + inflows - outflows.
	var flows: Dictionary = state.flows.get(gid, {})
	for good: String in goods + ["people"]:
		var inflow := 0
		var outflow := 0
		var f: Dictionary = flows.get(good, {})
		for category: String in INFLOW:
			inflow += int(f.get(category, 0))
		for category: String in OUTFLOW:
			outflow += int(f.get(category, 0))
		var actual := _population(g) if good == "people" else int(g.stock[good]) + int(g.held[good]) + int(cargo.get(gid + ":" + good, 0))
		if actual != int(state.opening[gid][good]) + inflow - outflow:
			return "Ledgerbilanz verletzt: %s.%s (Ist %d, Soll %d)." % [gid, good, actual, int(state.opening[gid][good]) + inflow - outflow]
	if not g.project.is_empty():
		if not _num(g.project.labour_left, 0.0, 100000.0) or not _int(g.project.progress_tick, 0, t):
			return "Ungültiges Bauvorhaben in %s." % gid
		for good: Variant in g.project.cost_left:
			if not _int(g.project.cost_left[good], 0, int(g.project.cost_total[good])):
				return "Ungültige Baukosten in %s." % gid
	return ""


static func _check_persons(state: Dictionary, t: int, ctx: Dictionary) -> String:
	var home_retinue := {}
	var away_counted := {}
	for pid: Variant in state.persons:
		var p: Variant = state.persons[pid]
		if not _keys(p, PERSON_KEYS) or not state.groups.has(p.group) or not (p.role in PERSON_ROLES) or not (p.status in PERSON_STATUS):
			return "Ungültige Person %s." % pid
		if not _num(p.prestige, 0.0, 100.0) or not _int(p.born_tick, -10000, t) or not _int(p.since, 0, t) or not _int(p.deeds, 0, 100000):
			return "Ungültige Personendaten %s." % pid
		if p.role == "retainer" and p.status == "alive":
			if p.with == "home":
				home_retinue[p.group] = int(home_retinue.get(p.group, 0)) + 1
			else:
				away_counted[p.with] = int(away_counted.get(p.with, 0)) + 1
	for gid: String in state.groups:
		if int(state.groups[gid].troops.get("gefolgsmann", {}).get("count", 0)) != int(home_retinue.get(gid, 0)):
			return "Die Gefolgschaft von %s entspricht nicht ihren Personen." % gid
		var leader := str(state.groups[gid].leader)
		if state.groups[gid].kind != "market" and state.groups[gid].status == "active" and (not state.persons.has(leader) or state.persons[leader].status != "alive" or state.persons[leader].role != "chief"):
			return "Aktive Gruppe %s ohne lebenden Anführer." % gid
	var away_retinue: Dictionary = ctx.away_retinue
	for xid: String in away_retinue:
		if int(away_retinue[xid]) != int(away_counted.get(xid, 0)):
			return "Gefolgsleute im Kriegszug %s stimmen nicht." % xid
	for xid: Variant in away_counted:
		if not away_retinue.has(xid):
			return "Gefolgsmann in einem nicht bestehenden Kriegszug."
	return ""


static func _check_records(state: Dictionary, t: int, ctx: Dictionary) -> String:
	if typeof(state.agreements) != TYPE_ARRAY or state.agreements.size() > MAX_AGREEMENTS:
		return "Ungültige Vereinbarungen."
	var ids: Dictionary = ctx.ids
	for item: Variant in state.agreements:
		if typeof(item) != TYPE_DICTIONARY or not item.has_all(["id", "kind", "a", "b", "start", "end", "every", "terms", "status", "paid", "missed", "broken_by", "closed_tick", "canon_kind"]):
			return "Unvollständige Vereinbarung."
		if not (item.kind in AGREEMENT_KINDS) or not (item.status in AGREEMENT_STATUS) or not ids.has(item.a) or not ids.has(item.b) or not _int(item.start, 0, t) or not _int(item.end, int(item.start), 100000000):
			return "Ungültige Vereinbarung %s." % item.id
		if item.status == "broken" and not ids.has(item.broken_by):
			return "Gebrochene Vereinbarung ohne Verursacher."
	if typeof(state.events) != TYPE_ARRAY or state.events.size() > MAX_EVENTS or typeof(state.ledger) != TYPE_ARRAY or state.ledger.size() > MAX_LEDGER:
		return "Chronik oder Ledger überschreitet die Grenze."
	for ev: Variant in state.events:
		if typeof(ev) != TYPE_DICTIONARY or not _int(ev.get("tick"), 0, t):
			return "Ereignis ohne gültige Zeit."
		if str(ev.get("kind", "")) in CONFLICT_EVENTS and not bool(ev.get("legacy", false)):
			var conflict: Variant = ev.get("conflict")
			if typeof(conflict) != TYPE_DICTIONARY or not (str(conflict.get("cause", "")) in CONFLICT_CAUSES):
				return "Konfliktereignis ohne erlaubten Anlass (D-048): %s." % ev.get("id", "")
	if typeof(state.disputes) != TYPE_ARRAY or state.disputes.size() > MAX_DISPUTES:
		return "Ungültige Streitliste."
	for item: Variant in state.disputes:
		if not _keys(item, ["id", "a", "b", "cause", "source", "note", "since", "until", "mutual", "status"]) or not (item.cause in CONFLICT_CAUSES) or not ids.has(item.a) or not ids.has(item.b):
			return "Ungültiger Streit."
		if not (item.status in ["open", "closed", "expired"]) or not _int(item.since, 0, t) or not _int(item.until, -1, 100000000) or typeof(item.source) != TYPE_STRING or str(item.source).is_empty():
			return "Streit ohne Quelle oder gültige Zeit: %s." % item.id
	for target_id: Variant in state.raid_windows:
		if not _int(state.raid_windows[target_id].get("until"), 0, 100000000):
			return "Ungültiges Erholungsfenster."
	return ""


static func _validate_troops(scn: Dictionary, troops: Variant) -> String:
	if typeof(troops) != TYPE_DICTIONARY:
		return "Ungültige Truppenliste."
	for type_id: Variant in troops:
		if not scn.troop_types.has(type_id):
			return "Unbekannter Kriegertyp %s." % type_id
		var stack: Variant = troops[type_id]
		if not _keys(stack, ["count", "xp", "gear"]) or not _int(stack.count, 0, 1000000) or not _num(stack.xp, 0.0, 40.0) or typeof(stack.gear) != TYPE_DICTIONARY:
			return "Ungültige Truppe %s." % type_id
		var spec: Dictionary = scn.troop_types[type_id]
		if str(spec.get("equipment_mode", "fixed")) == "mixed":
			var total := 0
			for good: Variant in stack.gear:
				if not (good in spec.slots) or not _int(stack.gear[good], 1, 1000000):
					return "Unzulässige Ausrüstung im Aufgebot."
				total += int(stack.gear[good])
			if total > int(stack.count):
				return "Das Aufgebot trägt mehr Waffen als Männer."
		else:
			var kit: Dictionary = {}
			for good: String in spec.equipment:
				if int(stack.count) * int(spec.equipment[good]) > 0:
					kit[good] = int(stack.count) * int(spec.equipment[good])
			if stack.gear.size() != kit.size():
				return "Ausrüstung von %s ist unvollständig." % type_id
			for good: String in kit:
				if int(stack.gear.get(good, -1)) != int(kit[good]):
					return "Ausrüstung von %s ist unvollständig." % type_id
	return ""


## Tribal state v1 (first #99 build) -> v2: forms of government and war
## leaders. Groups take the scenario's form; nobody leads a war yet.
static func migrate(state: Variant) -> void:
	if typeof(state) != TYPE_DICTIONARY or not _num(state.get("version"), 1, 1) or typeof(state.get("groups")) != TYPE_DICTIONARY or typeof(state.get("expeditions")) != TYPE_ARRAY or typeof(state.get("persons")) != TYPE_DICTIONARY:
		return
	for e: Variant in state.expeditions:
		if typeof(e) != TYPE_DICTIONARY or not e.has_all(["group", "troops", "cargo", "id"]) or not state.groups.has(e.group):
			return # Malformed: leave it to strict validation.
	var scn := scenario(str(state.get("scenario", NO_SCENARIO)))
	for gid: Variant in state.get("groups", {}):
		var g: Variant = state.groups[gid]
		if typeof(g) != TYPE_DICTIONARY or g.has("government"):
			continue
		g["government"] = str(scn.get("groups", {}).get(gid, {}).get("government", "assembly"))
		g["war_leader"] = ""
		g["war_until"] = -1
	for item: Variant in state.get("agreements", []):
		if typeof(item) == TYPE_DICTIONARY and item.get("kind", "") == "commission":
			item["hidden"] = true
	# D-048 came after v1: lasting enmities come from the roster; war bands
	# that left without a recorded cause go home; old conflict records are
	# kept as history and marked as written before the rule.
	state["disputes"] = []
	if not scn.is_empty():
		for item: Dictionary in scn.get("natural_enemies", []):
			if state.groups.has(item.a) and state.groups.has(item.b):
				_open(state, str(item.a), str(item.b), "natural_enemy", "roster:" + str(item.get("source", "design")), str(item.note), -1, true)
		for e: Variant in state.get("expeditions", []).duplicate():
			if typeof(e) == TYPE_DICTIONARY:
				_return_home(state, scn, e, int(state.tick))
	for ev: Variant in state.get("events", []):
		if typeof(ev) == TYPE_DICTIONARY and str(ev.get("kind", "")) in CONFLICT_EVENTS and not ev.has("conflict"):
			ev["legacy"] = true
	state.version = 2


## JSON turns integers into floats. Restore exact types so that a loaded
## world continues bit-identically to one that was never saved.
static func normalize(state: Dictionary) -> void:
	for key: String in ["version", "seed", "rng", "tick", "extra_days", "next_id"]:
		state[key] = int(state[key])
	for key: String in state.stats:
		state.stats[key] = int(state.stats[key])
	for gid: String in state.groups:
		var g: Dictionary = state.groups[gid]
		for section: String in ["stock", "held"]:
			for good: String in g[section]:
				g[section][good] = int(g[section][good])
		for key: String in ["last_action_tick", "last_raid_tick", "refuge_until", "prepared_until", "hunger_weeks", "war_until"]:
			g[key] = int(g[key])
		for key: String in g.history:
			g.history[key] = int(g.history[key])
		_normalize_troops(g.troops)
		for s: Dictionary in g.settlements:
			for key: String in ["population", "fields", "founded"]:
				s[key] = int(s[key])
			for b: String in s.buildings:
				s.buildings[b] = int(s.buildings[b])
		for site: Dictionary in g.sites:
			site.fields = int(site.fields)
		if not g.project.is_empty():
			for key: String in ["settlement", "started", "progress_tick"]:
				g.project[key] = int(g.project[key])
			for section: String in ["cost_total", "cost_left"]:
				for good: String in g.project[section]:
					g.project[section][good] = int(g.project[section][good])
		for section: String in ["arrival", "cap"]:
			if g.extra.has(section):
				for good: String in g.extra[section]:
					g.extra[section][good] = int(g.extra[section][good])
	for pid: String in state.persons:
		var p: Dictionary = state.persons[pid]
		for key: String in ["born_tick", "since", "deeds"]:
			p[key] = int(p[key])
	for tid: String in state.targets:
		state.targets[tid].defence = int(state.targets[tid].defence)
		state.targets[tid].story_lock_until = int(state.targets[tid].story_lock_until)
	for item: Dictionary in state.agreements:
		for key: String in ["start", "end", "every", "paid", "missed", "closed_tick"]:
			item[key] = int(item[key])
		for good: String in item.terms:
			item.terms[good] = int(item.terms[good])
	for e: Dictionary in state.expeditions:
		for key: String in ["depart_tick", "arrive_tick", "return_tick"]:
			e[key] = int(e[key])
		if e.has("await_until"):
			e.await_until = int(e.await_until)
		for good: String in e.cargo:
			e.cargo[good] = int(e.cargo[good])
		_normalize_troops(e.troops)
	for ev: Dictionary in state.events:
		ev.tick = int(ev.tick)
	for line: Dictionary in state.ledger:
		line.tick = int(line.tick)
		line.qty = int(line.qty)
	for gid: String in state.flows:
		for good: String in state.flows[gid]:
			for category: String in state.flows[gid][good]:
				state.flows[gid][good][category] = int(state.flows[gid][good][category])
	for gid: String in state.opening:
		for good: String in state.opening[gid]:
			state.opening[gid][good] = int(state.opening[gid][good])
	for gid: String in state.intel:
		for other: String in state.intel[gid]:
			var info: Dictionary = state.intel[gid][other]
			for key: String in ["tick", "food", "cattle", "wealth", "warriors"]:
				info[key] = int(info[key])
	for target_id: String in state.raid_windows:
		state.raid_windows[target_id].until = int(state.raid_windows[target_id].until)
	for item: Dictionary in state.disputes:
		item.since = int(item.since)
		item.until = int(item.until)
	for gid: String in state.visits:
		var visit: Dictionary = state.visits[gid]
		for key: String in ["tick", "population", "warriors"]:
			visit[key] = int(visit[key])
		for good: String in visit.stock:
			visit.stock[good] = int(visit.stock[good])
	Relations.normalize(state.relations)


static func _normalize_troops(troops: Dictionary) -> void:
	for type_id: String in troops:
		var stack: Dictionary = troops[type_id]
		stack.count = int(stack.count)
		stack.xp = float(stack.xp)
		for good: String in stack.gear:
			stack.gear[good] = int(stack.gear[good])
