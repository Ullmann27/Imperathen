extends SceneTree
## Actual production presentation and world fixtures, rendered for visual review.
## This script records frames. It never grants quality approval or gameplay progress.

const Person = preload("res://scripts/visuals/village_person.gd")
const Motion = preload("res://scripts/visuals/character_motion.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const World = preload("res://scripts/world/game_world.gd")
const Population = preload("res://scripts/world/village/village_population.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const LifeWorld = preload("res://scripts/world/village_life_world.gd")
const Cinematic = preload("res://scripts/cinematic/i00_stage.gd")
const Valley = preload("res://scripts/tactics/valley_scene.gd")

class SourcePerson extends Person:
	var exact_source := ""
	func _path(_level: int) -> String:
		return exact_source

var plan: Dictionary = {}
var slots: Array[Dictionary] = []
var segments: Array[Dictionary] = []
var shown: Array[Dictionary] = []
var errors: Array[String] = []
var observed_resources: Array[String] = []
var heading: Label
var output := ""
var surface: HBoxContainer
var frame_count := 0
var world_fixture: Dictionary = {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or DisplayServer.get_name() == "headless" or OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("A real isolated graphical viewport and a capture plan are required")
		quit(2)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not parsed is Dictionary:
		quit(2)
		return
	plan = parsed
	output = str(plan.output)
	DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
	_run.call_deferred()


func _run() -> void:
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(canvas)
	heading = Label.new()
	heading.position = Vector2(20, 8)
	heading.size = Vector2(1240, 52)
	heading.add_theme_font_size_override("font_size", 22)
	canvas.add_child(heading)
	surface = HBoxContainer.new()
	surface.position = Vector2(0, 66)
	surface.size = Vector2(1280, 604)
	surface.add_theme_constant_override("separation", 0)
	canvas.add_child(surface)
	var note := Label.new()
	note.position = Vector2(20, 680)
	note.text = "Echte Godot-Ausgabe · Desktop-Sichtprüfung · Aufnahme ist keine Freigabe"
	note.add_theme_font_size_override("font_size", 18)
	canvas.add_child(note)
	if str(plan.kind) in ["village_navigation", "raid_motion", "cinematic_people", "distant_ranks"]:
		_build_world_fixture()
	else:
		_build_people()
	_build_segments()
	if not errors.is_empty():
		_finish()
		return
	await process_frame
	await physics_frame
	await physics_frame
	var elapsed := 0.0
	var limit := float(plan.get("limit_seconds", 0.0))
	for segment: Dictionary in segments:
		if limit > 0.0 and elapsed >= limit:
			break
		var available := minf(float(segment.duration), limit - elapsed) if limit > 0.0 else float(segment.duration)
		var frames := maxi(1, ceili(available * 30.0))
		var first := frame_count
		_enter_segment(segment)
		for frame in frames:
			var local_time := float(frame) / 30.0
			heading.text = "%s · %s\n%.2f s · 60-Hz-Bewegung / 30 Bilder pro Sekunde" % [str(plan.family), str(segment.label), elapsed + local_time]
			for substep in 2:
				var t := local_time + float(substep) / 60.0
				if not world_fixture.is_empty():
					_tick_world(segment, t, 1.0 / 60.0)
				else:
					for slot: Dictionary in slots:
						_tick_person(slot, segment, t, 1.0 / 60.0)
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			if image == null or image.is_empty() or image.save_jpg(output.path_join("frames/frame-%06d.jpg" % frame_count), .97) != OK:
				errors.append("Rendered viewport frame could not be saved")
				_finish()
				return
			if frame == frames / 2:
				image.save_png(output.path_join("shot-%02d-%s.png" % [shown.size(), str(segment.action)]))
			frame_count += 1
		shown.append({"action": segment.action, "label": segment.label, "first_frame": first,
			"frame_count": frames, "completed": available >= float(segment.duration) - .00001})
		elapsed += available
	_finish()


func _new_view(title: String, count: int) -> Dictionary:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(1280.0 / float(count), 604)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surface.add_child(column)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	column.add_child(label)
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(holder)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(maxi(1, 1280 / count), 570)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	holder.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("25323a")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d4dfeb")
	settings.ambient_light_energy = .55
	environment.environment = settings
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 140, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("647469")
	material.roughness = .95
	ground.material_override = material
	stage.add_child(ground)
	var grid := Node3D.new()
	stage.add_child(grid)
	for index in range(-12, 48):
		var line := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(6, .003, .012)
		line.mesh = mesh
		line.position = Vector3(0, .003, float(index) * .5)
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color("86958a")
		line.material_override = paint
		grid.add_child(line)
	var camera := Camera3D.new()
	camera.fov = 38
	stage.add_child(camera)
	camera.current = true
	return {"stage": stage, "camera": camera, "viewport": viewport, "ground": ground,
		"grid": grid, "sun": sun, "environment": environment, "title": label}


func _build_people() -> void:
	var paths: Array = plan.actor_paths
	for index in paths.size():
		var path := str(paths[index])
		var slot := _new_view(path.get_file(), paths.size())
		var stage: Node3D = slot.stage
		if str(plan.kind) == "regional":
			var packed := load("res://" + path) as PackedScene
			if packed == null:
				errors.append("Registered regional model failed to load: " + path)
				continue
			var raw := packed.instantiate() as Node3D
			stage.add_child(raw)
			var players := raw.find_children("*", "AnimationPlayer", true, false)
			if players.is_empty():
				errors.append("Regional model has no actual AnimationPlayer")
				continue
			var player := players[0] as AnimationPlayer
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			slot["actor"] = raw
			slot["player"] = player
			slot["raw"] = true
		else:
			var actor := SourcePerson.new()
			actor.exact_source = "res://" + path
			stage.add_child(actor)
			actor.position.y = .9
			_configure(actor, path)
			slot["actor"] = actor
			slot["raw"] = false
			slot["paths"] = paths
			slot["index"] = index
			if actor.active_model_path != "res://" + path:
				errors.append("Production presentation loaded a different model: " + path)
		slot["speed"] = 0.0
		slot["phase"] = 0.0
		slot["lod_choice"] = -1
		slots.append(slot)
		_observe_resources(slot.actor, path)


func _configure(actor: SourcePerson, path: String) -> void:
	var level := 0
	var stem := path.get_file().get_basename()
	if stem.ends_with("_mid"):
		level = 1
	elif stem.right(1).is_valid_int():
		level = int(stem.right(1))
	if path.contains("hero_quality_"):
		actor.configure("player", "italia", 28 if str(plan.kind) == "service" else 12)
	elif path.contains("frontier_"):
		var appearance := stem.trim_prefix("frontier_")
		appearance = appearance.substr(0, appearance.length() - 2)
		actor.configure_resident("italia", 32, appearance, 0)
	elif path.contains("meshy/characters/"):
		var identity := stem.substr(0, stem.length() - 2)
		actor.configure_resident("germania" if "germanic" in identity else "italia", 32,
			"spearman" if "germanic" in identity else "legionary", 0)
		if not actor.configure_meshy(identity):
			errors.append("Registered Meshy presentation was rejected: " + path)
	else:
		var role := "companion" if "villager_" in path else ("mentor" if "/officer_" in path else ("recruit" if "/spear_" in path else "enemy"))
		actor.configure(role, "germania", 12 if role == "companion" else 32)
	actor._reload(level)
	actor._check_lod = 100000.0
	actor.set_process(false)
	if str(plan.kind) == "service":
		actor.set_service_gear(true)
	actor.reset_motion()


func _append(action: String, duration: float, label: String, extra := "") -> void:
	segments.append({"action": action, "duration": duration, "label": label, "extra": extra})


func _build_segments() -> void:
	if not world_fixture.is_empty():
		_append("world_move", 6.0, "Produktive Weltbewegung und Kontakt")
		_append("world_stop", 3.0, "Anhalten und Richtungswechsel")
		_append("world_interact", 5.0, "Begegnung / Reaktion / Formationsansicht")
		return
	_append("idle", 2.0, "Stand, Atmung und Blick")
	_append("talk", 2.0, "Gespräch und Gewichtsverlagerung")
	_append("march", 3.0, "Anlaufen und Gehen über sichtbares Bodengitter")
	_append("run", 2.0, "Tempowechsel zum Lauf")
	_append("stop", 2.0, "Bremsen, Stillstand und Übergang")
	_append("work", 2.0, "Arbeitsbewegung")
	if str(plan.kind) == "service":
		for technique: String in Motion.ARMED_ATTACKS:
			_append("armed", 1.4, "Schwert: " + technique, technique)
		for guard: String in Motion.SHIELD_GUARDS:
			_append("guard", .9, "Schild: " + guard, guard)
	elif str(plan.family) == "hero":
		for technique: String in Motion.TECHNIQUES:
			_append("unarmed", float(Motion.TIMING[technique].z) + .3, "Technik: " + technique, technique)
	else:
		_append("attack", 2.0, "Angriff mit vorhandener Ausrüstung")
		_append("block", 1.5, "Vorhandene Abwehrhaltung")
	_append("hit", 1.2, "Trefferreaktion und Rückkehr")
	_append("lod", 3.2, "Detailwechsel bei weiterlaufender Bewegung")
	_append("death", 2.0, "Fallbewegung")


func _enter_segment(segment: Dictionary) -> void:
	for slot: Dictionary in slots:
		var actor: Variant = slot.actor
		slot.lod_choice = -1
		if bool(slot.raw):
			var player: AnimationPlayer = slot.player
			var action := str(segment.action)
			if action in ["stop", "lod"]: action = "idle" if action == "stop" else "march"
			if player.has_animation(action):
				player.get_animation(action).loop_mode = Animation.LOOP_LINEAR if action in ["idle", "talk", "march", "run", "work", "block"] else Animation.LOOP_NONE
				player.play(action, .14)
			else:
				player.play("idle")
			continue
		if str(segment.action) not in ["march", "run", "stop", "lod"]:
			actor.drive(0.0)
			actor.cancel_action()
		match str(segment.action):
			"talk": actor.set_conversation_focus(true)
			"unarmed": actor.cue_unarmed(str(segment.extra))
			"armed": actor.cue("attack", str(segment.extra))
			"guard": actor.cue("block", str(segment.extra))
			"attack", "block", "hit", "death": actor.cue(str(segment.action))


func _tick_person(slot: Dictionary, segment: Dictionary, t: float, delta: float) -> void:
	var actor: Variant = slot.actor
	var action := str(segment.action)
	var desired := 1.45 if action in ["march", "lod"] else (3.8 if action == "run" else 0.0)
	slot.speed = move_toward(float(slot.speed), desired, delta * 3.0)
	if bool(slot.raw):
		var player: AnimationPlayer = slot.player
		player.advance(delta)
		if action in ["march", "run", "stop", "lod"]:
			actor.position.z += float(slot.speed) * delta
	else:
		if action in ["march", "run", "stop", "lod"]:
			actor.drive(float(slot.speed))
			actor.position.z += float(slot.speed) * delta
		elif action == "talk": actor.keep_talking()
		elif action == "work": actor.keep_working()
		if action == "lod":
			var paths: Array = slot.paths
			var choice := (int(t / .8) + int(slot.index)) % paths.size()
			if choice != int(slot.lod_choice):
				slot.lod_choice = choice
				actor.exact_source = "res://" + str(paths[choice])
				actor._reload(int(str(paths[choice]).get_basename().right(1)) if str(paths[choice]).get_basename().right(1).is_valid_int() else choice)
				actor._check_lod = 100000.0
				_observe_resources(actor, str(paths[choice]))
		actor._process(delta)
	var target: Vector3 = actor.position + Vector3(0, -.05 if not bool(slot.raw) else .85, 0)
	var camera: Camera3D = slot.camera
	var angle := .5 if action != "lod" else .5 + .2 * sin(t * 2.0)
	camera.position = target + Vector3(0, .35, -4.8).rotated(Vector3.UP, angle)
	camera.look_at(target)


func _observe_resources(actor: Node, initial: String) -> void:
	if initial not in observed_resources: observed_resources.append(initial)
	for child: Node in actor.find_children("*", "", true, false):
		if child.has_meta("model_path"):
			var path := str(child.get_meta("model_path")).trim_prefix("res://")
			if path not in observed_resources: observed_resources.append(path)


func _pause_tree(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		_pause_tree(child)


func _build_world_fixture() -> void:
	var slot := _new_view(str(plan.family), 1)
	var stage: Node3D = slot.stage
	var model := Model.new()
	model.new_game("italia", true, true)
	world_fixture = {"view": slot, "model": model, "clock": 0.0, "snapshots": 0}
	match str(plan.kind):
		"village_navigation":
			var population := Population.new()
			stage.add_child(population)
			population._add_resident(Layout.resident("flavia"), 4)
			population._add_resident(Layout.resident("bassa"), 18)
			var actor: CharacterBody3D = population.actors.flavia
			var peer: CharacterBody3D = population.actors.bassa
			actor.position = Vector3(-1.6, 0, 0)
			peer.position = Vector3(1.6, 0, 0)
			var person: Dictionary = model.data.village.behavior.people.flavia
			person.activity = "socialize"
			person.reason = "company"
			person.partner = "bassa"
			model.data.village.behavior.people.bassa.activity = "rest"
			population.sync_behavior(model.data)
			population.set_active(true)
			var obstacle := StaticBody3D.new()
			obstacle.collision_layer = 1
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(.24, 1.2, 1.0)
			shape.shape = box
			obstacle.position = Vector3(0, .6, 0)
			obstacle.add_child(shape)
			var visible := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = box.size
			visible.mesh = mesh
			obstacle.add_child(visible)
			stage.add_child(obstacle)
			world_fixture["population"] = population
			world_fixture["focus"] = actor
			_pause_tree(population)
		"raid_motion":
			slot.ground.position = Vector3(-5, 0, -62)
			slot.grid.position = Vector3(-5, 0, -62)
			var village := LifeWorld.new()
			stage.add_child(village)
			model.data.village.raid.active = true
			model.data.village.raid.status = "active"
			model.data.village.raid.enemies = [{"id": "capture_raider", "x": -5.0, "z": -62.0, "health": 45,
				"max_health": 45, "attack_timer": .9, "loot_timer": 0.0}]
			village.sync_state(model.data, "balanced")
			village.set_active(true)
			world_fixture["village"] = village
			world_fixture["focus"] = village.raiders.capture_raider
			_pause_tree(village)
			var obstacle := StaticBody3D.new()
			obstacle.collision_layer = 1
			obstacle.position = Vector3(1, .6, -62)
			var collider := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(.25, 1.2, 1.4)
			collider.shape = box
			obstacle.add_child(collider)
			var mesh := MeshInstance3D.new()
			var visible := BoxMesh.new()
			visible.size = box.size
			mesh.mesh = visible
			obstacle.add_child(mesh)
			stage.add_child(obstacle)
		"cinematic_people":
			slot.ground.queue_free()
			slot.grid.queue_free()
			var cinematic := Cinematic.new()
			stage.add_child(cinematic)
			cinematic.ensure_built()
			cinematic.position = Vector3.ZERO
			world_fixture["cinematic"] = cinematic
			world_fixture["focus"] = cinematic.speaker("caesar")
			_pause_tree(cinematic)
		"distant_ranks":
			slot.ground.queue_free()
			slot.grid.queue_free()
			slot.sun.queue_free()
			var valley := Valley.new()
			stage.add_child(valley)
			valley.set_quality("balanced")
			valley.model.order(["valley_guard"], "move", Vector2(-7, -8))
			valley.paused = false
			world_fixture["valley"] = valley
			valley.hud.hide()
			_pause_tree(valley)
	for actor: Node in stage.find_children("*", "", true, false):
		if actor is Person:
			actor._check_lod = 100000.0
			_observe_resources(actor, str(actor.active_model_path).trim_prefix("res://"))
	var camera: Camera3D = slot.camera
	camera.current = true


func _tick_world(segment: Dictionary, t: float, delta: float) -> void:
	world_fixture.clock = float(world_fixture.clock) + delta
	var camera: Camera3D = world_fixture.view.camera
	var target := Vector3(0, .8, 0)
	match str(plan.kind):
		"village_navigation":
			var population: Variant = world_fixture.population
			var person: Dictionary = world_fixture.model.data.village.behavior.people.flavia
			person.activity = "rest" if str(segment.action) == "world_stop" else "socialize"
			population.advance_to(float(population.seconds) + delta)
			for actor: Node3D in population.actors.values():
				actor.get_node("Figure")._process(delta)
			target = Vector3(0, .85, 0)
		"raid_motion":
			var village: Variant = world_fixture.village
			var data: Dictionary = world_fixture.model.data
			data.world_seconds = float(data.world_seconds) + delta
			var frame := int(float(world_fixture.clock) * 10.0)
			if frame != int(world_fixture.snapshots):
				world_fixture.snapshots = frame
				if str(segment.action) != "world_stop":
					data.village.raid.enemies[0].x += .12 if str(segment.action) == "world_move" else -.12
				data.village.raid.enemies[0].attack_timer = .1 if str(segment.action) == "world_interact" else .9
				village.sync_state(data, "balanced")
			village._advance_raiders(delta)
			for actor: Node3D in village.raiders.values():
				actor.get_node("Figure")._process(delta)
			target = world_fixture.focus.position + Vector3(0, .9, 0)
		"cinematic_people":
			var cinematic: Variant = world_fixture.cinematic
			cinematic._process(delta)
			for id: String in ["caesar", "labienus"]:
				var figure: Variant = cinematic.speaker(id)
				if str(segment.action) == "world_interact": figure.keep_talking()
				figure._process(delta)
			target = Vector3(0, 1, -5) if str(segment.action) == "world_move" else Vector3(-2.4, 1, 2.2)
		"distant_ranks":
			var valley: Variant = world_fixture.valley
			valley.paused = str(segment.action) == "world_stop"
			valley.distance = lerpf(24.0, 62.0, clampf(t / 6.0, 0.0, 1.0)) if str(segment.action) == "world_move" else 48.0
			valley._place_camera()
			valley._process(delta)
			camera.global_transform = valley.camera.global_transform
			camera.fov = valley.camera.fov
			camera.environment = valley.camera.environment
			camera.current = true
			return
	var distance := 18.0 if str(plan.kind) == "cinematic_people" and str(segment.action) == "world_move" else 7.0
	camera.position = target + Vector3(-distance * .45, distance * .25, -distance)
	camera.look_at(target)
	camera.current = true


func _finish() -> void:
	var file := FileAccess.open(output.path_join("rendered.json"), FileAccess.WRITE)
	if file == null:
		printerr("Cannot write capture receipt")
		quit(2)
		return
	file.store_string(JSON.stringify({"schema_version": 1, "family": plan.family, "batch": plan.id,
		"status": "captured_unreviewed", "source_fingerprint": plan.source_fingerprint,
		"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "frame_count": frame_count,
		"simulation_hz": 60, "playback_fps": 30, "android_device_test": false, "measured_fps": false,
		"subjects_requested": plan.subjects, "observed_resources": observed_resources,
		"requested_scenarios": plan.requested_scenarios, "rendered_segments": shown,
		"fixture_kind": plan.kind,
		"fixture_scope": "Production presentation and explicitly staged world paths; no domain, Android or naturalness approval is inferred",
		"errors": errors}, "  ") + "\n")
	file.close()
	print("MOTION_CAPTURE_RECORDED ", frame_count, " frames; errors=", errors.size())
	quit(0 if errors.is_empty() else 1)
