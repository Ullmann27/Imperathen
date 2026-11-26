extends RefCounted
## One local civic relationship with the existing fictional steward Decimus.
## WorldModel alone applies and commits these commands. The view is read-only.

const Life = preload("res://scripts/story/village_life.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const Calendar = preload("res://scripts/domain/world_calendar.gd")
const OFFICIAL_ID := "decimus"
const SURVEY_POINT := Vector2(0.0, 17.0)
const RANGE := 3.0
const DONATION_WOOD := 4
const VERSION := 1
const SURVEY := "valdora.road.survey"
const ROAD_HELP := "valdora.decimus.road_help"
const WOOD_HELP := "valdora.decimus.wood_help"
const AUDIENCE := "valdora.decimus.audience"
const COMMAND_FIELDS := {"politics_survey": [], "politics_help": ["route"], "politics_audience": []}
const ROUTES := {"road": ROAD_HELP, "wood": WOOD_HELP}


static func new_state() -> Dictionary:
	return {"version": VERSION, "events": []}


static func enabled(world: Dictionary) -> bool:
	return world.get("origin_id", "") == "italia" and bool(world.get("village", {}).get("enabled", false))


static func validate_arguments(command: String, args: Dictionary) -> String:
	if command == "politics_help" and (typeof(args.get("route")) != TYPE_STRING or not ROUTES.has(args.route)):
		return "Wähle zwischen einer Meldung zum Weg und einer Holzspende."
	return ""


static func view(world: Dictionary) -> Dictionary:
	var events: Array = world.get("world_state", {}).get("politics", {}).get("events", [])
	var ids := _event_ids(events)
	var route := _completed_help(ids)
	var audience := ids.has(AUDIENCE)
	var relation := Life.relationship(world, OFFICIAL_ID)
	var can_discuss := _shared_reason(world).is_empty()
	var result := {
		"available": enabled(world),
		"can_discuss": can_discuss,
		"official_id": OFFICIAL_ID,
		"report_point": SURVEY_POINT,
		"report_radius": RANGE,
		"survey_pending": can_discuss and route.is_empty() and not ids.has(SURVEY),
		"relationship": {"actor_id": "vil:decimus", "trust": int(relation.get("trust", 0)), "respect": 0},
		"recommendation": {},
		"learning": "",
		"events": events.duplicate(true),
		"options": [],
	}
	if route != "":
		result.learning = "Versorgung organisieren" if route == "wood" else "Beobachtungen für die Verwaltung festhalten"
		result.relationship.trust += (4 if route == "wood" else 2) + int(audience)
		result.relationship.respect = 2 if route == "wood" else 4
		result.recommendation = {
			"id": "valdora.decimus.recommendation",
			"issuer": "vil:decimus",
			"route": route,
			"audience": audience,
			"date": _event_date(events, ROUTES[route]),
		}
	if result.available:
		result.options = [
			_option(world, ids, "politics_survey", {}, "Südweg begutachten"),
			_option(world, ids, "politics_help", {"route": "road"}, "Vom Südweg berichten"),
			_option(world, ids, "politics_help", {"route": "wood"}, "%d Holz für den Weg abgeben" % DONATION_WOOD),
			_option(world, ids, "politics_audience", {}, "Um eine Audienz bitten"),
		]
	return result


static func apply(candidate: Dictionary, command: String, args: Dictionary) -> Dictionary:
	var events: Array = candidate.world_state.politics.events
	var why := _reason(candidate, _event_ids(events), command, args)
	if not why.is_empty():
		return {"ok": false, "message": why}
	var id := ""
	var message := ""
	match command:
		"politics_survey":
			id = SURVEY
			message = "Am Südweg hat der Regen die Erde unter einer Bohle ausgespült. Vom festen Rand aus siehst du die fehlende Auflage."
		"politics_help":
			id = ROUTES[args.route]
			if args.route == "wood":
				Life._pay(candidate, {"wood": DONATION_WOOD})
				message = "Decimus übernimmt vier Holz für den Südweg und merkt sich deine Hilfe."
			else:
				message = "Decimus hält deinen Bericht über die lose Bohle am Südweg fest."
			message += " Er spricht dir persönlich seine Empfehlung aus."
			message += " Du hast gelernt, Versorgung zu organisieren." if args.route == "wood" else " Du hast gelernt, Beobachtungen für die Verwaltung festzuhalten."
		"politics_audience":
			id = AUDIENCE
			message = "Decimus empfängt dich und hört sich deine Einschätzung zum Südweg an. Deine Empfehlung bleibt vermerkt."
		_:
			return {"ok": false, "message": "Dieser Dorfauftrag ist unbekannt."}
	var clock: Dictionary = candidate.calendar.clock
	events.append({"id": id, "jdn": int(clock.jdn), "second": int(clock.second)})
	return {"ok": true, "message": message}


static func _option(world: Dictionary, ids: Array[String], command: String, args: Dictionary, label: String) -> Dictionary:
	var why := _reason(world, ids, command, args)
	return {"command": command, "args": args, "label": label, "enabled": why.is_empty(), "reason": why}


static func _shared_reason(world: Dictionary) -> String:
	if not enabled(world) or int(world.get("player", {}).get("health", 0)) <= 0 or not Life.is_available(world, OFFICIAL_ID):
		return "Decimus kann dich gerade nicht empfangen."
	if str(world.village.raid.status) in ["warning", "active"] or bool(world.encounter.active):
		return "Warte, bis die Gefahr vorüber ist."
	if Childhood.enabled(world) and str(world.village.childhood.screenplay.get("i01", "")) not in ["complete", "legacy"]:
		return "Zu Hause wartet noch deine Familie auf dich."
	if not Life.relationship(world, OFFICIAL_ID).get("met", false):
		return "Stell dich zuerst bei Decimus vor."
	return ""


static func _reason(world: Dictionary, ids: Array[String], command: String, args: Dictionary) -> String:
	var shared := _shared_reason(world)
	if not shared.is_empty():
		return shared
	var remaining_help := _completed_help(ids).is_empty()
	if command == "politics_survey":
		if not remaining_help or ids.has(SURVEY):
			return "Du hast in dieser Sache bereits geholfen oder den Weg schon geprüft."
		return "" if _near(world, SURVEY_POINT) else "Sieh dir den Südweg an Ort und Stelle an."
	if not _near(world, Life.actor_position(world, OFFICIAL_ID)):
		return "Geh zu Decimus, um mit ihm zu sprechen."
	if command == "politics_audience":
		if ids.has(AUDIENCE):
			return "Decimus hat dich dazu bereits empfangen."
		if int(world.player.age) < 18:
			return "Decimus bespricht Amtsangelegenheiten in einer Audienz mit Erwachsenen."
		return "Decimus bittet dich zuerst um Hilfe am Südweg." if remaining_help else ""
	if not remaining_help:
		return "Decimus hat deine Hilfe zu dieser Aufgabe bereits anerkannt."
	if args.get("route") == "road":
		return "" if ids.has(SURVEY) else "Begutachte zuerst den Südweg."
	if int(world.resources.wood) < DONATION_WOOD:
		return "Für die Spende brauchst du vier Holz."
	return ""


static func _near(world: Dictionary, point: Vector2) -> bool:
	var at: Variant = world.get("player", {}).get("position", [])
	return at is Array and at.size() == 3 and Vector2(float(at[0]), float(at[2])).distance_to(point) <= RANGE


static func _event_ids(events: Array) -> Array[String]:
	var ids: Array[String] = []
	for event: Dictionary in events:
		ids.append(str(event.id))
	return ids


static func _completed_help(ids: Array[String]) -> String:
	if ids.has(ROAD_HELP):
		return "road"
	return "wood" if ids.has(WOOD_HELP) else ""


static func _event_date(events: Array, id: String) -> String:
	for event: Dictionary in events:
		if event.id == id:
			return Calendar.format_date(int(event.jdn))
	return ""


static func validate(world: Dictionary) -> String:
	var state: Variant = world.world_state.politics
	if not state is Dictionary or state.size() != 2 or not Calendar.is_integral(state.get("version")) or int(state.version) != VERSION or not state.get("events") is Array:
		return "Der politische Ortszustand ist ungültig."
	var events: Array = state.events
	if events.size() > 3 or (not events.is_empty() and not enabled(world)):
		return "Das Dorfgeschehen gehört nicht zu dieser Welt."
	if events.is_empty():
		return ""
	if not Life.relationship(world, OFFICIAL_ID).get("met", false):
		return "Das Ortsereignis hat keine bestätigte Bekanntschaft mit Decimus."
	var epoch: Dictionary = world.world_state.time.epoch
	var now: Dictionary = world.calendar.clock
	var previous := int(epoch.jdn) * Calendar.DAY_SECONDS + int(epoch.second)
	var latest := int(now.jdn) * Calendar.DAY_SECONDS + int(now.second)
	var ids: Array[String] = []
	for event: Variant in events:
		if not event is Dictionary or event.size() != 3 or not Calendar.is_integral(event.get("jdn")) or not Calendar.is_integral(event.get("second")):
			return "Ein politisches Ortsereignis hat kein gültiges Datum."
		var id: Variant = event.get("id")
		if not id is String or id not in [SURVEY, ROAD_HELP, WOOD_HELP, AUDIENCE] or id in ids:
			return "Ein politisches Ortsereignis ist unbekannt oder doppelt."
		var jdn := int(event.jdn)
		var second := int(event.second)
		if jdn < int(epoch.jdn) or jdn > int(now.jdn) or second < 0 or second >= Calendar.DAY_SECONDS:
			return "Ein politisches Ortsereignis liegt außerhalb der Weltzeit."
		var stamp := jdn * Calendar.DAY_SECONDS + second
		if stamp < previous or stamp > latest:
			return "Politische Ortsereignisse stehen in falscher Zeitfolge."
		var helped := not _completed_help(ids).is_empty()
		if (id == SURVEY and helped) or (id in [ROAD_HELP, WOOD_HELP] and helped) or (id == ROAD_HELP and SURVEY not in ids):
			return "Der politische Ortsauftrag wurde widersprüchlich bestätigt."
		if id == AUDIENCE and (not helped or Calendar.age_on(world.calendar.births.player, jdn) < 18):
			return "Die Audienz hat keine gültige persönliche Empfehlung oder Altersgrundlage."
		ids.append(id)
		previous = stamp
	return ""


static func normalize(world: Dictionary) -> void:
	var state: Dictionary = world.world_state.politics
	state.version = int(state.version)
	for event: Dictionary in state.events:
		event.jdn = int(event.jdn)
		event.second = int(event.second)
