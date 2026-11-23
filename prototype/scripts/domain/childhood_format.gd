extends RefCounted
## Disjoint persisted formats. Detection never creates or resets story progress.

const NONE := "none"
const AUTHORED := "authored"
const LEGACY := "legacy"
const INVALID := "invalid"
const AUTHORED_MARKERS := ["enabled", "scene_id", "journal"]
const LEGACY_MARKERS := ["completed", "night_event", "relationships"]


static func kind(data: Dictionary) -> String:
	var village: Variant = data.get("village", {})
	if typeof(village) != TYPE_DICTIONARY or not village.has("childhood"):
		return NONE
	var child: Variant = village.childhood
	if typeof(child) != TYPE_DICTIONARY:
		return INVALID
	var authored := false
	var legacy := false
	for key: String in AUTHORED_MARKERS:
		authored = authored or child.has(key)
	for key: String in LEGACY_MARKERS:
		legacy = legacy or child.has(key)
	if authored and not legacy and child.has_all(AUTHORED_MARKERS):
		return AUTHORED
	if legacy and not authored and child.has_all(LEGACY_MARKERS):
		return LEGACY
	return INVALID
