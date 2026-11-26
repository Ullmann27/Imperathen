extends SceneTree
## Vegetation assets, ecological placement and profile budgets (headless).
## Checks the Blender build output (4 LODs with falling triangle counts,
## wind vertex data, impostors, textures), deterministic ecological rules
## (habitats, clustering, raid-route and house clearance, no anachronistic
## species) and that the four graphics profiles really differ.
## Prints VEGETATION_PASS and a JSON budget table per profile.

const Library = preload("res://scripts/vegetation/vegetation_library.gd")
const Ecology = preload("res://scripts/vegetation/vegetation_ecology.gd")
const Field = preload("res://scripts/vegetation/vegetation_field.gd")
const Ground = preload("res://scripts/vegetation/vegetation_ground.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const Scenery = preload("res://scripts/world/village/village_scenery.gd")
const Land = preload("res://scripts/world/village/valdora_land.gd")
## Species allowed for 58 BC Valdora (docs/vegetation/ARTENLISTE_VALDORA_58VC.md).
const ALLOWED := ["quercus_robur", "quercus_cerris", "ulmus_minor", "fraxinus_angustifolia", "carpinus_betulus",
	"populus_nigra", "salix_alba", "salix_alba_pollard", "alnus_glutinosa", "acer_campestre", "acer_campestre_arbustum",
	"corylus_avellana", "crataegus_monogyna", "prunus_spinosa", "sambucus_nigra", "vitis_arbustum", "vitis_stake"]
const PROFILES := ["low", "balanced", "high", "very_high"]
var failures: Array[String] = []
var checks := 0
var summary := {}


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _run() -> void:
	_check_assets()
	var scenery := Scenery.new()
	root.add_child(scenery)
	scenery.create_land()
	var ground := Ground.new()
	ground.add_mesh(scenery.get_node_or_null("Foothills") as MeshInstance3D)
	var legacy := _legacy_sites()
	var first := Ecology.new(ground.height)
	first.build(legacy)
	var second := Ecology.new(ground.height)
	second.build(legacy)
	_check(first.trees.size() == second.trees.size() and first.counts == second.counts, "Placement is deterministic")
	_check(first.trees.size() > 1200, "A real landscape of trees and shrubs (%d)" % first.trees.size())
	_check(str(first.trees[100].position) == str(second.trees[100].position), "Same instance positions on rebuild")
	_check_rules(first, legacy)
	_check_clustering(first)
	await _check_profiles(ground, legacy)
	scenery.free()
	summary["checks"] = checks
	summary["failures"] = failures
	print("VEGETATION_SUMMARY ", JSON.stringify(summary))
	for failure in failures:
		printerr("FAIL: " + failure)
	print("VEGETATION_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("VEGETATION_PASS" if failures.is_empty() else "VEGETATION_FAIL")
	quit(0 if failures.is_empty() else 1)


func _check_assets() -> void:
	var names := Library.asset_names()
	_check(names.size() >= 17, "Manifest lists every species asset (%d)" % names.size())
	var table := {}
	for name: String in names:
		_check(name in ALLOWED, "Asset is on the 58 BC species list: " + name)
		var asset := Library.asset(name)
		var tris: Array = asset.triangles
		_check(asset.lods.size() == 4, "Four mesh LODs: " + name)
		for level in range(1, 4):
			_check(tris[level] < tris[level - 1], "LOD%d has fewer triangles than LOD%d: %s %s" % [level, level - 1, name, str(tris)])
		var kind: String = asset.kind
		if kind != "vine":
			_check(asset.impostor != null, "Impostor card for " + name)
		var lod0: Mesh = asset.lods[0]
		_check(lod0.get_surface_count() == 2, "Bark and leaf surfaces: " + name)
		var bark := lod0.surface_get_material(0) as ShaderMaterial
		var leaf := lod0.surface_get_material(1) as ShaderMaterial
		_check(bark != null and bark.shader == Library.BARK_SHADER and bark.get_shader_parameter("bark_normal") != null, "Bark normal-mapped material: " + name)
		_check(leaf != null and leaf.shader == Library.LEAF_SHADER and leaf.get_shader_parameter("leaf_albedo") != null, "Alpha leaf material: " + name)
		var bark_arrays := lod0.surface_get_arrays(0)
		var leaf_arrays := lod0.surface_get_arrays(1)
		var bark_colors: PackedColorArray = bark_arrays[Mesh.ARRAY_COLOR]
		var leaf_colors: PackedColorArray = leaf_arrays[Mesh.ARRAY_COLOR]
		_check(not bark_colors.is_empty() and not leaf_colors.is_empty(), "Wind vertex data present: " + name)
		if leaf_colors.is_empty() or bark_colors.is_empty():
			continue
		var flutter := 0.0
		var bend := 0.0
		for c in leaf_colors:
			flutter = maxf(flutter, c.b)
			bend = maxf(bend, c.r)
		var trunk_bend := 1.0
		var vertices: PackedVector3Array = bark_arrays[Mesh.ARRAY_VERTEX]
		for i in vertices.size():
			if vertices[i].y < .3:
				trunk_bend = minf(trunk_bend, bark_colors[i].r)
		_check(flutter > .95 and bend > .3, "Leaf flutter and branch bend weights: %s %.2f %.2f" % [name, flutter, bend])
		_check(trunk_bend < .05, "Stem base does not bend: %s %.2f" % [name, trunk_bend])
		_check(not (bark_arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).is_empty(), "Tangents for normal maps: " + name)
		table[name] = {"triangles": tris, "height_m": snappedf(asset.height, .1), "kind": kind}
	var near_tuft := Library.grass_mesh("grass_tuft_near")
	var far_tuft := Library.grass_mesh("grass_tuft_far")
	_check(near_tuft != null and far_tuft != null, "Blade tuft meshes are built")
	if near_tuft != null and far_tuft != null:
		_check(Library._triangles(near_tuft) > Library._triangles(far_tuft) * 3, "Near tuft has real blade geometry (%d vs %d triangles)" % [Library._triangles(near_tuft), Library._triangles(far_tuft)])
		_check((near_tuft.surface_get_material(0) as ShaderMaterial).shader == Library.GRASS_SHADER, "Blade grass uses the wind shader")
	for variant in ["clump_near", "clump_far"]:
		var mesh := Library.card_mesh(variant, "herbs")
		_check(mesh != null and mesh.get_surface_count() == 1, "Card mesh " + variant)
	summary["assets"] = table


func _legacy_sites() -> Array:
	# Same generator as GameWorld._create_terrain (seed 104729).
	var random := RandomNumberGenerator.new()
	random.seed = 104729
	var sites := []
	for index in range(38):
		var x := random.randf_range(-61, -33) if index < 22 else random.randf_range(-20, 43)
		var z := random.randf_range(-42, 28) if index < 22 else random.randf_range(-46, -27)
		if Layout.reserved(Vector2(x, z), 1.3) or Layout.road(Vector2(x, z)):
			continue
		sites.append({"kind": "oak", "position": Vector3(x, 0, z), "scale": 1.0, "yaw": random.randf_range(-PI, PI)})
	for at in [Vector3(-18, 0, 8), Vector3(6, 0, -12), Vector3(-19, 0, 15), Vector3(26, 0, 16)]:
		sites.append({"kind": "oak", "position": at, "scale": 0.92, "yaw": random.randf_range(-PI, PI)})
	return sites


func _check_rules(eco: Ecology, legacy: Array) -> void:
	var legacy_positions := {}
	for site: Dictionary in legacy:
		legacy_positions[str(site.position)] = true
	var wet := {"riparian": [], "wood": []}
	var in_house := 0
	var on_track := 0
	var in_water := 0
	var illegal := 0
	for tree: Dictionary in eco.trees:
		var at: Vector3 = tree.position
		var p := Vector2(at.x, at.z)
		if not tree.asset in ALLOWED:
			illegal += 1
		if Layout.reserved(p, 0.0) and not tree.legacy:
			in_house += 1
		if eco.in_track(p) and not tree.legacy:
			on_track += 1
		if eco.water_distance(p) < .3 and tree.asset not in ["vitis_stake"]:
			in_water += 1
		if tree.asset in ["salix_alba", "alnus_glutinosa", "salix_alba_pollard"] and not tree.legacy:
			wet.riparian.append(eco.wetness(p))
		if tree.asset == "quercus_robur" and p.x < eco.wood_edge_x(at.z) - 20.0:
			wet.wood.append(eco.wetness(p))
	_check(illegal == 0, "Only listed species are placed")
	_check(in_house == 0, "No plant inside a house footprint or yard (%d)" % in_house)
	_check(on_track == 0, "Tracks stay unplanted (%d)" % on_track)
	_check(in_water == 0, "No tree or shrub stands in the brook (%d)" % in_water)
	_check(_median(wet.riparian) > _median(wet.wood) + .25, "Willows and alders grow wetter than wood oaks (%.2f vs %.2f)" % [_median(wet.riparian), _median(wet.wood)])
	var raid := 0
	for entry: Array in eco.colliders:
		var at: Vector3 = entry[0]
		if Ecology.RAID_SURVEY.has_point(Vector2(at.x, at.z)):
			raid += 1
	_check(raid == 0, "No new collider in the raid-route survey (%d)" % raid)
	# Meadow blades: bare on tracks, water, crops and the village ground.
	_check(eco.grass_cover(Vector2(Land.south_track_x(60.0), 60.0)).x == 0.0, "No grass on the south track tread")
	_check(eco.grass_cover(Vector2(Land.brook_x(20.0), 20.0)).x == 0.0, "No grass in the brook")
	_check(eco.grass_cover(Vector2(0.0, 0.0)).x == 0.0, "No meadow blades on the village ground")
	_check(eco.grass_cover(Vector2(-14.0, 52.0)).x > .5, "Meadow south-west of the village grows grass (%.2f)" % eco.grass_cover(Vector2(-14.0, 52.0)).x)
	var crop_grass := 0
	for x in range(20, 140, 7):
		for z in range(50, 140, 7):
			var field := eco.parcel(Vector2(x, z))
			if not field.is_empty() and float(field.boundary) >= 1.5 and eco.grass_cover(Vector2(x, z)).x > 0.0:
				crop_grass += 1
	_check(crop_grass == 0, "No meadow grass inside the crop of a parcel (%d)" % crop_grass)
	var kept := 0
	for tree: Dictionary in eco.trees:
		if tree.legacy and legacy_positions.has(str(tree.position)):
			kept += 1
	_check(kept == legacy.size(), "Every existing village tree site is kept (%d/%d)" % [kept, legacy.size()])
	var crops_outside := 0
	for chunk: Dictionary in eco.cards.values():
		if chunk.atlas != "crops":
			continue
		var buffer: PackedFloat32Array = chunk.buffer
		for i in range(0, buffer.size(), 16 * 7):
			var p := Vector2(buffer[i + 3], buffer[i + 11])
			if eco.parcel(p).is_empty() and not Ecology.ENCLOSURE.has_point(p):
				crops_outside += 1
	_check(crops_outside == 0, "Crops only inside field parcels and kitchen gardens (%d)" % crops_outside)
	summary["placed"] = eco.counts
	summary["colliders"] = eco.colliders.size()


func _check_clustering(eco: Ecology) -> void:
	# Index of dispersion (variance / mean of counts per quadrat): 1 for a
	# random scatter, < 1 for an even grid, > 1 for natural clumping.
	var quadrats := {}
	for chunk: Dictionary in eco.cards.values():
		if chunk.atlas != "herbs":
			continue
		var c: Vector3 = chunk.center
		if Rect2(-130, -70, 305, 235).has_point(Vector2(c.x, c.z)):
			quadrats[str(c)] = int(chunk.count)
	var values: Array = quadrats.values()
	var mean := 0.0
	for v in values:
		mean += v
	mean /= maxf(1.0, values.size())
	var variance := 0.0
	for v in values:
		variance += (v - mean) * (v - mean)
	variance /= maxf(1.0, values.size() - 1)
	_check(variance / maxf(mean, .001) > 2.0, "Herbs grow in clumps and drifts (dispersion %.1f)" % (variance / maxf(mean, .001)))
	var shrubs := {}
	for tree: Dictionary in eco.trees:
		if tree.asset in ["prunus_spinosa", "crataegus_monogyna", "corylus_avellana"]:
			var at: Vector3 = tree.position
			var key := "%d_%d" % [floori(at.x / 20.0), floori(at.z / 20.0)]
			shrubs[key] = int(shrubs.get(key, 0)) + 1
	var shrub_values: Array = shrubs.values()
	var shrub_mean := 0.0
	for v in shrub_values:
		shrub_mean += v
	shrub_mean /= maxf(1.0, shrub_values.size())
	var shrub_var := 0.0
	for v in shrub_values:
		shrub_var += (v - shrub_mean) * (v - shrub_mean)
	shrub_var /= maxf(1.0, shrub_values.size() - 1)
	_check(shrub_var / maxf(shrub_mean, .001) > 1.5, "Shrubs form hedges and mantles (dispersion %.1f)" % (shrub_var / maxf(shrub_mean, .001)))
	summary["dispersion"] = {"herbs": snappedf(variance / maxf(mean, .001), .01), "shrubs": snappedf(shrub_var / maxf(shrub_mean, .001), .01)}


func _check_profiles(ground: Ground, legacy: Array) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(640, 360)
	view.own_world_3d = true
	root.add_child(view)
	var camera := Camera3D.new()
	camera.far = 300.0
	view.add_child(camera)
	camera.current = true
	var field := Field.new()
	view.add_child(field)
	field.build(ground.height, legacy)
	await process_frame
	var table := {}
	var shots := {"wood_edge": [Vector3(-21, 1.75, -4), Vector3(-70, 5, -12)], "fields": [Vector3(12, 2.6, 33), Vector3(4, .8, 75)]}
	for profile: String in PROFILES:
		field.set_quality(profile)
		table[profile] = {}
		for shot: String in shots:
			camera.global_position = shots[shot][0]
			camera.look_at(shots[shot][1], Vector3.UP)
			field.refresh(camera)
			table[profile][shot] = field.stats()
	for shot: String in shots:
		var low: Dictionary = table.low[shot]
		var balanced: Dictionary = table.balanced[shot]
		var very: Dictionary = table.very_high[shot]
		_check(low.card_instances_visible < balanced.card_instances_visible and balanced.card_instances_visible < very.card_instances_visible,
			"Herb/crop density rises with the profile at %s (%d/%d/%d)" % [shot, low.card_instances_visible, balanced.card_instances_visible, very.card_instances_visible])
		_check(low.tree_triangles_submitted < balanced.tree_triangles_submitted and balanced.tree_triangles_submitted < very.tree_triangles_submitted,
			"Tree detail rises with the profile at %s (%d/%d/%d)" % [shot, low.tree_triangles_submitted, balanced.tree_triangles_submitted, very.tree_triangles_submitted])
		_check(int(low.visible_by_level.get("impostor", 0)) >= int(very.visible_by_level.get("impostor", 0)), "Leicht uses impostors earlier at " + shot)
		_check(balanced.estimated_draw_calls < 160, "Ausgewogen vegetation draw calls bounded at %s (%d)" % [shot, balanced.estimated_draw_calls])
	_check(field.placed_trees == table.low.fields.placed_trees_shrubs_vines, "Every profile keeps the same placed plants")
	# Blade grass (D-060): none on Leicht, denser and farther with each profile.
	var blades := {}
	camera.global_position = Vector3(-12.0, 1.7, 50.0)
	camera.look_at(Vector3(-16.0, .5, 80.0), Vector3.UP)
	for profile: String in PROFILES:
		field.set_quality(profile)
		field.refresh(camera)
		blades[profile] = field.stats()
	_check(blades.low.grass_tufts_visible == 0, "Leicht draws no blade grass")
	_check(blades.balanced.grass_tufts_visible > 300, "Ausgewogen draws blade grass near the camera (%d)" % blades.balanced.grass_tufts_visible)
	_check(blades.balanced.grass_tufts_visible < blades.high.grass_tufts_visible and blades.high.grass_tufts_visible < blades.very_high.grass_tufts_visible,
		"Blade grass density rises with the profile (%d/%d/%d)" % [blades.balanced.grass_tufts_visible, blades.high.grass_tufts_visible, blades.very_high.grass_tufts_visible])
	_check(blades.balanced.grass_triangles_submitted < 120000, "Ausgewogen blade grass stays in budget (%d triangles)" % blades.balanced.grass_triangles_submitted)
	_check(blades.very_high.grass_triangles_submitted > blades.balanced.grass_triangles_submitted * 8, "Ultra blade grass is far denser (%d triangles)" % blades.very_high.grass_triangles_submitted)
	summary["grass"] = {}
	for profile: String in PROFILES:
		summary.grass[profile] = {"tufts": blades[profile].grass_tufts_visible, "triangles": blades[profile].grass_triangles_submitted, "cells": blades[profile].grass_cells_visible}
	summary["profiles"] = table
	# Shadow and wind settings differ per profile.
	field.set_quality("low")
	field.refresh(camera)
	var shadows_low := 0
	for batch in field.get_children():
		if batch is MultiMeshInstance3D and batch.visible and batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadows_low += 1
	_check(shadows_low == 0, "Leicht draws vegetation without shadow casting")
	var leaf: ShaderMaterial = Library.asset("quercus_robur").lods[0].surface_get_material(1)
	_check(int(leaf.get_shader_parameter("wind_detail")) == 0, "Leicht keeps only trunk sway")
	field.set_quality("balanced")
	_check(int(leaf.get_shader_parameter("wind_detail")) == 2, "Ausgewogen has trunk, branch and leaf wind")
	field.apply_season(3)
	_check(float(leaf.get_shader_parameter("leaf_presence")) < .3, "Winter thins the deciduous crowns")
	field.apply_season(1)
	view.free()


func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	values.sort()
	return float(values[values.size() / 2])
