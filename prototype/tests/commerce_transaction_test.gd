extends SceneTree
## Regression scenarios for finite trade, actual staff and the WorldModel save/replay boundary.

const Economy = preload("res://scripts/domain/village_economy.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Life = preload("res://scripts/story/village_life.gd")
const Behavior = preload("res://scripts/domain/npc_behavior.gd")

var checks := 0
var failures: Array[String] = []
var save_directory := "user://commerce_transactions_%s" % Time.get_ticks_usec()


func _initialize() -> void:
	_test_full_delivery_price()
	_test_treasury_recirculation()
	_test_failed_purchases_are_atomic()
	_test_staff_and_raid_pause()
	_test_civilian_alarm_and_guard_duty()
	_test_guard_reassignment_through_world()
	_test_partitioned_treasury_exhaustion()
	_test_world_save_and_replay()
	_cleanup()
	print("COMMERCE_TRANSACTION_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("COMMERCE_TRANSACTION_PASS" if failures.is_empty() else "COMMERCE_TRANSACTION_FAIL")
	quit(0 if failures.is_empty() else 1)


func _trading_world(trader := false) -> Dictionary:
	var data := {
		"resources":{"wood":40, "grain":12, "denarii":30},
		"village":{"social":{"profession":"trader" if trader else "", "npcs":{"decimus":{"met":true}}}, "raid":{"active":false}}
	}
	Economy.ensure(data)
	_check(Economy.execute(data, "village_request_work").ok, "Existing steward authorizes village work")
	for id: String in ["cassia", "silvanus"]:
		_check(Economy.execute(data, "village_assign", {"resident_id":id, "workplace_id":"trade"}).ok, "An existing named worker staffs the test market: " + id)
	# Isolated economy fixture: repair accounting has separate integration coverage below.
	data.village.economy.workplaces.trade.condition = 100
	return data


func _trade_view(data: Dictionary) -> Dictionary:
	for place: Dictionary in Economy.view(data).workplaces:
		if place.id == "trade":
			return place
	return {}


func _test_full_delivery_price() -> void:
	for trained: bool in [false, true]:
		var price := 7 if trained else 6
		for cash in price:
			var data := _trading_world(trained)
			data.village.economy.stocks.merchant_denarii = cash
			data.village.economy.workplaces.trade.cycle_seconds = 19.5
			_check(Economy.advance(data, 60.0), "A short-funded market does not stop the world clock")
			_check(data.resources.wood == 40 and data.resources.denarii == 30 and data.village.economy.stocks.merchant_denarii == cash, "No four-wood cargo is exchanged for a partial payment (%d/%d)" % [cash, price])
			_check(data.village.economy.workplaces.trade.cycle_seconds == 19.5 and data.village.economy.workplaces.trade.produced_cycles == 0, "Waiting for money neither completes nor banks delivery work")
			var view := _trade_view(data)
			_check(not view.working and view.reason.contains("%d Denare" % price) and view.yield_per_cycle == price, "The market exposes the complete price while funds are short")
		var exact := _trading_world(trained)
		exact.village.economy.stocks.merchant_denarii = price
		exact.resources.denarii = Economy.MAX_RESOURCE - price
		_check(Economy.advance(exact, 60.0), "An exactly funded and exactly fitting delivery completes")
		_check(exact.resources.wood == 36 and exact.resources.denarii == Economy.MAX_RESOURCE and exact.village.economy.stocks.merchant_denarii == 0, "A completed delivery transfers exactly four wood and its full proceeds")
		_check(exact.village.economy.ledger.wood == -4 and exact.village.economy.ledger.denarii == price, "Both delivery legs appear in the central signed ledger")
		_check(Economy.advance(exact, 60.0) and exact.resources.wood == 36 and exact.village.economy.workplaces.trade.produced_cycles == 1, "An exhausted treasury cannot pay a second delivery")


func _test_treasury_recirculation() -> void:
	for discounted: bool in [false, true]:
		var data := _trading_world()
		if discounted:
			data.village.abilities = {"version":1, "earned":["ch1_price_is_promise"]}
		var price := 5 if discounted else 6
		data.village.economy.stocks.merchant_denarii = 1
		data.village.economy.workplaces.trade.cycle_seconds = 23.0
		var money_sum: int = data.resources.denarii + data.village.economy.stocks.merchant_denarii
		var grain_sum: int = data.resources.grain + data.village.economy.stocks.emergency_grain
		_check(Economy.execute(data, "village_buy_food").ok, "An actual food purchase restores merchant liquidity")
		_check(data.resources.denarii == 30 - price and data.village.economy.stocks.merchant_denarii == 1 + price, "Only the actual price paid is credited, including the earned discount")
		_check(data.resources.denarii + data.village.economy.stocks.merchant_denarii == money_sum and data.resources.grain + data.village.economy.stocks.emergency_grain == grain_sum, "Food purchase conserves money and the existing emergency grain")
		_check(data.village.economy.ledger.denarii == -price and data.village.economy.ledger.grain == 16, "The food purchase has one matched central debit and credit")
		_check(Economy.advance(data, 36.5), "Funded work resumes from the saved partial delivery")
		_check(data.resources.wood == 40 and data.village.economy.workplaces.trade.produced_cycles == 0, "Restored funds do not retroactively finish a delivery")
		_check(Economy.advance(data, 0.5), "Remaining delivery work completes")
		_check(data.resources.wood == 36 and data.resources.denarii == 36 - price and data.village.economy.stocks.merchant_denarii == price - 5, "The completed delivery consumes four wood and all six owed denarii")
		_check(data.resources.denarii + data.village.economy.stocks.merchant_denarii == money_sum, "Money still balances after purchase and resumed sale")
		_check(Economy.validate(data).is_empty(), "Recycled treasury remains within the existing economy schema")


func _test_failed_purchases_are_atomic() -> void:
	for blocked: String in ["treasury_capacity", "grain_capacity", "player_money", "emergency_stock", "authority"]:
		var data := _trading_world()
		match blocked:
			"treasury_capacity": data.village.economy.stocks.merchant_denarii = Economy.MAX_RESOURCE - 5
			"grain_capacity": data.resources.grain = Economy.MAX_RESOURCE - 15
			"player_money": data.resources.denarii = 5
			"emergency_stock": data.village.economy.stocks.emergency_grain = 15
			"authority": data.village.economy.authority.work_permit = false
		var before := JSON.stringify(data)
		_check(not Economy.execute(data, "village_buy_food").ok, "Unavailable food purchase is rejected: " + blocked)
		_check(JSON.stringify(data) == before, "Rejected purchase changes no goods, money, stock or ledger: " + blocked)
	var exact := _trading_world()
	exact.village.economy.stocks.merchant_denarii = Economy.MAX_RESOURCE - 6
	_check(Economy.execute(exact, "village_buy_food").ok and exact.village.economy.stocks.merchant_denarii == Economy.MAX_RESOURCE, "A payment fitting the last six treasury slots succeeds")
	var paid := JSON.stringify(exact)
	_check(not Economy.execute(exact, "village_buy_food").ok and JSON.stringify(exact) == paid, "The next payment cannot overflow a full treasury")


func _test_staff_and_raid_pause() -> void:
	var data := _trading_world()
	data.village.economy.workplaces.trade.cycle_seconds = 31.0
	data.village.behavior = {"people":{"cassia":{"activity":"rest"}, "silvanus":{"activity":"work"}}}
	_check(Economy.advance(data, 20.0), "Merchant can rest while simulation time advances")
	_check(data.resources.wood == 40 and data.resources.denarii == 30 and data.village.economy.workplaces.trade.cycle_seconds == 31.0, "One absent merchant halts actual delivery work")
	_check(_trade_view(data).assigned == 2 and _trade_view(data).available == 1, "The resting merchant is one assigned person, not a replacement worker")
	data.village.behavior.people.cassia.activity = "work"
	_check(Economy.execute(data, "village_shift", {"resident_id":"silvanus", "duty":"defense"}).ok, "The existing porter can leave the market to defend")
	_check(Economy.advance(data, 20.0) and data.village.economy.workplaces.trade.cycle_seconds == 31.0, "A defender does not also deliver trade cargo")
	_check(Economy.execute(data, "village_shift", {"resident_id":"silvanus", "duty":"return"}).ok, "The same porter returns to his still-free market assignment")
	data.village.raid.active = true
	_check(Economy.advance(data, 20.0) and data.resources.wood == 40 and data.resources.denarii == 30, "A raid suspends trade without consuming cargo or payment")
	data.village.raid.active = false
	_check(Economy.advance(data, 29.0), "The surviving crew completes only its outstanding work")
	_check(data.resources.wood == 36 and data.resources.denarii == 36 and data.village.economy.workplaces.trade.produced_cycles == 1, "Rest, defense and raid interruption do not duplicate a sale")


func _test_partitioned_treasury_exhaustion() -> void:
	var whole := _trading_world(true)
	whole.village.economy.stocks.merchant_denarii = 15
	whole.village.economy.workplaces.trade.cycle_seconds = 17.0
	var pieces: Dictionary = whole.duplicate(true)
	_check(Economy.advance(whole, 171.0), "Long tick crosses delivery and treasury exhaustion boundaries")
	for index in 342:
		if not Economy.advance(pieces, 0.5):
			_check(false, "Short economy tick was rejected at step %d" % index)
			break
	_check(whole == pieces, "A long tick and half-second ticks produce identical balances and partial work")
	_check(whole.resources.wood == 32 and whole.resources.denarii == 44 and whole.village.economy.stocks.merchant_denarii == 1, "Two trained deliveries leave one denarius untouched")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(whole))
	_check(Economy.validate(restored).is_empty() and restored.village.economy.version == 1, "The existing economy version loads treasury leftovers without migration")
	_check(Economy.execute(whole, "village_buy_food").ok and Economy.execute(restored, "village_buy_food").ok, "One real food payment funds the next trained delivery after reload")
	_check(Economy.advance(whole, 60.0) and Economy.advance(restored, 60.0), "Saved economy resumes a funded delivery")
	_check(JSON.parse_string(JSON.stringify(whole)) == JSON.parse_string(JSON.stringify(restored)), "JSON reload cannot change subsequent money flow or production")


func _test_civilian_alarm_and_guard_duty() -> void:
	for reaction: String in ["alert", "patrol"]:
		var data := _trading_world()
		data.village.economy.workplaces.trade.cycle_seconds = 17.5
		data.village.economy.workplaces.watchpost.condition = 100
		data.village.behavior = {"people":{
			"cassia":{"activity":reaction}, "silvanus":{"activity":"work"},
			"severus":{"activity":"alert"}, "valeria":{"activity":"patrol"}
		}}
		_check(Economy.advance(data, 60.0), "Alarm and patrol roles advance on the common simulation clock")
		_check(data.village.economy.workplaces.trade.cycle_seconds == 17.5 and data.resources.wood == 40 and data.resources.denarii == 30, "A civilian responding to danger cannot simultaneously ship cargo: " + reaction)
		_check(_trade_view(data).available == 1, "The civilian reaction removes one real market worker")
		_check(data.village.economy.patrols_completed == 1, "Two people actually assigned to the watchpost can continue alert and patrol duties")
		data.village.behavior.people.cassia.activity = "work"
		_check(Economy.advance(data, 42.5) and data.resources.wood == 36 and data.resources.denarii == 36, "Civilian return resumes remaining delivery work without duplicating a worker")


func _test_world_save_and_replay() -> void:
	var model_script: Script = Model
	if not model_script.can_instantiate():
		_check(false, "WorldModel must compile before the real save/replay scenario can run")
		return
	var model := Model.new()
	model.new_game("italia", true)
	var steward: Vector2 = Life.actor_position(model.data, "decimus")
	model.set_player_position(Vector3(steward.x, 1.0, steward.y))
	_check(model.execute("village_talk", {"npc_id":"decimus", "choice":"meet"}).ok, "Meet actual steward through the WorldModel")
	_check(model.execute("village_request_work", {}, "commerce-work-permit").ok, "Actual permit is recorded through the authoritative command path")
	for node: Dictionary in model.data.resource_nodes.duplicate(true):
		model.set_player_position(Vector3(node.x, 1.0, node.z))
		for index in 4:
			_check(model.execute("gather", {"node_id":node.id}).ok, "Gather real material for repaired trade infrastructure")
	for id: String in ["aelia", "quintus", "sextus", "antonia"]:
		_check(model.execute("village_assign", {"resident_id":id, "workplace_id":"quarry"}).ok, "A named quarry crew supplies market repair stone: " + id)
	_check(model.execute("village_repair", {"workplace_id":"quarry"}).ok, "Pay for quarry repair from gathered timber")
	model.advance(80.0)
	_check(model.data.resources.stone == 6, "Stone used by the market was actually quarried")
	for id: String in ["cassia", "silvanus"]:
		_check(model.execute("village_assign", {"resident_id":id, "workplace_id":"trade"}).ok, "The repaired market uses existing adult residents")
	_check(model.execute("village_repair", {"workplace_id":"trade"}).ok, "Pay for market repair with actual wood and stone")
	model.advance(55.0)
	_check(is_equal_approx(float(model.data.village.economy.workplaces.trade.cycle_seconds), 15.0), "Only fifteen seconds of delivery work follow forty seconds of repair")
	var money_total: int = model.data.resources.denarii + model.data.village.economy.stocks.merchant_denarii
	var purchase: Dictionary = model.execute("village_buy_food", {}, "commerce-food-1")
	_check(purchase.ok and model.data.resources.denarii == 24 and model.data.village.economy.stocks.merchant_denarii == 606, "World transaction credits the merchant with exactly the paid amount")
	var paid_state := JSON.stringify(model.data)
	_check(model.execute("village_buy_food", {}, "commerce-food-1") == purchase and JSON.stringify(model.data) == paid_state, "Retrying the same purchase ID neither debits nor credits a second time")
	_check(not model.execute("village_resow", {}, "commerce-food-1").ok and JSON.stringify(model.data) == paid_state, "Reusing a payment ID for another action is rejected atomically")
	var path := save_directory.path_join("market.json")
	_check(model.save_game(path).ok, "Save an actual food payment and partly completed delivery")
	var loaded := Model.new()
	_check(loaded.load_game(path).ok and loaded.data.schema_version == Model.SCHEMA_VERSION and loaded.data.village.economy.version == 1, "Real envelope reload preserves the published world and economy versions")
	var loaded_state := JSON.stringify(loaded.data)
	_check(loaded.execute("village_buy_food", {}, "commerce-food-1") == purchase and JSON.stringify(loaded.data) == loaded_state, "Saved command identity prevents double merchant credit after restart")
	model.advance(45.0)
	loaded.advance(45.0)
	_check(loaded.data.resources == model.data.resources and loaded.data.village.economy == model.data.village.economy, "Reloaded repair and delivery progress produce identical authoritative balances")
	_check(loaded.data.resources.denarii == 30 and loaded.data.village.economy.stocks.merchant_denarii == 600 and loaded.data.village.economy.stocks.emergency_grain == 48, "One purchase and one completed delivery balance without recreating sold grain")
	_check(loaded.data.resources.denarii + loaded.data.village.economy.stocks.merchant_denarii == money_total and loaded._validate_state(loaded.data).is_empty(), "The complete world still balances after the two-sided cash flow")


func _test_guard_reassignment_through_world() -> void:
	var model := Model.new()
	model.new_game("italia", true)
	Behavior.start(model.data)
	_check(Behavior.enabled(model.data) and model._validate_state(model.data).is_empty(), "Legacy village work can be tested with the real NPC decision system active")
	var steward: Vector2 = Life.actor_position(model.data, "decimus")
	model.set_player_position(Vector3(steward.x, 1.0, steward.y))
	_check(model.execute("village_talk", {"npc_id":"decimus", "choice":"meet"}).ok, "Meet the steward before changing a guard's job")
	_check(model.execute("village_request_work", {}, "guard-civilian-permit").ok, "The actual steward permits the civilian reassignment")
	var timber: Dictionary = model.data.resource_nodes[0]
	model.set_player_position(Vector3(timber.x, 1.0, timber.z))
	for index in 2:
		_check(model.execute("gather", {"node_id":timber.id}).ok, "Gather the real wood used by the reassigned crew's repair")
	var observations := {}
	for id: String in ["severus", "valeria"]:
		_check(model.execute("village_assign", {"resident_id":id, "workplace_id":"woodcamp"}).ok, "A former guard accepts an available civilian job through WorldModel: " + id)
		# Isolate job classification from unrelated fatigue/social breaks. No
		# assignment, construction progress, money or goods are injected here.
		model.data.village.behavior.people[id].fatigue = 0.0
		model.data.village.behavior.people[id].social_need = 0.0
		model.data.village.behavior.people[id].next_decision = 0.0
		var workplace: Vector2 = Life.actor_position(model.data, id)
		observations[id] = {"position":[workplace.x, 0.0, workplace.y], "route_distance":0.0, "route_direction":1}
	model.npc_observations = func() -> Dictionary: return observations
	model.set_player_position(Vector3(0.0, 1.0, 60.0))
	_check(model.execute("village_repair", {"workplace_id":"woodcamp"}, "guard-civilian-repair").ok, "The civilian crew's repair is paid from gathered material")
	var wood_after_payment: int = model.data.resources.wood
	model.advance(0.5)
	for id: String in ["severus", "valeria"]:
		var actor: Dictionary = Behavior.view(model.data, id)
		_check(actor.observed and actor.activity == "work", "Observed former guard now performs civilian work rather than patrol: " + id)
	model.advance(30.0)
	_check(model.data.village.economy.workplaces.woodcamp.condition == 100 and model.data.resources.wood == wood_after_payment, "Two reclassified guards complete only the paid repair, without premature lumber")
	model.advance(30.0)
	_check(model.data.village.economy.workplaces.woodcamp.produced_cycles == 1 and model.data.resources.wood == wood_after_payment + 8, "Their actual civilian work produces one full finite lumber shipment")
	_check(model.data.village.economy.stocks.forest == 232 and model.data.village.economy.people.size() == 14 and model._validate_state(model.data).is_empty(), "Reassignment consumes real forest stock without duplicating people or violating the world ledger")


func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(save_directory)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	for file: String in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute(absolute.path_join(file))
	DirAccess.remove_absolute(absolute)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
