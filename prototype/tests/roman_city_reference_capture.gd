extends SceneTree
## Same-camera reference frames of the city base (main street, market row,
## forum, gates, kerbs, props) from the production CityExploration scene, for
## before/after comparison in every graphics profile.
##
## Every view has a fixed camera position and target in Godot metres, so two
## runs on different builds produce comparable frames. Real OpenGL framebuffer
## under Xvfb (CPU rasteriser): visual QA evidence, NOT a device screenshot and
## NOT a performance measurement of any phone.
##
##   IMPERATHEN_CITY_RENDER_PROFILE  low | balanced | high | very_high
##   IMPERATHEN_CITY_RENDER_OUTPUT   absolute output directory
##   IMPERATHEN_CITY_RENDER_LABEL    free text stored in the report (e.g. the source commit)
##   IMPERATHEN_CITY_RENDER_VIEWS    optional comma-separated subset of view names
const City = preload("res://scripts/world/city_exploration.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const Architecture = preload("res://scripts/rendering/city_architecture_detail.gd")
const PROFILES := ["low", "balanced", "high", "very_high"]
const SIZE := Vector2i(1280, 720)
# name: [camera position, look-at target, player position (sole height is found by the physics)]
const VIEWS := {
	"spawn":[Vector3(0.0, 3.0, 30.0), Vector3(0.0, 1.5, 0.0), Vector3(0.0, 0.0, 24.0)],
	"main_street_west":[Vector3(-250.0, 2.0, 65.0), Vector3(-150.0, 1.6, 65.0), Vector3(-243.0, 0.0, 63.5)],
	"main_street_centre":[Vector3(-60.0, 2.2, 66.5), Vector3(40.0, 1.5, 62.0), Vector3(-53.0, 0.0, 65.0)],
	"main_street_kerb":[Vector3(22.6, 1.2, 60.4), Vector3(19.6, 0.25, 57.2), Vector3(20.0, 0.0, 57.6)],
	"street_crossing":[Vector3(-86.0, 3.2, 80.0), Vector3(-100.0, 0.3, 61.0), Vector3(-96.0, 0.0, 66.0)],
	"market_row":[Vector3(-45.0, 2.4, 53.5), Vector3(10.0, 1.2, 48.0), Vector3(-36.0, 0.0, 51.5)],
	"market_counter":[Vector3(-21.6, 1.7, 51.6), Vector3(-24.8, 1.0, 47.4), Vector3(-24.8, 0.0, 48.6)],
	"forum_piazza":[Vector3(-60.0, 3.0, 35.0), Vector3(0.0, 2.0, -20.0), Vector3(-50.0, 0.0, 26.0)],
	"forum_portico_steps":[Vector3(-70.0, 1.3, -6.0), Vector3(-80.0, 1.0, -16.0), Vector3(-74.5, 0.0, -10.0)],
	"house_front_props":[Vector3(-2.6, 1.8, 76.2), Vector3(-6.4, 0.6, 81.6), Vector3(-3.6, 0.0, 78.6)],
	"west_gate":[Vector3(-362.0, 7.0, 65.0), Vector3(-410.0, 5.0, 65.0), Vector3(-372.0, 0.0, 65.0)],
	"east_gate":[Vector3(362.0, 7.0, 65.0), Vector3(410.0, 5.0, 65.0), Vector3(372.0, 0.0, 65.0)],
	"north_gate":[Vector3(-100.0, 7.0, -282.0), Vector3(-100.0, 5.0, -320.0), Vector3(-100.0, 0.0, -292.0)],
	"south_gate":[Vector3(-100.0, 7.0, 282.0), Vector3(-100.0, 5.0, 320.0), Vector3(-100.0, 0.0, 292.0)],
	"outer_house":[Vector3(-378.0, 4.5, 252.0), Vector3(-378.0, 1.5, 236.0), Vector3(-378.0, 0.0, 246.0)],
	"outer_street":[Vector3(-330.0, 3.2, -272.5), Vector3(-200.0, 1.5, -272.5), Vector3(-322.0, 0.0, -272.5)],
}
var failures: Array[String] = []
var frames: Array[Dictionary] = []


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("An actual OpenGL/Xvfb viewport is required; headless images are not valid.")
		quit(2)
		return
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("Use a disposable city profile for the reference capture.")
		quit(2)
		return
	_run.call_deferred()


func _sha256(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"


func _run() -> void:
	var profile := OS.get_environment("IMPERATHEN_CITY_RENDER_PROFILE")
	var folder := OS.get_environment("IMPERATHEN_CITY_RENDER_OUTPUT")
	if profile not in PROFILES or folder.is_empty():
		printerr("Explicit profile (low, balanced, high, very_high) and output path required.")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		printerr("Cannot create output directory.")
		quit(2)
		return
	var wanted := OS.get_environment("IMPERATHEN_CITY_RENDER_VIEWS")
	var names: Array = VIEWS.keys() if wanted.is_empty() else Array(wanted.split(",", false))
	root.size = SIZE
	root.content_scale_size = Vector2i.ZERO
	var scene := City.new()
	scene.persist = false
	scene.profile = profile
	root.add_child(scene)
	for i in 9:
		await process_frame
		await physics_frame
	if not scene.city_available:
		printerr("No original full city GLB, capture aborted.")
		quit(1)
		return
	scene._touch_move = Vector2.ZERO
	scene._running = false
	# A fixed camera with the production camera's lens and environment.
	var eye := Camera3D.new()
	eye.fov = scene.camera.fov
	eye.near = scene.camera.near
	eye.far = scene.camera.far
	eye.environment = scene.camera.environment
	eye.attributes = scene.camera.attributes
	scene.add_child(eye)
	var city := scene.get_node("RomanCity") as Node3D
	var drawn_meshes := city.find_children("*", "MeshInstance3D", true, false).size()
	for title: String in names:
		if not VIEWS.has(title):
			failures.append(title+": unknown view")
			continue
		var view: Array = VIEWS[title]
		var stand: Vector3 = view[2]
		# Put the player on the real floor of this build (physics, not a guess).
		var query := PhysicsRayQueryParameters3D.create(stand+Vector3.UP*3.0, stand+Vector3.DOWN*2.0, 1, [scene.player.get_rid()])
		var floor_hit := scene.get_world_3d().direct_space_state.intersect_ray(query)
		var floor_y := float(floor_hit.position.y) if not floor_hit.is_empty() else 0.0
		scene.teleport(Vector3(stand.x, floor_y+City.SOLE_OFFSET+0.02, stand.z))
		eye.global_position = view[0]
		eye.look_at(view[1], Vector3.UP)
		eye.current = true
		for i in 6:
			await physics_frame
			await RenderingServer.frame_post_draw
			eye.current = true
		var started := Time.get_ticks_usec()
		for i in 3:
			await RenderingServer.frame_post_draw
		var frame_ms := (Time.get_ticks_usec()-started)/3000.0
		var image := root.get_texture().get_image()
		if image == null or image.get_size() != SIZE:
			failures.append(title+": no complete framebuffer")
			continue
		var path := folder.path_join(profile+"_"+title+".png")
		if image.save_png(path) != OK:
			failures.append(title+": PNG save failed")
			continue
		var visible := 0
		for mesh: MeshInstance3D in city.find_children("*", "MeshInstance3D", true, false):
			var centre: Vector3 = (mesh.global_transform*mesh.get_aabb()).get_center()
			if mesh.visibility_range_end <= 0.0 or centre.distance_to(eye.global_position) <= mesh.visibility_range_end:
				visible += 1
		frames.append({"view":title, "file":path.get_file(), "camera_m":str(view[0]), "target_m":str(view[1]),
			"player_m":str(scene.player.global_position), "player_floor_m":snappedf(floor_y, 0.001),
			"draw_calls":int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)),
			"objects":int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)),
			"primitives":int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)),
			"city_meshes_within_range":visible,
			"cpu_rasteriser_frame_ms_not_device":snappedf(frame_ms, 0.1)})
	var report := {"status":"pass" if failures.is_empty() and frames.size() == names.size() else "fail",
		"label":OS.get_environment("IMPERATHEN_CITY_RENDER_LABEL"), "quality_profile":profile,
		"engine":Engine.get_version_info().string, "rendering_method":RenderingServer.get_current_rendering_method(),
		"video_adapter":RenderingServer.get_video_adapter_name(), "video_api":RenderingServer.get_video_adapter_api_version(),
		"resolution":str(SIZE), "physical_device":false,
		"city_glb_sha256":_sha256(City.CITY_PATH), "collision_glb_sha256":_sha256(City.CITY_COLLISION),
		"city_mesh_instances":drawn_meshes,
		"lighting":"production CityExploration sun and environment of this profile, unchanged",
		"player_model":scene.figure.get("model_path") if scene.figure.get("model_path") != null else "see IMPERATHEN_CITY_READY",
		"memory":{"texture_mib":snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)/1048576.0, 0.1),
			"mesh_buffer_mib":snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)/1048576.0, 0.1),
			"video_total_mib":snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)/1048576.0, 0.1),
			"process_static_mib":snappedf(Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0, 0.1)},
		"frames":frames, "failures":failures}
	var handle := FileAccess.open(folder.path_join(profile+"_report.json"), FileAccess.WRITE)
	if handle:
		handle.store_string(JSON.stringify(report, "\t"))
		handle.close()
	# Complete the scene and graphics-resource lifecycle while the rendering
	# server is still alive (same teardown as roman_city_visual_capture.gd).
	eye.environment = null
	eye.attributes = null
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.camera.environment = null
	for frame in 2:
		await process_frame
		await RenderingServer.frame_post_draw
	scene.queue_free()
	await process_frame
	await process_frame
	Person.scenes.clear()
	Person.materials.clear()
	Architecture._meshes.clear()
	for frame in 3:
		await process_frame
		await RenderingServer.frame_post_draw
	print("ROMAN_CITY_REFERENCE_RESULT "+JSON.stringify(report))
	print("ROMAN_CITY_REFERENCE_PASS" if report.status == "pass" else "ROMAN_CITY_REFERENCE_FAIL")
	quit(0 if report.status == "pass" else 1)
