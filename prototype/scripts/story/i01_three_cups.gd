extends RefCounted
## I-01 „Die drei Becher“ – playable first morning (Masterhandbuch 3.0 S. 13).
## Pure domain contract: state lives in village.childhood.screenplay (version 4),
## every decision writes one unique event into i01_events and applies the
## consequence record authored in I-01.json. Films and HUD only read this state.

const SOURCE := "res://assets/story/missions/band1/I-01.json"
const CUPS := ["julia", "silvanus", "player"]
const CONTACTS := ["marcus", "cassia", "aelia"]
const PATHS := ["talk", "help", "yard"]
const TOPICS := ["workshop", "fields", "contact"]
const NPC_RANGE := 3.2
const POINT_RANGE := 1.6
const WELL_RANGE := 2.2
## World X/Z of the family home (baker_home at (-13,0,11), yaw 0).
const HOME_ORIGIN := Vector3(-13.0, 0.3925, 11.0)
const POINTS := {
	"home_shelf":Vector2(-15.32, 12.05), "home_table":Vector2(-14.1, 10.39),
	"home_bed":Vector2(-12.05, 10.55), "home_jug":Vector2(-11.8, 11.18), "well":Vector2(-7.0, 6.0),
	"julia_table":Vector2(-14.15, 9.28), "silvanus_table":Vector2(-12.95, 10.95),
	"player_table":Vector2(-14.0, 11.55)
}
const KEYS := ["i01", "i01_path", "i01_cups", "i01_table_by", "i01_water", "i01_contacts", "i01_meal", "i01_topic", "i01_events"]
static var _slice: Dictionary = {}


static func slice() -> Dictionary:
	if _slice.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
		if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("slice")) == TYPE_DICTIONARY:
			_slice = parsed.slice
			_slice.make_read_only()
		else:
			push_error("I-01 slice data missing: " + SOURCE)
	return _slice


static func fresh_state() -> Dictionary:
	return {"i01":"pending", "i01_path":"", "i01_cups":{"julia":"shelf", "silvanus":"shelf", "player":"shelf"},
		"i01_table_by":"", "i01_water":"none", "i01_contacts":[], "i01_meal":"pending", "i01_topic":"", "i01_events":[]}


static func legacy_state() -> Dictionary:
	var state := fresh_state()
	state.i01 = "legacy"
	return state


static func _screenplay(data: Dictionary) -> Dictionary:
	var child: Variant = data.get("village", {}).get("childhood")
	if typeof(child) != TYPE_DICTIONARY or typeof(child.get("screenplay")) != TYPE_DICTIONARY:
		return {}
	return child.screenplay


## True while the I-01 slice owns the current objective (before mother_morning).
static func active(data: Dictionary) -> bool:
	var child: Variant = data.get("village", {}).get("childhood")
	if typeof(child) != TYPE_DICTIONARY or typeof(child.get("completed")) != TYPE_ARRAY or not child.completed.is_empty():
		return false
	return str(_screenplay(data).get("i01", "")) == "pending"


## True during the whole source mission I-01, including the three established
## family steps up to the father's basket. Used for the child's HUD.
static func in_mission(data: Dictionary) -> bool:
	var child: Variant = data.get("village", {}).get("childhood")
	if typeof(child) != TYPE_DICTIONARY or typeof(child.get("completed")) != TYPE_ARRAY:
		return false
	return child.completed.size() < 3


static func cups(data: Dictionary) -> Dictionary:
	var value: Variant = _screenplay(data).get("i01_cups")
	return value.duplicate() if typeof(value) == TYPE_DICTIONARY else {}


## Presentation summary used by props, HUD and films. Legacy saves show the
## cups where the former result text placed them (on the table).
static func presentation(data: Dictionary) -> Dictionary:
	var screenplay := _screenplay(data)
	var status := str(screenplay.get("i01", ""))
	var cup_state: Dictionary = cups(data)
	if status == "legacy" or cup_state.is_empty():
		cup_state = {"julia":"table", "silvanus":"table", "player":"table"}
	var child: Dictionary = data.get("village", {}).get("childhood", {})
	var water := str(screenplay.get("i01_water", "none"))
	var completed: int = child.get("completed", []).size()
	var jug := "bench"
	if completed >= 3:
		jug = "away"
	elif child.get("carried", []).has("water_jug"):
		jug = "hand"
	elif water in ["empty_jug", "jug"]:
		jug = "hand"
	elif water in ["jug_table", "poured", "silvanus"] or status == "legacy" or completed >= 2:
		jug = "table"
	# Julia stays at the breakfast table until the father has the jug (no
	# visible jump while the boy is in the house); Silvanus leaves after the
	# table talk and walks to his door work himself.
	return {"status":status, "cups":cup_state, "jug":jug, "water":water,
		"julia_at_table":status in ["pending", "complete"] and completed < 3,
		"silvanus_at_table":status == "pending" and completed == 0}


static func event_ids(data: Dictionary) -> Array:
	var value: Variant = _screenplay(data).get("i01_events")
	return value.duplicate() if typeof(value) == TYPE_ARRAY else []


static func has_event(data: Dictionary, event_id: String) -> bool:
	return event_ids(data).has(event_id)


static func _step(id: String) -> Dictionary:
	var spec: Dictionary = slice().get("steps", {}).get(id, {})
	var step := {"id":id, "mission":"I-01", "screenplay":true, "i01":true}
	for key: String in ["npc", "point", "chapter", "label", "objective", "text"]:
		if spec.has(key):
			step[key] = str(spec[key])
	if not step.has("text"):
		step["text"] = ""
	step["result"] = ""
	return step


static func current_step(data: Dictionary) -> Dictionary:
	if not active(data):
		return {}
	var s := _screenplay(data)
	var cup_state: Dictionary = s.i01_cups
	var path := str(s.i01_path)
	if path.is_empty():
		return _step("i01_choice")
	if str(s.i01_meal) == "done":
		return _step("i01_topic")
	# Recover saves produced by the former optional-well deadlock: a full
	# jug must be placed down before retrieving cups that are still on the shelf.
	if str(s.i01_water) == "jug" and not _table_set(s):
		return _step("i01_park_jug")
	if path == "help" and str(s.i01_table_by) != "player":
		return _step("i01_take_cups") if cup_state.values().has("shelf") else _step("i01_set_table")
	var water := str(s.i01_water)
	if water in ["jug", "jug_table"]:
		return _step("i01_pour")
	if water == "empty_jug":
		return _step("i01_well")
	if water == "none" and path in ["help", "talk"]:
		return _step("i01_take_jug")
	return _step("i01_meal")


static func _cup_label(owner: String) -> String:
	return {"julia":"Julias Becher abstellen", "silvanus":"Silvanus’ Becher abstellen", "player":"Deinen schiefen Becher abstellen"}[owner]


static func options(data: Dictionary, step: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var s := _screenplay(data)
	match str(step.get("id", "")):
		"i01_choice":
			for option: Dictionary in slice().steps.i01_choice.options:
				result.append({"id":str(option.id), "label":str(option.label)})
		"i01_take_cups":
			result.append({"id":"i01_take_cups", "label":"Die drei Becher vom Regal nehmen"})
		"i01_set_table":
			for owner: String in CUPS:
				if s.i01_cups[owner] == "hand":
					result.append({"id":"i01_place_" + owner, "label":_cup_label(owner)})
		"i01_park_jug":
			result.append({"id":"i01_park_jug", "label":"Den gefüllten Krug vorübergehend auf den Tisch stellen"})
		"i01_take_jug":
			result.append({"id":"i01_take_jug", "label":"Den leeren Familienkrug aufnehmen"})
		"i01_well":
			result.append({"id":"i01_well", "label":"Am Brunnen Wasser in den Krug schöpfen"})
		"i01_pour":
			result.append({"id":"i01_pour", "label":"Die drei Becher mit Brunnenwasser füllen"})
		"i01_meal":
			result.append({"id":"i01_meal", "label":"Zum Frühstück an den Tisch setzen"})
		"i01_topic":
			for option: Dictionary in slice().steps.i01_topic.options:
				var id := str(option.id)
				if id == "i01_topic_contact":
					if s.i01_contacts.is_empty():
						continue
					result.append({"id":id, "label":str(option.label) % contact_name(str(s.i01_contacts[0]))})
				else:
					result.append({"id":id, "label":str(option.label)})
	return result


## Optional point actions that are allowed while another objective leads:
## the well (a request can be fulfilled later) and the meal (it happens even
## when the player refuses to help). Both use the same checked transaction.
static func optional_actions(data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not active(data):
		return result
	var s := _screenplay(data)
	var primary := str(current_step(data).get("id", ""))
	if str(s.i01_path).is_empty() or str(s.i01_meal) == "done":
		return result
	if primary != "i01_take_jug" and str(s.i01_water) == "none" and _table_set(s):
		result.append({"id":"i01_take_jug", "label":"Den leeren Familienkrug aufnehmen", "point":"home_jug"})
	if primary != "i01_meal" and primary != "i01_pour" and _table_set(s) and str(s.i01_water) not in ["empty_jug", "jug", "jug_table"]:
		result.append({"id":"i01_meal", "label":"Ohne weitere Hilfe zum Frühstück setzen", "point":"home_table"})
	return result


static func contact_name(id: String) -> String:
	return str(slice().get("contacts", {}).get(id, id))


static func contact_line(id: String) -> String:
	return str(slice().get("contact_lines", {}).get(id, ""))


static func line(line_id: String) -> Dictionary:
	return slice().get("lines", {}).get(line_id, {})


static func consequence(event_id: String) -> Dictionary:
	return slice().get("consequences", {}).get(event_id, {})


static func handles(action: String) -> bool:
	return action.begins_with("i01_")


static func _table_set(s: Dictionary) -> bool:
	for owner: String in CUPS:
		if s.i01_cups[owner] != "table":
			return false
	return true


static func _distance(data: Dictionary, point: Vector2) -> float:
	var position: Array = data.player.position
	return Vector2(float(position[0]), float(position[2])).distance_to(point)


static func _person(data: Dictionary, id: String) -> Dictionary:
	for person: Dictionary in data.get("village", {}).get("economy", {}).get("people", []):
		if person.get("id", "") == id:
			return person
	return {}


static func _present(data: Dictionary, id: String) -> bool:
	if id == "marcus":
		var observed: Dictionary = data.get("village", {}).get("behavior", {}).get("people", {}).get("marcus", {})
		return not observed.is_empty() and str(observed.get("activity", "")) != "absent"
	var person := _person(data, id)
	return not person.is_empty() and bool(person.get("alive", false)) and not data.village.get("militia", []).has(id) and str(person.get("assignment", "")) != "defense"


## Where the contact physically is. Marcus uses his saved observed body
## (centre-height convention); villagers use their authored positions.
static func contact_position(data: Dictionary, id: String, villager_position: Vector2) -> Vector2:
	if id == "marcus":
		var observed: Dictionary = data.get("village", {}).get("behavior", {}).get("people", {}).get("marcus", {})
		var coordinates: Variant = observed.get("position")
		if typeof(coordinates) == TYPE_ARRAY and coordinates.size() == 3:
			return Vector2(float(coordinates[0]), float(coordinates[2]))
		return Vector2(-3.0, 4.0)
	return villager_position


static func contact_open(data: Dictionary, id: String) -> bool:
	if not active(data) or id not in CONTACTS:
		return false
	var s := _screenplay(data)
	return not str(s.i01_path).is_empty() and str(s.i01_meal) == "pending" and not s.i01_contacts.has(id) and _present(data, id)


## Shared reason check for HUD buttons and the transaction. Empty means allowed.
static func reason(data: Dictionary, action: String, villager_positions: Dictionary = {}) -> String:
	if not active(data):
		return "Dieser Teil des ersten Morgens ist bereits abgeschlossen."
	if data.get("village", {}).get("raid", {}).get("active", false) or data.get("encounter", {}).get("active", false):
		return "Während unmittelbarer Gefahr ruhen diese Alltagsaufgaben."
	var s := _screenplay(data)
	var path := str(s.i01_path)
	var meal := str(s.i01_meal)
	if action in ["i01_talk", "i01_help", "i01_yard"]:
		if not path.is_empty():
			return "Diese Entscheidung ist bereits getroffen."
		if not _present(data, "julia"):
			return "Julia ist gerade nicht im Haus."
		if _distance(data, POINTS.julia_table) > NPC_RANGE:
			return "Geh zu Julia an den Frühstückstisch."
		return ""
	if path.is_empty():
		return "Entscheide zuerst, was du an diesem Morgen tust."
	if action.begins_with("i01_contact_"):
		var id := action.trim_prefix("i01_contact_")
		if id not in CONTACTS:
			return "Unbekannte Begegnung."
		if meal != "pending":
			return "Das Frühstück hat bereits begonnen."
		if s.i01_contacts.has(id):
			return "Diese Begegnung ist bereits Teil deines Morgens."
		if not _present(data, id):
			return "Diese Person ist gerade nicht da."
		if _distance(data, contact_position(data, id, villager_positions.get(id, Vector2(INF, INF)))) > NPC_RANGE:
			return "Geh näher, um mit dieser Person zu sprechen."
		return ""
	if action.begins_with("i01_topic_"):
		if meal != "done":
			return "Das Tischgespräch beginnt erst beim Frühstück."
		if not str(s.i01_topic).is_empty():
			return "Ihr habt bereits über ein Thema gesprochen."
		var topic := action.trim_prefix("i01_topic_")
		if topic not in TOPICS:
			return "Unbekanntes Gesprächsthema."
		if topic == "contact" and s.i01_contacts.is_empty():
			return "Du hast heute Morgen noch niemanden draußen getroffen."
		if _distance(data, POINTS.home_table) > NPC_RANGE:
			return "Das Gespräch findet am Frühstückstisch statt."
		return ""
	if meal != "pending":
		return "Das Frühstück hat bereits begonnen."
	match action:
		"i01_take_cups":
			if path != "help":
				return "Julia hat den Tisch bereits selbst gedeckt."
			if not s.i01_cups.values().has("shelf"):
				return "Die Becher sind nicht mehr im Regal."
			if str(s.i01_water) == "jug":
				return "Stell zuerst den Wasserkrug ab."
			if _distance(data, POINTS.home_shelf) > POINT_RANGE:
				return "Geh zum Regal im Familienhaus."
		"i01_place_julia", "i01_place_silvanus", "i01_place_player":
			var owner := action.trim_prefix("i01_place_")
			if s.i01_cups.get(owner, "") != "hand":
				return "Diesen Becher hältst du gerade nicht."
			if _distance(data, POINTS.home_table) > POINT_RANGE:
				return "Geh zum Frühstückstisch."
		"i01_take_jug":
			if str(s.i01_water) != "none":
				return "Der Familienkrug wurde bereits aufgenommen oder gefüllt."
			if not _table_set(s):
				return "Stell zuerst die drei Becher auf den Tisch."
			if _distance(data, POINTS.home_jug) > POINT_RANGE:
				return "Geh zur Bank mit dem leeren Krug im Familienhaus."
		"i01_well":
			if str(s.i01_water) == "none":
				return "Nimm zuerst den leeren Familienkrug von der Bank im Haus."
			if str(s.i01_water) != "empty_jug":
				return "Für das Frühstück ist bereits Wasser geholt."
			if not _table_set(s):
				return "Decke zuerst den Tisch. Dann kannst du den Wasserkrug holen."
			if _distance(data, POINTS.well) > WELL_RANGE:
				return "Geh zum Brunnen im Hof."
		"i01_park_jug":
			if path != "help" or str(s.i01_water) != "jug" or _table_set(s):
				return "Der Krug muss jetzt nicht abgestellt werden."
			if _distance(data, POINTS.home_table) > POINT_RANGE:
				return "Geh zum Frühstückstisch, um den Krug sicher abzustellen."
		"i01_pour":
			if str(s.i01_water) not in ["jug", "jug_table"]:
				return "Du hast kein Brunnenwasser dabei."
			if not _table_set(s):
				return "Stell zuerst alle drei Becher auf den Tisch."
			if _distance(data, POINTS.home_table) > POINT_RANGE:
				return "Geh mit dem Krug zum Frühstückstisch."
		"i01_meal":
			if not _table_set(s):
				return "Der Tisch ist noch nicht gedeckt."
			if str(s.i01_water) == "empty_jug":
				return "Hol zuerst Wasser mit dem leeren Krug."
			if str(s.i01_water) in ["jug", "jug_table"]:
				return "Gieß zuerst das Wasser in die Becher."
			if _distance(data, POINTS.home_table) > POINT_RANGE:
				return "Komm an den Frühstückstisch im Familienhaus."
		_:
			return "Diese Handlung gehört nicht zum ersten Morgen."
	return ""


static func _relation(data: Dictionary, id: String) -> Dictionary:
	return data.village.childhood.relationships.get(id, {})


static func _apply_consequence(data: Dictionary, event_id: String) -> void:
	var effects: Dictionary = consequence(event_id).get("relationship", {})
	for id: String in effects:
		var relation := _relation(data, id)
		if relation.is_empty() or not relation.get("met", false):
			continue
		var effect: Dictionary = effects[id]
		if effect.has("trust"):
			relation.trust = clampi(int(relation.trust) + int(effect.trust), -100, 100)
		if bool(effect.get("helped", false)):
			relation.helped = true
			relation.declined = false
		if bool(effect.get("declined", false)) and not relation.helped:
			relation.declined = true


static func _event(data: Dictionary, event_id: String) -> bool:
	var events: Array = _screenplay(data).i01_events
	if events.has(event_id):
		return false
	events.append(event_id)
	_apply_consequence(data, event_id)
	return true


## Applies one checked I-01 action on a candidate copy. Returns ok/message and
## the event ids written, so the caller can record them in the chronicle.
static func apply(data: Dictionary, action: String, villager_positions: Dictionary = {}) -> Dictionary:
	var why := reason(data, action, villager_positions)
	if not why.is_empty():
		return {"ok":false, "message":why}
	var current := _screenplay(data)
	# Stage only mission fields: a duplicate late in a multi-event action must
	# not leave the cups, relationships or chronicle partially updated.
	var s: Dictionary = {}
	for key: String in KEYS:
		s[key] = current[key]
	s = s.duplicate(true)
	var written: Array[String] = []
	var message := ""
	if action in ["i01_talk", "i01_help", "i01_yard"]:
		var path := action.trim_prefix("i01_")
		s.i01_path = path
		if path != "help":
			# Julia sets the table herself; the cups are visibly on it afterwards.
			for owner: String in CUPS:
				s.i01_cups[owner] = "table"
			s.i01_table_by = "julia"
		written.append("I-01.choice." + path)
		message = str(line({"talk":"I01_A_REACT_TALK", "help":"I01_A_REACT_HELP", "yard":"I01_A_REACT_YARD"}[path]).get("text", ""))
	elif action == "i01_take_cups":
		for owner: String in CUPS:
			if s.i01_cups[owner] == "shelf":
				s.i01_cups[owner] = "hand"
		written.append("I-01.cups.taken")
		message = "Du nimmst die drei Becher vom oberen Regalbrett. Der schiefe liegt etwas anders in der Hand."
	elif action.begins_with("i01_place_"):
		var owner := action.trim_prefix("i01_place_")
		s.i01_cups[owner] = "table"
		written.append("I-01.cup." + owner)
		var cup_name := str(slice().cup_names[owner])
		message = "%s steht jetzt an seinem Platz am Tisch." % (cup_name.left(1).to_upper() + cup_name.substr(1))
		if _table_set(s):
			s.i01_table_by = "player"
			written.append("I-01.cups.table")
			message += " Alle drei Becher stehen am Tisch."
	elif action == "i01_take_jug":
		s.i01_water = "empty_jug"
		written.append("I-01.jug.taken")
		message = "Du nimmst den leeren Familienkrug von der Bank. Geh damit zum Brunnen im Hof."
	elif action == "i01_well":
		s.i01_water = "jug"
		written.append("I-01.water.well")
		message = "Du schöpfst am Brunnen frisches Wasser in den Familienkrug."
	elif action == "i01_park_jug":
		s.i01_water = "jug_table"
		written.append("I-01.water.parked")
		message = "Du stellst den gefüllten Krug auf den Tisch. Jetzt sind deine Hände für die Becher frei."
	elif action == "i01_pour":
		s.i01_water = "poured"
		written.append("I-01.water.poured")
		message = "Du füllst die drei Becher mit dem Brunnenwasser."
	elif action == "i01_meal":
		if str(s.i01_water) == "none":
			s.i01_water = "silvanus"
			written.append("I-01.water.silvanus")
			if str(s.i01_path) == "talk":
				written.append("I-01.request.open")
		s.i01_meal = "done"
		written.append("I-01.meal")
		message = "Die Familie setzt sich zum Frühstück an den Tisch."
	elif action.begins_with("i01_contact_"):
		var id := action.trim_prefix("i01_contact_")
		s.i01_contacts.append(id)
		written.append("I-01.contact." + id)
		message = "%s: %s" % [contact_name(id), contact_line(id)]
	elif action.begins_with("i01_topic_"):
		var topic := action.trim_prefix("i01_topic_")
		s.i01_topic = topic
		s.i01 = "complete"
		written.append("I-01.topic." + topic)
	var existing_events := event_ids(data)
	var pending_events: Dictionary = {}
	for event_id: String in written:
		if existing_events.has(event_id) or pending_events.has(event_id):
			return {"ok":false, "message":"Dieses Ereignis ist bereits gespeichert."}
		pending_events[event_id] = true
	for key: String in KEYS:
		current[key] = s[key]
	for event_id: String in written:
		_event(data, event_id)
	if action.begins_with("i01_topic_"):
		message = str(topic_line(data).get("text", ""))
	return {"ok":true, "message":message, "events":written}


static func topic_line(data: Dictionary) -> Dictionary:
	var s := _screenplay(data)
	match str(s.get("i01_topic", "")):
		"workshop": return line("I01_B_TOPIC_WORKSHOP")
		"fields": return line("I01_B_TOPIC_FIELDS")
		"contact":
			return line("I01_B_TOPIC_CONTACT_" + str(s.i01_contacts[0]).to_upper())
	return {}


## Julia's reaction in VID-B follows the stored facts, never the button label.
static func julia_reaction_id(data: Dictionary) -> String:
	var s := _screenplay(data)
	var table_by_player := str(s.get("i01_table_by", "")) == "player"
	var water := str(s.get("i01_water", "none"))
	if table_by_player and water == "poured":
		return "I01_B_JULIA_FULL"
	if table_by_player:
		return "I01_B_JULIA_CUPS"
	if water == "poured":
		return "I01_B_JULIA_WATER"
	if str(s.get("i01_path", "")) == "talk":
		return "I01_B_JULIA_DECLINED"
	return "I01_B_JULIA_ABSENT"


static func expected_events(s: Dictionary) -> Array:
	var result := []
	var path := str(s.i01_path)
	if path.is_empty():
		return result
	result.append("I-01.choice." + path)
	if path == "help":
		if not s.i01_cups.values().has("shelf"):
			result.append("I-01.cups.taken")
		for owner: String in CUPS:
			if s.i01_cups[owner] == "table":
				result.append("I-01.cup." + owner)
		if str(s.i01_table_by) == "player":
			result.append("I-01.cups.table")
	# Already-filled saves from older builds never invent a pickup event.
	if str(s.i01_water) == "empty_jug" or (str(s.i01_water) in ["jug", "jug_table", "poured"] and s.i01_events.has("I-01.jug.taken")):
		result.append("I-01.jug.taken")
	if str(s.i01_water) in ["jug", "jug_table", "poured"]:
		result.append("I-01.water.well")
	if str(s.i01_water) == "jug_table" or (str(s.i01_water) == "poured" and path == "help" and s.i01_events.has("I-01.water.parked")):
		result.append("I-01.water.parked")
	if str(s.i01_water) == "poured":
		result.append("I-01.water.poured")
	if str(s.i01_water) == "silvanus":
		result.append("I-01.water.silvanus")
		if path == "talk":
			result.append("I-01.request.open")
	for id: Variant in s.i01_contacts:
		result.append("I-01.contact." + str(id))
	if str(s.i01_meal) == "done":
		result.append("I-01.meal")
	if not str(s.i01_topic).is_empty():
		result.append("I-01.topic." + str(s.i01_topic))
	return result


static func validate(screenplay: Dictionary, completed: int) -> String:
	for key: String in KEYS:
		if not screenplay.has(key):
			return "I-01-Zustand unvollständig."
	var status: Variant = screenplay.i01
	if typeof(status) != TYPE_STRING or status not in ["pending", "complete", "legacy"]:
		return "Ungültiger I-01-Status."
	if completed > 0 and status == "pending":
		return "I-01 darf nach dem Familiengespräch nicht mehr offen sein."
	var path: Variant = screenplay.i01_path
	var cup_state: Variant = screenplay.i01_cups
	if typeof(path) != TYPE_STRING or path not in ["", "talk", "help", "yard"]:
		return "Ungültiger I-01-Weg."
	if typeof(cup_state) != TYPE_DICTIONARY or cup_state.size() != CUPS.size():
		return "Ungültige Becherzustände."
	for owner: String in CUPS:
		if not cup_state.has(owner) or typeof(cup_state[owner]) != TYPE_STRING or cup_state[owner] not in ["shelf", "hand", "table"]:
			return "Ungültiger Becherzustand."
	for key: String in ["i01_table_by", "i01_water", "i01_meal", "i01_topic"]:
		if typeof(screenplay[key]) != TYPE_STRING:
			return "Ungültiger I-01-Wert."
	if screenplay.i01_table_by not in ["", "player", "julia"] or screenplay.i01_water not in ["none", "empty_jug", "jug", "jug_table", "poured", "silvanus"] or screenplay.i01_meal not in ["pending", "done"] or screenplay.i01_topic not in ["", "workshop", "fields", "contact"]:
		return "Ungültiger I-01-Wert."
	if typeof(screenplay.i01_contacts) != TYPE_ARRAY or typeof(screenplay.i01_events) != TYPE_ARRAY or screenplay.i01_events.size() > 24:
		return "Ungültige I-01-Ereignisliste."
	for id: Variant in screenplay.i01_contacts:
		if typeof(id) != TYPE_STRING or id not in CONTACTS or screenplay.i01_contacts.count(id) != 1:
			return "Ungültige I-01-Begegnung."
	if status == "legacy":
		var untouched := legacy_state()
		for key: String in KEYS:
			if JSON.stringify(screenplay[key]) != JSON.stringify(untouched[key]):
				return "Ein übernommener alter Spielstand darf keine erfundene I-01-Handlung enthalten."
		return ""
	var values: Array = []
	for owner: String in CUPS:
		values.append(cup_state[owner])
	if path == "":
		if values != ["shelf", "shelf", "shelf"] or screenplay.i01_table_by != "" or screenplay.i01_water != "none" or not screenplay.i01_contacts.is_empty() or screenplay.i01_meal != "pending" or screenplay.i01_topic != "":
			return "Vor der ersten Entscheidung darf am Morgen nichts geschehen sein."
	elif path == "help":
		if values.has("shelf") and values.has("hand") or values.has("shelf") and values.has("table"):
			return "Die drei Becher werden gemeinsam vom Regal genommen."
		var all_table: bool = not values.has("shelf") and not values.has("hand")
		if (screenplay.i01_table_by == "player") != all_table or screenplay.i01_table_by == "julia":
			return "Der gedeckte Tisch muss durch tatsächlich abgestellte Becher belegt sein."
	else:
		if values != ["table", "table", "table"] or screenplay.i01_table_by != "julia":
			return "Ohne Mithilfe deckt Julia den Tisch selbst."
	var table_set: bool = values == ["table", "table", "table"]
	if screenplay.i01_water == "jug_table" and path != "help":
		return "Ein abgestellter voller Krug gehört nur zur Tischdeckhilfe."
	if screenplay.i01_water == "empty_jug" and not table_set:
		return "Der leere Krug wird erst bei gedecktem Tisch aufgenommen."
	if screenplay.i01_water in ["empty_jug", "jug"] and values.has("hand"):
		return "Becher und Krug können nicht gleichzeitig getragen werden."
	if screenplay.i01_water == "poured" and not table_set:
		return "Wasser kann nur in gedeckte Becher gegossen werden."
	if screenplay.i01_water == "silvanus" and screenplay.i01_meal != "done":
		return "Silvanus holt das Wasser erst, wenn das Frühstück ohne dich beginnt."
	if screenplay.i01_meal == "done" and (not table_set or screenplay.i01_water not in ["poured", "silvanus"]):
		return "Das Frühstück benötigt einen gedeckten Tisch und Wasser."
	if screenplay.i01_topic != "" and screenplay.i01_meal != "done":
		return "Das Tischgespräch folgt erst auf das Frühstück."
	if screenplay.i01_topic == "contact" and screenplay.i01_contacts.is_empty():
		return "Es gibt keine erzählbare Begegnung."
	if (status == "complete") != (screenplay.i01_topic != ""):
		return "I-01 ist genau mit dem Tischgespräch abgeschlossen."
	var expected := expected_events(screenplay)
	var stored: Array = screenplay.i01_events.duplicate()
	for id: Variant in stored:
		if typeof(id) != TYPE_STRING or stored.count(id) != 1:
			return "I-01-Ereignisse müssen eindeutig sein."
	expected.sort()
	stored.sort()
	if expected != stored:
		return "I-01-Ereignisprotokoll und Weltzustand widersprechen sich."
	return ""


## Screenplay v3 → v4. A save that has not yet spoken with Julia gets the new
## playable morning (nothing is completed for it); any later save keeps its
## progress and is marked "legacy" so no I-01 action is invented.
static func migrate(child: Dictionary) -> bool:
	var screenplay: Variant = child.get("screenplay")
	if typeof(screenplay) != TYPE_DICTIONARY or int(screenplay.get("version", 0)) != 3 or typeof(child.get("completed")) != TYPE_ARRAY:
		return false
	var added := fresh_state() if child.completed.is_empty() else legacy_state()
	for key: String in added:
		screenplay[key] = added[key]
	screenplay.version = 4
	return true


## Interactable world points for the active morning (primary plus optional).
static func interactables(data: Dictionary, reason_for: Callable) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not active(data):
		return result
	var step := current_step(data)
	var entries: Array[Dictionary] = []
	if step.has("point"):
		for option: Dictionary in options(data, step):
			entries.append({"id":option.id, "label":option.label, "point":str(step.point)})
	entries.append_array(optional_actions(data))
	for entry: Dictionary in entries:
		var point: Vector2 = POINTS[entry.point]
		var why: String = reason_for.call(entry.id)
		result.append({"id":"childhood_" + str(entry.id), "kind":"childhood", "label":entry.label,
			"action_id":entry.id, "point":point, "command":"village_childhood_action",
			"payload":{"action_id":entry.id}, "enabled":why.is_empty(), "reason":why,
			"x":point.x, "z":point.y, "position":[point.x, point.y],
			"radius":WELL_RANGE if entry.point == "well" else POINT_RANGE})
	return result


## Delayed hooks: a later step's dialogue starts with a remembered line when
## the triggering I-01 event is in the ledger.
static func hook_lines(data: Dictionary, step_id: String) -> Array[String]:
	var result: Array[String] = []
	var events := event_ids(data)
	for hook: Dictionary in slice().get("hooks", []):
		if str(hook.get("step", "")) == step_id and events.has(str(hook.get("event_id", ""))):
			result.append(str(hook.line))
	return result


## HUD heading: occasion and place, never a technical mission ID (HB S. 44).
static func hud_place(step: Dictionary) -> String:
	var point := str(step.get("point", ""))
	var npc := str(step.get("npc", ""))
	if point in ["home_shelf", "home_table", "home_bed", "home_jug", "family_water", "family_rest"] or npc in ["julia", "silvanus"] and str(step.get("id", "")).begins_with("i01_"):
		return "Familienhaus"
	if point == "well":
		return "Brunnen im Hof"
	return ""
