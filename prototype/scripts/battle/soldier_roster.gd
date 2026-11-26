extends RefCounted
## Persistent soldier identities (decision D-027). The battle model is the only
## authority over a soldier's existence and state; views receive copies.
## A uid is never reused: the fallen keep their record and are not replaced.
## All randomness is a pure function of (world_seed, salts), so results are reproducible
## from a saved state without hidden generator state.
## Percentages and ranges below are balancing design values, not historical claims.

const STATUSES := ["active", "wounded", "dead", "retired"]
const BATTLE_STATUSES := ["active", "wounded", "dead"]
const SEVERITIES := ["light", "serious", "crippling", "fatal", "unrecorded"]
const OUTCOMES := ["return", "return_impaired", "retire", "dead", "pending"]
const IMPAIRMENTS := ["Hinken", "steife Schulter", "geschwächte Schildhand", "Verlust eines Auges", "Kurzatmigkeit nach Rippenbruch"]
const SERVICE_EVENTS := ["mustered", "wounded", "killed", "took_command", "lost_comrade", "promoted", "legacy_casualty", "recovered", "retired"]
const SKILLS := ["melee", "missile", "discipline"]
const MAX_SERVICE := 12
const RECORD_KEYS := ["uid", "name", "origin", "age", "troop_id", "skills", "xp", "relations", "service", "status", "wound", "impairments", "appearance_seed"]
const AGES := [[17, 21], [19, 28], [24, 34], [30, 42], [26, 45]]
const SKILL_BASE := [25, 40, 52, 62, 70]
## Tent group (contubernium) or kin group (Tac. Germ. 7) that starts with mutual bonds.
const GROUP_SIZE := {"roman": 8}
const KILLED_SHARE := 0.30
const COMRADE_BOND := 50


static func _mul32(a: int, b: int) -> int:
	# Low 32 bits of a*b without signed 64-bit overflow (both factors < 2^32).
	return (a * (b & 0xffff) + (((a * (b >> 16)) & 0xffff) << 16)) & 0xffffffff


static func mix(v: int) -> int:
	# 32-bit integer finaliser (lowbias32); identical on every platform.
	v &= 0xffffffff
	v ^= v >> 16
	v = _mul32(v, 0x7feb352d)
	v ^= v >> 15
	v = _mul32(v, 0x846ca68b)
	v ^= v >> 16
	return v


static func text_salt(text: String) -> int:
	# FNV-1a over UTF-8 bytes; independent of engine hash implementations.
	var h := 0x811c9dc5
	for b in text.to_utf8_buffer():
		h = ((h ^ b) * 0x01000193) & 0xffffffff
	return h


static func roll(world_seed: int, a: int, b: int = 0, c: int = 0) -> float:
	var h := mix(world_seed ^ mix(a ^ mix(b ^ mix(c))))
	return float(h) / 4294967296.0


static func uid(squad_id: String, index: int) -> String:
	return "%s_%02d" % [squad_id, index]


static func _pick(list: Array, value: float) -> Variant:
	return list[mini(list.size() - 1, floori(value * list.size()))]


## Creates the identity of soldier `index` of a company. troop is the catalog entry,
## pool the name list and group the population group the recruit comes from.
static func identity(world_seed: int, squad_id: String, index: int, count: int, troop: Dictionary, pool: Dictionary,
		group: Dictionary, entry_xp: int, discipline: int, year: int) -> Dictionary:
	var id := uid(squad_id, index)
	var salt := text_salt(id)
	var tier := clampi(int(troop.get("tier", 1)), 1, 5)
	var first: Array = pool.get("first", ["Miles"])
	# Stepping through the list keeps neighbouring names distinct within a company.
	var name: String = first[(floori(roll(world_seed, salt, 1) * first.size()) + index * 7) % first.size()]
	var family: Array = pool.get("family", [])
	if not family.is_empty():
		name += " " + str(_pick(family, roll(world_seed, salt, 2)))
	var age_span: Array = AGES[tier - 1]
	var age: int = age_span[0] + floori(roll(world_seed, salt, 3) * (age_span[1] - age_span[0] + 1))
	var base: int = SKILL_BASE[tier - 1]
	var ranged := false
	for item: Dictionary in troop.get("loadout", {}).values():
		ranged = ranged or item.family_id in ["bow", "sling", "javelin", "pilum"]
	var skills := {
		"melee": clampi(base - 10 + floori(roll(world_seed, salt, 4) * 21), 5, 95),
		"missile": clampi(base - (10 if ranged else 25) + floori(roll(world_seed, salt, 5) * 21), 5, 95),
		"discipline": clampi(discipline - 8 + floori(roll(world_seed, salt, 6) * 17), 5, 95),
	}
	var relations := {}
	var size: int = GROUP_SIZE.get(troop.get("culture", ""), 6)
	var group_start := (index / size) * size
	for other in range(group_start, mini(count, group_start + size)):
		if other != index:
			# The same value from both sides: the pair is salted by its ordered indices.
			relations[uid(squad_id, other)] = 35 + floori(roll(world_seed, text_salt(squad_id), mini(index, other), maxi(index, other)) * 31)
	var places: Array = group.get("places", ["?"])
	return {
		"uid": id, "name": name,
		"origin": {"group_id": str(group.get("group_id", "")), "place": str(_pick(places, roll(world_seed, salt, 7)))},
		"age": age, "troop_id": str(troop.get("troop_id", "")), "skills": skills,
		"xp": entry_xp + floori(roll(world_seed, salt, 8) * 80),
		"relations": relations,
		"service": [{"event": "mustered", "ref": str(troop.get("troop_id", "")), "year": year, "step": 0}],
		"status": "active", "wound": {}, "impairments": [],
		# Unique within the company by construction (low bits hold the index), so a
		# replacement can never look identical to the fallen soldier.
		"appearance_seed": (mix(world_seed ^ salt) & 0x7ffff000) | (index & 0xfff),
	}


## Fate of a soldier taken out of the ranks. Deterministic for (world_seed, uid, step).
static func casualty(world_seed: int, id: String, step: int) -> Dictionary:
	var salt := text_salt(id)
	if roll(world_seed, salt, step, 11) < KILLED_SHARE:
		return {"status": "dead", "wound": {"severity": "fatal", "recovery_days": 0, "impairment": "", "outcome": "dead", "step": step}}
	var r := roll(world_seed, salt, step, 12)
	var severity := "light" if r < 0.55 else ("serious" if r < 0.88 else "crippling")
	var span: Array = {"light": [5, 20], "serious": [30, 90], "crippling": [60, 150]}[severity]
	var days: int = span[0] + floori(roll(world_seed, salt, step, 13) * (span[1] - span[0] + 1))
	var impairment := ""
	var outcome := "return"
	if severity == "crippling" or (severity == "serious" and roll(world_seed, salt, step, 14) < 0.25):
		impairment = str(_pick(IMPAIRMENTS, roll(world_seed, salt, step, 15)))
		outcome = "retire" if severity == "crippling" else "return_impaired"
	return {"status": "wounded", "wound": {"severity": severity, "recovery_days": days, "impairment": impairment, "outcome": outcome, "step": step}}


static func note(record: Dictionary, event: String, ref: String, year: int, step: int) -> void:
	var service: Array = record.service
	if service.size() >= MAX_SERVICE:
		service.remove_at(1)
	service.append({"event": event, "ref": ref, "year": year, "step": step})


## Recovery after the battle (campaign time). Returns a changed copy.
static func recover(record: Dictionary, days: int, year: int) -> Dictionary:
	var r := record.duplicate(true)
	if r.status != "wounded" or days <= 0:
		return r
	r.wound.recovery_days = maxi(0, int(r.wound.recovery_days) - days)
	if r.wound.recovery_days > 0:
		return r
	if r.wound.impairment != "":
		r.impairments.append(r.wound.impairment)
	var retire: bool = r.wound.outcome == "retire"
	r.status = "retired" if retire else "active"
	note(r, "retired" if retire else "recovered", r.wound.impairment, year, -1)
	r.wound = {}
	return r


## Mean bond among living comrades that know each other (0-100); 50 when nobody does.
static func bond(people: Dictionary, alive: Array) -> float:
	var total := 0.0
	var pairs := 0
	for id in alive:
		for other in people[id].relations:
			if other in alive:
				total += float(people[id].relations[other])
				pairs += 1
	return total / pairs if pairs > 0 else 50.0


static func _int(v: Variant, low: int, high: int) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)) and float(v) == floorf(float(v)) and v >= low and v <= high


static func _valid_wound(w: Variant, status: String, steps: int) -> bool:
	if status == "active" or status == "retired":
		return typeof(w) == TYPE_DICTIONARY and w.is_empty()
	if typeof(w) != TYPE_DICTIONARY or w.size() != 5 or not w.has_all(["severity", "recovery_days", "impairment", "outcome", "step"]):
		return false
	if not w.severity in SEVERITIES or not w.outcome in OUTCOMES or not _int(w.recovery_days, 0, 400) or not _int(w.step, 0, steps):
		return false
	if typeof(w.impairment) != TYPE_STRING or (w.impairment != "" and not w.impairment in IMPAIRMENTS):
		return false
	if status == "dead":
		return w.outcome == "dead" and w.severity in ["fatal", "unrecorded"] and w.recovery_days == 0 and w.impairment == ""
	if w.severity == "unrecorded":
		return w.outcome == "pending" and w.recovery_days == 0 and w.impairment == ""
	if w.severity == "fatal" or w.outcome in ["dead", "pending"] or w.recovery_days == 0:
		return false
	return (w.impairment != "") == (w.outcome in ["return_impaired", "retire"]) and (w.outcome != "retire" or w.severity == "crippling")


## Validates a saved record against the freshly generated identity of the same uid.
## Identity (name, origin, age, troop, skills, appearance) cannot change in battle.
static func valid_record(r: Variant, original: Dictionary, company: Array, steps: int) -> bool:
	if typeof(r) != TYPE_DICTIONARY or r.size() != RECORD_KEYS.size() or not r.has_all(RECORD_KEYS):
		return false
	for key in ["uid", "name", "origin", "age", "troop_id", "skills", "appearance_seed"]:
		if r[key] != original[key]:
			return false
	if not _int(r.xp, original.xp, original.xp + 100000) or not r.status in BATTLE_STATUSES or not _valid_wound(r.wound, r.status, steps):
		return false
	if typeof(r.impairments) != TYPE_ARRAY or r.impairments != original.impairments:
		return false
	if typeof(r.relations) != TYPE_DICTIONARY:
		return false
	for other in r.relations:
		if other == r.uid or not other in company or not _int(r.relations[other], 0, 100):
			return false
	if typeof(r.service) != TYPE_ARRAY or r.service.is_empty() or r.service.size() > MAX_SERVICE or r.service[0] != original.service[0]:
		return false
	for entry: Variant in r.service:
		if typeof(entry) != TYPE_DICTIONARY or entry.size() != 4 or not entry.get("event") in SERVICE_EVENTS or typeof(entry.get("ref")) != TYPE_STRING:
			return false
		if not _int(entry.get("year"), -3000, 2000) or entry.year == 0 or not _int(entry.get("step"), -1, steps):
			return false
	return true


## True when every number inside is a finite whole number (JSON stores them as floats).
static func integral(v: Variant) -> bool:
	match typeof(v):
		TYPE_FLOAT:
			return is_finite(v) and v == floorf(v) and absf(v) < 9.0e15
		TYPE_DICTIONARY:
			for key in v:
				if not integral(v[key]):
					return false
		TYPE_ARRAY:
			for item in v:
				if not integral(item):
					return false
	return true


## JSON stores numbers as floats; records only hold integers. Check integral() first.
static func integers(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return int(v)
		TYPE_DICTIONARY:
			for key in v:
				v[key] = integers(v[key])
		TYPE_ARRAY:
			for i in range(v.size()):
				v[i] = integers(v[i])
	return v
