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
