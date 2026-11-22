extends SceneTree
## Capture a real marching company from the valley scene. Pass an empty external
## output directory after --; encode the numbered PNGs at 24 frames per second.
const Valley := preload("res://scripts/tactics/valley_scene.gd")

func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or DisplayServer.get_name() == "headless":
		quit(2)
		return
	var out := String(args[0])
	DirAccess.make_dir_recursive_absolute(out)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(768,432)
	var scene := Valley.new()
	root.add_child(scene)
	scene.set_process(false)
	scene.hud.visible = false
	scene.profile = "high"
	scene.land.apply_quality("high")
	scene.camera.fov = 51
	scene.model.order(["valley_guard"],"move",Vector2(-7,-8))
	scene.paused = false
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid,true)
	var cpu := []
	var gpu := []
	var calls := []
	for i in range(92):
		scene._process(1.0/24)
		var unit: Dictionary = scene.model.squads.valley_guard
		var center := Vector3(unit.x,scene.model.ground_height(unit.x,unit.z),unit.z)
		scene.camera.position = center + Vector3(-3.4,1.48,-4.2)
		scene.camera.look_at(center + Vector3(0,1.04,0))
		for flag in scene.standards.values():
			flag.hide()
		await RenderingServer.frame_post_draw
		if i >= 20:
			root.get_texture().get_image().save_png(out.path_join("march_%03d.png" % (i-20)))
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
			calls.append(root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
	cpu.sort()
	gpu.sort()
	calls.sort()
	print("GAIT_RENDER frames=%d viewport=768x432 median_cpu_ms=%.2f median_gpu_ms=%.2f median_draw_calls=%s adapter=%s" %
			[cpu.size(),cpu[35],gpu[35],calls[35],RenderingServer.get_video_adapter_name()])
	scene.free()
	quit()
