extends SceneTree
## Production Main/UI/world journey. Travel uses explicit fixture teleports.
## Controlled elapsed time runs through the actual Main and WorldModel.
## Resources, worker assignments, social history and combat state use real commands.

const Entry = preload("res://main.tscn")
const Life = preload("res://scripts/story/village_life.gd")
const Economy = preload("res://scripts/domain/village_economy.gd")
const VillageDiagnostics = preload("res://scripts/ui/android_village_diagnostics.gd")
const LegacyCampaign = preload("res://tests/legacy_campaign_fixture.gd")
var game
var checks := 0
var failures: Array[String] = []
var captures: Array[Dictionary] = []
var capture_dir := ""


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST")!="1":
		printerr("Run with disposable XDG user directories and IMPERATHEN_ISOLATED_TEST=1.")
		quit(2)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	if capture_dir!="" and not capture_dir.is_absolute_path():
		printerr("The optional capture directory must be absolute.")
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	game = Entry.instantiate()
	root.add_child(game)
	await _frames()
	game.set_process(false)
	game.world.set_physics_process(false)
	game.ui._finish_intro()
	await _frames()
	_check(game.screen=="menu","Actual main menu is available")
	_modal_bounds("landscape menu")
	_click("Neues Leben")
	await _frames()
	_check(game.screen=="opening" and game.model.data.village.enabled,"A real new Roman life activates the village system")
	_check(game.model.data.player.age==12 and not game.model.data.village.economy.authority.player_is_ruler,"The child starts under an existing authority")
	game.opening_overlay._request_skip()
	_check(game.screen=="opening" and game.opening_sequence.beats[game.opening_index].get("final",false),"Skipping the film still presents the meaningful first objective")
	game.opening_overlay._request_advance()
	await _frames()
	_check(game.screen=="playing" and game.world.get("_active"),"Accepting the objective gives actual world control")
	_check(game.world.village_life_world.actors.size()==15 and game.world.village_life_world.workplaces.size()==5,"The scene contains the same fourteen residents, steward and five workplaces")
	_check(game.world.village_life_world.visible,"Village projections are actually enabled in the new world")
	_check(not game.world.get_node("TrainingGround/Mentor").visible,"The old generic trainer does not duplicate the new mentor")
	await _capture("01-village-start")
	_check(LegacyCampaign.load_into(game), "Existing village-only saves retain their worker and profession campaign")
	await _frames()
	# An invalid action must not trigger a dodge animation before its rule accepts it.
	var before: String = _state()
	var old_motion := float(game.world.get("_dodge_remaining"))
	game.ui.action_requested.emit("village_dodge",{})
	_check(_state()==before and game.world.get("_dodge_remaining")==old_motion,"Rejected out-of-combat dodge has no state or movement cue")

	_move_actor("decimus")
	game.ui.action_requested.emit("interact",{})
	await _frames()
	_check(game.screen=="village_dialog" and game.model.data.village.social.npcs.decimus.met,"World interaction meets the actual steward")
	_check(game.world.get("_village_focus")=="decimus","The conversation focuses the corresponding visible person")
	await _capture("02-decimus-dialogue")
	_click("Beim Wiederaufbau mithelfen")
	await _frames()
	_check(game.model.data.village.economy.authority.work_permit,"The real dialogue button receives the steward's work permission")
	root.go_back_requested.emit()
	_check(game.screen=="playing","Android Back leaves the village conversation")
	if game.screen!="playing":
		_click("Gespräch beenden")
	await _frames()
	_move_actor("fabius")
	game.ui.action_requested.emit("interact",{})
	await _frames()
	_click("Helfen ·")
	await _frames()
	_check(game.model.data.village.social.npcs.fabius.helped and game.model.data.resources.grain==10,"The real mentor choice consumes the two actual rations")
	_click("Beruf lernen ·")
	await _frames()
	_check(game.model.data.village.social.profession=="woodcutter","The live mentor UI starts the selected profession")
	_click("Bündnis schließen ·")
	await _frames()
	_check(game.model.data.village.social.npcs.fabius.ally and game.model.data.resources.grain==8,"Friendship opens an actual provisioned alliance")
	_click("Gespräch beenden")
	await _frames()
	_move_actor("aelia")
	game.ui.action_requested.emit("interact",{})
	await _frames()
	_check(game.model.data.village.social.npcs.aelia.met,"A third distinct acquaintance joins the personal history")
	_click("Gespräch beenden")
	await _frames()
	_move(Vector3(-8,1,2))
	for index in 4:
		game.ui.action_requested.emit("interact",{})
	_check(game.model.data.resources.wood==16 and game.model.data.resource_nodes[0].amount==0,"World interaction gathers four real bundles from the finite source")
	_move(Vector3(8,1,4))
	game.world.action_requested.emit("build",{"x":8.0,"z":4.0})
	_advance(13.0)
	_check(game.model.data.buildings.size()==1 and game.model.data.buildings[0].completed,"The legal placement command and real work complete the first home")
	_check(game.model.data.player.age==12 and not Life.training_ready(game.model.data),"A single home no longer skips the lived village phase")

	# Exercise the Android failure path through native touch and the real UI
	# dispatcher, then inspect the same read-only observer used by the APK run.
	# The overview and work tab share a screen name but have different controls.
	var diagnostics := VillageDiagnostics.new()
	diagnostics.session = game
	game.add_child(diagnostics)
	diagnostics.set_process(false)
	await _open_panel("overview")
	var overview_snapshot: Dictionary = diagnostics.snapshot()
	_check(overview_snapshot.get("screen", "") == "village_panel" and overview_snapshot.controls.has("work_tab") and not overview_snapshot.controls.has("aelia_assignment"), "The real overview snapshot cannot stand in for the work tab")
	await _tap("Arbeit & Versorgung")
	await _frames()
	var work_snapshot: Dictionary = diagnostics.snapshot()
	_check(game.ui.get("_village_tab") == "work" and work_snapshot.controls.has("aelia_assignment"), "A native touch reaches the work tab and exposes Aelia in a new diagnostic snapshot")
	_check(work_snapshot.controls.get("aelia_assignment", {}).get("enabled", false), "The diagnostic selector is enabled after the real steward's permission")
	var aelia_selector := _selector("Aelia")
	if aelia_selector != null:
		var work_scrolls: Array[Node] = game.ui.get("_screen").find_children("*", "ScrollContainer", true, false)
		if not work_scrolls.is_empty():
			(work_scrolls[0] as ScrollContainer).ensure_control_visible(aelia_selector)
			await _frames()
	var visible_snapshot: Dictionary = diagnostics.snapshot()
	_check(visible_snapshot.controls.get("aelia_assignment", {}).get("visible", false), "Scrolling reveals the actual enabled Aelia selector inside the clipped work panel")
	_check(_person("aelia").assignment == "idle", "Opening and inspecting work controls does not invent a worker assignment")
	_check(game.screen=="village_panel" and game.ui.get("_view_state")=="village","The HUD opens the actual work panel")
	_modal_bounds("landscape workplace panel")
	await _assign("Fabius",2)
	await _assign("Drusa",2)
	_check(_person("fabius").assignment=="woodcamp" and _person("drusa").assignment=="woodcamp","Two actual people are assigned through the live selectors")
	var actual: Vector3 = game.world.village_life_world.actor_position("fabius")
	var expected := Life.actor_position(game.model.data,"fabius")
	_check(Vector2(actual.x,actual.z).is_equal_approx(expected),"A reassigned mentor appears at his authoritative workplace")
	_click_section("Holzfällerlager","Wiederaufbauen")
	await _frames()
	_check(not game.model.data.village.economy.workplaces.woodcamp.project.is_empty(),"The visible repair button spends resources and starts real work")
	await _capture("03-workplace-panel")
	before = _state()
	game._process(20.0)
	_check(_state()==before,"Open work panels hold simulation time")
	root.go_back_requested.emit()
	_check(game.screen=="playing","Android Back closes the village panel")
	if game.screen!="playing":
		_click("Zurück ins Dorf")
	_advance(61.0)
	await _frames()
	_check(game.model.data.village.economy.workplaces.woodcamp.condition==100 and game.model.data.village.economy.workplaces.woodcamp.produced_cycles>=1,"Actual elapsed staffed work repairs and operates the camp")
	_check(game.world.village_life_world.workplaces.woodcamp.repaired.visible and not game.world.village_life_world.workplaces.woodcamp.damaged.visible,"The repaired workplace is visibly the actual completed state")
	_check(game.model.data.resources.wood>=12,"The learned timber method affects real finite production")
	await _open_panel("work")
	await _assign("Drusa",0)
	_check(_person("drusa").assignment=="idle","The live Free/Recover option actually releases a worker")
	_click("Zurück ins Dorf")
	var cycles: int = game.model.data.village.economy.workplaces.woodcamp.produced_cycles
	_advance(30.0)
	_check(game.model.data.village.economy.workplaces.woodcamp.produced_cycles==cycles,"The understaffed camp stops instead of producing phantom work")
	await _open_panel("work")
	await _assign("Drusa",2)
	_click("Zurück ins Dorf")
	await _frames()
	game.ui.action_requested.emit("pause",{})
	await _frames()
	_click("Dorfleben und Wiederaufbau")
	await _frames()
	_check(game.screen=="village_panel","The pause-menu village entry reaches the real panel")
	if game.screen=="village_panel":
		_click("Zurück ins Dorf")
	else:
		game.ui.action_requested.emit("resume",{})
	await _frames()

	_move_actor("varro")
	game.ui.action_requested.emit("interact",{})
	await _frames()
	_check(game.model.data.village.social.npcs.varro.met,"The scout is encountered through his visible person")
	_click("Gespräch beenden")
	_advance(maxf(0.1,120.1-float(game.model.data.village.social.seconds)))
	_check(game.model.data.village.raid.status=="warning","Lived time and completed prerequisites trigger the genuine warning")
	_move(Vector3(Life.SCOUT_POINT.x,1,Life.SCOUT_POINT.y))
	game.ui.action_requested.emit("interact",{})
	_check(game.model.data.village.raid.scouted and game.model.data.village.attributes.insight==2,"The in-world trail interaction records real reconnaissance")
	_move(Vector3(Life.ALARM_POINT.x,1,Life.ALARM_POINT.y))
	game.ui.action_requested.emit("interact",{})
	_check(game.model.data.village.raid.alarm and game.model.data.village.attributes.tactics==2,"The visible alarm interaction changes the real defense preparation")
	await _open_panel("map")
	_check(_has_label("32 × 32 km") and _has_label("geplante Siedlungen"),"The actual regional panel shows the planned extent and honest content boundary")
	await _capture("05-regional-map")
	root.size = Vector2i(540,960)
	await _frames(6)
	_check(game.screen=="village_panel" and game.ui.get("_village_tab")=="map","Resizing preserves the actual selected region tab")
	_modal_bounds("narrow regional panel")
	_click("Arbeit & Versorgung")
	await _frames()
	_modal_bounds("narrow workplace panel")
	_check(_selector("Fabius")!=null,"Work assignments remain present in the narrow layout")
	await _capture("06-narrow-workplace-panel")
	root.go_back_requested.emit()
	_check(game.screen=="playing","Back remains functional after panel resize")
	root.size = Vector2i(1280,720)
	await _frames(5)
	_advance(float(game.model.data.village.raid.remaining)+0.2)
	await _frames()
	_check(game.model.data.village.raid.active and game.world.village_life_world.raiders.size()==3,"The warning produces three real world enemy actors")
	for enemy: Dictionary in game.model.data.village.raid.enemies:
		var actor: Node3D = game.world.village_life_world.raiders[enemy.id]
		_check(actor.visible and Vector2(actor.position.x,actor.position.z).is_equal_approx(Vector2(enemy.x,enemy.z)),"Rendered attacker position comes from its saved combat state")
	var enemy: Dictionary = game.model.data.village.raid.enemies[0]
	_move(Vector3(enemy.x+3.0,1,enemy.z+2.0))
	game.world._update_camera(1.0)
	await _capture("04-raid-in-world")
	game.ui.action_requested.emit("village_block",{})
	_check(game.model.data.village.raid.block_window>0.0 and game.world.get("_figure").clip=="block","An accepted block reaches the actual character cue")
	before = _state()
	old_motion = game.world.get("_dodge_remaining")
	game.ui.action_requested.emit("village_dodge",{})
	_check(_state()==before and game.world.get("_dodge_remaining")==old_motion,"Rejected shared-cooldown dodge does not run its motion")
	_advance(1.2)
	game.ui.action_requested.emit("village_dodge",{})
	_check(game.model.data.village.raid.dodge_window>0.0 and game.world.get("_dodge_remaining")>0.0,"Accepted dodge starts both rule protection and actual movement")
	var start_position: Vector3 = game.world.get_player_position()
	_advance(0.1)
	_check(game.world.get_player_position().distance_to(start_position)>0.01,"Accepted dodge produces a measured change in the rendered player's position")
	game.ui.action_requested.emit("pause",{})
	await _frames()
	before = _state()
	game._process(15.0)
	_check(game.screen=="paused" and _state()==before,"Pause holds the ongoing raid and shared resource state")
	_click("Spiel speichern")
	await _frames()
	_check(FileAccess.file_exists(game.SAVE_PATH),"The ongoing lived village is written through the real Save action")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(game.model.data))
	_click("Zum Hauptmenü")
	await _frames()
	_click("Speichern und Hauptmenü")
	await _frames()
	_check(game.screen=="menu","The confirmed save action reaches the actual main menu")
	_click("Fortsetzen")
	await _frames()
	_check(game.screen=="playing" and game.model.data.village.enabled,"Continue restores the new village mode without replaying the completed intro")
	_check(_equivalent(game.model.data.village,saved.village),"Continue preserves work, friends, profession, raid timers and skill history")
	_check(_equivalent(game.model.data.resources,saved.resources),"Continue does not re-award production, spend favors again or reset provisions")
	_check(game.world.village_life_world.raiders.size()==3 and game.world.village_life_world.visible,"Continued combat also rebuilds its actual world presentation")
	var rescued_id: String = game.model.data.village.raid.rescue_person_id
	_move(Vector3(Life.RESCUE_POINT.x,1,Life.RESCUE_POINT.y))
	game.ui.action_requested.emit("interact",{})
	_check(game.model.data.village.raid.rescued and int(_person(rescued_id).health)==100,"Continued world interaction rescues and treats the actual existing resident")
	for index in game.model.data.village.raid.enemies.size():
		var attempts := 0
		while int(game.model.data.village.raid.enemies[index].health)>0 and attempts<5:
			var current: Dictionary = game.model.data.village.raid.enemies[index]
			_move(Vector3(current.x,1,current.z+0.5))
			var health_before := int(current.health)
			game.ui.action_requested.emit("attack",{})
			_check(int(game.model.data.village.raid.enemies[index].health)<health_before,"The actual attack input damages the live in-range village raider")
			_advance(0.75)
			attempts += 1
	_check(game.model.data.village.raid.won==1 and not game.model.data.village.raid.active,"The actual player wins after all enemies are genuinely defeated")
	_check(game.model.data.village.attributes.combat>=9 and game.model.data.village.attributes.courage>=3,"Real fighting and rescue develop the actual saved abilities")
	var hidden := true
	for actor: Node3D in game.world.village_life_world.raiders.values():
		hidden = hidden and not actor.visible
	_check(hidden,"Settled combat removes active enemy presentation")
	_advance(maxf(0.1,240.1-float(game.model.data.village.social.seconds)))
	_check(Life.training_ready(game.model.data) and int(game.model.data.player.age)==12,"Lived village prerequisites open later training without silently aging the player")
	game.ui.action_requested.emit("pause",{})
	await _frames()
	_click("Spiel speichern")
	_check(FileAccess.file_exists(game.SAVE_PATH),"The completed defense and lived village remain saveable")
	_click("Weiterspielen")
	await _frames()
	_move(Vector3(-3,1,4))
	game.ui.action_requested.emit("interact",{})
	await _frames()
	_check(game.screen=="dialog","The original companion encounter remains reachable after village development")
	_click("4 Holz teilen")
	await _frames()
	_check(game.model.data.companion.met and game.model.data.companion.choice=="help","The required earlier companion choice is made through its actual dialogue")
	_move(Vector3(0,1,-7))
	game.ui.action_requested.emit("interact",{})
	await _frames()
	_check(game.screen=="opening" and game.opening_sequence.id=="adulthood" and game.model.data.player.age==18,"The eligible actual training interaction starts the saved adult transition")
	if game.screen=="opening":
		game.opening_overlay._request_skip()
		game.opening_overlay._request_advance()
	await _frames()
	for index in 3:
		game.ui.action_requested.emit("attack",{})
		_advance(0.7)
	_check(game.model.data.progress.training_complete and game.model.data.progress.training_hits==3,"Three genuine training attacks complete the adult qualification")
	var recruit_button: Button = game.ui.get("_action_buttons").get("recruit")
	_check(recruit_button!=null and not recruit_button.disabled,"The actual recruit action is available after valid training")
	var denarii_before := int(game.model.data.resources.denarii)
	var grain_before := int(game.model.data.resources.grain)
	if recruit_button!=null and not recruit_button.disabled:
		recruit_button.pressed.emit()
	await _frames()
	_check(game.model.data.village.militia.size()==1 and game.model.data.squad.alive==1,"Actual recruitment selects one existing resident into the militia")
	_check(game.model.data.resources.denarii==denarii_before-5 and game.model.data.resources.grain==grain_before-2,"The recruit consumes the existing agreed pay and provisions")
	if game.model.data.village.militia.size()==1:
		var resident_id: String = game.model.data.village.militia[0]
		var resident := _person(resident_id)
		var squad: Array = game.world.get("_squad_views")
		_check(squad.size()==1 and squad[0].visible,"The recruited militia has one actual visible troop actor")
		if squad.size()==1:
			_check(squad[0].get_meta("resident_id","")==resident_id and squad[0].get_node("RecruitName").text==resident.name,"The troop render carries the same resident ID and actual person's name")
		_check(not game.world.village_life_world.actors[resident_id].visible,"The same resident is hidden in the civilian projection, preventing a duplicate person")
		_check(game.world.population.recruited==0,"Unrelated older Frontier decoration is not consumed by the new named militia")
		await _open_panel("work")
		var assignment := _selector(resident.name)
		_check(assignment!=null and assignment.disabled,"The recruited person's work selector is disabled")
		if assignment!=null:
			_check(assignment.get_item_text(assignment.selected)=="In deiner Truppe","The disabled selector explains the person's actual military assignment")
		_click("Zurück ins Dorf")
		game.ui.action_requested.emit("pause",{})
		await _frames()
		_click("Spiel speichern")
		_check(FileAccess.file_exists(game.SAVE_PATH),"Named militia and civilian removal remain saveable after the real progression")
	game.queue_free()
	await _frames()
	_finish()


func _advance(seconds: float) -> void:
	var remaining := seconds
	while remaining>0.000001:
		var step := minf(0.1,remaining)
		game._process(step)
		game.world._physics_process(step)
		remaining -= step
	game._refresh()


func _move(position: Vector3) -> void:
	game.world.get_node("Player").position = position
	game.world.get_node("Player").velocity = Vector3.ZERO
	game.model.set_player_position(position)
	game.world.sync_state(game.model.data)
	game.world._update_camera(1.0)


func _move_actor(id: String) -> void:
	var at := Life.actor_position(game.model.data,id)
	_move(Vector3(at.x,1,at.y+0.5))


func _person(id: String) -> Dictionary:
	for person: Dictionary in game.model.data.village.economy.people:
		if person.id==id:
			return person
	return {}


func _open_panel(tab: String) -> void:
	if game.screen!="playing":
		game.ui.action_requested.emit("resume",{})
	await _frames()
	await _tap("Dorfleben")
	await _frames()
	if tab=="work":
		await _tap("Arbeit & Versorgung")
	elif tab=="map":
		await _tap("Region")
	elif tab=="people":
		await _tap("Menschen & Berufe")
	await _frames()


func _tap(prefix: String) -> void:
	for node: Node in _nodes(game.ui.get("_screen")):
		if node is Button and not node is OptionButton and node.text.begins_with(prefix):
			_check(not node.disabled and node.is_visible_in_tree(), "The native touch target is available: " + prefix)
			if node.disabled or not node.is_visible_in_tree():
				return
			var point: Vector2 = node.get_global_rect().get_center()
			_check(root.get_visible_rect().has_point(point), "The native touch target is inside the viewport: " + prefix)
			for down in [true, false]:
				var event := InputEventScreenTouch.new()
				event.index = 0
				event.position = point
				event.pressed = down
				Input.parse_input_event(event)
				await process_frame
			return
	_check(false, "Missing native touch target: " + prefix)


func _assign(name: String, selection: int) -> void:
	var select := _selector(name)
	_check(select!=null and not select.disabled,"An available live assignment selector exists for "+name)
	if select!=null and not select.disabled:
		select.select(selection)
		select.item_selected.emit(selection)
	await _frames()


func _selector(name: String) -> OptionButton:
	for node: Node in _nodes(game.ui.get("_screen")):
		if node is Label and node.text.begins_with(name+" ·"):
			for sibling: Node in node.get_parent().get_children():
				if sibling is OptionButton:
					return sibling
	return null


func _click(prefix: String) -> void:
	for node: Node in _nodes(game.ui.get("_screen")):
		if node is Button and not node is OptionButton and node.text.begins_with(prefix):
			_check(not node.disabled,"The actual UI action is enabled: "+prefix)
			if not node.disabled:
				node.pressed.emit()
			return
	_check(false,"Missing actual UI button: "+prefix)


func _click_section(section: String, prefix: String) -> void:
	for node: Node in _nodes(game.ui.get("_screen")):
		if node is Label and node.text.begins_with(section+" ·"):
			for sibling: Node in node.get_parent().get_children():
				if sibling is Button and sibling.text.begins_with(prefix):
					_check(not sibling.disabled,"The actual workplace action is enabled: "+section)
					if not sibling.disabled:
						sibling.pressed.emit()
					return
	_check(false,"Missing actual workplace action: "+section+" / "+prefix)


func _has_label(fragment: String) -> bool:
	for node: Node in _nodes(game.ui.get("_screen")):
		if node is Label and node.text.contains(fragment):
			return true
	return false


func _nodes(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child: Node in node.get_children():
		result.append_array(_nodes(child))
	return result


func _modal_bounds(label: String) -> void:
	var bounds: Rect2 = game.ui.get("_root").get_global_rect()
	var fitting := true
	var inspected := 0
	for node: Node in _nodes(game.ui.get("_screen")):
		if node is ScrollContainer or node is PanelContainer:
			var rectangle: Rect2 = node.get_global_rect()
			if rectangle.size.x<1.0:
				continue
			inspected += 1
			if rectangle.position.x<bounds.position.x-1.0 or rectangle.end.x>bounds.end.x+1.0:
				fitting = false
				print("LAYOUT_OVERFLOW ",label," ",node.get_path()," rect=",rectangle," bounds=",bounds)
	_check(inspected>0 and fitting,"Panels stay inside horizontal viewport bounds: "+label)


func _state() -> String:
	return JSON.stringify(game.model.data)


func _frames(count := 3) -> void:
	for index in count:
		await process_frame


func _capture(label: String) -> void:
	if capture_dir.is_empty():
		return
	if DisplayServer.get_name()=="headless":
		_check(false,"Requested image capture requires a real rendering display")
		return
	await _frames(3)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var path := capture_dir.path_join(label+".png")
	var error := image.save_png(path)
	_check(error==OK,"Actual rendered capture saved: "+label)
	if error==OK:
		captures.append({"file":path,"width":image.get_width(),"height":image.get_height(),"screen":game.screen,"world_seconds":game.model.data.world_seconds,"sha256":FileAccess.get_sha256(path)})


func _finish() -> void:
	if not capture_dir.is_empty():
		var report := FileAccess.open(capture_dir.path_join("experience-report.json"),FileAccess.WRITE)
		if report!=null:
			report.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"engine":Engine.get_version_info().string,"evidence":"Actual Godot Main/UI/world journey. Fixture teleports and explicit elapsed-time stepping accelerate the scenario; no resource, skill, worker or quest state is invented. These captures are not an FPS benchmark."},"  "))
	print("VILLAGE_EXPERIENCE_RESULT checks=%d failures=%d captures=%d" % [checks,failures.size(),captures.size()])
	for failure: String in failures:
		printerr("FAIL: "+failure)
	print("VILLAGE_EXPERIENCE_PASS" if failures.is_empty() else "VILLAGE_EXPERIENCE_FAIL")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _equivalent(left: Variant, right: Variant) -> bool:
	# Godot JSON restores integral numbers as floats and can round the last bit.
	# Check every field while accepting numeric representations of the same value.
	if typeof(left) in [TYPE_INT,TYPE_FLOAT] and typeof(right) in [TYPE_INT,TYPE_FLOAT]:
		return absf(float(left)-float(right))<0.00000001
	if typeof(left)!=typeof(right):
		return false
	if typeof(left)==TYPE_DICTIONARY:
		if left.size()!=right.size():
			return false
		for key in left:
			if not right.has(key) or not _equivalent(left[key],right[key]):
				return false
		return true
	if typeof(left)==TYPE_ARRAY:
		if left.size()!=right.size():
			return false
		for index in left.size():
			if not _equivalent(left[index],right[index]):
				return false
		return true
	return left==right
