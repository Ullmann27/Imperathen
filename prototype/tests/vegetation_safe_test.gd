extends SceneTree
## Reproduces the Android-safe code path on both the headless scene and a real
## Compatibility framebuffer. Isolated projection tests check actual pixels
## against the independently projected bounds of separated imported plants.
## Full-game images are fixture views, not a physical-device approval.
const Safe := preload("res://scripts/vegetation/vegetation_safe.gd")
const Library := preload("res://scripts/vegetation/vegetation_library.gd")
const Entry := preload("res://main.tscn")
const I01 := preload("res://scripts/story/i01_three_cups.gd")
var checks := 0
var failures: Array[String] = []
var output := ""
var samples: Array[Dictionary] = []
var game
var graphical := false

func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("VEGETATION_SAFE_REQUIRES_ISOLATED_TEST")
		quit(2)
		return
	OS.set_environment("IMPERATHEN_VEGETATION_SAFE","1")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			output = arg.trim_prefix("--capture-dir=")
	graphical = not output.is_empty()
	if graphical and DisplayServer.get_name() == "headless":
		printerr("VEGETATION_SAFE_REQUIRES_REAL_FRAMEBUFFER")
		quit(2)
		return
	if graphical:
		DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("VEGETATION_SAFE_FAIL: "+label)


func _record(t: Transform3D, custom: Color) -> PackedFloat32Array:
	var b := t.basis
	return PackedFloat32Array([b.x.x,b.y.x,b.z.x,t.origin.x,b.x.y,b.y.y,b.z.y,t.origin.y,
		b.x.z,b.y.z,b.z.z,t.origin.z,custom.r,custom.g,custom.b,custom.a])


func _check_transforms() -> void:
	var t := Transform3D(Basis(Vector3.UP,.61).scaled(Vector3(.8,.47,.8)),Vector3(119.0,2.1,-84.0))
	var record := _record(t,Color(.125,1,.6,.2))
	var decoded := Safe.transforms(record,1)
	_check(decoded.size() == 1 and decoded[0].is_equal_approx(t),"Row-major instance transforms recover the correct rotated, translated plant")
	var corrupt := record.duplicate()
	corrupt[3] = NAN
	_check(Safe.transforms(corrupt,1).is_empty(),"Nonfinite position is rejected")
	corrupt = record.duplicate()
	corrupt[0] = 99.0
	_check(Safe.transforms(corrupt,1).is_empty(),"Excessive stretch is rejected")
	_check(Safe.transforms(record,2).is_empty(),"Truncated instance record is rejected")
	_check(not Safe.valid_transform(Transform3D(Basis.IDENTITY.scaled(Vector3(1,0,1)),Vector3.ZERO)),"Zero-scale geometry is rejected")
	_check(not Safe.valid_transform(Transform3D(Basis.IDENTITY,Vector3(100000,0,0))),"Out-of-world translation is rejected")


func _bounds_rect(camera: Camera3D, box: AABB, t: Transform3D) -> Rect2:
	var lo := Vector2(INF,INF)
	var hi := Vector2(-INF,-INF)
	for i in 8:
		var p := box.position + Vector3(box.size.x if i&1 else 0.0,box.size.y if i&2 else 0.0,box.size.z if i&4 else 0.0)
		var at := camera.unproject_position(t*p)
		lo = lo.min(at)
		hi = hi.max(at)
	return Rect2(lo,hi-lo).grow(4.0)


func _frame(view: Viewport) -> Image:
	for i in 3:
		await process_frame
		RenderingServer.force_draw(true,1.0/60.0)
	return view.get_texture().get_image()


func _projection(label: String, mesh: Mesh, scale: float, card := false, cpu_grass := false) -> void:
	if mesh == null:
		_check(false,label+" imported geometry missing")
		return
	var view := SubViewport.new()
	view.size = Vector2i(640,480)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.7,.05,.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 1.0
	view.add_child(env)
	var camera := Camera3D.new()
	view.add_child(camera)
	var centre := Vector3(123.0,1.0,-83.0)
	camera.position = centre + Vector3(0,2.1,10.0)
	camera.look_at(centre+Vector3(0,.65,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.0
	camera.current = true
	var blank: Image = await _frame(view)
	var transforms: Array[Transform3D] = [
		Transform3D(Basis(Vector3.UP,.41).scaled(Vector3.ONE*scale),centre+Vector3(-3,0,0)),
		Transform3D(Basis(Vector3.UP,-.57).scaled(Vector3.ONE*scale),centre+Vector3(3,0,0))]
	var data := _record(transforms[0],Color(0,1,.3,.1))
	data.append_array(_record(transforms[1],Color(0,1,.7,.2)))
	var rectangles: Array[Rect2] = []
	for t in transforms:
		rectangles.append(_bounds_rect(camera,mesh.get_aabb(),t))
	if card or cpu_grass:
		var instance := MeshInstance3D.new()
		instance.mesh = Safe.merge_cards(mesh,data,2,centre,not cpu_grass)
		_check(instance.mesh != null,label+" native CPU card batch exists")
		if instance.mesh == null:
			view.free()
			return
		instance.position = centre
		view.add_child(instance)
	else:
		var instance := MultiMeshInstance3D.new()
		var mm := Safe.new_multimesh(mesh,3,AABB(centre-Vector3(8,4,8),Vector3(16,12,16)))
		_check(Safe.upload(mm,data,2),label+" native transform upload")
		_check(not mm.use_custom_data and not mm.use_colors and mm.visible_instance_count==2,label+" no packed attributes or visible unused capacity")
		for i in 2:
			_check(mm.get_instance_transform(i).is_equal_approx(transforms[i]),label+" renderer reads the exact transform")
		instance.multimesh = mm
		view.add_child(instance)
	var image: Image = await _frame(view)
	_check(image != null and not image.is_empty() and blank != null and image.get_size()==blank.get_size(),label+" real framebuffer")
	if image != null and blank != null and not image.is_empty() and image.get_size()==blank.get_size():
		var hits := [0,0]
		var stray := 0
		for y in image.get_height():
			for x in image.get_width():
				var a := image.get_pixel(x,y)
				var b := blank.get_pixel(x,y)
				if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b) < .12:
					continue
				var inside := false
				for i in 2:
					if rectangles[i].has_point(Vector2(x,y)):
						hits[i] += 1
						inside = true
				if not inside:
					stray += 1
		_check(hits[0]>12 and hits[1]>12,label+" both actual plants render separately: "+str(hits))
		_check(stray <= 4,label+" no stretched pixels outside the transformed mesh bounds: "+str(stray))
		var path := output.path_join(label+".png")
		_check(image.save_png(path)==OK,label+" framebuffer saved")
		samples.append({"name":label,"pixels_per_instance":hits,"stray_pixels":stray,"image":path.get_file(),"sha256":FileAccess.get_sha256(path)})
	view.free()
	await process_frame


func _assert_field(label: String) -> void:
	var field = game.world.vegetation
	if not is_instance_valid(field):
		_check(false,label+" actual village vegetation is missing")
		return
	_check(field.stats().render_path=="android_static",label+" Android-safe field selected")
	for batch: MultiMeshInstance3D in field._batches.values():
		_check(not batch.multimesh.use_custom_data and not batch.multimesh.use_colors,label+" native tree batch "+str(batch.name))
	for chunk: Dictionary in field._card_chunks:
		_check(chunk.node is MeshInstance3D,label+" cards are ordinary meshes, not GPU instances")
		if chunk.node.visible:
			_check(chunk.node.mesh != null and chunk.render_count > 0,label+" visible chunk has real geometry")
	for cell: Dictionary in field.grass._cells.values():
		if cell.has("node"):
			_check(cell.node is MeshInstance3D,label+" grass bypasses GPU instancing")
			if cell.node.visible:
				_check(cell.node.mesh != null and cell.render_count > 0,label+" grass contains baked local geometry")
				if cell.node.mesh != null:
					_check(cell.node.mesh.get_aabb().size.x < 12.0 and cell.node.mesh.get_aabb().size.z < 12.0,label+" grass stays inside its world cell")
	# Every material in the actual field must use the independent static shaders.
	for material: ShaderMaterial in Library.materials():
		_check(material.shader in [Safe.BARK,Safe.LEAF,Safe.CARD,Safe.GRASS,Safe.IMPOSTOR],label+" static material selected")


func _shot(label: String) -> void:
	var camera := root.get_camera_3d()
	if camera == null:
		_check(false,label+" camera missing")
		return
	game.world.vegetation.refresh(camera,true)
	_assert_field(label)
	if graphical:
		var image: Image = await _frame(root)
		var path := output.path_join(label+".png")
		_check(image!=null and not image.is_empty() and image.save_png(path)==OK,label+" actual game frame")
		samples.append({"name":label,"image":path.get_file(),"sha256":FileAccess.get_sha256(path),
			"scene":game.screen,"field":game.world.vegetation.stats()})


func _run() -> void:
	_check(Safe.active(),"Android safety path is active")
	_check_transforms()
	var grass_near := Library.grass_mesh("grass_tuft_near")
	var grass_far := Library.grass_mesh("grass_tuft_far")
	var card := Library.card_mesh("clump_near","herbs")
	var oak := Library.asset("quercus_robur")
	_check(grass_near != null and grass_far != null and card != null and oak.lods.size()==4,"All original geometry families are available")
	if graphical and failures.is_empty():
		await _projection("isolated-grass-near",grass_near,1.25,false,true)
		await _projection("isolated-grass-far",grass_far,1.25,false,true)
		await _projection("isolated-herbs",card,1.0,true)
		await _projection("isolated-tree-lod3",oak.lods[3],.16)
		await _projection("isolated-tree-impostor",oak.impostor,.16)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(900,1000)
	game = Entry.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.world.set_physics_process(false)
	game.ui._finish_intro()
	game._show_menu()
	game.world.set_quality("high")
	await _shot("game-menu")
	game._start_new_game()
	await process_frame
	_check(game.screen=="opening" and game.opening_sequence.id=="i00_aquileia","Actual I-00 introduction")
	await _shot("game-prologue")
	_check(not game.world.vegetation.visible,"Historical camp does not render unrelated village vegetation")
	_check(game.opening_director.camera.environment != null,"Historical camera has an independent readable exposure")
	game.opening_overlay._request_skip()
	await _shot("game-family-handoff")
	_check(game.world.vegetation.visible,"Village vegetation is restored for the handoff")
	game.opening_overlay._request_advance()
	_check(game.screen=="opening" and game.opening_sequence.id=="childhood_home","Actual I-01 family scene")
	game.opening_overlay._request_skip()
	game.opening_overlay.choice_requested.emit("i01_yard")
	game.opening_overlay._request_skip()
	game.opening_overlay._request_advance()
	_check(game.screen=="playing","Actual opening hands off to the playable village")
	_check(game.world.vegetation.visible,"Vegetation is not globally disabled in gameplay")
	var at: Vector2 = I01.POINTS.well + Vector2(1.5,.3)
	game.world.get_node("Player").position = Vector3(at.x,1.35,at.y)
	game.model.set_player_position(game.world.get_player_position())
	game.world.sync_state(game.model.data)
	game.world.prepare_cinematic_camera()
	await _shot("game-well")
	var camera := game.world.get_node("WorldCamera") as Camera3D
	camera.global_position = Vector3(-12,1.7,50)
	camera.look_at(Vector3(-16,.5,80))
	var counts := []
	for profile in ["low","balanced","high","very_high"]:
		game.world.set_quality(profile)
		game.world.vegetation.refresh(camera,true)
		var stats: Dictionary = game.world.vegetation.stats()
		counts.append(int(stats.grass_tufts_visible))
		_check(int(stats.placed_trees_shrubs_vines)>1200 and int(stats.visible_tree_batches)>0 and int(stats.card_instances_visible)>0,"Plants remain present at "+profile)
	_check(counts[0]==0 and counts[1]>0 and counts[2]>counts[1] and counts[3]>counts[2],"The four grass-density profiles remain distinct: "+str(counts))
	if graphical:
		await _shot("game-meadow-ultra")
		var receipt := FileAccess.open(output.path_join("vegetation-safe-report.json"),FileAccess.WRITE)
		if receipt != null:
			receipt.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples,
				"renderer":RenderingServer.get_current_rendering_method(),"physical_fold7_test":false}, "  "))
			receipt.close()
		else:
			_check(false,"Graphical report could not be written")
	# Exercise the real debug layout callback across scene destruction. The
	# original await-based logger emitted a fatal error after the 3961
	# vegetation checks had passed. Do not simply drain all frames first.
	game._show_menu()
	game._log_menu_geometry()
	if OS.is_debug_build():
		_check(process_frame.is_connected(game._log_menu_geometry_next_frame),"Menu layout callback is scheduled as a lifetime-bound signal")
	var old_menu_callback: Callable = game._log_menu_geometry_next_frame
	var old_menu_emit: Callable = game._emit_menu_geometry
	var old_opening_callback: Callable = game._log_opening_geometry_next_frame
	var old_opening_emit: Callable = game._emit_opening_geometry
	game.free()
	_check(not old_menu_callback.is_valid() and not old_menu_emit.is_valid() and not old_opening_callback.is_valid() and not old_opening_emit.is_valid(),"Scene destruction invalidates every bound layout callback")
	for i in 3:
		await process_frame
	print("VEGETATION_SAFE_RESULT checks=",checks," failures=",failures.size()," profiles=",counts)
	print("VEGETATION_SAFE_PASS" if failures.is_empty() else "VEGETATION_SAFE_FAIL")
	quit(0 if failures.is_empty() else 1)
