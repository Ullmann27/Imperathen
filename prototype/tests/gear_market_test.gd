extends SceneTree
## Equipment shops through real WorldModel commands: buy, sell, equip, home
## storage, and the era, age, access, tier and money gates.
## Positions at shop anchors are test positioning, not an automated playthrough.

const Model = preload("res://scripts/domain/world_model.gd")
const Gear = preload("res://scripts/domain/gear_market.gd")
const Calendar = preload("res://scripts/domain/world_calendar.gd")
const Formula = preload("res://scripts/battle/combat_formula.gd")
const Life = preload("res://scripts/story/village_life.gd")
const SITES := {"smith": Vector3(10, 1, 4), "outfitter": Vector3(16, 1, 4), "stable": Vector3(16, 1, -8),
	"market": Vector3(-10, 1, 4), "home": Vector3(-12.05, 1, 10.55)}
var checks := 0
var failures: Array[String] = []
var directory := "user://gear_market_%s" % Time.get_ticks_usec()


func _initialize() -> void:
	_test_catalog_and_prices()
	_test_era_gate()
	_test_child_cannot_buy()
	_test_access_and_tier_rules()
	_test_adult_58_bc_fixture()
	_test_adult_world_commands()
	_test_formula_link()
	_cleanup()
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("GEAR_MARKET_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("GEAR_MARKET_PASS" if failures.is_empty() else "GEAR_MARKET_FAIL")
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)


func _ok(result: Dictionary, label: String) -> void:
	_check(result.get("ok", false), label + ": " + str(result.get("message", "")))


func _refused(result: Dictionary, part: String, label: String) -> void:
	_check(not result.get("ok", true) and str(result.get("message", "")).contains(part), "%s (got: %s)" % [label, str(result.get("message", ""))])


func _snapshot(model) -> String:
	return JSON.stringify(model.data)


func _near(model, place: String) -> void:
	model.set_player_position(SITES[place])


func _buy(model, shop: String, id: String, quality: int, command_id := "") -> Dictionary:
	return model.execute("gear_buy", {"shop_id": shop, "item_id": id, "quality": quality}, command_id)


func _test_catalog_and_prices() -> void:
	Gear.reset_cache_for_tests()
	var catalog := Gear.catalog()
	_check(catalog.get("errors", []).is_empty(), "Catalog validates: " + str(catalog.get("errors", [])))
	_check(Gear.catalog_errors({"format": "x"}).size() == 1, "A foreign document is rejected")
	# Handbook 3.0 p. 116-118: Q0/Q1/Q2/Q3/Q4 price rows.
	var rows := {"gladius": [27, 55, 85, 153, 255], "pilum": [10, 21, 32, 58, 96], "spear": [18, 36, 55, 99, 165],
		"hand_axe": [14, 29, 44, 79, 132], "scutum": [17, 34, 52, 94, 156], "round_shield": [12, 24, 37, 67, 111]}
	for id: String in rows:
		for quality in 5:
			_check(Gear.price(id, quality) == rows[id][quality], "Handbook price %s Q%d" % [id, quality])
	_check(Gear.price("riding_horse", 2) == 220 and Gear.tiers("riding_horse") == [2], "Travel horse has the handbook base price and no sword-style tiers")
	_check(Gear.price("pugio", 2) == 30 and Gear.price("pugio", 4) == 90, "Supplement prices follow the handbook tier ratios")
	for id: String in catalog.items:
		var entry: Dictionary = catalog.items[id]
		var previous := 0
		for quality: int in Gear.tiers(id):
			_check(Gear.price(id, quality) > previous, "Better quality costs more: %s Q%d" % [id, quality])
			previous = Gear.price(id, quality)
			_check(Gear.sell_price(id, quality) < Gear.price(id, quality), "Selling stays below buying: %s Q%d" % [id, quality])
		if bool(entry.get("listed", true)):
			for lod in int(entry.lods):
				_check(ResourceLoader.exists(Gear.model_path(id, lod), "PackedScene"), "Listed item has its runtime model: %s LOD %d" % [id, lod])
		else:
			_check(not str(entry.get("unlisted_reason", "")).is_empty(), "A held-back item names its reason: " + id)
	for quality in 5:
		_check(not str(catalog.quality[quality].visible).is_empty(), "Each tier names its visible difference: Q%d" % quality)
	var shops: Dictionary = catalog.shops
	_check(shops.has("smith") and shops.has("outfitter") and shops.has("stable") and shops.has("market"), "Smith, outfitter, stable and market exist")
	_check(shops.outfitter.stock.has("pilum") and shops.outfitter.stock.has("scutum") and not shops.smith.stock.has("pilum"), "Service weapons are stocked at the outfitter only")
	_check(shops.stable.stock.has("riding_horse") and shops.market.stock.has("sling"), "Horse at the stable, sling at the market")


func _test_era_gate() -> void:
	var start := Calendar.to_jdn(-58, 5, 1)
	for id: String in ["gladius", "pugio", "pilum", "spear", "hand_axe", "sling", "scutum", "round_shield", "cavalry_shield", "cavalry_lance", "riding_horse"]:
		_check(Gear.era_open(id, start), "Available in 58 BC: " + id)
	for id: String in ["spatha", "muscle_cuirass", "crossbow"]:
		_check(not Gear.era_open(id, start), "Hidden in 58 BC: " + id)
	_check(not Gear.era_open("spatha", Calendar.to_jdn(13, 12, 31)) and Gear.era_open("spatha", Calendar.to_jdn(14, 1, 1)), "Spatha opens on its first registered day")
	_check(not Gear.era_open("muscle_cuirass", Calendar.to_jdn(-28, 12, 31)) and Gear.era_open("muscle_cuirass", Calendar.to_jdn(-27, 1, 1)), "Parade cuirass opens with the Principate")
	_check(not Gear.era_open("crossbow", Calendar.to_jdn(99, 12, 31)) and Gear.era_open("crossbow", Calendar.to_jdn(100, 1, 1)), "Crossbow concept opens in AD 100")
	_check(not Gear.era_open("gladius", Calendar.to_jdn(251, 1, 1)), "A family also ends: gladius after AD 250")
	_check(not Gear.era_open("gladius", start, {"equipment.gladius_family": {"suppressed": true, "divergence_id": "test"}}), "A marked divergence can close a registry entry")
	var registered := {}
	for row: Dictionary in Gear.registry(start):
		registered[row.item_id] = row
	for id: String in ["spatha", "muscle_cuirass", "crossbow", "horned_saddle", "bow"]:
		_check(registered.has(id), "Later or held-back item stays registered: " + id)
	_check(not registered.spatha.era_open and registered.spatha.listed and registered.spatha.valid_from == 14, "Spatha is registered with its era and hidden")
	_check(registered.horned_saddle.era_open and not registered.horned_saddle.listed, "Saddle is in era but held back for its model")


func _child_world():
	var model = Model.new()
	model.new_game("italia", true, true)
	model.gear_sites = SITES.duplicate()
	return model


func _test_child_cannot_buy() -> void:
	var legacy = Model.new()
	_check(not Gear.enabled(legacy.data) and not legacy.execute("gear_enable").ok, "A world without the village cannot open the equipment shops")
	var model = _child_world()
	var resources: Dictionary = model.data.resources.duplicate(true)
	var childhood: Dictionary = model.data.village.childhood.duplicate(true)
	_ok(model.execute("gear_enable", {}, "open-gear"), "Enable the equipment shops")
	_check(model.data.resources == resources and model.data.village.childhood == childhood, "Enabling gives no money, item or story progress")
	_check(model.data.village.gear.items.is_empty() and model.data.village.gear.equipped.values() == [0, 0, 0, 0, 0, 0, 0], "The twelve-year-old starts without weapons and armour")
	_check(model._validate_state(model.data).is_empty(), "Enabled child world validates")
	_check(Gear.world_jdn(model.data) == Calendar.to_jdn(-58, 5, 1), "The childhood world starts on 1 May 58 BC")
	var before := _snapshot(model)
	_refused(_buy(model, "smith", "gladius", 2), "näher", "A remote purchase is refused")
	_near(model, "smith")
	before = _snapshot(model)
	for id: String in ["gladius", "pugio", "spear", "hand_axe", "round_shield"]:
		for quality in 5:
			_refused(_buy(model, "smith", id, quality), "Erwachsener", "Child cannot buy %s Q%d" % [id, quality])
	_near(model, "market")
	_refused(_buy(model, "market", "sling", 1), "Erwachsener", "Child cannot buy the sling")
	_near(model, "outfitter")
	_refused(_buy(model, "outfitter", "pilum", 2), "Soldaten", "The outfitter turns the child away")
	_refused(_buy(model, "outfitter", "spatha", 2), "gibt es hier und heute nicht", "The outfitter turns the child away before any era detail")
	_near(model, "stable")
	_refused(_buy(model, "stable", "riding_horse", 2), "Erwachsener", "Child cannot buy a horse")
	_check(model.data.village.gear.items.is_empty() and JSON.stringify(model.data.village.gear.purchases).find("1") < 0, "Refused purchases leave no item and no receipt")
	_check(model.data.resources == resources, "Refused purchases cost nothing")
	_near(model, "smith")
	for offer: Dictionary in Gear.view(model.data, "smith", SITES).offers:
		_check(not offer.can_buy and offer.reason.contains("Erwachsener"), "Offer shows the age gate: %s Q%d" % [offer.item_id, offer.quality])
	for value: Variant in [-1, 5, 1.5, NAN, "2", true]:
		_check(not model.execute("gear_buy", {"shop_id": "smith", "item_id": "gladius", "quality": value}).ok, "Malformed quality rejected: " + str(value))
	_check(not model.execute("gear_buy", {"shop_id": "smith", "item_id": "gladius", "quality": 2, "price": 0}).ok, "Caller cannot set a price")
	_check(not model.execute("gear_buy", {"shop_id": "nowhere", "item_id": "gladius", "quality": 2}).ok, "Unknown shop rejected")
	# Domain fixture: the same child with an empty purse (owner rule D-017).
	var poor: Dictionary = model.data.duplicate(true)
	poor.resources.denarii = 0
	_check(not Gear.apply(poor, "gear_buy", {"shop_id": "smith", "item_id": "gladius", "quality": 0}, SITES).ok and poor.village.gear.items.is_empty(), "A child without money owns nothing after trying")
	# Domain fixture: a child cannot wear a piece even if a save claimed one.
	var forged: Dictionary = model.data.duplicate(true)
	forged.village.gear.purchases.smith.gladius[2] = 1
	forged.village.gear.items.append({"uid": 1, "id": "gladius", "q": 2, "wear": 0.0, "at": "carried"})
	forged.village.gear.serial = 2
	_refused(Gear.apply(forged, "gear_equip", {"uid": 1}, SITES), "Erwachsenenweg", "A child cannot wear a weapon")
	forged.village.gear.equipped.main_hand = 1
	_check(not Gear.validate(forged).is_empty(), "A save with an armed child is invalid")


func _context(overrides: Dictionary = {}) -> Dictionary:
	var context := {"age": 25, "trained": true, "service": true, "mount": false, "appointments": [], "allies": [],
		"achievements": [], "profession": "", "skills": {"combat": 20, "defense": 20, "command": 0, "riding": 0},
		"jdn": Calendar.to_jdn(-58, 5, 1)}
	context.merge(overrides, true)
	return context


func _test_access_and_tier_rules() -> void:
	_check(Gear.offer_reason("smith", "gladius", 2, _context()).is_empty(), "Trained adult may buy a solid gladius")
	_check(Gear.offer_reason("smith", "gladius", 2, _context({"trained": false})).contains("Waffenausbildung"), "Untrained adult may not")
	_check(Gear.offer_reason("smith", "gladius", 2, _context({"age": 17})).contains("Erwachsener"), "Age gate at 18")
	_check(Gear.offer_reason("outfitter", "pilum", 2, _context({"service": false})).contains("Soldaten"), "Outfitter serves soldiers only")
	_check(Gear.offer_reason("outfitter", "pilum", 2, _context()).is_empty(), "Soldier in service buys the pilum")
	_check(Gear.offer_reason("outfitter", "cavalry_lance", 2, _context()).contains("Pferd"), "Lance needs an owned mount")
	_check(Gear.offer_reason("outfitter", "cavalry_lance", 2, _context({"mount": true})).is_empty(), "Lance with an owned mount")
	_check(Gear.offer_reason("smith", "pilum", 2, _context()).contains("führt"), "The smith does not carry service pila")
	# Q3: skill 45 or a specialist; Q4: skill 65, a proven achievement and a specialist.
	_check(Gear.offer_reason("smith", "gladius", 3, _context()).contains("45"), "Q3 refused below skill 45")
	_check(Gear.offer_reason("smith", "gladius", 3, _context({"skills": {"combat": 45, "defense": 0, "command": 0, "riding": 0}})).is_empty(), "Q3 with skill 45")
	_check(Gear.offer_reason("smith", "gladius", 3, _context({"allies": ["severus"]})).is_empty(), "Q3 with a specialist contact")
	_check(Gear.offer_reason("smith", "gladius", 3, _context({"profession": "smith"})).is_empty(), "Q3 with the smith's trade")
	_check(Gear.offer_reason("market", "sling", 3, _context({"allies": ["severus"]})).contains("45"), "A contact only counts in its own shop")
	var master := {"skills": {"combat": 65, "defense": 65, "command": 0, "riding": 0}, "achievements": ["village_defense"], "allies": ["severus"]}
	_check(Gear.offer_reason("outfitter", "gladius", 4, _context(master)).is_empty(), "Q4 with skill, achievement and access")
	for missing: String in ["skills", "achievements", "allies"]:
		var partial := master.duplicate(true)
		partial.erase(missing)
		_check(not Gear.offer_reason("outfitter", "gladius", 4, _context(partial)).is_empty(), "Q4 refused without " + missing)
	_check(Gear.offer_reason("outfitter", "scutum", 4, _context({"skills": {"combat": 99, "defense": 20, "command": 0, "riding": 0}, "achievements": ["village_defense"], "allies": ["severus"]})).contains("65"), "A shield tier reads the defence skill, not combat")
	# Appointments: a rank is conferred, never bought.
	var rules: Dictionary = Gear.item("muscle_cuirass").access
	_check(Gear.access_reason(rules, _context()).contains("Ernennung"), "Rank piece refused without an appointment")
	_check(Gear.access_reason(rules, _context({"appointments": ["centurio"]})).is_empty(), "Rank piece allowed for a held appointment")
	_check(Gear.access_reason(rules, _context({"appointments": ["signifer"]})).contains("Ernennung"), "Another appointment does not count")


func _test_adult_58_bc_fixture() -> void:
	# Domain fixture, not a playthrough: the 58 BC world with the player set to a
	# trained adult. It proves the gates against the real catalog and calendar.
	var model = _child_world()
	_ok(model.execute("gear_enable"), "Enable for the fixture")
	var data: Dictionary = model.data.duplicate(true)
	data.player.age = 20
	data.player.role = "soldier"
	data.progress.training_complete = true
	data.progress.stage = "trained"
	data.resources.denarii = 400
	data.village.economy.stocks.merchant_denarii = 100
	data.player.position = [16.0, 1.0, 4.0]
	var offered := {}
	for offer: Dictionary in Gear.view(data, "outfitter", SITES).offers:
		offered[offer.item_id] = true
	_check(offered.has("gladius") and offered.has("pilum") and offered.has("scutum") and offered.has("cavalry_shield") and offered.has("cavalry_lance"), "58 BC outfitter offers the period service gear")
	_check(not offered.has("spatha") and not offered.has("muscle_cuirass"), "58 BC outfitter shows neither spatha nor parade cuirass")
	_refused(Gear.apply(data, "gear_buy", {"shop_id": "outfitter", "item_id": "spatha", "quality": 2}, SITES), "hier und heute nicht", "Spatha cannot be bought in 58 BC")
	_ok(Gear.apply(data, "gear_buy", {"shop_id": "outfitter", "item_id": "gladius", "quality": 2}, SITES), "Gladius can be bought in 58 BC")
	_ok(Gear.apply(data, "gear_buy", {"shop_id": "outfitter", "item_id": "scutum", "quality": 2}, SITES), "Scutum can be bought in 58 BC")
	_check(data.resources.denarii == 400 - 85 - 52 and data.village.economy.stocks.merchant_denarii == 100 + 85 + 52, "Both payments reach the merchant treasury")
	_ok(Gear.apply(data, "gear_equip", {"uid": 1}, SITES), "Wear the gladius")
	_ok(Gear.apply(data, "gear_equip", {"uid": 2}, SITES), "Carry the scutum")
	_check(Gear.validate(data).is_empty(), "Fixture state stays valid: " + Gear.validate(data))
	var inputs := Gear.combat_inputs(data)
	_check(inputs.weapon == {"family": "gladius", "quality": 2, "wear": 0.0} and inputs.shield.family == "scutum", "Equipped pieces become formula inputs")
	_check(Gear.equipped_models(data).size() == 2 and Gear.equipped_models(data)[0].model == "weap_roman_gladius_pompeii", "Equipped pieces name their models")
	# Later in the same world the spatha appears without any other change.
	data.progress.years_elapsed = 72
	offered.clear()
	for offer: Dictionary in Gear.view(data, "outfitter", SITES).offers:
		offered[offer.item_id] = true
	_check(Calendar.year_of(Gear.world_jdn(data)) >= 14 and offered.has("spatha"), "The spatha is offered once the calendar reaches its era")


func _clear(_from: Vector2, _to: Vector2) -> bool:
	return true


func _stationary(from: Vector2, _to: Vector2) -> Vector2:
	return from


func _attack(model, target: String) -> Dictionary:
	return model.execute("village_unarmed_attack", {"technique": "jab_left", "target_id": target, "facing_x": 0.0, "facing_z": -1.0})


func _trained_villager():
	# Reached through existing commands and simulated time (same path as
	# city_trade_test), never by assigning age, training or money.
	var model = Model.new()
	model.new_game("italia", true, false, true)
	model.combat_sight_check = _clear
	model.combat_motion_check = _stationary
	model.set_player_position(Vector3(-8, 1, 2))
	for i in 3:
		_ok(model.execute("gather", {"node_id": "timber_0"}), "Collect home material")
	model.set_player_position(Vector3(-3, 1, 4))
	_ok(model.execute("choose_companion", {"choice": "help"}), "Companion choice")
	_ok(model.execute("build", {"x": 8.0, "z": 5.0}), "Pay for home")
	model.set_player_position(Vector3(8, 1, 5))
	model.advance(12)
	for id: String in ["decimus", "aelia", "varro"]:
		var at: Vector2 = Life.actor_position(model.data, id)
		model.set_player_position(Vector3(at.x, 1, at.y))
		_ok(model.execute("village_talk", {"npc_id": id, "choice": "meet"}), "Meet " + id)
	model.set_player_position(Vector3(50, 1, 50))
	model.advance(Life.FIRST_WARNING - float(model.data.village.social.seconds))
	model.advance(Life.WARNING_SECONDS)
	var attempts := 0
	while model.data.village.raid.active and attempts < 32:
		var target: Dictionary = {}
		for enemy: Dictionary in model.data.village.raid.enemies:
			if int(enemy.health) > 0:
				target = enemy.duplicate()
				break
		if target.is_empty():
			break
		model.set_player_position(Vector3(float(target.x), 1, float(target.z) + 0.7))
		if not _attack(model, str(target.id)).ok:
			break
		model.advance(0.25)
		model.set_player_position(Vector3(50, 1, 50))
		model.advance(1)
		attempts += 1
	model.set_player_position(Vector3(0, 1, -6))
	model.advance(maxf(0.0, 240.0 - float(model.data.village.social.seconds)))
	_ok(model.execute("train"), "Adult transition")
	for i in 3:
		_ok(_attack(model, "practice"), "Adult training contact")
		model.advance(0.7)
	_check(model.data.player.age == 18 and model.data.progress.training_complete, "Adult training completed through play")
	model.gear_sites = SITES.duplicate()
	return model


func _test_adult_world_commands() -> void:
	var model = _trained_villager()
	if not model.data.progress.training_complete:
		return
	_ok(model.execute("gear_enable"), "Adult opens the equipment shops")
	_check(Calendar.year_of(Gear.world_jdn(model.data)) >= 100, "The legacy career plays around AD 100")
	var money := int(model.data.resources.denarii)
	var cash := int(model.data.village.economy.stocks.merchant_denarii)
	_check(money >= 19 and money < 220, "Fixture purse suits the scenario (%d denarii)" % money)
	# Buy.
	_near(model, "market")
	var before := _snapshot(model)
	var bought := _buy(model, "market", "hand_axe", 0, "axe-once")
	_ok(bought, "Buy a worn hand axe at the market")
	_check(model.data.village.gear.items.size() == 1 and model.data.village.gear.items[0].uid == 1, "The purchase is the last entry of the gear list")
	_check(model.data.resources.denarii == money - 14 and model.data.village.economy.stocks.merchant_denarii == cash + 14, "Price reaches the merchant treasury exactly")
	_check(Gear.stock(model.data, "market", "hand_axe", 0) == 0, "Finite stock went down")
	before = _snapshot(model)
	_check(_buy(model, "market", "hand_axe", 0, "axe-once") == bought and _snapshot(model) == before, "Transport replay neither charges nor delivers twice")
	_refused(_buy(model, "market", "hand_axe", 0), "vorrätig", "Sold-out stock is refused")
	_ok(_buy(model, "market", "sling", 1), "Buy a used sling")
	_check(model.data.resources.denarii == money - 14 - 5 and model.data.village.gear.items.size() == 2, "Two pieces owned, both paid")
	_check(model._validate_state(model.data).is_empty(), "World validates after purchases: " + model._validate_state(model.data))
	# Money, tier and site gates on the real adult.
	_near(model, "stable")
	_refused(_buy(model, "stable", "riding_horse", 2), "reichen deine Denare nicht", "A horse costs more than the purse holds")
	_near(model, "smith")
	_refused(_buy(model, "smith", "gladius", 3), "45", "High quality needs skill or a specialist")
	_refused(_buy(model, "smith", "gladius", 4), "65", "Master work needs skill 65")
	var without_stable: Dictionary = SITES.duplicate()
	without_stable.erase("stable")
	model.gear_sites = without_stable
	_refused(_buy(model, "stable", "riding_horse", 2), "nicht erreichbar", "A shop without a place in this settlement stays closed")
	model.gear_sites = SITES.duplicate()
	_check(_snapshot(model).contains("\"serial\":3"), "Refusals did not consume piece numbers")
	# The AD 100 outfitter shows the spatha; the 58 BC one did not.
	_near(model, "outfitter")
	var offered := {}
	for offer: Dictionary in Gear.view(model.data, "outfitter", SITES).offers:
		offered[offer.item_id] = offer
	_check(offered.has("spatha") and offered.has("pilum") and not offered.has("muscle_cuirass"), "AD 100 outfitter offers the spatha; the unbuilt cuirass stays out")
	# Equip.
	_ok(model.execute("gear_equip", {"uid": 1}), "Take the axe in hand")
	_check(model.data.village.gear.equipped.main_hand == 1, "Axe sits in the main hand")
	_check(Gear.combat_inputs(model.data).weapon == {"family": "axe", "quality": 0, "wear": 0.0}, "Formula input is the worn axe")
	_ok(model.execute("gear_equip", {"uid": 2}), "Hang the sling at the belt")
	_check(Gear.combat_inputs(model.data).missile.family == "sling" and Gear.equipped_models(model.data).size() == 2, "Both pieces are carried visibly")
	# Sell.
	_near(model, "smith")
	_refused(model.execute("gear_sell", {"shop_id": "smith", "uid": 1}), "Lege", "An equipped piece is not sold")
	_refused(model.execute("gear_sell", {"shop_id": "smith", "uid": 2}), "kauft diesen Gegenstand nicht", "The smith does not take the sling")
	_refused(model.execute("gear_sell", {"shop_id": "smith", "uid": 9}), "besitzt du nicht", "Unknown piece")
	_ok(model.execute("gear_equip", {"uid": 1}), "Put the axe away")
	_check(model.data.village.gear.equipped.main_hand == 0 and Gear.combat_inputs(model.data).weapon.is_empty(), "Unarmed again")
	var purse := int(model.data.resources.denarii)
	var smith_stock := Gear.stock(model.data, "smith", "hand_axe", 0)
	_ok(model.execute("gear_sell", {"shop_id": "smith", "uid": 1}, "sell-axe"), "Sell the axe to the smith")
	_check(model.data.resources.denarii == purse + 5 and Gear.sell_price("hand_axe", 0) == 5, "Sale pays 40 percent of the tier price")
	_check(Gear.stock(model.data, "smith", "hand_axe", 0) == smith_stock + 1 and model.data.village.gear.items.size() == 1, "The piece moved into the smith's stock")
	_check(model._validate_state(model.data).is_empty(), "World validates after the sale: " + model._validate_state(model.data))
	# Home chest.
	_refused(model.execute("gear_store", {"uid": 2}), "näher", "The chest is at home, not at the smith")
	_near(model, "home")
	_refused(model.execute("gear_store", {"uid": 2}), "zuerst ab", "A worn piece is not stored")
	_ok(model.execute("gear_equip", {"uid": 2}), "Take the sling off")
	_ok(model.execute("gear_store", {"uid": 2}), "Put the sling into the chest at home")
	_check(model.data.village.gear.items[0].at == "home" and Gear.view(model.data, "", SITES).home.stored == 1, "The chest holds the sling")
	_refused(model.execute("gear_equip", {"uid": 2}), "Truhe", "A stored piece cannot be worn")
	_near(model, "market")
	_refused(model.execute("gear_sell", {"shop_id": "market", "uid": 2}), "Truhe", "A stored piece cannot be sold from afar")
	# Save, reload, replay.
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory + "/gear.json"
	_ok(model.save_game(path), "Save with stored and sold gear")
	var loaded = Model.new()
	_ok(loaded.load_game(path), "Reload")
	loaded.gear_sites = SITES.duplicate()
	_check(JSON.stringify(loaded.data.village.gear) == JSON.stringify(model.data.village.gear), "Gear, stock books and chest survive the reload")
	_check(loaded.data.resources.denarii == model.data.resources.denarii, "Purse survives the reload")
	_check(loaded.execute("gear_sell", {"shop_id": "smith", "uid": 1}, "sell-axe").ok and loaded.data.village.gear.items.size() == 1, "A replayed sale after reload pays nothing again")
	loaded.set_player_position(SITES.home)
	_ok(loaded.execute("gear_take", {"uid": 2}), "Take the sling out again after reload")
	_check(loaded.data.village.gear.items[0].at == "carried", "Sling is carried again")
	# Tampering is caught by the proofs.
	for attempt: String in ["free_item", "free_money", "foreign_item", "wrong_slot", "stock"]:
		var forged: Dictionary = loaded.data.duplicate(true)
		match attempt:
			"free_item":
				forged.village.gear.items.append({"uid": 3, "id": "gladius", "q": 4, "wear": 0.0, "at": "carried"})
				forged.village.gear.serial = 4
			"free_money": forged.resources.denarii = int(forged.resources.denarii) + 100
			"foreign_item": forged.village.gear.items[0].id = "excalibur"
			"wrong_slot": forged.village.gear.equipped.shield = 2
			"stock": forged.village.gear.purchases.smith.gladius[0] = 99
		_check(not loaded._validate_state(forged).is_empty(), "Tampered save is rejected: " + attempt)


func _test_formula_link() -> void:
	# The shop only supplies family and quality; the shared formula (D-042)
	# turns them into damage. No factor is computed in the shop code.
	var previous := 0.0
	var damages := []
	for quality in 5:
		var hit := {"weapon": {"family": str(Gear.item("gladius").combat_family), "quality": quality, "wear": 0.0},
			"attacker": {"skill": 55, "stamina": 100, "injuries": []}, "defender": {"skill": 0, "armor": {}},
			"zone": "torso", "shield_cover": 0.0, "impact": 1.0}
		var result := Formula.resolve_hit(hit)
		_check(result.get("hit", false) and float(result.damage) > previous, "A better gladius hits harder through the shared formula: Q%d" % quality)
		previous = float(result.damage)
		damages.append(snappedf(previous, 0.01))
	_check(damages.size() == 5 and damages[4] / damages[1] > 1.1 and damages[4] / damages[1] < 1.25, "Q4 over Q1 stays a bounded advantage: " + str(damages))
	var veteran := Formula.resolve_hit({"weapon": {"family": "gladius", "quality": 2, "wear": 0.0}, "attacker": {"skill": 75, "stamina": 100, "injuries": []},
		"defender": {"skill": 0, "armor": {}}, "zone": "torso", "shield_cover": 0.0, "impact": 1.0})
	var novice := Formula.resolve_hit({"weapon": {"family": "gladius", "quality": 4, "wear": 0.0}, "attacker": {"skill": 25, "stamina": 100, "injuries": []},
		"defender": {"skill": 0, "armor": {}}, "zone": "torso", "shield_cover": 0.0, "impact": 1.0})
	_check(float(veteran.damage) > float(novice.damage), "Training outweighs a master blade (D-042)")
	for id: String in Gear.catalog().items:
		var family := str(Gear.item(id).get("combat_family", ""))
		var slot := str(Gear.item(id).slot)
		if family.is_empty():
			continue
		var balance := Formula.balance()
		var known: bool = balance.weapons.has(family) if slot in ["main_hand", "missile"] else (balance.shields.families.has(family) if slot == "shield" else balance.armor.families.has(family))
		_check(known, "Combat family of %s exists in combat_balance.json: %s" % [id, family])


func _cleanup() -> void:
	var folder := DirAccess.open(directory)
	if folder == null:
		return
	for file: String in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(directory)
