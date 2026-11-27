extends SceneTree
const Activity := preload("res://scripts/visuals/resident_activity.gd")
const Person := preload("res://scripts/visuals/village_person.gd")
const Behavior := preload("res://scripts/domain/npc_behavior.gd")
const Model := preload("res://scripts/domain/world_model.gd")
const Stock := preload("res://scripts/visuals/workplace_stock.gd")
var failed := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _run() -> void:
	var resident := {"act":"water","arr":10,"until":40,"bag":{}}
	var old := resident.duplicate(true)
	check(Activity.city_prop(resident,5)=="water","Water errands carry actual vessel")
	check(resident==old,"Presentation never changes the resident ledger")
	resident = {"act":"haul","arr":10,"until":40,"bag":{"oil":2}}
	check(Activity.city_prop(resident,5)=="amphora","Transport with oil has a visible amphora")
	resident.bag = {}
	check(Activity.city_prop(resident,5)=="","No cargo before collection")
	resident = {"act":"shop","arr":10,"until":40,"with":3,"step":2,"talked":-1000,"bag":{}}
	check(Activity.partner_id(resident,12)==3 and Activity.partner_id(resident,40)==-1,"Haggling follows actual scheduled contact")
	resident = {"act":"gossip","arr":0,"until":1000,"with":5,"talked":10}
	check(Activity.partner_id(resident,50)==5 and Activity.partner_id(resident,250)==-1,"No indefinite conversation")
	check(Activity.speaker(3,5,0)!=Activity.speaker(3,5,5) and Activity.speaker(3,5,0)==Activity.speaker(5,3,0),"Consistent alternating speakers")
	check(Activity.standing_work({"act":"work","arr":10,"until":40},12),"Work intent uses actual workplace animation")
	check(not Activity.standing_work({"act":"work","arr":10,"until":40},5),"No work animation while commuting")
	check(Behavior.daily_window({"calendar":{"clock":{"second":12*3600+14*60+30}}},"flavia")=="meal","Staggered lunchtime overlaps at midday")
	check(Behavior.daily_window({"calendar":{"clock":{"second":20*3600}}},"flavia")=="evening","Evening follows world clock")
	check(Behavior.daily_window({},"flavia")=="","Legacy saves retain behavior")
	var model := Model.new()
	model.new_game("italia",true,true)
	var data := model.data
	data.calendar.clock.second = 12*3600+14*60+30
	data.village.behavior.people.flavia.next_decision = 0.0
	data.village.behavior.people.flavia.observed = false
	data.village.behavior.people.flavia.fatigue = 12.0
	data.village.behavior.people.flavia.social_need = 10.0
	var ledger: Dictionary = data.resources.duplicate(true)
	Behavior._decide_all(data,0.0)
	check(Behavior.view(data,"flavia").activity=="meal","Actual resident decision chooses midday break")
	check(Behavior.view(data,"lucius").activity!="meal","Guard retains duty")
	check(data.resources==ledger,"Daytime choice cannot create goods")
	check(Behavior.validate(data).is_empty(),"New decision remains compatible with the saved state contract")
	check(Stock.pile_count(0,240)==0 and Stock.pile_count(120,240)==2 and Stock.pile_count(240,240)==3,"Stock visibility follows depletion")
	var workplace := Node3D.new()
	root.add_child(workplace)
	var piles := Stock.build(workplace,"woodcamp")
	check(piles.size()==3,"Three real imported Meshy wood piles")
	Stock.sync(piles,"woodcamp",{"forest":0})
	check(piles.all(func(item: Node3D)->bool: return not item.visible),"Depleted stock disappears")
	Stock.sync(piles,"woodcamp",{"forest":240})
	check(piles.all(func(item: Node3D)->bool: return item.visible),"Replenished stock appears")
	workplace.free()
	var actor := Person.new()
	root.add_child(actor)
	actor.configure_resident("italia",35,"civilian_man",3,null,"test-resident")
	actor.set_resident_prop("basket")
	check(is_instance_valid(actor._resident_prop),"Real imported basket instantiated")
	actor.drive(0.0)
	actor._process(0.1)
	check(is_instance_valid(actor._resident_prop) and actor._resident_prop.visible,"Real prop follows resident in idle")
	var first := actor._resident_prop
	actor._reload(1)
	actor._process(0.1)
	check(actor._resident_prop==first and first.visible,"LOD replacement preserves actual activity prop")
	actor.set_resident_prop("")
	check(not is_instance_valid(actor._resident_prop),"Ending task removes visible prop")
	actor.free()
	print("RESIDENT_ACTIVITY_PASS" if failed==0 else "RESIDENT_ACTIVITY_FAIL")
	quit(0 if failed==0 else 1)
