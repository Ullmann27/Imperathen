extends SceneTree
## Actual New Life scene, including streamed regional terrain and five real
## authored cuts. Projection is a diagnostic only, never visual acceptance.
const Entry = preload("res://main.tscn")
const Terrain = preload("res://scripts/world/regional_terrain.gd")
const Plan = preload("res://scripts/world/world_stream_plan.gd")
const Vexillum = preload("res://scripts/cinematic/i00_vexillum.gd")
const SHOTS := ["aquileia_detail", "legions_rain", "caesar_orders", "labienus_orders", "legions_depart"]

var size := Vector2i(1280,720)
var out := ""
var game
var failures: Array[String] = []
var coverage_failures: Array[String] = []
var samples: Array[Dictionary] = []
var checks := 0

func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1" or DisplayServer.get_name() == "headless":
		printerr("I00 capture requires isolated state and a real display")
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			out = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				size = Vector2i(int(parts[0]), int(parts[1]))
	if out.is_empty() or size.x < 320 or size.y < 320:
		quit(2)
		return
	_run.call_deferred()

func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("I00_TERRAIN_CAPTURE_FAIL: " + label)
	return ok

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _projected_ranks(stage: Node3D, camera: Camera3D) -> Array[int]:
	var counts: Array[int] = [0,0,0]
	for figure: Node3D in stage._foreground:
		var block := floori(float(figure.get_meta("i00_slot")) / 18.0)
		if camera.is_position_in_frustum(figure.global_position + Vector3.UP * 0.1):
			counts[block] += 1
	var bodies: MultiMeshInstance3D = stage._legions._batches.spear
	for i in range(bodies.multimesh.visible_instance_count):
		var block := floori(float(i) / 15.0)
		var point := bodies.to_global(bodies.multimesh.get_instance_transform(i).origin + Vector3.UP)
		if camera.is_position_in_frustum(point):
			counts[block] += 1
	return counts

func _capture(name: String) -> String:
	RenderingServer.render_loop_enabled = true
	await _frames(3)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	RenderingServer.render_loop_enabled = false
	if not _check(image != null and not image.is_empty(), "Real framebuffer " + name):
		return ""
	_check(image.get_size() == size, "Full-size framebuffer " + name)
	var filename := "%dx%d-%s.png" % [size.x,size.y,name]
	if not _check(image.save_png(out.path_join(filename)) == OK, "Save " + filename):
		return ""
	return filename

func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = size
	DirAccess.make_dir_recursive_absolute(out)
	var original_loop := RenderingServer.render_loop_enabled
	game = Entry.instantiate()
	root.add_child(game)
	await _frames(3)
	game.set_process(false)
	game.set_physics_process(false)
	game.ui._finish_intro()
	game.ui.action_requested.emit("new_game", {})
	await _frames(3)
	if not _check(game.screen == "opening" and game.opening_sequence.id == "i00_aquileia", "Production New Life opens I00"):
		game.queue_free()
		quit(1)
		return
	game.world.set_quality("high")
	var director: Node3D = game.opening_director
	director.reduced_motion = false
	var stage := director.get_node_or_null("I00AquileiaStage") as Node3D
	if not _check(is_instance_valid(stage), "Actual historical stage exists"):
		game.queue_free()
		quit(1)
		return
	RenderingServer.render_loop_enabled = false
	var sector := Plan.sector_id(Plan.sector_for_position(stage.global_position))
	var path := "Terrain_" + sector.replace(":", "_") + "/Ground"
	for i in range(120):
		if game.world.regional_terrain.get_node_or_null(path) != null:
			break
		await process_frame
	_check(game.world.regional_terrain.get_node_or_null(path) is MeshInstance3D, "Actual terrain mesh below the stage is loaded")
	_check(stage._foreground.size() == 9, "Actual nine near soldier rigs")
	var wide_coverage := {}
	for shot: String in SHOTS:
		var beat: Dictionary = game.opening_sequence.beats[game.opening_index]
		if not _check(str(beat.shot_id) == shot, "Real production beat " + shot):
			break
		var all_three := false
		for fraction: float in [0.0,0.5,1.0]:
			director.reduced_motion = false
			director.sample(shot,fraction,float(beat.duration)*fraction)
			var camera: Camera3D = director.camera
			var at := camera.global_position
			var clearance := at.y - Terrain.surface_height(Vector2(at.x,at.z))
			_check(clearance > camera.near, "Camera above streamed terrain: " + shot + " " + str(fraction))
			var ranks := _projected_ranks(stage,camera)
			var subject_in_frame := true
			if shot in ["legions_rain","legions_depart"]:
				subject_in_frame = ranks[0] + ranks[1] + ranks[2] > 0
				all_three = all_three or (ranks[0] > 0 and ranks[1] > 0 and ranks[2] > 0)
			elif shot == "aquileia_detail":
				var banner: Node3D = stage._standards[0]
				subject_in_frame = camera.is_position_in_frustum(banner.to_global(Vector3(0,Vexillum.TOP - Vexillum.HEIGHT * 0.5,Vexillum.FRONT)))
			else:
				var commander: Node3D = stage.speaker("caesar" if shot == "caesar_orders" else "labienus")
				subject_in_frame = is_instance_valid(commander) and camera.is_position_in_frustum(commander.gaze_anchor())
			if not subject_in_frame:
				coverage_failures.append(shot + " fraction=" + str(fraction) + ": intended subject outside camera frustum")
			var filename: String = await _capture("%s-%02d" % [shot,roundi(fraction*100.0)])
			var record := {"shot":shot,"fraction":fraction,"camera_clearance_m":clearance,"projected_rank_centres":ranks,"subject_in_frustum":subject_in_frame,"file":filename}
			samples.append(record)
			print("I00_CAPTURE ", JSON.stringify(record))
		if shot in ["legions_rain","legions_depart"]:
			wide_coverage[shot] = all_three
			if not all_three:
				coverage_failures.append(shot + ": no sampled frame includes centres from all three legion blocks")
		game._opening_next()
		await _frames(2)
	RenderingServer.render_loop_enabled = original_loop
	_check(samples.size() == 15, "Every historical shot sampled at three points")
	var report := {"checks":checks,"failures":failures,"coverage_failures":coverage_failures,"samples":samples,"size":[size.x,size.y],"quality":game.world.get_quality_profile(),"renderer":RenderingServer.get_current_rendering_method(),"three_block_coverage":wide_coverage,"stage_y":stage.position.y,"status":"REVIEW_PENDING","note":"Real framebuffer plus point-frustum diagnostic; no occlusion, temporal quality or device acceptance."}
	var file := FileAccess.open(out.path_join("i00-report-%dx%d.json" % [size.x,size.y]),FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	else:
		_check(false,"Write report")
	print("I00_TERRAIN_CAPTURE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"coverage_failures":coverage_failures,"samples":samples.size()}))
	game.queue_free()
	await _frames(2)
	quit(0 if failures.is_empty() and coverage_failures.is_empty() else 1)
