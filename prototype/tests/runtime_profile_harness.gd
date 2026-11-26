extends SceneTree
## Reproducible runtime profiling harness for the three key scenes.
##
## Usage (rendered, desktop software renderer):
##   xvfb-run -a godot --path prototype --fixed-fps 60 --script res://tests/runtime_profile_harness.gd \
##     -- --scene=village --quality=balanced --frames=600 --warmup=180 --mode=natural --out=/tmp/x.json
##
## Modes:
##   natural    - the game runs unmodified. Records wall frame time, engine
##                Performance monitors and render counters every frame.
##   attributed - script _process/_physics_process callbacks are dispatched by
##                this harness (same order key: process priority, tree order)
##                and timed per script file. This is a measurement mode only;
##                its totals are cross-checked against the natural pass.
##
## Every number is a desktop/software-renderer measurement. It is a relative
## comparison between source states, never an Android device result.

const Entry = preload("res://main.tscn")
const SEED := 20261126
const SCENES := ["village", "city", "district", "valley"]
const QUALITIES := ["low", "balanced", "high", "very_high"]

var scene_name := "village"
var quality := "balanced"
var frames_to_record := 600
var warmup_frames := 180
var mode := "natural"
var out_path := ""
var walk := true
var capture_path := ""

var game
var district
var _failures: Array[String] = []
var _frame_samples: Array[Dictionary] = []
var _last_frame_usec := 0
var _recording := false
var _managed_process: Array = []
var _managed_physics: Array = []
var _attr_process := {}
var _attr_physics := {}
var _attr_frames := 0
var _attr_physics_frames := 0
var _scan_due := 0


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("Runtime profiling requires isolated settings and saves.")
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		var value := parts[1] if parts.size() > 1 else ""
		match parts[0]:
			"scene": scene_name = value
			"quality": quality = value
			"frames": frames_to_record = int(value)
			"warmup": warmup_frames = int(value)
			"mode": mode = value
			"out": out_path = value
			"walk": walk = value != "0"
			"capture": capture_path = value
	if scene_name not in SCENES or quality not in QUALITIES or mode not in ["natural", "attributed"]:
		printerr("RUNTIME_PROFILE_FAIL bad arguments")
		quit(2)
		return
	seed(SEED)
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _uncap() -> void:
	# RuntimeDisplay applies the profile frame cap (30/60). The harness
	# measures cost, so it removes only the cap; every quality setting stays.
	Engine.max_fps = 0


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	game = Entry.instantiate()
	root.add_child(game)
	game.ui.set_quality(quality)
	await _frames(5)
	game.ui._touch_enabled = true
	game.ui._finish_intro()
	await _frames(3)
	var load_started := Time.get_ticks_usec()
	match scene_name:
		"village": await _enter_village()
		"city": await _enter_city()
		"valley": await _enter_valley()
		"district": await _enter_district()
	var load_ms := (Time.get_ticks_usec() - load_started) / 1000.0
	if not _failures.is_empty():
		_finish({}, load_ms)
		return
	var display := root.get_node_or_null("RuntimeDisplay")
	if display:
		display.apply_quality(quality)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_uncap()
	for i in warmup_frames:
		_drive(i)
		await process_frame
		_uncap()
	if mode == "attributed":
		_scan_managed()
		process_frame.connect(_dispatch_process)
		physics_frame.connect(_dispatch_physics)
	_recording = true
	_last_frame_usec = Time.get_ticks_usec()
	for i in frames_to_record:
		_drive(warmup_frames + i)
		await process_frame
		_uncap()
		_sample()
	_recording = false
	if not capture_path.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_path)
	if mode == "attributed":
		process_frame.disconnect(_dispatch_process)
		physics_frame.disconnect(_dispatch_physics)
	var scene_stats := _scene_census()
	var micro := _microbench() if mode == "natural" else {}
	scene_stats["microbench"] = micro
	_finish(scene_stats, load_ms)


# ---------------------------------------------------------------- scenes

func _enter_village() -> void:
	game.ui.action_requested.emit("new_game", {})
	await _frames(5)
	for i in 2:
		if game.screen == "opening":
			game._opening_skip()
			game._opening_next()
			await _frames(12)
	if game.screen != "playing":
		_failures.append("village did not reach playing: " + str(game.screen))


func _enter_city() -> void:
	if game.screen != "menu":
		game._show_menu()
		await _frames(2)
	game._open_city_exploration()
	await _frames(20)
	if game.screen != "city_exploration" or not is_instance_valid(game.city_exploration):
		_failures.append("city exploration did not open")


func _enter_district() -> void:
	# The walkable market district of the shared trade model (CitySupportDistrict).
	if game.screen != "menu":
		game._show_menu()
		await _frames(2)
	# The campaign shell is not part of this standalone district.
	game.set_process(false)
	game.set_physics_process(false)
	game.world.set_active(false)
	game.world.hide()
	game.remove_child(game.world)
	game.ui.hide()
	game.ui.process_mode = Node.PROCESS_MODE_DISABLED
	district = load("res://scenes/city_support_district.tscn").instantiate()
	district.auto_load = false
	district.save_path = "user://runtime_profile_district.json"
	district.quality_profile = quality
	root.add_child(district)
	await _frames(20)
	if not is_instance_valid(district) or not district.active:
		_failures.append("market district did not start")


func _enter_valley() -> void:
	if game.screen != "menu":
		game._show_menu()
		await _frames(2)
	game._open_valley(true)
	await _frames(10)
	if not is_instance_valid(game.valley):
		_failures.append("valley did not open")
		return
	game.valley.speed = 1.0
	game.valley.paused = false


func _drive(frame: int) -> void:
	# Deterministic movement per frame index under --fixed-fps 60.
	if not walk:
		return
	var phase := (frame / 240) % 4
	var axis: Vector2 = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][phase]
	match scene_name:
		"city":
			if is_instance_valid(game.city_exploration):
				game.city_exploration._touch_move = axis
		"district":
			if is_instance_valid(district):
				district._touch_axis = axis
		"village":
			if game.world and game.world.has_method("set_touch_move"):
				game.world.set_touch_move(axis)
			else:
				Input.action_release("move_forward")


# ---------------------------------------------------------------- sampling

func _monitor(id: int) -> float:
	return float(Performance.get_monitor(id))


func _sample() -> void:
	var now := Time.get_ticks_usec()
	var rid := root.get_viewport_rid()
	_frame_samples.append({
		"frame_ms": (now - _last_frame_usec) / 1000.0,
		"process_ms": _monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": _monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"navigation_ms": _monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0,
		"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(rid),
		"render_gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(rid),
		"draw_calls": _monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": _monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"objects": _monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"nodes": _monitor(Performance.OBJECT_NODE_COUNT),
		"physics_active": _monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		"physics_pairs": _monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
	})
	_last_frame_usec = Time.get_ticks_usec()


static func _stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for v in sorted:
		total += float(v)
	var n := sorted.size()
	return {"mean": snappedf(total / n, 0.0001), "p50": snappedf(float(sorted[ceili(n * 0.5) - 1]), 0.0001),
		"p95": snappedf(float(sorted[ceili(n * 0.95) - 1]), 0.0001),
		"p99": snappedf(float(sorted[ceili(n * 0.99) - 1]), 0.0001),
		"max": snappedf(float(sorted[n - 1]), 0.0001)}


func _summary() -> Dictionary:
	var out := {}
	if _frame_samples.is_empty():
		return out
	for key in _frame_samples[0]:
		var values := []
		for sample in _frame_samples:
			values.append(sample[key])
		out[key] = _stats(values)
	return out


# ---------------------------------------------------------------- attribution

func _script_key(node: Node) -> String:
	var script: Script = node.get_script()
	var path := script.resource_path
	if path.is_empty() or path.contains("::"):
		# Inner or built-in classes: name them by their owning file and base.
		var base: Script = script.get_base_script()
		path = (base.resource_path if base else "") + "::inner(" + node.get_class() + ")"
	return path


static func _declares(script: Script, method: String) -> bool:
	var current := script
	while current:
		for entry in current.get_script_method_list():
			if entry.name == method:
				return true
		current = current.get_base_script()
	return false


func _scan_managed() -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node.get_script() == null:
			continue
		var script: Script = node.get_script()
		if node.is_processing() and _declares(script, "_process"):
			node.set_process(false)
			_managed_process.append([node, _script_key(node)])
		if node.is_physics_processing() and _declares(script, "_physics_process"):
			node.set_physics_process(false)
			_managed_physics.append([node, _script_key(node)])
	var order := func(a, b) -> bool:
		if not is_instance_valid(a[0]) or not is_instance_valid(b[0]):
			return false
		if a[0].process_priority != b[0].process_priority:
			return a[0].process_priority < b[0].process_priority
		return b[0].is_greater_than(a[0])
	_managed_process.sort_custom(order)
	_managed_physics.sort_custom(order)


func _dispatch(list: Array, bucket: Dictionary, delta: float, physics: bool) -> void:
	for entry in list:
		var node = entry[0]
		if not is_instance_valid(node) or not node.is_inside_tree() or not node.can_process():
			continue
		var key: String = entry[1]
		var started := Time.get_ticks_usec()
		if physics:
			node._physics_process(delta)
		else:
			node._process(delta)
		var spent := Time.get_ticks_usec() - started
		var slot: Dictionary = bucket.get(key, {"usec": 0, "calls": 0})
		slot.usec += spent
		slot.calls += 1
		bucket[key] = slot


func _dispatch_process() -> void:
	if not _recording:
		return
	_attr_frames += 1
	_dispatch(_managed_process, _attr_process, get_root().get_process_delta_time(), false)


func _dispatch_physics() -> void:
	if not _recording:
		return
	_attr_physics_frames += 1
	_dispatch(_managed_physics, _attr_physics, get_root().get_physics_process_delta_time(), true)


func _attribution_report(bucket: Dictionary, frames: int) -> Array:
	var rows := []
	for key in bucket:
		var slot: Dictionary = bucket[key]
		rows.append({"script": key, "ms_per_frame": snappedf(slot.usec / 1000.0 / maxf(frames, 1), 0.0001),
			"calls_per_frame": snappedf(float(slot.calls) / maxf(frames, 1), 0.01)})
	rows.sort_custom(func(a, b): return a.ms_per_frame > b.ms_per_frame)
	return rows


# ---------------------------------------------------------------- census

func _scene_census() -> Dictionary:
	var materials := {}
	var meshes := 0
	var multimeshes := 0
	var multimesh_instances := 0
	var visible_meshes := 0
	var with_visibility_range := 0
	var lights := 0
	var shadow_lights := 0
	var skeletons := 0
	var animation_players := 0
	var bodies := {}
	var sleeping := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is GeometryInstance3D:
			var geometry := node as GeometryInstance3D
			if geometry.visibility_range_end > 0.0:
				with_visibility_range += 1
			if geometry.material_override:
				materials[geometry.material_override.get_instance_id()] = true
		if node is MeshInstance3D:
			meshes += 1
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.is_visible_in_tree():
				visible_meshes += 1
			if mesh_instance.mesh:
				for s in mesh_instance.mesh.get_surface_count():
					var material := mesh_instance.get_active_material(s)
					if material:
						materials[material.get_instance_id()] = true
		elif node is MultiMeshInstance3D:
			multimeshes += 1
			var mm := (node as MultiMeshInstance3D).multimesh
			if mm:
				multimesh_instances += mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
		elif node is Light3D:
			lights += 1
			if (node as Light3D).shadow_enabled and node.is_visible_in_tree():
				shadow_lights += 1
		elif node is Skeleton3D:
			skeletons += 1
		elif node is AnimationPlayer:
			animation_players += 1
		if node is PhysicsBody3D:
			var cls := node.get_class()
			bodies[cls] = int(bodies.get(cls, 0)) + 1
			if node is RigidBody3D and (node as RigidBody3D).sleeping:
				sleeping += 1
	return {"unique_materials": materials.size(), "mesh_instances": meshes,
		"visible_mesh_instances": visible_meshes, "multimesh_nodes": multimeshes,
		"multimesh_instances": multimesh_instances, "geometry_with_visibility_range": with_visibility_range,
		"lights": lights, "shadow_lights": shadow_lights, "skeletons": skeletons,
		"animation_players": animation_players, "physics_bodies": bodies, "sleeping_rigid_bodies": sleeping,
		"village_people": get_nodes_in_group("village_people").size(),
		"village_people_by_detail": _people_by_detail(),
		"memory_static_mib": snappedf(_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.01),
		"video_mem_mib": snappedf(_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.01),
		"texture_mem_mib": snappedf(_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.01),
		"buffer_mem_mib": snappedf(_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0, 0.01),
		"objects": int(_monitor(Performance.OBJECT_COUNT)), "resources": int(_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"nodes": int(_monitor(Performance.OBJECT_NODE_COUNT))}


func _people_by_detail() -> Dictionary:
	var out := {}
	for actor in get_nodes_in_group("village_people"):
		var key := "d%d_%s" % [int(actor.detail), "shown" if actor.is_visible_in_tree() else "hidden"]
		out[key] = int(out.get(key, 0)) + 1
	return out


# ---------------------------------------------------------------- microbench

func _time_call(callable: Callable, repeats: int) -> float:
	var started := Time.get_ticks_usec()
	for i in repeats:
		callable.call()
	return snappedf((Time.get_ticks_usec() - started) / 1000.0 / repeats, 0.0001)


func _microbench() -> Dictionary:
	# Isolated costs of the domain step on a private copy of the live state.
	if scene_name != "village" or game.model == null:
		return {}
	var Model = load("res://scripts/domain/world_model.gd")
	var copy = Model.new()
	copy.data = game.model.data.duplicate(true)
	copy.combat_sight_check = game.model.combat_sight_check
	copy.npc_sight_check = game.model.npc_sight_check
	copy.combat_motion_check = game.model.combat_motion_check
	copy.npc_observations = game.model.npc_observations
	copy.raid_observations = game.model.raid_observations
	var state_bytes := var_to_bytes(copy.data).size()
	return {"state_bytes": state_bytes,
		"validate_state_ms": _time_call(func(): copy._validate_state(copy.data), 40),
		"world_copy_ms": _time_call(func(): copy._world_copy(), 40),
		"advance_0_1s_ms": _time_call(func(): copy.advance(0.1), 40),
		"advance_1_60s_ms": _time_call(func(): copy.advance(1.0 / 60.0), 40),
		"step_ms": _step_costs(copy, Model),
		"validators_ms": {
			"combat_actions": _time_call(func(): Model.CombatActions.validate(copy.data), 40),
			"village_economy": _time_call(func(): Model.VillageEconomy.validate(copy.data), 40),
			"village_life": _time_call(func(): Model.VillageLife.validate(copy.data), 40),
			"npc_behavior": _time_call(func(): Model.NpcBehavior.validate(copy.data), 40),
			"city_trade": _time_call(func(): Model.CityTrade.validate(copy.data), 40),
			"frontier": _time_call(func(): Model.Frontier.validate(copy.data), 40),
			"seasons": _time_call(func(): Model.Seasons.validate(copy.data.strategy), 40),
		}}


func _step_costs(copy, Model) -> Dictionary:
	# Each stage of WorldModel.advance() on a fresh private candidate.
	var fresh := func() -> Dictionary: return copy._world_copy()
	var out := {}
	var observations: Variant = copy.npc_observations.call() if copy.npc_observations.is_valid() else null
	out["npc_observations_call"] = _time_call(func(): copy.npc_observations.call(), 20) if copy.npc_observations.is_valid() else 0.0
	out["npc_observe"] = _time_call(func(): Model.NpcBehavior.observe(fresh.call(), observations, true), 20) - out.get("world_copy", 0.0)
	out["childhood_advance"] = _time_call(func(): Model.Childhood.advance(fresh.call(), 0.1), 20)
	out["economy_advance"] = _time_call(func(): Model.VillageEconomy.advance(fresh.call(), 0.1), 20)
	out["life_advance"] = _time_call(func(): Model.VillageLife.advance(fresh.call(), 0.1, copy.combat_sight_check, copy.combat_motion_check, {}), 20)
	out["npc_advance"] = _time_call(func(): Model.NpcBehavior.advance(fresh.call(), 0.1, copy.npc_sight_check), 20)
	out["combat_advance"] = _time_call(func(): Model.CombatActions.advance(fresh.call(), 0.1, copy.combat_sight_check, copy._apply_combat_hit), 20)
	out["copy_only"] = _time_call(func(): fresh.call(), 20)
	return out


# ---------------------------------------------------------------- output

func _finish(scene_stats: Dictionary, load_ms: float) -> void:
	var report := {
		"harness": "runtime_profile_harness.gd", "schema": 1, "seed": SEED,
		"scene": scene_name, "quality": quality, "mode": mode, "walk": walk,
		"frames": _frame_samples.size(), "warmup_frames": warmup_frames,
		"load_ms": snappedf(load_ms, 0.1),
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"display": DisplayServer.get_name(),
		"viewport": [root.size.x, root.size.y], "scale_3d": root.scaling_3d_scale,
		"msaa_3d": root.msaa_3d,
		"evidence_class": "desktop software renderer, relative only; not an Android device measurement",
		"failures": _failures,
		"summary": _summary(), "census": scene_stats,
	}
	if mode == "attributed":
		report["process_attribution"] = _attribution_report(_attr_process, _attr_frames)
		report["physics_attribution"] = _attribution_report(_attr_physics, _attr_physics_frames)
		report["physics_frames"] = _attr_physics_frames
	var text := JSON.stringify(report, "  ")
	if not out_path.is_empty():
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		if file:
			file.store_string(text + "\n")
			file.close()
	print("RUNTIME_PROFILE " + ("FAIL " + str(_failures) if not _failures.is_empty() else "DONE") + " " + scene_name + " " + quality + " " + mode)
	quit(0 if _failures.is_empty() else 1)
