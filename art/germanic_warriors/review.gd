extends SceneTree
## Godot engine review of the Germanic warrior families next to the existing
## Roman frontier figures and the Meshy axe fighter.
##
## godot --path prototype --rendering-method gl_compatibility --resolution 1280x720 \
##   --script "$PWD/art/germanic_warriors/review.gd" -- balanced /tmp/out
##
## The Germanic GLBs are read from art/germanic_warriors/export with
## GLTFDocument (they are not in the runtime tree yet); Roman and Meshy figures
## are the imported production scenes. Quality settings follow
## prototype/assets/quality_profiles.json exactly as RuntimeDisplay.apply_quality
## applies them (MSAA, mesh LOD threshold, shadow atlas, 3D render scale).

const MeshyEquipment = preload("res://scripts/visuals/meshy_equipment.gd")
const ROMANS := [
	["frontier_legionary", "res://assets/characters/frontier_legionary_0.glb"],
	["frontier_spearman", "res://assets/characters/frontier_spearman_0.glb"],
	["frontier_officer", "res://assets/characters/frontier_officer_0.glb"],
]
const AXE := "res://assets/meshy/characters/unit_germanic_axe_fighter_0.glb"

var profile := "balanced"
var out_dir := ""
var art := ""
var registry: Dictionary
var profiles: Dictionary
var cam: Camera3D
var notes: Array[String] = []


var _elapsed := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _process(delta: float) -> bool:
	# A script error inside the coroutine would otherwise leave the engine
	# running until the outer timeout; stop after a fixed budget instead.
	_elapsed += delta
	if _elapsed > 1200.0:
		push_error("GERMANIC_REVIEW_TIMEOUT notes=" + str(notes))
		quit(3)
	return false


func _instance(path: String) -> Node3D:
	var scene := load(path) as PackedScene
	if scene == null:
		notes.append("cannot load " + path)
		return null
	var node := scene.instantiate() as Node3D
	root.add_child(node)
	return node


func _gltf(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		notes.append("load failed " + path)
		return null
	return doc.generate_scene(state) as Node3D


func _pose(model: Node3D, clip: String, seconds: float) -> void:
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		notes.append("no AnimationPlayer in " + model.name)
		return
	var name := clip
	if not player.has_animation(name):
		for candidate: StringName in player.get_animation_list():
			if String(candidate).ends_with(clip):
				name = String(candidate)
	if not player.has_animation(name):
		notes.append("missing clip %s in %s" % [clip, model.name])
		return
	player.play(name)
	player.seek(seconds, true)
	player.pause()


func _apply_profile(size: Vector2i) -> void:
	var s: Dictionary = profiles[profile]
	var vp := root
	vp.mesh_lod_threshold = float(s.mesh_lod_threshold)
	vp.msaa_3d = Viewport.MSAA_4X if int(s.msaa_samples) == 4 else (Viewport.MSAA_2X if int(s.msaa_samples) == 2 else Viewport.MSAA_DISABLED)
	RenderingServer.directional_shadow_atlas_set_size(int(s.shadow_atlas_size), true)
	var budget: float = s.get("desktop_max_3d_pixels", s.max_3d_pixels)
	vp.scaling_3d_scale = clampf(sqrt(budget / float(size.x * size.y)), 0.25, 1.0)


func _stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#5f7c97")
	sky_material.sky_horizon_color = Color("#b9b6a6")
	sky_material.ground_horizon_color = Color("#8d8676")
	sky_material.ground_bottom_color = Color("#3e3a33")
	sky.sky_material = sky_material
	env.environment.background_mode = Environment.BG_SKY
	env.environment.sky = sky
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment.ambient_light_energy = 0.75
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.glow_enabled = bool(profiles[profile].glow)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.light_energy = 1.35
	sun.light_color = Color("#fff1dc")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = float(profiles[profile].shadow_distance_metres)
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_energy = 0.35
	fill.light_color = Color("#bcd0ff")
	root.add_child(fill)
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	(ground.mesh as PlaneMesh).size = Vector2(60, 60)
	var material := StandardMaterial3D.new()
	var noise := NoiseTexture2D.new()
	noise.width = 512
	noise.height = 512
	noise.seamless = true
	noise.noise = FastNoiseLite.new()
	noise.noise.frequency = 0.02
	material.albedo_texture = noise
	material.albedo_color = Color("#6f6a55")
	material.uv1_scale = Vector3(14, 14, 14)
	material.roughness = 0.95
	ground.material_override = material
	root.add_child(ground)
	cam = Camera3D.new()
	cam.fov = 38
	root.add_child(cam)


func _capture(name: String) -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not name.is_empty():
		image.save_png(out_dir.path_join(name + ".png"))
	return image


func _figure(id: String) -> Node3D:
	var model := _gltf(art.path_join("export/figures/germanic_%s_0.glb" % id))
	if model:
		model.name = id
		root.add_child(model)
	return model


func _clear(nodes: Array) -> void:
	for node: Node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	await process_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	profile = args[0] if args.size() > 0 else "balanced"
	out_dir = args[1] if args.size() > 1 else "/tmp/germanic_review"
	DirAccess.make_dir_recursive_absolute(out_dir)
	art = ProjectSettings.globalize_path("res://").path_join("../art/germanic_warriors").simplify_path()
	registry = JSON.parse_string(FileAccess.get_file_as_string(art.path_join("registry.json")))
	profiles = JSON.parse_string(FileAccess.get_file_as_string("res://assets/quality_profiles.json")).profiles
	var size := root.size
	_apply_profile(size)
	_stage()
	var tag := "%s_%dx%d" % [profile, size.x, size.y]
	var figures: Array = registry.figures

	# 1. Line-up: river kin, forest kin, then the Meshy axe fighter and the Romans.
	var placed: Array = []
	var x := 0.0
	var order: Array = []
	for group in ["river_kin", "forest_kin"]:
		for f: Dictionary in figures:
			if f.group == group:
				order.append(f.id)
	for id: String in order:
		var m := _figure(id)
		if m:
			m.position = Vector3(x, 0, 0)
			_pose(m, "idle", 0.6)
			placed.append(m)
		x += 0.95
	x += 0.5
	var axe := _instance(AXE)
	if axe:
		axe.rotation.y = 0.0
		axe.position = Vector3(x, 0, 0)
		MeshyEquipment.attach(axe, "unit_germanic_axe_fighter", 0)
		_pose(axe, "idle", 0.6)
		placed.append(axe)
	x += 1.25
	for roman: Array in ROMANS:
		var r := _instance(roman[1])
		if r:
			r.position = Vector3(x, 0, 0)
			_pose(r, "idle", 0.6)
			placed.append(r)
		x += 0.95
	var centre := (x - 0.95) * 0.5
	cam.position = Vector3(centre, 1.6, 15.5 * maxf(1.0, 0.75 * float(size.y) / float(size.x) * 16.0 / 9.0))
	cam.look_at(Vector3(centre, 0.95, 0))
	await _capture("lineup_" + tag)
	await _clear(placed)

	# 2. Side-by-side comparison with the Roman figures (same light, same pose).
	placed = []
	var compare := ["river_spear", "forest_spear", "river_retinue", "forest_swordsman"]
	x = 0.0
	for id: String in compare:
		var m := _figure(id)
		if m:
			m.position = Vector3(x, 0, 0)
			m.rotation.y = 0.25
			_pose(m, "idle", 0.6)
			placed.append(m)
		x += 1.05
	axe = _instance(AXE)
	if axe:
		axe.rotation.y = 0.25
		axe.position = Vector3(x, 0, 0)
		MeshyEquipment.attach(axe, "unit_germanic_axe_fighter", 0)
		_pose(axe, "idle", 0.6)
		placed.append(axe)
	x += 1.15
	for roman: Array in ROMANS.slice(0, 2):
		var r := _instance(roman[1])
		if r:
			r.position = Vector3(x, 0, 0)
			r.rotation.y = 0.25
			_pose(r, "idle", 0.6)
			placed.append(r)
		x += 1.05
	centre = (x - 1.05) * 0.5
	cam.position = Vector3(centre, 1.45, 8.4 * maxf(1.0, float(size.y) / float(size.x) * 1.6))
	cam.look_at(Vector3(centre, 1.0, 0))
	await _capture("compare_romans_" + tag)
	await _clear(placed)

	# 3. Close-ups: head and shoulders of every figure, composed into one sheet.
	var cols := 5
	var tile := Vector2i(size.x / cols, size.y / 2)
	var sheet := Image.create(tile.x * cols, tile.y * 2, false, Image.FORMAT_RGBA8)
	var k := 0
	for id: String in order:
		var m := _figure(id)
		if m == null:
			k += 1
			continue
		_pose(m, "idle", 0.6)
		cam.position = Vector3(0.28, 1.66, 1.05)
		cam.look_at(Vector3(0, 1.56, 0))
		var shot := await _capture("")
		var w := mini(shot.get_width(), int(float(shot.get_height()) * float(tile.x) / float(tile.y)))
		var crop := shot.get_region(Rect2i((shot.get_width() - w) / 2, 0, w, shot.get_height()))
		crop.resize(tile.x, tile.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i((k % cols) * tile.x, (k / cols) * tile.y))
		await _clear([m])
		k += 1
	sheet.save_png(out_dir.path_join("closeups_" + tag + ".png"))

	# 4. Turntable (front, three-quarter, side, back) and action poses per figure.
	if args.size() > 2 and args[2] == "turntable":
		for id: String in order:
			var m := _figure(id)
			if m == null:
				continue
			var strip := Image.create(tile.x * 4, size.y, false, Image.FORMAT_RGBA8)
			var angles := [0.0, 0.75, 1.5708, 3.1416]
			for a in 4:
				m.rotation.y = angles[a]
				_pose(m, "idle", 0.6)
				cam.position = Vector3(0, 1.15, 4.2)
				cam.look_at(Vector3(0, 1.0, 0))
				var shot := await _capture("")
				var crop := shot.get_region(Rect2i((shot.get_width() - tile.x) / 2, 0, tile.x, shot.get_height()))
				strip.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(a * tile.x, 0))
			strip.save_png(out_dir.path_join("turntable_%s_%s.png" % [id, tag]))
			var poses := Image.create(tile.x * 4, size.y, false, Image.FORMAT_RGBA8)
			var clips := [["march", 0.25], ["attack", 0.45], ["block", 0.6], ["shoot" if registry.figures.filter(func(f): return f.id == id)[0].family == "skirmisher" else "hit", 0.5]]
			for a in 4:
				m.rotation.y = 0.6
				_pose(m, clips[a][0], clips[a][1])
				cam.position = Vector3(0, 1.15, 4.4)
				cam.look_at(Vector3(0, 1.0, 0))
				var shot := await _capture("")
				var crop := shot.get_region(Rect2i((shot.get_width() - tile.x) / 2, 0, tile.x, shot.get_height()))
				poses.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(a * tile.x, 0))
			poses.save_png(out_dir.path_join("actions_%s_%s.png" % [id, tag]))
			await _clear([m])
	var info := {"profile": profile, "size": [size.x, size.y], "scaling_3d_scale": root.scaling_3d_scale,
		"msaa": root.msaa_3d, "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "notes": notes}
	var file := FileAccess.open(out_dir.path_join("review_%s.json" % tag), FileAccess.WRITE)
	file.store_string(JSON.stringify(info, "  "))
	file.close()
	print("GERMANIC_REVIEW_DONE ", tag, " notes=", notes)
	quit()
