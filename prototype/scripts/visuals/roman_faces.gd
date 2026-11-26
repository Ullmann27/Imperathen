extends RefCounted
## Close-up shape controls baked on the existing frontier models in Blender.
## Each mesh stays shared. Only instance weights change, once per materialization.
const FEATURES := [&"CastJaw",&"CastBridge",&"CastCheeks",&"CastHair"]

# The original photographic atlas and its roughness/normal maps stay attached.
const COMPLEXIONS := [Color(1.00,.99,.97),Color(.96,.92,.89),Color(.91,.86,.80),
	Color(.85,.76,.68),Color(.78,.68,.59),Color(.71,.59,.51),Color(.65,.53,.46)]


static func apply(model: Node3D, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var traits := PackedFloat32Array()
	for feature in FEATURES:
		traits.append(rng.randf_range(-0.92, 0.98))
	var complexion := rng.randi_range(0,COMPLEXIONS.size()-1)
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if part.mesh == null:
			continue
		if part.name == &"HeroBody" and part.find_blend_shape_by_name(&"CastJaw") >= 0:
			_apply_skin(part,complexion)
		for index in FEATURES.size():
			var slot := part.find_blend_shape_by_name(FEATURES[index])
			if slot >= 0:
				part.set_blend_shape_value(slot, traits[index])

static func _apply_skin(part: MeshInstance3D, complexion: int) -> void:
	var source := part.mesh.surface_get_material(0) as StandardMaterial3D
	if source == null:
		return
	var key := "legio_complexion_%d" % complexion
	var cached := source.get_meta(key,null) as WeakRef if source.has_meta(key) else null
	var finish: StandardMaterial3D = cached.get_ref() if cached else null
	if not finish:
		finish = source.duplicate() as StandardMaterial3D
		finish.albedo_color *= COMPLEXIONS[complexion]
		source.set_meta(key,weakref(finish))
	part.material_override = finish
