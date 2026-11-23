extends SceneTree
## Offline resource compiler invoked by build_hand_grips.py after Blender FK.

func _initialize() -> void:
	for path: String in OS.get_cmdline_user_args():
		var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var positions := PackedVector3Array()
		var deltas := PackedVector3Array()
		var rotations := PackedColorArray()
		for row: Array in payload.records:
			positions.append(Vector3(row[0], row[1], row[2]))
			deltas.append(Vector3(row[3], row[4], row[5]))
			rotations.append(Color(row[6], row[7], row[8], row[9]))
		var resource := Resource.new()
		resource.set_meta("source_sha256", payload.source_sha256)
		resource.set_meta("positions", positions)
		resource.set_meta("deltas", deltas)
		resource.set_meta("rotations", rotations)
		if ResourceSaver.save(resource, payload.destination, ResourceSaver.FLAG_COMPRESS) != OK:
			printerr("Could not write grip resource " + payload.destination)
			quit(1)
			return
	print("HAND_GRIPS_COMPILED")
	quit(0)
