extends RefCounted
## Deterministic founding of the city population: households in real houses,
## residents with age, origin, profession and workplace, and the businesses
## they own and staff. Everything derives from the seed, the activity anchors
## and the economy data; the same inputs always yield the same city.
##
## The result contains only JSON-safe integers, strings, booleans, arrays and
## dictionaries so a save file reproduces it exactly.

const Anchors = preload("res://scripts/domain/city_anchors.gd")
const Relations = preload("res://scripts/domain/actor_relations.gd")
const TIERS := ["poor", "common", "prosperous", "elite"]
const RELATION_SHARDS := 16
const MAX_KNOWN := 10
const ADULT_AGE := 16
const ELDER_AGE := 62
const PRAENOMINA := ["Gaius", "Lucius", "Marcus", "Publius", "Quintus", "Titus", "Aulus", "Gnaeus", "Decimus", "Sextus", "Manius", "Numerius", "Servius", "Spurius", "Tiberius", "Appius"]
const NOMINA := ["Aemilius", "Antonius", "Caecilius", "Calpurnius", "Cassius", "Claudius", "Cornelius", "Domitius", "Fabius", "Flavius", "Fulvius", "Horatius", "Iunius", "Licinius", "Livius", "Marius", "Octavius", "Papirius", "Pompeius", "Porcius", "Quinctius", "Rutilius", "Sempronius", "Sergius", "Servilius", "Sulpicius", "Terentius", "Tullius", "Valerius", "Vibius", "Volumnius", "Titius", "Mucius", "Atilius", "Furius", "Hostilius"]
const COGNOMINA := ["Rufus", "Niger", "Longus", "Crassus", "Paulus", "Felix", "Severus", "Maximus", "Priscus", "Celer", "Varus", "Balbus", "Naso", "Lentulus", "Flaccus", "Macer", "Pulcher", "Bassus", "Sabinus", "Tiro"]
const FEMALE_EXTRA := ["Maior", "Minor", "Tertia", "Prima", "Secunda", "Paulla", "Rufa", "Sabina", "Prisca", "Felicula"]
const FOREIGN := {
	"graecia": {"m": ["Nikias", "Philon", "Demetrios", "Xenon", "Andronikos", "Theodoros", "Apollonios", "Diodoros"], "f": ["Chloe", "Eirene", "Philista", "Nike", "Tryphaina", "Kallisto", "Doris", "Zosime"]},
	"gallia": {"m": ["Dumnorix", "Vercas", "Cintugnatos", "Litavos", "Sennos", "Togirix"], "f": ["Esuvia", "Sennia", "Ategnia", "Lituma", "Divica", "Cintusma"]},
	"hispania": {"m": ["Reburrus", "Tancinus", "Ambatus", "Caturo", "Boutius", "Pintamus"], "f": ["Ammia", "Sunua", "Boutia", "Camala", "Docia", "Tangina"]},
	"africa": {"m": ["Hanno", "Mago", "Bodmelqart", "Iddibal", "Masgaba", "Gisgo"], "f": ["Sophonisba", "Arishat", "Namgidde", "Muttunbal", "Tanit", "Elissa"]},
	"syria": {"m": ["Malchus", "Bargates", "Zabdas", "Abdes", "Sampsigeramus", "Iamblichos"], "f": ["Martha", "Thaime", "Amath", "Bathnanaia", "Salome", "Zabda"]},
	"germania": {"m": ["Segimer", "Gandrik", "Ansgar", "Wulfila", "Haribert", "Theudo"], "f": ["Albruna", "Gunda", "Thusna", "Waluburg", "Hilda", "Ansa"]}
}
## Share of non-Italic origins per wealth tier, in percent.
const FOREIGN_SHARE := [34, 18, 8, 4]
const FOREIGN_ORDER := ["graecia", "gallia", "hispania", "africa", "syria", "germania"]
const FOREIGN_WEIGHT := [34, 18, 14, 12, 14, 8]


static func mix(a: int, b: int, c: int = 0, d: int = 0) -> int:
	var h := (a * 0x9E3779B1 + b * 0x85EBCA77 + c * 0xC2B2AE3D + d * 0x27D4EB2F + 0x165667B1) & 0xFFFFFFFF
	h ^= h >> 15
	h = (h * 0x2C1B3C6D) & 0xFFFFFFFF
	h ^= h >> 12
	h = (h * 0x297A2D39) & 0xFFFFFFFF
	h ^= h >> 15
	return h


static func fnv(text: String) -> int:
	var h := 2166136261
	for byte: int in text.to_utf8_buffer():
		h = ((h ^ byte) * 16777619) & 0xFFFFFFFF
	return h


static func between(h: int, low: int, high: int) -> int:
	return low + h % (high - low + 1)


static func resident_id(index: int) -> String:
	return "c%04d" % index


## Founds the population. `anchor_ids` are the anchors usable in `year`.
static func found(seed: int, index: Dictionary, anchor_ids: Array, economy: Dictionary, year: int) -> Dictionary:
	var state := {"residents": [], "households": [], "businesses": [], "relations": []}
	for shard in RELATION_SHARDS:
		state.relations.append(Relations.new_graph())
	var homes: Array[String] = []
	var stalls: Array[String] = []
	var workshops: Array[String] = []
	for id: String in anchor_ids:
		var anchor: Dictionary = index.anchors[id]
		match anchor.kind:
			"doorway":
				if not Anchors.tag_value(anchor, "house").is_empty():
					homes.append(id)
			"stall":
				stalls.append(id)
			"workshop":
				workshops.append(id)
	# Households, in house order.
	for home: String in homes:
		var anchor: Dictionary = index.anchors[home]
		var house := Anchors.tag_value(anchor, "house")
		var h := mix(seed, fnv(home), 1)
		match house:
			"insula":
				for flat in 5:
					_household(state, seed, home, 0 if mix(h, flat, 2) % 100 < 55 else 1, year, economy)
					state.households[-1].rented = true
			"artisan":
				_household(state, seed, home, 1, year, economy)
			"domus":
				_household(state, seed, home, 2, year, economy)
			"atrium":
				_household(state, seed, home, 2 if h % 100 < 50 else 3, year, economy)
			"villa":
				_household(state, seed, home, 3, year, economy)
	_businesses(state, seed, index, stalls, workshops, economy)
	_employment(state, seed, index, economy)
	_landlords(state, seed)
	_acquaintances(state, seed)
	return state


static func _household(state: Dictionary, seed: int, home: String, tier: int, year: int, economy: Dictionary) -> void:
	var hh_index: int = state.households.size()
	var h := mix(seed, hh_index, 11)
	var funds_range: Array = economy.start_funds[tier]
	var household := {"id": "h%03d" % hh_index, "home": home, "tier": tier, "members": [],
		"funds": between(mix(h, 1), int(funds_range[0]), int(funds_range[1])),
		"pantry": {"staple": 0, "side": 0}, "due": {}, "landlord": -1, "owns": [], "hungry_days": 0, "name": "",
		"rented": false, "arrears": 0, "shopper": -1, "water_day": -1, "fed_day": -1}
	state.households.append(household)
	var origin := "italia"
	if mix(h, 2) % 100 < int(FOREIGN_SHARE[tier]):
		var roll := mix(h, 3) % 100
		for slot in FOREIGN_ORDER.size():
			roll -= int(FOREIGN_WEIGHT[slot])
			if roll < 0:
				origin = FOREIGN_ORDER[slot]
				break
	var nomen: String = NOMINA[mix(h, 4) % NOMINA.size()]
	household.name = nomen if origin == "italia" else origin
	var single := tier == 0 and mix(h, 5) % 100 < 30
	var head_age := between(mix(h, 6), 22, 54)
	var head_female := single and mix(h, 7) % 100 < 40
	var head := _person(state, seed, hh_index, head_female, head_age, origin, nomen, year, tier)
	if not single:
		var spouse := _person(state, seed, hh_index, not head_female, clampi(head_age - between(mix(h, 8), -2, 8), 17, 60), origin, nomen, year, tier)
		state.residents[head].spouse = spouse
		state.residents[spouse].spouse = head
	var children := between(mix(h, 9), 0, 3) if not single else between(mix(h, 9), 0, 1)
	for child in children:
		var age := between(mix(h, 20 + child), 1, maxi(2, mini(17, head_age - 18)))
		_person(state, seed, hh_index, mix(h, 30 + child) % 2 == 0, age, origin, nomen, year, tier)
	if mix(h, 10) % 100 < (20 if tier == 0 else 30):
		_person(state, seed, hh_index, mix(h, 12) % 2 == 0, between(mix(h, 13), 62, 78), origin, nomen, year, tier)
	# Dependents of wealthy houses (the familia). Their legal status is data;
	# see docs/29_living_city for the open owner decision on portrayal.
	var dependents := 0 if tier < 2 else (2 if tier == 2 else 4)
	for extra in dependents:
		var d := mix(h, 40 + extra)
		var from: String = FOREIGN_ORDER[d % FOREIGN_ORDER.size()] if d % 100 < 70 else "italia"
		var who := _person(state, seed, hh_index, mix(d, 1) % 2 == 0, between(mix(d, 2), 17, 48), from, nomen, year, 0)
		state.residents[who].role = "servant"
		state.residents[who].dependent = true


static func _person(state: Dictionary, seed: int, hh: int, female: bool, age: int, origin: String, nomen: String, year: int, tier: int) -> int:
	var index: int = state.residents.size()
	var h := mix(seed, index, 21)
	var name := ""
	if origin == "italia":
		if female:
			name = nomen.trim_suffix("us") + "a"
			if h % 3 != 0:
				name += " " + FEMALE_EXTRA[mix(h, 1) % FEMALE_EXTRA.size()]
		else:
			name = "%s %s" % [PRAENOMINA[mix(h, 1) % PRAENOMINA.size()], nomen]
			if h % 2 == 0:
				name += " " + COGNOMINA[mix(h, 2) % COGNOMINA.size()]
	else:
		var pool: Array = FOREIGN[origin]["f" if female else "m"]
		name = pool[mix(h, 1) % pool.size()]
	var role := "child" if age < ADULT_AGE else ("elder" if age >= ELDER_AGE else "adult")
	state.residents.append({
		"name": name, "female": female, "birth_year": _birth_year(year, age), "origin": origin, "hh": hh,
		"tier": tier, "role": role, "job": -1, "work": "", "spouse": -1, "dependent": false,
		"look": mix(h, 3) % 100000, "voice": mix(h, 4) % 4,
		# sociable, diligent, pious, thrifty, bold: 0..100
		"traits": [between(mix(h, 5), 15, 95), between(mix(h, 6), 25, 95), between(mix(h, 7), 5, 90), between(mix(h, 8), 10, 95), between(mix(h, 9), 5, 95)],
		# Needs are timestamps of the last time they were met (seconds, may be negative).
		"ate": -between(mix(h, 10), 3600, 14400), "talked": -between(mix(h, 11), 0, 100000), "prayed": -between(mix(h, 12), 0, 300000),
		"act": "home", "at": state.households[hh].home, "prev": state.households[hh].home, "dep": 0, "arr": 0, "until": 0,
		"step": 0, "n": 0, "bag": {}, "purse": 0, "with": -1, "slot": -1, "wake": 0, "errand": {}, "worked": 0, "unpaid": 0, "heard": 0, "known": []})
	state.households[hh].members.append(index)
	return index


static func _birth_year(year: int, age: int) -> int:
	var Calendar := preload("res://scripts/domain/world_calendar.gd")
	return Calendar.birth_year_for_age(age, year)


static func age_of(resident: Dictionary, year: int) -> int:
	var Calendar := preload("res://scripts/domain/world_calendar.gd")
	return Calendar.age_in_year(int(resident.birth_year), year)


static func _businesses(state: Dictionary, seed: int, index: Dictionary, stalls: Array, workshops: Array, economy: Dictionary) -> void:
	var sites: Array[String] = []
	sites.append_array(stalls)
	sites.append_array(workshops)
	for site: String in sites:
		var anchor: Dictionary = index.anchors[site]
		var type := Anchors.tag_value(anchor, "business")
		if not economy.business_types.has(type):
			continue
		var definition: Dictionary = economy.business_types[type]
		var number: int = state.businesses.size()
		var queue := site
		if anchor.kind == "stall":
			var candidate := site.replace(".stall_", ".queue_")
			if index.anchors.has(candidate):
				queue = candidate
		var stock := {}
		var price := {}
		var sold := {}
		for good: String in definition.get("sells", {}):
			stock[good] = int(definition.sells[good]) if not definition.has("produces") else int(definition.sells[good]) / 2
			price[good] = int(economy.goods[good].price)
			sold[good] = 0
		for good: String in definition.get("produces", {}):
			if not stock.has(good):
				stock[good] = 0
				price[good] = int(economy.goods[good].price)
				sold[good] = 0
		state.businesses.append({"id": "b%03d" % number, "type": type, "name": str(definition.name), "anchor": site, "queue": queue,
			"owner": -1, "staff": [], "till": 0, "stock": stock, "price": price, "sold": sold, "open": [anchor.hours[0], anchor.hours[1]],
			"worked": 0, "order": {}, "order_state": "", "porter": -1, "shop": Anchors.tag_value(anchor, "shop"),
			"node": Anchors.tag_value(anchor, "stall_node"), "building": Anchors.tag_value(anchor, "building"),
			"made": {}, "closed_days": 0})


static func _employment(state: Dictionary, seed: int, index: Dictionary, economy: Dictionary) -> void:
	# Artisan workshops belong to the household living in that house.
	var by_building := {}
	for hh in state.households.size():
		var building := Anchors.tag_value(index.anchors[state.households[hh].home], "building")
		if not by_building.has(building):
			by_building[building] = hh
	var free_adults: Array[int] = []
	for person in state.residents.size():
		var resident: Dictionary = state.residents[person]
		if resident.role == "adult":
			free_adults.append(person)
	var taken := {}
	for number in state.businesses.size():
		var business: Dictionary = state.businesses[number]
		var definition: Dictionary = economy.business_types[business.type]
		var staff_wanted := int(definition.staff)
		var owner_hh := -1
		if by_building.has(business.building) and str(business.anchor).begins_with("workshop.artisan_"):
			owner_hh = by_building[business.building]
		else:
			# Stalls and the large workshops are owned by common households.
			for attempt in state.households.size():
				var candidate: int = (mix(seed, number, 31) + attempt * 7919) % int(state.households.size())
				var household: Dictionary = state.households[candidate]
				if int(household.tier) == 1 and household.owns.is_empty() and _first_free(state, household, taken) >= 0:
					owner_hh = candidate
					break
		if owner_hh < 0:
			continue
		business.owner = owner_hh
		state.households[owner_hh].owns.append(number)
		business.till = 400
		for member: int in state.households[owner_hh].members:
			if business.staff.size() >= staff_wanted:
				break
			if state.residents[member].role == "adult" and not taken.has(member):
				_hire(state, business, number, member, "vendor" if business.anchor.contains(".stall_") else "craft")
				taken[member] = true
	# Open positions go to poor and common adults, nearest index first so the
	# result does not depend on dictionary order.
	for number in state.businesses.size():
		var business: Dictionary = state.businesses[number]
		if int(business.owner) < 0:
			continue
		var wanted := int(economy.business_types[business.type].staff)
		var cursor: int = mix(seed, number, 37) % free_adults.size()
		var looked := 0
		while business.staff.size() < wanted and looked < free_adults.size():
			var person: int = free_adults[(cursor + looked) % free_adults.size()]
			looked += 1
			var resident: Dictionary = state.residents[person]
			if taken.has(person) or int(resident.tier) > 1 or resident.dependent:
				continue
			_hire(state, business, number, person, "vendor" if business.anchor.contains(".stall_") else "craft")
			taken[person] = true
	# Public and casual roles.
	var guards := 0
	var porters := 0
	var beggars := 0
	for person: int in free_adults:
		var resident: Dictionary = state.residents[person]
		if taken.has(person) or resident.dependent:
			continue
		var h := mix(seed, person, 41)
		var tier := int(resident.tier)
		var household: Dictionary = state.households[resident.hh]
		var other_earner := false
		for member: int in household.members:
			if member != person and state.residents[member].role in ["vendor", "craft", "guard", "porter", "labourer", "patron"]:
				other_earner = true
		if tier >= 2:
			resident.role = "patron" if not resident.female else "matron"
		elif not resident.female and guards < 22 and h % 100 < 12:
			resident.role = "guard"
			guards += 1
		elif not resident.female and porters < 26 and tier == 0 and h % 100 < 30:
			resident.role = "porter"
			porters += 1
		elif tier == 0 and beggars < 9 and household.members.size() == 1 and h % 100 < 45:
			resident.role = "beggar"
			beggars += 1
		elif other_earner and _has_child(state, household):
			resident.role = "homemaker"
		elif resident.female and other_earner and h % 100 < 60:
			resident.role = "homemaker"
		else:
			resident.role = "labourer"


static func _first_free(state: Dictionary, household: Dictionary, taken: Dictionary) -> int:
	for member: int in household.members:
		if state.residents[member].role == "adult" and not taken.has(member):
			return member
	return -1


static func _has_child(state: Dictionary, household: Dictionary) -> bool:
	for member: int in household.members:
		if state.residents[member].role == "child":
			return true
	return false


static func _hire(state: Dictionary, business: Dictionary, number: int, person: int, role: String) -> void:
	business.staff.append(person)
	state.residents[person].role = role
	state.residents[person].job = number
	state.residents[person].work = business.anchor


static func _landlords(state: Dictionary, seed: int) -> void:
	var owners: Array[int] = []
	for hh in state.households.size():
		if int(state.households[hh].tier) == 3:
			owners.append(hh)
	if owners.is_empty():
		return
	# One elite household owns each insula; every flat in it pays that owner.
	var by_home := {}
	for hh in state.households.size():
		var household: Dictionary = state.households[hh]
		if not household.rented:
			continue
		if not by_home.has(household.home):
			by_home[household.home] = owners[mix(seed, by_home.size(), 51) % owners.size()]
		household.landlord = by_home[household.home]


## Neighbours and colleagues already know each other when the game starts.
static func _acquaintances(state: Dictionary, seed: int) -> void:
	var by_home := {}
	for person in state.residents.size():
		var resident: Dictionary = state.residents[person]
		if resident.role == "child":
			continue
		var home: String = state.households[resident.hh].home
		if not by_home.has(home):
			by_home[home] = []
		by_home[home].append(person)
	for person in state.residents.size():
		var resident: Dictionary = state.residents[person]
		if resident.role == "child":
			continue
		var pool: Array = by_home[state.households[resident.hh].home]
		var made := 0
		for attempt in 4:
			var other: int = pool[mix(seed, person, 61 + attempt) % pool.size()]
			if other == person or int(state.residents[other].hh) == int(resident.hh) or made >= 2:
				continue
			meet(state, person, other, "founding:neighbour", 0, "neighbour", 8 + mix(seed, person, 71 + attempt) % 22)
			made += 1
		if int(resident.job) >= 0:
			for mate: int in state.businesses[resident.job].staff:
				if mate != person:
					meet(state, person, mate, "founding:colleague", 0, "colleague", 14 + mix(seed, person, 81) % 20)


static func graph_for(state: Dictionary, observer: int) -> Dictionary:
	return state.relations[observer % RELATION_SHARDS]


## Directed: the observer's feelings about the subject change. A resident
## keeps at most MAX_KNOWN acquaintances; a chat with one more stranger then
## leaves no lasting relation, which also bounds the relation graph.
static func meet(state: Dictionary, observer: int, subject: int, event_id: String, tick: int, kind: String, trust: int) -> void:
	var known: Array = state.residents[observer].known
	if not known.has(subject):
		if known.size() >= MAX_KNOWN:
			return
		known.append(subject)
	Relations.apply(graph_for(state, observer), resident_id(observer), resident_id(subject), event_id, tick, kind, {"trust": float(trust)})


static func trust(state: Dictionary, observer: int, subject: int) -> float:
	return Relations.value(graph_for(state, observer), resident_id(observer), resident_id(subject), "trust")


static func knows(state: Dictionary, observer: int, subject: int) -> bool:
	return Relations.knows(graph_for(state, observer), resident_id(observer), resident_id(subject))
