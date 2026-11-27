extends RefCounted
## Voice-line catalogue. Lines are looked up by a hash of the exact subtitle
## text, so an edited line silently loses its outdated recording instead of
## playing words that no longer match the subtitle.

const MANIFEST_PATH := "res://assets/audio/voice/manifest.json"
const SPEAKER_ALIASES := {"chronik": "narrator", "wachmann": "severus"}

static var _manifest: Dictionary = {}
static var _by_key: Dictionary = {}
static var _by_id: Dictionary = {}


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
				_by_id[str(line.line_id)] = line
				# Barks share texts between voices; only story lines are found by text.
				if str(line.get("kind", "story")) == "story":
					var key := str(line.text_key)
					var cast: Dictionary = _by_key.get(key, {})
					cast[str(line.speaker_id)] = line
					_by_key[key] = cast
	return _manifest


## Returns the manifest entry for exactly this text, or {} when not voiced.
static func find(text: String, speaker_label: String = "") -> Dictionary:
	manifest()
	var cast: Dictionary = _by_key.get(text_key(text), {})
	var line: Dictionary = {}
	if not speaker_label.is_empty():
		line = cast.get(speaker_id(speaker_label), {})
	elif cast.size() == 1:
		line = cast.values()[0]
	# A text-hash collision or conflicting cast must never play wrong words.
	return line if line.get("text", "") == text else {}


static func find_line_id(line_id: String) -> Dictionary:
	manifest()
	return _by_id.get(line_id, {})


static func all_lines() -> Array:
	return manifest().get("lines", [])


static func stream_for(line: Dictionary) -> AudioStream:
	var path := "res://assets/audio/voice/" + str(line.get("file", ""))
	return load(path) as AudioStream if ResourceLoader.exists(path) else null


## Actual forced-alignment format: segments [start, end, viseme index].
static func viseme_track(line: Dictionary) -> Dictionary:
	var path := "res://assets/audio/voice/" + str(line.get("visemes", ""))
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema_version", 0) != 1:
		return {}
	for key: String in ["line_id", "speaker_id", "text_key"]:
		if parsed.get(key) != line.get(key):
			return {}
	var segments: Variant = parsed.get("segments", [])
	var names: Variant = parsed.get("visemes", [])
	var duration: float = float(parsed.get("duration_s",0.0))
	if not segments is Array or segments.is_empty() or not names is Array or names.size() != 15 or not is_finite(duration) or duration <= 0.0:
		return {}
	var last := -1.0
	for segment: Variant in segments:
		if not segment is Array or segment.size() != 3:
			return {}
		if not (segment[0] is float or segment[0] is int) or not (segment[1] is float or segment[1] is int) or not (segment[2] is float or segment[2] is int):
			return {}
		var start := float(segment[0])
		var end := float(segment[1])
		var index := float(segment[2])
		if not is_finite(start) or not is_finite(end) or not is_finite(index) or start < 0.0 or start < last or end < start or end > duration + 0.061 or index != floor(index) or index < 0.0 or index >= float(names.size()):
			return {}
		last = start
	return parsed
