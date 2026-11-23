extends RefCounted
## Presentation progress is separate from the authoritative campaign schema.
## A different campaign or invalid file can never replay an old introduction.

const PATH := "user://imperathen_opening.json"
const VERSION := 1
const MAX_BYTES := 4096


static func write(world_id: String, sequence_id: String, index: int, completed: bool, path: String = PATH) -> Error:
	if world_id.is_empty() or world_id.length() > 128 or sequence_id.is_empty() or sequence_id.length() > 128 or index < 0 or index > 32:
		return ERR_INVALID_PARAMETER
	var pending_path := path + ".pending"
	var file := FileAccess.open(pending_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": VERSION, "world_id": world_id,
		"sequence_id": sequence_id, "index": index, "completed": completed}))
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK:
		return result
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(pending_path), ProjectSettings.globalize_path(path))


static func read(world_id: String, path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return {}
	var parsed = parser.data
	if not parsed is Dictionary or parsed.size() != 5:
		return {}
	for key in ["version", "world_id", "sequence_id", "index", "completed"]:
		if not parsed.has(key):
			return {}
	if parsed.version != VERSION or not parsed.world_id is String or parsed.world_id != world_id:
		return {}
	if not parsed.sequence_id is String or parsed.sequence_id.is_empty() or parsed.sequence_id.length() > 128:
		return {}
	if not (parsed.index is int or parsed.index is float) or not is_finite(float(parsed.index)) or float(parsed.index) != floorf(float(parsed.index)):
		return {}
	if int(parsed.index) < 0 or int(parsed.index) > 32 or not parsed.completed is bool:
		return {}
	return parsed
