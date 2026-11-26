extends RefCounted
## Voice-line catalogue. Lines are looked up by a hash of the exact subtitle
## text, so an edited line silently loses its outdated recording instead of
## playing words that no longer match the subtitle.

const MANIFEST_PATH := "res://assets/audio/voice/manifest.json"
const SPEAKER_ALIASES := {"chronik": "narrator", "wachmann": "severus"}

static var _manifest: Dictionary = {}
static var _by_key: Dictionary = {}


static func text_key(text: String) -> String:
	return text.sha256_text().substr(0, 16)


static func speaker_id(label: String) -> String:
	var id := label.strip_edges().to_lower()
	return str(SPEAKER_ALIASES.get(id, id))


static func manifest() -> Dictionary:
	if _manifest.is_empty() and FileAccess.file_exists(MANIFEST_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			_manifest = parsed
			for line: Dictionary in _manifest.get("lines", []):
				_by_key[str(line.text_key)] = line
	return _manifest


## Returns the manifest entry for exactly this text, or {} when not voiced.
static func find(text: String) -> Dictionary:
	manifest()
	return _by_key.get(text_key(text), {})


static func all_lines() -> Array:
	return manifest().get("lines", [])


static func stream_for(line: Dictionary) -> AudioStream:
	var path := "res://assets/audio/voice/" + str(line.get("file", ""))
	return load(path) as AudioStream if ResourceLoader.exists(path) else null


## Viseme track: {"fps":.., "visemes":[...], "keys":[[t, viseme_index, weight], ...]}.
static func viseme_track(line: Dictionary) -> Dictionary:
	var path := "res://assets/audio/voice/" + str(line.get("visemes", ""))
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
