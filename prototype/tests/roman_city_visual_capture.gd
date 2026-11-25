extends SceneTree
## Produces genuine OpenGL framebuffer screenshots of the exact exported city.
## CPU Mesa/Xvfb images are visual QA references, NOT screenshots from Fold7.
const City = preload("res://scripts/world/city_exploration.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const Architecture = preload("res://scripts/rendering/city_architecture_detail.gd")
const SCENES := {
	"market":Vector3(-12.0,0.92,68.0),
	"forum":Vector3(-8.0,0.92,24.0),
	"masonry":Vector3(-120.0,0.92,65.0)
}
var failures: Array[String] = []
var screenshots: Array[Dictionary] = []


func _initialize() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("An actual OpenGL/Xvfb viewport is required; headless images are not valid.")
		quit(2)
		return
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST")!="1":
		printerr("Use a disposable city profile for the visual capture.")
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	var profile := OS.get_environment("IMPERATHEN_CITY_RENDER_PROFILE")
	var folder := OS.get_environment("IMPERATHEN_CITY_RENDER_OUTPUT")
	if profile not in ["high","very_high"] or folder.is_empty():
		printerr("Explicit high/very_high and output path required.")
		quit(2)
		return
	var made := DirAccess.make_dir_recursive_absolute(folder)
	if made!=OK:
		printerr("Cannot create screenshot output directory: "+str(made))
		quit(2)
		return
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i.ZERO
	var scene := City.new()
	scene.persist=false
	scene.profile=profile
	root.add_child(scene)
	for i in 9:
		await process_frame
		await physics_frame
	if not scene.city_available:
		printerr("No original full city GLB, framebuffer capture aborted.")
		quit(1)
		return
	scene.set_physics_process(false)
	scene._touch_move=Vector2.ZERO
	scene._running=false
	scene.camera.current=true
	for title: String in SCENES:
		scene.teleport(SCENES[title])
		scene._yaw=0.0
		scene._pitch=-0.18
		scene._distance=4.2
		scene._place_camera(0.2)
		for i in 9:
			await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		if image==null or image.get_width()!=1280 or image.get_height()!=720:
			failures.append(title+": no complete actual 1280x720 screen capture")
			continue
		# A uniform black dummy image must never be called a real city.
		var min_luma:=1.0
		var max_luma:=0.0
		for y in range(36,685,65):
			for x in range(48,1225,92):
				var sample:=image.get_pixel(x,y)
				var luma:=.2126*sample.r+.7152*sample.g+.0722*sample.b
				min_luma=minf(min_luma,luma)
				max_luma=maxf(max_luma,luma)
		if max_luma-min_luma<.08:
			failures.append(title+": framebuffer is uniform/empty")
			continue
		var path:=folder.path_join(profile+"_"+title+".png")
		if image.save_png(path)!=OK:
			failures.append(title+": PNG save failed")
			continue
		var file:=FileAccess.open(path,FileAccess.READ)
		var length:=file.get_length() if file!=null else 0
		if file!=null:
			file.close()
		if length<50000:
			failures.append(title+": PNG unexpectedly too small")
		screenshots.append({"scene":title,"file":path.get_file(),"bytes":length,
			"min_sampled_luma":min_luma,"max_sampled_luma":max_luma})
	# Complete the actual scene and graphics-resource lifecycle while the
	# rendering server is still alive. Never hide or reclassify GL errors.
	# This runner owns the only city instance and its scene caches.
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.camera.environment = null
	for frame in 2:
		await process_frame
		await RenderingServer.frame_post_draw
	var scene_ref := weakref(scene)
	scene.queue_free()
	await process_frame
	if scene_ref.get_ref() != null:
		await process_frame
	if scene_ref.get_ref() != null:
		failures.append("City node was not freed during graphical teardown")
	else:
		# Release strong references to imported resources held by static
		# caches before the graphics backend shuts down. Isolated runner only:
		# gameplay keeps the existing shared caches and streaming behavior.
		Person.scenes.clear()
		Person.materials.clear()
		Architecture._meshes.clear()
	for frame in 3:
		await process_frame
		await RenderingServer.frame_post_draw
	print("ROMAN_CITY_VISUAL_TEARDOWN "+JSON.stringify({"scene_freed":scene_ref.get_ref()==null,"render_frames_drained":5}))
	var output={"status":"pass" if failures.is_empty() and screenshots.size()==3 else "fail",
		"quality_profile":profile,"renderer":RenderingServer.get_current_rendering_method(),
		"real_rendered_frames":screenshots,
		"failures":failures,"physical_fold7":false,
		"source":"Godot 4.7.2 real GL Compatibility framebuffer using Xvfb, not an AI concept image",
		"visible_art_review":"required"}
	var report:=folder.path_join(profile+"_report.json")
	var handle:=FileAccess.open(report,FileAccess.WRITE)
	if handle:
		handle.store_string(JSON.stringify(output,"\t"))
		handle.close()
	print("ROMAN_CITY_VISUAL_RESULT "+JSON.stringify(output))
	print("ROMAN_CITY_VISUAL_PASS" if output.status=="pass" else "ROMAN_CITY_VISUAL_FAIL")
	quit(0 if output.status=="pass" else 1)
