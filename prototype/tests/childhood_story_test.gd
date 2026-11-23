extends SceneTree

const Model = preload("res://scripts/domain/world_model.gd")
const Childhood = preload("res://scripts/story/childhood_story.gd")
const Life = preload("res://scripts/story/village_life.gd")
const PATH_TO_NIGHT := [
	["family_morning","promise"], ["father_lunch","deliver"],
	["friend_well","join"], ["well_search","inspect"], ["friend_return","return"],
	["day1_evening","tell"], ["day1_sleep","sleep"],
	["father_invitation","ask"], ["smith_first","help"], ["smith_material","take"],
	["smith_work","careful"], ["smith_account","truth"], ["day2_evening","return"], ["day2_sleep","sleep"],
	["smith_second","borrow"], ["smith_practice","listen"], ["market_offer","accept"],
	["delivery_road","secure"], ["delivery_field","deliver"], ["delivery_account","paid"],
	["day3_evening","stay"], ["day3_sleep","sleep"], ["healer_request","food"],
	["father_promise","promise"], ["smith_third","buy"], ["patrol_brief","join"],
	["patrol_south","observe"], ["patrol_east","report"], ["watchpost_help","report"],
	["day4_evening","share"], ["day4_sleep","sleep"]
]
const REFUSAL_PATH := [
	["family_morning","decline"], ["father_lunch","explain"], ["friend_well","decline"],
	["day1_evening","quiet"], ["day1_sleep","sleep"], ["father_invitation","go"],
	["smith_first","observe"], ["smith_account","truth"], ["day2_evening","uncertain"], ["day2_sleep","sleep"],
	["smith_second","watch"], ["smith_practice","stop"], ["market_offer","decline"],
	["day3_evening","ask"], ["day3_sleep","sleep"], ["healer_request","visit"],
	["father_promise","promise"], ["smith_third","talk"], ["patrol_brief","message"],
	["watchpost_help","report"], ["day4_evening","embrace"], ["day4_sleep","sleep"]
]
var assertions := 0
var failures: Array[String] = []
var files: Array[String] = []


func _initialize() -> void:
	_test_new_childhood_and_clock()
	_test_world_authority_and_stale_choices()
	_test_authored_path_and_saves()
	_test_failures_and_refusal_continuation()
	_test_night_escort_and_irreversible_loss()
	_test_pending_help_needs_real_action()
	_test_hiding_and_replay()
	_test_actual_combat_evidence()
	_test_legacy_migration()
	_test_corrupt_story_is_rejected()
	for path: String in files:
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
			if FileAccess.file_exists(path+suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("CHILDHOOD STORY: %d checks; %d failures" % [assertions,failures.size()])
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _new():
	var model = Model.new()
	model.new_game("italia",true,true)
	_check(model._validate_state(model.data)=="","New childhood has a valid shared world and resource balance")
	return model


func _test_new_childhood_and_clock() -> void:
	var model = _new()
	_check(Childhood.enabled(model.data) and model.data.village.economy.people.size()==14,"The new childhood uses the fourteen existing people")
	_check(model.data.buildings.is_empty() and not model.data.village.economy.authority.player_is_ruler,"A family home does not invent a player-built hut or village authority")
	for place: Dictionary in model.data.village.economy.workplaces.values():
		_check(place.condition==100,"The existing village starts with an intact workplace")
	_check(model.data.resources.wood==12 and model.data.resources.grain==28 and model.data.resources.stone==8,"Documented starting village stocks enter the exact signed ledger")
	_check(_person(model,"julia").assignment=="idle" and _person(model,"silvanus").assignment=="idle" and _person(model,"sextus").assignment=="idle","Parents and the smith do not produce at a second invisible workplace")
	var before: Dictionary = model.data.village.childhood.duplicate(true)
	model.advance(301.25)
	_check(model.data.village.childhood==before,"Five minutes of active simulation do not skip childhood scenes, narrated days, or the explicit night choice")
	_check(model.data.village.raid.number==0 and model.data.player.age==12 and model.data.progress.years_elapsed==0,"The inherited two-minute raid and six-year jump stay closed")
	_check(model.data.village.economy.day>0 and model.data.village.childhood.day==1,"Work cycles are recorded independently of explicit narrated day closures")
	var view: Dictionary = model.get_childhood_view()
	_check(view.year==100 and view.age==12 and view.day==1 and is_equal_approx(view.economy_seconds,301.25),"The view exposes the actual calendar age and economic elapsed clock")
	_check(model._validate_state(model.data)=="","Long idle simulation preserves the entire world balance")


func _test_world_authority_and_stale_choices() -> void:
	var model = _new()
	var before: Dictionary = model.data.duplicate(true)
	for command: String in ["train","training_hit","build","recruit","start_skirmish","village_request_work"]:
		var args := {"x":8.0,"z":2.0} if command=="build" else {}
		_check(not model.execute(command,args).ok,"A childhood player cannot bypass the story with the legacy command " + command)
	_check(model.data==before,"Blocked shortcuts do not mutate age, resources, authority or people")
	var wrong := model.execute("childhood_choose",{"scene_id":"night_decision","choice":"defend"})
	_check(not wrong.ok and model.data==before,"A future night choice cannot be called before its prerequisites")
	model.set_player_position(Vector3(50,1,50))
	_check(not model.execute("childhood_choose",{"scene_id":"family_morning","choice":"promise"}).ok,"The mother's actual position is required for accepting a parcel")
	_check(_choose(model,"family_morning","promise","parcel-one"),"The real mother encounter reserves the actual two rations")
	var after: Dictionary = model.data.duplicate(true)
	var duplicate: Dictionary = model.execute("childhood_choose",{"scene_id":"family_morning","choice":"promise"},"parcel-one")
	_check(duplicate.ok and model.data==after,"The same idempotency receipt cannot take the rations twice")
	_check(not model.execute("childhood_choose",{"scene_id":"family_morning","choice":"promise"},"parcel-two").ok and model.data==after,"A stale scene with a new request ID cannot be replayed")
	for i in 3:
		model.get_childhood_dialog("julia")
	_check(model.data==after,"Revisiting family dialogue does not farm trust, money, or new receipts")


func _test_authored_path_and_saves() -> void:
	var model = _new()
	var saved_material := false
	var paid_before := int(model.data.resources.denarii)
	for item: Array in PATH_TO_NIGHT:
		if item[0]=="smith_work":
			var path := _path("material")
			_check(model.save_game(path).ok,"Save succeeds while the smith's actual material is in transit")
			var loaded = Model.new()
			_check(loaded.load_game(path).ok and loaded.data.village.childhood.cargo.billets==2,"Reload preserves the reserved material and pending work")
			model = loaded
			saved_material = true
		if not _choose(model,item[0],item[1]):
			return
		var target: Dictionary = model.get_childhood_objective()
		if target.npc_id!="":
			var point: Vector2 = Life.actor_position(model.data,target.npc_id)
			_check(point.is_equal_approx(Vector2(target.position[0],target.position[1])),"Quest and visible person's source agree for " + target.npc_id)
		if item[0] in ["day1_sleep","day2_sleep","day3_sleep","day4_sleep"]:
			var path := _path(str(item[0]))
			var snapshot: Dictionary = model.data.village.childhood.duplicate(true)
			_check(model.save_game(path).ok,"An explicit day closure is saveable")
			var loaded = Model.new()
			_check(loaded.load_game(path).ok and Childhood._equivalent(loaded.data.village.childhood,snapshot),"A restart preserves the exact day closure without re-closing the day")
			model = loaded
	_check(saved_material and model.data.resources.denarii==paid_before+1,"Two real completed jobs pay once and the purchased practice staff costs one denarius")
	_check(model.data.village.childhood.equipment.practice_staff=="owned","The acquired practice staff is an explicit persistent item")
	_check(model.data.village.childhood.closed_days.size()==4 and model.data.village.childhood.scene_id=="night_decision","Four actual day conclusions open the pending night decision")
	_check(model.data.village.childhood.night_raid.decision=="pending" and model.data.village.childhood.night_raid.phase=="dormant","There is no timer-selected night branch")
	model.advance(40.0)
	_check(model.data.village.childhood.scene_id=="night_decision" and model.data.village.raid.number==0,"Even at the night scene, waiting cannot decide or start the attack")
	_check(model.data.player.age==12 and not Life.training_ready(model.data),"The authored arc does not grant adult soldier status")


func _test_failures_and_refusal_continuation() -> void:
	var failed = _new()
	for item: Array in [["family_morning","promise"],["father_lunch","lost"],["friend_well","join"],["well_search","guess"],["friend_return","blame"],["day1_evening","tell"],["day1_sleep","sleep"],["father_invitation","ask"],["smith_first","help"],["smith_material","take"],["smith_work","rush"],["smith_account","truth"]]:
		if not _choose(failed,item[0],item[1]):
			return
	_check(failed.data.resources.denarii==30 and failed.data.village.childhood.memories.smith_work=="split","Failed smith work consumes its real materials without paying imaginary wages")
	_check(failed.data.village.childhood.memories.meal=="lost" and failed.data.village.childhood.bonds.marcus<10,"Lost food and an unsupported accusation leave distinct memories and relationship consequences")
	_check(failed.data.village.childhood.scene_id=="day2_evening","Failure has a continuing family scene instead of a progression dead end")
	var refused = _new()
	for item: Array in REFUSAL_PATH:
		if not _choose(refused,item[0],item[1]):
			return
	_check(refused.data.village.childhood.scene_id=="night_decision" and refused.data.resources.denarii==30,"Declining errands and watching instruction still produce a connected four-day life without reward farming")
	_check(refused.data.village.childhood.bonds.sextus>10 and refused.data.village.childhood.memories.has("father_promise"),"Repeated personal smith and father scenes establish the bond without requiring successful paid work")


func _to_night():
	var model = _new()
	for item: Array in PATH_TO_NIGHT:
		if not _choose(model,item[0],item[1]):
			return null
	return model


func _test_night_escort_and_irreversible_loss() -> void:
	var model = _to_night()
	if model==null:
		return
	if not _choose(model,"night_decision","defend"):
		return
	_check(not model.data.village.childhood.night_raid.support_confirmed,"A promise to fight is not observed support")
	model.advance(12.75)
	var approach_path := _path("approach")
	_check(model.save_game(approach_path).ok,"The rider approach can be saved at a fractional elapsed time")
	var loaded = Model.new()
	_check(loaded.load_game(approach_path).ok and loaded.data.village.childhood.night_raid.elapsed==model.data.village.childhood.night_raid.elapsed,"Restart preserves the exact approach phase, decision and elapsed time")
	model = loaded
	if not _choose(model,"night_mother","escort"):
		return
	_check(not model.data.village.childhood.night_raid.support_confirmed,"Starting an escort is not the completed rescue")
	var before: Dictionary = model.data.duplicate(true)
	_check(not model.execute("childhood_choose",{"scene_id":"night_escort","choice":"arrive"}).ok and model.data==before,"The second physical destination cannot be confirmed from the parents' house")
	model.set_player_position(Vector3(Childhood.REFUGE.x,1,Childhood.REFUGE.y))
	_check(not model.execute("childhood_choose",{"scene_id":"night_escort","choice":"arrive"}).ok,"The player's destination alone cannot teleport Julia or complete the rescue")
	model.advance(2.0,0.0)
	_check(model.data.village.childhood.escort.progress==0.0,"An actual-world collision cap stops the escort while the shared simulation clock keeps running")
	var blocked_snapshot: Dictionary = model.data.duplicate(true)
	model.advance(1.0,NAN)
	_check(model.data==blocked_snapshot,"An invalid physical progress limit does not mutate the world")
	model.advance(5.0)
	var escort_progress: float = model.data.village.childhood.escort.progress
	_check(escort_progress>0.0 and escort_progress<=5.0*Childhood.ESCORT_SPEED+0.0001,"The mother moves along the doorway route with a bounded real walking speed")
	var escort_path := _path("escort_walking")
	_check(model.save_game(escort_path).ok,"The exact position during the escort is saveable")
	loaded = Model.new()
	_check(loaded.load_game(escort_path).ok and Childhood._equivalent(loaded.data.village.childhood.escort,model.data.village.childhood.escort),"Restart does not teleport the mother to the player or lose her progress")
	model = loaded
	model.advance(20.0,Childhood._escort_length()-1.0)
	before = model.data.duplicate(true)
	_check(not model.execute("childhood_choose",{"scene_id":"night_escort","choice":"arrive"}).ok and model.data==before,"Julia still on the outer doorstep cannot be booked as safely inside the refuge")
	model.advance(2.0)
	_check(model.get_childhood_objective().npc_id=="julia" and not model.get_childhood_dialog("julia").choices.is_empty(),"At actual arrival the same mother is the reachable confirmation speaker")
	if not _choose(model,"night_escort","arrive"):
		return
	_check(model.data.village.childhood.night_raid.support_kind=="escort","Reaching the actual neighbour house records the completed support action")
	model.advance(180.0)
	_check(model.data.village.childhood.night_raid.consequences_applied,"The completed live raid applies its irreversible authored consequence")
	_check(not _person(model,"silvanus").alive and not _person(model,"sextus").alive and _person(model,"julia").alive,"Father and his best friend die; Julia survives the real rescue")
	_check(model.data.village.childhood.night_raid.outcome=="mother_survived" and model.get_childhood_objective().npc_id=="aurelia","The next objective points to a living survivor instead of a dead required person")
	var outcome_path := _path("mother_survives")
	_check(model.save_game(outcome_path).ok,"The irreversible survivor branch is saveable")
	loaded = Model.new()
	_check(loaded.load_game(outcome_path).ok,"The complete changed population and story load together")
	model = loaded
	var night_before: Dictionary = model.data.village.childhood.night_raid.duplicate(true)
	model.advance(10.0)
	_check(model.data.village.childhood.night_raid==night_before and _resolution_count(model)==1,"Advancing after reload does not replay deaths or open a second raid")
	for item: Array in [["grief_aurelia","listen"],["father_memory","remember"],["smith_memory","remember"],["survivor_visit","accept"],["marcus_after","vow"],["departure","leave"]]:
		if not _choose(model,item[0],item[1]):
			return
	_check(model.data.village.childhood.memories.revenge_vow=="sworn" and model.data.player.age==12 and model.data.player.role=="child","The actual departure is motivated by a remembered revenge vow without automatic age, rank or imperial power")
	_check(model.get_childhood_dialog("silvanus").is_empty() and model.get_childhood_dialog("sextus").is_empty(),"Dead relatives cannot be required dialogue targets or invisible speakers")
	_check(model._validate_state(model.data)=="","The survivor branch conserves resources, time, identities and irreversible losses")


func _test_pending_help_needs_real_action() -> void:
	var model = _to_night()
	if model==null or not _choose(model,"night_decision","defend"):
		return
	model.advance(220.0)
	_check(model.data.village.raid.completed==1 and not model.data.village.childhood.night_raid.consequences_applied,"The combat timer does not invent a branch when a promised contribution is still missing")
	_check(not model.data.village.childhood.night_raid.support_confirmed and model.get_childhood_objective().npc_id=="julia","A promised but unperformed defense retains a reachable real rescue task")
	var path := _path("help_pending")
	_check(model.save_game(path).ok,"An unresolved personal decision remains saveable after the live attack")
	var loaded = Model.new()
	_check(loaded.load_game(path).ok and loaded.data.village.childhood.night_raid.decision=="defend","Restart preserves an unfinished defense intention instead of silently choosing hiding")
	model = loaded
	if not _choose(model,"night_mother","escort"):
		return
	model.set_player_position(Vector3(Childhood.REFUGE.x,1,Childhood.REFUGE.y))
	model.advance(25.0)
	if not _choose(model,"night_escort","arrive"):
		return
	_check(model.data.village.childhood.night_raid.outcome=="mother_survived" and model.get_childhood_objective().npc_id=="aurelia","Completing the actual still-needed rescue resolves the stored branch once")


func _test_hiding_and_replay() -> void:
	var model = _to_night()
	if model==null or not _choose(model,"night_decision","hide"):
		return
	var path := _path("hidden")
	_check(model.save_game(path).ok,"The hiding choice saves before its consequences")
	var loaded = Model.new()
	_check(loaded.load_game(path).ok,"Hiding remains the explicit choice after restart")
	model = loaded
	model.advance(32.2)
	var enemy: Dictionary = model.data.village.raid.enemies[0]
	model.set_player_position(Vector3(enemy.x,1.0,enemy.z))
	_check(not model.execute("village_strike",{"enemy_id":enemy.id}).ok,"A hidden branch cannot use an out-of-band command to rewrite itself as defense")
	model.set_player_position(Vector3(Childhood.HOME.x,1,Childhood.HOME.y))
	model.advance(180.0)
	_check(model.data.village.childhood.night_raid.outcome=="parents_lost","The explicit hiding branch retains its defined loss")
	for id: String in ["julia","silvanus","sextus"]:
		var person := _person(model,id)
		_check(not person.alive and person.health==0 and person.assignment=="idle","The actual roster permanently records death and removed work for " + id)
	_check(model.data.village.economy.people.size()==14 and _resolution_count(model)==1,"Losses change the same identities; no duplicate people or duplicate death receipts are made")
	_check(model.save_game(path).ok and loaded.load_game(path).ok,"The saved loss branch can be restored after all three deaths")
	_check(not _person(loaded,"julia").alive and loaded.get_childhood_objective().npc_id=="aurelia","A restarted loss branch does not resurrect the mother or target her as a required speaker")


func _test_actual_combat_evidence() -> void:
	var model = _to_night()
	if model==null or not _choose(model,"night_decision","defend"):
		return
	model.advance(32.1)
	_check(model.execute("village_block").ok,"A defense window can be opened in the actual raid")
	_check(not model.data.village.childhood.night_raid.support_confirmed,"Pressing block with no enemy hit does not count as a performed defense")
	var enemy: Dictionary = model.data.village.raid.enemies[0]
	model.set_player_position(Vector3(enemy.x,1.0,enemy.z))
	var health := int(enemy.health)
	_check(model.execute("village_strike",{"enemy_id":enemy.id}).ok,"A real in-range strike is accepted by the existing combat rules")
	_check(int(model.data.village.raid.enemies[0].health)<health and model.data.village.childhood.night_raid.support_kind=="combat","Observed damage, not the chosen intention, is the support evidence")
	model.set_player_position(Vector3(Childhood.REFUGE.x,1,Childhood.REFUGE.y))
	model.advance(180.0)
	_check(model.data.village.childhood.night_raid.outcome=="mother_survived" and _person(model,"julia").alive,"The actual combat contribution preserves the mother without pretending that father or Sextus survived")


func _test_legacy_migration() -> void:
	var legacy = Model.new()
	legacy.new_game("italia",true)
	_check(not Childhood.enabled(legacy.data),"The previous two-argument village constructor retains its legacy meaning")
	legacy.advance(0.035)
	var old: Dictionary = legacy.data.duplicate(true)
	old.schema_version = 5
	old.village.erase("childhood")
	old.village.erase("trade")
	var path := _path("schema5")
	_write_legacy(path,old)
	var loaded = Model.new()
	_check(loaded.load_game(path).ok and loaded.data.schema_version==Model.SCHEMA_VERSION,"An actual schema-5 save migrates through the normal file loader")
	_check(not Childhood.enabled(loaded.data) and loaded.data.resources==old.resources and loaded.data.player==old.player and loaded.data.village.economy==old.village.economy,"Migration preserves the existing player, people, sub-tick clocks and every resource")
	var adult = Model.new()
	for i in 3:
		adult.set_player_position(Vector3(-8,1,2))
		_check(adult.execute("gather",{"node_id":"timber_0"}).ok,"Legacy fixture gathers actual material")
	adult.set_player_position(Vector3(-3,1,4))
	_check(adult.execute("choose_companion",{"choice":"help"}).ok,"Legacy fixture resolves its own companion encounter")
	_check(adult.execute("build",{"x":8.0,"z":2.0}).ok,"Legacy fixture builds its own existing prologue home")
	adult.set_player_position(Vector3(8,1,2))
	adult.advance(12.0)
	adult.set_player_position(Vector3(0,1,-7))
	_check(adult.execute("train").ok and adult.data.player.age==18,"The older isolated life path can still make its explicit adult transition")
	old = adult.data.duplicate(true)
	old.schema_version = 5
	old.village.erase("childhood")
	old.village.erase("trade")
	path = _path("adult_schema5")
	_write_legacy(path,old)
	_check(loaded.load_game(path).ok and loaded.data.player.age==18 and loaded.data.progress.stage=="training" and not Childhood.enabled(loaded.data),"An adult legacy save is not reset to a new childhood or new family fate")


func _test_corrupt_story_is_rejected() -> void:
	var model = _new()
	if not _choose(model,"family_morning","promise"):
		return
	var valid: Dictionary = model.data.duplicate(true)
	model.data.village.childhood.ledger.grain += 2
	_check(not model._validate_state(model.data).is_empty(),"A parcel ledger changed without a scene receipt is rejected")
	model.data = valid.duplicate(true)
	model.data.village.childhood.scene_id = "night_decision"
	_check(not model._validate_state(model.data).is_empty(),"Skipping the four-day scene chain in a save is rejected")
	model.data = valid.duplicate(true)
	model.data.village.childhood.night_raid.support_confirmed = true
	model.data.village.childhood.night_raid.support_kind = "combat"
	_check(not model._validate_state(model.data).is_empty(),"An invented support flag without decision or observed combat is rejected")
	model.data = valid.duplicate(true)
	model.data.village.childhood.journal.append(model.data.village.childhood.journal[0].duplicate(true))
	_check(not model._validate_state(model.data).is_empty(),"Duplicated completed scene receipts are rejected")
	model.data = valid.duplicate(true)
	model.data.player.age = 18
	_check(not model._validate_state(model.data).is_empty(),"An unearned age jump cannot enter a new childhood save")
	model.data = valid.duplicate(true)
	model.data.village.childhood.escort.position = [Childhood.REFUGE.x,Childhood.REFUGE.y]
	_check(not model._validate_state(model.data).is_empty(),"An invented escort position away from the recorded path progress is rejected")


func _choose(model, scene: String, choice: String, id := "") -> bool:
	var target: Dictionary = model.get_childhood_objective()
	if target.is_empty():
		_check(false,"No active objective for " + scene)
		return false
	model.set_player_position(Vector3(target.position[0],1.0,target.position[1]))
	var result: Dictionary = model.execute("childhood_choose",{"scene_id":scene,"choice":choice},id)
	_check(result.ok,"Actual scene %s / %s: %s" % [scene,choice,result.message])
	return result.ok


func _person(model,id: String) -> Dictionary:
	for person: Dictionary in model.data.village.economy.people:
		if person.id==id:
			return person
	return {}


func _resolution_count(model) -> int:
	var result := 0
	for receipt: Dictionary in model.data.village.childhood.journal:
		result += int(receipt.scene_id=="night_resolution")
	return result


func _path(id: String) -> String:
	var path := "user://childhood_story_test_%s.json" % id
	files.append(path)
	return path


func _write_legacy(path: String, state: Dictionary) -> void:
	var payload := JSON.stringify(state,"",true,true)
	var envelope := JSON.stringify({"format":Model.SAVE_FORMAT,"format_version":1,"payload":payload,"sha256":payload.sha256_text()})
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(envelope)
	file.close()


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
