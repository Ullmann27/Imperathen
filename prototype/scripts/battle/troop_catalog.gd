extends RefCounted
## Era-aware troop catalog: loads, validates and queries assets/troops/*.json.
## Years are integers, negative = BC. There is no year 0: 1 BC is followed by AD 1.
## Every query returns copies; callers cannot change the shared catalog.

const TROOPS_PATH := "res://assets/troops/troops.json"
const FAMILIES_PATH := "res://assets/troops/item_families.json"
const PEOPLE_PATH := "res://assets/troops/people.json"
const MIN_YEAR := -3000
const MAX_YEAR := 2000
const MAX_QUALITY := 4
const ATTESTATIONS := ["attested", "plausible", "design_assumption"]
const LOADOUT_SLOTS := ["head", "torso", "shield", "main_hand", "sidearm", "missile", "mount", "mount_gear", "standard"]
const BATTLE_KINDS := ["infantry", "spear", "archer", ""]
const BATTLE_ROLES := ["heavy", "spear", "archer", "officer", ""]
const SERVICES := ["roman", "own"]
const OWNERSHIP := ["loan", "own", "issued"]
const COMMAND_SCOPES := ["army", "company", "deputy", "none"]
## A battle kind needs a matching main weapon, otherwise data and simulation disagree.
const KIND_WEAPONS := {"infantry": ["gladius", "sword_long", "axe"], "spear": ["spear"], "archer": ["bow", "sling"]}

static var _default := {}


static func load_default() -> Dictionary:
	if _default.is_empty():
		_default = build(read_json(FAMILIES_PATH), read_json(TROOPS_PATH), read_json(PEOPLE_PATH))
	return _default


static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Validates all three documents and returns an indexed catalog.
## On any error the catalog is empty and ok is false; nothing partial is published.
static func build(families_doc: Variant, troops_doc: Variant, people_doc: Variant) -> Dictionary:
	var errors := validate(families_doc, troops_doc, people_doc)
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "families": {}, "troops": {}, "appointments": {}, "name_pools": {}, "groups": {}}
	var catalog := {"ok": true, "errors": [], "families": {}, "troops": {}, "appointments": {}, "name_pools": {}, "groups": {}}
	for f: Dictionary in families_doc.families:
		catalog.families[f.family_id] = _integers(f.duplicate(true))
	for t: Dictionary in troops_doc.troops:
		catalog.troops[t.troop_id] = _integers(t.duplicate(true))
	for a: Dictionary in troops_doc.appointments:
		catalog.appointments[a.appointment_id] = _integers(a.duplicate(true))
	catalog.name_pools = people_doc.name_pools.duplicate(true)
	for g: Dictionary in people_doc.population_groups:
		catalog.groups[g.group_id] = g.duplicate(true)
	catalog.drills = troops_doc.drills.duplicate(true)
	catalog.authorities = troops_doc.authorities.duplicate(true)
	return catalog


# JSON numbers arrive as floats. Validation guarantees integral values first.
static func _integers(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if v == floorf(v) else v
		TYPE_DICTIONARY:
			for key in v:
				if key != "design_stats":
					v[key] = _integers(v[key])
			return v
		TYPE_ARRAY:
			for i in range(v.size()):
				v[i] = _integers(v[i])
			return v
	return v


static func is_integer(v: Variant, low: int, high: int) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(v)) and float(v) == floorf(float(v)) and v >= low and v <= high


static func valid_year(v: Variant) -> bool:
	return is_integer(v, MIN_YEAR, MAX_YEAR) and int(v) != 0


static func valid_span(entry: Dictionary) -> bool:
	return valid_year(entry.get("valid_from")) and valid_year(entry.get("valid_to")) and int(entry.valid_from) <= int(entry.valid_to)


static func valid_at(entry: Dictionary, year: int) -> bool:
	return year != 0 and int(entry.valid_from) <= year and year <= int(entry.valid_to)


## Elapsed calendar years without a year zero (58 BC to AD 9 is 66 years).
static func years_between(from_year: int, to_year: int) -> int:
	var span := to_year - from_year
	if from_year < 0 and to_year > 0:
		span -= 1
	elif from_year > 0 and to_year < 0:
		span += 1
	return span


static func year_label(year: int) -> String:
	return ("%d v. Chr." % -year) if year < 0 else ("%d n. Chr." % year)


static func _text(v: Variant) -> bool:
	return typeof(v) == TYPE_STRING and not String(v).strip_edges().is_empty()


static func _identifier(v: Variant) -> bool:
	if typeof(v) != TYPE_STRING or v.is_empty() or v[0] < "a" or v[0] > "z":
		return false
	for c in String(v):
		if not ((c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_"):
			return false
	return true


static func _check_sources(owner: String, entry: Dictionary, errors: Array[String], required: bool) -> void:
	if not entry.get("attestation") in ATTESTATIONS:
		errors.append("%s: attestation muss attested, plausible oder design_assumption sein" % owner)
	var sources: Variant = entry.get("sources")
	if typeof(sources) != TYPE_ARRAY or (required and sources.is_empty()):
		errors.append("%s: Quellenangaben fehlen" % owner)
		return
	for source: Variant in sources:
		if typeof(source) != TYPE_DICTIONARY or not _text(source.get("ref")) or typeof(source.get("note")) != TYPE_STRING or typeof(source.get("verified")) != TYPE_BOOL:
			errors.append("%s: Quellenangabe braucht ref, note und verified" % owner)


static func validate(families_doc: Variant, troops_doc: Variant, people_doc: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(families_doc) != TYPE_DICTIONARY or families_doc.get("schema_version") != 1.0 or typeof(families_doc.get("families")) != TYPE_ARRAY:
		errors.append("item_families: Dokument oder schema_version 1 fehlt")
		return errors
	if typeof(troops_doc) != TYPE_DICTIONARY or troops_doc.get("schema_version") != 1.0 or typeof(troops_doc.get("troops")) != TYPE_ARRAY or typeof(troops_doc.get("appointments")) != TYPE_ARRAY:
		errors.append("troops: Dokument oder schema_version 1 fehlt")
		return errors
	if typeof(troops_doc.get("drills")) != TYPE_DICTIONARY or typeof(troops_doc.get("authorities")) != TYPE_DICTIONARY:
		errors.append("troops: drills und authorities müssen Wörterbücher sein")
		return errors
	if typeof(people_doc) != TYPE_DICTIONARY or people_doc.get("schema_version") != 1.0 or typeof(people_doc.get("name_pools")) != TYPE_DICTIONARY or typeof(people_doc.get("population_groups")) != TYPE_ARRAY:
		errors.append("people: Dokument oder schema_version 1 fehlt")
		return errors
	var families := {}
	for f: Variant in families_doc.families:
		if typeof(f) != TYPE_DICTIONARY or not _identifier(f.get("family_id")):
			errors.append("item_families: Eintrag ohne gültige family_id")
			continue
		var owner: String = "Familie " + f.family_id
		if families.has(f.family_id):
			errors.append(owner + ": doppelt")
		families[f.family_id] = f
		var ref: Variant = f.get("handbook_ref")
		if typeof(ref) != TYPE_STRING or not (ref == "Ergänzung" or (ref.begins_with("IT-0") and ref.length() == 6)):
			errors.append(owner + ": handbook_ref muss IT-0xx oder Ergänzung sein")
		if not _text(f.get("name")) or typeof(f.get("notes")) != TYPE_STRING:
			errors.append(owner + ": name/notes fehlen")
		if not valid_span(f):
			errors.append(owner + ": ungültige Zeitspanne (Jahr 0 gibt es nicht)")
		var slots: Variant = f.get("slots")
		if typeof(slots) != TYPE_ARRAY or slots.is_empty():
			errors.append(owner + ": slots fehlen")
		else:
			for slot: Variant in slots:
				if not slot in LOADOUT_SLOTS:
					errors.append(owner + ": unbekannter Platz " + str(slot))
		var stats: Variant = f.get("design_stats")
		if typeof(stats) != TYPE_DICTIONARY:
			errors.append(owner + ": design_stats fehlt")
		else:
			for key in stats:
				if typeof(stats[key]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(stats[key])) or stats[key] < 0:
					errors.append(owner + ": design_stats." + str(key) + " ist keine Zahl")
		_check_sources(owner, f, errors, true)
	var drills: Dictionary = troops_doc.drills
	var authorities: Dictionary = troops_doc.authorities
	var appointments := {}
	for a: Variant in troops_doc.appointments:
		if typeof(a) != TYPE_DICTIONARY or not _identifier(a.get("appointment_id")):
			errors.append("appointments: Eintrag ohne gültige appointment_id")
			continue
		var owner: String = "Ernennung " + a.appointment_id
		if appointments.has(a.appointment_id):
			errors.append(owner + ": doppelt")
		appointments[a.appointment_id] = a
		if not _text(a.get("name")) or not _identifier(a.get("culture")) or not a.get("command_scope") in COMMAND_SCOPES:
			errors.append(owner + ": name, culture oder command_scope ungültig")
		if not valid_span(a):
			errors.append(owner + ": ungültige Zeitspanne")
		_check_sources(owner, a, errors, true)
	var troops := {}
	for t: Variant in troops_doc.troops:
		if typeof(t) != TYPE_DICTIONARY or not _identifier(t.get("troop_id")):
			errors.append("troops: Eintrag ohne gültige troop_id")
			continue
		if troops.has(t.troop_id):
			errors.append("Truppe %s: doppelt" % t.troop_id)
		troops[t.troop_id] = t
	for t: Dictionary in troops.values():
		_validate_troop(t, families, troops, drills, authorities, errors)
	if troops.is_empty():
		errors.append("troops: keine Einträge")
	var pools: Dictionary = people_doc.name_pools
	for pool_id in pools:
		var pool: Variant = pools[pool_id]
		var owner: String = "Namensliste " + str(pool_id)
		if typeof(pool) != TYPE_DICTIONARY or not pool.get("attestation") in ATTESTATIONS or typeof(pool.get("first")) != TYPE_ARRAY or pool.first.is_empty() or typeof(pool.get("family")) != TYPE_ARRAY:
			errors.append(owner + ": attestation, first oder family ungültig")
			continue
		for n: Variant in pool.first + pool.family:
			if not _text(n):
				errors.append(owner + ": leerer Name")
	var groups := {}
	for g: Variant in people_doc.population_groups:
		if typeof(g) != TYPE_DICTIONARY or not _identifier(g.get("group_id")):
			errors.append("population_groups: Eintrag ohne gültige group_id")
			continue
		var owner: String = "Herkunft " + g.group_id
		if groups.has(g.group_id):
			errors.append(owner + ": doppelt")
		groups[g.group_id] = true
		if not pools.has(g.get("names")) or typeof(g.get("places")) != TYPE_ARRAY or g.places.is_empty():
			errors.append(owner + ": names oder places ungültig")
		else:
			for p: Variant in g.places:
				if not _text(p):
					errors.append(owner + ": leerer Ort")
		_check_sources(owner, g, errors, true)
	return errors


static func _validate_troop(t: Dictionary, families: Dictionary, troops: Dictionary, drills: Dictionary, authorities: Dictionary, errors: Array[String]) -> void:
	var owner: String = "Truppe " + t.troop_id
	if not _text(t.get("name")) or not _identifier(t.get("culture")) or not t.get("service") in SERVICES or not _identifier(t.get("role")):
		errors.append(owner + ": name, culture, service oder role ungültig")
	if not valid_span(t):
		errors.append(owner + ": ungültige Zeitspanne (Jahr 0 gibt es nicht)")
		return
	if not is_integer(t.get("tier"), 1, 5) or not t.get("battle_kind") in BATTLE_KINDS:
		errors.append(owner + ": tier oder battle_kind ungültig")
	var loadout: Variant = t.get("loadout")
	if typeof(loadout) != TYPE_DICTIONARY or loadout.is_empty():
		errors.append(owner + ": loadout fehlt")
		return
	for slot in loadout:
		var item: Variant = loadout[slot]
		var where: String = "%s: loadout.%s" % [owner, slot]
		if not slot in LOADOUT_SLOTS or typeof(item) != TYPE_DICTIONARY:
			errors.append(where + ": unbekannter Platz")
			continue
		if not item.has("family_id"):
			errors.append(where + ": family_id fehlt")
			continue
		var family: Variant = families.get(item.family_id)
		if family == null:
			errors.append(where + ": unbekannte family_id " + str(item.family_id))
			continue
		if not slot in family.get("slots", []):
			errors.append(where + ": Familie passt nicht zu diesem Platz")
		if not is_integer(item.get("q_min"), 0, MAX_QUALITY) or not is_integer(item.get("q_max"), 0, MAX_QUALITY) or item.q_min > item.q_max:
			errors.append(where + ": Qualitätsspanne Q0–Q4 ungültig")
		if item.has("count") and not is_integer(item.count, 1, 12):
			errors.append(where + ": count ungültig")
		if item.has("ownership") and not item.ownership in OWNERSHIP:
			errors.append(where + ": ownership ungültig")
		for key in item:
			if not key in ["family_id", "q_min", "q_max", "count", "ownership"]:
				errors.append(where + ": unbekanntes Feld " + str(key))
		if valid_span(family) and (family.valid_from > t.valid_from or family.valid_to < t.valid_to):
			errors.append("%s: Familie %s gilt nicht für die gesamte Zeitspanne %s–%s" % [where, item.family_id, year_label(int(t.valid_from)), year_label(int(t.valid_to))])
	var kind: String = t.get("battle_kind", "")
	if KIND_WEAPONS.has(kind) and (not loadout.has("main_hand") or typeof(loadout.main_hand) != TYPE_DICTIONARY or not loadout.main_hand.get("family_id") in KIND_WEAPONS[kind]):
		errors.append(owner + ": battle_kind %s braucht passende Hauptwaffe" % kind)
	var trained: Variant = t.get("drills")
	if typeof(trained) != TYPE_DICTIONARY:
		errors.append(owner + ": drills fehlt")
	else:
		for drill in trained:
			if not drills.has(drill) or not is_integer(trained[drill], 0, 3):
				errors.append(owner + ": Drill %s ungültig" % str(drill))
	var visual: Variant = t.get("visual")
	if typeof(visual) != TYPE_DICTIONARY or not visual.get("battle_role") in BATTLE_ROLES or typeof(visual.get("meshy_loadout")) != TYPE_STRING:
		errors.append(owner + ": visual ungültig")
	if typeof(t.get("notes")) != TYPE_STRING or (t.get("attestation") == "design_assumption" and String(t.notes).strip_edges().is_empty()):
		errors.append(owner + ": notes fehlen (Designannahmen brauchen eine Begründung)")
	_check_sources(owner, t, errors, t.get("attestation") != "design_assumption")
	if t.has("variant_of") and not troops.has(t.variant_of):
		errors.append(owner + ": variant_of verweist auf keine Truppe")
	if t.has("rarity") and not t.rarity in ["common", "rare"]:
		errors.append(owner + ": rarity ungültig")
	if t.has("reconstruction") and (t.reconstruction != "artistic" or t.get("rarity") != "rare" or t.get("attestation") != "design_assumption"):
		errors.append(owner + ": künstlerische Rekonstruktion muss selten und als design_assumption gekennzeichnet sein")
	var upgrades: Variant = t.get("upgrades")
	if typeof(upgrades) != TYPE_ARRAY:
		errors.append(owner + ": upgrades fehlt")
		return
	for u: Variant in upgrades:
		if typeof(u) != TYPE_DICTIONARY or not troops.has(u.get("to")):
			errors.append(owner + ": Aufstieg ohne gültiges Ziel")
			continue
		var target: Dictionary = troops[u.to]
		var where: String = "%s → %s" % [owner, u.to]
		if not is_integer(u.get("xp"), 1, 100000) or not authorities.has(u.get("authority")):
			errors.append(where + ": xp oder authority ungültig")
		if target.get("culture") != t.culture or not is_integer(target.get("tier"), 1, 5) or not is_integer(t.get("tier"), 1, 5) or target.tier <= t.tier:
			errors.append(where + ": Ziel muss gleiche Kultur und höhere Stufe haben")
		if not valid_span(target) or target.valid_to < t.valid_from or target.valid_from > t.valid_to:
			errors.append(where + ": Zeitspannen überschneiden sich nicht")
			continue
		var overlap_from := maxi(int(t.valid_from), int(target.valid_from))
		var overlap_to := mini(int(t.valid_to), int(target.valid_to))
		var items: Variant = u.get("items")
		if typeof(items) != TYPE_ARRAY or items.is_empty():
			errors.append(where + ": Aufstieg ohne Gegenstand ist nicht erlaubt")
			continue
		for need: Variant in items:
			if typeof(need) != TYPE_DICTIONARY or not need.has("family_id"):
				errors.append(where + ": Gegenstand ohne family_id")
				continue
			var family: Variant = families.get(need.family_id)
			if family == null or not is_integer(need.get("q_min"), 0, MAX_QUALITY) or not is_integer(need.get("n"), 1, 12):
				errors.append(where + ": Gegenstand %s ungültig" % str(need.family_id))
			elif valid_span(family) and (family.valid_from > overlap_from or family.valid_to < overlap_to):
				errors.append(where + ": Familie %s gilt nicht in der gemeinsamen Zeitspanne" % need.family_id)


static func troop(catalog: Dictionary, troop_id: String) -> Dictionary:
	return catalog.troops.get(troop_id, {}).duplicate(true)


## Troop ids valid in this year, optionally limited to a culture and/or a service.
static func available(catalog: Dictionary, year: int, culture: String = "", service: String = "") -> Array[String]:
	var ids: Array[String] = []
	for t: Dictionary in catalog.troops.values():
		if valid_at(t, year) and (culture == "" or t.culture == culture) and (service == "" or t.service == service):
			ids.append(t.troop_id)
	ids.sort()
	return ids


static func families_of(catalog: Dictionary, troop_id: String) -> Array[String]:
	var ids: Array[String] = []
	for item: Dictionary in catalog.troops.get(troop_id, {}).get("loadout", {}).values():
		if not item.family_id in ids:
			ids.append(item.family_id)
	ids.sort()
	return ids


## The issued kit of a newly raised unit: each slot at its minimum quality.
static func resolve_loadout(catalog: Dictionary, troop_id: String) -> Dictionary:
	var kit := {}
	var entry: Dictionary = catalog.troops.get(troop_id, {})
	for slot in entry.get("loadout", {}):
		var item: Dictionary = entry.loadout[slot]
		kit[slot] = {"family_id": item.family_id, "quality": int(item.q_min), "count": int(item.get("count", 1))}
	return kit


## Experience a soldier of this troop has at least: the largest threshold of any upgrade into it.
static func entry_xp(catalog: Dictionary, troop_id: String) -> int:
	var xp := 0
	for t: Dictionary in catalog.troops.values():
		for u: Dictionary in t.upgrades:
			if u.to == troop_id:
				xp = maxi(xp, int(u.xp))
	return xp


static func _upgrade(catalog: Dictionary, from_id: String, to_id: String) -> Dictionary:
	for u: Dictionary in catalog.troops.get(from_id, {}).get("upgrades", []):
		if u.to == to_id:
			return u
	return {}


## Plans an upgrade without changing anything. inventory is an array of stacks
## {family_id, quality, count}; authorities lists who is present to grant it.
static func plan_upgrade(catalog: Dictionary, record: Dictionary, to_id: String, year: int, inventory: Array, authorities: Array) -> Dictionary:
	var from_id: String = str(record.get("troop_id", ""))
	var u := _upgrade(catalog, from_id, to_id)
	if u.is_empty():
		return {"ok": false, "message": "Kein Aufstiegsweg von %s nach %s." % [from_id, to_id], "take": []}
	if not valid_year(year) or not valid_at(catalog.troops[to_id], year):
		return {"ok": false, "message": "Die Zielstufe gibt es %s nicht." % (year_label(year) if valid_year(year) else "in diesem Jahr"), "take": []}
	if not is_integer(record.get("xp"), 0, 1000000) or int(record.xp) < int(u.xp):
		return {"ok": false, "message": "Zu wenig Erfahrung (%d von %d)." % [int(record.get("xp", 0)), int(u.xp)], "take": []}
	if not u.authority in authorities:
		return {"ok": false, "message": "Die nötige Befugnis (%s) fehlt." % u.authority, "take": []}
	var remaining := []
	for stack: Variant in inventory:
		if typeof(stack) != TYPE_DICTIONARY or not catalog.families.has(stack.get("family_id")) or not is_integer(stack.get("quality"), 0, MAX_QUALITY) or not is_integer(stack.get("count"), 1, 100000):
			return {"ok": false, "message": "Ungültiger Bestandseintrag.", "take": []}
		remaining.append(int(stack.count))
	var take := []
	for need: Dictionary in u.items:
		var wanted := int(need.n)
		# Use the lowest sufficient quality first, so better pieces stay in store.
		var order := []
		for i in range(inventory.size()):
			if inventory[i].family_id == need.family_id and int(inventory[i].quality) >= int(need.q_min):
				order.append([int(inventory[i].quality), i])
		order.sort()
		for pair: Array in order:
			var amount := mini(wanted, remaining[pair[1]])
			if amount > 0:
				remaining[pair[1]] -= amount
				wanted -= amount
				take.append({"index": pair[1], "family_id": need.family_id, "quality": pair[0], "count": amount})
		if wanted > 0:
			return {"ok": false, "message": "Es fehlt %d× %s ab Q%d." % [wanted, need.family_id, int(need.q_min)], "take": []}
	return {"ok": true, "message": "Aufstieg möglich.", "take": take}


## Applies an upgrade atomically. On success returns copies of the changed record and
## inventory; on failure the inputs are untouched and record/inventory are empty.
static func apply_upgrade(catalog: Dictionary, record: Dictionary, to_id: String, year: int, inventory: Array, authorities: Array) -> Dictionary:
	var plan := plan_upgrade(catalog, record, to_id, year, inventory, authorities)
	if not plan.ok:
		return {"ok": false, "message": plan.message, "record": {}, "inventory": [], "consumed": []}
	var stock := inventory.duplicate(true)
	for part: Dictionary in plan.take:
		stock[part.index].count = int(stock[part.index].count) - part.count
	var left := []
	for stack: Dictionary in stock:
		if int(stack.count) > 0:
			left.append(stack)
	var promoted := record.duplicate(true)
	promoted.troop_id = to_id
	var service: Array = promoted.get("service", []).duplicate(true)
	service.append({"event": "promoted", "ref": to_id, "year": year, "step": -1})
	promoted.service = service
	var consumed := []
	for part: Dictionary in plan.take:
		consumed.append({"family_id": part.family_id, "quality": part.quality, "count": part.count})
	return {"ok": true, "message": "Aufstieg zu %s." % catalog.troops[to_id].name, "record": promoted, "inventory": left, "consumed": consumed}
