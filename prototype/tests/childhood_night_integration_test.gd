extends SceneTree
## Production Main + world + persistence at the night transition. Preparatory
## travel is an explicit fixture; no scene, death, reward or outcome is injected.

const Entry = preload("res://main.tscn")
const Childhood = preload("res://scripts/story/childhood_story.gd")
const Neighborhood = preload("res://scripts/world/village/childhood_neighborhood.gd")
const StoryCases = preload("res://tests/childhood_story_test.gd")
var game
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST")!="1":
		printerr("Use a disposable XDG account and IMPERATHEN_ISOLATED_TEST=1.")
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	var settings := ConfigFile.new()
	settings.set_value("input","touch_controls",true)
	settings.set_value("graphics","quality","low")
	settings.save("user://imperathen_ui.cfg")
	await _spawn()
	await _defend_branch()
	await _hide_branch()
	if is_instance_valid(game):
		game.queue_free()
	await _frames(3)
	print("CHILDHOOD_NIGHT_INTEGRATION_RESULT checks=%d failures=%d" % [checks,failures.size()])
	for failure: String in failures:
		printerr(failure)
	print("CHILDHOOD_NIGHT_INTEGRATION_PASS" if failures.is_empty() else "CHILDHOOD_NIGHT_INTEGRATION_FAIL")
	quit(0 if failures.is_empty() else 1)


func _spawn() -> void:
	game = Entry.instantiate()
	root.add_child(game)
	game.set_process(false)
	game.world.set_physics_process(false)
	game.world.set_quality("low")
	await _frames(2)


func _prepare_night() -> bool:
	game._start_new_game()
	game._opening_skip()
	game._opening_next()
	game.set_process(false)
	game.world.set_physics_process(false)
	await _frames(2)
	_check(game.screen=="playing" and Childhood.enabled(game.model.data),"A real new Main session starts the authored child life")
	for item: Array in StoryCases.PATH_TO_NIGHT:
		if not _command_step(item[0],item[1]):
			return false
	await _frames(2)
	_check(game.model.data.village.childhood.scene_id=="night_decision" and game.model.data.village.childhood.closed_days.size()==4,"Only the full valid four-day command chain reaches the pending night choice")
	_check(game.model.data.village.childhood.night_raid.decision=="pending" and game.model.data.village.raid.number==0,"Preparation injects neither a branch nor a fabricated attack")
	_check(game.ui.get("_hud_labels").time.text=="TAG 4 · Nacht","The actual HUD identifies the pending night as night")
	_check(_is_night(),"The actual world is dark at the explicit night decision, before the player chooses a branch")
	return true


func _defend_branch() -> void:
	if not await _prepare_night():
		return
	if not await _ui_step("night_decision","defend"):
		return
	_check(_is_night(),"Choosing defense applies the real night lighting")
	var riders: Dictionary = game.world.childhood_raiders.debug_snapshot()
	_check(riders.visible and riders.riders==30 and riders.sequence.decision=="defend","Thirty actual rider samples use the saved explicit defense branch")
	_check(not game.model.data.village.childhood.night_raid.support_confirmed,"The UI choice has not yet become invented support")
	await _simulate(7.5,0.5)
	var pending: Dictionary = game.model.data.village.childhood.night_raid.duplicate(true)
	await _restart_saved("approach")
	_check(Childhood._equivalent(game.model.data.village.childhood.night_raid,pending),"A real Main restart restores the exact approach phase and fractional time")
	_check(_is_night() and game.world.childhood_raiders.debug_snapshot().riders==30,"Reload reconstructs the actual night environment and rider instances")
	if not await _ui_step("night_mother","escort"):
		return
	var actor_id: int = game.world.village_life_world.actors.julia.get_instance_id()
	var length := Childhood._escort_length()
	var player_progress := 1.75
	_move_point(Childhood._escort_point(player_progress))
	await _frames(1)
	var previous_progress := 0.0
	var projection_error := 0.0
	var bounded := true
	var restarted := false
	var arrived := false
	for index in 300:
		player_progress = minf(length,player_progress+0.20)
		var destination := Childhood._escort_point(player_progress)
		if is_equal_approx(player_progress,length):
			# Wait inside, beside the route, so the child does not physically
			# occupy Julia's last safe step through the doorway.
			destination += Vector2(1.0,0.0)
		_move_point(destination,false)
		await physics_frame
		game._process(0.1)
		var progress: float = game.model.data.village.childhood.escort.progress
		bounded = bounded and progress>=previous_progress-0.000001 and progress-previous_progress<=Childhood.ESCORT_SPEED*0.1+0.0001
		previous_progress = progress
		var point: Array = game.model.data.village.childhood.escort.position
		var actual: Vector3 = game.world.village_life_world.actors.julia.position
		projection_error = maxf(projection_error,Vector2(actual.x,actual.z).distance_to(Vector2(point[0],point[1])))
		if progress>5.0 and not restarted:
			var saved: Dictionary = game.model.data.village.childhood.escort.duplicate(true)
			await _restart_saved("walking")
			_check(Childhood._equivalent(game.model.data.village.childhood.escort,saved),"A true Main restart preserves Julias exact position midway through both-house travel")
			actor_id = game.world.village_life_world.actors.julia.get_instance_id()
			restarted = true
		if Childhood._escort_arrived(game.model.data.village.childhood):
			arrived = true
			break
	_check(arrived and restarted,"The actual collision-limited Main loop escorts Julia to the refuge and resumes after a mid-walk restart")
	_check(bounded and projection_error<0.0001,"Every real frame projects the saved route position and respects the walking-speed limit")
	_check(game.world.village_life_world.actors.julia.get_instance_id()==actor_id,"The living world keeps the same Julia node after restoration while she walks")
	if not arrived:
		printerr("Night integration escort stopped at progress=%s position=%s screen=%s" % [game.model.data.village.childhood.escort.progress,game.model.data.village.childhood.escort.position,game.screen])
		return
	var actual: Vector3 = game.world.village_life_world.actors.julia.position
	_check(Neighborhood.house_at(Vector2(actual.x,actual.z))=="neighbors","The saved and visible mother is inside the actual neighboring house")
	_check(Neighborhood.house_at(Vector2(actual.x,actual.z+0.29))=="neighbors","The entire real Julia capsule has cleared the inner doorway before rescue confirmation")
	await _simulate(1.0,0.1)
	_check(game.model.get_childhood_objective().npc_id=="julia" and game.world.can_talk_childhood("julia"),"The completed route remains interactable when Julia occupies its exact destination")
	if not await _ui_step("night_escort","arrive"):
		return
	_check(game.model.data.village.childhood.night_raid.support_kind=="escort","The actual arrival button confirms a completed spatial rescue")
	await _simulate_to_outcome()
	await _verify_outcome("mother_survived",12)
	await _finish_vow()


func _hide_branch() -> void:
	if not await _prepare_night():
		return
	if not await _ui_step("night_decision","hide"):
		return
	_check(_is_night() and game.model.data.village.childhood.night_raid.decision=="hide","The actual hiding button persists a distinct nighttime branch")
	await _simulate(10.25,0.5)
	var pending: Dictionary = game.model.data.village.childhood.night_raid.duplicate(true)
	await _restart_saved("hidden")
	_check(Childhood._equivalent(game.model.data.village.childhood.night_raid,pending),"Main reload cannot reinterpret the hiding choice as a defense contribution")
	await _simulate_to_outcome()
	await _verify_outcome("parents_lost",11)
	await _finish_vow()


func _simulate_to_outcome() -> void:
	var finished := false
	for index in 200:
		await physics_frame
		game._process(1.0)
		if game.model.data.village.childhood.night_raid.consequences_applied:
			finished = true
			break
	_check(finished,"The live Main loop reaches the authoritative end of the actual running raid")
	await _frames(2)


func _verify_outcome(expected: String, alive_count: int) -> void:
	_check(game.model.data.village.childhood.night_raid.outcome==expected,"The real Main loop applies the requested saved outcome: " + expected)
	for id: String in ["silvanus","sextus"] + (["julia"] if expected=="parents_lost" else []):
		var person := _person(id)
		var actor: Node3D = game.world.village_life_world.actors[id]
		_check(not person.alive and person.health==0 and person.assignment=="idle","The shared authority permanently removes dead resident work: " + id)
		_check(not actor.visible and actor.collision_layer==0,"The actual dead resident neither renders nor leaves an invisible body: " + id)
	_check(game.world.village_life_world.actors.julia.visible==(expected=="mother_survived"),"The actual mother projection matches the saved survivor branch")
	var economy: Dictionary = game.VillageEconomy.view(game.model.data)
	_check(economy.population.alive==alive_count and economy.people.size()==14,"The same fourteen identities produce the correct actual survivor count")
	_check(not game.world.childhood_raiders.debug_snapshot().visible and not _is_night(),"The actual rider scene clears and daylight returns on the saved fifth morning")
	_check(game.model.get_childhood_objective().npc_id=="aurelia" and game.world.can_talk_childhood("silvanus")==false,"The next objective is living Aurelia; dead father dialogue cannot open")
	_check(game.ui.get("_hud_labels").time.text=="TAG 5 · Morgen","The real HUD advances to the authored fifth morning without six skipped years")
	var result_before: Dictionary = game.model.data.village.childhood.duplicate(true)
	await _restart_saved(expected)
	_check(Childhood._equivalent(game.model.data.village.childhood,result_before),"Reload preserves every irreversible night receipt, memory and survivor flag")
	_check(game.model.data.player.age==12 and game.model.data.player.role=="child","Restart preserves the child's actual age and role after the losses")
	_check(not game.world.village_life_world.actors.silvanus.visible and not game.world.village_life_world.actors.sextus.visible,"A fresh World scene does not resurrect either of the same dead identities")
	await _simulate(3.0,0.5)
	var count := 0
	for receipt: Dictionary in game.model.data.village.childhood.journal:
		count += int(receipt.scene_id=="night_resolution")
	_check(count==1 and game.model.data.village.raid.number==1,"Live post-reload simulation neither replays losses nor starts a second automatic raid")


func _finish_vow() -> void:
	for item: Array in [["grief_aurelia","listen"],["father_memory","remember"],["smith_memory","remember"],["survivor_visit","accept"],["marcus_after","vow"],["departure","leave"]]:
		if not await _ui_step(item[0],item[1]):
			return
	_check(game.model.data.village.childhood.scene_id=="journey" and game.model.data.village.childhood.memories.revenge_vow=="sworn","The actual Main dialogue path reaches the explicit revenge vow and departure")
	_check(game.model.data.player.age==12 and not game.model.data.progress.training_complete and game.model.data.squad.recruits==0,"The departure creates no automatic soldier, adult age or command of troops")
	_check(game.model._read_save(ProjectSettings.globalize_path(game.SAVE_PATH)).ok,"The complete actual departure is saved by the production action path")


func _command_step(scene: String, choice: String) -> bool:
	var objective: Dictionary = game.model.get_childhood_objective()
	var point := Vector2(float(objective.position[0]),float(objective.position[1]))
	_move_point(point+Vector2(-0.65,0.65))
	var result: Dictionary = game._command("childhood_choose",{"scene_id":scene,"choice":choice})
	_check(result.ok,"Valid preparation command: %s / %s (%s)" % [scene,choice,result.message])
	return result.ok


func _ui_step(scene: String, choice: String) -> bool:
	_check(game.model.data.village.childhood.scene_id==scene,"Expected real Main story scene: " + scene)
	var objective: Dictionary = game.model.get_childhood_objective()
	var point := Vector2(float(objective.position[0]),float(objective.position[1]))
	_move_point(Childhood.REFUGE+Vector2(1.0,0.0) if scene=="night_escort" else point+Vector2(-0.65,0.65))
	await _frames(2)
	game.world.action_requested.emit("childhood_interact",{"npc_id":objective.npc_id})
	await _frames(1)
	_check(game.screen=="childhood_dialog","The physical World interaction opens the actual night/followup dialogue: " + scene)
	if game.screen!="childhood_dialog":
		return false
	var frozen := JSON.stringify(game.model.data)
	game._process(5.0)
	_check(JSON.stringify(game.model.data)==frozen,"Reading the actual night or mourning dialogue freezes clocks: " + scene)
	var button: Button = game.ui.find_child("FrontierChoice_"+choice,true,false)
	_check(button!=null and not button.disabled and button.is_visible_in_tree(),"An actual enabled choice button exists: " + scene + " / " + choice)
	if button==null or button.disabled:
		return false
	button.pressed.emit()
	await _frames(1)
	_check(game.model.data.village.childhood.scene_id!=scene,"The real choice advances exactly once: " + scene)
	root.go_back_requested.emit()
	await _frames(1)
	_check(game.screen=="playing","Android Back returns from the night/followup dialogue: " + scene)
	return game.screen=="playing" and game.model.data.village.childhood.scene_id!=scene


func _restart_saved(label: String) -> void:
	_check(game._save(false).ok,"Production save succeeds before restart: " + label)
	game.queue_free()
	await _frames(3)
	await _spawn()
	game._continue_game()
	game.set_process(false)
	game.world.set_physics_process(false)
	await _frames(2)
	_check(game.screen=="playing","A newly instantiated Main continues the actual saved world: " + label)


func _simulate(seconds: float, step: float) -> void:
	var remaining := seconds
	while remaining>0.000001:
		await physics_frame
		var delta := minf(step,remaining)
		game._process(delta)
		remaining -= delta


func _move_point(point: Vector2, sync := true) -> void:
	var position := Vector3(point.x,Neighborhood.floor_height_at(point)+0.95,point.y)
	game.world.get_node("Player").position = position
	game.model.set_player_position(position)
	if sync:
		game.world.sync_state(game.model.data)
		game.world._update_camera(0.05)


func _is_night() -> bool:
	var environment: Environment = game.world.get("_village_environment")
	return environment.background_mode==Environment.BG_COLOR and environment.background_color.is_equal_approx(Color("101a2c"))


func _person(id: String) -> Dictionary:
	for person: Dictionary in game.model.data.village.economy.people:
		if person.id==id:
			return person
	return {}


func _frames(count: int) -> void:
	for index in count:
		await process_frame


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
