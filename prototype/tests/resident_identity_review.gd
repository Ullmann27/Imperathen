extends SceneTree
## Viewport review of every named village resident through the production
## VillagePerson path: one close-up and one full-body image per person.
## This is a lit studio with the village sun/ambient values, not the live
## village scene, and it makes no device performance claim.
## ++ <output> <profile> [close,talk,full,walk,hand,lineup] [id,id,...]

const Person := preload("res://scripts/visuals/village_person.gd")
const Layout := preload("res://scripts/world/village/village_layout.gd")
const Economy := preload("res://scripts/domain/village_economy.gd")
const PROFILES := ["low", "balanced", "high", "very_high"]
var output := ""
var profile := "balanced"
var shots: Array = ["close", "full"]
var only: Array = []
var stage: Node3D
var camera: Camera3D
var report := {"captures": [], "errors": []}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1" or args.is_empty():
		printerr("A graphical viewport, isolated settings and output directory are required.")
		quit(2)
		return
	output = args[0]
	if args.size() > 1 and args[1] in PROFILES:
		profile = args[1]
	if args.size() > 2:
		shots = Array(args[2].split(",", false))
	if args.size() > 3:
		only = Array(args[3].split(",", false))
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


## The same id, appearance, age and variation the two live builders assign.
static func roster() -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		{"id":"player","name":"Spieler","role":"Jugendlicher","appearance":"","age":12,"variation":0,"source":"player"},
		{"id":"marcus","name":"Marcus","role":"Jugendfreund","appearance":"","age":12,"variation":0,"source":"companion"}]
	var index := 0
	for person: Dictionary in Economy.PEOPLE:
		var id := str(person.id)
		var appearance := "civilian_woman" if id in ["aelia", "aurelia", "cassia", "drusa", "julia", "valeria", "antonia"] else "civilian_man"
		if id == "severus":
			appearance = "legionary"
		result.append({"id": id, "name": str(person.name), "role": str(person.profession), "appearance": appearance,
			"age": 32 + index % 20, "variation": index, "source": "village_life"})
		index += 1
	result.append({"id": "decimus", "name": "Decimus", "role": "Dorfverwalter", "appearance": "elder",
		"age": 32 + index % 20, "variation": index, "source": "village_life"})
	for i in Layout.RESIDENTS.size():
		var item: Dictionary = Layout.RESIDENTS[i]
		result.append({"id": str(item.id), "name": str(item.name), "role": str(item.occupation), "appearance": str(item.appearance),
			"age": int(item.age), "variation": i, "source": "village_population"})
	return result


func _run() -> void:
	var display := root.get_node_or_null("RuntimeDisplay")
	if display and display.has_method("apply_quality"):
		display.apply_quality(profile)
	_build_stage()
	var people := roster()
	report.profile = profile
	report.output_pixels = [root.size.x, root.size.y]
	report.renderer = RenderingServer.get_current_rendering_method()
	report.adapter = RenderingServer.get_video_adapter_name()
	if "lineup" in shots:
		await _lineups(people)
	for entry: Dictionary in people:
		if not only.is_empty() and entry.id not in only:
			continue
		for shot: String in shots:
			if shot in ["close", "talk", "full", "walk", "hand"]:
				await _single(entry, shot)
	var file := FileAccess.open(output.path_join("review-%s-%dx%d.json" % [profile, root.size.x, root.size.y]), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("RESIDENT_IDENTITY_REVIEW ", JSON.stringify(report.errors))
	quit(0 if report.errors.is_empty() else 1)


func _build_stage() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.36, 0.55, 0.78)
	sky_material.sky_horizon_color = Color(0.72, 0.78, 0.80)
	sky_material.ground_horizon_color = Color(0.55, 0.52, 0.45)
	sky.sky_material = sky_material
	environment.sky = sky
	# Same ambient/tonemap values as GameWorld._create_atmosphere().
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.69, 0.77, 0.85)
	environment.ambient_light_energy = 0.58
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = environment
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -28 + 180, 0)
	sun.light_color = Color(1.0, 0.88, 0.69)
	sun.light_energy = 0.46
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	(ground.mesh as PlaneMesh).size = Vector2(40, 40)
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color(0.36, 0.33, 0.26)
	earth.roughness = 0.97
	ground.material_override = earth
	stage.add_child(ground)
	var wall := MeshInstance3D.new()
	wall.mesh = BoxMesh.new()
	(wall.mesh as BoxMesh).size = Vector3(40, 6, 0.2)
	wall.position = Vector3(0, 3, 6.0)
	var plaster := StandardMaterial3D.new()
	plaster.albedo_color = Color(0.70, 0.64, 0.53)
	plaster.roughness = 0.95
	wall.material_override = plaster
	stage.add_child(wall)
	camera = Camera3D.new()
	camera.current = true
	stage.add_child(camera)


func _spawn(entry: Dictionary, at: Vector3) -> Person:
	var actor := Node3D.new()
	actor.position = at
	stage.add_child(actor)
	var figure := Person.new()
	figure.name = "Figure"
	figure.position.y = 0.9
	figure.profile = profile
	actor.add_child(figure)
	figure.set_process(false)
	if str(entry.source) in ["player","companion"]:
		figure.configure(str(entry.source),"italia",int(entry.age))
		if entry.source == "player" and Person.youth_outfit_installed("civil"):
			figure.configure_meshy_youth(true,"civil")
		return figure
	# Newer builds accept the stable resident id; older builds ignore it.
	var arguments := 5
	for method: Dictionary in figure.get_script().get_script_method_list():
		if method.name == "configure_resident":
			arguments = (method.args as Array).size()
	# Dynamic call: the same review script also runs against the older API.
	if arguments >= 6:
		figure.call("configure_resident", "italia", int(entry.age), str(entry.appearance), int(entry.variation), camera, str(entry.id))
	else:
		figure.call("configure_resident", "italia", int(entry.age), str(entry.appearance), int(entry.variation), camera)
	if entry.id == "severus":
		figure.configure_meshy("unit_roman_signifer")
	return figure


func _head(figure: Person) -> Vector3:
	var rig := figure.body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var bone := rig.find_bone("Head")
	return rig.global_transform * rig.get_bone_global_pose(bone).origin if bone >= 0 else figure.global_position + Vector3.UP * 0.6


func _triangles(figure: Person) -> int:
	var count := 0
	for mesh: MeshInstance3D in figure.body.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh and mesh.is_visible_in_tree():
			for surface in mesh.mesh.get_surface_count():
				count += mesh.mesh.surface_get_array_index_len(surface) / 3
	return count


func _bone(figure: Person, bone_name: String) -> Vector3:
	var rig := figure.body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var bone := rig.find_bone(bone_name)
	return rig.global_transform * rig.get_bone_global_pose(bone).origin if bone >= 0 else figure.global_position


## Clip and normalised time of each single shot. The cameras depend only on
## the fifteen joints every build has, so older builds get the same framing.
const POSES := {"close": ["idle", 0.25], "talk": ["talk", 0.42], "full": ["idle", 0.25],
	"walk": ["march", 0.30], "hand": ["work", 0.50]}


func _single(entry: Dictionary, shot: String) -> void:
	var figure := _spawn(entry, Vector3.ZERO)
	var actor := figure.get_parent() as Node3D
	var clip: String = POSES[shot][0]
	var at: float = POSES[shot][1]
	# An unrotated resident faces -Z, toward the studio camera.
	figure.sample_pose(clip, at)
	await process_frame
	var head := _head(figure)
	if shot in ["close", "talk"]:
		camera.fov = 30
		var target := head + Vector3(0, 0.07, 0)
		camera.position = target + Vector3(0.20, 0.03, -0.95)
		camera.look_at(target, Vector3.UP)
	elif shot == "walk":
		camera.fov = 34
		var target := Vector3(0, 0.95, 0)
		camera.position = target + Vector3(2.6, 0.20, -2.9)
		camera.look_at(target, Vector3.UP)
	elif shot == "hand":
		camera.fov = 24
		var target := _bone(figure, "Hand_R") + Vector3(0, -0.04, 0)
		camera.position = target + Vector3(-0.42, 0.10, -0.62)
		camera.look_at(target, Vector3.UP)
	else:
		camera.fov = 34
		var target := Vector3(0, 0.95, 0)
		camera.position = target + Vector3(0.45, 0.15, -3.9)
		camera.look_at(target, Vector3.UP)
	figure.refresh_lod(camera)
	figure.sample_pose(clip, at)
	for i in 4:
		await RenderingServer.frame_post_draw
	var name := "%s-%s-%s-%dx%d.png" % [entry.id, shot, profile, root.size.x, root.size.y]
	if root.get_texture().get_image().save_png(output.path_join(name)) != OK:
		report.errors.append("capture failed " + name)
		actor.free()
		return
	var rig := figure.body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	report.captures.append({"id": entry.id, "name": entry.name, "role": entry.role, "shot": shot, "file": name,
		"clip": clip, "clip_time": at, "joints": rig.get_bone_count(),
		"model": figure.active_model_path, "lod": figure.detail, "visible_triangles": _triangles(figure),
		"camera_distance_m": snappedf(camera.global_position.distance_to(figure.global_position), 0.01)})
	actor.free()


func _lineups(people: Array[Dictionary]) -> void:
	# Six residents per image, side by side at a common distance.
	var groups: Array = []
	var current: Array = []
	for entry: Dictionary in people:
		if not only.is_empty() and entry.id not in only:
			continue
		current.append(entry)
		if current.size() == 6:
			groups.append(current)
			current = []
	if not current.is_empty():
		groups.append(current)
	for group_index in groups.size():
		var actors: Array[Node3D] = []
		var group: Array = groups[group_index]
		camera.fov = 38
		camera.position = Vector3(0, 1.25, -6.8)
		camera.look_at(Vector3(0, 0.95, 0), Vector3.UP)
		for i in group.size():
			var figure := _spawn(group[i], Vector3((i - (group.size() - 1) * 0.5) * 0.95, 0, 0))
			figure.refresh_lod(camera)
			figure.sample_pose("idle", 0.25 + 0.11 * i)
			actors.append(figure.get_parent() as Node3D)
		for i in 4:
			await RenderingServer.frame_post_draw
		var ids: Array = []
		for entry: Dictionary in group: ids.append(entry.id)
		var name := "lineup%02d-%s-%dx%d.png" % [group_index, profile, root.size.x, root.size.y]
		root.get_texture().get_image().save_png(output.path_join(name))
		report.captures.append({"shot": "lineup", "file": name, "ids": ids})
		for actor in actors:
			actor.free()
