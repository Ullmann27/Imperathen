extends SceneTree
const Footwear := preload("res://scripts/visuals/resident_footwear.gd")
const Figure := preload("res://scripts/visuals/village_person.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var measured := {}
	for family in ["civilian_man", "civilian_woman", "elder"]:
		for level in 4:
			var path := "res://assets/characters/frontier_%s_%d.glb" % [family, level]
			var scene := load(path) as PackedScene
			var original := scene.instantiate() as Node3D
			var same := scene.instantiate() as Node3D
			root.add_child(original)
			root.add_child(same)
			var held: MeshInstance3D = original.find_child("HeroSandal_L", true, false)
			var material := held.get_active_material(0)
			var skin := held.skin
			var source := _ordered_surface(original)
			if not Footwear.apply(original, path):
				_check(false, path + " refused parts " + str(original.find_children("HeroSandal*", "MeshInstance3D", true, false)))
				original.free()
				same.free()
				continue
			var combined := _ordered_surface(original)
			_check(source.exact == combined.exact, path + " changed positions, UVs, skin indices/weights, tangent handedness or triangle order")
			var angular_error := 0.0
			for j in source.axes.size():
				angular_error = maxf(angular_error, (source.axes[j] as Vector3).distance_to(combined.axes[j]))
			# The engine octahedrally packs tangent axes into 16-bit components.
			# One decode/encode pass must remain below 0.012 degrees even at a fold.
			_check(angular_error < 0.0002, path + " altered normal/tangent direction")
			_check(held.skin == skin and held.get_active_material(0) == material, path + " changed material or skin")
			_check(Footwear.apply(same, path), path + " second actor")
			var other: MeshInstance3D = same.find_child("HeroSandal_L", true, false)
			_check(held.mesh == other.mesh, path + " duplicate mesh allocation")
			var reference: WeakRef = weakref(held.mesh)
			var surface := RenderingServer.mesh_get_surface(held.mesh.get_rid(), 0)
			var buffer_bytes := 0
			for key in ["vertex_data", "attribute_data", "skin_data", "index_data"]:
				buffer_bytes += (surface[key] as PackedByteArray).size()
			measured[path] = {"vertices":held.mesh.surface_get_array_len(0), "indices":held.mesh.surface_get_array_index_len(0), "buffer_bytes":buffer_bytes, "axis_error":angular_error}
			_check(not Footwear.apply(original, path), path + " must not batch twice")
			original.free()
			same.free()
			_check(reference.get_ref() == null, path + " retained an unused mesh")
	var path := "res://assets/characters/frontier_civilian_man_1.glb"
	var body = load(path).instantiate()
	root.add_child(body)
	var piece = body.find_child("HeroSandal_R", true, false)
	piece.set_surface_override_material(0, StandardMaterial3D.new())
	_check(not Footwear.apply(body,path), "different materials must preserve the original meshes")
	piece.set_surface_override_material(0, null)
	piece.position.x += 0.1
	_check(not Footwear.apply(body,path), "different transforms must preserve the original meshes")
	body.free()
	var actor := Figure.new()
	root.add_child(actor)
	actor.configure_resident("italia", 40, "civilian_man", 0, null)
	for profile in ["low", "balanced", "high", "very_high"]:
		actor.profile = profile
		for level in [3, 2, 1, 0, 3]:
			actor._reload(level)
			var shown := 0
			for part: MeshInstance3D in actor.body.find_children("HeroSandal*", "MeshInstance3D", true, false):
				if part.visible:
					shown += 1
			_check(shown == 1, "normal profile/LOD entry: %s/%s" % [profile, level])
	actor.free()
	print("RESIDENT_FOOTWEAR %d checks, %d failures, array sizes %s" % [checks, failures, JSON.stringify(measured)])
	if failures == 0:
		print("RESIDENT_FOOTWEAR_PASS")
	quit(1 if failures else 0)

func _ordered_surface(body: Node3D) -> Dictionary:
	var axes: Array[Vector3] = []
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	# Hash every expanded triangle vertex, irrespective of how the importer
	# shares its indices. Check quantised lighting axes separately.
	for node in body.find_children("HeroSandal*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if not part.visible:
			continue
		var mesh := part.mesh
		var arr := mesh.surface_get_arrays(0)
		var positions: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var tangent: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		for i in indices:
			var v := positions[i]
			var t := uv[i]
			axes.append(normals[i])
			axes.append(Vector3(tangent[4*i], tangent[4*i+1], tangent[4*i+2]))
			var attributes := PackedFloat32Array([v.x, v.y, v.z, t.x, t.y, tangent[4*i+3]])
			digest.update(attributes.to_byte_array())
			for k in 4:
				digest.update(PackedInt32Array([bones[4*i+k]]).to_byte_array())
				digest.update(PackedFloat32Array([weights[4*i+k]]).to_byte_array())
	return {"exact":digest.finish().hex_encode(), "axes":axes}
