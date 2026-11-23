extends SceneTree

const Economy = preload("res://scripts/domain/village_economy.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_initial_authority_and_atomic_commands()
	_staffing_and_repairs()
	_production_and_conservation()
	_defense_and_raid_work_pause()
	_food_and_recovery()
	_profession_effects()
	_partition_save_and_boundary_tests()
	_invalid_state_tests()
	print("VILLAGE_ECONOMY_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	print("VILLAGE_ECONOMY_PASS" if failures.is_empty() else "VILLAGE_ECONOMY_FAIL")
	quit(0 if failures.is_empty() else 1)


func _world() -> Dictionary:
	var data := {"resources":{"wood":40,"grain":12,"denarii":30},"village":{"social":{"npcs":{"decimus":{"met":false}}},"raid":{"active":false}}}
	Economy.ensure(data)
	return data


func _permitted() -> Dictionary:
	var data := _world()
	data.village.social.npcs.decimus.met = true
	_check(Economy.execute(data,"village_request_work").ok,"Steward grants work after conversation")
	return data


func _initial_authority_and_atomic_commands() -> void:
	var data := _world()
	_check(Economy.validate(data).is_empty(),"Initial economy validates")
	_check(data.village.economy.people.size()==14,"Fourteen named adult residents exist")
	_check(not data.village.economy.authority.player_is_ruler,"Player is not ruler")
	_check(Economy.view(data).population.idle==10,"Existing farmers and guards occupy four of fourteen people")
	_check(data.resources.stone==0 and data.resources.wood==40,"Migration creates stone without awarding existing goods")
	var before := JSON.stringify(data)
	Economy.ensure(data)
	_check(JSON.stringify(data)==before,"Repeated ensure does not reset economy")
	_check(not Economy.execute(data,"village_request_work").ok,"Work permit requires real steward conversation")
	_check(not Economy.execute(data,"village_assign",{"resident_id":"fabius","workplace_id":"woodcamp"}).ok,"Assignment requires authority")
	_check(not Economy.execute(data,"village_request_work",{"force":true}).ok,"Hidden bypass argument rejected")
	_check(JSON.stringify(data)==before,"Rejected commands do not mutate state")
	data.village.social.npcs.decimus.met=true
	_check(Economy.execute(data,"village_request_work").ok,"Talked-to steward grants permit")
	before=JSON.stringify(data)
	_check(not Economy.execute(data,"village_request_work").ok,"Repeated permission has no reward")
	_check(not Economy.execute(data,"village_assign",{"resident_id":1,"workplace_id":"woodcamp"}).ok,"Invalid person type rejected")
	_check(not Economy.execute(data,"village_assign",{"resident_id":"fabius","workplace_id":"free_money"}).ok,"Unknown workplace rejected")
	_check(JSON.stringify(data)==before,"Invalid assignments remain atomic")


func _staffing_and_repairs() -> void:
	var data := _permitted()
	_check(Economy.execute(data,"village_repair",{"workplace_id":"woodcamp"}).ok,"Damaged woodcamp accepts a paid repair")
	_check(data.resources.wood==35 and data.village.economy.ledger.wood==-5,"Repair consumes exactly scaled material cost")
	Economy.advance(data,30.0)
	_check(data.village.economy.workplaces.woodcamp.condition==40,"Paid repair does not complete without staff")
	_assign(data,"fabius","woodcamp")
	Economy.advance(data,30.0)
	_check(data.village.economy.workplaces.woodcamp.condition==40,"One lumber worker cannot operate a two-person worksite")
	_assign(data,"drusa","woodcamp")
	var before := JSON.stringify(data)
	_check(not Economy.execute(data,"village_assign",{"resident_id":"sextus","workplace_id":"woodcamp"}).ok,"Third worker cannot overbook a two-person site")
	_check(JSON.stringify(data)==before,"Overbooking costs and moves nothing")
	Economy.advance(data,15.0)
	_check(data.village.economy.workplaces.woodcamp.condition==40 and data.village.economy.workplaces.woodcamp.project.remaining==15.0,"Repair progresses with actual work time")
	_check(data.resources.wood==35,"Partial repair produces no lumber")
	Economy.advance(data,15.0)
	_check(data.village.economy.workplaces.woodcamp.condition==100,"Two workers complete repair after thirty working seconds")
	_check(data.resources.wood==35,"Repair completion does not award unworked production")
	_check(not Economy.execute(data,"village_repair",{"workplace_id":"woodcamp"}).ok,"Finished site cannot be repaired for repeated credit")
	for id in ["aelia","quintus","sextus"]:
		_assign(data,id,"quarry")
	_check(Economy.execute(data,"village_repair",{"workplace_id":"quarry"}).ok,"Quarry repair begins with existing wood")
	Economy.advance(data,40.0)
	_check(data.village.economy.workplaces.quarry.condition==20,"Three workers cannot supply the required quarry crew of four")
	_assign(data,"antonia","quarry")
	Economy.advance(data,40.0)
	_check(data.village.economy.workplaces.quarry.condition==100,"Four workers restore quarry")
	_check(data.resources.stone==0,"Quarry repair does not create stone in the same work interval")
	Economy.advance(data,40.0)
	_check(data.resources.stone==6,"Four-person quarry creates first six stone only after its production interval")
	_check(_place(data,"quarry").required==4 and _place(data,"trade").required==2 and _place(data,"watchpost").required==2,"All requested crew sizes remain explicit")


func _production_and_conservation() -> void:
	var data := _permitted()
	_ready(data,"woodcamp",["fabius","drusa"])
	var initial_wood: int=data.resources.wood
	Economy.advance(data,29.0)
	_check(data.resources.wood==initial_wood,"No output before a complete production cycle")
	Economy.advance(data,1.0)
	_check(data.resources.wood==initial_wood+8 and data.village.economy.stocks.forest==232,"Lumber moves from finite forest to central store")
	_check(data.village.economy.ledger.wood==8,"Production has signed inventory ledger entry")
	data.village.economy.stocks.forest=8
	Economy.advance(data,60.0)
	_check(data.village.economy.stocks.forest==0 and data.resources.wood==initial_wood+16,"Exhausted forest cannot generate more wood")
	_check(_place(data,"woodcamp").reason.contains("erschöpft"),"Exhaustion reason is player-visible")
	_ready(data,"trade",["cassia","silvanus"])
	var before_money: int=data.resources.denarii
	initial_wood=data.resources.wood
	Economy.advance(data,60.0)
	_check(data.resources.wood==initial_wood-4 and data.resources.denarii==before_money+6,"Trade consumes actual cargo and produces its proceeds")
	_check(data.village.economy.stocks.merchant_denarii==594,"Merchant money is finite")
	data.resources.wood=0
	before_money=data.resources.denarii
	Economy.advance(data,120.0)
	_check(data.resources.denarii==before_money,"Trade without cargo stops")
	_check(_place(data,"trade").reason.contains("4 Holz"),"Missing trade cargo has clear explanation")
	data.resources.wood=Economy.MAX_RESOURCE-7
	data.village.economy.stocks.forest=16
	Economy.advance(data,30.0)
	_check(data.resources.wood<=Economy.MAX_RESOURCE,"Production never exceeds central inventory capacity")
	_check(Economy.validate(data).is_empty(),"Production state remains structurally valid")


func _defense_and_raid_work_pause() -> void:
	var data := _permitted()
	_ready(data,"woodcamp",["fabius","drusa"])
	Economy.advance(data,15.0)
	_check(Economy.execute(data,"village_shift",{"resident_id":"fabius","duty":"defense"}).ok,"Worker can join defense")
	_check(_place(data,"woodcamp").assigned==1 and Economy.view(data).population.defense==1,"Defender is removed from workplace, not copied")
	var before_wood: int=data.resources.wood
	Economy.advance(data,30.0)
	_check(data.resources.wood==before_wood,"Understaffed workplace stops during defense duty")
	_check(data.village.economy.workplaces.woodcamp.cycle_seconds==15.0,"Missing crew does not bank future production time")
	_check(not Economy.execute(data,"village_assign",{"resident_id":"fabius","workplace_id":"quarry"}).ok,"Defender cannot simultaneously receive a civilian assignment")
	_assign(data,"sextus","woodcamp")
	_check(Economy.execute(data,"village_shift",{"resident_id":"fabius","duty":"return"}).ok,"Returning defender is released")
	_check(_person(data,"fabius").assignment=="idle","Occupied former position sends returnee to reserve")
	Economy.advance(data,15.0)
	_check(data.resources.wood==before_wood+8,"Replacement crew completes remaining real work")
	data.village.raid.active=true
	before_wood=data.resources.wood
	var before_farm: float=data.village.economy.workplaces.farm.cycle_seconds
	Economy.advance(data,60.0)
	_check(data.resources.wood==before_wood and data.village.economy.workplaces.farm.cycle_seconds==before_farm,"Raid suspends all civilian production")
	_check(_place(data,"woodcamp").reason.contains("Überfall"),"Raid explains workplace suspension")
	_check(Economy.execute(data,"village_shift",{"resident_id":"fabius","duty":"defense"}).ok,"Reserve resident can answer live attack")
	_check(not Economy.execute(data,"village_shift",{"resident_id":"fabius","duty":"return"}).ok,"Defender cannot disappear into work during attack")
	data.village.raid.active=false
	_check(Economy.execute(data,"village_shift",{"resident_id":"fabius","duty":"return"}).ok,"Duty ends after attack")
	_check(Economy.view(data).population.alive==14,"Assignment transitions conserve actual people")


func _food_and_recovery() -> void:
	var data := _permitted()
	Economy.advance(data,120.0)
	_check(data.resources.grain==22,"Four harvest cycles add twenty-four grain; fourteen residents eat fourteen")
	_check(data.village.economy.meals_served==14 and data.village.economy.ledger.grain==10,"Meals and harvest share central grain ledger")
	_check(data.village.economy.day==1,"Only elapsed simulation time advances village day")
	data.village.raid.active=true
	data.resources.grain=0
	Economy.advance(data,240.0)
	_check(Economy.view(data).population.unfit==14,"Two missed rations make each resident unfit for work")
	_check(data.village.economy.grain_shortfall==14,"Shortage count tracks hungry residents")
	_check(not Economy.execute(data,"village_shift",{"resident_id":"fabius","duty":"defense"}).ok,"Unfit resident cannot be sent into defense")
	var money: int=data.resources.denarii
	_check(Economy.execute(data,"village_buy_food").ok,"Emergency food provides a finite recovery path")
	_check(data.resources.grain==16 and data.resources.denarii==money-6 and data.village.economy.stocks.emergency_grain==48,"Emergency food is bought, not created without cost")
	data.village.raid.active=false
	Economy.advance(data,120.0)
	_check(Economy.view(data).population.unfit==0,"A fed day restores work eligibility after two missed meals")
	_check(data.resources.grain==2,"Unfit farmers do not work before recovery ration")
	Economy.advance(data,120.0)
	_check(data.resources.grain==12,"Recovered farmers resume a sustainable food loop")
	for index in 3:
		_check(Economy.execute(data,"village_buy_food").ok,"Remaining emergency ration is available")
	var before:=JSON.stringify(data)
	_check(not Economy.execute(data,"village_buy_food").ok,"Emergency reserve eventually runs out")
	_check(JSON.stringify(data)==before,"Exhausted emergency store does not consume payment")
	data.village.economy.stocks.harvest=0
	var grain: int=data.resources.grain
	_check(Economy.execute(data,"village_resow").ok,"Exhausted field accepts paid sowing")
	_check(data.resources.grain==grain-4,"Seed is real grain")
	Economy.advance(data,60.0)
	_check(data.village.economy.stocks.harvest==0,"New sowing is not immediately harvestable")
	Economy.advance(data,60.0)
	_check(data.village.economy.stocks.harvest==120,"Two actual workers complete field regeneration")


func _partition_save_and_boundary_tests() -> void:
	var a:=_permitted()
	_ready(a,"woodcamp",["fabius","drusa"])
	_ready(a,"quarry",["aelia","quintus","sextus","antonia"])
	_ready(a,"trade",["cassia","silvanus"])
	_ready(a,"watchpost",["severus","valeria"])
	var b:Dictionary=a.duplicate(true)
	Economy.advance(a,360.0)
	for index in 360:
		Economy.advance(b,1.0)
	_check(JSON.stringify(a)==JSON.stringify(b),"One long tick and three hundred sixty short ticks have identical results")
	_check(a.village.economy.patrols_completed==6,"Two guards complete actual timed patrols")
	var saved:Variant=JSON.parse_string(JSON.stringify(a))
	_check(typeof(saved)==TYPE_DICTIONARY and Economy.validate(saved).is_empty(),"JSON save roundtrip remains valid")
	Economy.advance(a,42.5)
	Economy.advance(saved,42.5)
	_check(JSON.parse_string(JSON.stringify(a))==JSON.parse_string(JSON.stringify(saved)),"Reloaded partial cycles continue without duplicate production")
	var input_limited:=_permitted()
	_ready(input_limited,"woodcamp",["fabius","drusa"])
	_ready(input_limited,"trade",["cassia","silvanus"])
	input_limited.resources.wood=0
	var input_partitioned:Dictionary=input_limited.duplicate(true)
	Economy.advance(input_limited,90.0)
	for index in 90:
		Economy.advance(input_partitioned,1.0)
	_check(input_limited==input_partitioned,"Downstream trader cannot retroactively work before first cargo arrives")
	_check(input_limited.resources.denarii==36,"First timber arrival starts, rather than completes, trade labour")
	var before:=JSON.stringify(a)
	for delta in [0.0,-1.0,NAN,INF,3601.0]:
		_check(not Economy.advance(a,delta),"Invalid delta rejected")
	_check(JSON.stringify(a)==before,"Invalid time cannot skip days or mint resources")
	var snapshot:=JSON.stringify(a)
	var projection:=Economy.view(a)
	projection.people[0].health=0
	projection.authority.work_permit=false
	_check(JSON.stringify(a)==snapshot,"UI projections cannot mutate authoritative state")
	var limit:=_permitted()
	limit.village.economy.day=1000000000
	var limit_before:=JSON.stringify(limit)
	_check(not Economy.advance(limit,120.0),"Clock overflow cannot commit an invalid economy")
	_check(JSON.stringify(limit)==limit_before,"Rejected overflow preserves food and partial work atomically")


func _profession_effects() -> void:
	for profession in ["woodcutter","mason","trader"]:
		var data:=_permitted()
		data.village.social.profession=profession
		var id:String={"woodcutter":"woodcamp","mason":"quarry","trader":"trade"}[profession]
		var people:Array={"woodcamp":["fabius","drusa"],"quarry":["aelia","quintus","sextus","antonia"],"trade":["cassia","silvanus"]}[id]
		_ready(data,id,people)
		var resource:String=Economy.WORKPLACES[id].resource
		var stock:String=Economy.WORKPLACES[id].stock
		var before:int=data.resources[resource]
		var old_stock:int=data.village.economy.stocks[stock]
		var expected:int=Economy.WORKPLACES[id]["yield"]+1
		Economy.advance(data,float(Economy.WORKPLACES[id].period))
		_check(data.resources[resource]==before+expected,"Learned profession increases real cycle output: "+profession)
		_check(data.village.economy.stocks[stock]==old_stock-expected,"Profession bonus is withdrawn from actual source: "+profession)
		_check(data.village.economy.ledger[resource]==expected,"Profession bonus has central ledger entry: "+profession)
		_check(_place(data,id).yield_per_cycle==expected,"UI exposes current learned work yield: "+profession)
		data.village.economy.stocks[stock]=2
		before=data.resources[resource]
		Economy.advance(data,float(Economy.WORKPLACES[id].period))
		_check(data.resources[resource]==before+2 and data.village.economy.stocks[stock]==0,"Last partial cargo cannot exceed remaining source: "+profession)
	var healing:=_permitted()
	healing.village.social.profession="healer"
	_person(healing,"aurelia").health=60
	_person(healing,"vibius").health=60
	Economy.advance(healing,120.0)
	_check(_person(healing,"aurelia").health==67,"Healer knowledge improves actual reserve recovery by two")
	_check(_person(healing,"vibius").health==61,"Healer reserve treatment is not awarded during field work")
	_check(healing.resources.grain==22,"Improved recovery still requires actual meals")


func _invalid_state_tests() -> void:
	for corruption in ["duplicate","unknown","overbooked","negative","time","ruler","project"]:
		var data:=_permitted()
		match corruption:
			"duplicate": data.village.economy.people[1].id=data.village.economy.people[0].id
			"unknown": data.village.economy.people[0].assignment="infinite_money"
			"overbooked": data.village.economy.people[0].assignment="farm"
			"negative": data.resources.grain=-1
			"time": data.village.economy.day_seconds=NAN
			"ruler": data.village.economy.authority.player_is_ruler=true
			"project": data.village.economy.workplaces.farm.project={"kind":"sow","remaining":-2.0,"total":120.0}
		_check(not Economy.validate(data).is_empty(),"Invalid state rejected: "+corruption)
		var before:=var_to_bytes(data)
		_check(not Economy.execute(data,"village_buy_food").ok,"Command refuses corrupt state: "+corruption)
		_check(not Economy.advance(data,1.0),"Advance refuses corrupt state: "+corruption)
		_check(var_to_bytes(data)==before,"Corrupt state remains untouched: "+corruption)


func _assign(data:Dictionary,id:String,workplace:String)->void:
	_check(Economy.execute(data,"village_assign",{"resident_id":id,"workplace_id":workplace}).ok,"Assign "+id+" to "+workplace)


func _ready(data:Dictionary,id:String,people:Array)->void:
	data.village.economy.workplaces[id].condition=100
	for person_id in people:
		if _person(data,person_id).assignment!=id:
			_assign(data,person_id,id)


func _person(data:Dictionary,id:String)->Dictionary:
	for person in data.village.economy.people:
		if person.id==id:
			return person
	return {}


func _place(data:Dictionary,id:String)->Dictionary:
	for place in Economy.view(data).workplaces:
		if place.id==id:
			return place
	return {}


func _check(condition:bool,message:String)->void:
	checks+=1
	if not condition:
		failures.append(message)
