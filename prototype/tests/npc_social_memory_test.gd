extends SceneTree
## Social memory only follows observed, mutual interaction. Save-envelope and
## shared-economy integration are also exercised by team_b_integration_test.gd.

const Model = preload("res://scripts/domain/world_model.gd")
const Behavior = preload("res://scripts/domain/npc_behavior.gd")
const Social = preload("res://scripts/domain/npc_social_memory.gd")
var checks := 0
var failures: Array[String] = []
var sight_calls := 0
var sight_points: Array[Vector3] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_real_conversations()
	_test_unavailable_and_unobserved()
	_test_visibility()
	_test_companion_perception()
	_test_preferences_and_order()
	_test_replay_and_cooldown()
	_test_overlapping_observations()
	_test_invalid_observations()
	_test_bounded_memory()
	_test_contract()
	_test_legacy()
	_test_neighbor_view()
	if failures.is_empty():
		print("NPC social memory: %d checks passed" % checks)
		quit(0)
	else:
		print("NPC social memory: %d failures / %d checks" % [failures.size(),checks])
		quit(1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)


func _fresh() -> Dictionary:
	var model := Model.new()
	model.new_game("italia",true,true)
	var data: Dictionary = model.data.duplicate(true)
	data.player.position = [70.0,1.0,70.0]
	return data


func _set_conversation(data: Dictionary, first := "flavia", second := "bassa") -> void:
	Behavior.observe(data,{first:{"position":[-16.0,0.0,5.0]},second:{"position":[-16.0,0.0,6.0]}},true)
	var people: Dictionary = data.village.behavior.people
	for id: String in [first,second]:
		people[id].activity = "socialize"
		people[id].reason = "company"
		people[id].partner = second if id == first else first
		people[id].social_need = 100.0
		people[id].fatigue = 5.0
		people[id].since = float(data.village.behavior.seconds)
		people[id].next_decision = float(data.village.behavior.seconds)+0.5


func _ticks(data: Dictionary, seconds: float) -> void:
	for index in roundi(seconds/Behavior.STEP):
		data.world_seconds = float(data.world_seconds)+Behavior.STEP
		Behavior.advance(data,Behavior.STEP)


func _test_real_conversations() -> void:
	var data := _fresh()
	var resources: Dictionary = data.resources.duplicate(true)
	var story: Dictionary = data.village.childhood.duplicate(true)
	var player_trust: Dictionary = data.village.social.duplicate(true)
	_set_conversation(data)
	_ticks(data,7.5)
	_check(Social.relationship(data.village.behavior.social,"flavia","bassa").encounters == 0,"A passing greeting is not a completed conversation")
	_ticks(data,7.5)
	var relation := Social.relationship(data.village.behavior.social,"flavia","bassa")
	_check(relation.status == "familiar" and relation.encounters == 1,"Eight observed reciprocal seconds form an acquaintance, not an instant friendship")
	_check(relation.shared_seconds == 15.0,"Only the actual fixed-step conversation time is remembered")
	_check(Behavior.view(data,"flavia").reason == Behavior.EXPLANATIONS.familiar_neighbor,"Remembered acquaintance is visible in the existing activity explanation")
	for episode in 2:
		Behavior.observe(data,{},true)
		_ticks(data,35.0)
		_set_conversation(data)
		_ticks(data,15.0)
	relation = Social.relationship(data.village.behavior.social,"flavia","bassa")
	_check(relation.status == "friend" and relation.encounters == 3 and relation.shared_seconds == 45.0,"A friendship requires three separate completed encounters and cumulative shared time")
	_check(Social.relationship(data.village.behavior.social,"bassa","flavia") == relation,"Both residents refer to one symmetric relationship")
	_check(data.resources == resources and data.village.childhood == story and data.village.social == player_trust,"NPC friendship creates no goods, quests, player trust or rewards")
	_check(Behavior.validate(data).is_empty(),"Accumulated social memories satisfy the strict behavior contract")


func _test_unavailable_and_unobserved() -> void:
	var data := _fresh()
	_set_conversation(data)
	data.village.behavior.people.bassa.observed = false
	_ticks(data,0.5)
	_check(data.village.behavior.social.pairs.is_empty(),"An unobserved partner grants no social memory")
	_set_conversation(data)
	data.village.behavior.people.bassa.partner = "lucius"
	_ticks(data,0.5)
	_check(data.village.behavior.social.pairs.is_empty(),"A one-sided conversation grants no social memory")
	_set_conversation(data)
	data.village.behavior.people.bassa.activity = "absent"
	_ticks(data,0.5)
	_check(data.village.behavior.social.pairs.is_empty(),"An absent resident cannot form a new encounter")
	_set_conversation(data)
	data.village.behavior.people.bassa.position[1] = 4.0
	_ticks(data,0.5)
	_check(data.village.behavior.social.pairs.is_empty(),"Residents on separate floors do not converse through the floor")
	_set_conversation(data,"fabius","drusa")
	for person: Dictionary in data.village.economy.people:
		if person.id == "drusa":
			person.alive = false
	var before := float(data.village.behavior.people.fabius.social_need)
	_ticks(data,0.5)
	_check(data.village.behavior.social.pairs.is_empty(),"Death blocks a stale observed conversation in the same tick")
	_check(float(data.village.behavior.people.fabius.social_need) >= before,"A deceased interlocutor cannot satisfy the survivor's social need")
	_check(data.village.behavior.people.fabius.partner != "drusa","The next partner choice excludes a deceased economic resident immediately")
	data = _fresh()
	_set_conversation(data,"fabius","drusa")
	data.village.militia = ["drusa"]
	_ticks(data,0.5)
	_check(data.village.behavior.social.pairs.is_empty(),"Military duty blocks stale civilian conversation")
	data = _fresh()
	data.village.raid.active = true
	data.village.raid.enemies = [{"id":"perception_fixture","health":40,"x":-16.0,"z":3.0}]
	Behavior.observe(data,{"flavia":{"position":[-16.0,0.0,5.0]}},true)
	_ticks(data,0.5)
	_check(data.village.behavior.people.flavia.activity == "flee","An observed mobile resident reacts to nearby active danger")
	Behavior.observe(data,{},true)
	_ticks(data,0.5)
	_check(data.village.behavior.people.flavia.activity != "flee","A hidden body cannot keep detecting danger at its stale position")


func _test_preferences_and_order() -> void:
	var data := _fresh()
	_set_conversation(data)
	var people: Dictionary = data.village.behavior.people
	Behavior.observe(data,{"marius":{"position":[-16.0,0.0,5.8]}})
	var social := Social.initial_state()
	social.pairs[Social.pair_key("flavia","bassa")] = _pair(45.0,3,100.0)
	# Compare exactly the same candidates with and without learned friendship.
	var chosen := Behavior._nearby_partner("flavia",people.flavia,Behavior.profile("flavia"),people,social)
	_check(chosen == "bassa","An established friend remains an attractive choice among nearby residents")
	_check(Behavior._nearby_partner("flavia",people.flavia,Behavior.profile("flavia"),people,{}) == "marius","Removing the learned friendship changes the choice to the nearer resident sharing an interest")
	var reversed := {}
	var ids: Array = people.keys()
	ids.reverse()
	for id: String in ids:
		reversed[id] = people[id].duplicate(true)
	_check(Behavior._nearby_partner("flavia",reversed.flavia,Behavior.profile("flavia"),reversed,social) == chosen,"Partner selection is independent of dictionary insertion order")
	people.bassa.position = [-16.0,0.0,10.0]
	_check(Behavior._nearby_partner("flavia",people.flavia,Behavior.profile("flavia"),people,social) != "bassa","Friendship does not grant remote perception or unlimited pursuit")
	var whole := _fresh()
	_set_conversation(whole)
	var split: Dictionary = whole.duplicate(true)
	whole.world_seconds = 12.5
	Behavior.advance(whole,12.5)
	for index in 50:
		split.world_seconds = float(split.world_seconds)+0.25
		Behavior.advance(split,0.25)
	_check(whole.village.behavior == split.village.behavior,"Relationships and decisions remain invariant under frame partition")


func _test_visibility() -> void:
	var data := _fresh()
	_set_conversation(data)
	var before_need := float(data.village.behavior.people.flavia.social_need)
	data.world_seconds = 0.5
	Behavior.advance(data,0.5,_blocked_sight)
	_check(data.village.behavior.social.pairs.is_empty(),"A geometry blocker prevents conversation credit through a wall")
	_check(float(data.village.behavior.people.flavia.social_need) >= before_need,"A blocked conversation does not satisfy social need")
	_check(data.village.behavior.people.flavia.partner.is_empty(),"A neighbor behind a wall is not selected as a visible social partner")
	data.village.behavior.people.flavia.next_decision = 0.0
	data.village.behavior.people.bassa.next_decision = 0.0
	data.world_seconds = 1.0
	Behavior.advance(data,0.5,_clear_sight)
	data.world_seconds = 1.5
	Behavior.advance(data,0.5,_clear_sight)
	_check(not data.village.behavior.social.pairs.is_empty(),"Cleared visibility is observed on the next decision round, without a stale persisted cache")
	data = _fresh()
	Behavior.observe(data,{"flavia":{"position":[-16.0,0.0,5.0]}},true)
	data.player.position = [-16.0,0.9,5.6]
	data.village.raid.active = true
	data.village.raid.enemies = [{"id":"occluded","health":40,"x":-16.0,"z":7.0}]
	data.world_seconds = 0.5
	Behavior.advance(data,0.5,_blocked_sight)
	_check(data.village.behavior.people.flavia.activity not in ["flee","greet","yield"],"A wall blocks visual danger and player proximity reactions")
	_check(data.village.behavior.people.flavia.memories.is_empty(),"A hidden enemy does not create a danger_seen memory")
	data.player.position = [70.0,0.9,70.0]
	data.world_seconds = 1.0
	Behavior.advance(data,0.5,_clear_sight)
	_check(data.village.behavior.people.flavia.activity == "flee" and data.village.behavior.people.flavia.memories.back().kind == "danger_seen","A newly clear view of the real active threat creates the appropriate response")
	var people := _people("flavia","bassa")
	var cache := {}
	sight_calls = 0
	Social.close_conversation(people.flavia,people.bassa,_counted_clear_sight,cache)
	Social.close_conversation(people.bassa,people.flavia,_counted_clear_sight,cache)
	_check(sight_calls == 1,"One decision round reuses the symmetric visibility result for both speakers")
	people.bassa.position = [0.0,0.0,20.0]
	Social.close_conversation(people.flavia,people.bassa,_counted_clear_sight,cache)
	_check(sight_calls == 1,"Distance filtering happens before expensive geometry queries")
	people.bassa.position = [0.0,0.0,1.0]
	_check(Social.close_conversation(people.flavia,people.bassa,_clear_sight) and not Social.close_conversation(people.flavia,people.bassa,_blocked_sight),"Calls without an explicit per-round cache never reuse a past visibility result")
	sight_calls = 0
	var raid := {"enemies":[{"id":"near_hidden","health":40,"x":-16.0,"z":7.0},
		{"id":"next_visible","health":40,"x":-16.0,"z":8.0},{"id":"farther","health":40,"x":-16.0,"z":9.0}]}
	var distance := Behavior._nearest_visible_danger(data.village.behavior.people.flavia,raid,_selective_sight,{})
	_check(distance == 3.0 and sight_calls == 2,"Danger perception stops at the nearest visible living threat")


func _blocked_sight(_from: Vector3, _to: Vector3) -> bool:
	return false


func _clear_sight(_from: Vector3, _to: Vector3) -> bool:
	return true


func _counted_clear_sight(_from: Vector3, _to: Vector3) -> bool:
	sight_calls += 1
	return true


func _selective_sight(_from: Vector3, to: Vector3) -> bool:
	sight_calls += 1
	return to.z >= 8.0


func _test_companion_perception() -> void:
	var data := _fresh()
	_set_conversation(data,"flavia","marcus")
	data.village.behavior.people.marcus.position[1] = 0.9
	var saved_marcus: Array = data.village.behavior.people.marcus.position.duplicate()
	sight_points.clear()
	data.world_seconds = 0.5
	Behavior.advance(data,0.5,_recorded_sight)
	_check(data.village.behavior.people.marcus.position == saved_marcus,"Marcus retains his established saved center-height position")
	_check(sight_points.has(Vector3(-16.0,0.0,6.0)) and not sight_points.has(Vector3(-16.0,0.9,6.0)),"Marcus uses his actual foot point in social visibility queries")
	_check(data.village.behavior.social.pairs.has(Social.pair_key("flavia","marcus")),"Marcus can form a real observed reciprocal conversation using the same height contract")
	var nearby: Dictionary = Behavior._perception_people(data.village.behavior.people)
	_check(Behavior._nearby_partner("flavia",nearby.flavia,Behavior.profile("flavia"),nearby,{}, {},_clear_sight) == "marcus","Marcus remains a valid nearby social choice after transient coordinate normalization")
	data.player.position = [-16.0,0.9,6.6]
	data.village.raid.active = true
	data.village.raid.enemies = [{"id":"companion_threat","health":40,"x":-16.0,"z":8.0}]
	sight_points.clear()
	data.world_seconds = 1.0
	Behavior.advance(data,0.5,_recorded_sight)
	_check(not sight_points.has(Vector3(-16.0,0.9,6.0)) and data.village.behavior.people.marcus.activity == "alert","Companion danger and player proximity use the same normalized foot point")


func _recorded_sight(from: Vector3, to: Vector3) -> bool:
	sight_points.append(from)
	sight_points.append(to)
	return true


func _test_replay_and_cooldown() -> void:
	var people := _people("flavia","bassa")
	var available := {"flavia":true,"bassa":true}
	var social := Social.initial_state()
	for index in 16:
		Social.advance(social,people,available,(index+1)*0.5,0.5)
	var before: Dictionary = social.duplicate(true)
	Social.advance(social,people,available,8.0,0.5)
	_check(social == before,"Replaying the same observation timestamp cannot duplicate relationship credit")
	for index in 120:
		Social.advance(social,people,available,8.5+index*0.5,0.5)
	_check(Social.relationship(social,"flavia","bassa").encounters == 1,"One uninterrupted conversation cannot farm repeated encounters")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(social,"",true,true))
	for state: Dictionary in [social,restored]:
		for index in 16:
			Social.advance(state,people,available,80.0+index*0.5,0.5)
	_check(_same(social,restored),"Restarting midway retains session boundaries and cooldowns")
	_check(Social.relationship(social,"flavia","bassa").encounters == 2,"A separate later completed conversation contributes one encounter")
	var tiny := Social.initial_state()
	for index in 16:
		Social.advance(tiny,people,available,(index+1)*0.5,0.5)
	for index in 16:
		Social.advance(tiny,people,available,10.0+index*0.5,0.5)
	_check(Social.relationship(tiny,"flavia","bassa").encounters == 1,"Rapid leave-and-return cannot bypass the encounter cooldown")


func _test_overlapping_observations() -> void:
	var people := _people("flavia","bassa")
	var available := {"flavia":true,"bassa":true}
	var social := Social.initial_state()
	var key := Social.pair_key("flavia","bassa")
	Social.advance(social,people,available,0.5,0.5)
	Social.advance(social,people,available,0.75,0.5)
	Social.advance(social,people,available,1.0,0.5)
	_check(is_equal_approx(float(social.pairs[key].shared_seconds),1.0),"Overlapping observations only earn previously unobserved seconds")
	_check(is_equal_approx(float(social.pairs[key].session_seconds),1.0),"Overlapping intervals cannot accelerate the encounter threshold")
	_check(Social.validate(social,["flavia","bassa"],1.0).is_empty(),"Overlapping observations still satisfy elapsed-time validation")
	var before: Dictionary = social.duplicate(true)
	Social.advance(social,people,available,0.75,0.5)
	Social.advance(social,people,available,1.0,0.5)
	_check(social == before,"Older and identical timestamps leave the complete ledger unchanged")
	for index in range(5,32):
		Social.advance(social,people,available,float(index)*0.25,0.5)
	_check(is_equal_approx(float(social.pairs[key].shared_seconds),7.75),"Dense overlapping observations cannot create extra time")
	_check(int(social.pairs[key].encounters)==0,"No encounter before eight actual elapsed seconds")
	Social.advance(social,people,available,8.0,0.5)
	_check(is_equal_approx(float(social.pairs[key].shared_seconds),8.0) and int(social.pairs[key].encounters)==1,"The first actual eight-second encounter is retained")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(social,"",true,true))
	for state: Dictionary in [social,restored]:
		Social.advance(state,people,available,8.25,0.5)
		Social.advance(state,people,available,12.0,0.5)
	_check(_same(social,restored),"Serialized contact watermark prevents overlapping credit after restart")
	_check(is_equal_approx(float(social.pairs[key].shared_seconds),8.75) and is_equal_approx(float(social.pairs[key].session_seconds),0.5),"A gap opens a new session and never credits unobserved time")
	_check(int(social.pairs[key].encounters)==1 and Social.validate(social,["flavia","bassa"],12.0).is_empty(),"Encounter cooldown and valid bounded memory are preserved")


func _test_invalid_observations() -> void:
	var people := _people("flavia","bassa")
	var invalid: Array = [[],[0.0,0.0],[0.0,0.0,1.0,2.0],[NAN,0.0,0.0],[0.0,INF,0.0],[0.0,0.0,"0"],[true,0.0,0.0],null,"missing"]
	for value: Variant in invalid:
		people.flavia.position = value
		var cache := {}
		sight_calls = 0
		_check(not Social.close_conversation(people.flavia,people.bassa,_counted_clear_sight,cache),"Malformed observation cannot establish an encounter")
		_check(sight_calls == 0 and cache.is_empty(),"Malformed observation cannot reach or populate geometry cache")
	people = _people("flavia","bassa")
	people.flavia.observed = "true"
	_check(not Social.close_conversation(people.flavia,people.bassa),"A string cannot masquerade as an observed NPC")
	people.flavia.observed = true
	_check(Social.close_conversation(people.flavia,people.bassa),"Valid domain-only observations remain compatible")
	sight_calls = 0
	var cache := {}
	_check(not Social.clear_sight([0.0,0.0],[0.0,0.0,1.0],_counted_clear_sight,cache),"Invalid direct sight input fails closed")
	_check(not Social.clear_sight([0.0,0.0,NAN],[0.0,0.0,1.0]),"Invalid direct sight input fails closed without physics")
	_check(sight_calls == 0 and cache.is_empty(),"Invalid direct endpoints never invoke the sight adapter")
	var forged := Social.initial_state()
	forged.pairs[Social.pair_key("flavia","bassa")] = {"shared_seconds":2.0,"encounters":0,"last_contact":1.0,"session_seconds":1.0,"session_counted":false,"last_encounter":-1.0}
	_check(not Social.validate(forged,["flavia","bassa"],100.0).is_empty(),"Claimed shared time cannot exceed the last real contact timestamp")


func _test_bounded_memory() -> void:
	var social := Social.initial_state()
	var ids: Array = Behavior.roster().keys()
	ids.sort()
	var now := 0.5
	for first in ids.size():
		for second in range(first+1,ids.size()):
			var one: String = ids[first]
			var two: String = ids[second]
			Social.advance(social,_people(one,two),{one:true,two:true},now,0.5)
			now += 0.5
	_check(social.pairs.size() == Social.MAX_PAIRS,"The full village cannot grow social memory beyond its fixed pair budget")
	_check(Social.validate(social,ids,now).is_empty(),"Every retained pair uses canonical known resident IDs and bounded values")
	var strong := Social.pair_key(ids[0],ids[1])
	social.pairs.erase(social.pairs.keys()[0])
	social.pairs[strong] = _pair(45.0,3,now)
	Social.advance(social,_people(ids[2],ids[3]),{ids[2]:true,ids[3]:true},now+0.5,0.5)
	_check(social.pairs.has(strong),"Memory pressure retains established friendship ahead of a brief encounter")


func _test_contract() -> void:
	var ids: Array = Behavior.roster().keys()
	var good := Social.initial_state()
	good.pairs["bassa:flavia"] = _pair(45.0,3,100.0)
	_check(Social.validate(good,ids,100.0).is_empty(),"A canonical earned relationship validates")
	for bad_key: Variant in ["intruder:flavia","flavia:flavia","flavia:bassa","bassa:flavia:lucius",42]:
		var bad: Dictionary = good.duplicate(true)
		bad.pairs = {bad_key:_pair(45.0,3,100.0)}
		_check(not Social.validate(bad,ids,100.0).is_empty(),"Reject malformed or unknown pair ID: "+str(bad_key))
	for patch: Dictionary in [{"shared_seconds":NAN},{"encounters":0.5},{"shared_seconds":1.0},{"last_contact":101.0},{"session_counted":"true"},{"session_seconds":100.0},{"last_encounter":-1.0}]:
		var bad: Dictionary = good.duplicate(true)
		bad.pairs["bassa:flavia"].merge(patch,true)
		_check(not Social.validate(bad,ids,100.0).is_empty(),"Reject inconsistent relationship field: "+str(patch.keys()[0]))
	var bad: Dictionary = good.duplicate(true)
	bad.version = true
	_check(not Social.validate(bad,ids,100.0).is_empty(),"A boolean cannot masquerade as a relationship version")
	bad = good.duplicate(true)
	bad.pairs["bassa:flavia"].unknown_reward = 100
	_check(not Social.validate(bad,ids,100.0).is_empty(),"Unknown fields cannot introduce reward-bearing relationship data")
	bad = good.duplicate(true)
	bad.pairs["bassa:flavia"].last_encounter = 10.0
	_check(not Social.validate(bad,ids,100.0).is_empty(),"Three claimed encounters cannot fit inside ten seconds")
	bad = good.duplicate(true)
	bad.pairs["bassa:flavia"].shared_seconds = 101.0
	_check(not Social.validate(bad,ids,100.0).is_empty(),"Claimed shared time cannot exceed total elapsed world time")


func _test_legacy() -> void:
	var legacy := _fresh()
	legacy.village.behavior.erase("social")
	var before: Dictionary = legacy.village.behavior.duplicate(true)
	_check(Behavior.validate(legacy).is_empty(),"Existing behavior-v1 saves remain valid before migration")
	Behavior.ensure_social(legacy)
	var migrated: Dictionary = legacy.village.behavior.duplicate(true)
	migrated.erase("social")
	_check(migrated == before and legacy.village.behavior.social == Social.initial_state(),"Migration preserves every old need, memory and route and invents no past friendship")
	legacy.village.behavior.social = {"version":1,"pairs":{"flavia:intruder":{}}}
	var malformed: Dictionary = legacy.village.behavior.social.duplicate(true)
	Behavior.ensure_social(legacy)
	_check(legacy.village.behavior.social == malformed and not Behavior.validate(legacy).is_empty(),"A present corrupt social record is rejected, never reset by migration")


func _test_neighbor_view() -> void:
	var data := _fresh()
	data.village.behavior.social.pairs[Social.pair_key("flavia","bassa")] = _pair(45.0,3,100.0)
	data.village.behavior.social.pairs[Social.pair_key("flavia","marius")] = _pair(15.0,1,100.0)
	data.village.behavior.social.pairs[Social.pair_key("flavia","severus")] = _pair(45.0,3,100.0)
	var before: Dictionary = data.duplicate(true)
	var neighbors := Behavior.social_neighbors(data,"flavia")
	_check(neighbors.size() == 3 and neighbors[0].id == "bassa" and neighbors[1].id == "severus" and neighbors[2].id == "marius","The panel lists remembered friends first, then acquaintances, with stable ID order")
	_check(neighbors[1].name == "Wachmann","Remembered people use the current screenplay display name without changing their saved identity")
	_check(data == before,"Reading neighbor memories does not modify the world or earn more friendship")
	neighbors[0].encounters = 99
	_check(Behavior.social_neighbors(data,"flavia")[0].encounters == 3,"UI data cannot mutate the underlying relationship ledger")
	_check(Behavior.social_neighbors(data,"intruder").is_empty(),"Unknown panel IDs return no invented resident")


func _people(first: String, second: String) -> Dictionary:
	return {first:{"activity":"socialize","partner":second,"observed":true,"position":[0.0,0.0,0.0]},
		second:{"activity":"socialize","partner":first,"observed":true,"position":[0.0,0.0,1.0]}}


func _pair(seconds: float, encounters: int, now: float) -> Dictionary:
	return {"shared_seconds":seconds,"encounters":encounters,"last_contact":now,"session_seconds":15.0,
		"session_counted":true,"last_encounter":now-7.0}


func _same(left: Variant, right: Variant) -> bool:
	if typeof(left) in [TYPE_INT,TYPE_FLOAT] and typeof(right) in [TYPE_INT,TYPE_FLOAT]:
		return absf(float(left)-float(right)) < 0.000000001
	if typeof(left) == TYPE_DICTIONARY and typeof(right) == TYPE_DICTIONARY:
		if left.size() != right.size():
			return false
		for key: Variant in left:
			if not right.has(key) or not _same(left[key],right[key]):
				return false
		return true
	return left == right
