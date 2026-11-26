extends RefCounted
## A first playable investigation slice. The original case file is the only
## source of testimony and conclusions. No culprit/hidden truth is exposed.
const CASE = preload("res://assets/story/investigation/valdora_raid.json")
const WITNESSES := ["aurelia", "fabius", "severus", "julia"]
const PHASES := ["night", "morning", "after_oath"]
const COMMAND_FIELDS := {"village_investigation_question":["npc_id","topic"], "village_investigation_compare":["deduction_id"]}

static func fresh_state() -> Dictionary:
	return {"statements":[], "deductions":[]}

static func _script(data: Dictionary) -> Dictionary:
	var village = data.get("village", {})
	if not village is Dictionary:
		return {}
	var childhood = village.get("childhood", {})
	if not childhood is Dictionary:
		return {}
	var screenplay = childhood.get("screenplay", {})
	return screenplay if screenplay is Dictionary else {}

static func phase(data: Dictionary) -> String:
	var s := _script(data)
	var raid = data.get("village", {}).get("raid", {})
	if not raid is Dictionary:
		return ""
	if s.get("i10") != "complete" or s.get("i11") not in ["pending","complete"] or raid.get("status") != "aftermath" or int(raid.get("completed",0)) < 1:
		return ""
	if s.get("i14") == "complete":
		return "after_oath"
	if s.get("i13") == "complete":
		return "morning"
	return "night"

static func _memories(data: Dictionary) -> Array:
	var s := _script(data)
	var known: Array = []
	if s.get("hoof_evidence",false) == true and s.get("i08") in ["report","complete"]:
		known.append("c_i08_tracks")
	if not phase(data).is_empty():
		match s.get("raid_path"):
			"defend":
				known.append("c_own_defend")
			"hide":
				known.append("c_own_hide")
	return known

static func _lines(npc: String) -> Array:
	return CASE.data.get("witnesses",{}).get(npc,{}).get("statements",[]) if npc in WITNESSES else []

static func _line(npc: String, id: String) -> Dictionary:
	for entry: Dictionary in _lines(npc):
		if entry.get("line_id") == id:
			return entry
	return {}

static func _clue(entry: Dictionary) -> String:
	return str(entry.get("clue",""))

static func _known(data: Dictionary) -> Array:
	var known := _memories(data)
	for entry: Dictionary in _script(data).get("investigation",{}).get("statements",[]):
		var clue := _clue(_line(str(entry.get("npc","")),str(entry.get("line_id",""))))
		if not clue.is_empty() and clue not in known:
			known.append(clue)
	return known

static func _eligible(data: Dictionary, npc: String, entry: Dictionary, at_phase: String, trust: int, known: Array) -> bool:
	var clue := _clue(entry)
	if clue.is_empty() or clue in known or at_phase not in PHASES:
		return false
	if not CASE.data.get("clues",{}).has(clue):
		return false
	if npc == "julia":
		var s := _script(data)
		if s.get("i12") != "complete" or s.get("julia_outcome") != "survived":
			return false
	var conditions: Dictionary = entry.get("when",{})
	for key in conditions:
		match key:
			"phase":
				if at_phase not in conditions[key]:
					return false
			"raid_path":
				if _script(data).get("raid_path") not in conditions[key]:
					return false
			"trust_min":
				if trust < int(conditions[key]):
					return false
			"known":
				for required in conditions[key]:
					if required not in known:
						return false
			"known_any":
				var found := false
				for required in conditions[key]:
					if required in known:
						found = true
				if not found:
					return false
			_:
				# Unimplemented conditions never silently pass.
				return false
	var topic := str(entry.get("topic",""))
	if topic == "night":
		return true
	if topic.begins_with("present:"):
		return topic.trim_prefix("present:") in known
	return false

static func _next(data: Dictionary, npc: String, topic: String, trust: int) -> Dictionary:
	var known := _known(data)
	for entry: Dictionary in _lines(npc):
		if entry.get("topic") == topic and _eligible(data,npc,entry,phase(data),trust,known):
			return entry
	return {}

static func _can_compare(id: String, known: Array) -> bool:
	if id != "d_mixed_band":
		return false
	var definition: Dictionary = CASE.data.get("deductions",{}).get(id,{})
	for group in definition.get("requires",[]):
		var valid: bool = group is Array and not group.is_empty()
		if not valid:
			continue
		for clue in group:
			if clue not in known:
				valid = false
		if valid:
			return true
	return false

static func validate(data: Dictionary) -> String:
	var state = _script(data).get("investigation")
	if not state is Dictionary or state.size() != 2 or not state.get("statements") is Array or not state.get("deductions") is Array:
		return "Ungültiger Ermittlungsstand."
	var known := _memories(data)
	var previous_phase := -1
	for record in state.statements:
		if not record is Dictionary or record.size() != 4:
			return "Ungültiger Zeugeneintrag."
		for key in ["npc","line_id","phase"]:
			if not record.get(key) is String:
				return "Ungültige Zeugenaussage."
		var trust = record.get("trust")
		if typeof(trust) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(trust)) or float(trust) != floor(float(trust)) or float(trust) < -100 or float(trust) > 100:
			return "Ungültiger Vertrauenswert."
		var index := PHASES.find(record.phase)
		if index < 0 or index < previous_phase or index > PHASES.find(phase(data)):
			return "Ungültige Reihenfolge der Zeugenaussagen."
		var entry := _line(record.npc,record.line_id)
		if not _eligible(data,record.npc,entry,record.phase,int(trust),known):
			return "Zeugenaussage ohne erfüllte Voraussetzungen."
		known.append(_clue(entry))
		previous_phase = index
	var compared: Array = []
	for id in state.deductions:
		if not id is String or id in compared or not _can_compare(id,known):
			return "Schlussfolgerung ohne ausreichende Belege."
		compared.append(id)
	return ""

static func choices(data: Dictionary, npc: String, trust: int) -> Array:
	if phase(data).is_empty() or not validate(data).is_empty():
		return []
	var state: Dictionary = _script(data).investigation
	var options: Array = []
	if npc == "decimus":
		if "d_mixed_band" not in state.deductions and _can_compare("d_mixed_band",_known(data)):
			options.append({"label":"Die Aussagen miteinander vergleichen","command":"village_investigation_compare","payload":{"deduction_id":"d_mixed_band"}})
		return options
	var topics: Array = []
	for entry: Dictionary in _lines(npc):
		var topic := str(entry.get("topic",""))
		if topic in topics or not _eligible(data,npc,entry,phase(data),trust,_known(data)):
			continue
		topics.append(topic)
		var label := "Nach dem Überfall fragen"
		if topic.begins_with("present:"):
			var clue: Dictionary = CASE.data.clues.get(topic.trim_prefix("present:"),{})
			label = "Hinweis vorlegen: " + str(clue.get("title",""))
		elif _clue(entry) == "w_guard_carter":
			label = "Nach dem Fuhrmann fragen"
		options.append({"label":label,"command":"village_investigation_question","payload":{"npc_id":npc,"topic":topic}})
	return options

static func question(data: Dictionary, npc: String, topic: String, trust: int) -> Dictionary:
	var entry := _next(data,npc,topic,trust)
	if entry.is_empty():
		return {"ok":false,"message":"Dazu gibt es keine neue zugängliche Aussage."}
	var record := {"npc":npc,"line_id":entry.line_id,"phase":phase(data),"trust":trust}
	_script(data).investigation.statements.append(record)
	return {"ok":true,"message":str(entry.get("text","Aussage aufgenommen."))}

static func compare(data: Dictionary, id: String) -> Dictionary:
	var state: Dictionary = _script(data).investigation
	if phase(data).is_empty() or id in state.deductions or not _can_compare(id,_known(data)):
		return {"ok":false,"message":"Dafür fehlen noch unabhängige Hinweise."}
	state.deductions.append(id)
	return {"ok":true,"message":str(CASE.data.deductions[id].get("text","Hinweise verglichen."))}

static func view(data: Dictionary) -> Dictionary:
	var result := {"visible":false,"title":str(CASE.data.get("title","Ermittlungen")),"clues":[],"deductions":[]}
	if _script(data).is_empty() or not validate(data).is_empty():
		return result
	for id in _known(data):
		var clue: Dictionary = CASE.data.clues.get(id,{})
		if not clue.is_empty():
			result.clues.append({"id":id,"title":clue.get("title",""),"text":clue.get("text",""),"reliability":clue.get("reliability",""),"source_label":clue.get("source_label","")})
	for id in _script(data).investigation.deductions:
		var conclusion: Dictionary = CASE.data.deductions.get(id,{})
		result.deductions.append({"id":id,"title":conclusion.get("title",""),"text":conclusion.get("text",""),"strength":conclusion.get("strength","")})
	result.visible = not result.clues.is_empty() or not phase(data).is_empty()
	return result
