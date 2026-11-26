extends SceneTree

const Model = preload("res://scripts/domain/world_model.gd")
const Party = preload("res://scripts/domain/travel_party.gd")
const Life = preload("res://scripts/story/village_life.gd")
const F := Party.FATHER
const A := "vil:aurelia"
var checks := 0
var errors := 0
var model := Model.new()
var observed := {}
var path := OS.get_temp_dir().path_join("legio-party-%d.json" % Time.get_ticks_usec())

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		errors += 1
		printerr("FAIL: ",label)

func near(uid: String, point: Vector2) -> void:
	observed[Party.local_id(model.data,uid)] = {"position":[point.x,0.0,point.y]}
	model.set_player_position(Vector3(point.x,1.0,point.y))

func action(cmd: String, args: Dictionary, accepted := true, key := "") -> Dictionary:
	var snapshot := JSON.stringify(model.data) if not accepted else ""
	var result := model.execute(cmd,args,key)
	check(result.ok == accepted, "%s %s: %s" % [cmd,args,result.message])
	if not accepted:
		check(JSON.stringify(model.data) == snapshot,"Rejected action is atomic")
	return result

func _run() -> void:
	model.new_game("italia",true,true)
	model.npc_observations = func(): return observed
	var father := Life.actor_position(model.data,"silvanus")
	near(F,father)
	action("party_invite",{"actor_uid":"vil:marcus"},false)
	action("party_invite",{"actor_uid":Party.FRIEND},false)
	action("party_invite",{"actor_uid":F})
	action("party_invite",{"actor_uid":F},false)
	action("party_order",{"actor_uid":"all","order":"attack"},false)
	action("party_assign",{"actor_uid":F,"assignment":"carry"})
	var first := action("party_supply",{"actor_uid":F,"quantity":4},true,"one-transfer")
	var shared := int(model.data.resources.grain)
	check(first == model.execute("party_supply",{"actor_uid":F,"quantity":4},"one-transfer") and model.data.resources.grain == shared,"Retry does not transfer additional food")
	action("party_supply",{"actor_uid":F,"quantity":1},false,"one-transfer")
	action("party_supply",{"actor_uid":F,"quantity":99},false)
	action("party_equip",{"actor_uid":F,"item_id":"walking_staff"},false)
	model.set_player_position(Vector3(-8,1,2))
	action("gather",{"node_id":"timber_0"})
	near(F,father)
	action("party_equip",{"actor_uid":F,"item_id":"walking_staff"})
	var wood := int(model.data.resources.wood)
	action("party_equip",{"actor_uid":F,"item_id":"walking_staff"})
	action("party_equip",{"actor_uid":F,"item_id":"walking_staff"})
	check(model.data.resources.wood == wood and model.data.world_state.party.staff_made == 1,"One real piece of wood, one transferable staff")
	action("city_trade_enable",{})
	model.city_trade_sites = {"clothier":Vector3(-10,0,4)}
	model.set_player_position(Vector3(-10,1,4))
	action("city_buy",{"shop_id":"clothier","item_id":"linen_tunic","quantity":1})
	near(F,father)
	action("party_equip",{"actor_uid":F,"item_id":"linen_tunic"})
	check(model.data.village.city_trade.inventory.linen_tunic == 0,"No second sellable tunic remains")
	action("party_equip",{"actor_uid":F,"item_id":"wool_cloak"},false)
	near(F,Party.POST)
	action("party_train",{"actor_uid":F,"skill":"perception"})
	model.advance(2.0)
	check(model.data.world_state.party.members[F].practice == 2.0,"Training consumes actual attendance time")
	model.set_player_position(Vector3(23,1,18))
	model.advance(4)
	check(model.data.world_state.party.members[F].practice == 2.0,"No remote skill gain")
	check(model.save_game(path).ok,"Save partial lesson")
	var restored := Model.new()
	check(restored.load_game(path).ok,"Reload partial lesson")
	check(model.data.world_state.party == restored.data.world_state.party,"Save/load preserves equipment, contract, id and fractional work")
	model = restored
	model.npc_observations = func(): return observed
	near(F,Party.POST)
	model.advance(4.0)
	check(model.data.world_state.party.members[F].skills.get("perception") == 1 and model.party_view().members[0].trust > 4,"Completing the lesson grows skill and individual bond")
	action("party_dismiss",{"actor_uid":F})
	action("party_order",{"actor_uid":F,"order":"follow"},false)
	action("party_invite",{"actor_uid":F})
	check(model.data.world_state.party.members[F].equipment.body == "linen_tunic","Re-invitation retains the personal tunic")
	var healer := Life.actor_position(model.data,"aurelia")
	near(A,healer)
	action("village_talk",{"npc_id":"aurelia","choice":"meet"})
	action("party_hire",{"actor_uid":A},false)
	near(F,healer)
	var cash := int(model.data.resources.denarii)
	action("party_hire",{"actor_uid":A},true,"escort-terms")
	action("party_supply",{"actor_uid":A,"quantity":3})
	check(model.pass_calendar_days(1).ok and model.data.resources.denarii == cash-2,"First working day prepaid exactly once")
	check(model.pass_calendar_days(1).ok and model.data.resources.denarii == cash-4,"Second day's wage transferred from existing cash")
	check(model.data.world_state.party.members[A].paid == 4 and model.data.world_state.party.members[A].rations == 1,"Individual purse and carried provisions balance")
	var total := int(model.data.resources.grain)
	check(model.pass_calendar_days(5).ok and model.data.resources.grain == total,"Issued grain is not withdrawn again")
	check(model.data.world_state.party.members[A].order == "home","Two unfed days bring the specialist home")
	check(model.save_game(path).ok,"Joint finances persist after a long interval")
	for suffix in ["",".bak"]:
		DirAccess.remove_absolute(path + suffix)
	print("PARTY_TRANSACTIONS_RESULT checks=%d failures=%d" % [checks,errors])
	if errors == 0:
		print("PARTY_TRANSACTIONS_PASS")
	quit(1 if errors else 0)
