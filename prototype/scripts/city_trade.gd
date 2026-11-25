extends RefCounted
## Optional city commerce. WorldModel alone commits transactions and saves.
## Quest parcels in childhood.carried are never copied, sold or consumed here.

const Catalog = preload("res://scripts/city_trade_catalog.gd")
const VERSION := 1
const RANGE := 3.0
const MAX_COUNT := 1000000
const MAX_TRANSACTION := 99
const EQUIPMENT_SLOTS := ["weapon","shield","body","belt"]
const COMMAND_FIELDS := {
	"city_trade_enable":[],
	"city_buy":["shop_id","item_id","quantity"],
	"city_sell":["shop_id","item_id","quantity"],
	"city_consume":["item_id"],
	"city_equip":["item_id"],
	"city_issue_service":["shop_id"],
	"city_claim_reward":["shop_id","reward_id"]
}


static func enabled(data: Dictionary) -> bool:
	return typeof(data.get("village")) == TYPE_DICTIONARY and data.village.has("city_trade")


static func _initial() -> Dictionary:
	var inventory := {}
	var purchases := {}
	var sales := {}
	var used := {}
	for id: String in Catalog.ITEMS:
		inventory[id] = 0
		used[id] = 0
	for shop_id: String in Catalog.SHOPS:
		purchases[shop_id] = {}
		sales[shop_id] = {}
		for id: String in Catalog.SHOPS[shop_id].items:
			purchases[shop_id][id] = 0
			sales[shop_id][id] = 0
	return {"version":VERSION,"inventory":inventory,"purchases":purchases,"sales":sales,
		"used":used,"service_issued":false,"claimed_rewards":[],
		"equipment":{"weapon":"","shield":"","body":"","belt":""}}


static func shop_catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in Catalog.SHOPS:
		var shop: Dictionary = Catalog.SHOPS[id].duplicate(true)
		shop["id"] = id
		result.append(shop)
	return result


static func item_catalog() -> Dictionary:
	return Catalog.ITEMS.duplicate(true)


static func validate_arguments(command: String, args: Dictionary) -> String:
	if not COMMAND_FIELDS.has(command) or not _keys(args, COMMAND_FIELDS[command]):
		return "Der Handelsauftrag enthält fehlende oder unerlaubte Angaben."
	for key: String in args:
		if key == "quantity":
			if not _integer(args[key],1,MAX_TRANSACTION):
				return "Die Menge muss eine ganze Zahl zwischen 1 und 99 sein."
		elif typeof(args[key]) != TYPE_STRING or str(args[key]).is_empty() or str(args[key]).length() > 64:
			return "Eine gültige Waren-, Laden- oder Auftragskennung fehlt."
	if args.has("shop_id") and not Catalog.SHOPS.has(args.shop_id):
		return "Diese Verkaufsstelle gibt es nicht."
	if args.has("item_id") and not Catalog.ITEMS.has(args.item_id):
		return "Diese Ware gehört nicht zum Handelsbestand."
	if args.has("reward_id") and not Catalog.REWARDS.has(args.reward_id):
		return "Diese Auszeichnung gehört nicht zu einem bestätigten Auftrag."
	return ""


## Called only on WorldModel's private candidate, after complete state validation.
static func apply(data: Dictionary, command: String, args: Dictionary, sites: Dictionary = {}) -> Dictionary:
	var error := validate_arguments(command,args)
	if not error.is_empty():
		return _result(false,error)
	if command == "city_trade_enable":
		if not bool(data.get("village",{}).get("enabled",false)):
			return _result(false,"Der Stadtmarkt gehört zur römischen Dorfwelt.")
		if enabled(data):
			return _result(true,"Der Stadtmarkt ist bereits geöffnet.")
		data.village.city_trade = _initial()
		return _result(true,"Du kannst die Stadt erkunden und bei den Ständen einkaufen.")
	if not enabled(data):
		return _result(false,"Dieser Spielstand verwendet den Stadtmarkt noch nicht.")
	error = _ready_reason(data)
	if not error.is_empty():
		return _result(false,error)
	if args.has("shop_id"):
		error = _shop_reason(data,str(args.shop_id),sites)
		if not error.is_empty():
			return _result(false,error)
	var trade: Dictionary = data.village.city_trade
	match command:
		"city_buy","city_sell":
			var shop_id: String = args.shop_id
			var item_id: String = args.item_id
			if not Catalog.SHOPS[shop_id].items.has(item_id):
				return _result(false,"Diese Verkaufsstelle handelt nicht mit dieser Ware.")
			var item: Dictionary = Catalog.ITEMS[item_id]
			var quantity := int(args.quantity)
			var buying := command == "city_buy"
			if buying and str(item.slot) in ["weapon","shield"] and not _trained_soldier(data):
				return _result(false,"Waffen und Schild gehören zu deiner abgeschlossenen erwachsenen Ausbildung.")
			if buying and _stock(data,shop_id,item_id) < quantity:
				return _result(false,"Diese Menge ist hier nicht vorrätig.")
			if not buying and int(trade.inventory[item_id]) < quantity:
				return _result(false,"Diese Menge trägst du nicht bei dir.")
			if not buying and trade.equipment.values().has(item_id):
				return _result(false,"Lege diesen Gegenstand vor dem Verkauf ab.")
			if not buying and int(item.sell_price) == 0:
				return _result(false,"Diese geöffnete Verbrauchsware wird nicht zurückgekauft.")
			var total := quantity * int(item.price if buying else item.sell_price)
			var delta := -total if buying else total
			error = _money_reason(data,delta)
			if not error.is_empty():
				return _result(false,error)
			if buying and int(trade.inventory[item_id]) > MAX_COUNT-quantity:
				return _result(false,"Dein Warenbestand ist voll.")
			var counters: Dictionary = trade.purchases if buying else trade.sales
			if int(counters[shop_id][item_id]) > MAX_COUNT-quantity:
				return _result(false,"Das Warenbuch ist für diese Ware voll.")
			_transfer_money(data,delta)
			trade.inventory[item_id] = int(trade.inventory[item_id]) + (quantity if buying else -quantity)
			counters[shop_id][item_id] = int(counters[shop_id][item_id]) + quantity
			return _result(true,"%d × %s %s: %d Denare." % [quantity,item.name,"gekauft" if buying else "verkauft",total])
		"city_consume":
			var id: String = args.item_id
			var item: Dictionary = Catalog.ITEMS[id]
			if int(trade.inventory[id]) <= 0:
				return _result(false,"Diese Speise oder dieses Getränk trägst du nicht bei dir.")
			if int(item.health) <= 0 and float(item.stamina) <= 0.0:
				return _result(false,"Dieser Gegenstand ist keine Speise und kein Getränk.")
			var health_gain := mini(int(item.health),100-int(data.player.health))
			var stamina_gain := 0.0
			if typeof(data.village.get("unarmed")) == TYPE_DICTIONARY:
				stamina_gain = minf(float(item.stamina),100.0-float(data.village.unarmed.stamina))
			if health_gain == 0 and stamina_gain <= 0.000001:
				return _result(false,"Du bist bereits erholt. Die Ware bleibt in deinem Gepäck.")
			if int(trade.used[id]) >= MAX_COUNT:
				return _result(false,"Das Verbrauchsbuch ist voll.")
			trade.inventory[id] = int(trade.inventory[id])-1
			trade.used[id] = int(trade.used[id])+1
			data.player.health = int(data.player.health)+health_gain
			data.village.health_delta = int(data.village.health_delta)+health_gain
			if stamina_gain > 0.0:
				data.village.unarmed.stamina = float(data.village.unarmed.stamina)+stamina_gain
			return _result(true,"%s: %d Gesundheit und %.0f Ausdauer erholt." % [item.name,health_gain,stamina_gain])
		"city_equip":
			var id: String = args.item_id
			var item: Dictionary = Catalog.ITEMS[id]
			var slot: String = item.slot
			if slot.is_empty():
				return _result(false,"Dieser Gegenstand ist keine anlegbare Ausrüstung.")
			if int(data.player.age) < 18:
				return _result(false,"Kampfausrüstung gehört zu deinem späteren Erwachsenenweg.")
			if int(trade.inventory[id]) <= 0:
				return _result(false,"Du besitzt diesen Gegenstand nicht.")
			if slot in ["weapon","shield"] and not _trained_soldier(data):
				return _result(false,"Waffen und Schild setzen deine abgeschlossene erwachsene Ausbildung voraus.")
			var removing: bool = trade.equipment[slot] == id
			trade.equipment[slot] = "" if removing else id
			return _result(true,"%s %s." % [item.name,"abgelegt" if removing else "angelegt"])
		"city_issue_service":
			if args.shop_id != "armorer":
				return _result(false,"Deine Dienstausrüstung erhältst du an der Ausrüstungsschmiede.")
			if not _trained_soldier(data):
				return _result(false,"Die kostenlose Grundausrüstung ist für bestätigte erwachsene Rekruten vorgesehen.")
			if trade.service_issued:
				return _result(false,"Deine kostenlose Grundausrüstung wurde bereits ausgegeben.")
			for id: String in Catalog.SERVICE_KIT:
				if int(trade.inventory[id]) > MAX_COUNT-int(Catalog.SERVICE_KIT[id]):
					return _result(false,"Für die Ausgabe ist dein Warenbestand voll.")
			trade.service_issued = true
			for id: String in Catalog.SERVICE_KIT:
				trade.inventory[id] = int(trade.inventory[id])+int(Catalog.SERVICE_KIT[id])
				trade.equipment[Catalog.ITEMS[id].slot] = id
			return _result(true,"Gladius, Scutum, Tunika und Gürtel erhalten. Diese erste Dienstausrüstung kostet dich nichts.")
		"city_claim_reward":
			if args.shop_id != "armorer":
				return _result(false,"Die bestätigten Auszeichnungen gibt die Ausrüstungsschmiede aus.")
			var id: String = args.reward_id
			if trade.claimed_rewards.has(id):
				return _result(false,"Diese Auszeichnung und ihr Lohn wurden bereits übergeben.")
			if not _reward_available(data,id):
				return _result(false,"Der zugehörige Auftrag ist noch nicht durch deinen Spielverlauf bestätigt.")
			var reward: Dictionary = Catalog.REWARDS[id]
			error = _money_reason(data,int(reward.money))
			if not error.is_empty():
				return _result(false,error)
			for item_id: String in reward.items:
				if int(trade.inventory[item_id]) > MAX_COUNT-int(reward.items[item_id]):
					return _result(false,"Für die Auszeichnung ist dein Warenbestand voll.")
			trade.claimed_rewards.append(id)
			_transfer_money(data,int(reward.money))
			for item_id: String in reward.items:
				trade.inventory[item_id] = int(trade.inventory[item_id])+int(reward.items[item_id])
			return _result(true,"%s: %d Denare und ein Gegenstand übergeben. Deine erworbene Erfahrung bleibt auch ohne diesen Gegenstand erhalten." % [reward.name,reward.money])
	return _result(false,"Unbekannter Handelsauftrag.")


static func view(data: Dictionary, shop_id := "", sites: Dictionary = {}) -> Dictionary:
	var result := {"enabled":enabled(data),"money":int(data.get("resources",{}).get("denarii",0)),
		"shops":shop_catalog(),"offers":[],"inventory":[],"skills":skills(data),
		"equipment_bonuses":equipment_bonuses(data),"service":{},"rewards":[]}
	if not enabled(data):
		return result
	var error := validate(data)
	if not error.is_empty():
		result["error"] = error
		return result
	var trade: Dictionary = data.village.city_trade
	for id: String in Catalog.ITEMS:
		var count := int(trade.inventory[id])
		if count <= 0:
			continue
		var item: Dictionary = Catalog.ITEMS[id]
		var can_consume := _ready_reason(data).is_empty() and (int(item.health)>0 or float(item.stamina)>0.0)
		var can_equip := _ready_reason(data).is_empty() and not str(item.slot).is_empty() and int(data.player.age)>=18
		if str(item.slot) in ["weapon","shield"]:
			can_equip = can_equip and _trained_soldier(data)
		result.inventory.append({"item_id":id,"name":item.name,"quantity":count,
			"can_consume":can_consume,"can_equip":can_equip,"equipped":trade.equipment.values().has(id)})
	if Catalog.SHOPS.has(shop_id):
		var reason := _shop_reason(data,shop_id,sites)
		if reason.is_empty():
			reason = _ready_reason(data)
		for id: String in Catalog.SHOPS[shop_id].items:
			var item: Dictionary = Catalog.ITEMS[id]
			var stock := _stock(data,shop_id,id)
			var affordable := _money_reason(data,-int(item.price)).is_empty()
			var authorized := str(item.slot) not in ["weapon","shield"] or _trained_soldier(data)
			var can_sell: bool = int(trade.inventory[id])>0 and int(item.sell_price)>0 and not trade.equipment.values().has(id)
			can_sell = can_sell and _money_reason(data,int(item.sell_price)).is_empty()
			result.offers.append({"item_id":id,"name":item.name,"price":item.price,"sell_price":item.sell_price,
				"stock":stock,"owned":int(trade.inventory[id]),"can_buy":reason.is_empty() and stock>0 and affordable and authorized,
				"can_sell":reason.is_empty() and can_sell,"reason":reason if authorized else "Waffen und Schild: erst nach erwachsener Ausbildung."})
	var service_reason := ""
	if trade.service_issued:
		service_reason = "Bereits einmal ausgegeben."
	elif not _trained_soldier(data):
		service_reason = "Abgeschlossene erwachsene Ausbildung erforderlich."
	elif not _shop_reason(data,"armorer",sites).is_empty():
		service_reason = _shop_reason(data,"armorer",sites)
	elif not _ready_reason(data).is_empty():
		service_reason = _ready_reason(data)
	result.service = {"issued":trade.service_issued,"eligible":service_reason.is_empty(),"reason":service_reason}
	for id: String in Catalog.REWARDS:
		var reward: Dictionary = Catalog.REWARDS[id]
		var claimed: bool = trade.claimed_rewards.has(id)
		var reason := ""
		if claimed:
			reason = "Bereits erhalten."
		elif not _reward_available(data,id):
			reason = "Der zugehörige Auftrag ist noch nicht bestätigt."
		elif not _shop_reason(data,"armorer",sites).is_empty():
			reason = _shop_reason(data,"armorer",sites)
		elif not _ready_reason(data).is_empty():
			reason = _ready_reason(data)
		else:
			reason = _money_reason(data,int(reward.money))
		result.rewards.append({"id":id,"name":reward.name,"money":reward.money,"claimed":claimed,
			"eligible":reason.is_empty(),"reason":reason,"items":reward.items.duplicate(true),"xp":reward.xp.duplicate(true)})
	return result


static func skills(data: Dictionary) -> Dictionary:
	var result := {"combat":0,"defense":0,"command":0}
	if not enabled(data):
		return result
	var record: Variant = data.village.city_trade
	if typeof(record) != TYPE_DICTIONARY or typeof(record.get("claimed_rewards")) != TYPE_ARRAY:
		return result
	for id: Variant in record.claimed_rewards:
		if typeof(id) == TYPE_STRING and Catalog.REWARDS.has(id):
			for key: String in result:
				result[key] += int(Catalog.REWARDS[id].xp[key])
	return result


static func equipment_bonuses(data: Dictionary) -> Dictionary:
	var result := {"attack":0,"defense":0,"command":0}
	if not enabled(data) or int(data.get("player",{}).get("age",0))<18:
		return result
	var record: Variant = data.village.city_trade
	if typeof(record)!=TYPE_DICTIONARY or typeof(record.get("equipment"))!=TYPE_DICTIONARY:
		return result
	for id: Variant in record.equipment.values():
		if typeof(id)==TYPE_STRING and Catalog.ITEMS.has(id):
			for key: String in result:
				result[key] += int(Catalog.ITEMS[id][key])
	return result


static func service_gear(data: Dictionary) -> bool:
	if not enabled(data):
		return _trained_soldier(data)
	var trade: Variant = data.village.city_trade
	if typeof(trade)!=TYPE_DICTIONARY or typeof(trade.get("equipment"))!=TYPE_DICTIONARY or typeof(trade.get("inventory"))!=TYPE_DICTIONARY:
		return false
	var weapon := str(trade.equipment.get("weapon",""))
	var shield := str(trade.equipment.get("shield",""))
	return _trained_soldier(data) and weapon in ["gladius","fine_gladius"] and shield=="scutum" and int(trade.inventory.get(weapon,0))>0 and int(trade.inventory.get(shield,0))>0


static func damage_bonus(data: Dictionary, armed: bool) -> int:
	if not enabled(data) or int(data.get("player",{}).get("age",0))<18:
		return 0
	var learned := mini(3,int(skills(data).combat)/10)
	return learned + (int(equipment_bonuses(data).attack) if armed else 0)


static func guard_bonus_seconds(data: Dictionary) -> float:
	if not enabled(data) or int(data.get("player",{}).get("age",0))<18:
		return 0.0
	return minf(0.20,float(skills(data).defense)*0.004+float(equipment_bonuses(data).defense)*0.015)


static func command_bonus(data: Dictionary) -> int:
	if not enabled(data) or int(data.get("squad",{}).get("recruits",0))<=0 or int(data.get("player",{}).get("age",0))<18:
		return 0
	return mini(5,int(skills(data).command)/5+int(equipment_bonuses(data).command))


static func validate(data: Dictionary) -> String:
	if not enabled(data):
		return ""
	if not bool(data.village.get("enabled",false)):
		return "Der Handelsbestand gehört zu einer deaktivierten Dorfwelt."
	var record: Variant = data.village.city_trade
	if not _keys(record,["version","inventory","purchases","sales","used","service_issued","claimed_rewards","equipment"]):
		return "Der Handelsbestand ist unvollständig oder unbekannt."
	var trade: Dictionary = record
	if not _integer(trade.version,VERSION,VERSION) or typeof(trade.service_issued)!=TYPE_BOOL:
		return "Die Handelsversion oder Ausrüstungsausgabe ist ungültig."
	if not _keys(trade.inventory,Catalog.ITEMS.keys()) or not _keys(trade.used,Catalog.ITEMS.keys()):
		return "Das Wareninventar oder Verbrauchsbuch enthält fremde Gegenstände."
	if not _keys(trade.purchases,Catalog.SHOPS.keys()) or not _keys(trade.sales,Catalog.SHOPS.keys()):
		return "Das Handelsbuch enthält unbekannte Verkaufsstellen."
	if typeof(trade.claimed_rewards)!=TYPE_ARRAY or trade.claimed_rewards.size()>Catalog.REWARDS.size():
		return "Das Auszeichnungsbuch ist ungültig."
	var claimed := {}
	for id: Variant in trade.claimed_rewards:
		if typeof(id)!=TYPE_STRING or not Catalog.REWARDS.has(id) or claimed.has(id):
			return "Eine Auszeichnung ist fremd oder doppelt."
		if not _reward_proven(data,id):
			return "Eine Auszeichnung ist durch keinen gespeicherten Auftrag belegt."
		claimed[id]=true
	if trade.service_issued and not _trained_soldier(data):
		return "Dienstausrüstung ohne bestätigte erwachsene Ausbildung."
	for shop_id: String in Catalog.SHOPS:
		var items: Array = Catalog.SHOPS[shop_id].items
		if not _keys(trade.purchases[shop_id],items) or not _keys(trade.sales[shop_id],items):
			return "Ein Wareneintrag gehört nicht zum Ladensortiment."
		for id: String in items:
			if not _integer(trade.purchases[shop_id][id],0,MAX_COUNT) or not _integer(trade.sales[shop_id][id],0,MAX_COUNT):
				return "Käufe und Verkäufe müssen begrenzte ganze Mengen sein."
			if _stock(data,shop_id,id)<0 or _stock(data,shop_id,id)>MAX_COUNT:
				return "Die Verkaufsstelle hat mehr Ware ausgegeben, als sie besitzt."
	for id: String in Catalog.ITEMS:
		if not _integer(trade.inventory[id],0,MAX_COUNT) or not _integer(trade.used[id],0,MAX_COUNT):
			return "Warenbestand und Verbrauch müssen begrenzte ganze Mengen sein."
		var item: Dictionary=Catalog.ITEMS[id]
		if int(trade.used[id])>0 and int(item.health)==0 and float(item.stamina)==0.0:
			return "Ein nicht essbarer Gegenstand wurde verbraucht."
		var expected := -int(trade.used[id])
		for shop_id: String in Catalog.SHOPS:
			expected += int(trade.purchases[shop_id].get(id,0))-int(trade.sales[shop_id].get(id,0))
		if trade.service_issued:
			expected += int(Catalog.SERVICE_KIT.get(id,0))
		for reward_id: String in claimed:
			expected += int(Catalog.REWARDS[reward_id].items.get(id,0))
		if int(trade.inventory[id])!=expected:
			return "Der Bestand von %s ist nicht durch Erwerb und Verbrauch belegt." % item.name
	if not _keys(trade.equipment,EQUIPMENT_SLOTS):
		return "Die Ausrüstungsplätze sind unvollständig."
	for slot: String in EQUIPMENT_SLOTS:
		var id: Variant=trade.equipment[slot]
		if typeof(id)!=TYPE_STRING:
			return "Ein Ausrüstungsplatz enthält keine Gegenstandskennung."
		if id=="":
			continue
		if not Catalog.ITEMS.has(id) or Catalog.ITEMS[id].slot!=slot or int(trade.inventory[id])<=0:
			return "Ein angelegter Gegenstand fehlt oder liegt auf dem falschen Platz."
		if int(data.get("player",{}).get("age",0))<18:
			return "Ein Kind kann keine erwachsene Kampfausrüstung tragen."
		if slot in ["weapon","shield"] and not _trained_soldier(data):
			return "Bewaffnung ohne abgeschlossene erwachsene Ausbildung."
	return ""


static func restore_integer_fields(data: Dictionary) -> void:
	if not enabled(data):
		return
	var trade: Dictionary = data.village.city_trade
	trade.version=int(trade.version)
	for section: String in ["inventory","used"]:
		for key: String in trade[section]:
			trade[section][key]=int(trade[section][key])
	for section: String in ["purchases","sales"]:
		for shop: Dictionary in trade[section].values():
			for key: String in shop:
				shop[key]=int(shop[key])


static func money_effect(data: Dictionary) -> int:
	# A derived contribution to WorldModel's existing resource ledger. Keeping
	# receipts and the money proof separate detects unpaid inventory changes;
	# the only spendable player balance remains resources.denarii.
	if not enabled(data):
		return 0
	var trade: Dictionary=data.village.city_trade
	var total:=0
	for shop_id: String in Catalog.SHOPS:
		for id: String in Catalog.SHOPS[shop_id].items:
			total -= int(trade.purchases[shop_id][id])*int(Catalog.ITEMS[id].price)
			total += int(trade.sales[shop_id][id])*int(Catalog.ITEMS[id].sell_price)
	for id: String in trade.claimed_rewards:
		total += int(Catalog.REWARDS[id].money)
	return total


static func _reward_proven(data: Dictionary, id: String) -> bool:
	var village: Dictionary = data.get("village",{})
	var adult := int(data.get("player",{}).get("age",0))>=18
	match id:
		"watch_duty":
			var child: Variant=village.get("childhood")
			return typeof(child)==TYPE_DICTIONARY and typeof(child.get("completed"))==TYPE_ARRAY and child.completed.has("return_gear")
		"village_defense":
			return adult and int(village.get("raid",{}).get("won",0))>0
		"frontier_delivery":
			return adult and data.get("frontier",{}).get("completed",false)==true
		"valley_victory":
			return adult and data.get("valley",{}).get("outcome","")=="victory"
	return false


static func _reward_available(data: Dictionary, id: String) -> bool:
	if not _reward_proven(data,id):
		return false
	if id == "village_defense":
		# Claim only a recent successfully defended raid with actual player
		# contribution. The durable receipt remains valid after the next raid
		# resets the current participation counters; validate() uses won instead.
		var raid: Dictionary=data.get("village",{}).get("raid",{})
		return raid.get("outcome","")=="defended" and int(raid.get("participation",0))>0
	return true


static func _trained_soldier(data: Dictionary) -> bool:
	var player: Dictionary=data.get("player",{})
	var progress: Dictionary=data.get("progress",{})
	return int(player.get("age",0))>=18 and player.get("role","")=="soldier" and progress.get("training_complete",false)==true and progress.get("stage","") in ["trained","skirmish","aftermath","ended","fallen"]


static func _ready_reason(data: Dictionary) -> String:
	if int(data.get("player",{}).get("health",0))<=0:
		return "Du kannst gerade keinen Handel treiben."
	if bool(data.get("village",{}).get("raid",{}).get("active",false)) or bool(data.get("encounter",{}).get("active",false)):
		return "Während des Angriffs ruht der Handel."
	var combat: Variant=data.get("village",{}).get("unarmed")
	if typeof(combat)==TYPE_DICTIONARY and (not str(combat.get("technique","")).is_empty() or float(combat.get("guard_remaining",0.0))>0.000001 or float(combat.get("dodge_remaining",0.0))>0.000001):
		return "Lass deine aktuelle Kampfbewegung zuerst ausklingen."
	return ""


static func _shop_reason(data: Dictionary, shop_id: String, sites: Dictionary = {}) -> String:
	var point: Array = Catalog.SHOPS[shop_id].position
	var target := Vector3(float(point[0]),1.0,float(point[1]))
	# Existing isolated market tests keep their original catalog positions.
	# The real city must supply all six independently verified scene anchors.
	if not sites.is_empty():
		if not sites.has(shop_id) or typeof(sites[shop_id]) != TYPE_VECTOR3:
			return "Diese Verkaufsstelle ist nicht an die Stadt angeschlossen."
		target = sites[shop_id]
		if not target.is_finite():
			return "Der Standort dieser Verkaufsstelle ist ungültig."
	var at: Array=data.get("player",{}).get("position",[])
	if at.size()!=3 or Vector3(float(at[0]),float(at[1]),float(at[2])).distance_to(target)>RANGE:
		return "Gehe näher zur Verkaufsstelle: %s." % Catalog.SHOPS[shop_id].name
	return ""


static func _stock(data: Dictionary, shop_id: String, item_id: String) -> int:
	var trade: Dictionary=data.village.city_trade
	return int(Catalog.ITEMS[item_id].stock)-int(trade.purchases[shop_id][item_id])+int(trade.sales[shop_id][item_id])


static func _money_reason(data: Dictionary, delta: int) -> String:
	var money:=int(data.resources.denarii)
	var treasury:=int(data.village.economy.stocks.merchant_denarii)
	if money+delta<0:
		return "Dafür reichen deine Denare nicht."
	if treasury-delta<0:
		return "Die gemeinsame Händlerkasse kann diesen Betrag gerade nicht auszahlen."
	if money+delta>MAX_COUNT or treasury-delta>MAX_COUNT:
		return "Diese Zahlung würde den zulässigen Geldbestand überschreiten."
	return ""


static func _transfer_money(data: Dictionary, delta: int) -> void:
	data.resources.denarii=int(data.resources.denarii)+delta
	data.village.economy.stocks.merchant_denarii=int(data.village.economy.stocks.merchant_denarii)-delta


static func _keys(value: Variant, expected: Array) -> bool:
	if typeof(value)!=TYPE_DICTIONARY or value.size()!=expected.size():
		return false
	for key: Variant in expected:
		if not value.has(key):
			return false
	return true


static func _integer(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=low and float(value)<=high and float(value)==floorf(float(value))


static func _result(ok: bool, message: String) -> Dictionary:
	return {"ok":ok,"message":message}

