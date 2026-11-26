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
