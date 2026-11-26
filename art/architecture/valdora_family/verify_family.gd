extends SceneTree
## Headless checks of the imported Valdora house family (after --import):
## asset structure, budgets, LOD, texture arrays, profile differences, the
## household assignment and the match of visible surfaces and colliders.
##   godot --headless --path prototype --script "$PWD/art/architecture/valdora_family/verify_family.gd"

const Family = preload("res://scripts/world/village/architecture/valdora_house_family.gd")
const Regional = preload("res://scripts/world/regional_village.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const Art = preload("res://scripts/world/village_art.gd")
const Paving = preload("res://scripts/world/village/architecture/valdora_paving.gd")
var errors: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func require(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		errors.append(reason)
		push_error(reason)


func _run() -> void:
	var manifest := Family.manifest()
	var variants: Dictionary = manifest.variants
	require(variants.size() >= 8, "at least eight variants in the manifest")
	var tiers := {}
	for id: String in variants:
		var data: Dictionary = variants[id]
		tiers[int(data.tier)] = true
		var scene := load("res://assets/architecture/valdora/%s.glb" % id) as PackedScene
		require(scene != null, id + " imports")
		if scene == null:
			continue
		var model := scene.instantiate() as Node3D
		var names := {}
		for mesh_node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			names[str(mesh_node.name)] = mesh_node
		for role in ["_shell", "_detail", "_far"]:
			require(names.has(id + role), "%s has %s" % [id, role])
		for fixture in ["Fixture_Table", "Fixture_Bench", "Fixture_Jar"]:
			require(names.has(fixture), "%s keeps %s as a separate node" % [id, fixture])
		var stats := Family.imported_stats(model)
		var shell: Dictionary = stats.get(id + "_shell", {})
		var lods: Array = shell.get("lod_triangles", [])
		require(lods.size() >= 3, id + " shell has generated LODs")
		for i in range(1, lods.size()):
			require(int(lods[i]) < int(lods[i - 1]), id + " LOD reduces")
		var total := 0
		for key: String in stats:
			if not key.ends_with("_far"):
				total += int(stats[key].lod_triangles[0])
			require(int(stats[key].surfaces) == 1, "%s %s single surface" % [id, key])
		require(total <= int(data.budget_lod0), "%s LOD0 %d within budget %d" % [id, total, int(data.budget_lod0)])
		require(int(stats.get(id + "_far", {}).get("lod_triangles", [99999])[0]) <= int(data.budget_far), id + " far proxy budget")
		var arrays := (names[id + "_shell"] as MeshInstance3D).mesh.surface_get_arrays(0)
		require(arrays[Mesh.ARRAY_TEX_UV2] != null and (arrays[Mesh.ARRAY_TEX_UV2] as PackedVector2Array).size() > 0, id + " carries texture layers in UV2")
		require(arrays[Mesh.ARRAY_COLOR] != null and (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size() > 0, id + " carries ageing masks in COLOR")
		var max_layer := 0.0
		for uv: Vector2 in arrays[Mesh.ARRAY_TEX_UV2]:
			max_layer = maxf(max_layer, uv.x)
		require(max_layer <= 15.5, id + " layer indices within the 16 texture layers")
		print("VALDORA_FAMILY_ASSET ", id, " tier=", data.tier, " lod0_total=", total, " stats=", JSON.stringify(stats))
		model.free()
	require(tiers.size() >= 3, "three wealth tiers")
	for size in [1024, 512, 256]:
		var albedo := load("res://assets/architecture/valdora/family_albedo_%d.jpg" % size) as TextureLayered
		require(albedo != null and albedo.get_layers() == 16 and albedo.get_width() == size, "albedo array %d with 16 layers" % size)
	var normal := load("res://assets/architecture/valdora/family_normal_512.jpg") as TextureLayered
	require(normal != null and normal.get_layers() == 16, "normal array with 16 layers")
	# Profiles really differ: textures, normal maps, parallax and detail ranges.
	var low := Family.material("low", Color("dfd4bd"), "worn")
	var high := Family.material("very_high", Color("dfd4bd"), "worn")
	require((low.get_shader_parameter("albedo_layers") as TextureLayered).get_width() == 256, "Leicht uses 256 layers")
	require(not bool(low.get_shader_parameter("use_normal_map")), "Leicht has no normal map")
	require(bool(high.get_shader_parameter("use_parallax")), "Sehr hoch adds parallax relief")
	require((high.get_shader_parameter("albedo_layers") as TextureLayered).get_width() == 1024, "Sehr hoch uses 1024 layers")
	var balanced := Family.material("balanced", Color("dfd4bd"), "worn")
	require((balanced.get_shader_parameter("albedo_layers") as TextureLayered).get_width() == 512, "Ausgewogen uses 512 layers")
	require(Family.RANGES.low.detail < Family.RANGES.balanced.detail and Family.RANGES.balanced.detail < Family.RANGES.high.detail, "detail range grows with the profile")
	await _village(variants)
	print("VALDORA_FAMILY checks=", checks)
	print("VALDORA_FAMILY errors ", errors)
	quit(0 if errors.is_empty() else 1)


func _village(variants: Dictionary) -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	Art.box_collider(stage, Vector3(300, .5, 150), Vector3(30, -.26, 0))
	var region := Regional.new()
	stage.add_child(region)
	region.show_origin("italia")
	await physics_frame
	await physics_frame
	require(region.house_count == 20, "twenty households")
	var used := {}
	var space := stage.get_world_3d().direct_space_state
	for home: Dictionary in Layout.HOMES:
		var house := region.get_node(NodePath(home.id)) as Node3D
		require(house != null and Family.is_family_house(house), home.id + " is a family house")
		if house == null:
			continue
		var variant: String = house.get_meta("house_variant")
		used[variant] = int(used.get(variant, 0)) + 1
		require(variants.has(variant), home.id + " variant exists")
		# The visible threshold, ramp and porch surfaces equal the collider tops.
		var shell := house.get_node(NodePath(variant + "_shell")) as MeshInstance3D
		var tri := shell.mesh.generate_triangle_mesh()
		var entry: Dictionary = variants[variant].metadata.entry
		var worst := 0.0
		for x: float in [-.45, 0.0, .45]:
			for z: float in [2.3, 2.7, float(entry.ramp_start_z) + .25, float(entry.ramp_start_z) + .55, float(entry.ramp_start_z) + .85]:
				var top := Vector3(x, 1.2, z)
				var down := Vector3(x, -.5, z)
				var visual := tri.intersect_segment(top, down)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(house.to_global(top), house.to_global(down), 1))
				if visual.is_empty() or hit.is_empty():
					require(false, "%s entry sample (%.2f, %.2f) visual=%s physics=%s" % [home.id, x, z, not visual.is_empty(), not hit.is_empty()])
					continue
				var gap: float = absf(float(visual.position.y) - house.to_local(hit.position).y)
				worst = maxf(worst, gap)
		require(worst <= .03, "%s visible entry within 3 cm of its collider (worst %.3f m)" % [home.id, worst])
		# Doorway: free for the mesh and the physics; the walls beside it are solid.
		for x: float in [-.5, 0.0, .5]:
			for h: float in [.6, 1.4, 2.3]:
				var a := Vector3(x, h, 3.2)
				var b := Vector3(x, h, 1.6)
				require(tri.intersect_segment(a, b).is_empty(), "%s mesh doorway clear at x=%.1f h=%.1f" % [home.id, x, h])
				require(space.intersect_ray(PhysicsRayQueryParameters3D.create(house.to_global(a), house.to_global(b), 1)).is_empty(),
					"%s physics doorway clear at x=%.1f h=%.1f" % [home.id, x, h])
		for x: float in [-1.9, 1.9]:
			var a := Vector3(x, 1.0, 3.4)
			var b := Vector3(x, 1.0, 1.8)
			require(not space.intersect_ray(PhysicsRayQueryParameters3D.create(house.to_global(a), house.to_global(b), 1)).is_empty(), home.id + " wall beside the door is solid")
		var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(house.to_global(Vector3(.35, 2, .35)), house.to_global(Vector3(.35, -1, .35)), 1))
		require(not floor_hit.is_empty() and absf(float(floor_hit.position.y) - Layout.HOUSE_FLOOR) < .015, home.id + " floor at the paving height")
		var visual_floor := tri.intersect_segment(Vector3(.35, 2, .35), Vector3(.35, -1, .35))
		require(not visual_floor.is_empty() and absf(float(visual_floor.position.y) - Layout.HOUSE_FLOOR) < .012, home.id + " visible paving at the collider height")
	require(used.size() >= 6, "at least six different variants are placed (%d)" % used.size())
	var max_repeat := 0
	for v: String in used:
		max_repeat = maxi(max_repeat, int(used[v]))
	require(max_repeat <= 4, "no variant used more than four times (%d)" % max_repeat)
	print("VALDORA_FAMILY_ASSIGNMENT ", JSON.stringify(used))
	# Paving: present, cheap, flat on the ground collider, profile dependent.
	var paving := region.get_node_or_null("ValdoraPaving") as Node3D
	require(paving != null, "village paving exists")
	if paving != null:
		var paving_triangles := 0
		var chunks := 0
		for mesh_node: MeshInstance3D in paving.find_children("Paving_*", "MeshInstance3D", true, false):
			chunks += 1
			paving_triangles += mesh_node.mesh.surface_get_array_index_len(0) / 3
			var aabb := mesh_node.get_aabb()
			require(aabb.position.y > -.01 and aabb.end.y < .012, "%s lies on the ground (y %.3f..%.3f)" % [mesh_node.name, aabb.position.y, aabb.end.y])
		require(chunks >= 2 and paving_triangles > 500 and paving_triangles < 30000, "paving chunks %d with %d triangles" % [chunks, paving_triangles])
		var stones := paving.get_node_or_null("SetStones") as MultiMeshInstance3D
		require(stones != null and stones.multimesh.instance_count >= 20, "set stones are instanced")
		if stones != null:
			require(stones.multimesh.mesh.get_aabb().end.y <= .018, "set stones stand at most 18 mm proud")
		require(paving.patches.size() >= 30, "square, aprons, drip strips, paths and hollows planned (%d)" % paving.patches.size())
		var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-7.6, 2, 3.4), Vector3(-7.6, -2, 3.4), 1))
		require(not ground.is_empty() and absf(float(ground.position.y) - (-.01)) < .02, "ground collider under the square")
		print("VALDORA_PAVING chunks=", chunks, " triangles=", paving_triangles, " patches=", paving.patches.size(), " stones=", stones.multimesh.instance_count if stones else 0)
	for profile in ["low", "balanced", "high", "very_high"]:
		region.set_quality(profile)
		var house := region.get_node("baker_home") as Node3D
		var detail := house.get_node(NodePath(str(house.get_meta("house_variant")) + "_detail")) as GeometryInstance3D
		require(is_equal_approx(detail.visibility_range_end, float(Family.RANGES[profile].detail)), profile + " detail range applied")
		if paving != null:
			var chunk := paving.find_children("Paving_*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var paint := chunk.material_override as ShaderMaterial
			require(bool(paint.get_shader_parameter("use_normal_map")) == (profile != "low"), profile + " paving normal map setting")
			require(is_equal_approx(chunk.visibility_range_end, float(Paving.RANGES[profile])), profile + " paving range")
	stage.free()
	await process_frame
