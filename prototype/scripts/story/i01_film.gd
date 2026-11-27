extends RefCounted
## I-01 in-engine films (Klasse B, HB S. 22–29). Pure functions of the saved
## state: every rebuild after a choice, suspend or reload yields the same beats.
## A film never commits anything by itself; choice beats name the childhood
## action they await (AwaitChoice), and skipping stops at an open choice.
## Exact recordings are resolved by the production dialogue player. The
## subtitle and line id remain authoritative even before voice acceptance.

const I01 = preload("res://scripts/story/i01_three_cups.gd")
const VoiceLines = preload("res://scripts/audio/voice_lines.gd")
const VID_A := "childhood_home"
const VID_B := "i01_vid_b"
const CHAPTER := "Kapitel I · Die drei Becher"
const LOCATION := "Valdora · Familienhaus · Frühjahr 58 v. Chr."
const SPEAKERS := {"julia":["Julia", "Deine Mutter"], "silvanus":["Silvanus", "Dein Vater"], "chronik":["Chronik", "Ein Morgen in Valdora"], "player":["Du", "Zwölf Jahre"]}


static func _beat(id: String, shot_id: String, line_id: String, minimum: float, actor_id := "", override := {}) -> Dictionary:
	var line: Dictionary = I01.line(line_id)
	var speaker_id := str(override.get("speaker_id", line.get("speaker_id", "chronik")))
	var text := str(override.get("text", line.get("text", "")))
	var names: Array = SPEAKERS.get(speaker_id, [speaker_id.capitalize(), ""])
	var recorded := VoiceLines.find(text,speaker_id)
	var has_recording: bool = not recorded.is_empty() and str(recorded.get("speaker_id", "")) == VoiceLines.speaker_id(speaker_id)
	return {"id":id, "shot_id":shot_id, "line_id":line_id, "speaker_id":speaker_id,
		"speaker":names[0], "role":names[1], "text":text, "actor_id":actor_id,
		"duration":maxf(minimum, 2.0 + text.length() / 17.0), "chapter":CHAPTER, "location":LOCATION,
		"voice":"recorded" if has_recording else "blocked_no_recording"}


## A dramatic pause or silent reaction: a shot without a line. It has no
## line_id (nothing to voice), never holds reading mode and is skipped like
## any other beat.
static func _pause(id: String, shot_id: String, seconds: float, actor_id := "") -> Dictionary:
	return {"id":id, "shot_id":shot_id, "line_id":"", "speaker_id":"", "speaker":"", "role":"", "text":"",
		"actor_id":actor_id, "duration":seconds, "chapter":CHAPTER, "location":LOCATION, "silent":true, "voice":"none"}


static func _choice_beat(id: String, shot_id: String, prompt: String, step_id: String, choices: Array[Dictionary]) -> Dictionary:
	var beat := _beat(id, shot_id, "", 4.0, "", {"speaker_id":"player", "text":prompt})
	beat["await_choice"] = true
	beat["choice_step"] = step_id
	beat["choices"] = choices
	return beat


## VID-A: table, cups and hands, Silvanus' joke, the boy at his bed, the
## choice beat, Julia's reaction; main appends the handoff at the bed.
static func vid_a(data: Dictionary) -> Dictionary:
	var choices: Array[Dictionary] = []
	for option: Dictionary in I01.slice().get("steps", {}).get("i01_choice", {}).get("options", []):
		choices.append({"label":str(option.label), "action_id":str(option.id)})
	var path := str(data.get("village", {}).get("childhood", {}).get("screenplay", {}).get("i01_path", ""))
	var reaction := {"talk":"I01_A_REACT_TALK", "help":"I01_A_REACT_HELP", "yard":"I01_A_REACT_YARD"}.get(path, "I01_A_REACT_HELP") as String
	var beats: Array[Dictionary] = [
		_beat("i01_a_table", "i01_table_detail", "I01_A_TABLE", 7.0, "julia"),
		_beat("i01_a_joke", "i01_shelf_cups", "I01_A_JOKE", 8.0, "silvanus"),
		_beat("i01_a_bed", "i01_bed", "I01_A_BED", 8.0, "julia"),
		_choice_beat("i01_a_choice", "i01_choice", "Was tust du zuerst?", "i01_choice", choices),
		_beat("i01_a_react", "mission_dialogue", reaction, 5.0, "julia")]
	var objective := I01.current_step(data) if not path.is_empty() else {}
	return {"id":VID_A, "version":3, "origin_id":"italia", "source_mission_id":"I-01",
		"film_id":"I-01.VID-A", "title":"Ein Morgen zu Hause", "location":LOCATION, "chapter":CHAPTER,
		"beats":beats, "objective_title":"Die drei Becher · Familienhaus",
		"objective_text":str(objective.get("objective", "Du stehst an deinem Bett im Familienhaus. Julia wartet am Frühstückstisch auf deine Antwort.")),
		"handoff_label":"Ins Haus"}


## VID-B: table talk after the meal. Julia reacts to the stored facts; the
## topic choice is the only commit and waits for the player.
static func vid_b(data: Dictionary) -> Dictionary:
	var choices: Array[Dictionary] = []
	var step := {"id":"i01_topic"}
	for option: Dictionary in I01.options(data, step):
		choices.append({"label":str(option.label), "action_id":str(option.id)})
	var reply: Dictionary = I01.topic_line(data)
	var reply_speaker := str(reply.get("speaker_id", "silvanus"))
	var screenplay: Dictionary = data.get("village", {}).get("childhood", {}).get("screenplay", {})
	var topic := str(screenplay.get("i01_topic", ""))
	var reply_id := "I01_B_TOPIC_" + topic.to_upper()
	if topic == "contact" and not screenplay.get("i01_contacts", []).is_empty():
		reply_id += "_" + str(screenplay.i01_contacts[0]).to_upper()
	var reaction_id := I01.julia_reaction_id(data)
	# Shot plan: wide, insert (pause), close with a reaction cut, silent
	# reaction, close with a cut to the two-shot, choice over the shoulder,
	# answer in the close, a last look from Julia before the handoff.
	var telling := _beat("i01_b_sextus", "i01_close_speaker", "I01_B_SEXTUS", 12.0, "silvanus")
	telling["cuts"] = [{"at":0.0, "shot_id":"i01_close_speaker", "actor_id":"silvanus"},
		{"at":0.46, "shot_id":"i01_react_boy", "actor_id":"silvanus"},
		{"at":0.70, "shot_id":"i01_close_speaker", "actor_id":"silvanus"}]
	var mother := _beat("i01_b_julia", "i01_close_speaker", reaction_id, 6.0, "julia")
	mother["cuts"] = [{"at":0.0, "shot_id":"i01_close_speaker", "actor_id":"julia"},
		{"at":0.62, "shot_id":"i01_two_shot", "actor_id":"julia"}]
	var answer := _beat("i01_b_reply", "i01_close_speaker", reply_id if not topic.is_empty() else "I01_B_TOPIC_PENDING", 6.0, reply_speaker,
		{"speaker_id":reply_speaker, "text":str(reply.get("text", "…"))})
	answer["cuts"] = [{"at":0.0, "shot_id":"i01_close_speaker", "actor_id":reply_speaker},
		{"at":0.72, "shot_id":"i01_react_boy", "actor_id":reply_speaker}]
	var arrival := _beat("i01_b_table", "i01_table_wide", "I01_B_TABLE", 5.0, "silvanus")
	if str(screenplay.get("i01_water","")) == "poured":
		arrival.duration = maxf(float(arrival.duration),7.2)
		arrival["cuts"] = [{"at":0.0,"shot_id":"i01_table_wide","actor_id":"silvanus"},
			{"at":.10,"shot_id":"i01_cups_insert","actor_id":"silvanus"},
			{"at":.87,"shot_id":"i01_table_wide","actor_id":"silvanus"}]
	var beats: Array[Dictionary] = [
		arrival,
		_pause("i01_b_cups", "i01_cups_insert", 2.8, "silvanus"),
		telling,
		_pause("i01_b_listen", "i01_react_julia", 2.4, "silvanus"),
		mother,
		_choice_beat("i01_b_choice", "i01_topic_choice", "Worüber sprichst du am Tisch?", "i01_topic", choices),
		answer,
		_pause("i01_b_after", "i01_two_shot", 2.6, reply_speaker)]
	return {"id":VID_B, "version":2, "origin_id":"italia", "source_mission_id":"I-01",
		"film_id":"I-01.VID-B", "title":"Am Frühstückstisch", "location":LOCATION, "chapter":CHAPTER,
		"beats":beats, "objective_title":"Die drei Becher · vor dem Haus",
		"objective_text":"Julia geht nach dem Frühstück vor das Haus. Sprich dort mit ihr über den Tag.",
		"handoff_label":"Weiter"}


## VID-C lines for the I-01/I-02 border (after father_morning). Variants follow
## stored help and encounters; an offer is mentioned only after a real contact.
static func vid_c_beats(data: Dictionary, chapter: String, location: String) -> Array[Dictionary]:
	var beats: Array[Dictionary] = []
	if str(data.get("village", {}).get("childhood", {}).get("screenplay", {}).get("i01", "")) != "complete":
		return beats
	var helped := bool(data.village.childhood.relationships.julia.get("helped", false))
	var parents := _beat("i01_c_parents", "mission_dialogue", "I01_C_HELPED" if helped else "I01_C_FAREWELL", 5.0, "silvanus")
	parents.chapter = chapter
	parents.location = location
	beats.append(parents)
	var contacts: Array = data.village.childhood.screenplay.get("i01_contacts", [])
	for id: String in ["marcus", "cassia"]:
		if contacts.has(id):
			var offer := _beat("i01_c_" + id, "mission_dialogue", "I01_C_" + id.to_upper(), 4.5, "silvanus")
			offer.chapter = chapter
			offer.location = location
			beats.append(offer)
			break
	return beats


static func restore(data: Dictionary, sequence_id: String) -> Dictionary:
	if sequence_id == VID_B and str(data.get("village", {}).get("childhood", {}).get("screenplay", {}).get("i01_meal", "")) == "done":
		return vid_b(data)
	return {}
