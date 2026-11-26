extends RefCounted
## I-03 in-engine films (Klasse B, HB S. 14 and S. 22–29). Pure functions of
## the saved state, like the I-01 films: a film commits nothing by itself,
## choice beats name the childhood step they await, skipping stops at an open
## choice. Voices are produced later; every spoken beat keeps a stable
## line_id and speaker_id, pauses and reaction shots carry none.

const I03 = preload("res://scripts/story/i03_shortcut.gd")
const I01 = preload("res://scripts/story/i01_three_cups.gd")
const VID_A := "i03_vid_a"
const VID_B := "i03_vid_b"
const VID_C := "i03_vid_c"
const IDS := [VID_A, VID_B, VID_C]
const CHAPTER := "Kapitel I · Marcus kennt eine Abkürzung"
const LANE := "Valdora · Gasse zum Markt · Frühjahr 58 v. Chr."
const STALL := "Valdora · Cassias Stand · Frühjahr 58 v. Chr."
const SPEAKERS := {"marcus":["Marcus", "Zwölf Jahre · Nachbarssohn"], "cassia":["Cassia", "Händlerin"], "chronik":["Chronik", "Ein Vormittag in Valdora"], "player":["Du", "Zwölf Jahre"]}


static func _beat(id: String, shot_id: String, line_id: String, minimum: float, actor_id: String, location: String) -> Dictionary:
	var line: Dictionary = I03.line(line_id)
	var speaker_id := str(line.get("speaker_id", "chronik"))
	var text := str(line.get("text", ""))
	var names: Array = SPEAKERS.get(speaker_id, [speaker_id.capitalize(), ""])
	return {"id":id, "shot_id":shot_id, "line_id":line_id, "speaker_id":speaker_id,
		"speaker":names[0], "role":names[1], "text":text, "actor_id":actor_id,
		"duration":maxf(minimum, 2.0 + text.length() / 17.0), "chapter":CHAPTER, "location":location,
		"voice":"pending_recording"}


static func _pause(id: String, shot_id: String, seconds: float, actor_id: String, location: String, anchor := "") -> Dictionary:
	return {"id":id, "shot_id":shot_id, "line_id":"", "speaker_id":"", "speaker":"", "role":"", "text":"",
		"actor_id":actor_id, "anchor":anchor, "duration":seconds, "chapter":CHAPTER, "location":location, "silent":true, "voice":"none"}


static func _choice(id: String, step_id: String, actor_id: String, location: String, data: Dictionary) -> Dictionary:
	var spec: Dictionary = I03.slice().steps[step_id]
	var choices: Array[Dictionary] = []
	for option: Dictionary in I03.options(data, {"id":step_id}):
		choices.append({"label":str(option.label), "action_id":str(option.id)})
	return {"id":id, "shot_id":"duo_ots", "line_id":"", "speaker_id":"player", "speaker":"Du", "role":"Zwölf Jahre",
		"text":str(spec.get("prompt", "")), "actor_id":actor_id, "duration":4.0, "chapter":CHAPTER, "location":location,
		"await_choice":true, "choice_step":step_id, "choices":choices, "voice":"none"}


static func _cuts(beat: Dictionary, cuts: Array) -> Dictionary:
	beat["cuts"] = cuts
	return beat


static func _sequence(id: String, film_id: String, title: String, location: String, beats: Array[Dictionary], objective_title: String, objective: String) -> Dictionary:
	return {"id":id, "version":1, "origin_id":"italia", "source_mission_id":"I-03", "film_id":film_id,
		"title":title, "location":location, "chapter":CHAPTER, "beats":beats,
		"objective_title":objective_title, "objective_text":objective, "handoff_label":"Weiter"}


static func _objective(data: Dictionary, ctx: Dictionary, fallback: String) -> String:
	return str(I03.current_step(data, ctx).get("objective", fallback))


## VID-A: the coins in Marcus' fist open the picture, then both boys in the
## same lane, his own worry, the route choice and his answer.
static func vid_a(data: Dictionary, ctx: Dictionary) -> Dictionary:
	var route := str(data.village.childhood.screenplay.get("i03_route", ""))
	var street := _cuts(_beat("i03_a_street", "duo_wide", "I03_A_STREET", 8.0, "marcus", LANE),
		[{"at":0.0, "shot_id":"duo_wide", "actor_id":"marcus"}, {"at":0.5, "shot_id":"duo_close", "actor_id":"marcus"}])
	var worry := _cuts(_beat("i03_a_worry", "duo_close", "I03_A_WORRY", 8.0, "marcus", LANE),
		[{"at":0.0, "shot_id":"duo_close", "actor_id":"marcus"}, {"at":0.66, "shot_id":"duo_react", "actor_id":"marcus"}])
	var beats: Array[Dictionary] = [
		_beat("i03_a_coins", "duo_hands", "I03_A_COINS", 6.0, "marcus", LANE),
		street,
		worry,
		_pause("i03_a_pause", "duo_wide", 2.2, "marcus", LANE),
		_choice("i03_a_choice", "i03_marcus", "marcus", LANE, data),
		_beat("i03_a_react", "duo_close", "I03_A_REACT_" + (route.to_upper() if not route.is_empty() else "TOGETHER"), 4.0, "marcus", LANE)]
	if I01.has_event(data, "I-01.contact.marcus"):
		# Delayed hook of the I-01 encounter: a shared memory, not a loyalty value.
		beats.insert(1, _beat("i03_a_hook", "duo_close", "I03_A_HOOK_WELL", 5.0, "marcus", LANE))
	return _sequence(VID_A, "I-03.VID-A", "An der Gasse", LANE, beats, "Marcus kennt eine Abkürzung · Markt",
		_objective(data, ctx, "Marcus wartet an der Gasse auf deine Antwort."))


## VID-B: Cassia explains the two prices over the coins on her stall; Marcus
## answers according to the boy's stored stance; the proposal is the choice.
static func vid_b(data: Dictionary, ctx: Dictionary) -> Dictionary:
	var resolve_id := I03.resolve_line_id(data)
	var explain := _cuts(_beat("i03_b_cassia", "duo_close", "I03_B_CASSIA", 11.0, "cassia", STALL),
		[{"at":0.0, "shot_id":"duo_close", "actor_id":"cassia"}, {"at":0.42, "shot_id":"duo_close", "actor_id":"marcus"},
		{"at":0.62, "shot_id":"duo_close", "actor_id":"cassia"}])
	var marcus := _cuts(_beat("i03_b_marcus", "duo_close", I03.marcus_reaction_id(data), 5.0, "marcus", STALL),
		[{"at":0.0, "shot_id":"duo_close", "actor_id":"marcus"}, {"at":0.68, "shot_id":"duo_react", "actor_id":"marcus"}])
	var beats: Array[Dictionary] = [
		_beat("i03_b_stall", "duo_wide", "I03_B_STALL", 5.0, "cassia", STALL),
		_pause("i03_b_coins", "prop_insert", 2.8, "cassia", STALL, "i03_coins"),
		explain,
		_pause("i03_b_look", "duo_react", 2.2, "marcus", STALL),
		marcus,
		_choice("i03_b_choice", "i03_resolve", "cassia", STALL, data),
		_beat("i03_b_reply", "duo_close", resolve_id if not resolve_id.is_empty() else "I03_B_RESOLVE_CLARIFY", 6.0, "cassia", STALL),
		_pause("i03_b_after", "duo_close", 2.4, "marcus", STALL)]
	return _sequence(VID_B, "I-03.VID-B", "Zwei Asse, drei Asse", STALL, beats, "Marcus kennt eine Abkürzung · Cassias Stand",
		_objective(data, ctx, "Julia hat bei Cassia Brot und Grütze bestellt. Frag an ihrem Stand danach."))


## VID-C: Marcus opens according to what really happened; the boy decides
## how they part; an apology is offered only while a dispute is open.
static func vid_c(data: Dictionary, ctx: Dictionary) -> Dictionary:
	var reply_id := I03.farewell_reply_id(data)
	var open := _cuts(_beat("i03_c_open", "duo_close", I03.farewell_open_id(data), 5.0, "marcus", STALL),
		[{"at":0.0, "shot_id":"duo_close", "actor_id":"marcus"}, {"at":0.7, "shot_id":"duo_react", "actor_id":"marcus"}])
	var beats: Array[Dictionary] = [
		_pause("i03_c_pot", "prop_insert", 2.6, "marcus", STALL, "i03_pot"),
		open,
		_choice("i03_c_choice", "i03_farewell", "marcus", STALL, data),
		_beat("i03_c_reply", "duo_close", reply_id if not reply_id.is_empty() else "I03_C_TOGETHER", 4.0, "marcus", STALL),
		_pause("i03_c_after", "duo_wide", 2.4, "marcus", STALL)]
	return _sequence(VID_C, "I-03.VID-C", "Der Heimweg", STALL, beats, "Marcus kennt eine Abkürzung · Heimweg",
		_objective(data, ctx, "Bring Julias Bestellung nach Hause."))


## Rebuilds a film for a checkpoint or after a committed choice. A film is
## only restored while its own part of the errand is still the current one
## or was just decided; otherwise there is nothing to resume.
static func restore(data: Dictionary, sequence_id: String, ctx: Dictionary) -> Dictionary:
	var s: Dictionary = data.get("village", {}).get("childhood", {}).get("screenplay", {})
	if str(s.get("i03s", "")) not in ["pending", "complete"]:
		return {}
	match sequence_id:
		VID_A:
			if str(s.get("i03_stance", "")).is_empty() and str(s.get("i02", "")) == "complete":
				return vid_a(data, ctx)
		VID_B:
			if str(s.get("i03_stance", "")) in ["watch", "offer", "object"] and str(s.get("i03_home", "")).is_empty():
				return vid_b(data, ctx)
		VID_C:
			if str(s.get("i03_task", "")) == "done" and str(s.get("i03_stance", "")) != "missed":
				return vid_c(data, ctx)
	return {}
