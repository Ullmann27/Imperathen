extends SceneTree

const Life = preload("res://scripts/story/village_life.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_test_history_and_reads()
	_test_relationships_professions_allies()
	_test_high_trust_progression()
	_test_warning_and_preparation()
	_test_real_combat_and_defense()
	_test_losses_recovery_and_staff()
	_test_time_save_validation()
	_test_actor_positions_and_guard_distance()
	_test_unavailable_mentors()
	print("VILLAGE_LIFE_RESULT checks=%d failures=%d" % [checks,failures.size()])
	for failure: String in failures:
		printerr("FAIL: "+failure)
	print("VILLAGE_LIFE_PASS" if failures.is_empty() else "VILLAGE_LIFE_FAIL")
	quit(0 if failures.is_empty() else 1)


func _fixture() -> Dictionary:
	var data := {"origin_id":"italia","resources":{"wood":40,"grain":60,"denarii":30,"stone":20},
		"player":{"position":[0.0,1.0,8.0],"health":100,"age":12},"progress":{"years_elapsed":0},
		"buildings":[{"completed":true}],"encounter":{"active":false},"village":{"enabled":true,"economy":{"people":[{"id":"silvanus","name":"Silvanus","alive":true,"health":100,"hunger":0,"assignment":"idle"}],"workplaces":{"watchpost":{"condition":60}}}}}
	for id: String in Life.NPCS:
		if id!="decimus":
			data.village.economy.people.append({"id":id,"name":Life.NPCS[id].name,"alive":true,"health":100,"hunger":0,"assignment":"idle"})
	Life.ensure(data)
	return data


func _at(data: Dictionary, point: Vector2) -> void:
	data.player.position = [point.x,1.0,point.y]


func _meet(data: Dictionary, id: String) -> void:
	var npc: Dictionary = Life.NPCS[id]
	_at(data,Vector2(npc.x,npc.z))
	_check(Life.execute(data,"village_talk",{"npc_id":id,"choice":"meet"}).ok,"Actual first meeting: "+id)


func _ready() -> Dictionary:
	var data := _fixture()
	for id: String in ["decimus","varro","severus"]:
		_meet(data,id)
	_at(data,Vector2(50.0,50.0))
	return data


func _active() -> Dictionary:
	var data := _ready()
	Life.advance(data,Life.FIRST_WARNING)
	Life.advance(data,Life.WARNING_SECONDS)
	_check(data.village.raid.active,"Warning becomes an actual timed attack")
	return data


func _snapshot(data: Dictionary) -> String:
	return JSON.stringify(data)


func _test_history_and_reads() -> void:
	var data := _fixture()
	_check(Life.validate(data)=="","Initial village data is valid")
	var before := _snapshot(data)
	var view: Dictionary = Life.view(data)
	_check(view.player_authority=="Bewohner" and view.ruler.contains("Trajan"),"A historical ruler and local steward precede the player")
	_check(view.history.current_year==100 and view.history.anchors.size()==3,"Historical baseline and documented anchors are explicit")
	_check(Life.npc_catalog().size()==7,"Seven individually named speaking people exist")
	for npc: Dictionary in Life.npc_catalog():
		var dialogue: Dictionary = Life.dialogue(data,npc.id)
		_check(dialogue.title.contains(npc.name) and not dialogue.text.is_empty(),"Distinct character introduction: "+npc.id)
		_check(dialogue.choices.size()==1,"An unknown person first requires meeting: "+npc.id)
	view.npcs.clear()
	view.raid.number = 999
	_check(_snapshot(data)==before,"Rendering and modifying returned presentation data cannot change the campaign")
	data.progress.years_elapsed = 6
	_check(Life.view(data).history.current_year==106,"Historical calendar follows the existing confirmed age progression")
	data.progress.years_elapsed = 18
	_check(not Life.view(data).ruler.contains("Trajan") and not Life.dialogue(data,"decimus").text.contains("Trajan"),"Later unimplemented history does not keep the historical emperor alive forever")
	data.origin_id = "han"
	_check(Life.view(data).history.anchors.is_empty() and not Life.view(data).ruler.contains("Trajan"),"Other origins receive no Roman historical assertion")
	_check(not Life.dialogue(data,"decimus").text.contains("Trajan"),"Regional fallback does not claim Roman rule")


func _test_relationships_professions_allies() -> void:
	var data := _fixture()
	var before := _snapshot(data)
	_check(not Life.execute(data,"village_talk",{"npc_id":"aelia","choice":"meet"}).ok and _snapshot(data)==before,"Remote conversation is rejected atomically")
	_meet(data,"aelia")
	before = _snapshot(data)
	_check(not Life.execute(data,"village_talk",{"npc_id":"aelia","choice":"meet"}).ok and _snapshot(data)==before,"Greeting repetition cannot farm trust")
	_check(not Life.execute(data,"village_learn",{"npc_id":"aelia"}).ok,"A profession needs a relationship earned through action")
	_check(Life.execute(data,"village_talk",{"npc_id":"aelia","choice":"help"}).ok,"The mentor's agreed practical help can be completed")
	_check(data.resources.wood==38 and data.village.social.ledger.wood==-2,"Actual material leaves the shared inventory and is accounted for")
	before = _snapshot(data)
	_check(not Life.execute(data,"village_talk",{"npc_id":"aelia","choice":"help"}).ok and _snapshot(data)==before,"Reopening a completed favor neither pays nor rewards twice")
	_check(Life.execute(data,"village_learn",{"npc_id":"aelia"}).ok and data.village.social.profession=="mason","A known mentor opens a real profession")
	_check(data.village.social.npcs.aelia.trust==12,"Distinct meeting, assistance and first apprenticeship carry bounded trust")
	_check(Life.execute(data,"village_ally",{"npc_id":"aelia"}).ok and data.resources.grain==58,"Alliance requires earned trust and shared provisions")
	before = _snapshot(data)
	_check(not Life.execute(data,"village_ally",{"npc_id":"aelia"}).ok and _snapshot(data)==before,"An alliance cannot be bought repeatedly")
	_meet(data,"cassia")
	_check(Life.execute(data,"village_talk",{"npc_id":"cassia","choice":"help"}).ok,"Another mentor has an independent relationship")
	_check(Life.execute(data,"village_learn",{"npc_id":"cassia"}).ok and data.resources.denarii==27 and data.village.social.profession=="trader","Career change remains possible and pays its actual cost")
	_check(data.village.history.mode=="fictional_branch","Fictional choices are not presented as a changed historical war")
	_check(data.village.history.events.back().provenance=="fictional_playable_event","Authored village events keep their provenance")
	_meet(data,"fabius")
	_check(Life.execute(data,"village_talk",{"npc_id":"fabius","choice":"decline"}).ok,"A meaningful refusal is available")
	_check(not Life.execute(data,"village_learn",{"npc_id":"fabius"}).ok,"A refused request does not silently award mentorship")
	var poor := _fixture()
	_meet(poor,"aurelia")
	poor.resources.grain = 0
	before = _snapshot(poor)
	_check(not Life.execute(poor,"village_talk",{"npc_id":"aurelia","choice":"help"}).ok and _snapshot(poor)==before,"Missing supplies cannot create fictitious help")
	for args: Dictionary in [{"npc_id":"ghost","choice":"meet"},{"npc_id":"aelia","choice":"help","xp":999},{"npc_id":42,"choice":"meet"}]:
		_check(not Life.execute(poor,"village_talk",args).ok,"Unknown identities and caller-selected rewards are rejected")


func _test_high_trust_progression() -> void:
	var data := _fixture()
	_meet(data,"aelia")
	# A saved relationship can approach 100 after repeated defended raids,
	# before the player accepts this mentor's separate one-time favor.
	data.village.social.npcs.aelia.trust = 99
	data = JSON.parse_string(JSON.stringify(data))
	_check(Life.validate(data).is_empty(),"High earned trust remains a valid restored relationship")
	var wood := int(data.resources.wood)
	_check(Life.execute(data,"village_talk",{"npc_id":"aelia","choice":"help"}).ok,"An old friend can still complete a favor near the trust limit")
	_check(data.resources.wood==wood-2 and data.village.social.npcs.aelia.helped and data.village.social.npcs.aelia.trust==100,"Saturated favor commits its actual cost and bounded relationship together")
	_check(Life.execute(data,"village_learn",{"npc_id":"aelia"}).ok,"Maximum trust does not lock the first apprenticeship")
	_check(data.village.social.profession=="mason" and data.village.social.npcs.aelia.learned and data.village.social.npcs.aelia.trust==100,"The profession is learned without exceeding the saved trust contract")
	var before := _snapshot(data)
	_check(not Life.execute(data,"village_talk",{"npc_id":"aelia","choice":"help"}).ok and _snapshot(data)==before,"Clamping trust does not make the one-time favor repeatable")
	# Aurelia also hears about real rescues before the first personal meeting.
	data.village.social.npcs.aurelia.trust = 100
	_at(data,Life.actor_position(data,"aurelia"))
	_check(Life.execute(data,"village_talk",{"npc_id":"aurelia","choice":"meet"}).ok,"Known rescue work cannot prevent meeting Aurelia at maximum trust")
	_check(data.village.social.npcs.aurelia.met and data.village.social.npcs.aurelia.trust==100 and Life.validate(data).is_empty(),"The first meeting at maximum trust remains valid and persistent")
	data.village.social.npcs.aurelia.trust = 101
	_check(not Life.validate(data).is_empty(),"The repair preserves strict rejection of out-of-range saved trust")


func _test_warning_and_preparation() -> void:
	var idle := _fixture()
	Life.advance(idle,240.0)
	_check(idle.village.raid.status=="quiet","A new player has time to establish a home and meet people")
	var data := _ready()
	Life.advance(data,119.9)
	_check(data.village.raid.status=="quiet","The first warning has a real elapsed-time prerequisite")
	Life.advance(data,0.1)
	_check(data.village.raid.status=="warning" and not data.village.raid.active,"Warning precedes the actual raid")
	var before := _snapshot(data)
	_check(not Life.execute(data,"village_alarm").ok and _snapshot(data)==before,"Alarm requires physically reaching the post")
	_at(data,Life.ALARM_POINT)
	_check(Life.execute(data,"village_alarm").ok and data.village.attributes.tactics==2,"A real early warning grows tactics once")
	_check(not Life.execute(data,"village_alarm").ok,"Alarm button repetition cannot farm tactics")
	_at(data,Life.SCOUT_POINT)
	_check(Life.execute(data,"village_scout").ok and data.village.attributes.insight==2,"Learning the scout and examining the actual trail grows insight")
	_check(not Life.execute(data,"village_scout").ok,"A trail is not an unlimited experience source")
	Life.advance(data,Life.WARNING_SECONDS)
	_check(data.village.raid.active and data.village.raid.enemies.size()==3,"Three live attackers spawn after the warning")
	_check(not Life.execute(data,"village_scout").ok,"The preparation opportunity closes when combat starts")
	_check(not Life.training_ready(data),"A shelter and first conversation do not immediately skip village life")
	var legacy := _ready()
	legacy.encounter.active = true
	Life.advance(legacy,300.0)
	_check(legacy.village.raid.status=="quiet","The new raid cannot overlap the existing skirmish")
	legacy.encounter.active = false
	Life.advance(legacy,0.1)
	_check(legacy.village.raid.status=="warning","The warning can start after the earlier encounter finishes")


func _test_real_combat_and_defense() -> void:
	var data := _active()
	var first: Dictionary = data.village.raid.enemies[0]
	var before := _snapshot(data)
	_check(not Life.execute(data,"village_strike",{"enemy_id":first.id}).ok and _snapshot(data)==before,"Distant attacks have no damage or XP")
	for index in data.village.raid.enemies.size():
		while int(data.village.raid.enemies[index].health)>0:
			var enemy: Dictionary = data.village.raid.enemies[index]
			_at(data,Vector2(enemy.x,enemy.z))
			_check(Life.execute(data,"village_strike",{"enemy_id":enemy.id}).ok,"Confirmed in-range attack damages a real live enemy")
			if data.village.raid.active:
				before = _snapshot(data)
				_check(not Life.execute(data,"village_strike",{"enemy_id":enemy.id}).ok and _snapshot(data)==before,"Attack cooldown or dead target prevents duplicate damage")
				Life.advance(data,0.7)
	_check(not data.village.raid.active and data.village.raid.won==1 and data.village.raid.completed==1,"Victory is settled only after all actual attackers are defeated")
	_check(data.village.attributes.combat==12 and data.village.attributes.courage==2,"Skill growth follows nine hits, three defeats and participation")
	Life.advance(data,80.0)
	_check(Life.training_ready(data),"Three village days, real meetings and a resolved danger unlock further training")
	_check(not Life.execute(data,"village_strike",{"enemy_id":first.id}).ok,"A settled fight cannot award another victory")
	var shield := _active()
	shield.village.raid.enemies[0].x = 0.0
	shield.village.raid.enemies[0].z = 0.0
	shield.village.raid.enemies[0].attack_timer = 0.2
	_at(shield,Vector2.ZERO)
	_check(Life.execute(shield,"village_block").ok and shield.village.attributes.combat==0,"Holding a shield alone grants no experience")
	Life.advance(shield,0.2)
	_check(shield.player.health==100 and shield.village.raid.blocks==1 and shield.village.attributes.combat==1,"The timed shield actually intercepts an enemy blow")
	_check(not Life.execute(shield,"village_dodge").ok,"Shield and dodge share a real recovery time")
	Life.advance(shield,1.0)
	shield.village.raid.enemies[0].attack_timer = 0.2
	_check(Life.execute(shield,"village_dodge").ok,"A recovered player can start a dodge window")
	Life.advance(shield,0.2)
	_check(shield.player.health==100 and shield.village.raid.dodges==1 and shield.village.attributes.insight==1,"A dodge protects against an attack and earns experience only on contact")
	Life.advance(shield,2.0)
	_check(shield.player.health<100,"Protection expires; it does not become permanent invulnerability")
	_at(shield,Life.RESCUE_POINT)
	_check(Life.execute(shield,"village_rescue").ok and shield.village.attributes.courage==2,"Physically reaching the threatened villager completes a real rescue")
	_check(not Life.execute(shield,"village_rescue").ok,"The same person cannot be rescued repeatedly for XP")


func _test_losses_recovery_and_staff() -> void:
	var data := _active()
	data.village.raid.rescue_available = false
	data.village.economy = {"people":[{"id":"severus","alive":true,"health":100,"hunger":0,"assignment":"defense"}],"workplaces":{"watchpost":{"condition":60}}}
	Life.advance(data,150.0)
	_check(not data.village.raid.active and data.village.raid.outcome=="raided","Ignoring the danger has a persisted loss outcome")
	_check(data.resources.grain==54 and data.village.social.ledger.grain==-6,"Raid loot is capped at six and charged to the same resource ledger")
	_check(data.village.economy.people[0].health==85,"An actual named defender receives the persistent injury")
	_check(data.village.attributes=={"courage":0,"combat":0,"insight":0,"tactics":0},"A player who contributes nothing gains no skill")
	data.village.economy.people.append({"id":"aurelia","name":"Aurelia","alive":true,"health":100,"hunger":0,"assignment":"idle"})
	_meet(data,"aurelia")
	data.player.health = 1
	_check(Life.execute(data,"village_recover").ok and data.player.health==26 and data.resources.grain==53,"Defeat has a real recovery route that consumes provisions")
	data.encounter.active = true
	var before := _snapshot(data)
	_check(not Life.execute(data,"village_recover").ok and _snapshot(data)==before,"The old battle cannot be bypassed with safe-village treatment")
	var staff := _fixture()
	staff.village.economy = {"people":[
		{"id":"severus","alive":true,"health":100,"hunger":0,"assignment":"watchpost"},
		{"id":"aelia","alive":true,"health":100,"hunger":0,"assignment":"quarry"},
		{"id":"varro","alive":true,"health":100,"hunger":0,"assignment":"defense"}],"workplaces":{"watchpost":{"condition":60}}}
	_check(Life.defense_strength(staff)==1,"A damaged post and a quarry worker cannot masquerade as ready guards")
	staff.village.economy.workplaces.watchpost.condition = 100
	_check(Life.defense_strength(staff)==2,"A repaired, staffed post contributes the actual available watchman")
	staff.village.economy.people[2].hunger = 2
	_check(Life.defense_strength(staff)==1,"A hungry defender is not counted as combat-ready")


func _test_actor_positions_and_guard_distance() -> void:
	var data := _fixture()
	_person(data,"aelia").assignment = "quarry"
	var actor: Vector2 = Life.actor_position(data,"aelia")
	_check(actor.distance_to(Life.WORKPLACE_POSITIONS.quarry)<4.0,"An assigned mentor is placed at her actual worksite")
	_at(data,Vector2(Life.NPCS.aelia.x,Life.NPCS.aelia.z))
	_check(not Life.execute(data,"village_talk",{"npc_id":"aelia","choice":"meet"}).ok,"The mentor cannot be addressed at her obsolete home position")
	_at(data,actor)
	_check(Life.execute(data,"village_talk",{"npc_id":"aelia","choice":"meet"}).ok,"Approaching the same rendered worksite actor opens the conversation")
	var presented: Dictionary = Life.view(data).npcs.filter(func(row): return row.id=="aelia")[0]
	_check(Vector2(presented.x,presented.z)==actor,"Presentation and command range use exactly the same actor location")
	_person(data,"severus").assignment = "quarry"
	_check(Life.actor_position(data,"aelia")!=Life.actor_position(data,"severus"),"Two real workers at one site receive different physical positions")
	var raid := _active()
	var rescued_id: String = raid.village.raid.rescue_person_id
	_check(rescued_id=="silvanus" and Life.actor_position(raid,rescued_id)==Life.RESCUE_POINT,"The threatened person is the existing roster identity at the visible rescue point")
	_at(raid,Life.RESCUE_POINT)
	_check(Life.execute(raid,"village_rescue").ok and raid.village.economy.people[0].health==100,"Rescuing changes the health of the same named person")
	var guarded := _active()
	_person(guarded,"severus").assignment = "watchpost"
	_person(guarded,"varro").assignment = "watchpost"
	guarded.village.economy.workplaces.watchpost.condition = 100
	for enemy: Dictionary in guarded.village.raid.enemies:
		enemy.z = 40.0
		enemy.x = 40.0
	_at(guarded,Vector2(-80.0,80.0))
	Life.advance(guarded,3.0)
	_check(guarded.village.raid.enemies[0].health==45,"Guards cannot damage enemies on the far side of the village")
	guarded.village.raid.enemies[0].x = 0.0
	guarded.village.raid.enemies[0].z = -48.0
	Life.advance(guarded,3.0)
	_check(guarded.village.raid.enemies[0].health==41,"Two actual ready guards damage a nearby attacker")
	_check(guarded.village.attributes.combat==0 and guarded.village.attributes.courage==0,"Guard achievements are not silently credited to the player")


func _test_time_save_validation() -> void:
	var whole := _ready()
	var split := whole.duplicate(true)
	Life.advance(whole,130.0)
	for index in 1300:
		Life.advance(split,0.1)
	_check(is_equal_approx(whole.village.social.seconds,split.village.social.seconds) and whole.village.raid==split.village.raid,"Timer partition does not change raid outcome or preparation window")
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(whole, "", true, true))
	_check(Life.validate(roundtrip)=="" and _equivalent(Life.view(roundtrip),Life.view(whole)),"Saving and restoring JSON preserves relationships, timers and history")
	Life.advance(roundtrip,35.0)
	Life.advance(whole,35.0)
	_check(_equivalent(roundtrip.village.raid,whole.village.raid),"A saved warning resumes deterministically")
	var before := _snapshot(whole)
	for delta in [-1.0,0.0,NAN,INF,3601.0]:
		_check(not Life.advance(whole,delta) and _snapshot(whole)==before,"Invalid elapsed time is rejected without mutation")
	var malformed := whole.duplicate(true)
	malformed.village.social.npcs.aelia.met = "yes"
	_check(Life.validate(malformed)!="","Malformed saved relationships are rejected")
	malformed = whole.duplicate(true)
	malformed.village.raid.enemies[0].x = NAN
	_check(Life.validate(malformed)!="","Non-finite saved enemy coordinates are rejected")
	malformed = whole.duplicate(true)
	malformed.village.raid.active = false
	_check(Life.validate(malformed)!="","Conflicting active/status flags are rejected")
	malformed = whole.duplicate(true)
	malformed.village.social.ledger.wood = -1.5
	_check(Life.validate(malformed)!="","Resource ledgers cannot contain fractional hidden costs")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _equivalent(left: Variant, right: Variant) -> bool:
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


func _person(data: Dictionary, id: String) -> Dictionary:
	for person: Dictionary in data.village.economy.people:
		if person.id==id:
			return person
	return {}


func _test_unavailable_mentors() -> void:
	var data := _fixture()
	_meet(data,"aurelia")
	_person(data,"aurelia").alive = false
	_person(data,"aurelia").health = 0
	data.player.health = 50
	var before := _snapshot(data)
	_check(not Life.is_available(data,"aurelia") and Life.dialogue(data,"aurelia").choices.is_empty(),"A dead mentor is remembered but offers no dialogue actions")
	_check(not Life.execute(data,"village_recover").ok and _snapshot(data)==before,"A deceased healer cannot heal or consume supplies")
	_check(not Life.execute(data,"village_learn",{"npc_id":"aurelia"}).ok,"A deceased mentor cannot offer an apprenticeship")
	data.village.militia = ["aelia"]
	_at(data,Life.actor_position(data,"aelia"))
	_check(not Life.execute(data,"village_talk",{"npc_id":"aelia","choice":"meet"}).ok,"A mentor deployed with the player troop cannot also hold village conversations")
	_check(Life.dialogue(data,"aelia").text.contains("Wachtrupp") and Life.dialogue(data,"aelia").choices.is_empty(),"Absent troop members have an explicit explanation")
