extends SceneTree
## Reproduzierbare Prüfszenen, kein durchgespielter Weg und keine FPS-Messung.
## Alle Missionsstände entstehen durch WorldModel-Befehle. Nur die Anreise wird
## als ausdrücklich protokolliertes Fixture platziert. Auf Basis und Änderung
## läuft dieselbe externe Datei mit denselben Kameras und Grafikparametern.

const WorldModel = preload("res://scripts/domain/world_model.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const I03Support = preload("res://tests/i03_support.gd")
const Life = preload("res://scripts/story/village_life.gd")
const World = preload("res://scripts/world/game_world.gd")
const Interface = preload("res://scripts/ui/game_ui.gd")
const STEP := 1.0 / 60.0
const FOLLOW_STEPS := 3600
const SHOTS := [
	{"id":"01_schmiede_i04", "stage":"deliver_kindling", "actor":"silvanus",
		"player":Vector3(31.0,0.9,-24.6), "camera":Vector3(26.3,2.6,-19.5), "look":Vector3(32.0,1.25,-25.2), "fov":60.0},
	{"id":"02_markt_i06", "stage":"market_trade", "actor":"marcus",
		"player":Vector3(22.0,0.9,27.1), "camera":Vector3(29.0,3.2,31.5), "look":Vector3(23.0,1.1,26.0), "fov":60.0},
	{"id":"03_wachmann_i07", "stage":"deliver_medicine", "actor":"severus", "dialogue":true,
		"player":Vector3(9.0,0.9,20.2), "camera":Vector3(5.5,2.6,24.0), "look":Vector3(10.0,1.15,18.5), "fov":58.0},
	{"id":"04_nordweg_i08", "stage":"i08_tracks", "actor":"marcus",
		"player":Vector3(0.0,0.9,-34.2), "camera":Vector3(6.0,3.0,-29.5), "look":Vector3(0.0,1.1,-34.2), "fov":58.0},
	{"id":"05_abend_i09", "stage":"night_rest", "actor":"marcus",
		"player":Vector3(-11.0,0.9,15.7), "camera":Vector3(-6.0,2.9,20.9), "look":Vector3(-13.3,1.1,15.9), "fov":60.0}
]

var output := ""
var check_only := false
var expect_companions := false
var errors: Array[String] = []
var commands: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var checks := 0
var world
var ui


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg == "--check-only":
			check_only = true
		elif arg == "--expect-companions":
			expect_companions = true
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1" or output.is_empty():
		printerr("Isolierte Nutzerdaten und --output sind erforderlich.")
		quit(2)
		return
	if not check_only and DisplayServer.get_name() == "headless":
		printerr("Bildnachweise benötigen einen echten grafischen Treiber.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	_run.call_deferred()


func _run() -> void:
	seed(20261124)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	if not check_only:
		_check(RenderingServer.get_current_rendering_method() == "gl_compatibility", "Produktiver Compatibility-Renderer")
	var model = WorldModel.new()
	model.new_game("italia", true, true)
	for spec: Dictionary in SHOTS:
		if not _until(model, str(spec.stage), "friend"):
			break
		var current: Dictionary = Childhood.view(model.data)
		var target := str(current.get("target_npc", ""))
		if not target.is_empty() and not _meet(model, target):
			break
		await _capture_scene(model.data, spec, "friend")
		if not errors.is_empty():
			break
	# Freund und Rivale werden in I-03 gewählt, niemals nachträglich umgeschrieben.
	if errors.is_empty():
		var rival = WorldModel.new()
		rival.new_game("italia", true, true)
		if _until(rival, "market_trade", "rival"):
			var spec: Dictionary = SHOTS[1].duplicate(true)
			spec.id = "06_markt_rivale_i06"
			await _capture_scene(rival.data, spec, "rival")
	_write_report()
	for message: String in errors:
		printerr("COMPANION_REVIEW_FAIL: " + message)
	print("COMPANION_REVIEW_PASS" if errors.is_empty() else "COMPANION_REVIEW_FAIL")
	quit(0 if errors.is_empty() else 1)


func _capture_scene(source: Dictionary, spec: Dictionary, relation: String) -> void:
	seed(20261124)
	var state := source.duplicate(true)
	state.player.position = _vector(spec.player)
	world = World.new()
	root.add_child(world)
	world.setup(state)
	world.set_quality("balanced")
	world.set_active(true)
	ui = Interface.new()
	root.add_child(ui)
	ui.set_quality("balanced")
	ui.hide()
	# Die Kulisse und übrigen Darsteller bleiben auf dem gespeicherten Stand.
	# Nur das produktive Begleitsystem darf während dieser Wartephase laufen.
	_freeze_processes(world)
	for index in 3:
		await physics_frame
	var has_follow: bool = world.has_method("_update_story_companions")
	if expect_companions:
		_check(has_follow, "Produktive Begleitsteuerung vorhanden")
	if has_follow and str(spec.actor) in ["marcus", "silvanus"]:
		for index in FOLLOW_STEPS:
			await physics_frame
			world.call("_update_story_companions", STEP)
	world.set_presentation_time(4.0)
	var camera: Camera3D = world._camera
	camera.position = spec.camera
	camera.look_at(spec.look)
	camera.fov = float(spec.fov)
	camera.current = true
	for figure: Node in get_nodes_in_group("village_people"):
		if world.is_ancestor_of(figure):
			if figure.has_method("refresh_lod"):
				figure.call("refresh_lod", camera)
			if figure.has_method("sample_pose"):
				figure.call("sample_pose", "idle", 0.25)
	world.village_life_world._update_nameplates()
	var actor: Node3D = world._companion if spec.actor == "marcus" else world.village_life_world.actors.get(spec.actor)
	_check(actor != null and actor.is_visible_in_tree(), "Darsteller sichtbar: " + str(spec.actor))
	var actor_position := actor.global_position if actor != null else Vector3.ZERO
	var actor_screen := camera.unproject_position(actor_position + Vector3.UP)
	var distance := Vector2(actor_position.x,actor_position.z).distance_to(Vector2(spec.player.x,spec.player.z))
	if expect_companions and str(spec.actor) in ["marcus", "silvanus"]:
		_check(distance <= 5.0, "%s erreicht Prüfszene %s (%.3f m)" % [spec.actor,spec.id,distance])
		_check(not camera.is_position_behind(actor_position + Vector3.UP), "Begleiter vor Kamera: " + str(spec.id))
		_check(Rect2(24,24,1232,672).has_point(actor_screen), "Begleiter im Bildausschnitt: " + str(spec.id))
	var dialog: Dictionary = _dialogue(state, str(spec.actor))
	if bool(spec.get("dialogue", false)) and not dialog.is_empty():
		ui.show()
		ui.show_village_dialog(dialog)
	var record := {
		"id":str(spec.id), "stage":str(spec.stage), "relation":relation,
		"quality":"balanced", "output_pixels":[1280,720],
		"camera":{"position":_vector(spec.camera), "look_at":_vector(spec.look), "fov":float(spec.fov),
			"transform":_transform(camera.global_transform)},
		"fixture_player_position":_vector(spec.player), "player_position":_vector(world.get_player_position()),
		"actor":str(spec.actor), "actor_position":_vector(actor_position), "actor_distance_m":distance,
		"actor_screen_position":[actor_screen.x,actor_screen.y],
		"companion_controller_present":has_follow, "follow_simulation_steps":FOLLOW_STEPS if has_follow and str(spec.actor) in ["marcus","silvanus"] else 0,
		"world_sha256":JSON.stringify(state).sha256_text(), "fixture_progress_sha256":_progress_hash(state),
		"dialogue":dialog, "dialogue_visible":bool(spec.get("dialogue",false)) and not dialog.is_empty(),
		"presentation_time":4.0, "pose":{"name":"idle", "seconds":0.25}}
	await _write_image(record)
	shots.append(record)
	if spec.actor == "marcus" and spec.stage in ["market_trade", "night_rest"]:
		# Die Basis besitzt hier noch kein Gespräch. Kein Ersatztext wird erfunden.
		if not dialog.is_empty():
			ui.show()
			ui.show_village_dialog(dialog)
		else:
			ui.hide()
		var conversation: Dictionary = record.duplicate(true)
		conversation.id = str(spec.id) + "_dialog"
		conversation.dialogue_visible = not dialog.is_empty()
		await _write_image(conversation)
		shots.append(conversation)
		if expect_companions:
			_check(not dialog.is_empty(), "Produktives Begleitgespräch: " + str(spec.id))
	ui.free()
	world.free()
	await process_frame


func _write_image(record: Dictionary) -> void:
	if check_only:
		return
	for frame in 3:
		await process_frame
		RenderingServer.force_draw(true, STEP)
	var picture := root.get_texture().get_image()
	_check(picture != null and not picture.is_empty(), "Viewport liefert Bild: " + str(record.id))
	if picture == null or picture.is_empty():
		return
	_check(picture.get_size() == Vector2i(1280,720), "Unveränderte Bildauflösung: " + str(record.id))
	var filename := str(record.id) + ".png"
	var path := output.path_join(filename)
	_check(picture.save_png(path) == OK, "PNG gespeichert: " + filename)
	record["image"] = filename
	record["image_sha256"] = FileAccess.get_sha256(path)


func _until(model, wanted: String, relation: String) -> bool:
	for index in Childhood.STEPS.size() + 24:
		if str(Childhood.view(model.data).get("stage", "")) == wanted:
			return true
		if not _complete(model, relation):
			return false
	_check(false, "Prüfschritt erreichbar: " + wanted)
	return false


func _complete(model, relation: String) -> bool:
	var view: Dictionary = Childhood.view(model.data)
	if str(view.get("stage", "")).begins_with("i03_"):
		return bool(I03Support.play_stage(model, I03Support.RIVAL if relation == "rival" else I03Support.FRIEND).get("ok", false))
	if not view.has("point"):
		_check(false, "Aktiver Auftrag mit Zielpunkt")
		return false
	_place(model, view.point)
	var target := str(view.get("target_npc", ""))
	if not target.is_empty() and not _meet(model, target):
		return false
	var stage := str(view.stage)
	if float(view.get("work_required", 0.0)) > 0.0:
		if not _command(model, "village_childhood_action", {"action_id":"begin_" + stage}):
			return false
		model.advance(float(view.work_required))
	view = Childhood.view(model.data)
	var actions: Array = view.get("actions", [])
	if actions.is_empty():
		_check(false, "Ausführbarer Auftrag: " + stage)
		return false
	var action := str(actions[0].payload.action_id)
	if stage == "market_trade":
		action = "market_fair"
	return _command(model, "village_childhood_action", {"action_id":action})


func _meet(model, id: String) -> bool:
	_place(model, Life.actor_position(model.data, id))
	return true if Life.relationship(model.data, id).get("met", false) else _command(model, "village_talk", {"npc_id":id,"choice":"meet"})


func _place(model, point: Vector2) -> void:
	model.set_player_position(Vector3(point.x,1.0,point.y))


func _command(model, command: String, payload: Dictionary) -> bool:
	var result: Dictionary = model.execute(command, payload)
	commands.append({"command":command, "payload":payload, "ok":result.get("ok", false),
		"fixture_player_position":model.data.player.position.duplicate(), "stage_after":Childhood.view(model.data).get("stage", "")})
	_check(bool(result.get("ok", false)), command + " " + str(payload) + ": " + str(result.get("message", "")))
	return bool(result.get("ok", false))


func _progress_hash(state: Dictionary) -> String:
	return JSON.stringify({"stage":Childhood.view(state).get("stage", ""),
		"completed":state.village.childhood.completed, "screenplay":state.village.childhood.screenplay,
		"carried":state.village.childhood.carried, "choice":state.companion.choice,
		"age":state.player.age, "day":state.village.childhood.day}).sha256_text()


func _dialogue(state: Dictionary, id: String) -> Dictionary:
	# Die Basis besitzt keine neue statische Methode. Dynamische Abfrage an
	# einer Instanz hält genau dieselbe Review-Datei auf beiden Ständen lauffähig.
	var chapter = Childhood.new()
	if chapter.has_method("companion_dialogue"):
		var companion: Dictionary = chapter.call("companion_dialogue", state, id)
		if not companion.is_empty():
			return companion
	return Life.dialogue(state, id)


func _freeze_processes(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		_freeze_processes(child)


func _vector(value: Vector3) -> Array:
	return [value.x,value.y,value.z]


func _transform(value: Transform3D) -> Array:
	return [_vector(value.basis.x),_vector(value.basis.y),_vector(value.basis.z),_vector(value.origin)]


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		errors.append(message)


func _write_report() -> void:
	var report := {"schema_version":1, "engine":Engine.get_version_info().string,
		"renderer":RenderingServer.get_current_rendering_method(), "driver":RenderingServer.get_current_rendering_driver_name(),
		"adapter":RenderingServer.get_video_adapter_name(), "check_only":check_only,
		"capture_scope":"WorldModel-Aufträge und reale GameWorld/GameUI-Prüfszenen; Fixture-Anreisen, kein Spielzeit- oder FPS-Nachweis",
		"fixture_travel":true, "measured_playthrough":false, "android_device_test":false,
		"review_script_sha256":FileAccess.get_sha256(get_script().resource_path),
		"passed":errors.is_empty(), "checks":checks, "errors":errors, "shots":shots, "commands":commands}
	var file := FileAccess.open(output.path_join("companion-review.json"), FileAccess.WRITE)
	if file == null:
		printerr("Prüfbericht konnte nicht geschrieben werden.")
		errors.append("Berichtsdatei nicht schreibbar")
		return
	file.store_string(JSON.stringify(report,"  ") + "\n")
	file.close()
