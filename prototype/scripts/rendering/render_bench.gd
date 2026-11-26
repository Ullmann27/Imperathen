extends RefCounted
## Fixed views, harness night lighting and render counters shared by the
## desktop renderer comparison (tests/render_comparison.gd), the feature probe
## (tests/render_feature_probe.gd) and the Android graphics probe "views" mode.
##
## Presentation only: staging moves the player capsule and camera of an already
## running game and may add clearly named harness lights. Callers restore the
## start pose afterwards; world simulation data is never written.
## Every number measured here belongs to the renderer and driver that ran it.
## Software renderers (llvmpipe, lavapipe) give relative indicators only.

const RenderProfile = preload("res://scripts/rendering/render_profile.gd")

const VILLAGE_VIEWS := ["house_interior", "village_lane", "village_overview", "night_torch"]
const CITY_VIEWS := ["city_forum", "city_market"]
## D-052 showcase: the shared fixed camera list of the visual reference
## environment (family house, Valdora, forge, landscape path, dialogue, Roman
## main street, market, forum). One file for every graphics branch.
const SHOWCASE := "res://assets/rendering/showcase_cameras.json"
## Same lane and overview cameras as tests/village_look_review.gd ("path",
## "overview"), so look development and renderer comparison share framings.
const LANE_POSITION := Vector3(0.9, 0.0, 12.5)
const LANE_YAW := 0.0
const LANE_PITCH := 0.24
const OVERVIEW_EYE := Vector3(31.0, 17.5, 33.0)
const OVERVIEW_TARGET := Vector3(-4.0, 1.0, -9.0)
## Same spots as tests/roman_city_visual_capture.gd.
const CITY_SPOTS := {"city_forum": Vector3(-8.0, 0.92, 24.0), "city_market": Vector3(-12.0, 0.92, 68.0)}
## The village look development keeps its shot set in this file; when present
## its "cameras" win, so look reviews and renderer/profile benches stay
## same-camera. The constants above are the identical fallback.
const LOOK_VALUES := "res://assets/village/look/look_values.json"
## Harness night: neutral test values for an engine comparison of positional
## lights and shadows. They are NOT look-development presets; moon, sky and
## torch colours belong to the village look and replace these once they exist.
const NIGHT := {"sun_energy": 0.05, "sun_color": Color(0.61, 0.70, 0.85), "ambient_scale": 0.14, "sky_energy": 0.07}
const TORCH := {"color": Color(1.0, 0.60, 0.31), "energy": 2.4, "range": 8.5, "attenuation": 1.3, "height": 2.15}
## Torch stands along the lane, relative to the lane camera: x to the right,
## y forward in metres. Six stands exceed the light budget of the low profile.
const TORCH_OFFSETS := [Vector2(-2.6, 4.5), Vector2(2.8, 7.5), Vector2(-2.7, 11.5),
	Vector2(2.9, 16.0), Vector2(-3.0, 21.0), Vector2(3.0, 27.0)]
const TORCH_NODE := "RenderBenchTorches"
## Local solar hour of the night view when the village look provides time of day.
const NIGHT_HOUR := 23.0


static func renderer_info() -> Dictionary:
	var method := RenderingServer.get_current_rendering_method()
	var adapter := RenderingServer.get_video_adapter_name()
	var software := adapter.to_lower().contains("llvmpipe") or adapter.to_lower().contains("lavapipe") \
		or adapter.to_lower().contains("swiftshader") or adapter.to_lower().contains("software")
	return {"method": method, "driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": adapter, "vendor": RenderingServer.get_video_adapter_vendor(),
		"api_version": RenderingServer.get_video_adapter_api_version(),
		"device_type": RenderingServer.get_video_adapter_type(),
		"software_renderer": software,
		"engine": Engine.get_version_info().string, "os": OS.get_name(),
		"model": OS.get_model_name(), "processor": OS.get_processor_name(),
		"processor_count": OS.get_processor_count(),
		"headless": DisplayServer.get_name() == "headless",
		"label": "HEADLESS: nothing is rendered; render counters and GPU times are not measured" if DisplayServer.get_name() == "headless"
			else ("SOFTWARE RENDERER (%s): relative indicator only, not mobile-GPU or Fold7 data" % adapter) if software
			else "Hardware GPU %s: valid only for this device and driver" % adapter}


## Starts a new life through the real game path (main.tscn -> intro -> new
## game -> opening skipped) and freezes simulation for repeatable images.
## Returns the game node, or null with the reason in `errors`.
static func boot_village(root: Window, errors: Array) -> Node:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await root.get_tree().process_frame
	game.ui._finish_intro()
	game._start_new_game()
	for attempt in 4:
		if game.screen != "opening":
			break
		game._opening_skip()
		# I-01 VID-A waits for the morning choice; skip stops there and decides
		# nothing, so the bench takes the yard path through the regular command.
		game._opening_choose("i01_yard")
		game._opening_skip()
		game._opening_next()
		await root.get_tree().process_frame
	if game.screen != "playing":
		errors.append("Opening did not hand over to play: " + str(game.screen))
	for i in 12:
		await root.get_tree().physics_frame
	game._refresh()
	game._save(false)
	game._continue_game()
	game.set_process(false)
	game.world.set_physics_process(false)
	game.world._camera_initialized = false
	game.world._update_camera(0)
	game._refresh()
	game.ui._toast_panel.hide()
	game.ui.hide()
	return game


## Places player and camera of a running village (scripts/world/game_world.gd)
## for one fixed view. `start` is the pose captured right after game start.
static func stage_village(world: Node3D, view: String, start: Dictionary) -> bool:
	var camera: Camera3D = world._camera
	leave_night(world)
	match view:
		"house_interior":
			# The I-01 start view inside the family house, through the game camera.
			restore_village(world, start)
			world._camera_initialized = false
			world._update_camera(0)
		"village_lane", "night_torch":
			# Fixed comparison time: a fresh campaign may start before sunrise.
			# Do not let its saved clock turn the daytime comparison into a night shot.
			_set_bench_day(world)
			var lane: Dictionary = cameras().lane
			place_player(world, lane.player, lane.yaw, float(start.get("lift", 1.0)))
			world._camera_yaw = lane.yaw
			world._camera_pitch = lane.pitch
			world._camera_initialized = false
			world._update_camera(0)
			if view == "night_torch":
				enter_night(world)
		"village_overview":
			_set_bench_day(world)
			var overview: Dictionary = cameras().overview
			camera.fov = overview.fov
			camera.global_position = overview.eye
			camera.look_at(overview.target, Vector3.UP)
		_:
			var shot := showcase_shot(view)
			if shot.is_empty() or str(shot.get("scene", "")) != "village" or not _stage_showcase(world, shot, start):
				return false
	for figure in world.get_tree().get_nodes_in_group("village_people"):
		if figure.has_method("refresh_lod") and figure.is_visible_in_tree():
			figure.refresh_lod(camera)
	world.population.update_nearby(world.get_player_position(), true)
	# Refresh the same native light selection at the new camera before a
	# fixed-frame comparison; a zero-time sample changes no simulation clock.
	var look: Object = _village_look(world)
	if look != null:
		look.call("_process", 0.0)
	return true


## Lane and overview cameras: the look-values shot set if installed, else the constants.
static func cameras() -> Dictionary:
	var result := {"source": "render_bench.gd constants",
		"lane": {"player": LANE_POSITION, "yaw": LANE_YAW, "pitch": LANE_PITCH},
		"overview": {"eye": OVERVIEW_EYE, "target": OVERVIEW_TARGET, "fov": 54.0}}
	if not FileAccess.file_exists(LOOK_VALUES):
		return result
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LOOK_VALUES))
	var shots: Dictionary = data.get("cameras", {}) if data is Dictionary else {}
	if shots.has("path") and shots.path.get("player") is Array:
		var p: Array = shots.path.player
		result.lane = {"player": Vector3(p[0], p[1], p[2]), "yaw": float(shots.path.yaw), "pitch": float(shots.path.pitch)}
		result.source = LOOK_VALUES
	if shots.has("overview") and shots.overview.get("eye") is Array:
		var e: Array = shots.overview.eye
		var t: Array = shots.overview.target
		result.overview = {"eye": Vector3(e[0], e[1], e[2]), "target": Vector3(t[0], t[1], t[2]), "fov": float(shots.overview.get("fov", 54.0))}
		result.source = LOOK_VALUES
	return result


## Showcase shots by id, numbers resolved against the look file ("look" key).
static func showcase() -> Dictionary:
	var result := {"source": SHOWCASE, "shots": {}, "order": [], "profiles": ["balanced", "very_high"]}
	if not FileAccess.file_exists(SHOWCASE):
		return result
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHOWCASE))
	if not data is Dictionary:
		return result
	result.profiles = data.get("profiles", result.profiles)
	var look := {}
	var look_file := str(data.get("look_file", LOOK_VALUES))
	if FileAccess.file_exists(look_file):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(look_file))
		if parsed is Dictionary:
			look = parsed.get("cameras", {})
	for entry: Dictionary in data.get("shots", []):
		var shot := entry.duplicate(true)
		var key := str(shot.get("look", ""))
		if look.has(key) and look[key] is Dictionary:
			shot.merge(look[key], true)
			shot["numbers_from"] = look_file
		result.shots[str(shot.id)] = shot
		result.order.append(str(shot.id))
	return result


static func showcase_shot(view: String) -> Dictionary:
	return showcase().shots.get(view, {})


static func showcase_views(scene: String) -> Array:
	var data := showcase()
	var views := []
	for id: String in data.order:
		if str(data.shots[id].get("scene", "")) == scene:
			views.append(id)
	return views


static func _vec(value: Variant) -> Vector3:
	return Vector3(value[0], value[1], value[2])


static func _stage_showcase(world: Node3D, shot: Dictionary, start: Dictionary) -> bool:
	var camera: Camera3D = world._camera
	match str(shot.get("kind", "")):
		"start":
			restore_village(world, start)
			world._camera_initialized = false
			world._update_camera(0)
		"free":
			camera.fov = float(shot.get("fov", 54.0))
			camera.global_position = _vec(shot.eye)
			camera.look_at(_vec(shot.target), Vector3.UP)
		"player":
			place_player(world, _vec(shot.player), float(shot.yaw), float(start.get("lift", 1.0)))
			world._camera_yaw = float(shot.yaw)
			world._camera_pitch = float(shot.pitch)
			world._camera_initialized = false
			world._update_camera(0)
			if bool(shot.get("night", false)):
				enter_night(world)
		"conversation":
			return _stage_conversation(world, shot, start)
		_:
			return false
	return true


## Over-the-shoulder two-shot, the same construction as the look review's
## "conversation": the player stands at talking distance on open floor, the
## resident turns to the player, the camera sits behind the player's shoulder.
## The resident's previous facing is stored and restored by restore_village().
static func _stage_conversation(world: Node3D, shot: Dictionary, start: Dictionary) -> bool:
	var life = world.village_life_world
	var id := ""
	for candidate in shot.get("partners", []):
		if life.actors.has(candidate) and (life.actors[candidate] as Node3D).is_visible_in_tree():
			id = str(candidate)
			break
	if id.is_empty():
		return false
	var at: Vector3 = life.actor_position(id)
	var actor: Node3D = life.actors[id]
	var body: Node3D = actor.get_node("Figure") if actor.has_node("Figure") else actor
	var facing := -body.global_basis.z
	facing.y = 0
	facing = facing.normalized() if facing.length() > 0.1 else Vector3.BACK
	var distance := float(shot.get("distance", 1.35))
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var ground := floor_height(world, at + Vector3.UP * 0.5)
	var away: Vector3 = facing
	for direction: Vector3 in [facing, -facing, facing.rotated(Vector3.UP, PI / 2), facing.rotated(Vector3.UP, -PI / 2)]:
		var stand: Vector3 = at + direction * distance
		if absf(floor_height(world, Vector3(stand.x, ground + 0.5, stand.z)) - ground) > 0.3:
			continue
		var line := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.2 + direction * 0.35,
			stand + Vector3.UP * 1.2 + direction * 0.6, 1, [world._player.get_rid()])
		if space.intersect_ray(line).is_empty():
			away = direction
			break
	var lift := float(start.get("lift", 1.0))
	var stand_at: Vector3 = at + away * distance
	place_player(world, Vector3(stand_at.x, ground + 0.5, stand_at.z), atan2(away.x, away.z), lift)
	world.set_meta("render_bench_turned", {"node": body, "yaw": body.global_rotation.y})
	body.global_rotation.y = atan2(away.x, away.z) + PI
	var feet: Vector3 = world.get_player_position() - Vector3.UP * lift
	var side := Vector3.UP.cross(-away).normalized()
	var camera: Camera3D = world._camera
	camera.fov = float(shot.get("fov", 44.0))
	camera.global_position = feet + away * float(shot.get("camera_back", 1.15)) - side * float(shot.get("camera_side", 0.52)) \
		+ Vector3.UP * float(shot.get("camera_height", 1.62))
	camera.look_at(Vector3(at.x, feet.y, at.z) + Vector3.UP * 1.42 - side * 0.18, Vector3.UP)
	world.set_meta("render_bench_conversation", {"partner": id, "partner_position": str(at), "player": str(world.get_player_position())})
	return true


static func village_start(world: Node3D) -> Dictionary:
	var camera: Camera3D = world._camera
	var player: CharacterBody3D = world._player
	var look: Object = _village_look(world)
	return {"player": player.global_position, "yaw": world._camera_yaw, "pitch": world._camera_pitch,
		"camera": camera.global_transform, "fov": camera.fov, "figure_yaw": world._figure.rotation.y,
		"look_time": float(look.get("time_of_day")) if look != null else -1.0,
		"lift": player.global_position.y - floor_height(world, player.global_position)}


static func restore_village(world: Node3D, start: Dictionary) -> void:
	leave_night(world)
	if world.has_meta("render_bench_turned"):
		var turned: Dictionary = world.get_meta("render_bench_turned")
		if is_instance_valid(turned.node):
			(turned.node as Node3D).global_rotation.y = float(turned.yaw)
		world.remove_meta("render_bench_turned")
	if not world._village_focus.is_empty():
		world.clear_frontier_focus()
	world._player.global_position = start.player
	world._figure.rotation.y = start.figure_yaw
	world._camera_yaw = start.yaw
	world._camera_pitch = start.pitch
	world._camera.fov = start.fov
	world._camera.global_transform = start.camera
	var look: Object = _village_look(world)
	if look != null and start.has("look_time"):
		look.call("set_time_of_day", float(start.look_time))
		look.call("_process", 0.0)


static func _set_bench_day(world: Node3D) -> void:
	var look: Object = _village_look(world)
	if look != null:
		look.call("set_time_of_day", -1.0)


static func place_player(world: Node3D, at: Vector3, yaw: float, lift: float) -> void:
	world._player.global_position = Vector3(at.x, floor_height(world, at) + lift, at.z)
	world._figure.rotation.y = yaw


static func floor_height(world: Node3D, at: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, at.y + 1.0, at.z), Vector3(at.x, at.y - 6.0, at.z), 1, [world._player.get_rid()])
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else 0.0


## Moonlit night with torch stands along the lane. The previous sun, sky and
## ambient values are stored on the torch node and restored by leave_night().
static func enter_night(world: Node3D) -> Node3D:
	if world.has_node(TORCH_NODE):
		return world.get_node(TORCH_NODE)
	var sun: DirectionalLight3D = world._sun
	var environment: Environment = world._village_environment
	var torches := Node3D.new()
	torches.name = TORCH_NODE
	# With the village look installed, night and fire light come from its data
	# file (look_values.json: night, fire); the NIGHT/TORCH constants are only
	# the neutral fallback of a tree without look development.
	var look: Object = _village_look(world)
	if look != null:
		torches.set_meta("restore", {"look_time": look.get("time_of_day")})
		look.call("set_time_of_day", float(NIGHT_HOUR))
	else:
		torches.set_meta("restore", {"sun_energy": sun.light_energy, "sun_color": sun.light_color,
			"ambient": environment.ambient_light_energy, "sky": environment.background_energy_multiplier})
		sun.light_energy = float(NIGHT.sun_energy)
		sun.light_color = NIGHT.sun_color
		environment.ambient_light_energy *= float(NIGHT.ambient_scale)
		environment.background_energy_multiplier = float(NIGHT.sky_energy)
	world.add_child(torches)
	var camera: Camera3D = world._camera
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.1 else Vector3.FORWARD
	var right := forward.cross(Vector3.UP).normalized()
	var origin := Vector3(camera.global_position.x, 0.0, camera.global_position.z)
	var pole := _torch_materials()
	for index in TORCH_OFFSETS.size():
		var offset: Vector2 = TORCH_OFFSETS[index]
		var at := origin + right * offset.x + forward * offset.y
		at.y = floor_height(world, at + Vector3.UP * 3.0)
		var stand := _torch(index, at, pole, look == null)
		torches.add_child(stand)
		if look != null:
			var light: OmniLight3D = look.call("add_fire_light", stand, Vector3(0, float(TORCH.height) + 0.08, 0), "torch")
			light.shadow_bias = 0.08
			light.add_to_group(RenderProfile.LIGHT_GROUP)
			RenderProfile.configure_light(light, RenderProfile.current_profile())
	return torches


## The look-development node of the village (scripts/rendering/village_look.gd), if this tree has it.
static func _village_look(world: Node3D) -> Object:
	var look: Variant = world.get("look")
	return look if look is Object and (look as Object).has_method("set_time_of_day") and (look as Object).has_method("add_fire_light") else null


static func leave_night(world: Node3D) -> void:
	if not world.has_node(TORCH_NODE):
		return
	var torches := world.get_node(TORCH_NODE)
	var saved: Dictionary = torches.get_meta("restore")
	var look: Object = _village_look(world)
	world.remove_child(torches)
	torches.free()
	if saved.has("look_time") and look != null:
		# The look node animates its fire lights; forget the ones just freed.
		var fires: Variant = look.get("_fires")
		if fires is Array:
			look.set("_fires", (fires as Array).filter(func(entry): return is_instance_valid(entry.get("light"))))
		look.call("set_time_of_day", float(saved.look_time))
		return
	var sun: DirectionalLight3D = world._sun
	var environment: Environment = world._village_environment
	sun.light_energy = float(saved.sun_energy)
	sun.light_color = saved.sun_color
	environment.ambient_light_energy = float(saved.ambient)
	environment.background_energy_multiplier = float(saved.sky)


static func _torch_materials() -> Dictionary:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.29, 0.21, 0.14)
	wood.roughness = 0.9
	var flame := StandardMaterial3D.new()
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.albedo_color = Color(1.0, 0.72, 0.38)
	flame.emission_enabled = true
	flame.emission = Color(1.0, 0.55, 0.22)
	flame.emission_energy_multiplier = 3.0
	return {"wood": wood, "flame": flame}


static func _torch(index: int, at: Vector3, materials: Dictionary, with_light := true) -> Node3D:
	var stand := Node3D.new()
	stand.name = "TorchStand%d" % index
	stand.position = at
	var pole := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.035
	cylinder.bottom_radius = 0.05
	cylinder.height = float(TORCH.height)
	pole.mesh = cylinder
	pole.material_override = materials.wood
	pole.position.y = float(TORCH.height) * 0.5
	stand.add_child(pole)
	var flame := MeshInstance3D.new()
	var blob := SphereMesh.new()
	blob.radius = 0.075
	blob.height = 0.22
	flame.mesh = blob
	flame.material_override = materials.flame
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position.y = float(TORCH.height) + 0.08
	stand.add_child(flame)
	if not with_light:
		return stand
	var light := OmniLight3D.new()
	light.name = "TorchLight"
	light.light_color = TORCH.color
	light.light_energy = float(TORCH.energy)
	light.omni_range = float(TORCH.range)
	light.omni_attenuation = float(TORCH.attenuation)
	light.position.y = float(TORCH.height) + 0.08
	# The flame sits inside the light; it must not shadow its own room.
	light.shadow_bias = 0.08
	light.add_to_group(RenderProfile.LIGHT_GROUP)
	stand.add_child(light)
	RenderProfile.configure_light(light, RenderProfile.current_profile())
	return stand


## City exploration (scripts/world/city_exploration.gd) at a fixed spot.
static func stage_city(city: Node3D, view: String) -> bool:
	var shot := showcase_shot(view)
	if str(shot.get("kind", "")) == "city":
		city.teleport(_vec(shot.spot))
		city._yaw = float(shot.get("yaw", 0.0))
		city._pitch = float(shot.get("pitch", -0.18))
		city._distance = float(shot.get("distance", 4.2))
		city._place_camera(0.2)
		return true
	if not CITY_SPOTS.has(view):
		return false
	city.teleport(CITY_SPOTS[view])
	city._yaw = 0.0
	city._pitch = -0.18
	city._distance = 4.2
	city._place_camera(0.2)
	return true


static func rss_kib() -> int:
	if OS.get_name() not in ["Android", "Linux"]:
		return -1
	var status := FileAccess.open("/proc/self/status", FileAccess.READ)
	if status == null:
		return -1
	for line in status.get_buffer(32768).get_string_from_ascii().split("\n"):
		if line.begins_with("VmRSS:"):
			return line.trim_prefix("VmRSS:").strip_edges().get_slice(" ", 0).to_int()
	return -1


## frame_post_draw is never emitted without a drawing display (headless runs);
## the protocol then advances on process frames and measures no rendering.
static func next_frame(tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless":
		await tree.process_frame
	else:
		await RenderingServer.frame_post_draw


## Frame and counter sample over `frames` drawn frames. Absent GPU timing is
## reported as null, never as zero.
static func measure(viewport: Viewport, frames: int) -> Dictionary:
	var rid := viewport.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var wall: Array[float] = []
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var calls: Array[float] = []
	var primitives: Array[float] = []
	var objects: Array[float] = []
	var tree := viewport.get_tree()
	await next_frame(tree)
	var previous := Time.get_ticks_usec()
	for i in maxi(frames, 2):
		await next_frame(tree)
		var now := Time.get_ticks_usec()
		wall.append((now - previous) / 1000.0)
		previous = now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		calls.append(viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
		primitives.append(viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
		objects.append(viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME))
	var gpu_p50 := percentile(gpu, 0.5)
	var cpu_p50 := percentile(cpu, 0.5)
	var rss := rss_kib()
	return {"frames": wall.size(), "wall_ms_p50": percentile(wall, 0.5), "wall_ms_p95": percentile(wall, 0.95),
		"wall_ms_max": percentile(wall, 1.0),
		"render_cpu_ms_p50": cpu_p50 if cpu_p50 > 0.0 else null,
		"render_gpu_ms_p50": gpu_p50 if gpu_p50 > 0.0 else null,
		"draw_calls": percentile(calls, 0.5), "primitives": percentile(primitives, 0.5), "objects": percentile(objects, 0.5),
		"shadow_draw_calls": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"shadow_primitives": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		"texture_mib": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0,
		"buffer_mib": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576.0,
		"video_mib": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
		"rss_mib": rss / 1024.0 if rss > 0 else null,
		"render_scale": viewport.scaling_3d_scale,
		"internal_3d_pixels": [roundi(viewport.get_visible_rect().size.x * viewport.scaling_3d_scale),
			roundi(viewport.get_visible_rect().size.y * viewport.scaling_3d_scale)]}


static func percentile(values: Array, fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[clampi(ceili(sorted.size() * fraction) - 1, 0, sorted.size() - 1)])


## The engine state that actually produced an image (D-038 metadata).
static func engine_state(viewport: Viewport, scene: Node) -> Dictionary:
	var camera := viewport.get_camera_3d()
	var environment: Environment = RenderProfile.active_environment(viewport)
	var torches := scene.get_node_or_null(TORCH_NODE)
	var lights := {"directional": 0, "omni": 0, "spot": 0, "visible": 0, "shadowed": 0,
		"harness_omni": 0, "harness_shadowed": 0, "scene_omni_paths": []}
	var sun := {}
	for light: Light3D in scene.find_children("*", "Light3D", true, false):
		if not light.is_visible_in_tree():
			continue
		lights.visible += 1
		lights.shadowed += 1 if light.shadow_enabled else 0
		if light is DirectionalLight3D:
			lights.directional += 1
			if sun.is_empty():
				sun = {"name": str(light.name), "energy": light.light_energy, "color": light.light_color.to_html(false),
					"rotation_deg": str(light.rotation_degrees), "shadow": light.shadow_enabled,
					"shadow_mode": ["orthogonal", "2_splits", "4_splits"][light.directional_shadow_mode],
					"shadow_max_distance": light.directional_shadow_max_distance,
					"blend_splits": light.directional_shadow_blend_splits}
		elif light is OmniLight3D:
			lights.omni += 1
			if torches != null and torches.is_ancestor_of(light):
				lights.harness_omni += 1
				lights.harness_shadowed += 1 if light.shadow_enabled else 0
			else:
				lights.scene_omni_paths.append(str(scene.get_path_to(light)))
		elif light is SpotLight3D:
			lights.spot += 1
	var env := {}
	if environment != null:
		env = {"tonemapper": ["linear", "reinhard", "filmic", "aces", "agx"][clampi(environment.tonemap_mode, 0, 4)],
			"exposure": environment.tonemap_exposure, "white": environment.tonemap_white,
			"ambient_source": environment.ambient_light_source, "ambient_energy": environment.ambient_light_energy,
			"glow": environment.glow_enabled, "ssao": environment.ssao_enabled, "ssil": environment.ssil_enabled,
			"sdfgi": environment.sdfgi_enabled, "ssr": environment.ssr_enabled,
			"volumetric_fog": environment.volumetric_fog_enabled, "fog": environment.fog_enabled,
			"fog_density": environment.fog_density, "adjustments": environment.adjustment_enabled,
			"sky_radiance": environment.sky.radiance_size if environment.sky else null}
	return {"renderer": renderer_info(), "profile": RenderProfile.current_profile(),
		"applied_profile": RenderProfile.last_applied(),
		"viewport": {"size": [viewport.get_visible_rect().size.x, viewport.get_visible_rect().size.y],
			"scaling_3d_scale": viewport.scaling_3d_scale, "scaling_3d_mode": viewport.scaling_3d_mode,
			"msaa_3d": viewport.msaa_3d, "screen_space_aa": viewport.screen_space_aa, "use_taa": viewport.use_taa,
			"mesh_lod_threshold": viewport.mesh_lod_threshold,
			"positional_shadow_atlas_size": viewport.positional_shadow_atlas_size,
			"anisotropic_filtering_level": viewport.anisotropic_filtering_level},
		"camera": {"set": cameras().source, "transform": str(camera.global_transform) if camera else "", "fov": camera.fov if camera else 0.0,
			"position": [camera.global_position.x, camera.global_position.y, camera.global_position.z] if camera else [],
			"near": camera.near if camera else 0.0, "far": camera.far if camera else 0.0},
		"sun": sun, "lights": lights, "environment": env}


## Source files behind what the scene actually instantiated: scenes, meshes and
## textures, each with the SHA-256 of its res:// source file.
static func loaded_assets(scene: Node) -> Dictionary:
	var paths := {}
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if not node.scene_file_path.is_empty():
			paths[node.scene_file_path] = "scene"
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mesh: Mesh = (node as MeshInstance3D).mesh
			_note(paths, mesh.resource_path, "mesh")
			for surface in mesh.get_surface_count():
				_note_material(paths, (node as MeshInstance3D).get_active_material(surface))
		elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null and (node as MultiMeshInstance3D).multimesh.mesh != null:
			var batch: Mesh = (node as MultiMeshInstance3D).multimesh.mesh
			_note(paths, batch.resource_path, "mesh")
			for surface in batch.get_surface_count():
				_note_material(paths, batch.surface_get_material(surface))
			_note_material(paths, (node as GeometryInstance3D).material_override)
	var entries := []
	var keys := paths.keys()
	keys.sort()
	for path: String in keys:
		entries.append({"path": path, "kind": paths[path],
			"sha256": FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""})
	return {"count": entries.size(), "files": entries}


static func _note(paths: Dictionary, resource_path: String, kind: String) -> void:
	if resource_path.is_empty():
		return
	var file := resource_path.get_slice("::", 0)
	if file.begins_with("res://") and not paths.has(file):
		paths[file] = kind


static func _note_material(paths: Dictionary, material: Material) -> void:
	if material == null:
		return
	_note(paths, material.resource_path, "material")
	if material is BaseMaterial3D:
		for slot in [BaseMaterial3D.TEXTURE_ALBEDO, BaseMaterial3D.TEXTURE_NORMAL, BaseMaterial3D.TEXTURE_ORM,
				BaseMaterial3D.TEXTURE_ROUGHNESS, BaseMaterial3D.TEXTURE_METALLIC, BaseMaterial3D.TEXTURE_EMISSION,
				BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION, BaseMaterial3D.TEXTURE_DETAIL_ALBEDO, BaseMaterial3D.TEXTURE_DETAIL_NORMAL]:
			var texture: Texture2D = (material as BaseMaterial3D).get_texture(slot)
			if texture != null:
				_note(paths, texture.resource_path, "texture")
	elif material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		if shader_material.shader != null:
			_note(paths, shader_material.shader.resource_path, "shader")
			for uniform in shader_material.shader.get_shader_uniform_list():
				var value: Variant = shader_material.get_shader_parameter(uniform.name)
				if value is Texture:
					_note(paths, (value as Texture).resource_path, "texture")
