extends RefCounted
## Exact-text, exact-speaker catalogue. Ambiguous records are not playable.
## FaceDriver consumes numeric indices in its fixed VISEMES order.
const FaceDriver := preload("res://scripts/audio/face_driver.gd")
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


## Empty records are deliberate ambiguity sentinels, never last-writer wins.
static func index_lines(lines: Array) -> Dictionary:
	var by_id: Dictionary = {}
	var by_key: Dictionary = {}
	for raw: Variant in lines:
		if not raw is Dictionary:
			continue
		var line: Dictionary = raw
		var id := str(line.get("line_id", ""))
		var sid := str(line.get("speaker_id", ""))
		var key := str(line.get("text_key", ""))
		var text: Variant = line.get("text")
		if id.is_empty() or sid.is_empty() or not text is String or text.is_empty() or key != text_key(text):
			continue
		by_id[id] = {} if by_id.has(id) else line
		if str(line.get("kind", "story")) == "story":
			var cast: Dictionary = by_key.get(key, {})
			cast[sid] = {} if cast.has(sid) else line
			by_key[key] = cast
	return {"by_id": by_id, "by_key": by_key}


static func manifest() -> Dictionary:
	if _manifest.is_empty() and FileAccess.file_exists(MANIFEST_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if parsed is Dictionary and parsed.get("lines") is Array:
			_manifest = parsed
			var indexes := index_lines(_manifest.lines)
			_by_id = indexes.by_id
			_by_key = indexes.by_key
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
	if line.is_empty() or line.get("text", "") != text:
		return {}
	# Duplicate IDs must also be rejected when looking up by subtitle.
	return line if not _by_id.get(str(line.line_id), {}).is_empty() else {}


static func find_line_id(line_id: String) -> Dictionary:
	manifest()
	return _by_id.get(line_id, {})


static func all_lines() -> Array:
	return manifest().get("lines", [])


static func _asset_path(relative: Variant) -> String:
	if not relative is String or relative.is_empty() or relative.is_absolute_path() or relative.contains("\\") or relative.contains(":"):
		return ""
	for part: String in relative.split("/"):
		if part.is_empty() or part == "." or part == "..":
			return ""
	return "res://assets/audio/voice/" + relative


static func stream_for(line: Dictionary) -> AudioStream:
	var path := _asset_path(line.get("file"))
	return load(path) as AudioStream if not path.is_empty() and ResourceLoader.exists(path) else null


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


## Actual forced-alignment format: segments [start, end, viseme index].
## Keep this contract aligned with FaceDriver and the offline audio audit.
static func validate_viseme_track(parsed: Variant, line: Dictionary) -> bool:
	if not parsed is Dictionary or parsed.get("schema_version", 0) != 1:
		return false
	for key: String in ["line_id", "speaker_id", "text_key"]:
		if not parsed.get(key) is String or str(parsed.get(key)).is_empty() or parsed.get(key) != line.get(key):
			return false
	var segments: Variant = parsed.get("segments")
	var names: Variant = parsed.get("visemes")
	var duration: Variant = parsed.get("duration_s")
	var expected: Variant = line.get("duration_s")
	if not segments is Array or segments.is_empty() or not names is Array or names != FaceDriver.VISEMES:
		return false
	if not _finite_number(duration) or not _finite_number(expected) or float(duration) <= 0.0 or absf(float(duration) - float(expected)) > 0.002:
		return false
	var onset: Variant = parsed.get("audio_onset_s")
	var first: Variant = parsed.get("first_phoneme_s")
	if not _finite_number(onset) or not _finite_number(first):
		return false
	if float(onset) < 0.0 or float(first) < 0.0 or float(onset) > float(duration) or float(first) > float(duration) or absf(float(onset) - float(first)) > 0.0167:
		return false
	var last := -1.0
	for segment: Variant in segments:
		if not segment is Array or segment.size() != 3:
			return false
		if not _finite_number(segment[0]) or not _finite_number(segment[1]) or not _finite_number(segment[2]):
			return false
		var start := float(segment[0])
		var end := float(segment[1])
		var index := float(segment[2])
		if start < 0.0 or start < last or end < start or end > float(duration) + 0.061 or index != floor(index) or index < 0.0 or index >= float(names.size()):
			return false
		last = start
	return true


static func viseme_track(line: Dictionary) -> Dictionary:
	var path := _asset_path(line.get("visemes"))
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if validate_viseme_track(parsed, line) else {}
