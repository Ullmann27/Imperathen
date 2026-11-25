extends SceneTree
## Material changes must not alter shared resources, rigs, colour or far LODs.
const Detail := preload("res://scripts/rendering/city_character_detail.gd")
var checks := 0
var failures: Array[String] = []
var texture_evidence: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr(message)


func _plane(material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.material = material
	node.mesh = mesh
	return node


func _run() -> void:
	for specification: Array in [["skin_detail_normal.png", 10], ["skin_detail_roughness.png", 10], ["linen_detail_normal.png", 10], ["leather_detail_normal.png", 8]]:
		var path: String = Detail.ROOT + str(specification[0])
		var texture := load(path) as Texture2D
		_expect(texture is CompressedTexture2D, "Detail must be a real imported Texture2D resource: " + path)
		var bitmap: Image = texture.get_image() if texture != null else null
		var mip_count := bitmap.get_mipmap_count() if bitmap != null else 0
		_expect(bitmap != null and bitmap.has_mipmaps() and mip_count == int(specification[1]), "Actual imported texture must contain the complete mip chain: " + path)
		texture_evidence.append({"path": path, "class": texture.get_class() if texture != null else "missing",
			"width": texture.get_width() if texture != null else 0,
			"height": texture.get_height() if texture != null else 0,
			"mipmap_count_excluding_base": mip_count, "source_sha256": FileAccess.get_sha256(path),
			"import_settings_sha256": FileAccess.get_sha256(path + ".import")})
		print("CITY_TEXTURE_RESOURCE ", JSON.stringify(texture_evidence.back()))
	var source := StandardMaterial3D.new()
	source.resource_name = "HeroSkin"
	source.roughness = 0.63
	source.albedo_color = Color(0.72, 0.51, 0.39, 0.75)
	var image := Image.create(4, 4, true, Image.FORMAT_RGBA8)
	image.fill(Color(0.3, 0.4, 0.5, 0.6))
	source.albedo_texture = ImageTexture.create_from_image(image)
	var original_filter := source.texture_filter
	var first := _plane(source)
	var second := MeshInstance3D.new()
	second.mesh = first.mesh
	_expect(Detail.apply_to(first, "balanced", 0) == 0, "Balanced must keep the original material.")
	_expect(Detail.apply_to(first, "high", 0) == 1, "High near skin must be detailed.")
	var detailed := first.get_active_material(0) as StandardMaterial3D
	_expect(detailed != source, "Detail must be an instance override.")
	_expect(detailed.albedo_texture == source.albedo_texture and detailed.albedo_color == source.albedo_color, "Face colour, alpha and original texture must stay identical.")
	_expect(source.normal_texture == null and is_equal_approx(source.roughness, 0.63) and source.texture_filter == original_filter, "Shared source material must remain unchanged.")
	_expect(detailed.normal_texture.get_width() == 1024 and detailed.normal_texture.get_height() == 1024, "Skin must use authored 1024 surface data.")
	_expect(detailed.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC, "Near surfaces must use anisotropic mipmap filtering.")
	_expect(Detail.apply_to(first, "high", 0) == 0, "Repeated application must be idempotent.")
	_expect(Detail.apply_to(second, "high", 0) == 1 and second.get_active_material(0) == detailed, "Equal live sources should reuse one material.")
	_expect(Detail.apply_to(first, "very_high", 0) == 1 and is_equal_approx((first.get_active_material(0) as StandardMaterial3D).normal_scale, 1.0), "Very high must select its own bounded strength.")
	_expect(is_equal_approx(detailed.normal_scale, 0.8), "A second actor must not inherit another actor's profile switch.")
	_expect(Detail.apply_to(first, "very_high", 2) == 1 and first.get_active_material(0) == source, "Far LOD must restore the exact source material.")
	_expect(Detail.apply_to(second, "low", 0) == 1 and second.get_active_material(0) == source, "Low profile must restore the exact source material.")
	for name: String in ["FrontierSkin", "HeroLinen", "FrontierCloth", "HeroLeather"]:
		var mat := StandardMaterial3D.new()
		mat.resource_name = name
		var node := _plane(mat)
		_expect(Detail.apply_to(node, "high", 1) == 1, "Known near material was skipped: " + name)
		_expect(node.mesh.surface_get_material(0) == mat and mat.normal_texture == null, "Known source was mutated: " + name)
		node.free()
	var unknown := StandardMaterial3D.new()
	unknown.resource_name = "Meshy_unit_roman_signifer"
	var atlas := _plane(unknown)
	_expect(Detail.apply_to(atlas, "very_high", 0) == 0 and atlas.get_active_material(0) == unknown, "Mixed Meshy atlas must not be treated as skin or cloth.")
	atlas.free()
	var bare := MeshInstance3D.new()
	var arrays := first.mesh.surface_get_arrays(0)
	arrays[Mesh.ARRAY_TANGENT] = null
	_expect(not Detail.has_normal_basis(arrays), "A missing tangent basis must prevent normal-map application.")
	# Godot 4.7 synthesizes tangent data when ArrayMesh is created. The
	# missing-input guard is therefore checked before that reconstruction.
	# Missing UVs remain missing and form the real mesh integration case.
	arrays[Mesh.ARRAY_TEX_UV] = null
	var no_tangents := ArrayMesh.new()
	no_tangents.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	no_tangents.surface_set_material(0, source)
	bare.mesh = no_tangents
	_expect(Detail.apply_to(bare, "high", 0) == 0, "A real mesh without UVs must not receive a normal map.")
	bare.free()
	var overriding := _plane(source)
	overriding.material_override = unknown
	_expect(Detail.apply_to(overriding, "high", 0) == 0 and overriding.material_override == unknown, "A full instance material override must remain authoritative.")
	overriding.free()
	_expect(Detail.apply_to(null, "high", 0) == 0, "Null roots must be harmless.")
	var scene := load("res://assets/characters/hero_quality_0.glb") as PackedScene
	_expect(scene != null, "Actual hero GLB must be imported for the character regression.")
	if scene != null:
		var hero := scene.instantiate()
		var meshes: Array = hero.find_children("*", "MeshInstance3D", true, false)
		var originals := []
		for node: MeshInstance3D in meshes:
			var surfaces := []
			for surface in node.mesh.get_surface_count():
				surfaces.append(node.get_active_material(surface))
			originals.append([node, node.mesh, node.skin, surfaces])
		var skeletons := hero.find_children("*", "Skeleton3D", true, false)
		var skeleton_counts := []
		for skeleton: Skeleton3D in skeletons:
			skeleton_counts.append(skeleton.get_bone_count())
		_expect(Detail.apply_to(hero, "very_high", 0) > 0, "Actual hero surfaces must receive the optional material pass.")
		for row: Array in originals:
			var node := row[0] as MeshInstance3D
			_expect(node.mesh == row[1] and node.skin == row[2], "Actual hero mesh or skin was replaced: " + node.name)
			for surface in node.mesh.get_surface_count():
				var before := row[3][surface] as BaseMaterial3D
				var after := node.get_active_material(surface) as BaseMaterial3D
				if before != null and after != null:
					_expect(before.albedo_texture == after.albedo_texture and before.albedo_color == after.albedo_color, "Actual hero colour identity changed: " + node.name)
		for index in skeletons.size():
			_expect((skeletons[index] as Skeleton3D).get_bone_count() == skeleton_counts[index], "Bone count changed.")
		Detail.apply_to(hero, "balanced", 0)
		for row: Array in originals:
			var node := row[0] as MeshInstance3D
			for surface in node.mesh.get_surface_count():
				_expect(node.get_active_material(surface) == row[3][surface], "Actual hero source was not restored: " + node.name)
		hero.free()
	first.free()
	second.free()
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		var report_path: String = arguments[0]
		DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
		var report_file := FileAccess.open(report_path, FileAccess.WRITE)
		if report_file == null:
			printerr("Cannot write character texture evidence: " + report_path)
			quit(1)
			return
		report_file.store_string(JSON.stringify({"engine": Engine.get_version_info().string,
			"display_server": DisplayServer.get_name(), "checks": checks, "failures": failures,
			"test_sha256": FileAccess.get_sha256(get_script().resource_path),
			"helper_sha256": FileAccess.get_sha256("res://scripts/rendering/city_character_detail.gd"),
			"texture_resources": texture_evidence}, "  ") + "\n")
		report_file.close()
	print("CITY_CHARACTER_DETAIL: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
