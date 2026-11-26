extends RefCounted
## Deterministic voice assignment for unnamed residents and their barks.
## The same NPC id always maps to the same pool voice (hash of the id), so a
## resident sounds identical across sessions and saves. Named characters use
## their fixed speaker ids from the voice registry instead.

const VoiceLines = preload("res://scripts/audio/voice_lines.gd")
const CATEGORIES := ["woman", "man", "girl", "boy", "old_woman", "old_man"]
const BARKS := ["greeting", "market", "refusal", "alarm"]
const VOICES_PER_CATEGORY := 4
const CHILD_MAX_AGE := 13
const ELDER_MIN_AGE := 62


## Maps village data (appearance id such as "civilian_woman", "elder",
## "officer"; age in years) to a pool category.
static func category_for(appearance: String, age: int) -> String:
	var female := appearance.contains("woman") or appearance.contains("girl") or appearance.contains("female")
	if age <= CHILD_MAX_AGE:
		return "girl" if female else "boy"
	if age >= ELDER_MIN_AGE or (appearance == "elder" and age <= 0):
		return "old_woman" if female else "old_man"
	return "woman" if female else "man"


static func voice_for(npc_id: String, category: String) -> String:
	var cat := category if category in CATEGORIES else "man"
	# hash() is stable for a given string within an engine version; use our
	# own FNV-1a so the mapping survives engine upgrades.
	var h := 2166136261
	for b in npc_id.to_utf8_buffer():
		h = ((h ^ b) * 16777619) & 0xFFFFFFFF
	return "npc_%s_%d" % [cat, h % VOICES_PER_CATEGORY]


## Manifest entry of a bark for this NPC, or {} if not generated.
static func bark(npc_id: String, category: String, bark_type: String) -> Dictionary:
	if bark_type not in BARKS:
		return {}
	return VoiceLines.find_line_id("pool.%s.%s" % [voice_for(npc_id, category), bark_type])
