extends RefCounted
## Optional access to Meshy source assets.
##
## The manifest records canonical source tasks, but a manifest entry is not a
## runtime asset. Only an imported GLB that Godot can resolve as PackedScene is
## instantiated. Callers must keep their existing fallback when this returns
## null.

const MANIFEST_PATH := "res://assets/meshy/manifest.json"

static var _loaded := false
static var _assets: Dictionary = {}


static func metadata(stable_id: String) -> Dictionary:
	_load_manifest()
	if not _assets.has(stable_id):
		return {}
	return (_assets[stable_id] as Dictionary).duplicate(true)


static func source_path(stable_id: String) -> String:
	var entry := metadata(stable_id)
	return str(entry.get("intended_source_path", ""))


static func has_source(stable_id: String) -> bool:
	var path := source_path(stable_id)
	return not path.is_empty() and ResourceLoader.exists(path, "PackedScene")


static func instantiate(stable_id: String) -> Node3D:
	var path := source_path(stable_id)
	if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var instance := scene.instantiate()
	if instance is Node3D:
		return instance as Node3D
	instance.free()
	return null


static func available(stable_ids: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for stable_id: String in stable_ids:
		if has_source(stable_id):
			result.append(stable_id)
	return result


static func all_metadata() -> Array[Dictionary]:
	_load_manifest()
	var result: Array[Dictionary] = []
	var ids: Array = _assets.keys()
	ids.sort()
	for stable_id: String in ids:
		result.append((_assets[stable_id] as Dictionary).duplicate(true))
	return result


static func reset_cache_for_tests() -> void:
	_loaded = false
	_assets.clear()


static func _load_manifest() -> void:
	if _loaded:
		return
	_loaded = true
	_assets.clear()
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("Meshy manifest missing: " + MANIFEST_PATH)
		return
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_warning("Meshy manifest cannot be opened: " + MANIFEST_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Meshy manifest is not a JSON object")
		return
	var entries: Variant = (parsed as Dictionary).get("assets", [])
	if not entries is Array:
		push_warning("Meshy manifest assets must be an array")
		return
	for value: Variant in entries:
		if not value is Dictionary:
			continue
		var entry := value as Dictionary
		var stable_id := str(entry.get("stable_id", ""))
		var path := str(entry.get("intended_source_path", ""))
		if stable_id.is_empty() or path.is_empty() or _assets.has(stable_id):
			continue
		_assets[stable_id] = entry.duplicate(true)
