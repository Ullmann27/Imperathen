extends RefCounted
## Separate authored Marcus meshes; complete family or legacy fallback.
const PATH := "res://assets/characters/marcus_quality_%d.glb"

static func installed() -> bool:
	for level in 4:
		if not ResourceLoader.exists(PATH % level, "PackedScene"):
			return false
	return true

static func owns(path: String) -> bool:
	return path.begins_with("res://assets/characters/marcus_quality_")

## Age morphs move the actual eyeball centres. This calibrated rest-space
## displacement is emitted by the Blender build alongside the four GLBs.
const EYE_CALIBRATION := "res://assets/characters/marcus_eye_calibration.json"
static var _mature_eye_offsets: Dictionary = {}

static func eye_offsets(adult: bool) -> Dictionary:
	if not adult:
		return {}
	if _mature_eye_offsets.is_empty() and FileAccess.file_exists(EYE_CALIBRATION):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EYE_CALIBRATION))
		if parsed is Dictionary and parsed.get("schema") == 1:
			var offsets: Dictionary = parsed.get("mature_rest_offsets", {})
			for name: String in ["Eye_L", "Eye_R"]:
				var row: Variant = offsets.get(name)
				if row is Array and row.size() == 3:
					var offset := Vector3(float(row[0]), float(row[1]), float(row[2]))
					if offset.is_finite() and offset.length() <= 0.035:
						_mature_eye_offsets[name] = offset
	return _mature_eye_offsets
