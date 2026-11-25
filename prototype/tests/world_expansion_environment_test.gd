extends SceneTree
## Exercise pause, presentation clocks, actual node batching and scale limits.
## Synthetic meshes test topology; a staged manifest adds real GLB import checks.
const Controller = preload("res://scripts/world_expansion/environment_controller.gd")
const Layout = preload("res://scripts/world_expansion/settlement_layout.gd")
const Library = preload("res://scripts/world_expansion/asset_library.gd")
const View = preload("res://scripts/world_expansion/settlement_view.gd")
const Atlas = preload("res://scripts/world_expansion/atlas.gd")
const Preview = preload("res://scripts/world_expansion/preview.gd")
var checks := 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var completed_stages: Array[String] = []
const BUILDINGS := [
	{"id": "shop", "footprint": [8.2, 10.2], "height": 5.5, "category": "commerce"},
	{"id": "house", "footprint": [12.0, 12.0], "height": 11.5, "category": "residential"},
	{"id": "hall", "footprint": [14.0, 20.0], "height": 12.0, "category": "civic"}
]
const PLANTS := [{"id": "tree", "footprint": [9, 9], "height": 10, "category": "tree"}]
const ROADS := [{"id": "road", "footprint": [8, 8], "height": 0.16, "category": "road"}]


func _initialize() -> void:
	for script: GDScript in [Controller, Layout, Library, View, Atlas, Preview]:
		if not script.can_instantiate():
			print("WORLD_EXPANSION_TESTS ", JSON.stringify({"passed": false, "failures": ["Script cannot instantiate: " + script.resource_path]}))
			quit(1)
			return
	_run.call_deferred()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL ", label)


func _run() -> void:
	await _test_clock()
	var layouts := _test_layouts()
	_test_batches(layouts[4000])
	_test_atlas()
	_test_real_assets()
	# Give renderer-owned release commands a real frame before shutdown.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		evidence["post_release_render_frame"] = true
	else:
		evidence["post_release_render_frame"] = false
	_check(completed_stages == ["clock", "layout", "batches", "atlas", "assets"], "Every runtime test stage completed without an aborted function")
	evidence["passed"] = failures.is_empty()
	evidence["checks"] = checks
	evidence["failures"] = failures
	evidence["godot"] = Engine.get_version_info().string
	evidence["renderer"] = RenderingServer.get_current_rendering_method()
	evidence["visual_render_checked"] = false
	print("WORLD_EXPANSION_TESTS ", JSON.stringify(evidence))
	quit(0 if failures.is_empty() else 1)


func _test_clock() -> void:
	var clock := Controller.new()
	root.add_child(clock)
	clock.set_process(false)
	clock.set_time_of_day(12.0)
	var noon: Dictionary = clock.snapshot()
	clock.set_time_of_day(0.0)
	var night: Dictionary = clock.snapshot()
	_check(float(noon.sun_energy) > float(night.sun_energy) + 1.0 and is_zero_approx(night.sun_energy), "Midnight switches off direct sunlight")
	_check(float(night.moon_energy) > 0.05 and is_zero_approx(noon.moon_energy), "Moon and sun have separate day/night ranges")
	_check(clock.set_time_of_day(-1.0) and is_equal_approx(clock.time_of_day, 23.0), "Negative day time wraps to the previous evening")
	var before := clock.time_of_day
	_check(not clock.set_time_of_day(NAN) and clock.time_of_day == before, "Non-finite day time is rejected without corrupting light state")
	_check(not clock.set_cycle_duration(0) and clock.set_cycle_duration(120.0), "A finite positive presentation cycle is required")
	clock.set_time_of_day(23.0)
	clock.auto_cycle = true
	clock.advance_presentation(10.0)
	_check(is_equal_approx(clock.time_of_day, 1.0), "Advancing the clock crosses midnight correctly")
	var before_pause: Dictionary = clock.snapshot()
	clock.motion_paused = true
	clock.advance_presentation(30.0)
	_check(clock.snapshot() == before_pause.merged({"motion_paused": true}, true), "Pause freezes both day progress and wind phase")
	clock.motion_paused = false
	var material := ShaderMaterial.new()
	material.shader = Controller.WIND_SHADER
	clock.bind_material(material)
	clock.bind_material(material)
	clock.set_wind(2.5, Vector2(0, -3))
	clock.set_wind_time(7.5)
	_check(is_equal_approx(material.get_shader_parameter("wind_strength"), 2.0), "Material receives the bounded wind strength")
	_check(material.get_shader_parameter("wind_direction") == Vector2(0, -1), "Wind direction is normalized in world space")
	_check(material.get_shader_parameter("wind_time") == 7.5 and clock.snapshot().wind_material_count == 1, "Presentation phase is explicit and materials are bound once")
	var saved_direction: Vector2 = clock.wind_direction
	clock.set_wind(0, Vector2.ZERO)
	_check(clock.wind_direction == saved_direction and is_zero_approx(clock.wind_strength), "Zero wind stops motion without destroying the direction")
	_check(not clock.set_wind(NAN, Vector2.ONE) and not clock.set_wind(1, Vector2(INF, 1)), "Non-finite wind inputs are rejected")
	clock.set_quality("low")
	_check(clock.sun.directional_shadow_max_distance <= 24.0, "Low quality has a real limited shadow distance")
	clock.set_quality("very_high")
	_check(clock.sun.directional_shadow_max_distance == 110.0, "High-detail profile applies its shadow range")
	evidence["clock_noon"] = noon
	evidence["clock_night"] = night
	# GLES3 4.7.2 keeps newly dirtied skies on a render-update list.
	# A same-frame create/free test must first complete that real GPU update;
	# otherwise the later update can allocate radiance textures after sky release.
	var sky_watch: WeakRef = weakref(clock.environment.sky)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		evidence["clock_rendered_before_release"] = true
	else:
		evidence["clock_rendered_before_release"] = false
	root.remove_child(clock)
	clock.free()
	_check(not is_instance_valid(clock) and sky_watch.get_ref() == null, "Clock and its owned sky are released after the applicable initialization frame")
	completed_stages.append("clock")


func _test_layouts() -> Dictionary:
	var output := {}
	var reports: Array[Dictionary] = []
	for count in [48, 256, 1024, 4000]:
		var config := {"id": str(count), "count": count, "spacing": 26.0, "seed": 1926}
		var plan: Dictionary = Layout.generate(config, BUILDINGS, PLANTS, ROADS)
		_check(plan.ok and plan.buildings.size() == count, "Requested layout has exactly %d building placements" % count)
		var identifiers := {}
		var positions := {}
		var finite := true
		var separated := true
		for entry: Dictionary in plan.buildings:
			identifiers[entry.id] = true
			positions[entry.position] = true
			finite = finite and entry.position.is_finite()
			separated = separated and float(entry.footprint[0]) + 2.0 <= float(plan.spacing) and float(entry.footprint[1]) + 2.0 <= float(plan.spacing)
		_check(identifiers.size() == count and positions.size() == count and finite, "IDs and positions remain unique and finite at %d buildings" % count)
		_check(separated, "Building envelopes fit their parcels at %d buildings" % count)
		var repetition: Dictionary = Layout.generate(config, BUILDINGS, PLANTS, ROADS)
		_check(plan == repetition, "The same seed recreates exactly the same settlement at %d buildings" % count)
		_check(plan.vegetation.size() <= 1600 and not plan.roads.is_empty(), "Vegetation stays bounded and streets exist at %d buildings" % count)
		var road_positions := {}
		var road_lattice := true
		var road_origin: Vector3 = plan.roads[0].position
		for entry: Dictionary in plan.roads:
			road_positions[entry.position] = true
			var relative: Vector3 = (entry.position - road_origin) / 8.0
			road_lattice = road_lattice and is_equal_approx(relative.x, roundf(relative.x)) and is_equal_approx(relative.z, roundf(relative.z))
		_check(road_positions.size() == plan.roads.size(), "Road instances contain no duplicate transform at %d buildings" % count)
		_check(road_lattice, "All street and crossing tiles share one non-overlapping eight-metre lattice at %d buildings" % count)
		reports.append({"buildings": count, "roads": plan.roads.size(), "plants": plan.vegetation.size(),
			"width_m": plan.extent.x, "depth_m": plan.extent.y, "unique_building_modules": plan.unique_building_modules})
		output[count] = plan
	_check(not Layout.generate({"count": 0}, BUILDINGS, PLANTS).ok, "An empty settlement is rejected")
	_check(not Layout.generate({"count": 40000}, BUILDINGS, PLANTS).ok, "Unbounded placement requests are rejected")
	_check(not Layout.generate({"count": 4}, [], PLANTS).ok, "Missing structures cannot silently become primitives")
	var village: Dictionary = Layout.generate({"count": 48, "allowed_building_ids": ["shop"]}, BUILDINGS, PLANTS, ROADS)
	var only_small_buildings := true
	for building: Dictionary in village.buildings:
		only_small_buildings = only_small_buildings and building.asset == "shop"
	_check(village.building_count == 48 and village.unique_building_modules == 1 and only_small_buildings, "Village allowlist excludes multi-storey urban and civic modules")
	_check(not Layout.generate({"count": 4, "allowed_building_ids": ["unavailable"]}, BUILDINGS, PLANTS).ok, "Unknown asset restrictions cannot silently select another building")
	evidence["layouts"] = reports
	completed_stages.append("layout")
	return output


func _test_batches(plan: Dictionary) -> void:
	var library := Library.new()
	for definition: Dictionary in BUILDINGS + PLANTS + ROADS:
		var meshes: Array[Mesh] = []
		for detail in 3:
			var mesh := BoxMesh.new()
			mesh.size = Vector3(2.0 + float(detail) * 0.05, 4, 2)
			meshes.append(mesh)
		library.assets[definition.id] = {"definition": definition, "meshes": meshes, "triangles": [12, 12, 12],
			"wind": definition.id == "tree", "category": definition.category}
	var view := View.new()
	root.add_child(view)
	view.set_process(false)
	var built: Dictionary = view.populate(plan, library)
	_check(built.ok, "Actual spatial MultiMesh nodes can represent all 4000 synthetic building fixtures")
	var observed_buildings := 0
	var observed_instances := 0
	var bounded_chunks := true
	var bound_enclosures := true
	for batch: Dictionary in view.batches:
		var node: MultiMeshInstance3D = batch.node
		var multi: MultiMesh = node.multimesh
		if batch.kind == "buildings":
			observed_buildings += multi.instance_count
		observed_instances += multi.instance_count
		for index in multi.instance_count:
			var pose: Transform3D = multi.get_instance_transform(index) if DisplayServer.get_name() != "headless" else batch.local_poses[index]
			bounded_chunks = bounded_chunks and absf(pose.origin.x) <= View.CHUNK_METRES * 0.5 + 0.01 and absf(pose.origin.z) <= View.CHUNK_METRES * 0.5 + 0.01
			bound_enclosures = bound_enclosures and multi.custom_aabb.encloses(pose * library.assets[batch.asset].meshes[0].get_aabb())
	_check(observed_buildings == 4000, "Observed MultiMesh instance counts match the 4000 building records")
	_check(observed_instances == plan.buildings.size() + plan.roads.size() + plan.vegetation.size(), "Roads and vegetation are separate from the building total")
	_check(bounded_chunks and bound_enclosures, "Every submitted transform belongs to a bounded spatial batch with conservative bounds")
	view.set_quality("low")
	view.refresh_all(Vector3(0, 15, 0))
	var low: Dictionary = view.report()
	_check(low.distance_enabled_buildings > 0 and low.distance_enabled_buildings < 4000, "Low profile actually hides distant buildings")
	_check(low.distance_enabled_lod_instances[0] == 0, "Low profile never selects the near-detail meshes")
	view.set_quality("very_high")
	view.refresh_all(Vector3(0, 15, 0))
	var high: Dictionary = view.report()
	_check(high.distance_enabled_buildings > low.distance_enabled_buildings, "Higher profile changes real distance residency")
	_check(high.distance_enabled_lod_instances[0] < 4000, "The 4000-building layout is never all at near detail")
	view.refresh_all(Vector3(100000, 100, 100000))
	_check(view.report().distance_enabled_batches == 0, "Moving far away actually hides all batches")
	view.refresh_budgeted(Vector3.ZERO)
	_check(view.report().last_refresh_count <= View.BATCH_REFRESH_BUDGET, "One runtime update cannot exceed the batch refresh budget")
	view.set_overview(true, 5000)
	view.refresh_all(Vector3(0, 1000, 0))
	var overview_report: Dictionary = view.report()
	_check(overview_report.distance_enabled_buildings == 4000 and overview_report.distance_enabled_lod_instances[0] == 0 and overview_report.distance_enabled_lod_instances[1] == 0, "Overview displays all placements using far meshes only")
	_check(overview_report.batch_count == library.assets.size(), "Overview uses one far mesh batch per asset instead of thousands of street batches")
	var same_plan: Dictionary = view.layout
	_check(view.populate(same_plan, library).ok and same_plan.buildings.size() == 4000, "Repopulating the same layout never erases the caller-owned dictionary")
	var inactive_hidden := true
	for batch: Dictionary in view.batches:
		inactive_hidden = inactive_hidden and not batch.node.visible
	var actual_visible_children := 0
	for child: Node in view.get_children():
		if child is MultiMeshInstance3D and child.visible:
			actual_visible_children += 1
	_check(inactive_hidden and actual_visible_children == view.report().distance_enabled_batches, "All real child visibility agrees with the report after an overview replacement; no duplicate street meshes remain active")
	var broken: Dictionary = plan.duplicate(true)
	broken.buildings[0].asset = "missing_model"
	var before_count: int = view.batches.size()
	_check(not view.populate(broken, library).ok and view.batches.size() == before_count, "Invalid asset replacement leaves the existing view intact")
	evidence["multimesh_transform_readback"] = DisplayServer.get_name() != "headless"
	evidence["synthetic_batch_low"] = low
	evidence["synthetic_batch_high"] = high
	evidence["synthetic_batch_overview"] = overview_report
	view.clear()
	_check(view.batches.is_empty() and view.get_child_count() == 0, "Replacing/clearing a settlement frees its actual batch nodes")
	root.remove_child(view)
	view.free()
	completed_stages.append("batches")


func _test_atlas() -> void:
	var atlas := Atlas.new()
	atlas.size = Vector2(900, 650)
	atlas.configure({"regions": [
		{"id": "a", "position": [0, 0]}, {"id": "b", "position": [600, 400]}],
		"trade_routes": [{"id": "route", "from": "a", "to": "b", "waypoints": [[0, 0], [300, 400], [600, 400]]}]})
	var report: Dictionary = atlas.route_report()
	_check(report.region_count == 2 and report.route_count == 1 and is_equal_approx(report.routes[0].length_m, 800.0), "Atlas lengths follow the actual waypoint polyline")
	var a: Vector2 = atlas.map_point(Vector2(0, 0))
	var b: Vector2 = atlas.map_point(Vector2(600, 400))
	_check(Rect2(Vector2.ZERO, atlas.size).has_point(a) and Rect2(Vector2.ZERO, atlas.size).has_point(b) and a.distance_to(b) > 50, "Atlas projects distinct region coordinates into its visible bounds")
	atlas.free()
	completed_stages.append("atlas")


func _test_real_assets() -> void:
	const PATH := "res://assets/world_expansion/manifest.json"
	evidence["asset_import"] = {"checked": false, "reason": "No asset manifest in this isolated logic fixture."}
	if not FileAccess.file_exists(PATH):
		completed_stages.append("assets")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_check(parsed is Dictionary, "The actual asset manifest parses as a dictionary")
	if not parsed is Dictionary:
		return
	var manifest: Dictionary = parsed
	var library := Library.new()
	var loaded := library.load_manifest_assets(manifest)
	_check(loaded, "All actual authored GLBs import without primitive substitutions: " + "; ".join(library.errors))
	if not loaded:
		evidence["asset_import"] = {"checked": true, "passed": false, "errors": library.errors}
		return
	var imports: Array[Dictionary] = []
	for id: String in library.assets:
		var asset: Dictionary = library.assets[id]
		_check(asset.meshes.size() == 3 and asset.triangles[0] >= asset.triangles[1] and asset.triangles[1] >= asset.triangles[2] and asset.triangles[2] > 0, "Real model LODs are present and reduced: " + id)
		var bound: AABB = asset.meshes[0].get_aabb()
		var footprint: Array = asset.definition.footprint
		_check(bound.size.x <= float(footprint[0]) + 0.05 and bound.size.z <= float(footprint[1]) + 0.05, "Manifest envelope contains the actual imported model: " + id)
		if asset.wind:
			var wind_values_valid := true
			var anchored := false
			var flexible := false
			for mesh: Mesh in asset.meshes:
				for surface in mesh.get_surface_count():
					var arrays: Array = mesh.surface_get_arrays(surface)
					var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
					for color in colors:
						wind_values_valid = wind_values_valid and is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and color.r >= 0.0 and color.r <= 1.0 and color.g >= 0.0 and color.g <= 1.0 and color.b >= 0.0 and color.b <= 1.0
						anchored = anchored or (is_zero_approx(color.r) and is_zero_approx(color.g))
						flexible = flexible or color.r > 0.1
			_check(wind_values_valid and anchored and flexible, "Imported wind data contains valid roots and flexible parts: " + id)
		imports.append({"id": id, "triangles": asset.triangles, "surface_count_lod0": asset.meshes[0].get_surface_count(),
			"bounds_size": [bound.size.x, bound.size.y, bound.size.z], "wind": asset.wind})
	var basilica_receipt := {"checked": false, "passed": false}
	_check(library.assets.has("basilica"), "The actual asset set includes the basilica tangent-regeneration regression model")
	if library.assets.has("basilica"):
		basilica_receipt = _test_basilica_tangents(library.assets["basilica"].meshes[0])
	evidence["asset_import"] = {"checked": true, "passed": loaded and basilica_receipt.passed,
		"asset_count": library.assets.size(), "models": imports, "wind_material_count": library.wind_materials.size(),
		"basilica_lod0_tangents": basilica_receipt}

	completed_stages.append("assets")


func _test_basilica_tangents(mesh: Mesh) -> Dictionary:
	# This GLB omits its derivable TANGENT payload for transport. Inspect the
	# real imported arrays and materials used by MultiMesh, not source metadata.
	var surfaces: Array[Dictionary] = []
	var passed := mesh.get_surface_count() == 7
	_check(passed, "Basilica LOD0 retains all seven imported material surfaces")
	for surface in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
		var complete := not vertices.is_empty() and normals.size() == vertices.size() and tangents.size() == vertices.size() * 4
		var finite := complete
		var non_degenerate := complete
		var min_tangent_length_squared := INF
		var min_frame_cross_squared := INF
		if complete:
			for index in vertices.size():
				var offset := index * 4
				var tangent := Vector3(tangents[offset], tangents[offset + 1], tangents[offset + 2])
				var handedness := tangents[offset + 3]
				var normal := normals[index]
				if not tangent.is_finite() or not normal.is_finite() or not is_finite(handedness):
					finite = false
					non_degenerate = false
					continue
				var length_squared := tangent.length_squared()
				var cross_squared := normal.cross(tangent).length_squared()
				min_tangent_length_squared = minf(min_tangent_length_squared, length_squared)
				min_frame_cross_squared = minf(min_frame_cross_squared, cross_squared)
				non_degenerate = non_degenerate and length_squared > 0.00000001 and cross_squared > 0.00000001 and absf(absf(handedness) - 1.0) < 0.0001
		var material := mesh.surface_get_material(surface) as BaseMaterial3D
		var normal_bound := material != null and material.normal_enabled and material.normal_texture != null
		var texture_size := Vector2.ZERO
		if normal_bound:
			texture_size = material.normal_texture.get_size()
			normal_bound = texture_size.x > 0 and texture_size.y > 0 and is_finite(material.normal_scale) and material.normal_scale > 0
		var label := "Basilica LOD0 surface %d" % surface
		_check(complete, label + " has one complete tangent frame per imported vertex")
		_check(finite and non_degenerate, label + " has finite nonzero tangents, a usable normal/tangent basis and valid handedness")
		_check(normal_bound, label + " retains an enabled, bound normal map")
		passed = passed and complete and finite and non_degenerate and normal_bound
		surfaces.append({"surface": surface, "material": material.resource_name if material != null else "",
			"vertex_count": vertices.size(), "tangent_float_count": tangents.size(), "complete": complete,
			"finite": finite, "non_degenerate": non_degenerate, "normal_map_bound": normal_bound,
			"normal_texture_size": [texture_size.x, texture_size.y],
			"min_tangent_length_squared": min_tangent_length_squared if is_finite(min_tangent_length_squared) else null,
			"min_frame_cross_squared": min_frame_cross_squared if is_finite(min_frame_cross_squared) else null})
	return {"checked": true, "passed": passed, "lod": 0, "surface_count": mesh.get_surface_count(), "surfaces": surfaces}
