extends RefCounted
## Real-time story transitions are presentation only. No animation can complete,
## unlock, reward or mutate a mission. The existing successful transaction owns
## those effects and hands the next objective to this authored sequence.
const Childhood = preload("res://scripts/story/village_childhood.gd")
const I01Film = preload("res://scripts/story/i01_film.gd")
const I03 = preload("res://scripts/story/i03_shortcut.gd")
const I03Film = preload("res://scripts/story/i03_film.gd")
const I04Film = preload("res://scripts/story/i04_film.gd")
const PREFIX := "mission_transition_"
const KEY_DIALOGUES := ["deliver_kindling","smith_trial","smith_apprentice","deliver_hinge","patrol_brief","watch_permission","borrow_gear","return_gear"]

static func _mission(step: Dictionary) -> String:
	return str(step.get("mission",step.get("source_mission",Childhood.SOURCE_MISSION_BY_STEP.get(str(step.get("id","")),""))))

static func sequence_for(data: Dictionary, previous: Dictionary, following: Dictionary) -> Dictionary:
	if not Childhood.enabled(data) or previous.is_empty() or following.is_empty():
		return {}
	var id := str(previous.get("id",""))
	var next_id := str(following.get("id",""))
	if id.is_empty() or next_id.is_empty() or id == next_id:
		return {}
	# I-01 VID-B: the committed breakfast opens the table talk.
	if next_id == "i01_topic":
		return I01Film.vid_b(data)
	if id.begins_with("i01_"):
		return {}
	# I-03 VID-B: the committed stance at the stall opens Cassia's explanation.
	if next_id == "i03_resolve":
		return I03Film.vid_b(data, Childhood.i03_ctx(data))
	# I-03 VID-C: with Julia's order bought, Marcus speaks about the way home.
	# Without Marcus there is no film and no stand-in.
	if next_id == "i03_farewell":
		return I03Film.vid_c(data, Childhood.i03_ctx(data)) if I03.marcus_present(data) else {}
	if id.begins_with("i03_") and next_id.begins_with("i03_") or id == "i03_farewell":
		return {}
	# I-04 VID-A: the delivered bundle opens the introduction in the forge;
	# VID-B: the finished work (or the decision to watch) opens the anvil talk.
	if next_id == "i04_work":
		return I04Film.vid_a(data, Childhood.i04_ctx(data))
	if next_id == "i04_topic":
		return I04Film.vid_b(data, Childhood.i04_ctx(data))
	if id.begins_with("i04_"):
		return {}
	var old_mission := _mission(previous)
	var next_mission := _mission(following)
	var boundary := not old_mission.is_empty() and not next_mission.is_empty() and old_mission != next_mission
	if not boundary and id not in KEY_DIALOGUES:
		return {}
	var objective := str(following.get("objective",""))
	if objective.is_empty():
		return {}
	var actor := str(previous.get("npc",""))
	var dialogue := str(previous.get("text",""))
	var chapter := Childhood.mission_heading(next_mission,str(following.get("chapter","Dein nächster Schritt")))
	var location := "Valdora · Aquileia-Region"
	var beats: Array[Dictionary] = []
	if not actor.is_empty() and not dialogue.is_empty():
		var caption := str(Childhood.EXTRA_NPCS.get(actor,Childhood.NEIGHBORS.get(actor,{})).get("name",actor))
		beats.append({"id":id+"_dialogue","shot_id":"mission_dialogue","actor_id":actor,
			"speaker":caption,"role":"Gespräch · Auftrag abgeschlossen","text":dialogue,
			"duration":maxf(5.0,2.0+dialogue.length()/17.0),"chapter":chapter,"location":location})
	if id == "smith_trial":
		# I-04 VID-C: Sextus' farewell names what the boy asked about.
		beats.append_array(I04Film.vid_c_beats(data, chapter, location))
	if id == "father_morning":
		# I-01 VID-C variants at the border to I-02 (HB S. 13, 30–34).
		beats.append_array(I01Film.vid_c_beats(data, chapter, location))
	var result := str(previous.get("result",""))
	if not result.is_empty():
		beats.append({"id":id+"_reaction","shot_id":"mission_reaction","actor_id":actor,
			"speaker":"Chronik","role":"Dein nächster Weg","text":result,
			"duration":maxf(3.5,1.5+result.length()/19.0),"chapter":chapter,"location":location})
	if beats.is_empty():
		beats.append({"id":id+"_transition","shot_id":"mission_reaction","actor_id":actor,
			"speaker":"Chronik","role":"Ein neuer Auftrag","text":objective,
			"duration":maxf(3.5,1.5+objective.length()/19.0),"chapter":chapter,"location":location})
	return {"id":PREFIX+id,"version":1,"origin_id":str(data.get("origin_id","italia")),
		"title":chapter,"chapter":chapter,"location":location,"beats":beats,
		"objective_title":str(following.get("label",chapter)),"objective_text":objective,
		"handoff_label":"Weiter zum Auftrag"}

static func restore(data: Dictionary, sequence_id: String) -> Dictionary:
	if not sequence_id.begins_with(PREFIX) or not Childhood.enabled(data):
		return {}
	var wanted := sequence_id.trim_prefix(PREFIX)
	var candidates: Array = Childhood.STEPS.duplicate()
	candidates.append_array(Childhood.BRIDGE_STEPS.values())
	for step: Dictionary in candidates:
		if str(step.get("id",""))==wanted:
			return sequence_for(data,step,Childhood.current_step(data))
	return {}
