extends Node3D
## Batched silhouettes. Transforms supplied to sync() are local to this node.

const SoldierVisual = preload("res://scripts/visuals/soldier_visual.gd")
var _batches: Dictionary = {}
var _last_fraction := -1.0

func set_step_fraction(fraction: float) -> void:
	if is_equal_approx(_last_fraction, fraction):
		return
	_last_fraction = fraction
	for batch: MultiMeshInstance3D in _batches.values():
		if batch.visible:
			batch.material_override.set_shader_parameter("step_fraction", fraction)


func sync(by_role: Dictionary, gait_by_role: Dictionary = {}) -> void:
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
			batch.multimesh.use_custom_data = true
			batch.multimesh.mesh = SoldierVisual.far_mesh(role)
			var painted := batch.multimesh.mesh.surface_get_material(0) as StandardMaterial3D
			var stride := ShaderMaterial.new()
			stride.shader = preload("res://shaders/rank_stride.gdshader")
			stride.set_shader_parameter("pigments", painted.albedo_texture)
			stride.set_shader_parameter("finish_map", painted.roughness_texture)
			stride.set_shader_parameter("step_fraction", maxf(0, _last_fraction))
			batch.material_override = stride
			_batches[role] = batch
			add_child(batch)
		var group := batch.multimesh
		if transforms.size() > group.instance_count:
			group.instance_count = nearest_po2(transforms.size())
		var gait: Array = gait_by_role.get(role, [])
		for index in transforms.size():
			group.set_instance_transform(index, transforms[index])
			group.set_instance_custom_data(index, gait[index] if index < gait.size() else Color(0, 0, 0, 0))
		group.visible_instance_count = transforms.size()
		batch.show()
