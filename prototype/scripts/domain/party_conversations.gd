extends RefCounted
## Creative companion dialogue. The single saved fact is attendance at an
## accomplished task. Directed opinions and dialogue are read from these facts.
const Calendar = preload("res://scripts/domain/world_calendar.gd")
const Relations = preload("res://scripts/domain/actor_relations.gd")
const Neighbours = preload("res://scripts/domain/npc_social_memory.gd")
const Data = preload("res://scripts/story/mission_data.gd")
const FRIEND := "pc:companion"
const ROLES := {"guide":"Weg zeigen","carry":"Tragen","watch":"Ausblick halten","aid":"Beistehen"}
const STANCES := {"neutral":"Gemeinsam unterwegs","friendly":"Freundschaft","close":"Enge Freundschaft","wary":"Rivalität","hostile":"Feindschaft"}
static var _captions := {}

static func _caption(step: String) -> String:
	if _captions.is_empty():
		for mission: Dictionary in Data.mission_files("band1"):
			for authored: Dictionary in mission.get("steps",[]) + mission.get("bridges",[]):
				_captions[authored.id] = str(authored.label)
			for key: String in mission.get("party_tasks",{}).get("steps",{}):
				if not _captions.has(key):
					_captions[key] = str(mission.title)
	return _captions.get(step,step)

static func record(world: Dictionary, step: String, witnesses: Dictionary) -> String:
	if witnesses.is_empty():
		return ""
	var party: Dictionary = world.world_state.party
	var outings: Array = party.get("outings",[])
	for previous: Dictionary in outings:
		if previous.step == step:
			return ""
	outings.append({"step":step,"jdn":int(world.calendar.clock.jdn),"roles":witnesses,"answers":{}})
	party.outings = outings
	# The speaker takes the initiative in the actual mission feedback. The
	# others retain their own offers and can be answered separately.
	var speaker: String = witnesses.keys()[0]
	return "%s: »%s«" % [name_for(world,speaker),_offer(world,speaker,step,witnesses).line]

static func name_for(world: Dictionary, uid: String) -> String:
	var id := str(world.companion.id) if uid == FRIEND else uid.trim_prefix("vil:")
	for person: Dictionary in world.village.economy.people:
		if person.id == id:
			return person.name
	return id.capitalize()

static func _offer(world: Dictionary, uid: String, step: String, roles: Dictionary) -> Dictionary:
	var skills: Dictionary = world.world_state.party.members[uid].skills
	var role := "carry"
	var line := "Beim nächsten Mal kann ich dir etwas abnehmen. Gibst du mir die Last?"
	if uid in [FRIEND,"vil:varro"] or int(skills.get("navigation",0)) >= 8:
		role = "guide"
		if uid == FRIEND:
			line = "Jetzt kenne ich den Weg. Darf ich beim nächsten Gang vorausgehen?"
		else:
			line = "Ich habe mir die Abzweigungen gemerkt. Soll ich uns beim nächsten Mal führen?"
		if roles[uid] == "guide" and roles.values().count("guide") > 1:
			line = "Wir haben beide den Weg angesagt. Beim nächsten Mal möchte ich die Richtung zeigen."
			# The offer changes the speaker's responsibility only. The player
			# remains free to reassign the other guide personally.
	elif uid == "vil:silvanus":
		role = "watch" if step == "i08_tracks" else "carry"
		line = "Die Spuren gefallen mir nicht. Ich würde lieber nach der Straße sehen." if role == "watch" else "Lass die schwere Last beim nächsten Gang mir. Du kannst dich um die Übergabe kümmern."
	elif uid == "vil:aurelia" or int(skills.get("healing",0)) >= 8:
		role = "aid"
		line = "Ich möchte die Hände frei haben, falls jemand meine Hilfe braucht. Können wir das so abmachen?"
	elif uid in ["vil:valeria","vil:severus"] or int(skills.get("perception",0)) >= 3:
		role = "watch"
		line = "Während ihr arbeitet, kann ich die Umgebung im Auge behalten. Ist dir das recht?"
	if step == "i13_morning" and uid == FRIEND:
		role = "watch"
		line = "Ich muss an Silvanus denken. Soll ich bei dir bleiben und nach den anderen sehen?"
	elif step == "i08_tracks" and uid == "vil:varro":
		role = "watch"
		line = "Aus diesen Spuren allein erkenne ich keinen Reiter. Ich möchte die Straße weiter beobachten."
	return {"role":role,"line":line,"step":step}

static func _is_rival(observer: String, role: String, other: String) -> bool:
	return observer in [FRIEND,"vil:varro"] and role == "guide" and other == "guide"

## Use the same stance thresholds as political relations. No second saved
## relation graph or independent copy of a person's opinion is needed.
static func opinions(world: Dictionary, uid: String) -> Dictionary:
	var projection := Relations.new_graph()
	var outings: Array = world.world_state.party.get("outings",[])
	for outing: Dictionary in outings:
		var roles: Dictionary = outing.roles
		if not roles.has(uid):
			continue
		for other: String in roles:
			if other == uid:
				continue
			var delta := {"trust":2,"respect":1}
			if _is_rival(uid,roles[uid],roles[other]):
				delta = {"trust":-4,"grievance":11}
			elif roles[uid] != "witness" and roles[other] != "witness" and roles[uid] != roles[other]:
				delta = {"trust":9,"respect":4,"grievance":-12}
			Relations.apply(projection,uid,other,outing.step,int(outing.jdn),"witnessed_mission",delta)
	return projection

static func stance(world: Dictionary, uid: String, other: String, graph: Dictionary) -> String:
	var standing := Relations.stance(graph,uid,other)
	if standing in ["unknown","neutral"]:
		var social: Dictionary = world.village.get("behavior",{}).get("social",{})
		var first := str(world.companion.id) if uid == FRIEND else uid.trim_prefix("vil:")
		var second := str(world.companion.id) if other == FRIEND else other.trim_prefix("vil:")
		if Neighbours.relationship(social,first,second).status == "friend":
			return "friendly"
	return standing

static func row(world: Dictionary, uid: String) -> Dictionary:
	var notes := []
	var contacts := PackedStringArray()
	var offer := {}
	for outing: Dictionary in world.world_state.party.get("outings",[]):
		if not outing.roles.has(uid):
			continue
		var text := "%s · %s" % [Calendar.format_date(int(outing.jdn)),_caption(outing.step)]
		text += " · " + str(ROLES.get(outing.roles[uid],"Dabei gewesen"))
		if outing.answers.has(uid):
			text += " · " + ("Vorschlag angenommen" if outing.answers[uid] == "accept" else "Anders vereinbart")
		notes.append(text)
		# Only the most recent witnessed task can still prompt a new offer.
		offer = {} if outing.answers.has(uid) else _offer(world,uid,outing.step,outing.roles)
	var graph := opinions(world,uid)
	for other: String in Relations.known_by(graph,uid):
		contacts.append("%s · %s" % [name_for(world,other),STANCES[stance(world,uid,other,graph)]])
	return {"entries":notes,"contacts":contacts,"offer":offer}

static func answer(world: Dictionary, uid: String, step: String, choice: String) -> Dictionary:
	var outings: Array = world.world_state.party.get("outings",[])
	for i in range(outings.size()-1,-1,-1):
		var outing: Dictionary = outings[i]
		if not outing.roles.has(uid):
			continue
		if outing.step != step or outing.answers.has(uid) or choice not in ["accept","decline"]:
			break
		var offer := _offer(world,uid,step,outing.roles)
		var member: Dictionary = world.world_state.party.members[uid]
		if choice == "accept":
			if member.order == "train":
				return {"ok":false,"message":"Beendet zuerst die gemeinsame Übung."}
			member.assignment = offer.role
			member.order = "assist"
		outing.answers[uid] = choice
		var text := "»Abgemacht.« %s übernimmt die Aufgabe %s." % [name_for(world,uid),ROLES[offer.role]] if choice == "accept" else "»Dann belassen wir es bei der bisherigen Aufteilung.«"
		return {"ok":true,"message":text}
	return {"ok":false,"message":"Dieser Vorschlag ist nicht mehr offen."}

static func validate(world: Dictionary, outings: Variant, task_roles: Callable) -> String:
	if not outings is Array:
		return "Ungültige gemeinsame Unternehmungen."
	var previous_day := int(world.world_state.time.epoch.jdn)
	var seen := {}
	for item: Variant in outings:
		if not item is Dictionary or item.size() != 4 or not item.has_all(["step","jdn","roles","answers"]) or not item.step is String or seen.has(item.step) or not Calendar.is_integral(item.jdn) or item.jdn < previous_day or item.jdn > world.calendar.clock.jdn:
			return "Widersprüchliche oder doppelte Aufgabenerinnerung."
		var child: Dictionary = world.village.get("childhood",{})
		var screenplay: Dictionary = child.get("screenplay",{})
		var accomplished: bool = child.get("completed",[]).has(item.step)
		match item.step:
			"i07_water_bring": accomplished = screenplay.get("i07_water") == "complete"
			"i08_tracks": accomplished = screenplay.get("hoof_evidence") == true
			"i13_morning": accomplished = screenplay.get("i13") == "complete"
		if not accomplished:
			return "Diese Erinnerung gehört zu keiner abgeschlossenen Aufgabe."
		var valid_roles: Dictionary = task_roles.call(item.step)
		if valid_roles.is_empty() or not item.roles is Dictionary or item.roles.is_empty() or not item.answers is Dictionary:
			return "Unbekannte gemeinsame Aufgabe."
		for uid: Variant in item.roles:
			if not world.world_state.party.members.has(uid) or (item.roles[uid] != "witness" and not valid_roles.has(item.roles[uid])):
				return "Ungültige Person oder Aufgabe in einer Erinnerung."
		for uid: Variant in item.answers:
			if not item.roles.has(uid) or item.answers[uid] not in ["accept","decline"]:
				return "Unbelegte persönliche Absprache."
		previous_day = int(item.jdn)
		seen[item.step] = true
	return ""
