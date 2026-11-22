extends SceneTree

const Campaign := preload("res://scripts/strategy/season_campaign.gd")
const Atlas := preload("res://scripts/strategy/atlas_data.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_test_ports_and_origins()
	_test_winter()
	_test_empire()
	_test_rejection()
	print("SEASON_CAMPAIGN_RESULT checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)


func _advance(data: Dictionary, count: int) -> void:
	for i in count:
		_check(Campaign.act(data,"advance").ok,"Advance season %d" % i)


func _test_ports_and_origins() -> void:
	for home in Campaign.HOMES:
		var world := Campaign.new_game(home)
		_check(Campaign.validate(world) and world.owned == [home] and world.mission.target == home, "Independent people " + home)
		var info := Campaign.summary(world)
		_check(info.year == 100 and info.season == "Frühling", "Historical starting date " + home)
	_check(Campaign.new_game("unknown").is_empty(),"Unrecognized origin")
	var data := Campaign.new_game()
	var southern := false
	for id in Atlas.REGIONS:
		if Atlas.REGIONS[id].lat < 0:
			var info := Campaign.region_info(data,id)
			southern = info.season == "Herbst" and Campaign.region_info(data,"italia").season == "Frühling"
			break
	_check(southern, "Hemispheres use opposite seasons")


func _test_winter() -> void:
	var neglect := Campaign.new_game()
	_advance(neglect,3)
	_check(Campaign.summary(neglect).warning.contains("fehlen"), "Actionable warning before first winter ends")
	_advance(neglect,1)
	_check(neglect.mission.misses == 1 and neglect.mission.status == "active" and neglect.grain == 9, "First missed winter brings aid and a second chance")
	_advance(neglect,3)
	_check(Campaign.summary(neglect).warning.contains("zweiter"), "Warning before permanent mission loss")
	_advance(neglect,1)
	_check(neglect.failures == 1 and neglect.history.size() == 1 and neglect.mission.status == "failed", "Repeated neglect fails the regional mission")
	_check(Campaign.summary(neglect).year == 102 and Campaign.summary(neglect).season == "Frühling", "Eight seasons advance two calendar years")
	var missed: Dictionary = neglect.history[0].duplicate(true)
	_check(Campaign.act(neglect,"mission","italia").ok and neglect.mission.id == 2,"Start a separate recovery mission")
	_check(Campaign.act(neglect,"store").ok,"Store provisions after aid")
	_advance(neglect,4)
	_check(neglect.mission.status == "won" and neglect.wins == 1 and neglect.failures == 1 and neglect.history[0] == missed,"Later recovery preserves failed order")
	var complete := Campaign.new_game()
	_check(Campaign.act(complete,"store").ok and complete.stores == 6 and complete.grain == 0,"Fresh stock becomes winter inventory")
	_advance(complete,4)
	_check(complete.mission.status == "won" and complete.stores == 2 and complete.unrest == 0,"Prepared first winter consumes exact demand")
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(neglect))
	_check(Campaign.validate(decoded) and Campaign.act(decoded,"advance").ok,"Resume seasonal simulation after JSON round trip")


func _frontier(data: Dictionary) -> Dictionary:
	var choice := {}
	for id in Atlas.REGIONS:
		var info := Campaign.region_info(data,id)
		if info.reachable and (choice.is_empty() or info.cost < choice.cost):
			choice = {"id":id,"cost":info.cost}
	return choice


func _test_empire() -> void:
	var data := Campaign.new_game()
	var crossing_seen := false
	var last_frontier := {}
	for i in 2400:
		if data.owned.size() == Atlas.REGIONS.size():
			break
		if data.actions == 0:
			if not Campaign.act(data,"advance").ok:
				break
			continue
		var frontier := _frontier(data)
		if frontier.is_empty():
			break
		var needed := int(Campaign.summary(data).winter_need)
		var command := "harvest"
		if data.stores < needed and data.grain > 0:
			command = "store"
		elif data.stores >= needed and data.supply >= frontier.cost:
			command = "campaign"
			last_frontier = frontier
			crossing_seen = crossing_seen or frontier.cost >= 5
		elif data.stores >= needed and data.grain > 0:
			command = "supply"
		var result := Campaign.act(data,command,frontier.id)
		if not result.ok:
			printerr("Empire turn rejected ",command," ",result.message)
			break
	var peak: int = data.owned.size()
	_check(peak == Atlas.REGIONS.size() and Campaign.validate(data), "Every modeled territory is conquerable through legal turns from Italia")
	_check(crossing_seen, "Conquest includes a longer sea connection")
	_check(data.mandate == 0 and not last_frontier.is_empty(), "Expansion alone does not promote")
	if data.actions == 0:
		_advance(data,1)
	_check(Campaign.act(data,"mandate").ok and data.mandate == 1, "Accept provincial mandate explicitly")
	if data.actions == 0:
		_advance(data,1)
	_check(Campaign.act(data,"mandate").ok and data.mandate == 2, "Accept realm mandate explicitly")
	if data.actions == 0:
		_advance(data,1)
	_check(Campaign.act(data,"mission","southafrica").ok, "Accept a southern winter mission")
	var calendar := Campaign.summary(data)
	while calendar.mission_season != "Winter":
		_advance(data,1)
		calendar = Campaign.summary(data)
	_check(calendar.season == "Sommer","Southern mission winter falls in northern summer")
	var mission_id: int = data.mission.id
	_advance(data,1)
	_check(data.mission.id == mission_id and (data.mission.misses > 0 or data.mission.status == "won"), "Local winter resolves on the southern calendar")
	var size_before: int = data.owned.size()
	_advance(data,20)
	_check(data.unrest >= 45 and data.owned.size() < size_before and data.home in data.owned, "Prolonged shortage in a large realm costs border control")
	_check(Campaign.validate(data),"Border losses preserve connectivity to home")
	print("Atlas test peak=%d remaining_after_shortages=%d year=%d last_conquest=%s" % [peak,data.owned.size(),Campaign.summary(data).year,str(last_frontier.get("id"))])


func _test_rejection() -> void:
	var data := Campaign.new_game()
	var frontier := _frontier(data)
	var saved := data.duplicate(true)
	for order in [["campaign","italia"],["campaign","?"],["campaign",frontier.id],["mandate",""],["mission","italia"],["unknown",""]]:
		_check(not Campaign.act(data,order[0],order[1]).ok and data == saved,"Rejected action remains atomic: " + order[0])
	for pair in [["owned",["italia","italia"]],["owned",[{}]],["mission",{}],["mission",null],
			["history",{}],["history",[11]],["actions",3],["turn",0.4],["grain",-1],["unrest",101],["home",["italia"]]]:
		var bad := saved.duplicate(true)
		bad[pair[0]] = pair[1]
		_check(not Campaign.validate(bad),"Invalid field " + pair[0])
	for id in Atlas.REGIONS:
		if id != "italia" and not Campaign.region_info(data,id).reachable:
			var isolated := data.duplicate(true)
			isolated.owned.append(id)
			_check(not Campaign.validate(isolated),"Reject detached holdings")
			break
	Campaign.act(data,"harvest")
	Campaign.act(data,"supply")
	saved = data.duplicate(true)
	_check(not Campaign.act(data,"harvest").ok and data == saved,"Seasonal preparation budget enforced")
