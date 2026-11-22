extends Node3D
## Batched silhouettes. Transforms supplied to sync() are local to this node.

const SoldierVisual = preload("res://scripts/visuals/soldier_visual.gd")
var _batches: Dictionary = {}

func sync(by_role: Dictionary) -> void:
	for role: String in SoldierVisual.ROLES:
		var transforms: Array = by_role.get(role, [])
		var batch: MultiMeshInstance3D = _batches.get(role)
		if transforms.is_empty():
			if batch:
				batch.multimesh.visible_instance_count = 0
				batch.hide()
			continue
		if batch == null:
			batch = MultiMeshInstance3D.new()
			batch.name = role.capitalize()
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.multimesh = MultiMesh.new()
			batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			batch.multimesh.mesh = SoldierVisual.far_mesh(role)
			_batches[role] = batch
			add_child(batch)
		var group := batch.multimesh
		if transforms.size() > group.instance_count:
			group.instance_count = nearest_po2(transforms.size())
		for index in transforms.size():
			group.set_instance_transform(index, transforms[index])
		group.visible_instance_count = transforms.size()
		batch.show()
