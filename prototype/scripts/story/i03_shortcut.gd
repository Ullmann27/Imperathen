extends RefCounted
## I-03 „Marcus kennt eine Abkürzung“ – playable errand with Marcus
## (Masterhandbuch 3.0 S. 14, Knoten I-03.B03 S. 10, Originalblatt S. 70).
## Pure domain contract like I-01: the state lives in
## village.childhood.screenplay (version 5), every decision writes one unique
## event into i03_events. Films, props and HUD only read this state.
##
## Relationship rule: the mission stores concrete memories (route, promise,
## stance, service, debt, apology). The older binary companion.choice used by
## later systems is only a summary derived from these memories when Marcus and
## the boy part (see summary()); it is never chosen directly by a button.

const SOURCE := "res://assets/story/missions/band1/I-03.json"
const ROUTES := ["together", "later", "apart"]
const STANCES := ["watch", "offer", "object", "missed"]
const RESOLVES := ["clarify", "accept", "refuse"]
const TASKS := ["", "measure", "service_fetch", "service_bring", "done"]
const SALT := ["", "small", "large", "debt", "none"]
const HOMES := ["", "together", "apart", "alone"]
const NPC_RANGE := 3.2
const WELL_RANGE := 2.2
## Marcus counts as "at the stall" within this distance of his stall place.
const STALL_RANGE := 4.5
## The farewell is spoken across the stall; wide enough for any place from
## which Julia's order can be bought, so the film choice can never dead-end.
const FAREWELL_RANGE := 7.0
const POINTS := {"lane":Vector2(-3.0, 4.0), "well":Vector2(-7.0, 6.0)}
## Cassia trades at the village trading shelter; its table is her stall.
## She stands in front of it, Marcus steps up beside her at the table.
const STALL_TABLE := Vector3(25.0, 0.925, 24.0)
const MARCUS_OFFSET := Vector2(1.2, -0.5)
const KEYS := ["i03s", "i03_route", "i03_stance", "i03_resolve", "i03_task", "i03_salt", "i03_home", "i03_apology", "i03_events"]
const ROUTE_ACTIONS := {"i03_together":"together", "i03_later":"later", "i03_apart":"apart"}
const STANCE_ACTIONS := {"i03_watch":"watch", "i03_offer":"offer", "i03_object":"object", "i03_missed":"missed"}
const RESOLVE_ACTIONS := {"i03_clarify":"clarify", "i03_accept":"accept", "i03_refuse":"refuse"}
const HOME_ACTIONS := {"i03_home_together":"together", "i03_home_apart":"apart", "i03_apologise":"together", "i03_home_alone":"alone"}
static var _slice: Dictionary = {}


static func slice() -> Dictionary:
	if _slice.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
		if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("slice")) == TYPE_DICTIONARY:
			_slice = parsed.slice
			_slice.make_read_only()
		else:
			push_error("I-03 slice data missing: " + SOURCE)
	return _slice


static func fresh_state() -> Dictionary:
	return {"i03s":"pending", "i03_route":"", "i03_stance":"", "i03_resolve":"", "i03_task":"", "i03_salt":"",
		"i03_home":"", "i03_apology":false, "i03_events":[]}


static func legacy_state() -> Dictionary:
	var state := fresh_state()
	state.i03s = "legacy"
	return state


static func _screenplay(data: Dictionary) -> Dictionary:
	var child: Variant = data.get("village", {}).get("childhood")
	if typeof(child) != TYPE_DICTIONARY or typeof(child.get("screenplay")) != TYPE_DICTIONARY:
		return {}
	return child.screenplay


static func line(line_id: String) -> Dictionary:
	return slice().get("lines", {}).get(line_id, {})


static func consequence(event_id: String) -> Dictionary:
	return slice().get("consequences", {}).get(event_id, {})


static func event_ids(data: Dictionary) -> Array:
	var value: Variant = _screenplay(data).get("i03_events")
	return value.duplicate() if typeof(value) == TYPE_ARRAY else []


static func has_event(data: Dictionary, event_id: String) -> bool:
	return event_ids(data).has(event_id)


static func handles(action: String) -> bool:
	return action.begins_with("i03_")


## Phase 1 (lane, stall, resolution) runs while the bridge flag i03 is pending.
static func errand_open(data: Dictionary) -> bool:
	var s := _screenplay(data)
	return str(s.get("i03s", "")) == "pending" and str(s.get("i02", "")) == "complete" and str(s.get("i03", "")) == "pending"


## Phase 2 (farewell) opens once Julia's order is bought. The context comes
## from the childhood module: farewell_index (completed[] size at which the
## parcel is in the boy's hands), cassia (where she really stands and trades)
## and cassia_here (she is alive and at her stall).
static func farewell_open(data: Dictionary, ctx: Dictionary) -> bool:
	var s := _screenplay(data)
	var child: Dictionary = data.get("village", {}).get("childhood", {})
	return str(s.get("i03s", "")) == "pending" and str(s.get("i03", "")) == "complete" and child.get("completed", []).size() == int(ctx.farewell_index)


static func _step(id: String) -> Dictionary:
	var spec: Dictionary = slice().get("steps", {}).get(id, {})
	var step := {"id":id, "mission":"I-03", "screenplay":true, "i03":true, "text":"", "result":""}
	for key: String in ["npc", "point", "chapter", "label", "objective", "text"]:
		if spec.has(key):
			step[key] = str(spec[key])
	return step


static func current_step(data: Dictionary, ctx: Dictionary) -> Dictionary:
	var s := _screenplay(data)
	if errand_open(data):
		if str(s.i03_route).is_empty():
			return _step("i03_marcus")
		if str(s.i03_stance).is_empty():
			return _step("i03_coin")
		if str(s.i03_resolve).is_empty():
			return _step("i03_resolve")
		match str(s.i03_task):
			"measure": return _step("i03_measure")
			"service_fetch": return _step("i03_service_fetch")
			"service_bring": return _step("i03_service_bring")
	elif farewell_open(data, ctx):
		return _step("i03_farewell")
	return {}


## An open dispute is a stored fact: the boy contradicted Marcus in front of
## Cassia and neither a calm clarification nor an apology followed.
static func dispute_open(s: Dictionary) -> bool:
	return str(s.get("i03_stance", "")) == "object" and str(s.get("i03_resolve", "")) != "clarify" and not bool(s.get("i03_apology", false))


## Compatibility summary for systems that still read the older binary
## companion.choice ("help"/"decline"). Derived, never chosen.
static func summary(s: Dictionary) -> String:
	return "decline" if dispute_open(s) else "help"


static func _marcus(data: Dictionary) -> Dictionary:
	return data.get("village", {}).get("behavior", {}).get("people", {}).get("marcus", {})


static func marcus_present(data: Dictionary) -> bool:
	var observed := _marcus(data)
	return not observed.is_empty() and str(observed.get("activity", "")) != "absent"


static func marcus_position(data: Dictionary) -> Vector2:
	var coordinates: Variant = _marcus(data).get("position")
	if typeof(coordinates) == TYPE_ARRAY and coordinates.size() == 3:
		return Vector2(float(coordinates[0]), float(coordinates[2]))
	return POINTS.lane


static func _player(data: Dictionary) -> Vector2:
	var position: Array = data.player.position
	return Vector2(float(position[0]), float(position[2]))


static func marcus_stall(ctx: Dictionary) -> Vector2:
	return (ctx.cassia as Vector2) + MARCUS_OFFSET


static func _marcus_at_stall(data: Dictionary, ctx: Dictionary) -> bool:
	return marcus_present(data) and marcus_position(data).distance_to(marcus_stall(ctx)) <= STALL_RANGE


## Where the director of the living world should take Marcus. "home" is his
## usual place at the lane; "follow" walks with the boy; "stall" is his place
## in front of Cassia's stall. Presentation reads this, it stores nothing.
static func marcus_station(data: Dictionary, ctx: Dictionary) -> String:
	var s := _screenplay(data)
	if str(s.get("i03s", "")) != "pending" or str(s.get("i03_route", "")).is_empty():
		return "home"
	if str(s.i03_stance) == "missed":
		return "home"
	if str(s.i03_stance).is_empty():
		return "follow" if str(s.i03_route) == "together" else "stall"
	if str(s.i03) == "pending" and str(s.i03_task) in ["service_fetch", "service_bring"] and str(s.i03_route) == "together":
		return "follow"
	var child: Dictionary = data.get("village", {}).get("childhood", {})
	return "stall" if child.get("completed", []).size() <= int(ctx.farewell_index) else "home"


static func options(data: Dictionary, step: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var s := _screenplay(data)
	var id := str(step.get("id", ""))
	match id:
		"i03_marcus", "i03_resolve":
			for option: Dictionary in slice().steps[id].options:
				result.append({"id":str(option.id), "label":str(option.label)})
		"i03_coin":
			for option: Dictionary in slice().steps.i03_coin.options:
				# The "he did not come" exit exists only while Marcus is really absent.
				if (str(option.id) == "i03_missed") == marcus_present(data):
					continue
				result.append({"id":str(option.id), "label":str(option.label)})
		"i03_farewell":
			for option: Dictionary in slice().steps.i03_farewell.options:
				var action := str(option.id)
				if (action == "i03_home_alone") == marcus_present(data):
					continue
				if action == "i03_apologise" and not dispute_open(s):
					continue
				result.append({"id":action, "label":str(option.label)})
		"i03_measure", "i03_service_fetch", "i03_service_bring":
			result.append({"id":id, "label":str(step.get("label", ""))})
	return result


## Shared reason check for HUD, film choice and the transaction. Empty = allowed.
static func reason(data: Dictionary, action: String, ctx: Dictionary) -> String:
	if data.get("village", {}).get("raid", {}).get("active", false) or data.get("encounter", {}).get("active", false):
		return "Während unmittelbarer Gefahr ruhen diese Alltagsaufgaben."
	var step := current_step(data, ctx)
	var s := _screenplay(data)
	if action in ["i03_measure", "i03_service_bring", "i03_service_fetch"] and str(s.get("i03_salt", "")) in ["small", "large", "debt"]:
		# Gegenstand bereits bezahlt: never a second payment or service.
		return "Marcus’ Salz ist bereits bezahlt."
	if step.is_empty():
		return "Dieser Teil des Marktwegs ist gerade nicht offen."
	var offered := false
	for option: Dictionary in options(data, step):
		offered = offered or str(option.id) == action
	var here := _player(data)
	if step.has("npc") and str(step.npc) == "cassia" and not bool(ctx.cassia_here):
		return "Cassia ist gerade nicht an ihrem Stand."
	match str(step.id):
		"i03_marcus":
			if not ROUTE_ACTIONS.has(action):
				return "Sprich zuerst mit Marcus an der Gasse."
			if not marcus_present(data):
				return "Marcus ist gerade nicht an der Gasse. Niemand anderes kennt seine Abkürzung."
			if here.distance_to(marcus_position(data)) > NPC_RANGE:
				return "Geh näher zu Marcus an die Gasse."
		"i03_coin":
			if not STANCE_ACTIONS.has(action):
				return "Am Stand streiten Marcus und Cassia über den Preis. Entscheide zuerst, wie du dich verhältst."
			if here.distance_to(ctx.cassia) > NPC_RANGE:
				return "Geh zu Cassias Stand am Markt."
			if action == "i03_missed":
				if marcus_present(data):
					return "Marcus ist unterwegs zum Stand."
			elif not marcus_present(data):
				return "Marcus ist nicht am Stand. Ohne ihn gibt es keinen Streit um sein Salz."
			elif not _marcus_at_stall(data, ctx):
				return "Marcus ist noch nicht am Stand angekommen."
		"i03_resolve":
			if not RESOLVE_ACTIONS.has(action):
				return "Cassia wartet auf einen Vorschlag zum Salz."
			if here.distance_to(ctx.cassia) > NPC_RANGE:
				return "Der Vorschlag gehört an Cassias Stand."
		"i03_measure", "i03_service_bring":
			if action != str(step.id):
				if action in ["i03_measure", "i03_service_bring", "i03_service_fetch"] and str(s.i03_task) == "done":
					return "Marcus’ Salz ist bereits bezahlt."
				return "Das passt nicht zu dem, was am Stand vereinbart wurde."
			if here.distance_to(ctx.cassia) > NPC_RANGE:
				return "Geh zu Cassias Stand am Markt."
		"i03_service_fetch":
			if action != "i03_service_fetch":
				return "Hol zuerst das Wasser, das Cassia für das fehlende As nimmt."
			if here.distance_to(POINTS.well) > WELL_RANGE:
				return "Geh zum Brunnen im Hof."
		"i03_farewell":
			if not HOME_ACTIONS.has(action):
				return "Marcus wartet noch auf dich."
			if action == "i03_home_alone":
				if marcus_present(data):
					return "Marcus steht noch am Stand."
			else:
				if not marcus_present(data):
					return "Marcus ist nicht mehr am Stand."
				if here.distance_to(marcus_position(data)) > FAREWELL_RANGE:
					return "Geh zu Marcus an Cassias Stand."
				if action == "i03_apologise" and not dispute_open(s):
					return "Zwischen euch steht nichts, wofür du dich entschuldigen müsstest."
	if not offered:
		# Covers a repeated or foreign action at any step, e.g. paying twice.
		if action in ["i03_measure", "i03_service_bring", "i03_service_fetch"] and not str(s.i03_salt).is_empty():
			return "Marcus’ Salz ist bereits bezahlt."
		return "Diese Entscheidung ist bereits getroffen."
	return ""


static func _event(data: Dictionary, event_id: String, relations: Dictionary) -> bool:
	var events: Array = _screenplay(data).i03_events
	if events.has(event_id):
		return false
	events.append(event_id)
	var effects: Dictionary = consequence(event_id).get("relationship", {})
	for id: String in effects:
		var relation: Dictionary = relations.get(id, {})
		if relation.is_empty() or not relation.get("met", false):
			continue
		if effects[id].has("trust"):
			relation.trust = clampi(int(relation.trust) + int(effects[id].trust), -100, 100)
	return true


## Applies one checked I-03 action on a candidate copy. The caller owns the
## carried-item list and the companion summary (see result fields).
static func apply(data: Dictionary, action: String, ctx: Dictionary) -> Dictionary:
	var why := reason(data, action, ctx)
	if not why.is_empty():
		return {"ok":false, "message":why}
	var s := _screenplay(data)
	var written: Array[String] = []
	var message := str(slice().get("results", {}).get(action, ""))
	var result := {"ok":true, "carry_add":[], "carry_remove":[], "parted":false}
	if ROUTE_ACTIONS.has(action):
		s.i03_route = ROUTE_ACTIONS[action]
		written.append("I-03.route." + str(s.i03_route))
		message = str(line("I03_A_REACT_" + str(s.i03_route).to_upper()).get("text", ""))
	elif STANCE_ACTIONS.has(action):
		s.i03_stance = STANCE_ACTIONS[action]
		if action == "i03_missed":
			written.append("I-03.marcus.missed")
			s.i03_resolve = "refuse"
			s.i03_task = "done"
			s.i03_salt = "none"
			s.i03 = "complete"
			# Nobody to part from: the errand with Marcus ends here.
			s.i03_home = "alone"
			s.i03s = "complete"
			written.append("I-03.home.alone")
			result.parted = true
		else:
			written.append("I-03.stance." + str(s.i03_stance))
			if str(s.i03_route) == "later":
				written.append("I-03.promise.kept")
	elif RESOLVE_ACTIONS.has(action):
		s.i03_resolve = RESOLVE_ACTIONS[action]
		written.append("I-03.resolve." + str(s.i03_resolve))
		match str(s.i03_resolve):
			"clarify":
				s.i03_task = "measure"
			"accept":
				if str(s.i03_stance) == "offer":
					s.i03_task = "service_fetch"
				else:
					s.i03_task = "done"
					s.i03_salt = "debt"
					written.append("I-03.salt.debt")
			"refuse":
				s.i03_task = "done"
				s.i03_salt = "none"
				written.append("I-03.salt.none")
		message = str(resolve_line(data).get("text", ""))
		if str(s.i03_task) == "done":
			s.i03 = "complete"
	elif action == "i03_measure":
		s.i03_task = "done"
		s.i03_salt = "small"
		s.i03 = "complete"
		written.append("I-03.salt.small")
	elif action == "i03_service_fetch":
		s.i03_task = "service_bring"
		written.append("I-03.service.water")
		result.carry_add.append("stall_water")
	elif action == "i03_service_bring":
		s.i03_task = "done"
		s.i03_salt = "large"
		s.i03 = "complete"
		written.append("I-03.service.done")
		written.append("I-03.salt.large")
		result.carry_remove.append("stall_water")
	elif HOME_ACTIONS.has(action):
		if action == "i03_apologise":
			s.i03_apology = true
			written.append("I-03.apology")
		s.i03_home = HOME_ACTIONS[action]
		written.append("I-03.home." + str(s.i03_home))
		s.i03s = "complete"
		result.parted = true
		if action != "i03_home_alone":
			message = str(farewell_reply(data).get("text", ""))
	var relations: Dictionary = data.village.childhood.relationships
	for event_id: String in written:
		if not _event(data, event_id, relations):
			return {"ok":false, "message":"Dieses Ereignis ist bereits gespeichert."}
	result["message"] = message
	result["events"] = written
	return result


static func marcus_reaction_id(data: Dictionary) -> String:
	return "I03_B_MARCUS_" + str(_screenplay(data).get("i03_stance", "watch")).to_upper()


static func resolve_line_id(data: Dictionary) -> String:
	var s := _screenplay(data)
	match str(s.get("i03_resolve", "")):
		"clarify": return "I03_B_RESOLVE_CLARIFY"
		"accept": return "I03_B_RESOLVE_SERVICE" if str(s.i03_stance) == "offer" else "I03_B_RESOLVE_DEBT"
		"refuse": return "I03_B_RESOLVE_REFUSE"
	return ""


static func resolve_line(data: Dictionary) -> Dictionary:
	return line(resolve_line_id(data))


## Marcus opens the farewell according to what actually happened at the stall.
static func farewell_open_id(data: Dictionary) -> String:
	var s := _screenplay(data)
	if str(s.get("i03_stance", "")) == "object" and str(s.get("i03_resolve", "")) != "clarify":
		return "I03_C_OPEN_DISPUTE"
	match str(s.get("i03_salt", "")):
		"debt": return "I03_C_OPEN_DEBT"
		"none": return "I03_C_OPEN_NONE"
	return "I03_C_OPEN_FRIENDLY"


static func farewell_reply_id(data: Dictionary) -> String:
	var s := _screenplay(data)
	if bool(s.get("i03_apology", false)):
		return "I03_C_APOLOGY"
	match str(s.get("i03_home", "")):
		"together": return "I03_C_TOGETHER_TENSE" if dispute_open(s) else "I03_C_TOGETHER"
		"apart": return "I03_C_APART"
	return ""


static func farewell_reply(data: Dictionary) -> Dictionary:
	return line(farewell_reply_id(data))


static func expected_events(s: Dictionary) -> Array:
	var result := []
	if str(s.i03_route).is_empty():
		return result
	result.append("I-03.route." + str(s.i03_route))
	var stance := str(s.i03_stance)
	if stance == "missed":
		result.append("I-03.marcus.missed")
	elif not stance.is_empty():
		result.append("I-03.stance." + stance)
		if str(s.i03_route) == "later":
			result.append("I-03.promise.kept")
		if not str(s.i03_resolve).is_empty():
			result.append("I-03.resolve." + str(s.i03_resolve))
	if str(s.i03_task) in ["service_bring", "done"] and stance == "offer" and str(s.i03_resolve) == "accept":
		result.append("I-03.service.water")
	if str(s.i03_salt) == "large":
		result.append("I-03.service.done")
	if not str(s.i03_salt).is_empty() and stance != "missed":
		result.append("I-03.salt." + str(s.i03_salt))
	if bool(s.i03_apology):
		result.append("I-03.apology")
	if not str(s.i03_home).is_empty():
		result.append("I-03.home." + str(s.i03_home))
	return result


## Validates the slice fields against each other, the bridge flag i03 and the
## companion summary. `carried` is the childhood carry list.
static func validate(screenplay: Dictionary, companion: Dictionary, carried: Array) -> String:
	for key: String in KEYS:
		if not screenplay.has(key):
			return "I-03-Zustand unvollständig."
	var s := screenplay
	for key: String in ["i03s", "i03_route", "i03_stance", "i03_resolve", "i03_task", "i03_salt", "i03_home"]:
		if typeof(s[key]) != TYPE_STRING:
			return "Ungültiger I-03-Wert."
	if typeof(s.i03_apology) != TYPE_BOOL or typeof(s.i03_events) != TYPE_ARRAY or s.i03_events.size() > 16:
		return "Ungültige I-03-Ereignisliste."
	if s.i03s not in ["pending", "complete", "legacy"] or s.i03_route not in [""] + ROUTES or s.i03_stance not in [""] + STANCES \
			or s.i03_resolve not in [""] + RESOLVES or s.i03_task not in TASKS or s.i03_salt not in SALT or s.i03_home not in HOMES:
		return "Ungültiger I-03-Wert."
	var water := carried.has("stall_water")
	if s.i03s == "legacy":
		var untouched := legacy_state()
		for key: String in KEYS:
			if JSON.stringify(s[key]) != JSON.stringify(untouched[key]):
				return "Ein übernommener alter Spielstand darf keine erfundene I-03-Handlung enthalten."
		return "Ein alter Spielstand trägt keinen Wasserkrug für Cassia." if water else ""
	var bridge := str(s.get("i03", ""))
	var started := not str(s.i03_route).is_empty()
	if started and bridge == "locked":
		return "I-03 beginnt erst nach I-02."
	if s.i03_stance != "" and not started or s.i03_resolve != "" and s.i03_stance == "" or s.i03_task != "" and s.i03_resolve == "":
		return "Die Schritte des Marktwegs folgen aufeinander."
	if s.i03_stance == "missed" and (s.i03_resolve != "refuse" or s.i03_task != "done" or s.i03_salt != "none"):
		return "Ohne Marcus gibt es am Stand weder Streit noch Kauf."
	match str(s.i03_resolve):
		"clarify":
			if s.i03_task not in ["measure", "done"] or (s.i03_task == "done") != (s.i03_salt == "small"):
				return "Das kleine Maß muss tatsächlich abgemessen sein."
		"accept":
			if s.i03_stance == "offer":
				if s.i03_task not in ["service_fetch", "service_bring", "done"] or (s.i03_task == "done") != (s.i03_salt == "large"):
					return "Das große Maß ist erst nach dem Wasserdienst bezahlt."
			elif s.i03_task != "done" or s.i03_salt != "debt":
				return "Ohne Hilfsangebot bleibt das dritte As eine Schuld."
		"refuse":
			if s.i03_task != "done" or s.i03_salt != "none":
				return "Ohne Kauf bleibt das Salz am Stand."
		"":
			if s.i03_salt != "":
				return "Salz gibt es erst nach einer Einigung."
	if water != (s.i03_task == "service_bring"):
		return "Der Wasserkrug für Cassia wird genau während des Dienstes getragen."
	if (bridge == "complete") != (s.i03_task == "done"):
		return "Der Marktweg mit Marcus ist genau mit der Einigung am Stand abgeschlossen."
	if s.i03_home != "" and s.i03_task != "done":
		return "Der Abschied folgt erst auf die Einigung."
	if (s.i03s == "complete") != (s.i03_home != ""):
		return "I-03 ist genau mit dem Abschied von Marcus abgeschlossen."
	if s.i03_apology and (s.i03_stance != "object" or s.i03_resolve == "clarify" or s.i03_home != "together"):
		return "Eine Entschuldigung setzt den offenen Streit voraus."
	if s.i03_home == "alone" and s.i03_apology:
		return "Niemand entschuldigt sich bei einem Abwesenden."
	# Companion summary: set exactly when the two have parted, and derived.
	var met := bool(companion.get("met", false))
	if met != (s.i03s == "complete"):
		return "Die Beziehung zu Marcus wird genau beim Abschied zusammengefasst."
	if met and str(companion.get("choice", "")) != summary(s):
		return "Die Zusammenfassung der Marcus-Beziehung widerspricht den gespeicherten Erinnerungen."
	var expected := expected_events(s)
	var stored: Array = s.i03_events.duplicate()
	for id: Variant in stored:
		if typeof(id) != TYPE_STRING or stored.count(id) != 1:
			return "I-03-Ereignisse müssen eindeutig sein."
	expected.sort()
	stored.sort()
	if expected != stored:
		return "I-03-Ereignisprotokoll und Weltzustand widersprechen sich."
	return ""


## Screenplay v4 → v5. A save whose Marcus decision is already made (or that
## is past it) keeps it untouched as "legacy"; every earlier save gets the
## playable errand. Nothing is completed retroactively.
static func migrate(child: Dictionary, companion: Dictionary) -> bool:
	var screenplay: Variant = child.get("screenplay")
	if typeof(screenplay) != TYPE_DICTIONARY or int(screenplay.get("version", 0)) != 4:
		return false
	var decided: bool = str(screenplay.get("i03", "")) == "complete" or bool(companion.get("met", false)) or str(screenplay.get("i03_outcome", "")) != ""
	var added := legacy_state() if decided else fresh_state()
	for key: String in added:
		screenplay[key] = added[key]
	screenplay.version = 5
	return true


## Delayed hooks into later dialogue (same contract as I-01).
static func hook_lines(data: Dictionary, step_id: String) -> Array[String]:
	var result: Array[String] = []
	var events := event_ids(data)
	for hook: Dictionary in slice().get("hooks", []):
		if str(hook.get("step", "")) == step_id and events.has(str(hook.get("event_id", ""))):
			result.append(str(hook.line))
	return result


static func hud_place(step: Dictionary) -> String:
	match str(step.get("id", "")):
		"i03_marcus": return "Gasse zum Markt"
		"i03_service_fetch": return "Brunnen im Hof"
		"i03_coin", "i03_resolve", "i03_measure", "i03_service_bring", "i03_farewell": return "Cassias Stand"
	return ""
