extends RefCounted
## I-04 „Der Freund meines Vaters“ – the workshop visit between the delivered
## kindling and the father's permission (Masterhandbuch 3.0 S. 15, Original-
## blatt S. 71). Pure domain contract like I-01/I-03: the state lives in
## village.childhood.screenplay (version 6), every decision writes one unique
## event into i04_events. Films, props and HUD only read this state.
##
## The boy chooses his work (stack the delivered kindling at the hearth, carry
## Sextus' message to his charcoal supplier, or watch first), then asks about
## the craft, the horses or his father. Nothing here hands out wood, money or
## a weapon; the delivered bundle is never rewarded a second time.

const EventBatch := preload("res://scripts/story/mission_event_batch.gd")
const SOURCE := "res://assets/story/missions/band1/I-04.json"
const WORKS := ["stack", "message", "watch"]
const TOPICS := ["craft", "riding", "father"]
const NOTES := ["", "carried", "given"]
const STICKS := 2
const NPC_RANGE := 3.2
const POINT_RANGE := 1.6
const KEYS := ["i04s", "i04_work", "i04_sticks", "i04_hand", "i04_note", "i04_topic", "i04_events"]
const WORK_ACTIONS := {"i04_stack":"stack", "i04_message":"message", "i04_watch":"watch"}
const TOPIC_ACTIONS := {"i04_topic_craft":"craft", "i04_topic_riding":"riding", "i04_topic_father":"father"}
static var _slice: Dictionary = {}


static func slice() -> Dictionary:
	if _slice.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
		if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("slice")) == TYPE_DICTIONARY:
			_slice = parsed.slice
			_slice.make_read_only()
		else:
			push_error("I-04 slice data missing: " + SOURCE)
	return _slice


static func fresh_state() -> Dictionary:
	return {"i04s":"pending", "i04_work":"", "i04_sticks":0, "i04_hand":false, "i04_note":"", "i04_topic":"", "i04_events":[]}


static func legacy_state() -> Dictionary:
	var state := fresh_state()
	state.i04s = "legacy"
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
	var value: Variant = _screenplay(data).get("i04_events")
	return value.duplicate() if typeof(value) == TYPE_ARRAY else []


static func has_event(data: Dictionary, event_id: String) -> bool:
	return event_ids(data).has(event_id)


static func handles(action: String) -> bool:
	return action.begins_with("i04_")


## The visit is open exactly between the delivered bundle and the father's
## permission. ctx.index is that completed[] size.
static func active(data: Dictionary, ctx: Dictionary) -> bool:
	var child: Dictionary = data.get("village", {}).get("childhood", {})
	return str(_screenplay(data).get("i04s", "")) == "pending" and child.get("completed", []).size() == int(ctx.index)


static func _step(id: String) -> Dictionary:
	var spec: Dictionary = slice().get("steps", {}).get(id, {})
	var step := {"id":id, "mission":"I-04", "screenplay":true, "i04":true, "text":"", "result":""}
	for key: String in ["npc", "point", "chapter", "label", "objective", "text"]:
		if spec.has(key):
			step[key] = str(spec[key])
	return step


static func current_step(data: Dictionary, ctx: Dictionary) -> Dictionary:
	if not active(data, ctx):
		return {}
	var s := _screenplay(data)
	match str(s.i04_work):
		"":
			return _step("i04_work")
		"stack":
			if int(s.i04_sticks) < STICKS:
				return _step("i04_stack_put") if bool(s.i04_hand) else _step("i04_stack_take")
		"message":
			if str(s.i04_note) == "carried":
				return _step("i04_note_give")
	return _step("i04_topic")


static func options(_data: Dictionary, step: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var id := str(step.get("id", ""))
	match id:
		"i04_work", "i04_topic":
			for option: Dictionary in slice().steps[id].options:
				result.append({"id":str(option.id), "label":str(option.label)})
		"i04_stack_take", "i04_stack_put", "i04_note_give":
			result.append({"id":id, "label":str(step.get("label", ""))})
	return result


static func _player(data: Dictionary) -> Vector2:
	var position: Array = data.player.position
	return Vector2(float(position[0]), float(position[2]))


## Shared reason check for HUD, film choice and the transaction. Empty = allowed.
static func reason(data: Dictionary, action: String, ctx: Dictionary) -> String:
	if data.get("village", {}).get("raid", {}).get("active", false) or data.get("encounter", {}).get("active", false):
		return "Während unmittelbarer Gefahr ruhen diese Alltagsaufgaben."
	var s := _screenplay(data)
	if action in ["i04_stack_take", "i04_stack_put"] and int(s.get("i04_sticks", 0)) >= STICKS:
		# The delivered wood is stacked once; it is never rewarded again.
		return "Das Kleinholz liegt bereits vollständig an der Esse."
	if action == "i04_note_give" and str(s.get("i04_note", "")) == "given":
		return "Fabius hat Sextus’ Nachricht bereits."
	var step := current_step(data, ctx)
	if step.is_empty():
		return "Der Besuch in der Schmiede ist gerade nicht offen."
	var here := _player(data)
	var id := str(step.id)
	match id:
		"i04_work", "i04_topic":
			var wanted: Dictionary = WORK_ACTIONS if id == "i04_work" else TOPIC_ACTIONS
			if not wanted.has(action):
				return "Sextus wartet auf deine Antwort." if id == "i04_work" else "Sextus hat zwei Zangen auf den Amboss gelegt. Sag ihm, was du wissen willst."
			if not bool(ctx.sextus_here):
				return "Sextus ist gerade nicht in der Schmiede. Niemand anderes führt seine Werkstatt."
			if here.distance_to(ctx.sextus) > NPC_RANGE:
				return "Geh zu Sextus in die Schmiede."
		"i04_stack_take":
			if action != id:
				return "Hol zuerst Kleinholz vom Bündel am Kühltrog."
			if here.distance_to(ctx.bundle) > POINT_RANGE:
				return "Geh zum abgelegten Bündel am Kühltrog."
		"i04_stack_put":
			if action != id:
				return "Du hältst noch Kleinholz im Arm. Schichte es neben dem Blasebalg auf."
			if here.distance_to(ctx.hearth) > POINT_RANGE:
				return "Trag das Kleinholz zum Blasebalg an der Esse."
		"i04_note_give":
			if action != id:
				return "Bring zuerst Sextus’ Nachricht zu Fabius."
			if not bool(ctx.fabius_here):
				return "Fabius ist gerade nicht im Dorf. Die Nachricht ist nur für ihn bestimmt."
			if here.distance_to(ctx.fabius) > NPC_RANGE:
				return "Geh zu Fabius, dem Holzfäller."
	return ""


## Applies one checked I-04 action on a candidate copy. The caller owns the
## carried-item list (see result fields).
static func apply(data: Dictionary, action: String, ctx: Dictionary) -> Dictionary:
	var why := reason(data, action, ctx)
	if not why.is_empty():
		return {"ok":false, "message":why}
	var current := _screenplay(data)
	var s: Dictionary = EventBatch.stage(current, KEYS)
	if s.is_empty():
		return {"ok":false, "message":"Ungültiger Missionszustand."}
	var written: Array[String] = []
	var message := str(slice().get("results", {}).get(action, ""))
	var result := {"ok":true, "carry_add":[], "carry_remove":[]}
	if WORK_ACTIONS.has(action):
		s.i04_work = WORK_ACTIONS[action]
		written.append("I-04.work." + str(s.i04_work))
		if str(s.i04_work) == "message":
			s.i04_note = "carried"
			result.carry_add.append("sextus_note")
		message = str(line("I04_A_REACT_" + str(s.i04_work).to_upper()).get("text", ""))
	elif action == "i04_stack_take":
		s.i04_hand = true
	elif action == "i04_stack_put":
		s.i04_hand = false
		s.i04_sticks = int(s.i04_sticks) + 1
		if int(s.i04_sticks) >= STICKS:
			written.append("I-04.stack.done")
			message = str(slice().results.i04_stack_done)
	elif action == "i04_note_give":
		s.i04_note = "given"
		written.append("I-04.note.given")
		result.carry_remove.append("sextus_note")
	elif TOPIC_ACTIONS.has(action):
		s.i04_topic = TOPIC_ACTIONS[action]
		s.i04s = "complete"
		written.append("I-04.topic." + str(s.i04_topic))
	if not EventBatch.commit(current, KEYS, s, "i04_events", written):
		return {"ok":false, "message":"Ungültige oder bereits gespeicherte Handlung."}
	if TOPIC_ACTIONS.has(action):
		message = str(topic_line(data).get("text", ""))
	result["message"] = message
	result["events"] = written
	result["event_id"] = written[0] if not written.is_empty() else ""
	return result


static func topic_line_id(data: Dictionary) -> String:
	var topic := str(_screenplay(data).get("i04_topic", ""))
	return "I04_B_TOPIC_" + topic.to_upper() if not topic.is_empty() else ""


static func topic_line(data: Dictionary) -> Dictionary:
	return line(topic_line_id(data))


## Sextus comments on what the boy really did before the talk.
static func work_line_id(data: Dictionary) -> String:
	return "I04_B_WORK_" + str(_screenplay(data).get("i04_work", "watch")).to_upper()


## The cold bent nail lies on the anvil block only after the craft talk.
static func nail_kept(data: Dictionary) -> bool:
	return str(_screenplay(data).get("i04_topic", "")) == "craft"


static func expected_events(s: Dictionary) -> Array:
	var result := []
	if str(s.i04_work).is_empty():
		return result
	result.append("I-04.work." + str(s.i04_work))
	if int(s.i04_sticks) >= STICKS:
		result.append("I-04.stack.done")
	if str(s.i04_note) == "given":
		result.append("I-04.note.given")
	if not str(s.i04_topic).is_empty():
		result.append("I-04.topic." + str(s.i04_topic))
	return result


## `completed` is the childhood step count, `index` the size at which the
## visit is open, `carried` the childhood carry list.
static func validate(screenplay: Dictionary, completed: int, index: int, carried: Array) -> String:
	for key: String in KEYS:
		if not screenplay.has(key):
			return "I-04-Zustand unvollständig."
	var s := screenplay
	for key: String in ["i04s", "i04_work", "i04_note", "i04_topic"]:
		if typeof(s[key]) != TYPE_STRING:
			return "Ungültiger I-04-Wert."
	if typeof(s.i04_hand) != TYPE_BOOL or typeof(s.i04_events) != TYPE_ARRAY or s.i04_events.size() > 8:
		return "Ungültige I-04-Ereignisliste."
	if typeof(s.i04_sticks) not in [TYPE_INT, TYPE_FLOAT] or float(s.i04_sticks) != floorf(float(s.i04_sticks)) or int(s.i04_sticks) < 0 or int(s.i04_sticks) > STICKS:
		return "Ungültige Menge geschichteten Kleinholzes."
	if s.i04s not in ["pending", "complete", "legacy"] or s.i04_work not in [""] + WORKS or s.i04_note not in NOTES or s.i04_topic not in [""] + TOPICS:
		return "Ungültiger I-04-Wert."
	var note := carried.has("sextus_note")
	if s.i04s == "legacy":
		var untouched := legacy_state()
		for key: String in KEYS:
			var same: bool = int(s[key]) == int(untouched[key]) if key == "i04_sticks" else s[key] == untouched[key]
			if not same:
				return "Ein übernommener alter Spielstand darf keine erfundene I-04-Handlung enthalten."
		return "Ein alter Spielstand trägt keine Nachricht von Sextus." if note else ""
	if completed < index and (s.i04s != "pending" or s.i04_work != ""):
		return "Der Werkstattbesuch beginnt erst mit dem gebrachten Kleinholz."
	if completed > index and s.i04s != "complete":
		return "Die Erlaubnis des Vaters folgt erst auf den Werkstattbesuch."
	if s.i04_work != "stack" and (int(s.i04_sticks) != 0 or s.i04_hand):
		return "Kleinholz wird nur geschichtet, wenn du diese Arbeit übernommen hast."
	if s.i04_hand and int(s.i04_sticks) >= STICKS:
		return "Es ist kein Kleinholz mehr zum Tragen da."
	if (s.i04_work == "message") != (s.i04_note != ""):
		return "Die Nachricht gehört genau zum Botengang."
	if note != (s.i04_note == "carried"):
		return "Sextus’ Nachricht wird genau während des Botengangs getragen."
	if s.i04_topic != "":
		if s.i04_work == "" or s.i04_work == "stack" and (int(s.i04_sticks) < STICKS or s.i04_hand) or s.i04_work == "message" and s.i04_note != "given":
			return "Das Gespräch am Amboss folgt erst auf die übernommene Arbeit."
	if (s.i04s == "complete") != (s.i04_topic != ""):
		return "Der Werkstattbesuch ist genau mit dem Gespräch am Amboss abgeschlossen."
	var expected := expected_events(s)
	var stored: Array = s.i04_events.duplicate()
	for id: Variant in stored:
		if typeof(id) != TYPE_STRING or stored.count(id) != 1:
			return "I-04-Ereignisse müssen eindeutig sein."
	expected.sort()
	stored.sort()
	if expected != stored:
		return "I-04-Ereignisprotokoll und Weltzustand widersprechen sich."
	return ""


## Screenplay v5 → v6. A save that has already brought the kindling and moved
## on keeps its progress as "legacy"; every earlier save gets the visit.
static func migrate(child: Dictionary, index: int) -> bool:
	var screenplay: Variant = child.get("screenplay")
	if typeof(screenplay) != TYPE_DICTIONARY or int(screenplay.get("version", 0)) != 5 or typeof(child.get("completed")) != TYPE_ARRAY:
		return false
	var added := legacy_state() if child.completed.size() >= index else fresh_state()
	for key: String in added:
		screenplay[key] = added[key]
	screenplay.version = 6
	return true


## Delayed hooks into later dialogue (same contract as I-01 and I-03).
static func hook_lines(data: Dictionary, step_id: String) -> Array[String]:
	var result: Array[String] = []
	var events := event_ids(data)
	for hook: Dictionary in slice().get("hooks", []):
		if str(hook.get("step", "")) == step_id and events.has(str(hook.get("event_id", ""))):
			result.append(str(hook.line))
	return result


static func hud_place(step: Dictionary) -> String:
	match str(step.get("id", "")):
		"i04_work", "i04_topic", "i04_stack_take", "i04_stack_put": return "Schmiede des Sextus"
		"i04_note_give": return "bei Fabius"
	return ""
