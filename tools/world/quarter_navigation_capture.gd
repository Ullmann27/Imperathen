extends SceneTree
## Replays two street graphs against one frozen instance of the authored city.
## Arguments after --: old graph JSON, output directory, base SHA, current SHA.

const City = preload("res://scripts/world/city_exploration.gd")
const Streets = preload("res://scripts/domain/city_streets.gd")
const BOUNDS := Rect2(13, -36, 33, 52)
const EYE := Vector3(42, 58, 23)
const FOCUS := Vector3(28, 0, -10)
var output: String
var failure := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 4 or DisplayServer.get_name() == "headless":
		printerr("Use a graphical renderer. Pass old_graph.json output_dir base_sha current_sha.")
		quit(2)
		return
	output = args[1]
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(2)
		return
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1120, 840)
	var city := City.new()
	city.persist = false
	city.profile = "very_high"
	root.add_child(city)
	if not city.city_available or not is_instance_valid(city.quarter):
		printerr("Missing installed quarter")
		quit(2)
		return
	city.set_process(false)
	city.set_physics_process(false)
	for i in 3:
		await physics_frame
	var graphs := []
	for path: String in [args[0], Streets.PATH]:
		var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not payload is Dictionary or payload.get("format") != Streets.FORMAT:
			printerr("Missing graph: ", path)
			quit(2)
			return
		var view := _graph_view(payload, city.get_world_3d().direct_space_state)
		view.sha256 = FileAccess.get_sha256(path)
		graphs.append(view)
		city.add_child(view.overlay)
		view.overlay.hide()
	for child: Node in city.get_children():
		if child is CanvasLayer:
			child.hide()
	city.figure.hide()
	city.process_mode = Node.PROCESS_MODE_DISABLED
	city.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	city.camera.size = 54.0
	city.camera.position = EYE
	city.camera.look_at(FOCUS)
	await _save_view("00-Stadt-ohne-Diagnose")
	for i in 2:
		var overlay: MeshInstance3D = graphs[i].overlay
		overlay.show()
		await _save_view(["01-Wege-vorher", "02-Wege-nachher"][i])
		overlay.hide()
		graphs[i].erase("overlay")
	city.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	city.camera.fov = 64.0
	city.camera.position = Vector3(27.0, 1.75, -10.0)
	city.camera.look_at(Vector3(34, 1.5, -27.0))
	await _save_view("03-Gasse-auf-Augenhoehe")
	var evidence := {"git_basis": args[2], "git_stand": args[3], "godot": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(), "gpu": RenderingServer.get_video_adapter_name(),
		"profil": city.profile, "jdn": city.world_jdn, "viewport": [root.size.x, root.size.y],
		"kamera": [EYE.x, EYE.y, EYE.z], "blickziel": [FOCUS.x, FOCUS.y, FOCUS.z], "orthografische_groesse_m": 54.0,
		"pruefung": "Kanten mit mindestens einem Endpunkt im Quartier. Orange = beidseitig geprüfter vertikaler Körperquerschnitt trifft Geometrie. Türkis = Strahlen frei.",
		"graphen": graphs}
	if graphs[1].kanten == 0 or graphs[1].blockierte_kanten > 0:
		failure = true
	var file := FileAccess.open(output.path_join("Navigationsvergleich.json"), FileAccess.WRITE)
	if file == null:
		failure = true
	else:
		file.store_string(JSON.stringify(evidence, "  ") + "\n")
		file.close()
	print("QUARTER_NAVIGATION_CAPTURE ", JSON.stringify(graphs))
	city.free()
	await process_frame
	quit(1 if failure else 0)

func _save_view(name: String) -> void:
	for frame in 3:
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output.path_join(name + ".png")) != OK:
		failure = true

func _graph_view(graph: Dictionary, space: PhysicsDirectSpaceState3D) -> Dictionary:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blocked := 0
	var count := 0
	for edge: Array in graph.edges:
		var p: Array = graph.nodes[int(edge[0])]
		var q: Array = graph.nodes[int(edge[1])]
		var a := Vector3(p[0], p[1], p[2])
		var b := Vector3(q[0], q[1], q[2])
		if not BOUNDS.has_point(Vector2(a.x, a.z)) and not BOUNDS.has_point(Vector2(b.x, b.z)):
			continue
		count += 1
		var side := (b-a).cross(Vector3.UP).normalized()
		var obstructed := _obstructed(space, a, b, side)
		if obstructed:
			blocked += 1
		surface.set_color(Color("ff5228") if obstructed else Color("24cab8"))
		a.y += 0.18
		b.y += 0.18
		side *= 0.085 if obstructed else 0.035
		for vertex: Vector3 in [a-side, a+side, b+side, a-side, b+side, b-side]:
			surface.add_vertex(vertex)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	material.render_priority = 10
	var overlay := MeshInstance3D.new()
	overlay.mesh = surface.commit()
	overlay.material_override = material
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return {"kanten": count, "blockierte_kanten": blocked, "overlay": overlay}

func _obstructed(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, side: Vector3) -> bool:
	for height: float in [0.45, 1.0, 1.6]:
		for offset: float in [-0.30, 0.0, 0.30]:
			var displacement := Vector3.UP * height + side * offset
			var query := PhysicsRayQueryParameters3D.create(a + displacement, b + displacement, 1)
			query.hit_back_faces = true
			query.hit_from_inside = true
			if not space.intersect_ray(query).is_empty():
				return true
			query.from = b + displacement
			query.to = a + displacement
			if not space.intersect_ray(query).is_empty():
				return true
	return false
