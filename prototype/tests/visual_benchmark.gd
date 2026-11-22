extends SceneTree
## Run with a graphical Godot backend. The sole argument is an output directory.
var output := ""
var game
var scene
var report := {}
var sample_count := 55

func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1" or OS.get_cmdline_user_args().is_empty() or DisplayServer.get_name() == "headless":
		printerr("A graphical viewport and an output directory after -- are required.")
		quit(2)
		return
	output = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()

func _run() -> void:
	game = preload("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.ui._finish_intro()
	game.ui.action_requested.emit("valley_demo",{})
	scene = game.valley
	var display := root.get_node("RuntimeDisplay")
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid,true)
	report = {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(),"output_px":[root.size.x,root.size.y],
		"sample_frames":sample_count,"scene":"60 stationary soldiers, overview, simulation paused across profiles","profiles":{},"scope":"Linux graphical viewport. Whole-frame wall time includes frame limiter. Render CPU/GPU are viewport timestamps; on llvmpipe the GPU work is software."}
	var before := JSON.stringify(scene.model.snapshot())
	for profile in ["low","balanced","high"]:
		display.apply_quality(profile)
		scene.profile = profile
		scene.land.apply_quality(profile)
		scene._sync_units()
		for warmup in 12:
			await RenderingServer.frame_post_draw
		var wall := []
		var cpu := []
		var gpu := []
		var calls := []
		var memory := []
		var last := Time.get_ticks_usec()
		for i in sample_count:
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			wall.append((now-last)/1000.0)
			last = now
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
			calls.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
			if i%10 == 0:
				memory.append(display._resident_memory_kib()/1024.0)
		report.profiles[profile] = {"frame_ms":_quantiles(wall),"viewport_cpu_ms":_quantiles(cpu),
			"viewport_gpu_ms":_quantiles(gpu),"draw_calls":_quantiles(calls),"peak_sampled_rss_mib":memory.max(),
			"visible_soldiers_near_mid_far":[display._units.x,display._units.y,display._units.z],
			"same_simulation":before == JSON.stringify(scene.model.snapshot()),
			"submitted_trees":scene.land.grove.visible_tree_count,
			"render_scale":root.scaling_3d_scale}
		_capture("valley-"+profile)
	scene.focus = Vector2(-7,8)
	scene.distance = 9
	scene._place_camera()
	scene._sync_units()
	for i in 8: await RenderingServer.frame_post_draw
	_capture("valley-close")
	game._leave_valley()
	game.ui.origin_id = "han"
	game._open_atlas(true)
	for i in 8: await RenderingServer.frame_post_draw
	_capture("globe-han")
	game._leave_atlas()
	game.ui.origin_id = "italia"
	game._start_new_game()
	game._set_mode("city")
	game.world._city_focus = Vector3(-11,0,-9)
	game.world._city_zoom = 37
	game.world._camera_initialized = false
	for i in 8: await RenderingServer.frame_post_draw
	_capture("village-italia")
	var file := FileAccess.open(output.path_join("frames.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	file.close()
	game.free()
	await process_frame
	print("VISUAL_BENCHMARK_PASS")
	quit()

func _quantiles(samples: Array) -> Dictionary:
	samples.sort()
	return {"p50":samples[ceili(samples.size()*0.50)-1],"p95":samples[ceili(samples.size()*0.95)-1],"p99":samples[ceili(samples.size()*0.99)-1]}

func _capture(stem: String) -> void:
	root.get_texture().get_image().save_png(output.path_join(stem+".png"))
