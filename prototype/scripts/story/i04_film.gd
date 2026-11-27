extends RefCounted
## I-04 in-engine films (Klasse B, HB S. 15 and S. 22–29). Pure functions of
## the saved state: a film commits nothing, choice beats name the childhood
## step they await, skipping stops at an open choice. Every spoken beat keeps
## a stable line_id and speaker_id for the later voice production.

const I04 = preload("res://scripts/story/i04_workshop.gd")
const VID_A := "i04_vid_a"
const VID_B := "i04_vid_b"
const IDS := [VID_A, VID_B]
const CHAPTER := "Kapitel I · Der Freund meines Vaters"
const FORGE := "Valdora · Schmiede des Sextus · Frühjahr 58 v. Chr."
const SPEAKERS := {"sextus":["Sextus", "Dorfschmied · Freund deines Vaters"], "silvanus":["Silvanus", "Dein Vater"], "chronik":["Chronik", "Ein Nachmittag in Valdora"], "player":["Du", "Zwölf Jahre"]}


static func _beat(id: String, shot_id: String, line_id: String, minimum: float, actor_id: String, anchor := "") -> Dictionary:
	var line: Dictionary = I04.line(line_id)
	var speaker_id := str(line.get("speaker_id", "chronik"))
	var text := str(line.get("text", ""))
	var names: Array = SPEAKERS.get(speaker_id, [speaker_id.capitalize(), ""])
	return {"id":id, "shot_id":shot_id, "line_id":line_id, "speaker_id":speaker_id,
		"speaker":names[0], "role":names[1], "text":text, "actor_id":actor_id, "anchor":anchor,
		"duration":maxf(minimum, 2.0 + text.length() / 17.0), "chapter":CHAPTER, "location":FORGE,
		"voice":"pending_recording"}


static func _pause(id: String, shot_id: String, seconds: float, actor_id: String, anchor := "") -> Dictionary:
	return {"id":id, "shot_id":shot_id, "line_id":"", "speaker_id":"", "speaker":"", "role":"", "text":"",
		"actor_id":actor_id, "anchor":anchor, "duration":seconds, "chapter":CHAPTER, "location":FORGE, "silent":true, "voice":"none"}


static func _choice(id: String, step_id: String, data: Dictionary) -> Dictionary:
	var spec: Dictionary = I04.slice().steps[step_id]
	var choices: Array[Dictionary] = []
	for option: Dictionary in I04.options(data, {"id":step_id}):
		choices.append({"label":str(option.label), "action_id":str(option.id)})
	return {"id":id, "shot_id":"duo_ots", "line_id":"", "speaker_id":"player", "speaker":"Du", "role":"Zwölf Jahre",
		"text":str(spec.get("prompt", "")), "actor_id":"sextus", "duration":4.0, "chapter":CHAPTER, "location":FORGE,
		"await_choice":true, "choice_step":step_id, "choices":choices, "voice":"none"}


static func _cuts(beat: Dictionary, cuts: Array) -> Dictionary:
	beat["cuts"] = cuts
	return beat


static func _sequence(id: String, film_id: String, title: String, beats: Array[Dictionary], objective: String) -> Dictionary:
	return {"id":id, "version":1, "origin_id":"italia", "source_mission_id":"I-04", "film_id":film_id,
		"title":title, "location":FORGE, "chapter":CHAPTER, "beats":beats,
		"objective_title":"Der Freund meines Vaters · Schmiede", "objective_text":objective, "handoff_label":"Weiter"}


## VID-A: fire and tools open the picture, Silvanus introduces the boy,
## Sextus answers with their shared memory, then the choice of work.
static func vid_a(data: Dictionary, ctx: Dictionary) -> Dictionary:
	var work := str(data.village.childhood.screenplay.get("i04_work", ""))
	var introduce := _cuts(_beat("i04_a_silvanus", "duo_close", "I04_A_SILVANUS", 5.0, "silvanus"),
		[{"at":0.0, "shot_id":"duo_close", "actor_id":"silvanus"}, {"at":0.62, "shot_id":"duo_close", "actor_id":"sextus"}])
	var memory := _cuts(_beat("i04_a_memory", "duo_close", "I04_A_MEMORY", 10.0, "sextus"),
		[{"at":0.0, "shot_id":"duo_close", "actor_id":"sextus"}, {"at":0.5, "shot_id":"duo_close", "actor_id":"silvanus"},
		{"at":0.72, "shot_id":"duo_react", "actor_id":"sextus"}])
	var ask := _cuts(_beat("i04_a_ask", "duo_wide", "I04_A_ASK", 9.0, "sextus"),
		[{"at":0.0, "shot_id":"duo_wide", "actor_id":"sextus"}, {"at":0.45, "shot_id":"duo_close", "actor_id":"sextus"}])
	var beats: Array[Dictionary] = [
		_beat("i04_a_fire", "prop_insert", "I04_A_FIRE", 7.0, "sextus", "i04_hearth"),
		introduce,
		memory,
		_pause("i04_a_pause", "prop_insert", 2.6, "sextus", "i04_bundle"),
		ask,
		_choice("i04_a_choice", "i04_work", data),
		_beat("i04_a_react", "duo_close", "I04_A_REACT_" + (work.to_upper() if not work.is_empty() else "STACK"), 5.0, "sextus")]
	var next_step := I04.current_step(data, ctx)
	var sequence := _sequence(VID_A, "I-04.VID-A", "In der Schmiede", beats,
		str(next_step.get("objective", "Sextus wartet auf deine Antwort.")))
	# Only the actual watch choice needs an immediate film-to-film handoff.
	# Rebuilding the saved sequence reconstructs this presentation-only edge.
	if work == "watch" and str(next_step.get("id", "")) == "i04_topic":
		sequence["chain_to"] = VID_B
	return sequence


## VID-B: the two tongs on the anvil, Sextus' care, his word on the boy's
## actual work, the question, the answer (with the nail after "craft").
static func vid_b(data: Dictionary, ctx: Dictionary) -> Dictionary:
	var topic := str(data.village.childhood.screenplay.get("i04_topic", ""))
	var reply_id := I04.topic_line_id(data)
	var care := _cuts(_beat("i04_b_sextus", "duo_close", "I04_B_SEXTUS", 10.0, "sextus"),
		[{"at":0.0, "shot_id":"duo_close", "actor_id":"sextus"}, {"at":0.55, "shot_id":"duo_react", "actor_id":"sextus"}])
	var reply := _beat("i04_b_reply", "duo_close", reply_id if not reply_id.is_empty() else "I04_B_TOPIC_CRAFT", 7.0, "sextus", "i04_nail")
	if topic == "craft":
		# The handover is shown on the object itself.
		_cuts(reply, [{"at":0.0, "shot_id":"duo_close", "actor_id":"sextus"}, {"at":0.42, "shot_id":"prop_insert", "actor_id":"sextus"},
			{"at":0.74, "shot_id":"duo_react", "actor_id":"sextus"}])
	else:
		_cuts(reply, [{"at":0.0, "shot_id":"duo_close", "actor_id":"sextus"}, {"at":0.7, "shot_id":"duo_react", "actor_id":"sextus"}])
	var beats: Array[Dictionary] = [
		_beat("i04_b_tool", "prop_insert", "I04_B_TOOL", 6.0, "sextus", "i04_tongs"),
		care,
		_pause("i04_b_hands", "duo_hands", 2.4, "sextus"),
		_beat("i04_b_work", "duo_close", I04.work_line_id(data), 5.0, "sextus"),
		_choice("i04_b_choice", "i04_topic", data),
		reply,
		_pause("i04_b_after", "duo_wide", 2.6, "sextus")]
	return _sequence(VID_B, "I-04.VID-B", "Am Amboss", beats,
		"Sprich mit Silvanus bei der Schmiede über Sextus’ Angebot.")


## VID-C line for the farewell after the arranged trial morning: Sextus names
## what the boy asked about. Legacy saves get no invented line.
static func vid_c_beats(data: Dictionary, chapter: String, location: String) -> Array[Dictionary]:
	var beats: Array[Dictionary] = []
	var topic := str(data.get("village", {}).get("childhood", {}).get("screenplay", {}).get("i04_topic", ""))
	if topic.is_empty():
		return beats
	var lesson := _beat("i04_c_lesson", "duo_close", "I04_C_LESSON_" + topic.to_upper(), 4.0, "sextus", "i04_nail")
	lesson.chapter = chapter
	lesson.location = location
	if topic == "craft":
		_cuts(lesson, [{"at":0.0, "shot_id":"duo_close", "actor_id":"sextus"}, {"at":0.55, "shot_id":"prop_insert", "actor_id":"sextus"}])
	beats.append(lesson)
	return beats


static func restore(data: Dictionary, sequence_id: String, ctx: Dictionary) -> Dictionary:
	var s: Dictionary = data.get("village", {}).get("childhood", {}).get("screenplay", {})
	var completed: int = data.get("village", {}).get("childhood", {}).get("completed", []).size()
	if str(s.get("i04s", "")) not in ["pending", "complete"] or completed != int(ctx.index):
		return {}
	match sequence_id:
		VID_A:
			if str(s.get("i04_topic", "")).is_empty() and int(s.get("i04_sticks", 0)) == 0 and str(s.get("i04_note", "")) != "given":
				return vid_a(data, ctx)
		VID_B:
			if I04.current_step(data, ctx).get("id", "") == "i04_topic" or not str(s.get("i04_topic", "")).is_empty():
				return vid_b(data, ctx)
	return {}
