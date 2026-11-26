extends SceneTree
## Runs the Android graphics probe in its "views" mode against the real game
## (main.tscn) on this machine: the same driver a Fold7 debug installation
## uses to measure the renderer-comparison views in all four profiles. It
## checks the protocol and that profile switches reach the rendered scene; any
## timing it records belongs to the local renderer and proves nothing about a
## device.

const Bench = preload("res://scripts/rendering/render_bench.gd")
const Probe = preload("res://scripts/ui/android_graphics_probe.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const Profiles = preload("res://assets/quality_profiles.json")
const LookValues = preload("res://assets/village/look/look_values.json")
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
			# The updated village has real authored sconces as well as the room
			# hearth. Independently derive the expected nearest light identities
			# from the actual fixed camera and the authoring coordinates.
			var sources: Array = engine.lights.scene_omni_paths
			var eye := Vector3(float(engine.camera.position[0]), float(engine.camera.position[1]), float(engine.camera.position[2]))
			var authored := _expected_managed_fires(eye, String(row.quality), row.view == "night_torch")
			var actual: Array = []
			var room_sources: Array = []
			for source: String in sources:
				if source.begins_with("VillageLook/"):
					actual.append(source)
				else:
					room_sources.append(source)
			actual.sort()
			authored.sort()
			_check(actual == authored, "%s/%s has the exact nearest authored fire lights: %s expected %s" % [row.quality, row.view, actual, authored])
			var weaver_hearth: bool = row.quality == "very_high" and row.view != "village_overview"
			var room_count := 1 if weaver_hearth else 0
			_check(room_sources.size() == room_count and (not weaver_hearth or
				str(room_sources[0]).ends_with("/south_weaver_home/Interior/HearthGlow")),
				"%s/%s has the exact authored room light: %s" % [row.quality, row.view, room_sources])
			var expected_scene := authored.size() + room_count
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


## This calculation uses authoring data and the sampled camera, never the
## look node's visible flags or internal ranking. The scene light budget stays
## separate from the explicitly synthetic stress-test torches.
func _expected_managed_fires(eye: Vector3, profile: String, night: bool) -> Array:
	var data: Dictionary = LookValues.data.village_fires
	var ranked: Array = []
	var forge := Vector3(float(data.forge.at[0]), float(data.forge.at[1]), float(data.forge.at[2]))
	_add_expected_fire(ranked, eye, forge, 1.0 if night else float(data.forge.day_share), "VillageLook/ForgeHearthLight")
	var index := 0
	var local := Vector3(float(data.sconce_local[0]), float(data.sconce_local[1]), float(data.sconce_local[2]))
	var offset := Vector3(float(data.sconce_light_offset[0]), float(data.sconce_light_offset[1]), float(data.sconce_light_offset[2]))
	for home: Dictionary in Layout.HOMES:
		if home.id not in data.sconce_homes:
			continue
		var yaw := float(home.yaw)
		var at: Vector3 = home.at + (local + offset + Vector3(0, .1, .12)).rotated(Vector3.UP, yaw)
		_add_expected_fire(ranked, eye, at, 1.0 if night else 0.0, "VillageLook/DoorTorchLight%d" % index)
		index += 1
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var limit := int(Profiles.data.profiles[profile].look.fire_lights)
	var result: Array = []
	for row: Array in ranked.slice(0, limit):
		result.append(row[1])
	return result


func _add_expected_fire(ranked: Array, eye: Vector3, at: Vector3, power: float, path: String) -> void:
	var data: Dictionary = LookValues.data.village_fires
	var distance := eye.distance_to(at)
	if power * (1.0 - smoothstep(float(data.fade_start), float(data.fade_end), distance)) > .01:
		ranked.append([distance, path])
