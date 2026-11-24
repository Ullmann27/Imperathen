extends RefCounted
## Named people are assigned once. Production, food and repair share real elapsed time.
## Owns data.village.economy; all spendable goods remain in data.resources.

const Abilities = preload("res://scripts/story/chapter_abilities.gd")
const DAY_SECONDS := 120.0
const MAX_RESOURCE := 1000000
const EPSILON := 0.000001

static func day_length(data: Dictionary) -> float:
	# Active economic time is independent from explicitly ended narrative days.
	return 3600.0 if data.get("village",{}).has("childhood") else DAY_SECONDS

const RESOURCE_KEYS := ["wood", "grain", "denarii", "stone"]
const COMMAND_FIELDS := {
	"village_request_work": [],
	"village_assign": ["resident_id", "workplace_id"],
	"village_repair": ["workplace_id"],
	"village_shift": ["resident_id", "duty"],
	"village_buy_food": [],
	"village_resow": []
}
const PEOPLE := [
	{"id":"aelia", "name":"Aelia", "profession":"Steinmetzin"},
	{"id":"varro", "name":"Varro", "profession":"Späher und Jäger"},
	{"id":"vibius", "name":"Vibius", "profession":"Feldarbeiter"},
	{"id":"aurelia", "name":"Aurelia", "profession":"Heilerin"},
	{"id":"fabius", "name":"Fabius", "profession":"Holzfäller"},
	{"id":"cassia", "name":"Cassia", "profession":"Händlerin"},
	{"id":"quintus", "name":"Quintus", "profession":"Steinbrecher"},
	{"id":"drusa", "name":"Drusa", "profession":"Zimmerin"},
	{"id":"julia", "name":"Julia", "profession":"Bäuerin"},
	{"id":"silvanus", "name":"Silvanus", "profession":"Lastenträger"},
	{"id":"severus", "name":"Severus", "profession":"Wachausbilder"},
	{"id":"valeria", "name":"Valeria", "profession":"Wächterin"},
	{"id":"antonia", "name":"Antonia", "profession":"Töpferin"},
	{"id":"sextus", "name":"Sextus", "profession":"Bauarbeiter"}
]
const WORKPLACES := {
	"farm": {"name":"Dorffelder", "required":2, "period":30.0, "resource":"grain", "yield":6, "stock":"harvest", "repair_wood":4, "repair_stone":0, "repair_seconds":30.0},
	"woodcamp": {"name":"Holzfällerlager", "required":2, "period":30.0, "resource":"wood", "yield":8, "stock":"forest", "repair_wood":8, "repair_stone":0, "repair_seconds":30.0},
	"quarry": {"name":"Steinbruch", "required":4, "period":40.0, "resource":"stone", "yield":6, "stock":"rock", "repair_wood":12, "repair_stone":0, "repair_seconds":40.0},
	"trade": {"name":"Handelsplatz", "required":2, "period":60.0, "resource":"denarii", "yield":6, "stock":"merchant_denarii", "repair_wood":8, "repair_stone":4, "repair_seconds":40.0},
	"watchpost": {"name":"Stadtposten", "required":2, "period":60.0, "resource":"", "yield":0, "stock":"", "repair_wood":8, "repair_stone":8, "repair_seconds":30.0}
}


static func initial_state() -> Dictionary:
	var people: Array = []
	for entry in PEOPLE:
		var person: Dictionary = entry.duplicate(true)
		person.merge({"assignment":"idle", "previous_assignment":"idle", "health":100, "hunger":0, "alive":true})
		if person.id in ["vibius", "julia"]:
			person.assignment = "farm"
		if person.id in ["severus", "valeria"]:
			person.assignment = "watchpost"
		people.append(person)
	var workplaces: Dictionary = {}
	for key in WORKPLACES:
		workplaces[key] = {"condition": {"farm":100, "woodcamp":40, "quarry":20, "trade":0, "watchpost":60}[key], "cycle_seconds":0.0, "produced_cycles":0, "project":{}}
	return {
		"version":1, "people":people, "workplaces":workplaces,
		"authority":{"id":"decimus", "name":"Verwalter Decimus", "player_is_ruler":false, "work_permit":false},
		"stocks":{"forest":240, "rock":180, "harvest":240, "merchant_denarii":600, "emergency_grain":64},
		"ledger":{"wood":0, "grain":0, "denarii":0, "stone":0},
		"day":0, "day_seconds":0.0, "meal_offset":0, "meals_served":0,
		"grain_shortfall":0, "patrols_completed":0, "repair_count":0,
		"last_report":"Das Dorf wird von Decimus verwaltet. Sprich mit ihm über den Wiederaufbau."
	}


static func ensure(data: Dictionary) -> void:
	if not data.has("village"):
		data.village = {}
	if typeof(data.village) != TYPE_DICTIONARY:
		return
	if not data.village.has("economy"):
		data.village.economy = initial_state()
	if data.has("resources") and typeof(data.resources) == TYPE_DICTIONARY and not data.resources.has("stone"):
		data.resources.stone = 0


static func execute(data: Dictionary, command: String, args: Dictionary = {}) -> Dictionary:
	if not COMMAND_FIELDS.has(command) or not _exact_keys(args, COMMAND_FIELDS[command]):
		return _fail("Unbekannter Dorfauftrag oder unvollständige Angaben.")
	for value in args.values():
		if typeof(value) != TYPE_STRING or value.length() > 48:
			return _fail("Personen und Arbeitsplätze benötigen gültige Kennungen.")
	var error := validate(data)
	if not error.is_empty():
		return _fail("Ungültiger Dorfzustand: " + error)
	# Transactional even when called outside the WorldModel's transaction wrapper.
	var candidate := _transaction_copy(data)
	var result := _execute(candidate, command, args)
	if not result.ok:
		return result
	error = validate(candidate)
	if not error.is_empty():
		return _fail("Der Dorfauftrag wurde verworfen: " + error)
	data.resources = candidate.resources
	data.village.economy = candidate.village.economy
	return result


static func _execute(data: Dictionary, command: String, args: Dictionary) -> Dictionary:
	var economy: Dictionary = data.village.economy
	if command == "village_request_work":
		if economy.authority.work_permit:
			return _fail("Decimus hat dir die Mitarbeit bereits erlaubt.")
		var social: Variant = data.village.get("social", {})
		var npcs: Variant = social.get("npcs", {}) if typeof(social) == TYPE_DICTIONARY else {}
		var steward: Variant = npcs.get("decimus", {}) if typeof(npcs) == TYPE_DICTIONARY else {}
		var met: bool = typeof(steward) == TYPE_DICTIONARY and steward.get("met", false) == true
		if not met:
			return _fail("Sprich zuerst mit Verwalter Decimus. Er trägt die Verantwortung für das Dorf.")
		economy.authority.work_permit = true
		return _ok("Decimus erlaubt dir, freiwillige Helfer und die Reparaturen zu koordinieren. Er bleibt Verwalter.")
	if not economy.authority.work_permit:
		return _fail("Decimus muss deiner Mitarbeit zuerst zustimmen.")
	match command:
		"village_assign":
			var person := _person(economy, args.resident_id)
			if person.is_empty() or not person.alive:
				return _fail("Diese Person kann keinen Arbeitsauftrag annehmen.")
			if person.assignment == "defense":
				return _fail("Diese Person steht im Verteidigungsdienst. Beende zuerst ihren Dienst.")
			if args.workplace_id != "idle" and not WORKPLACES.has(args.workplace_id):
				return _fail("Diesen Arbeitsplatz gibt es nicht.")
			if person.assignment == args.workplace_id:
				return _fail("Diese Person ist dort bereits eingeteilt.")
			if args.workplace_id != "idle" and _assigned(economy, args.workplace_id) >= int(WORKPLACES[args.workplace_id].required):
				return _fail("Alle Stellen sind besetzt. Löse zuerst eine bisherige Einteilung.")
			person.assignment = args.workplace_id
			person.previous_assignment = "idle"
			return _ok("%s hilft jetzt bei: %s." % [person.name, "Reserve" if args.workplace_id == "idle" else WORKPLACES[args.workplace_id].name])
		"village_shift":
			var person := _person(economy, args.resident_id)
			if person.is_empty() or not person.alive or args.duty not in ["defense", "return"]:
				return _fail("Ungültiger Verteidigungsdienst.")
			if args.duty == "defense":
				if person.assignment == "defense":
					return _fail("Diese Person verteidigt das Dorf bereits.")
				if not _fit(person):
					return _fail("Diese Person benötigt erst Nahrung oder Erholung.")
				person.previous_assignment = person.assignment
				person.assignment = "defense"
				return _ok("%s schließt sich der Verteidigung an und fehlt am bisherigen Arbeitsplatz." % person.name)
			if person.assignment != "defense":
				return _fail("Diese Person steht nicht im Verteidigungsdienst.")
			if _raid_active(data):
				return _fail("Während des Überfalls kann die Verteidigung nicht verlassen werden.")
			var previous: String = person.previous_assignment
			person.assignment = previous if previous != "idle" and _assigned(economy, previous) < int(WORKPLACES[previous].required) else "idle"
			person.previous_assignment = "idle"
			return _ok("%s kehrt %s." % [person.name, "an den bisherigen Arbeitsplatz zurück" if person.assignment != "idle" else "in die Reserve zurück; der bisherige Platz ist inzwischen besetzt"])
		"village_repair":
			if not WORKPLACES.has(args.workplace_id):
				return _fail("Diesen Betrieb gibt es nicht.")
			var workplace: Dictionary = economy.workplaces[args.workplace_id]
			if int(workplace.condition) >= 100:
				return _fail("Dieser Betrieb ist bereits vollständig instand gesetzt.")
			if not workplace.project.is_empty():
				return _fail("Hier läuft bereits ein Arbeitsauftrag.")
			var cost := repair_cost(economy, args.workplace_id)
			if int(data.resources.wood) < int(cost.wood) or int(data.resources.stone) < int(cost.stone):
				return _fail("Die Reparatur braucht %d Holz und %d Stein." % [cost.wood, cost.stone])
			_transfer(data, "wood", -int(cost.wood))
			_transfer(data, "stone", -int(cost.stone))
			workplace.project = {"kind":"repair", "remaining":float(WORKPLACES[args.workplace_id].repair_seconds), "total":float(WORKPLACES[args.workplace_id].repair_seconds)}
			return _ok("Material bereitgestellt. %s benötigt %d arbeitsfähige Helfer für die Reparatur." % [WORKPLACES[args.workplace_id].name, WORKPLACES[args.workplace_id].required])
		"village_buy_food":
			if int(economy.stocks.emergency_grain) < 16:
				return _fail("Der örtliche Notvorrat ist erschöpft.")
			var price := emergency_food_price(data)
			if int(data.resources.denarii) < price or int(data.resources.grain) > MAX_RESOURCE - 16:
				return _fail("Eine Notration braucht %d Denare und Platz für 16 Getreide." % price)
			economy.stocks.emergency_grain -= 16
			_transfer(data, "denarii", -price)
			_transfer(data, "grain", 16)
			return _ok("16 Getreide aus dem begrenzten Notvorrat gekauft; %d Denare bezahlt." % price)
		"village_resow":
			var farm: Dictionary = economy.workplaces.farm
			if int(economy.stocks.harvest) != 0 or int(farm.condition) < 100 or not farm.project.is_empty():
				return _fail("Nachsäen ist erst auf abgeernteten, instand gesetzten Feldern möglich.")
			if int(data.resources.grain) < 4:
				return _fail("Für die neue Aussaat fehlen 4 Getreide.")
			_transfer(data, "grain", -4)
			farm.project = {"kind":"sow", "remaining":day_length(data), "total":day_length(data)}
			return _ok("4 Getreide ausgesät. Zwei Feldarbeiter benötigen einen Dorftag bis zur nächsten Ernte.")
	return _fail("Dieser Dorfauftrag wird nicht unterstützt.")


static func advance(data: Dictionary, delta: float) -> bool:
	if not is_finite(delta) or delta <= 0.0 or delta > 3600.0 or not validate(data).is_empty():
		return false
	var candidate := _transaction_copy(data)
	_advance(candidate, delta)
	if not validate(candidate).is_empty():
		return false
	data.resources = candidate.resources
	data.village.economy = candidate.village.economy
	return true


static func _advance(data: Dictionary, delta: float) -> void:
	var economy: Dictionary = data.village.economy
	var remaining := delta
	while remaining > 0.0:
		var step := minf(remaining, day_length(data) - float(economy.day_seconds))
		var work_modes: Dictionary = {}
		for id in WORKPLACES:
			var place: Dictionary = economy.workplaces[id]
			work_modes[id] = "idle"
			if not place.project.is_empty() and _crew_reason(data, id).is_empty():
				work_modes[id] = "project"
				step = minf(step, float(place.project.remaining))
			elif _production_reason(data, id).is_empty():
				work_modes[id] = "production"
				step = minf(step, float(WORKPLACES[id].period) - float(place.cycle_seconds))
		# Completed boundaries are consumed in this iteration, including floating-point residue.
		step = maxf(0.0, step)
		economy.day_seconds = float(economy.day_seconds) + step
		for id in WORKPLACES:
			var place: Dictionary = economy.workplaces[id]
			if work_modes[id] == "project":
				if not place.project.is_empty():
					place.project.remaining = maxf(0.0, float(place.project.remaining) - step)
					if float(place.project.remaining) <= EPSILON:
						if place.project.kind == "repair":
							place.condition = 100
							economy.repair_count += 1
							economy.last_report = "%s ist wieder betriebsbereit." % WORKPLACES[id].name
						else:
							economy.stocks.harvest = 120
							economy.last_report = "Die neue Aussaat ist erntereif."
						place.project = {}
			elif work_modes[id] == "production":
				place.cycle_seconds = float(place.cycle_seconds) + step
				if float(place.cycle_seconds) + EPSILON >= float(WORKPLACES[id].period):
					place.cycle_seconds = 0.0
					_produce(data, id)
		if float(economy.day_seconds) + EPSILON >= day_length(data):
			economy.day_seconds = 0.0
			economy.day += 1
			_meal(data)
		remaining -= step


static func _transaction_copy(data: Dictionary) -> Dictionary:
	# Other systems are observed only. Copy just the two owned mutable subtrees.
	var candidate := data.duplicate(false)
	candidate.resources = data.resources.duplicate(true)
	candidate.village = data.village.duplicate(false)
	candidate.village.economy = data.village.economy.duplicate(true)
	return candidate


static func _produce(data: Dictionary, id: String) -> void:
	var economy: Dictionary = data.village.economy
	var spec: Dictionary = WORKPLACES[id]
	economy.workplaces[id].produced_cycles += 1
	if id == "watchpost":
		economy.patrols_completed += 1
		return
	if id == "trade":
		_transfer(data, "wood", -4)
	var amount := _yield_for(data, id)
	economy.stocks[spec.stock] -= amount
	_transfer(data, spec.resource, amount)


static func _meal(data: Dictionary) -> void:
	var economy: Dictionary = data.village.economy
	var served := 0
	var shortfall := 0
	for offset in economy.people.size():
		var person: Dictionary = economy.people[(int(economy.meal_offset) + offset) % economy.people.size()]
		if not person.alive:
			continue
		if int(data.resources.grain) > 0:
			_transfer(data, "grain", -1)
			person.hunger = maxi(0, int(person.hunger) - 1)
			var recovery := 5 if person.assignment == "idle" else 1
			if person.assignment == "idle" and _profession(data) == "healer":
				recovery += 2
			person.health = mini(100, int(person.health) + recovery)
			served += 1
		else:
			person.hunger = mini(3, int(person.hunger) + 1)
			shortfall += 1
	economy.meal_offset = (int(economy.meal_offset) + maxi(1, served)) % economy.people.size()
	economy.meals_served += served
	economy.grain_shortfall = shortfall
	economy.last_report = "Tag %d: %d versorgt; %d ohne Ration." % [int(economy.day) + 1, served, shortfall]


static func view(data: Dictionary) -> Dictionary:
	if not validate(data).is_empty():
		return {"valid":false, "message":"Der Dorfzustand ist nicht lesbar."}
	var economy: Dictionary = data.village.economy
	var places: Array = []
	for id in WORKPLACES:
		var spec: Dictionary = WORKPLACES[id]
		var place: Dictionary = economy.workplaces[id]
		var people: Array = []
		for person in economy.people:
			if person.assignment == id and person.alive:
				people.append(person.id)
		var reason := _production_reason(data, id)
		var project_progress := 0.0
		if not place.project.is_empty():
			project_progress = 1.0 - float(place.project.remaining) / float(place.project.total)
			var crew_reason := _crew_reason(data, id)
			reason = "Reparatur läuft" if crew_reason.is_empty() else "Reparatur wartet: " + crew_reason
			if place.project.kind == "sow":
				reason = "Aussaat wächst" if crew_reason.is_empty() else "Aussaat wartet: " + crew_reason
		places.append({"id":id, "name":spec.name, "required":spec.required, "assigned":people.size(), "available":_available(data, id), "people":people, "condition":place.condition, "working":reason.is_empty(), "reason":reason, "project_progress":project_progress, "project":place.project.duplicate(true), "cycle_progress":float(place.cycle_seconds) / float(spec.period), "repair_cost":repair_cost(economy,id), "yield_per_cycle":_yield_for(data,id), "resource":spec.resource})
	var population := {"alive":0, "idle":0, "working":0, "defense":0, "unfit":0}
	for person in economy.people:
		if not person.alive:
			continue
		population.alive += 1
		if person.assignment == "idle":
			population.idle += 1
		elif person.assignment == "defense":
			population.defense += 1
		else:
			population.working += 1
		if not _fit(person):
			population.unfit += 1
	return {"valid":true, "authority":economy.authority.duplicate(true), "day":int(economy.day)+1, "day_progress":float(economy.day_seconds)/day_length(data), "day_seconds":day_length(data), "workplaces":places, "people":economy.people.duplicate(true), "population":population, "stocks":economy.stocks.duplicate(true), "grain_needed_per_day":population.alive, "grain_shortfall":economy.grain_shortfall, "patrols_completed":economy.patrols_completed, "last_report":economy.last_report}


static func repair_cost(economy: Dictionary, id: String) -> Dictionary:
	if not WORKPLACES.has(id) or not economy.get("workplaces", {}).has(id):
		return {"wood":0, "stone":0}
	var damage := (100.0 - float(economy.workplaces[id].condition)) / 100.0
	return {"wood":int(ceil(float(WORKPLACES[id].repair_wood) * damage)), "stone":int(ceil(float(WORKPLACES[id].repair_stone) * damage))}


static func _crew_reason(data: Dictionary, id: String) -> String:
	if _raid_active(data):
		return "Überfall: Zivilisten suchen Deckung"
	var available := _available(data, id)
	if available < int(WORKPLACES[id].required):
		return "%d von %d arbeitsfähigen Personen" % [available, WORKPLACES[id].required]
	return ""


static func _production_reason(data: Dictionary, id: String) -> String:
	var economy: Dictionary = data.village.economy
	var place: Dictionary = economy.workplaces[id]
	var spec: Dictionary = WORKPLACES[id]
	var crew := _crew_reason(data, id)
	if not crew.is_empty():
		return crew
	if not place.project.is_empty():
		return "Arbeitsauftrag läuft"
	if int(place.condition) < 100:
		return "Betrieb beschädigt: Reparatur erforderlich"
	if id == "watchpost":
		return ""
	if int(economy.stocks[spec.stock]) <= 0:
		return "Ernte erschöpft: nachsäen" if id == "farm" else "Örtlicher Vorrat erschöpft"
	if id == "trade" and int(data.resources.wood) < 4:
		return "Handel benötigt 4 Holz je Lieferung"
	if int(data.resources[spec.resource]) > MAX_RESOURCE - _yield_for(data,id):
		return "Lager voll"
	return ""


static func emergency_food_price(data: Dictionary) -> int:
	# Chapter I ability „Ein Preis ist eine Zusage“ (I-06) lowers the price by its catalog value.
	return maxi(1, 6 - int(Abilities.effect_value(data, "emergency_food_discount_denarii")))


static func _profession(data: Dictionary) -> String:
	var social: Variant = data.village.get("social", {})
	if typeof(social) != TYPE_DICTIONARY or typeof(social.get("profession", "")) != TYPE_STRING:
		return ""
	return social.get("profession", "")


static func _yield_for(data: Dictionary, id: String) -> int:
	if id == "watchpost":
		return 0
	var spec: Dictionary = WORKPLACES[id]
	var amount: int = spec["yield"]
	var learned := _profession(data)
	if (id == "woodcamp" and learned == "woodcutter") or (id == "quarry" and learned == "mason") or (id == "trade" and learned == "trader"):
		amount += 1
	return mini(amount, int(data.village.economy.stocks[spec.stock]))


static func _raid_active(data: Dictionary) -> bool:
	var raid: Variant = data.village.get("raid", {})
	return typeof(raid) == TYPE_DICTIONARY and raid.get("active", false) == true


static func _fit(person: Dictionary) -> bool:
	return person.alive and int(person.health) > 30 and int(person.hunger) < 2


static func _available(data: Dictionary, id: String) -> int:
	var count := 0
	for person in data.village.economy.people:
		if person.assignment == id and _fit(person) and _attending(data,person.id):
			count += 1
	return count


static func _attending(data: Dictionary, id: String) -> bool:
	# A break or reaction is an actual absence from production. Assignment and
	# ownership remain unchanged, so returning never creates a second worker.
	var behavior: Variant = data.village.get("behavior",{})
	if typeof(behavior) != TYPE_DICTIONARY:
		return false
	var people: Variant = behavior.get("people",{})
	if typeof(people) != TYPE_DICTIONARY:
		return false
	if not people.has(id):
		return true
	var person: Variant = people[id]
	return typeof(person) == TYPE_DICTIONARY and person.get("activity","") in ["work","patrol","alert"]


static func _assigned(economy: Dictionary, id: String) -> int:
	var count := 0
	for person in economy.people:
		if person.assignment == id and person.alive:
			count += 1
	return count


static func _person(economy: Dictionary, id: String) -> Dictionary:
	for person in economy.people:
		if person.id == id:
			return person
	return {}


static func _transfer(data: Dictionary, resource: String, quantity: int) -> void:
	data.resources[resource] = int(data.resources[resource]) + quantity
	data.village.economy.ledger[resource] = int(data.village.economy.ledger[resource]) + quantity


static func validate(data: Dictionary) -> String:
	if typeof(data.get("village")) != TYPE_DICTIONARY or typeof(data.village.get("economy")) != TYPE_DICTIONARY or typeof(data.get("resources")) != TYPE_DICTIONARY:
		return "Wirtschaft fehlt"
	var economy: Dictionary = data.village.economy
	for key in ["version", "people", "workplaces", "authority", "stocks", "ledger", "day", "day_seconds", "meal_offset", "meals_served", "grain_shortfall", "patrols_completed", "repair_count", "last_report"]:
		if not economy.has(key):
			return "Wirtschaftsfeld fehlt: " + key
	if economy.version != 1 or typeof(economy.people) != TYPE_ARRAY or economy.people.size() != PEOPLE.size():
		return "Unbekannte Dorfbevölkerung"
	for key in ["day", "meals_served", "grain_shortfall", "patrols_completed", "repair_count"]:
		if not _integer(economy[key], 0, 1000000000):
			return "Ungültiger Tageszähler"
	if not _number(economy.day_seconds, 0.0, day_length(data) - EPSILON) or not _integer(economy.meal_offset, 0, PEOPLE.size()-1):
		return "Ungültige Dorfzeit"
	if typeof(economy.authority) != TYPE_DICTIONARY or economy.authority.get("id") != "decimus" or economy.authority.get("player_is_ruler") != false or typeof(economy.authority.get("work_permit")) != TYPE_BOOL:
		return "Ungültige Amtsgewalt"
	if typeof(economy.last_report) != TYPE_STRING or economy.last_report.length() > 1024:
		return "Ungültiger Dorfbericht"
	if typeof(economy.ledger) != TYPE_DICTIONARY or typeof(economy.stocks) != TYPE_DICTIONARY:
		return "Vorratsbuch fehlt"
	for key in RESOURCE_KEYS:
		if not _integer(data.resources.get(key), 0, MAX_RESOURCE) or not _integer(economy.ledger.get(key), -1000000000, 1000000000):
			return "Ungültige Ressource oder Buchung: " + key
	for key in ["forest", "rock", "harvest", "merchant_denarii", "emergency_grain"]:
		if not _integer(economy.stocks.get(key), 0, MAX_RESOURCE):
			return "Ungültiger örtlicher Vorrat"
	var seen: Dictionary = {}
	for person in economy.people:
		if typeof(person) != TYPE_DICTIONARY:
			return "Ungültige Person"
		for key in ["id", "name", "profession", "assignment", "previous_assignment"]:
			if typeof(person.get(key)) != TYPE_STRING or person[key].length() > 96:
				return "Ungültige Personenkennung"
		var known := false
		for specification in PEOPLE:
			if specification.id == person.id:
				known = true
		if not known or seen.has(person.id):
			return "Doppelte oder unbekannte Person"
		seen[person.id] = true
		if not _integer(person.get("health"), 0, 100) or not _integer(person.get("hunger"), 0, 3) or typeof(person.get("alive")) != TYPE_BOOL:
			return "Ungültige Arbeitsfähigkeit"
		if person.assignment not in ["idle", "defense"] and not WORKPLACES.has(person.assignment):
			return "Unbekannte Arbeitseinteilung"
		if person.previous_assignment != "idle" and not WORKPLACES.has(person.previous_assignment):
			return "Ungültige Rückkehrstelle"
		if person.assignment != "defense" and person.previous_assignment != "idle":
			return "Veraltete doppelte Arbeitseinteilung"
	if typeof(economy.workplaces) != TYPE_DICTIONARY or not _exact_keys(economy.workplaces, WORKPLACES.keys()):
		return "Betriebsregister beschädigt"
	for id in WORKPLACES:
		var place: Variant = economy.workplaces[id]
		if typeof(place) != TYPE_DICTIONARY or not _integer(place.get("condition"), 0, 100) or not _number(place.get("cycle_seconds"), 0.0, float(WORKPLACES[id].period)-EPSILON) or not _integer(place.get("produced_cycles"),0,1000000000) or typeof(place.get("project")) != TYPE_DICTIONARY:
			return "Ungültiger Betrieb: " + id
		if _assigned(economy,id) > int(WORKPLACES[id].required):
			return "Arbeitsplatz doppelt belegt"
		if not place.project.is_empty():
			if not _exact_keys(place.project, ["kind", "remaining", "total"]) or place.project.kind not in ["repair", "sow"]:
				return "Ungültiger Bauauftrag"
			if place.project.kind == "sow" and id != "farm":
				return "Aussaat außerhalb der Felder"
			var expected := day_length(data) if place.project.kind == "sow" else float(WORKPLACES[id].repair_seconds)
			if not _number(place.project.total, expected, expected) or not _number(place.project.remaining, EPSILON, expected):
				return "Ungültige Arbeitszeit"
	return ""


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, float(minimum), float(maximum)) and float(value) == floor(float(value))


static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum


static func _exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key in expected:
		if not value.has(key):
			return false
	return true


static func _ok(message: String) -> Dictionary:
	return {"ok":true, "message":message}


static func _fail(message: String) -> Dictionary:
	return {"ok":false, "message":message}
