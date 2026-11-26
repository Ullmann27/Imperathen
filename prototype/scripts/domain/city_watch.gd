extends RefCounted
## One visiting Roman detachment. Its roster is reproducible from the campaign
## seed and origin year; only encounters with the player need saved facts.
const Combat = preload("res://scripts/domain/combat_actions.gd")
const Calendar = preload("res://scripts/domain/world_calendar.gd")
const Catalog = preload("res://scripts/battle/troop_catalog.gd")
const Roster = preload("res://scripts/battle/soldier_roster.gd")
const COMMAND_FIELDS := {"city_watch_reply":["choice"],"city_watch_contact":[]}
const CHOICES := ["yield","argue","resist"]
const MAX_TALK_RANGE := 2.35
const PRESSURE_SECONDS := 4.0
const COUNT := 6
const COMPANY := "aquileia_market_detail"
const LEADER := "sol:aquileia_market_detail_00"

static func roster(world: Dictionary) -> Array[Dictionary]:
	var people: Array[Dictionary] = []
	if world.origin_id != "italia" or not world.village.enabled:
		return people
	var year := int(world.calendar.origin_year)
	var today := Calendar.year_of(int(world.calendar.clock.jdn))
	var catalog := Catalog.load_default()
	var troop := "roman_miles" if year < 0 else "roman_legionarius_principate"
	if not catalog.ok or not Catalog.valid_at(catalog.troops[troop],year):
		return people
	var seed := Roster.text_salt(str(world.world_id))
	for i in COUNT:
		var id := "roman_veteranus" if i == 0 and year < 0 else troop
		var person := Roster.identity(seed, COMPANY, i, COUNT, catalog.troops[id], catalog.name_pools.roman, catalog.groups.gallia_cisalpina, 80, 65, year, {}, "commander" if i == 0 else "miles")
		person.age += Calendar.years_between(year,today)
		if person.age >= 55:
			person.status = "retired"
		people.append(person)
	return people

static func validate_arguments(command: String, args: Dictionary) -> String:
	if command == "city_watch_contact":
		return "" if args.is_empty() else "Der Kontakt enthält ungültige Angaben."
	return "" if command == "city_watch_reply" and args.size() == 1 and args.get("choice") is String and args.choice in CHOICES else "Wähle eine Antwort an die Wache."

static func reputation(world: Dictionary) -> int:
	return -2 * int(world.world_state.politics.get("street_watch",{}).get("disputes",0))

static func apply(world: Dictionary, command: String, args: Dictionary, observed: Dictionary) -> Dictionary:
	if not COMMAND_FIELDS.has(command) or not validate_arguments(command,args).is_empty():
		return _result(false,"Ungültige Antwort.")
	var day := int(world.calendar.clock.jdn)
	var i10: String = world.village.get("childhood",{}).get("screenplay",{}).get("i10","")
	if world.origin_id != "italia" or not world.village.enabled or int(world.player.health) <= 0 or world.encounter.active or i10 == "pending" or world.village.raid.status in ["warning","active"]:
		return _result(false,"Die Wache ist gerade nicht ansprechbar.")
	if observed.get("world_id") != world.world_id or observed.get("commander") != LEADER or observed.get("day") != day or not observed.get("clear",false):
		return _result(false,"In dieser Straße ist kein Gespräch mit dem Wachführer möglich.")
	var gap := float(observed.get("distance",INF))
	var seconds := float(observed.get("pressure",0.0))
	if not is_finite(gap) or gap < 0.0 or gap > MAX_TALK_RANGE or not is_finite(seconds) or seconds < PRESSURE_SECONDS:
		return _result(false,"Der Wachführer ist außer Hörweite.")
	var logbook: Dictionary = world.world_state.politics.get("street_watch",{"day":day,"answer":"","disputes":0,"scuffles":0})
	var previous := str(logbook.answer) if int(logbook.day) == day else ""
	var answer: String = str(args.get("choice",""))
	var message := ""
	if command == "city_watch_contact":
		var time := float(observed.get("contact_time",-1))
		if previous != "resist" or observed.get("phase") != "scuffle" or int(world.player.age) < 18 or gap > 1.65 or Combat.phase("jab_right",time) != "active":
			return _result(false,"Die Bewegung hat keinen Kontakt hergestellt.")
		var guarded: bool = observed.get("guard",false) == true
		var damage := 0 if guarded else mini(3,int(world.player.health)-1)
		world.player.health -= damage
		world.village.health_delta -= damage
		answer = "blocked" if guarded else "pushed"
		message = "Du fängst den Stoß ab. Der Wachführer bricht das Handgemenge ab." if guarded else "Der Wachführer drängt dich zurück. Gesundheit −%d." % damage
	elif observed.get("phase") == "talk" and previous.is_empty():
		if answer == "yield":
			message = "Du lässt den Zug passieren. Der Wachführer nickt und kehrt zu seinen Leuten zurück."
		elif answer == "argue":
			logbook.disputes = int(logbook.disputes) + 1
			message = "»Du hast mich verstanden. Lass meine Leute jetzt durch.« Ansehen bei der Marktwache −2."
		else:
			return _result(false,"Der Wachführer erwartet zunächst eine Antwort.")
	elif observed.get("phase") == "dispute" and previous == "argue":
		if answer == "yield":
			answer = "settled"
			message = "Du trittst zurück. Der Wortwechsel ist beendet."
		elif answer == "resist" and int(world.player.age) >= 18:
			logbook.scuffles = int(logbook.scuffles) + 1
			message = "Der Wachführer hebt den Schild. Du kannst zurückweichen."
		else:
			return _result(false,"Die Wache lässt sich auf diese Aufforderung nicht ein.")
	else:
		return _result(false,"Dieses Gespräch ist bereits beendet.")
	logbook.day = day
	logbook.answer = answer
	world.world_state.politics.street_watch = logbook
	return _result(true,message)

static func validate(world: Dictionary, record: Variant) -> String:
	if not record is Dictionary or record.size() != 4 or not record.has_all(["day","answer","disputes","scuffles"]):
		return "Ungültiger Vorfall der Marktwache."
	for key: String in ["day","disputes","scuffles"]:
		if not Calendar.is_integral(record[key]):
			return "Ungültige Angabe im Wachbuch."
	var day := int(record.day)
	var start := int(world.world_state.time.epoch.jdn)
	if day < start or day > int(world.calendar.clock.jdn) or record.answer not in ["yield","argue","settled","resist","pushed","blocked"] or record.disputes < 0 or record.disputes > day - start + 1 or record.scuffles < 0 or record.scuffles > record.disputes:
		return "Die Einträge des Wachbuchs widersprechen sich."
	if record.answer in ["argue","settled","resist","pushed","blocked"] and record.disputes == 0:
		return "Der Wortwechsel fehlt im Wachbuch."
	if record.answer in ["resist","pushed","blocked"] and (record.scuffles == 0 or Calendar.age_on(world.calendar.births.player,day) < 18):
		return "Der Eintrag über das Handgemenge ist ungültig."
	return ""

static func _result(ok: bool, message: String) -> Dictionary:
	return {"ok":ok,"message":message}
