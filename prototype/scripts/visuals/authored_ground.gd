extends RefCounted
## Ground offset of an exported rig, measured from its own skinned soles.
##
## build_frontier_people.py fits the hero body onto the unchanged company
## skeleton (fit_to_company) so the tested soldier gait, shielding and melee
## contacts keep their bone geometry. The fitted hero foot is shorter below
## the ankle than the company rig, which leaves every military frontier export
## standing on soles 3.41 cm (LOD 0) / 3.23 cm (LOD 2) above the model origin,
## in the bind pose and in every imported clip. Lowering the whole model by
## that authored lift keeps bones, clips and gameplay contacts unchanged.

const FOOT_BINDS := ["Foot_L", "Foot_R", "Toe_L", "Toe_R"]
const FOOT_WEIGHT := .5

static var _lift_by_path := {}


## Lowest bind-pose height of the foot-skinned vertices in model space.
## Returns 0.0 when the model has no skinned foot (nothing to correct).
static func sole_lift(path: String, model: Node3D) -> float:
	if _lift_by_path.has(path):
		return float(_lift_by_path[path])
	var lowest := INF
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var shape := node as MeshInstance3D
		if shape.mesh == null or shape.skin == null:
			continue
		var foot_binds := PackedInt32Array()
		for index in shape.skin.get_bind_count():
			if String(shape.skin.get_bind_name(index)) in FOOT_BINDS:
				foot_binds.append(index)
		if foot_binds.is_empty():
			continue
		# Mesh space to model space through the imported node hierarchy.
		var to_model := Transform3D.IDENTITY
		var parent: Node = shape
		while parent != null and parent != model:
			if parent is Node3D:
				to_model = (parent as Node3D).transform * to_model
			parent = parent.get_parent()
		for surface in shape.mesh.get_surface_count():
			var arrays := shape.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if vertices.is_empty() or bones.size() != weights.size() or bones.size() != vertices.size() * 4:
				continue
			for v in vertices.size():
				var amount := 0.0
				for slot in 4:
					if bones[v * 4 + slot] in foot_binds:
						amount += weights[v * 4 + slot]
				if amount >= FOOT_WEIGHT:
					lowest = minf(lowest, (to_model * vertices[v]).y)
	var lift := lowest if is_finite(lowest) else 0.0
	_lift_by_path[path] = lift
	return lift
