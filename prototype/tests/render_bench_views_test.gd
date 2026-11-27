extends SceneTree
## Runs the Android graphics probe in its "views" mode against the real game
## (main.tscn) on this machine: the same driver a Fold7 debug installation
## uses to measure the renderer-comparison views in all four profiles. It
## checks the protocol and that profile switches reach the rendered scene; any
## timing it records belongs to the local renderer and proves nothing about a
## device.

const Bench = preload("res://scripts/rendering/render_bench.gd")
const Probe = preload("res://scripts/ui/android_graphics_probe.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		push_error("The bench probe test needs an isolated test account")
		quit(2)
		return
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://graphics-frames.jsonl"))
	var flag := FileAccess.open("user://graphics-probe.txt", FileAccess.WRITE)
	flag.store_string("views 1 2\n")
	flag.close()
	var game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var probe = Probe.new()
	root.add_child(probe)
	var rows := []
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 90000:
		await process_frame
		if not FileAccess.file_exists("user://graphics-frames.jsonl"):
			continue
		rows = []
		for line in FileAccess.get_file_as_string("user://graphics-frames.jsonl").split("\n", false):
			rows.append(JSON.parse_string(line))
		if not rows.is_empty() and rows[-1].event in ["done", "error"]:
			break
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://graphics-probe.txt"))
	_check(not rows.is_empty() and rows[-1].event == "done", "Probe views mode finished: " + (str(rows[-1]) if not rows.is_empty() else "no rows"))
	var views := rows.filter(func(row) -> bool: return row.event == "view")
	_check(views.size() == Probe.PROFILES.size() * Bench.VILLAGE_VIEWS.size(), "Every profile renders every bench view (%d rows)" % views.size())
	var start: Array = rows.filter(func(row) -> bool: return row.event == "views_start")
	_check(start.size() == 1 and int(start[0].settle_frames) == 1 and int(start[0].measure_frames) == 2, "Flag file sets the sample length")
	var atlas := {}
	for row in views:
		var engine: Dictionary = row.metrics.engine
		_check(engine.profile == row.quality, "%s/%s rendered with the requested profile" % [row.quality, row.view])
		_check(int(row.metrics.frames) == 2, "Measured frame count recorded")
		atlas[row.quality] = int(engine.viewport.positional_shadow_atlas_size)
		if row.view in ["night_torch", "village_lane", "village_overview"]:
			# Both lane shots see the same authored hearth at the 13 m
			# Very High light radius. Other views here are beyond its range.
			var sources: Array = engine.lights.scene_omni_paths
			var weaver_hearth: bool = row.quality == "very_high" and row.view != "village_overview"
			var expected_scene := 1 if weaver_hearth else 0
			if row.view == "night_torch":
				# This fixed lane shot uses the production night lighting, not
				# just the six synthetic benchmark torches. Independent exact
				# identities guard the authored 1/3/5/7 door and 1/2/3/4 route
				# budgets, including the nearest pool slots; no unknown light
				# may be silently counted as an authored source.
				var door_ids: Dictionary = {
					"low": [0], "balanced": [0, 12, 13],
					"high": [0, 1, 12, 13, 14],
					"very_high": [0, 1, 2, 11, 12, 13, 14]}
				var route_counts: Dictionary = {"low": 1, "balanced": 2, "high": 3, "very_high": 4}
				var expected_doors: Array[String] = []
				for id: int in door_ids[row.quality]:
					expected_doors.append("VillageLook/DoorTorchLight%d" % id)
				var expected_route: Array[String] = []
				for id in int(route_counts[row.quality]):
					expected_route.append("VillageLook/ValdoraRouteFires/NearbyBrazierLight%d" % id)
				var actual_doors: Array[String] = []
				var actual_route: Array[String] = []
				var hearths := 0
				var unexpected: Array[String] = []
				for raw in sources:
					var path := str(raw)
					if path.begins_with("VillageLook/DoorTorchLight"):
						actual_doors.append(path)
					elif path.begins_with("VillageLook/ValdoraRouteFires/NearbyBrazierLight"):
						actual_route.append(path)
					elif path.ends_with("/south_weaver_home/Interior/HearthGlow"):
						hearths += 1
					else:
						unexpected.append(path)
				actual_doors.sort()
				expected_doors.sort()
				actual_route.sort()
				expected_route.sort()
				_check(actual_doors == expected_doors, "%s/night exact door identities: %s" % [row.quality, actual_doors])
				_check(actual_route == expected_route, "%s/night exact route pool identities: %s" % [row.quality, actual_route])
				expected_scene += expected_doors.size() + expected_route.size()
				_check(sources.size() == expected_scene and hearths == (1 if weaver_hearth else 0) and unexpected.is_empty(),
					"%s/night exact authored inventory (hearths=%d, unknown=%s): %s" % [row.quality, hearths, unexpected, sources])
			else:
				# Daylight views retain the original strict inventory and also
				# reject any leaked night-only door or route light.
				_check(sources.size() == expected_scene and (not weaver_hearth or
					str(sources[0]).ends_with("/south_weaver_home/Interior/HearthGlow")),
					"%s/%s has the expected authored lights: %s" % [row.quality, row.view, sources])
			var expected_torches := Bench.TORCH_OFFSETS.size() if row.view == "night_torch" else 0
			_check(int(engine.lights.harness_omni) == expected_torches, "Exact harness torch count for " + str(row.view))
			_check(int(engine.lights.omni) == expected_scene + expected_torches, "Every visible omni light is accounted for")
			var shadowed := 0 if row.quality == "low" else expected_torches
			_check(int(engine.lights.harness_shadowed) == shadowed and
				int(engine.lights.shadowed) == shadowed + int(bool(engine.sun.get("shadow", false))),
				"%s/%s exact torch and scene shadow counts" % [row.quality, row.view])
	_check(atlas == {"low": 0, "balanced": 2048, "high": 4096, "very_high": 8192}, "Torch shadow atlas per profile: " + str(atlas))
	_check(game.world.get_node_or_null(Bench.TORCH_NODE) == null, "Harness torches are removed afterwards")
	_check(game.world.is_physics_processing() and game.is_processing() and is_equal_approx(Engine.time_scale, 1.0), "Simulation is resumed afterwards")
	probe.queue_free()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("RENDER_BENCH_VIEWS_PASS checks=%d; protocol only, local timings are not device data" % checks)
	else:
		print("RENDER_BENCH_VIEWS_FAIL checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
