extends RefCounted
## Turns simulation events into spoken lines: who says what, in which voice.
##
## This is the seam between the life simulation and audio. A line is
## {speaker, voice_category, voice_id, bark, text, at_seconds, line_id,
## voiced}. `voiced` is true only when the voice manifest of the audio package
## (scripts/audio/voice_lines.gd, branch feat/voices-lipsync-sfx-20261126)
## really contains a recording for the line; otherwise the line is text only
## and a caller must not present it as audible speech.
##
## Texts live in res://assets/city/barks/city_barks.json so writers and the
## voice pipeline can extend them without touching code. The choice of line is
## a pure function of the event's seed: the same event always yields the same
## exchange.

const Population = preload("res://scripts/domain/city_population.gd")
const PATH := "res://assets/city/barks/city_barks.json"
const VOICE_LINES := "res://scripts/audio/voice_lines.gd"
const CATEGORIES := ["woman", "man", "girl", "boy", "old_woman", "old_man"]
const CHILD_MAX_AGE := 13
const ELDER_MIN_AGE := 62
const SECONDS_PER_LINE := 3.2

static var _data: Dictionary = {}
static var _voice_lines: Variant = null
static var _voice_checked := false


static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary and parsed.get("format") == "imperathen-city-barks":
			_data = parsed
	return _data


## Same category rule as the audio package's NPC voice pool.
static func voice_category(female: bool, age: int) -> String:
	if age <= CHILD_MAX_AGE:
		return "girl" if female else "boy"
	if age >= ELDER_MIN_AGE:
		return "old_woman" if female else "old_man"
	return "woman" if female else "man"


## Same FNV-1a mapping as scripts/audio/npc_voices.gd: 4 voices per category.
static func voice_id(resident_id: String, category: String) -> String:
	return "npc_%s_%d" % [category, Population.fnv(resident_id) % 4]


static func _recorded(line_id: String) -> bool:
	if not _voice_checked:
		_voice_checked = true
		if ResourceLoader.exists(VOICE_LINES):
			_voice_lines = load(VOICE_LINES)
	if _voice_lines == null:
		return false
	var entry: Variant = _voice_lines.find_line_id(line_id)
	return entry is Dictionary and not entry.is_empty()


static func _line(life: RefCounted, person: int, group: String, pick: int, at_seconds: float) -> Dictionary:
	var options: Array = data().get("lines", {}).get(group, [])
	if options.is_empty() or person < 0:
		return {}
	var resident: Dictionary = life.state.residents[person]
	var id := Population.resident_id(person)
	var category := voice_category(bool(resident.female), life.age(resident))
	var voice := voice_id(id, category)
	var slot := pick % options.size()
	var line_id := "city.%s.%s.%d" % [voice, group, slot]
	return {"speaker": id, "speaker_index": person, "name": str(resident.name), "voice_category": category, "voice_id": voice,
		"bark": group, "text": str(options[slot]), "at_seconds": at_seconds, "line_id": line_id, "voiced": _recorded(line_id)}


## Lines for one simulation event; empty when the event has nothing to say.
static func lines_for(life: RefCounted, event: Dictionary) -> Array:
	var result: Array = []
	var seed := int(event.get("seed", int(event.get("seq", 0)) * 7919 + int(event.get("t", 0))))
	match str(event.kind):
		"conversation":
			var topic := str(event.topic)
			var turns := clampi(int(float(event.seconds) / SECONDS_PER_LINE), 2, 6)
			for turn in turns:
				var speaker := int(event.a) if turn % 2 == 0 else int(event.b)
				var group := "talk.%s.%s" % [topic, "open" if turn == 0 else ("reply" if turn % 2 == 1 else "more")]
				if not data().get("lines", {}).has(group):
					group = "talk.neighbourhood.%s" % ("open" if turn == 0 else ("reply" if turn % 2 == 1 else "more"))
				_append(result, _line(life, speaker, group, Population.mix(seed, turn, 3), turn * SECONDS_PER_LINE))
		"haggle":
			_append(result, _line(life, int(event.a), "haggle.ask", Population.mix(seed, 1), 0.0))
			_append(result, _line(life, int(event.b), "haggle.offer." + _good_group(life, str(event.good)), Population.mix(seed, 2), 2.6))
			if int(event.seconds) >= 30:
				_append(result, _line(life, int(event.a), "haggle.counter", Population.mix(seed, 3), 5.4))
				_append(result, _line(life, int(event.b), "haggle.settle", Population.mix(seed, 4), 8.2))
		"purchase":
			_append(result, _line(life, int(event.b), "purchase.thanks", Population.mix(seed, 5), 0.0))
		"alms":
			_append(result, _line(life, int(event.b), "beggar.thanks", Population.mix(seed, 6), 0.0))
		"theft":
			if bool(event.get("noticed", false)):
				_append(result, _line(life, int(event.b), "alarm.thief", Population.mix(seed, 7), 0.0))
		"alarm":
			for index in mini(2, event.get("fled", []).size()):
				_append(result, _line(life, int(event.fled[index]), "alarm.flee", Population.mix(seed, 8 + index), 0.4 * index))
			for index in mini(1, event.get("guards", []).size()):
				_append(result, _line(life, int(event.guards[index]), "alarm.guard", Population.mix(seed, 11), 1.2))
		"delivery":
			if int(event.a) >= 0:
				_append(result, _line(life, int(event.a), "delivery.arrive", Population.mix(seed, 12), 0.0))
	return result


## A vendor's call across the street; `slot` rotates through the texts.
static func vendor_call(life: RefCounted, vendor: int, call: String, slot: int) -> Dictionary:
	var group := "call." + call
	if not data().get("lines", {}).has(group):
		group = "call.general"
	return _line(life, vendor, group, slot, 0.0)


## A resident's greeting when the player walks past.
static func greeting(life: RefCounted, person: int, hour: float, slot: int) -> Dictionary:
	var group := "greet.morning" if hour < 11.0 else ("greet.evening" if hour >= 17.0 else "greet.day")
	return _line(life, person, group, slot, 0.0)


static func _good_group(life: RefCounted, good: String) -> String:
	var category := str(life.economy.goods.get(good, {}).get("category", ""))
	return "food" if category in ["staple", "side", "meal", "drink", "luxury_food"] else "wares"


static func _append(target: Array, line: Dictionary) -> void:
	if not line.is_empty():
		target.append(line)


## Every (voice, group, slot) combination, for the voice pipeline to record.
static func recording_list() -> Array:
	var result: Array = []
	var groups: Dictionary = data().get("lines", {})
	var names: Array = groups.keys()
	names.sort()
	for group: String in names:
		for slot in groups[group].size():
			result.append({"group": group, "slot": slot, "text": str(groups[group][slot])})
	return result
