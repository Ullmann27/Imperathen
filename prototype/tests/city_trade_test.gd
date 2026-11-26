extends SceneTree
## Real WorldModel commands with deterministic geometry callbacks.
## Movement to shop/actor anchors is test positioning, not an automated playthrough.

const Model = preload("res://scripts/domain/world_model.gd")
const Trade = preload("res://scripts/city_trade.gd")
const Catalog = preload("res://scripts/city_trade_catalog.gd")
const Combat = preload("res://scripts/domain/combat_actions.gd")
const Life = preload("res://scripts/story/village_life.gd")
var checks := 0
var failures: Array[String] = []
var directory := "user://city_trade_%s" % Time.get_ticks_usec()


func _initialize() -> void:
	_test_opt_in_and_market()
	_test_consumption()
	_test_corrupt_and_saved_state()
	_test_service_and_rewards()
	_cleanup()
	for failure: String in failures:
		printerr("FAIL: "+failure)
	print("CITY_TRADE_RESULT checks=%d failures=%d" % [checks,failures.size()])
	print("CITY_TRADE_PASS" if failures.is_empty() else "CITY_TRADE_FAIL")
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)


func _ok(result: Dictionary, label: String) -> void:
	_check(result.get("ok",false),label+": "+str(result.get("message","")))


func _valid(model, label: String) -> void:
	var error: String=model._validate_state(model.data)
	_check(error.is_empty(),label+": "+error)


func _snapshot(model) -> String:
	return JSON.stringify(model.data)


func _near(model,shop_id: String) -> void:
	var at: Array=Catalog.SHOPS[shop_id].position
	model.set_player_position(Vector3(float(at[0]),1.0,float(at[1])))


func _buy(model,shop_id: String,id: String,quantity:=1,command_id:="") -> Dictionary:
	return model.execute("city_buy",{"shop_id":shop_id,"item_id":id,"quantity":quantity},command_id)


func _new():
	var model=Model.new()
	model.new_game("italia",true,true)
	var resources: Dictionary=model.data.resources.duplicate(true)
	var child: Dictionary=model.data.village.childhood.duplicate(true)
	_ok(model.execute("city_trade_enable",{},"open-market"),"Enable only the optional market")
	_check(model.data.resources==resources and model.data.village.childhood==child,"Enabling gives no resources, quest item, completion or age change")
	_valid(model,"Enabled child world validates")
	return model


func _test_opt_in_and_market() -> void:
	var legacy=Model.new()
	_check(not Trade.enabled(legacy.data),"Old regional world has no market data")
	var before:=_snapshot(legacy)
	_check(not legacy.execute("city_trade_enable").ok and _snapshot(legacy)==before,"Disabled village cannot silently acquire city mode")
	var model=_new()
	var source:=_snapshot(model)
	_ok(model.execute("city_trade_enable",{},"open-market"),"Enable command transport replay")
	_check(_snapshot(model)==source,"Repeated enable ID cannot recreate inventory")
	_check(Trade.shop_catalog().size()==6,"Six different real shop catalogs")
	for shop: Dictionary in Trade.shop_catalog():
		_check(not shop.items.is_empty(),"Shop has an actual assortment: "+str(shop.id))
	before=_snapshot(model)
	_check(not _buy(model,"bakery","bread").ok and _snapshot(model)==before,"Remote purchase is rejected atomically")
	_near(model,"bakery")
	before=_snapshot(model)
	for quantity: Variant in [-1,0,1.25,NAN,INF,100,"1",true]:
		_check(not model.execute("city_buy",{"shop_id":"bakery","item_id":"bread","quantity":quantity}).ok,"Malformed purchase quantity rejected: "+str(quantity))
	_check(not model.execute("city_buy",{"shop_id":"bakery","item_id":"bread","quantity":1,"price":0}).ok,"Caller cannot set the price")
	_check(_snapshot(model)==before,"Invalid arguments make no mutation")
	var cash:=int(model.data.village.economy.stocks.merchant_denarii)
	var money:=int(model.data.resources.denarii)
	var accepted:=_buy(model,"bakery","bread",2,"bread-two")
	_ok(accepted,"Buy real bread")
	_check(model.data.resources.denarii==money-4 and model.data.village.economy.stocks.merchant_denarii==cash+4,"Buyer payment exactly reaches existing merchant treasury")
	_check(model.data.village.city_trade.inventory.bread==2 and Trade.view(model.data,"bakery").offers[0].stock==38,"Finite stock loss equals inventory gain")
	before=_snapshot(model)
	_check(_buy(model,"bakery","bread",2,"bread-two")==accepted and _snapshot(model)==before,"Transport replay cannot charge or deliver twice")
	_check(not _buy(model,"bakery","bread",1,"bread-two").ok and _snapshot(model)==before,"Same command ID cannot change quantity")
	_ok(model.execute("city_sell",{"shop_id":"bakery","item_id":"bread","quantity":1}),"Sell one owned bread")
	_check(model.data.resources.denarii==money-3 and model.data.village.economy.stocks.merchant_denarii==cash+3,"Sale returns money from same finite merchant treasury")
	_check(model.data.village.city_trade.inventory.bread==1 and Trade.view(model.data,"bakery").offers[0].stock==39,"Resold item returns to merchant stock")
	before=_snapshot(model)
	_check(not model.execute("city_sell",{"shop_id":"bakery","item_id":"bread","quantity":2}).ok,"Cannot sell absent goods")
	_check(not _buy(model,"bakery","bread",40).ok,"Cannot buy more than finite remaining stock")
	_check(not _buy(model,"bakery","gladius").ok,"Wrong shop rejects wrong merchandise")
	_check(_snapshot(model)==before,"Rejected stock and inventory operations are atomic")
	_near(model,"armorer")
	_check(not model.execute("city_issue_service",{"shop_id":"armorer"}).ok,"Child cannot obtain soldier equipment")
	before=_snapshot(model)
	_check(not _buy(model,"armorer","gladius").ok and _snapshot(model)==before,"Child cannot bypass service restriction by purchasing adult weapons")
	_check(not Trade.view(model.data,"armorer").offers[0].can_buy,"Weapon offer visibly reflects the child restriction")
	_check(not model.execute("city_claim_reward",{"shop_id":"armorer","reward_id":"village_defense"}).ok,"No reward from unplayed mission")
	_check(model.data.player.age==12 and model.data.village.childhood.completed.is_empty(),"Browsing and purchasing do not advance childhood")
	_valid(model,"Trade respects original resource and story balances")


func _test_consumption() -> void:
	var model=_new()
	_near(model,"thermopolium")
	_ok(_buy(model,"thermopolium","water",2),"Buy two drinking-water portions")
	var before:=_snapshot(model)
	_check(not model.execute("city_consume",{"item_id":"water"}).ok and _snapshot(model)==before,"Full recovery does not waste a drink")
	_ok(model.execute("village_unarmed_attack",{"technique":"jab_left","target_id":"air","facing_x":0.0,"facing_z":-1.0}),"Real air gesture consumes stamina")
	before=_snapshot(model)
	_check(not model.execute("city_consume",{"item_id":"water"}).ok and _snapshot(model)==before,"Cannot consume during attack")
	model.advance(0.70)
	_check(model.data.village.unarmed.stamina<100.0,"Attack left a real stamina deficit")
	_ok(model.execute("city_consume",{"item_id":"water"}),"Water restores actual stamina")
	_check(is_equal_approx(model.data.village.unarmed.stamina,100.0),"Drink recovery is capped at actual stamina limit")
	_check(model.data.village.city_trade.inventory.water==1 and model.data.village.city_trade.used.water==1,"One drink is consumed exactly once")
	_near(model,"bakery")
	_ok(_buy(model,"bakery","bread"),"Buy food before a controlled injury")
	# This fixture represents already validated environmental damage. It is
	# deliberately not described as an observed battle or world-physics result.
	model.data.player.health=83
	model.data.village.health_delta=-17
	_valid(model,"Controlled injury preserves the existing health ledger")
	_ok(model.execute("city_consume",{"item_id":"bread"}),"Bread restores health")
	_check(model.data.player.health==88 and model.data.village.health_delta==-12,"Food updates the original health ledger by exactly its recovery")
	_valid(model,"Food and drink leave a fully valid saved world")


func _test_corrupt_and_saved_state() -> void:
	var model=_new()
	_near(model,"pottery")
	_ok(_buy(model,"pottery","oil_lamp",1,"lamp-once"),"Purchase saved commodity")
	var path:=_path("market")
	_ok(model.save_game(path),"Save actual market through WorldModel")
	var restored=Model.new()
	_ok(restored.load_game(path),"Load actual market through WorldModel")
	_check(restored.data.village.city_trade==model.data.village.city_trade,"Inventory, quantities, equipment and receipts survive save/load")
	var before:=_snapshot(restored)
	_ok(_buy(restored,"pottery","oil_lamp",1,"lamp-once"),"Replay purchase after load")
	_check(_snapshot(restored)==before,"Saved replay does not deliver another lamp")
	var original: Dictionary=restored.data.duplicate(true)
	for corruption: String in ["inventory","unpaid_receipt","stock","reward","slot","quantity","contract"]:
		restored.data=original.duplicate(true)
		match corruption:
			"inventory":restored.data.village.city_trade.inventory.oil_lamp+=1
			"unpaid_receipt":
				restored.data.village.city_trade.inventory.oil_lamp+=1
				restored.data.village.city_trade.purchases.pottery.oil_lamp+=1
			"stock":restored.data.village.city_trade.purchases.pottery.oil_lamp=99
			"reward":restored.data.village.city_trade.claimed_rewards=["valley_victory"]
			"slot":restored.data.village.city_trade.equipment.weapon="oil_lamp"
			"quantity":restored.data.village.city_trade.used.water=0.5
			"contract":restored.data.village.city_trade=42
		_check(not restored._validate_state(restored.data).is_empty(),"Corrupt trade contract rejected: "+corruption)
		before=_snapshot(restored)
		_check(not _buy(restored,"pottery","oil_lamp").ok and _snapshot(restored)==before,"Corrupt contract cannot execute: "+corruption)
	restored.data=original
	_valid(restored,"Original valid market can be restored unchanged")


func _clear(_from: Vector2,_to: Vector2) -> bool:
	return true


func _stationary(from: Vector2,_to: Vector2) -> Vector2:
	return from


func _attack(model,target: String,technique:="jab_left") -> Dictionary:
	return model.execute("village_unarmed_attack",{"technique":technique,"target_id":target,"facing_x":0.0,"facing_z":-1.0})


func _trained_villager():
	# This adult fixture is reached through existing commands and simulated time,
	# never by assigning age, profession, victory, equipment or a reward receipt.
	var model=Model.new()
	model.new_game("italia",true,false,true)
	model.combat_sight_check=_clear
	model.combat_motion_check=_stationary
	model.set_player_position(Vector3(-8,1,2))
	for i in 3:
		_ok(model.execute("gather",{"node_id":"timber_0"}),"Collect home material")
	model.set_player_position(Vector3(-3,1,4))
	_ok(model.execute("choose_companion",{"choice":"help"}),"Make real companion choice")
	_ok(model.execute("build",{"x":8.0,"z":5.0}),"Pay for home")
	model.set_player_position(Vector3(8,1,5))
	model.advance(12)
	for id: String in ["decimus","aelia","varro"]:
		var at: Vector2=Life.actor_position(model.data,id)
		model.set_player_position(Vector3(at.x,1,at.y))
		_ok(model.execute("village_talk",{"npc_id":id,"choice":"meet"}),"Meet "+id)
	model.set_player_position(Vector3(50,1,50))
	model.advance(Life.FIRST_WARNING-float(model.data.village.social.seconds))
	model.advance(Life.WARNING_SECONDS)
	_check(model.data.village.raid.active,"Actual timed raid started for reward proof")
	var attempts:=0
	while model.data.village.raid.active and attempts<32:
		var target: Dictionary={}
		for enemy: Dictionary in model.data.village.raid.enemies:
			if int(enemy.health)>0:
				target=enemy.duplicate()
				break
		if target.is_empty():
			break
		model.set_player_position(Vector3(float(target.x),1,float(target.z)+0.7))
		var result:=_attack(model,str(target.id))
		_ok(result,"Resolve real defense contact")
		if not result.ok:
			break
		model.advance(0.25)
		model.set_player_position(Vector3(50,1,50))
		model.advance(1)
		attempts+=1
	_check(model.data.village.raid.won==1,"All real enemies defeated before any reward is claimed")
	# Within the displayed adult jab of the training post (0.59 m + 0.16 m post).
	model.set_player_position(Vector3(0,1,-6.4))
	model.advance(maxf(0.0,240.0-float(model.data.village.social.seconds)))
	_ok(model.execute("train"),"Existing legacy adult transition follows lived defense")
	for i in 3:
		_ok(_attack(model,"practice"),"Actual adult training contact")
		model.advance(0.7)
	_check(model.data.player.age==18 and model.data.progress.training_complete,"Adult training genuinely completed")
	_valid(model,"Trained source world")
	return model


func _test_service_and_rewards() -> void:
	var model=_trained_villager()
	if not model.data.progress.training_complete:
		return
	_check(Combat.service_gear(model.data),"Unmodified legacy career retains service equipment")
	_ok(model.execute("city_trade_enable"),"Adult opts into explicit city equipment")
	_check(not Combat.service_gear(model.data),"City soldier visits the armorer before using weapons")
	_near(model,"armorer")
	var money:=int(model.data.resources.denarii)
	var cash:=int(model.data.village.economy.stocks.merchant_denarii)
	var issue: Dictionary=model.execute("city_issue_service",{"shop_id":"armorer"},"service-once")
	_ok(issue,"Issue free service equipment once")
	_check(model.data.resources.denarii==money and model.data.village.economy.stocks.merchant_denarii==cash,"Free kit changes no money or treasury")
	_check(Combat.service_gear(model.data),"Actual equipped Gladius and Scutum authorize sword actions")
	var before:=_snapshot(model)
	_check(model.execute("city_issue_service",{"shop_id":"armorer"},"service-once")==issue and _snapshot(model)==before,"Same issue ID replays exactly")
	_check(not model.execute("city_issue_service",{"shop_id":"armorer"}).ok and _snapshot(model)==before,"New issue ID cannot duplicate free equipment")
	for id: String in Catalog.SERVICE_KIT:
		_check(model.data.village.city_trade.inventory[id]==1,"Exactly one service item: "+id)
	_check(not model.execute("city_sell",{"shop_id":"armorer","item_id":"gladius","quantity":1}).ok,"Equipped weapon cannot be silently sold")
	_ok(model.execute("city_equip",{"item_id":"gladius"}),"Unequip actual sword")
	_check(not Combat.service_gear(model.data),"No sword permission after unequipping")
	_ok(model.execute("city_equip",{"item_id":"gladius"}),"Re-equip owned sword")
	_ok(model.execute("recruit"),"Recruit actual free village resident")
	_check(model.data.squad.morale==66,"Equipped command belt has a real one-point morale effect")
	var reward: Dictionary=model.execute("city_claim_reward",{"shop_id":"armorer","reward_id":"village_defense"},"defense-reward")
	_ok(reward,"Claim reward from the earlier real defended raid")
	_check(model.data.resources.denarii==money-5+8,"Mission reward uses original money after genuine recruitment cost")
	_check(model.data.village.economy.stocks.merchant_denarii==cash-8,"Reward comes from the same finite local treasury")
	_check(model.data.village.city_trade.inventory.fine_gladius==1,"One valuable real inventory item")
	_check(Trade.skills(model.data)=={"combat":10,"defense":8,"command":4},"Learned experience is derived from one confirmed reward")
	before=_snapshot(model)
	_check(model.execute("city_claim_reward",{"shop_id":"armorer","reward_id":"village_defense"},"defense-reward")==reward and _snapshot(model)==before,"Reward replay cannot duplicate money, item or experience")
	_check(not model.execute("city_claim_reward",{"shop_id":"armorer","reward_id":"village_defense"}).ok and _snapshot(model)==before,"New reward ID cannot duplicate completion")
	var learned: Dictionary=Trade.skills(model.data)
	_ok(model.execute("city_equip",{"item_id":"fine_gladius"}),"Equip earned higher-quality sword")
	_check(Trade.damage_bonus(model.data,true)==4,"Learned combat and weapon quality contribute separately")
	_check(Combat.guard_bonus_seconds(model.data)>0.0,"Learned defense and armor affect actual guard duration")
	_ok(model.execute("city_equip",{"item_id":"fine_gladius"}),"Unequip earned sword")
	_check(Trade.skills(model.data)==learned and Trade.equipment_bonuses(model.data).attack==0,"Removing item removes item bonus but preserves learned skills")
	_ok(model.execute("city_sell",{"shop_id":"armorer","item_id":"fine_gladius","quantity":1}),"Sell earned item through actual ledger")
	_check(Trade.skills(model.data)==learned and model.data.village.city_trade.inventory.fine_gladius==0,"Selling reward item cannot erase earned experience or retain the item")
	_ok(model.execute("city_equip",{"item_id":"gladius"}),"Return to issued sword")
	_valid(model,"Fully integrated commerce, combat and morale")
	var path:=_path("soldier")
	_ok(model.save_game(path),"Save equipment and reward receipt")
	var resumed=Model.new()
	_ok(resumed.load_game(path),"Load equipment and reward receipt")
	_check(Combat.service_gear(resumed.data) and Trade.skills(resumed.data)==learned,"Service and earned skills persist")
	before=_snapshot(resumed)
	_check(not resumed.execute("city_issue_service",{"shop_id":"armorer"}).ok and _snapshot(resumed)==before,"Reload cannot reopen the free-kit grant")
	_check(not resumed.execute("city_claim_reward",{"shop_id":"armorer","reward_id":"village_defense"}).ok,"Reload cannot reopen a paid reward")
	_valid(resumed,"Persisted city soldier")
	resumed.combat_sight_check=_clear
	resumed.combat_motion_check=_stationary
	_ok(resumed.execute("start_skirmish"),"Start an actual legacy encounter with the supplied soldier")
	var enemy: Dictionary=resumed.data.encounter.enemies[0]
	resumed.set_player_position(Vector3(float(enemy.x),1.0,float(enemy.z)+1.0))
	_ok(_attack(resumed,str(enemy.id),"thrust"),"Issued sword starts its actual combat window")
	resumed.advance(0.45)
	_check(resumed.data.encounter.enemies[0].health==40,"Real hit applies 18 base damage plus one learned and one equipped point")
	resumed.advance(0.4)
	_ok(resumed.execute("village_unarmed_guard"),"Learned defense starts a real guard")
	_check(is_equal_approx(resumed.data.village.unarmed.guard_remaining,0.927),"Actual guard lasts 0.85 base plus 0.032 learned and 0.045 equipment seconds")
	_valid(resumed,"Commerce-derived bonuses remain valid inside actual combat")


func _path(label: String) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	return directory.path_join(label+".json")


func _cleanup() -> void:
	var absolute:=ProjectSettings.globalize_path(directory)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	for filename: String in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute(absolute.path_join(filename))
	DirAccess.remove_absolute(absolute)

