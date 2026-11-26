extends RefCounted
## Epoch gate for monuments (D-053): later buildings must not appear in an
## earlier city.  Works on any imported world scene whose nodes carry the
## builder's glTF extra `era_min_ce` (e.g. the legacy RomanCity GLB).
const EraRegistry := preload("res://scripts/domain/era_registry.gd")


static func _era_of(node: Node) -> Variant:
	if node.has_meta("extras"):
		var extras: Variant = node.get_meta("extras")
		if extras is Dictionary and extras.has("era_min_ce"):
			return int(extras.era_min_ce)
	if node.has_meta("era_min_ce"):
		return int(node.get_meta("era_min_ce"))
	return null


## Hides (and disables collision below) every node whose `era_min_ce` lies after the world date.
## Returns {"hidden": [...names], "kept": int}.
static func apply(root: Node, jdn: int) -> Dictionary:
	var hidden: Array[String] = []
	var kept := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var era: Variant = _era_of(node)
		if era != null and not EraRegistry.era_min_visible(int(era), jdn):
			hidden.append(str(node.name))
			if node is Node3D:
				(node as Node3D).visible = false
			for shape: Node in node.find_children("*", "CollisionShape3D", true, false):
				(shape as CollisionShape3D).disabled = true
			if node is CollisionObject3D:
				(node as CollisionObject3D).process_mode = Node.PROCESS_MODE_DISABLED
				(node as CollisionObject3D).collision_layer = 0
			continue
		if era != null:
			kept += 1
		for child: Node in node.get_children():
			stack.append(child)
	return {"hidden": hidden, "kept": kept}
