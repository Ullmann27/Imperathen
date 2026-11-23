extends SceneTree
## Full transactions through WorldModel, without directly awarding gameplay state.

const WorldModel = preload("res://scripts/domain/world_model.gd")
const Life = preload("res://scripts/story/village_life.gd")
const Economy = preload("res://scripts/domain/village_economy.gd")
var checks := 0
var failures: Array[String] = []
var directory := "user://village_model_%s" % Time.get_ticks_usec()


func _initialize() -> void:
	_test_disabled_legacy_and_arguments()
	_test_real_village_lifecycle()
	_test_time_partition_and_pending_save()
	_test_migration_and_corrupt_transactions()
	_cleanup()
	print("VILLAGE_MODEL_RESULT checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures:
		printerr("FAIL: "+failure)
	print("VILLAGE_MODEL_PASS" if failures.is_empty() else "VILLAGE_MODEL_FAIL")
	quit(0 if failures.is_empty() else 1)


func _new():
	var model=WorldModel.new()
	model.new_game("italia",true)
	_check(model.data.village.enabled,"Explicit new village chapter is enabled")
	_check(model._validate_state(model.data).is_empty(),"Complete initial world validates")
	return model


func _meet(model,id:String)->void:
	var at:Vector2=Life.actor_position(model.data,id)
	model.set_player_position(Vector3(at.x,1.0,at.y))
	_ok(model.execute("village_talk",{"npc_id":id,"choice":"meet"}),"Meet "+id)


func _near(model,id:String)->void:
	var at:Vector2=Life.actor_position(model.data,id)
	model.set_player_position(Vector3(at.x,1.0,at.y))


func _collect(model,count:int)->void:
	for index in count:
		var node_index:int=index/4
		var node:Dictionary=model.data.resource_nodes[node_index]
		model.set_player_position(Vector3(node.x,1.0,node.z))
		_ok(model.execute("gather",{"node_id":node.id}),"Gather actual wood "+str(index))


func _settled():
	var model=_new()
	_collect(model,12)
	_meet(model,"decimus")
	_ok(model.execute("village_request_work",{},"permit"),"Steward permits participation")
	for id in ["fabius","aurelia","varro"]:
		_meet(model,id)
	_near(model,"fabius")
	_ok(model.execute("village_talk",{"npc_id":"fabius","choice":"help"}),"Help mentor with real food")
	_ok(model.execute("village_learn",{"npc_id":"fabius"}),"Learn first occupation")
	model.set_player_position(Vector3(-3.0,1.0,4.0))
	_ok(model.execute("choose_companion",{"choice":"help"}),"Keep actual Marcus decision")
	model.set_player_position(Vector3(8.0,1.0,5.0))
	_ok(model.execute("build",{"x":8.0,"z":5.0}),"Pay for first home")
	model.advance(12.0)
	_check(model.data.buildings[0].completed,"Actual nearby construction completes home")
	for id in ["fabius","drusa"]:
		_ok(model.execute("village_assign",{"resident_id":id,"workplace_id":"woodcamp"}),"Assign named lumber worker "+id)
	_ok(model.execute("village_repair",{"workplace_id":"woodcamp"},"repair-woodcamp"),"Pay real lumber camp repair")
	return model


func _test_disabled_legacy_and_arguments() -> void:
	var legacy=WorldModel.new()
	var before:=JSON.stringify(legacy.data)
	_check(not legacy.execute("village_request_work").ok,"Legacy career does not silently enable new rules")
	_check(JSON.stringify(legacy.data)==before,"Rejected new command preserves old career")
	legacy.advance(20.0)
	_check(legacy.data.village.economy.day_seconds==0.0 and legacy.data.village.social.seconds==0.0,"Legacy career does not consume village rations")
	var foreign=WorldModel.new()
	foreign.new_game("germania",true)
	_check(not foreign.data.village.enabled,"Roman historical village is not forced onto other origins")
	var model=_new()
	before=JSON.stringify(model.data)
	for item in [
		["village_talk",{"npc_id":NAN,"choice":"meet"}],
		["village_talk",{"npc_id":"decimus","choice":"meet","xp":100}],
		["village_assign",{"resident_id":"fabius","workplace_id":INF}],
		["village_repair",{"workplace_id":"woodcamp","wood":-20}],
		["village_strike",{"enemy_id":"none","damage":999}],
		["receive_damage",{"amount":-5}],
		["village_buy_food",{"amount":-1}],
		["village_unknown",{}]
	]:
		_check(not model.execute(item[0],item[1]).ok,"Malformed or fabricated action rejected: "+item[0])
	_check(JSON.stringify(model.data)==before,"Malformed actions cannot alter resource, experience or identity state")
	for delta in [-1.0,NAN,INF,3601.0]:
		model.advance(delta)
	_check(JSON.stringify(model.data)==before,"Invalid world time is non-mutating")
	model.set_player_position(Vector3(0.0,1.0,-100.0))
	before=JSON.stringify(model.data)
	_check(not model.execute("village_talk",{"npc_id":"decimus","choice":"meet"}).ok,"Real dialogue requires the actor's location")
	_check(JSON.stringify(model.data)==before,"Remote dialogue gives no social credit")


func _test_real_village_lifecycle() -> void:
	var model=_settled()
	_check(model.data.player.role=="child" and not model.data.village.economy.authority.player_is_ruler,"Working villager has not become ruler or adult")
	model.set_player_position(Vector3(0.0,1.0,-7.0))
	_check(not model.execute("train").ok,"Old quick training path cannot skip new village life")
	model.advance(15.0)
	_check(is_equal_approx(model.data.village.economy.workplaces.woodcamp.project.remaining,15.0),"Repair needs actual joint labour in full world")
	var partial_path:=_path("repair-partial")
	_ok(model.save_game(partial_path),"Save paid partial repair")
	var loaded=WorldModel.new()
	_ok(loaded.load_game(partial_path),"Load paid partial repair")
	_check(loaded.data.village.enabled and loaded.data.village.social.profession=="woodcutter","New career and learned profession survive save")
	var paid_snapshot:=JSON.stringify(loaded.data)
	var repeated:Dictionary=loaded.execute("village_repair",{"workplace_id":"woodcamp"},"repair-woodcamp")
	_check(repeated.ok and JSON.stringify(loaded.data)==paid_snapshot,"Repeated saved command does not charge repair materials again")
	_check(not loaded.execute("village_repair",{"workplace_id":"quarry"},"repair-woodcamp").ok,"Same command identity cannot be repurposed")
	loaded.advance(15.0)
	_check(loaded.data.village.economy.workplaces.woodcamp.condition==100,"Loaded work completes only its remaining duration")
	var old_wood:int=loaded.data.resources.wood
	loaded.advance(30.0)
	_check(loaded.data.resources.wood==old_wood+9,"Chosen woodcutter profession has real production effect")
	_check(loaded.data.village.economy.ledger.wood==4,"Repair minus production is conserved in signed wood ledger")
	_check(loaded._validate_state(loaded.data).is_empty(),"Full world accepts cumulative economy/social/legacy resource balances")
	var before_time:float=loaded.data.village.social.seconds
	loaded.advance(120.0-before_time)
	_check(loaded.data.village.raid.status=="warning","Longer village phase produces a timed warning after home and acquaintances")
	loaded.set_player_position(Vector3(Life.SCOUT_POINT.x,1.0,Life.SCOUT_POINT.y))
	_ok(loaded.execute("village_scout",{},"first-scout"),"Actual route scouting gives insight")
	var scouted_snapshot:=JSON.stringify(loaded.data)
	_ok(loaded.execute("village_scout",{},"first-scout"),"Transport replay returns original scouting result")
	_check(JSON.stringify(loaded.data)==scouted_snapshot,"Repeated scouting identity cannot farm insight")
	loaded.set_player_position(Vector3(Life.ALARM_POINT.x,1.0,Life.ALARM_POINT.y))
	_ok(loaded.execute("village_alarm"),"Actual alarm gives tactical preparation")
	loaded.advance(Life.WARNING_SECONDS)
	_check(loaded.data.village.raid.active and loaded.data.village.raid.enemies.size()==3,"Warning becomes live three-person attack")
	old_wood=loaded.data.resources.wood
	loaded.advance(1.0)
	_check(loaded.data.resources.wood==old_wood,"Civilian output is suspended during attack")
	var enemy:Dictionary=loaded.data.village.raid.enemies[0]
	loaded.set_player_position(Vector3(enemy.x,1.0,enemy.z))
	loaded.advance(1.0)
	_check(loaded.data.player.health<100,"A real nearby telegraphed enemy attack damages the player")
	_check(loaded.data.village.health_delta==int(loaded.data.player.health)-100 and loaded.data.encounter.damage_taken==0,"Village damage is separated from legacy encounter losses")
	_ok(loaded.save_game(_path("raid-wounded")),"Live raid damage remains saveable with full health ledger")
	_check(not loaded.execute("village_recover").ok,"Combat cannot be bypassed by instant treatment")
	loaded.advance(0.9)
	_ok(loaded.execute("village_block"),"Shield action opens a real protection window")
	loaded.advance(0.9)
	_check(loaded.data.village.raid.blocks>=1,"Timed shield only earns skill when intercepting an actual hit")
	loaded.set_player_position(Vector3(Life.RESCUE_POINT.x,1.0,Life.RESCUE_POINT.y))
	_ok(loaded.execute("village_rescue"),"Rescue changes a named resident's actual state")
	var attempts:=0
	while loaded.data.village.raid.active and attempts<30:
		var target:Dictionary={}
		for item in loaded.data.village.raid.enemies:
			if int(item.health)>0:
				target=item
				break
		if target.is_empty():
			break
		loaded.set_player_position(Vector3(target.x,1.0,target.z))
		var result:Dictionary=loaded.execute("village_strike",{"enemy_id":target.id})
		if not result.ok:
			loaded.advance(0.7)
		else:
			_check(result.ok,"Real close-range strike accepted")
			loaded.advance(0.7)
		attempts+=1
	_check(loaded.data.village.raid.outcome=="defended" and loaded.data.village.raid.completed==1,"Raid victory follows actual defeated enemy roster")
	_check(loaded.data.village.attributes.courage>0 and loaded.data.village.attributes.combat>0 and loaded.data.village.attributes.insight>0 and loaded.data.village.attributes.tactics>0,"Four requested attributes have distinct actual contributions")
	_check(loaded.data.village.history.mode=="fictional_branch","Player-created outcomes are labeled alternate history")
	_near(loaded,"aurelia")
	var before_health:int=loaded.data.player.health
	var before_grain:int=loaded.data.resources.grain
	var healing:Dictionary=loaded.execute("village_recover",{},"first-treatment")
	_ok(healing,"Actual post-combat treatment consumes food")
	_check(loaded.data.player.health==mini(100,before_health+25) and loaded.data.resources.grain==before_grain-1,"Treatment increases actual health by capped amount and debits ration")
	_check(loaded._validate_state(loaded.data).is_empty(),"Healing preserves combined legacy and new health balance")
	var healed_snapshot:=JSON.stringify(loaded.data)
	_check(loaded.execute("village_recover",{},"first-treatment")==healing and JSON.stringify(loaded.data)==healed_snapshot,"Repeated treatment identity cannot heal or charge twice")
	_near(loaded,"fabius")
	_ok(loaded.execute("village_ally",{"npc_id":"fabius"}),"Earned mentor trust permits an actual personal alliance")
	_check(loaded.data.village.social.npcs.fabius.ally and _person(loaded,"fabius").assignment=="woodcamp","Alliance does not duplicate the person or remove his work identity")
	_ok(loaded.save_game(_path("complete-village")),"Completed first defense and relationships save")
	var final=WorldModel.new()
	_ok(final.load_game(_path("complete-village")),"Full saved village loads")
	_check(final.data.village.raid.completed==1 and final.data.village.social.npcs.fabius.ally and final.data.player.health==loaded.data.player.health,"Raid, friendship and health survive reload")
	final.set_player_position(Vector3(0.0,1.0,-7.0))
	_check(not final.execute("train").ok,"One quick raid still cannot skip two actual village days")
	final.advance(maxf(0.0,240.0-float(final.data.village.social.seconds)))
	_ok(final.execute("train"),"After real village time and defense, old adult transition remains available")
	_check(final.data.player.age==18 and final.data.village.social.npcs.fabius.ally,"Adult transition retains actual village relationships")
	_ok(final.save_game(_path("adult-village")),"Combined adult and village career saves")
	_exercise_militia(final)


func _exercise_militia(model) -> void:
	for index in 3:
		model.advance(0.65)
		_ok(model.execute("training_hit"),"Actual adult weapon exercise "+str(index+1))
	for index in 3:
		_ok(model.execute("recruit",{},"named-recruit-"+str(index)),"Actual named village recruit "+str(index+1))
	_check(model.data.village.militia.size()==3 and model.data.village.economy.people.size()==14,"Recruiting reserves does not create three additional people")
	for id in model.data.village.militia:
		var resident:=_person(model,id)
		_check(resident.alive and resident.assignment=="defense" and not Life.NPCS.has(id),"A real free non-mentor now belongs to squad: "+id)
	var first_id:String=model.data.village.militia[0]
	var before:=JSON.stringify(model.data)
	_check(not model.execute("village_assign",{"resident_id":first_id,"workplace_id":"quarry"}).ok,"Squad member cannot also work in quarry")
	_check(not model.execute("village_shift",{"resident_id":first_id,"duty":"return"}).ok,"Civilian action cannot silently duplicate a recruited soldier")
	_check(JSON.stringify(model.data)==before,"Invalid dual assignment preserves squad and workforce")
	var warned=WorldModel.new()
	warned.data=model.data.duplicate(true)
	warned.advance(float(warned.data.village.raid.next_at)-float(warned.data.village.social.seconds))
	_check(warned.data.village.raid.status=="warning","Later warning uses actual elapsed village time")
	var warning_before:=JSON.stringify(warned.data)
	_check(not warned.execute("start_skirmish").ok,"A second military encounter cannot freeze a live village warning")
	_check(JSON.stringify(warned.data)==warning_before,"Rejected overlapping battle consumes no people or resources")
	_ok(model.execute("start_skirmish"),"Named militia enters the existing adult skirmish")
	model.set_player_position(Vector3(6.0,1.0,-10.0))
	for index in 4:
		model.advance(1.3)
		_ok(model.execute("receive_damage",{"amount":8}),"Actual legacy skirmish hit "+str(index+1))
	_check(model.data.population.dead==1 and model.data.squad.alive==2,"Legacy casualty counter records one actual loss")
	_check(not _person(model,first_id).alive and _person(model,first_id).health==0,"Casualty removes the exact same recruited resident")
	_check(Economy.view(model.data).population.alive==13,"Village food and population now count thirteen survivors")
	_ok(model.save_game(_path("named-casualty")),"Named casualty and dual health ledger save")
	for index in model.data.encounter.enemies.size():
		var enemy:Dictionary=model.data.encounter.enemies[index]
		model.set_player_position(Vector3(enemy.x,1.0,enemy.z))
		var attempts:=0
		while int(model.data.encounter.enemies[index].health)>0 and attempts<4:
			model.advance(0.65)
			_ok(model.execute("strike_enemy",{"enemy_id":enemy.id}),"Actual adult close-range strike")
			attempts+=1
	_check(model.data.progress.skirmish_won,"Adult battle completes from actual enemy health")
	_near(model,"aurelia")
	var old_health:int=model.data.player.health
	var old_delta:int=model.data.village.health_delta
	_ok(model.execute("village_recover"),"Healer can treat wounds from the older military encounter after victory")
	_check(model.data.player.health==mini(100,old_health+25),"Treatment heals actual military wounds")
	_check(model.data.village.health_delta==old_delta+mini(25,100-old_health),"New healing is represented as signed delta alongside old damage ledger")
	_check(model.data.encounter.damage_taken==100+model.data.village.health_delta-model.data.player.health,"Both battle systems obey the same exact health conservation equation")
	_check(model.data.population.dead==1 and not _person(model,first_id).alive,"Healing player cannot resurrect a fallen resident")
	_ok(model.save_game(_path("healed-military")),"Combined post-military healing is saveable")
	var restored=WorldModel.new()
	_ok(restored.load_game(_path("healed-military")),"Combined post-military healing reloads")
	_check(restored.data.village.militia==model.data.village.militia and not _person(restored,first_id).alive,"Reload preserves recruited identities and exact casualty")


func _test_time_partition_and_pending_save() -> void:
	var a=_settled()
	var b=WorldModel.new()
	b.data=a.data.duplicate(true)
	a.advance(170.0)
	for index in 340:
		b.advance(0.5)
	_check(a.data.resources==b.data.resources,"Long and short world frames produce identical resource balances through raid onset")
	_check(a.data.village.economy.ledger==b.data.village.economy.ledger,"Economic ledger is independent of frame partition")
	_check(a.data.village.raid==b.data.village.raid,"Attack simulation matches across frame partitions")
	var social_a:Dictionary=a.data.village.social.duplicate(true)
	var social_b:Dictionary=b.data.village.social.duplicate(true)
	var residual_match:=absf(float(social_a.accumulator)-float(social_b.accumulator))<0.00000001
	social_a.erase("accumulator")
	social_b.erase("accumulator")
	_check(social_a==social_b and residual_match,"Social results and time match across frame partitions within numeric precision")
	_check(absf(a.data.world_seconds-b.data.world_seconds)<0.00001,"World clock receives exactly the requested time")
	var pending=_new()
	pending.advance(0.035)
	_check(is_equal_approx(pending.data.village.social.accumulator,0.035),"Subtick elapsed time is retained")
	_ok(pending.save_game(_path("pending-tick")),"Subtick clock saves")
	var restored=WorldModel.new()
	_ok(restored.load_game(_path("pending-tick")),"Subtick clock reloads")
	pending.advance(0.065)
	restored.advance(0.065)
	_check(pending.data.village==restored.data.village,"Subtick reload does not lose or duplicate ongoing time")


func _test_migration_and_corrupt_transactions() -> void:
	var old_model=WorldModel.new()
	old_model.set_player_position(Vector3(-8.0,1.0,2.0))
	var original:Dictionary=old_model.execute("gather",{"node_id":"timber_0"},"old-gather")
	var old:Dictionary=old_model.data.duplicate(true)
	old.schema_version=4
	old.erase("village")
	old.resources.erase("stone")
	var old_path:=_path("schema4")
	_write(old_path,old)
	var bytes:=FileAccess.get_file_as_string(old_path)
	var loaded=WorldModel.new()
	_ok(loaded.load_game(old_path),"Real schema4 shape migrates to schema5")
	_check(loaded.data.schema_version==5 and not loaded.data.village.enabled,"Migrated career is preserved without imposing new youth requirements")
	_check(loaded.data.resources.wood==4 and loaded.data.resources.stone==0,"Migration grants no resources")
	_check(FileAccess.get_file_as_string(old_path)==bytes,"Loading migration does not overwrite original file")
	var before:=JSON.stringify(loaded.data)
	_check(loaded.execute("gather",{"node_id":"timber_0"},"old-gather")==original and JSON.stringify(loaded.data)==before,"Historical command identities survive migration")
	for corruption in ["wood","grain","stone","health","clock","ledger"]:
		var model=_new()
		var broken:Dictionary=model.data.duplicate(true)
		match corruption:
			"wood": broken.resources.wood+=1
			"grain": broken.resources.grain+=1
			"stone": broken.resources.stone+=1
			"health": broken.player.health=95
			"clock": broken.village.social.seconds=1.0
			"ledger": broken.village.economy.ledger.wood=-1
		var path:=_path("invalid-"+corruption)
		_write(path,broken)
		before=JSON.stringify(model.data)
		_check(not model.load_game(path).ok,"Checksummed but inconsistent save is rejected: "+corruption)
		_check(JSON.stringify(model.data)==before,"Rejected save keeps live world: "+corruption)
		model.data=broken
		var corrupt_bytes:=var_to_bytes(model.data)
		_check(not model.execute("village_request_work").ok,"Command rejects inconsistent world: "+corruption)
		model.advance(1.0)
		_check(var_to_bytes(model.data)==corrupt_bytes,"Advance rejects inconsistent world atomically: "+corruption)
	var retained=_new()
	_ok(retained.save_game(_path("retained")),"Initial complete save available")
	var saved_bytes:=FileAccess.get_file_as_string(_path("retained"))
	_check(not retained.save_game("res://village-forbidden.json").ok,"Project resource path is not writable save target")
	_check(FileAccess.get_file_as_string(_path("retained"))==saved_bytes,"Save failure does not replace existing valid file")


func _person(model,id:String)->Dictionary:
	for person in model.data.village.economy.people:
		if person.id==id:
			return person
	return {}


func _path(name:String)->String:
	return directory.path_join(name+".json")


func _write(path:String,state:Dictionary)->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var payload:=JSON.stringify(state,"",true,true)
	var file:=FileAccess.open(path,FileAccess.WRITE)
	_check(file!=null,"Write explicit fault fixture")
	if file!=null:
		file.store_string(JSON.stringify({"format":WorldModel.SAVE_FORMAT,"format_version":1,"payload":payload,"sha256":payload.sha256_text()}))
		file.close()


func _cleanup()->void:
	var absolute:=ProjectSettings.globalize_path(directory)
	var folder:=DirAccess.open(absolute)
	if folder==null:
		return
	for filename in folder.get_files():
		DirAccess.remove_absolute(absolute.path_join(filename))
	DirAccess.remove_absolute(absolute)


func _ok(result:Dictionary,message:String)->void:
	_check(result.get("ok",false),message+" — "+str(result.get("message","")))


func _check(condition:bool,message:String)->void:
	checks+=1
	if not condition:
		failures.append(message)
