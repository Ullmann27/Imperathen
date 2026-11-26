extends SceneTree
## Render evidence for the shop equipment (owner rule D-038): close-up, quality
## tiers, LOD tiers and source-versus-runtime with one fixed camera per item,
## plus the pieces carried on the adult player. Run with a real renderer:
##   godot --path prototype --resolution 1280x720 --script res://tests/gear_review.gd -- <output dir> <commit> [set]
## set: items | tiers | character | all (default all); one set per lock slot.

const Gear = preload("res://scripts/domain/gear_market.gd")
const Visuals = preload("res://scripts/visuals/gear_visuals.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const ITEMS := ["gladius", "pugio", "pilum", "spear", "cavalry_lance", "hand_axe", "sling", "scutum", "round_shield", "cavalry_shield", "riding_horse", "spatha"]
const PROPS := ["resource_firewood", "resource_iron_ore", "resource_clay", "resource_limestone", "resource_copper_ore"]
var output := "user://gear_review"
var commit := "unknown"
var selection := "all"
var stage: Node3D
var camera: Camera3D
var records: Array = []
var frame_ms: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		output = args[0]
	if args.size() > 1:
		commit = args[1]
	if args.size() > 2:
		selection = args[2]
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _studio() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.16, 0.17, 0.19)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8, 0.85, 0.95)
	environment.environment.ambient_light_energy = 0.55
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 148, 0)
	key.light_color = Color(1.0, 0.93, 0.82)
	key.light_energy = 1.15
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, -60, 0)
	fill.light_color = Color(0.7, 0.8, 1.0)
	fill.light_energy = 0.35
	stage.add_child(fill)
	var floor := MeshInstance3D.new()
	floor.mesh = PlaneMesh.new()
	(floor.mesh as PlaneMesh).size = Vector2(30, 30)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.2, 0.21)
	material.roughness = 0.9
	floor.material_override = material
	floor.name = "Floor"
	stage.add_child(floor)
	camera = Camera3D.new()
	camera.fov = 30
	stage.add_child(camera)
	camera.current = true


func _bounds(nodes: Array) -> AABB:
	var result := AABB()
	var first := true
	for node: Node3D in nodes:
		for value: Node in node.find_children("*", "MeshInstance3D", true, false):
			var shape := value as MeshInstance3D
			if shape.mesh == null or not shape.is_visible_in_tree():
				continue
			var box: AABB = shape.global_transform * shape.mesh.get_aabb()
			result = box if first else result.merge(box)
			first = false
	return result


func _frame(box: AABB, direction: Vector3, margin := 1.12) -> Dictionary:
	var centre := box.get_center()
	var radius := box.size.length() * 0.5 * margin
	var aspect := float(root.size.x) / float(root.size.y)
	var half := deg_to_rad(camera.fov) * 0.5
	var distance := radius / sin(minf(half, atan(tan(half) * aspect)))
	camera.position = centre + direction.normalized() * distance
	camera.look_at(centre)
	camera.near = maxf(0.01, distance - radius * 2.0)
	camera.far = distance + radius * 4.0 + 30.0
	return {"position": [snappedf(camera.position.x, 0.001), snappedf(camera.position.y, 0.001), snappedf(camera.position.z, 0.001)],
		"look_at": [snappedf(centre.x, 0.001), snappedf(centre.y, 0.001), snappedf(centre.z, 0.001)], "fov": camera.fov}


func _sha(path: String) -> String:
	var file := ProjectSettings.globalize_path(path)
	return FileAccess.get_sha256(file) if FileAccess.file_exists(file) else ""


func _shot(label: String, camera_record: Dictionary, models: Array, note: String) -> void:
	for frame in 4:
		await RenderingServer.frame_post_draw
	var started := Time.get_ticks_usec()
	for frame in 4:
		await RenderingServer.frame_post_draw
	frame_ms.append(float(Time.get_ticks_usec() - started) / 4000.0)
	var image := root.get_texture().get_image()
	var path := output.path_join(label + ".png")
	var saved := image != null and not image.is_empty() and image.save_png(path) == OK
	var loaded := []
	for model: String in models:
		loaded.append({"path": model, "sha256": _sha(model)})
	records.append({"image": label + ".png", "saved": saved, "camera": camera_record, "models": loaded, "note": note,
		"draw_calls": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))})
	print("GEAR_REVIEW_SHOT ", label, " ", saved)


## Lays a prop flat-on to the camera: long hand weapons stand, shields face it.
func _place(prop: Node3D, x: float, ground := true) -> void:
	stage.add_child(prop)
	prop.position = Vector3(x, 0, 0)
	var box := _bounds([prop])
	prop.position.y += (0.02 - box.position.y) if ground else 0.0


func _clear(nodes: Array) -> void:
	for node: Node in nodes:
		stage.remove_child(node)
		node.free()


func _source(model: String) -> Node3D:
	# Raw Meshy download, loaded at runtime (the source folder is not imported).
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/meshy/gear_profiles.json"))
	var lock: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/meshy/lock.json"))
	if not lock.assets.has(model):
		return null
	var path := ProjectSettings.globalize_path("res://").path_join("..").path_join(str(lock.assets[model].path))
	if not FileAccess.file_exists(path):
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return null
	var scene := document.generate_scene(state) as Node3D
	var holder := Node3D.new()
	holder.add_child(scene)
	var up := str(profiles.assets.get(model, {}).get("up", "+z"))
	var axis: Vector3 = {"+x": Vector3.RIGHT, "-x": Vector3.LEFT, "+z": Vector3.UP, "-z": Vector3.DOWN, "+y": Vector3.FORWARD, "-y": Vector3.BACK}[up]
	if not axis.is_equal_approx(Vector3.UP):
		scene.quaternion = Quaternion(axis, Vector3.UP)
	return holder


func _items() -> void:
	for id: String in ITEMS:
		var entry := Gear.item(id)
		var quality := int(entry.get("fixed_quality", 2))
		var direction := Vector3(0.55, 0.28, 1.0) if str(entry.slot) != "mount" else Vector3(1.0, 0.25, 0.75)
		var prop := Visuals.instantiate(id, quality)
		if prop == null:
			continue
		_place(prop, 0.0)
		var view := _frame(_bounds([prop]), direction)
		await _shot(id + "-closeup", view, [Gear.model_path(id, 0)], "Laufzeitmodell LOD 0, %s" % Gear.quality_name(quality))
		_clear([prop])
		# LOD tiers, one camera.
		var tiers: Array = []
		var paths: Array = []
		var width := 0.0
		for lod in int(entry.lods):
			var tier := Visuals.instantiate(id, quality, lod)
			_place(tier, 0.0)
			width = maxf(width, _bounds([tier]).size.x)
			tiers.append(tier)
			paths.append(Gear.model_path(id, lod))
		for index in tiers.size():
			(tiers[index] as Node3D).position.x = (index - (tiers.size() - 1) * 0.5) * (width * 1.25 + 0.12)
		view = _frame(_bounds(tiers), Vector3(0.25, 0.2, 1.0))
		await _shot(id + "-lods", view, paths, "LOD 0 bis %d von links nach rechts" % (tiers.size() - 1))
		_clear(tiers)
		# Raw source next to the runtime model, one camera.
		var source := _source(str(entry.model))
		if source != null:
			var runtime := Visuals.instantiate(id, quality)
			_place(runtime, 0.0)
			var target := _bounds([runtime])
			stage.add_child(source)
			var raw := _bounds([source])
			var scale := maxf(target.size.x, maxf(target.size.y, target.size.z)) / maxf(raw.size.x, maxf(raw.size.y, raw.size.z))
			source.scale = Vector3.ONE * scale
			raw = _bounds([source])
			var gap := maxf(raw.size.x, target.size.x) * 1.2 + 0.1
			source.position += Vector3(-gap * 0.5 - raw.get_center().x, 0.02 - raw.position.y, -raw.get_center().z)
			runtime.position.x = gap * 0.5
			view = _frame(_bounds([source, runtime]), Vector3(0.25, 0.2, 1.0))
			await _shot(id + "-source-vs-runtime", view, [Gear.model_path(id, 0)], "Links Meshy-Quelle (auf gleiche Länge skaliert), rechts Laufzeitmodell")
			_clear([source, runtime])
	for id: String in PROPS:
		var path := "res://assets/meshy/props/%s_0.glb" % id
		if not ResourceLoader.exists(path, "PackedScene"):
			continue
		var prop := (load(path) as PackedScene).instantiate() as Node3D
		_place(prop, 0.0)
		var view := _frame(_bounds([prop]), Vector3(0.7, 0.45, 1.0))
		await _shot(id + "-closeup", view, [path], "Rohstoff-Requisit LOD 0")
		_clear([prop])


func _tiers() -> void:
	for id: String in ITEMS:
		if Gear.tiers(id).size() < 5:
			continue
		var props: Array = []
		var width := 0.0
		for quality in 5:
			var prop := Visuals.instantiate(id, quality)
			_place(prop, 0.0)
			width = maxf(width, _bounds([prop]).size.x)
			props.append(prop)
		for quality in 5:
			(props[quality] as Node3D).position.x = (quality - 2) * (width * 1.3 + 0.1)
		var view := _frame(_bounds(props), Vector3(0.2, 0.18, 1.0))
		await _shot(id + "-quality", view, [Gear.model_path(id, 0)], "Q0 bis Q4 von links nach rechts")
		if id in ["gladius", "pugio", "spatha", "pilum", "spear"]:
			# Same line-up, camera on the part that carries the fittings: the
			# hilt of a blade stands on the ground, a shaft weapon shows its upper half.
			var box := _bounds(props)
			var part := AABB(Vector3(box.position.x, 0.0, box.position.z), Vector3(box.size.x, minf(box.size.y, 0.3), box.size.z))
			if id in ["pilum", "spear"]:
				part = AABB(Vector3(box.position.x, box.size.y * 0.5, box.position.z), Vector3(box.size.x, box.size.y * 0.5, box.size.z))
			view = _frame(part, Vector3(0.2, 0.25, 1.0), 1.0)
			await _shot(id + "-quality-detail", view, [Gear.model_path(id, 0)], "Q0 bis Q4, Ausschnitt mit Griff beziehungsweise oberem Schaft")
		_clear(props)


func _character() -> void:
	var pieces: Array = [
		{"slot": "main_hand", "item_id": "gladius", "quality": 3, "wear": 0.0, "model": "weap_roman_gladius_pompeii", "model_dir": "equipment", "lods": 3, "attach": "hand_right"},
		{"slot": "sidearm", "item_id": "pugio", "quality": 2, "wear": 0.0, "model": "weap_roman_pugio", "model_dir": "equipment", "lods": 3, "attach": "hip_right"},
		{"slot": "missile", "item_id": "pilum", "quality": 2, "wear": 0.0, "model": "weap_roman_pilum", "model_dir": "equipment", "lods": 3, "attach": "hand_right"},
		{"slot": "shield", "item_id": "scutum", "quality": 2, "wear": 0.0, "model": "gear_roman_scutum", "model_dir": "equipment", "lods": 3, "attach": "hand_left"}]
	var models: Array = []
	for piece: Dictionary in pieces:
		models.append(Gear.model_path(str(piece.item_id), 0))
	var actor := Person.new()
	stage.add_child(actor)
	actor.configure("player", "italia", 18)
	actor.position = Vector3(0, 0.9, 0)
	actor.rotation.y = PI
	for frame in 10:
		await process_frame
	var body_box := AABB(Vector3(-1.1, 0.0, -0.8), Vector3(2.2, 3.0, 1.6))
	var views := {
		"front": [body_box, Vector3(0.45, 0.1, 1.0)],
		"side": [body_box, Vector3(-1.0, 0.1, 0.35)],
		"back": [body_box, Vector3(-0.35, 0.12, -1.0)],
		"hand": [AABB(Vector3(-0.75, 0.55, -0.35), Vector3(0.7, 1.0, 0.7)), Vector3(0.9, 0.15, 1.0)]}
	models.append(actor.active_model_path)
	for label: String in views:
		actor.set_market_gear([])
		var view := _frame(views[label][0], views[label][1], 1.0)
		await _shot("equipped-%s-before" % label, view, [actor.active_model_path], "Erwachsener Spieler ohne gekaufte Ausrüstung")
		actor.set_market_gear(pieces)
		await _shot("equipped-%s-after" % label, view, models, "Gladius Q3 in der Hand, Scutum Q2, Pugio Q2 an der Hüfte, Pilum Q2 auf dem Rücken")
	actor._reload(3)
	var far := _frame(AABB(Vector3(-4.0, 0.0, -1.0), Vector3(8.0, 4.5, 2.0)), Vector3(0.3, 0.1, 1.0), 1.0)
	await _shot("equipped-far-lod", far, models, "Körper-LOD 3 mit Fernstufen der Ausrüstung")
	# The same world state the game uses: the adult's walk with gear in hand.
	actor._reload(0)
	actor.drive(1.0)
	for frame in 24:
		actor._process(1.0 / 60.0)
		await process_frame
	var walk := _frame(body_box, Vector3(0.45, 0.1, 1.0), 1.0)
	await _shot("equipped-walk", walk, models, "Gehzyklus nach 0,4 s mit getragener Ausrüstung")
	_clear([actor])
	# Stable view: the horse with a person-high reference post.
	var horse := Visuals.instantiate("riding_horse", 2)
	_place(horse, 0.0)
	var post := MeshInstance3D.new()
	post.mesh = BoxMesh.new()
	(post.mesh as BoxMesh).size = Vector3(0.06, 1.75, 0.06)
	stage.add_child(post)
	post.position = Vector3(-1.5, 0.875, 0)
	var view := _frame(_bounds([horse, post]), Vector3(1.0, 0.18, 0.9))
	await _shot("stable-horse-scale", view, [Gear.model_path("riding_horse", 0)], "Brauner neben einer 1,75 m hohen Messlatte")
	_clear([horse, post])


func _run() -> void:
	_studio()
	if selection in ["all", "items"]:
		await _items()
	if selection in ["all", "tiers"]:
		await _tiers()
	if selection in ["all", "character"]:
		await _character()
	frame_ms.sort()
	var report := {
		"schema": "imperathen-render-evidence-d038", "set": selection, "source_commit": commit,
		"profile": "Studio-Abnahme, Projektvoreinstellung", "rendering_method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		"renderer": {"adapter": RenderingServer.get_video_adapter_name(), "vendor": RenderingServer.get_video_adapter_vendor(),
			"api_version": RenderingServer.get_video_adapter_api_version(), "driver": OS.get_video_adapter_driver_info()},
		"engine": Engine.get_version_info().string, "resolution": [root.size.x, root.size.y],
		"lighting": "Hauptlicht 1,15 (warm, -38°/148°, Schatten), Aufhellung 0,35 (kühl), Umgebungsfarbe 0,55, filmischer Tonemapper, grauer Boden",
		"memory": {"static_bytes": OS.get_static_memory_usage(), "static_peak_bytes": OS.get_static_memory_peak_usage(),
			"texture_bytes": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)),
			"buffer_bytes": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)),
			"video_bytes": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED))},
		"performance": {"frame_ms_median": frame_ms[frame_ms.size() / 2] if not frame_ms.is_empty() else 0.0,
			"frame_ms_max": frame_ms[-1] if not frame_ms.is_empty() else 0.0,
			"environment": "Xvfb mit Software-Rasterizer auf einer stark belasteten 4-Kern-Maschine; nur relative Werte, keine Geräteaussage"},
		"shots": records}
	var file := FileAccess.open(output.path_join("review-%s.json" % selection), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	var missing := 0
	for record: Dictionary in records:
		missing += int(not record.saved)
	print("GEAR_REVIEW_DONE set=%s shots=%d missing=%d" % [selection, records.size(), missing])
	quit(0 if missing == 0 and not records.is_empty() else 1)
