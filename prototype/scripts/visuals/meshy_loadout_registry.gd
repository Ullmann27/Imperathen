extends RefCounted
## Read-only modular presentation loadouts for staged Meshy assets.
##
## Inventory, story and combat remain authoritative elsewhere. These records
## only describe which visual source assets could be assembled after acceptance.

const PATH := "res://assets/meshy/loadouts.json"
const AssetRegistry = preload("res://scripts/visuals/meshy_asset_registry.gd")

static var _loaded := false
static var _loadouts: Dictionary = {}
static var _resource_bindings: Dictionary = {}


static func metadata(loadout_id: String) -> Dictionary:
	_load()
	if not _loadouts.has(loadout_id):
		return {}
	return (_loadouts[loadout_id] as Dictionary).duplicate(true)


static func component_ids(loadout_id: String) -> Dictionary:
	var entry := metadata(loadout_id)
	var result := {}
	for key: String in ["body", "mount", "saddle", "primary", "sidearm", "shield"]:
		var asset_id := str(entry.get(key, ""))
		if not asset_id.is_empty():
			result[key] = asset_id
	return result


static func available_components(loadout_id: String) -> Dictionary:
	var result := {}
	for key: String in component_ids(loadout_id):
		var asset_id: String = component_ids(loadout_id)[key]
		result[key] = AssetRegistry.has_source(asset_id)
	return result


static func resource_asset(economy_key: String) -> String:
	_load()
	return str(_resource_bindings.get(economy_key, ""))


static func all_metadata() -> Array[Dictionary]:
	_load()
	var ids: Array = _loadouts.keys()
	ids.sort()
	var result: Array[Dictionary] = []
	for loadout_id: String in ids:
		result.append((_loadouts[loadout_id] as Dictionary).duplicate(true))
	return result


static func reset_cache_for_tests() -> void:
	_loaded = false
	_loadouts.clear()
	_resource_bindings.clear()


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		push_warning("Meshy loadout contract missing: " + PATH)
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_warning("Meshy loadout contract cannot be opened")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Meshy loadout contract is not a JSON object")
		return
	for value: Variant in (parsed as Dictionary).get("loadouts", []):
		if value is Dictionary:
			var entry := value as Dictionary
			var loadout_id := str(entry.get("id", ""))
			if not loadout_id.is_empty() and not _loadouts.has(loadout_id):
				_loadouts[loadout_id] = entry.duplicate(true)
	for value: Variant in (parsed as Dictionary).get("resource_bindings", []):
		if value is Dictionary:
			var binding := value as Dictionary
			var key := str(binding.get("economy_key", ""))
			var asset_id := str(binding.get("asset_id", ""))
			if not key.is_empty() and not asset_id.is_empty() and not _resource_bindings.has(key):
				_resource_bindings[key] = asset_id
