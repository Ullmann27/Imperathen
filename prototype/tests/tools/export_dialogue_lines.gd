extends SceneTree
## Exports authored spoken lines across installed mission bands, village idle
## lines, the legacy Italia Marcus lines) exactly as the runtime builds them.
## The voice pipeline hashes these strings, so the runtime lookup by text hash
## cannot drift from what the player reads in the subtitle.
## Usage: godot --headless --path prototype --script res://tests/tools/export_dialogue_lines.gd -- <out.json>

const Opening = preload("res://scripts/story/opening_story.gd")
const MissionData = preload("res://scripts/story/mission_data.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const VoiceLines = preload("res://scripts/audio/voice_lines.gd")
const Direction := preload("res://scripts/story/campaign_direction.gd")

var _lines: Array[Dictionary] = []
var _seen := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if not args.is_empty() else "user://dialogue_lines.json"
	var prologue: Dictionary = Opening.historical_prologue()
	for beat: Dictionary in prologue.beats:
		_add("I-00", "I-00." + str(beat.id), str(beat.speaker), str(beat.text), "opening_story.historical_prologue")
	var home: Dictionary = Opening.childhood()
	for beat: Dictionary in home.beats:
		if beat.get("await_choice", false) or beat.get("silent", false):
			continue
		_add("I-01", "I-01." + str(beat.id), str(beat.speaker), str(beat.text), "opening_story.childhood")
	var bands := DirAccess.get_directories_at(MissionData.ROOT)
	bands.sort()
	for band: String in bands:
		if not FileAccess.file_exists(MissionData.ROOT + band + "/index.json"):
			continue
		for mission: Dictionary in MissionData.mission_files(band):
			var mission_id := str(mission.mission)
			var entries: Array = mission.get("steps", []).duplicate()
			entries.append_array(mission.get("bridges", []))
			for step: Dictionary in entries:
				var npc := str(step.get("npc", ""))
				if not npc.is_empty() and not str(step.get("text", "")).is_empty():
					_add(mission_id, mission_id + "." + str(step.id), npc, str(step.text), "missions/" + band + "/" + mission_id + ".json:text")
				if not str(step.get("result", "")).is_empty():
					_add(mission_id, mission_id + "." + str(step.id) + ".result", "Chronik", str(step.result), "missions/" + band + "/" + mission_id + ".json:result")
			var authored: Dictionary = mission.get("slice", {}).get("lines", {})
			for line_id: String in authored:
				var line: Dictionary = authored[line_id]
				_add(mission_id, line_id, str(line.get("speaker_id", "")), str(line.get("text", "")), "missions/" + band + "/" + mission_id + ".json:slice.lines")
			var contacts: Dictionary = mission.get("slice", {}).get("contact_lines", {})
			for id: String in contacts:
				_add(mission_id, mission_id + ".contact." + id, id, str(contacts[id]), "missions/" + band + "/" + mission_id + ".json:slice.contact_lines")
	# Only intros for installed mission files enter the current voice inventory.
	for mission: Dictionary in MissionData.mission_files("band1"):
		var id := str(mission.mission)
		_add(id,id+".directed_intro","Chronik",Direction.introduction(id),"campaign_direction.INTRO")
	for id: String in Childhood.NEIGHBORS:
		_add("village", "village.idle." + id, id, Childhood._idle_text(id), "village_childhood.NEIGHBORS")
	for id: String in ["julia", "silvanus", "sextus"]:
		_add("village", "village.idle." + id, id, Childhood._idle_text(id), "village_childhood._idle_text")
	var italia: Dictionary = Opening.REGIONS["italia"]
	for key: String in ["request", "help_reply", "decline_reply"]:
		_add("legacy_opening", "legacy.marcus." + key, "Marcus", str(italia[key]), "opening_story.REGIONS.italia." + key)
	var file := FileAccess.open(out, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": 1, "lines": _lines}, "  "))
	file.close()
	print("EXPORT_DIALOGUE_LINES count=%d out=%s" % [_lines.size(), out])
	quit(0)


func _add(scope: String, line_id: String, speaker: String, text: String, source: String) -> void:
	if text.strip_edges().is_empty() or speaker.strip_edges().is_empty():
		return
	var key := VoiceLines.text_key(text)
	var cast_key := VoiceLines.speaker_id(speaker) + ":" + key
	if _seen.has(cast_key):
		return
	_seen[cast_key] = true
	_lines.append({"line_id": line_id, "scope": scope, "speaker_id": VoiceLines.speaker_id(speaker),
		"speaker_label": speaker, "text": text, "text_key": key, "source": source})
