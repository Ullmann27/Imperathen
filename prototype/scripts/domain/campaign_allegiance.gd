extends RefCounted
## Public declarations are dated campaign events. They do not rewrite the
## protagonist's age, learned trade, military qualifications or friendships.
const Party = preload("res://scripts/domain/travel_party.gd")
const Clock = preload("res://scripts/domain/world_clock.gd")
const Calendar = preload("res://scripts/domain/world_calendar.gd")
const Tribes = preload("res://scripts/domain/tribal_world.gd")
const Life = preload("res://scripts/story/village_life.gd")
const COMMAND_FIELDS := {"party_declare":["target"], "party_envoy":["target"]}
const HOME := ["rome","civil","free","service"]

static func _events(world: Dictionary) -> Array:
	return world.world_state.get("allegiance",[])

static func affiliation(world: Dictionary) -> String:
	var events := _events(world)
	for index in range(events.size()-1,-1,-1):
		if events[index].kind == "declare":
			return "rome" if events[index].target == "service" else str(events[index].target)
	return "rome"

static func roman_command(world: Dictionary) -> bool:
	var events: Array = world.get("world_state",{}).get("allegiance",[])
	for index in range(events.size()-1,-1,-1):
		if events[index].kind == "declare":
			return events[index].target == "service"
	return true

static func label(world: Dictionary, target: String) -> String:
	if target in HOME:
		return {"rome":"Rom","civil":"Zivilleben","free":"Freie Gefolgschaft","service":"Römischer Wachdienst"}[target]
	return str(world.tribes.groups.get(target,{}).get("name",target))

static func available(world: Dictionary) -> bool:
	if world.origin_id != "italia" or not world.village.enabled or int(world.player.age) < 18:
		return false
	var script: Dictionary = world.village.get("childhood",{}).get("screenplay",{})
	return script.is_empty() or script.i10 == "complete"

static func validate_arguments(_command: String, args: Dictionary) -> String:
	if typeof(args.get("target")) != TYPE_STRING or args.target.is_empty() or args.target.length() > 64:
		return "Unbekannte Gemeinschaft."
	return ""

static func _delegation(world: Dictionary, target: String) -> bool:
	var group: Dictionary = world.tribes.groups.get(target,{})
	return group.get("status","") == "active" and group.kind == "tribe"

static func _support(world: Dictionary, uid: String) -> bool:
	var member: Dictionary = world.world_state.party.members[uid]
	if member.status != "active" or member.order == "home" or not Party.healthy(world,uid):
		return false
	var trust := Party.base_trust(world,uid) + int(member.bond)
	return trust >= 10 and int(member.morale) >= 40 and (member.contract == "voluntary" or trust >= 20)

static func _near(world: Dictionary, actor: String) -> bool:
	return Life.relationship(world,actor).get("met",false) and Party.player_position(world).distance_to(Life.actor_position(world,actor)) <= Party.REACH

static func reason(world: Dictionary, cmd: String, target: String) -> String:
	if not available(world) or Party.protected(world) or world.progress.career_terminal:
		return "Eine öffentliche Erklärung ist in diesem Lebensabschnitt nicht möglich."
	if target not in HOME and not _delegation(world,target):
		return "Diese Gemeinschaft kann zurzeit keine Gesandtschaft empfangen."
	if cmd == "party_envoy":
		if not _delegation(world,target) or not _near(world,"cassia"):
			return "Vereinbare die Lieferung persönlich bei Cassia am Markt."
		if int(world.resources.grain) < 2:
			return "Die Gesandtschaft benötigt zwei Getreide aus eurem Vorrat."
		for event: Dictionary in _events(world):
			if event.kind == "envoy" and event.target == target and int(event.day) == Clock.jdn(world):
				return "Heute ist bereits eine Sendung unterwegs."
		return ""
	if target == affiliation(world):
		return "Zu dieser Entscheidung stehst du bereits."
	if target in ["rome","civil","service"] and not _near(world,"decimus"):
		return "Besprich deine Entscheidung mit Decimus im Dorf."
	if target == "service" and (roman_command(world) or affiliation(world) != "rome" or not world.progress.training_complete or not world.world_state.politics.events.any(func(e): return e.id == "valdora.decimus.audience")):
		return "Eine neue Ernennung setzt römische Loyalität, eine abgeschlossene Ausbildung und eine Audienz voraus."
	if target == "free":
		for uid: String in world.world_state.party.members:
			if _support(world,uid) and Party.position(world,uid).distance_to(Party.player_position(world)) <= Party.REACH:
				return ""
		return "Zur Gründung muss mindestens ein vertrauter Unterstützer persönlich anwesend sein."
	if target not in HOME:
		if not _near(world,"cassia"):
			return "Cassia vermittelt Kontakte am Markt."
		if Tribes._rel(world.tribes,target,"player","trust") < 5:
			return "Diese Gemeinschaft erwartet zuerst eine verlässliche persönliche Verbindung."
	return ""

static func apply(world: Dictionary, cmd: String, args: Dictionary) -> Dictionary:
	var target: String = args.target
	var why := reason(world,cmd,target)
	if not why.is_empty():
		return {"ok":false,"message":why}
	var entry := {"kind":"envoy" if cmd == "party_envoy" else "declare","target":target,"day":Clock.jdn(world)}
	if not world.world_state.has("allegiance"):
		world.world_state.allegiance = []
	var message := ""
	if cmd == "party_envoy":
		world.resources.grain -= 2
		var tribes := Tribes.writable(world)
		Tribes.receive_delegation(tribes,target,2)
		message = "Cassia übernimmt zwei Getreide für %s. Die Lieferung wird dort verbucht." % label(world,target)
	else:
		var previous := affiliation(world)
		if previous not in HOME and previous != target and world.tribes.groups.has(previous):
			Tribes.record_player_action(Tribes.writable(world),previous,"broke_promise","Die Gefolgschaft wurde öffentlich verlassen.")
		message = "Du erklärst dich für %s." % label(world,target)
		if target == "free" or target not in HOME:
			for uid: String in world.world_state.party.members:
				var member: Dictionary = world.world_state.party.members[uid]
				if member.status != "active":
					continue
				if _support(world,uid):
					Party.remember(member,"Unterstützt die Entscheidung für %s." % label(world,target))
				else:
					Party._order(member,"home")
					Party.remember(member,"Bleibt in dieser politischen Frage neutral.")
				if member.order == "home":
					message += " %s bleibt zu Hause." % Party.local_id(world,uid).capitalize()
	world.world_state.allegiance.append(entry)
	return {"ok":true,"message":message}

static func view(world: Dictionary) -> Dictionary:
	if not available(world):
		return {}
	var options := []
	var local := affiliation(world)
	var targets: Array = ["free","civil","rome"]
	if not roman_command(world) and world.progress.training_complete:
		targets.append("service")
	for gid: String in world.tribes.groups:
		if _delegation(world,gid):
			targets.append(gid)
	for target: String in targets:
		if target != local:
			options.append({"cmd":"party_declare","target":target,"label":label(world,target),"reason":reason(world,"party_declare",target)})
		if target not in HOME:
			options.append({"cmd":"party_envoy","target":target,"label":"Lieferung an %s" % label(world,target),"reason":reason(world,"party_envoy",target)})
	return {"label":label(world,local),"options":options}

static func validate(world: Dictionary) -> String:
	var entries: Variant = world.world_state.get("allegiance",[])
	if typeof(entries) != TYPE_ARRAY:
		return "Ungültige politische Laufbahn."
	var last_day := int(world.world_state.time.epoch.jdn)
	var local := "rome"
	var gifts := {}
	for event: Variant in entries:
		if typeof(event) != TYPE_DICTIONARY or event.size() != 3 or not event.has_all(["target","kind","day"]) or typeof(event.target) != TYPE_STRING or not Calendar.is_integral(event.day):
			return "Ungültige politische Erklärung."
		if world.origin_id != "italia" or not world.village.enabled or int(event.day) < last_day or int(event.day) > Clock.jdn(world) or Calendar.age_on(world.calendar.births.player,int(event.day)) < 18:
			return "Ungültiges Datum einer politischen Entscheidung."
		if event.target not in HOME and not world.tribes.groups.has(event.target):
			return "Unbekannter historischer Adressat."
		if event.kind == "envoy":
			var key := "%d/%s" % [int(event.day),event.target]
			if event.target in HOME or gifts.has(key):
				return "Ungültige doppelte oder ziellose Lieferung."
			gifts[key] = true
		elif event.kind == "declare":
			if event.target == local or (event.target == "service" and local != "rome"):
				return "Widersprüchlicher Wechsel der Gefolgschaft."
			local = "rome" if event.target == "service" else str(event.target)
		else:
			return "Unbekannte politische Handlung."
		last_day = int(event.day)
	return ""

static func donated_grain(world: Dictionary) -> int:
	var total := 0
	for entry: Dictionary in _events(world):
		if entry.kind == "envoy":
			total += 2
	return total
