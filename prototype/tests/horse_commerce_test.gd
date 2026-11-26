extends SceneTree
## Commands run through WorldModel. Positions and long calendar passages are
## test inputs; no model, movement, or city rendering is exercised here.

const Model = preload("res://scripts/domain/world_model.gd")
const Trade = preload("res://scripts/city_trade.gd")
const Catalog = preload("res://scripts/city_trade_catalog.gd")
const Calendar = preload("res://scripts/domain/world_calendar.gd")
const Era = preload("res://scripts/domain/era_registry.gd")
const STABLE_AT := Vector3(14.0, 1.0, 12.0)
const STABLE := Catalog.STABLE_ID
const PACK_MARE := "horse_fara"
const ROAD_HORSE := "horse_silex"
const COURIER_HORSE := "horse_iuba"
const HALTER := "halter_leather"
var checks := 0
var failures: Array[String] = []
var directory := "user://horse_commerce_%s" % Time.get_ticks_usec()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_test_start_and_site()
	_test_purchase_and_reload()
	_test_previous_save()
	_test_progress_and_era()
	for message: String in failures:
		printerr("FAIL: " + message)
	print("HORSE_COMMERCE_%s %d checks, %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _new(childhood := false) -> Model:
	var model := Model.new()
	model.new_game("italia", true, childhood, false, childhood)
	_check(model.execute("city_trade_enable").ok, "Enable existing market")
	model.city_trade_sites = {STABLE: STABLE_AT}
	model.set_player_position(STABLE_AT)
	return model


func _adult() -> Model:
	var model := _new()
	_check(model.pass_calendar_days(2195, "Test einer erwachsenen Handelsphase", "wait").ok, "Age through the actual world clock")
	_check(model.data.player.age == 18, "Adult fixture is eighteen")
	return model


func _offer(model: Model, id: String) -> Dictionary:
	for offer: Dictionary in Trade.view(model.data, STABLE, model.city_trade_sites).offers:
		if offer.item_id == id:
			return offer
	return {}


func _trade(model: Model, command: String, id: String, quantity := 1, command_id := "") -> Dictionary:
	return model.execute(command, {"shop_id":STABLE, "item_id":id, "quantity":quantity}, command_id)


func _test_start_and_site() -> void:
	var child := _new(true)
	_check(child.data.player.age == 12 and child.data.resources.denarii == 0, "Regular childhood starts at twelve with no money")
	var before := JSON.stringify(child.data)
	_check(not _trade(child, "city_buy", PACK_MARE).ok and JSON.stringify(child.data) == before, "A child cannot buy a horse")
	_check(not _offer(child, PACK_MARE).can_buy and str(_offer(child, PACK_MARE).reason).contains("Erwachsenenweg"), "The same age condition reaches the offer")
	_check(child.data.village.childhood.completed.is_empty() and Trade.selected_horse(child.data).is_empty(), "Market enablement grants no property or story progress")
	_check(Trade.shop_catalog().size() == 6 and Trade.shop_catalog(true).size() == 7, "Six existing stands stay required")
	var adult := _adult()
	adult.city_trade_sites.clear()
	before = JSON.stringify(adult.data)
	_check(not _trade(adult, "city_buy", PACK_MARE).ok and JSON.stringify(adult.data) == before, "No fallback teleport or mail-order stable")
	_check(not _offer(adult, PACK_MARE).can_buy, "Unregistered stable cannot offer purchases")
	adult.city_trade_sites = {STABLE: Vector3(INF, 1.0, 0.0)}
	_check(not _trade(adult, "city_buy", PACK_MARE).ok and JSON.stringify(adult.data) == before, "Reject non-finite anchor")
	adult.city_trade_sites = {STABLE: STABLE_AT}
	adult.set_player_position(STABLE_AT + Vector3(0.0, 0.0, 3.1))
	before = JSON.stringify(adult.data)
	_check(not _trade(adult, "city_buy", PACK_MARE).ok and JSON.stringify(adult.data) == before, "Reject remote order through the existing reach check")


func _test_purchase_and_reload() -> void:
	var model := _adult()
	var money: int = model.data.resources.denarii
	var treasury: int = model.data.village.economy.stocks.merchant_denarii
	var date := model.world_time()
	var offer := _offer(model, PACK_MARE)
	var uid := str(offer.horse.uid)
	var before := JSON.stringify(model.data)
	_check(offer.can_buy and offer.stock == 1 and offer.price <= money and not uid.is_empty(), "One affordable individual is available")
	_check(not _trade(model, "city_buy", PACK_MARE, 2).ok and JSON.stringify(model.data) == before, "One stable individual cannot be bought twice")
	var first := _trade(model, "city_buy", PACK_MARE, 1, "stock-individual-fara")
	_check(first.ok, "Buy through the existing WorldModel command")
	_check(model.data.resources.denarii == money - offer.price and model.data.village.economy.stocks.merchant_denarii == treasury + offer.price, "One payment reaches the real shared treasury")
	_check(int(model.world_time().second) - int(date.second) == 1800, "The existing trade time is booked once")
	_check(_offer(model, PACK_MARE).stock == 0 and model.data.village.city_trade.inventory[PACK_MARE] == 1, "One horse changes ownership and leaves offer stock")
	before = JSON.stringify(model.data)
	_check(_trade(model, "city_buy", PACK_MARE, 1, "stock-individual-fara") == first and JSON.stringify(model.data) == before, "Replay is byte-for-byte idempotent")
	_check(not _trade(model, "city_buy", PACK_MARE).ok and JSON.stringify(model.data) == before, "New ID still cannot duplicate the horse")
	_check(_trade(model, "city_buy", HALTER).ok, "Buy actual horse tack via generic ledger")
	before = JSON.stringify(model.data)
	_check(not _trade(model, "city_buy", HALTER, 2).ok and JSON.stringify(model.data) == before, "An in-stock order still requires enough denarii")
	_check(not model.execute("city_equip", {"item_id": HALTER}).ok, "An unselected horse cannot wear tack")
	_check(model.execute("city_equip", {"item_id": PACK_MARE}).ok and Trade.selected_horse(model.data).uid == uid, "Selected horse refers to the same stock identity")
	_check(model.execute("city_equip", {"item_id": HALTER}).ok and Trade.selected_horse(model.data).tack.item_id == HALTER, "Owned tack is visible on the selected horse record")
	before = JSON.stringify(model.data)
	_check(not _trade(model, "city_sell", PACK_MARE).ok and JSON.stringify(model.data) == before, "Put selected horse away before resale")
	_check(model.save_game(directory.path_join("horse.json")).ok, "Save populated market")
	var loaded := Model.new()
	_check(loaded.load_game(directory.path_join("horse.json")).ok, "Load populated market")
	loaded.city_trade_sites = {STABLE: STABLE_AT}
	_check(Trade.selected_horse(loaded.data) == Trade.selected_horse(model.data), "Save preserves horse identity and tack")
	before = JSON.stringify(loaded.data)
	_check(_trade(loaded, "city_buy", PACK_MARE, 1, "stock-individual-fara").ok and JSON.stringify(loaded.data) == before, "Transport replay still works after load")
	_check(loaded.execute("city_equip", {"item_id": PACK_MARE}).ok and Trade.selected_horse(loaded.data).is_empty(), "Put horse and tack away")
	_check(_trade(loaded, "city_sell", PACK_MARE).ok and _offer(loaded, PACK_MARE).horse.uid == uid, "Brought back to trader with same ID")
	before = JSON.stringify(loaded.data)
	_check(not _trade(loaded, "city_buy", COURIER_HORSE).ok and JSON.stringify(loaded.data) == before, "No premium horse without career proof")
	loaded.data.village.city_trade.sales[STABLE][PACK_MARE] += 1
	_check(not loaded._validate_state(loaded.data).is_empty(), "A fabricated second copy in merchant stock is rejected")


func _test_previous_save() -> void:
	var model := _adult()
	var site: Array = Catalog.SHOPS.pottery.position
	model.city_trade_sites.clear()
	model.set_player_position(Vector3(site[0], 1.0, site[1]))
	_check(model.execute("city_buy", {"shop_id":"pottery", "item_id":"oil_lamp", "quantity":1}).ok, "Legacy market sample owns a paid lamp")
	var data: Dictionary = model.data.duplicate(true)
	var trade: Dictionary = data.village.city_trade
	for id: String in Catalog.STABLE_ITEMS:
		trade.inventory.erase(id)
		trade.used.erase(id)
	trade.sales.erase(STABLE)
	trade.purchases.erase(STABLE)
	trade.equipment.erase("mount")
	trade.equipment.erase("tack")
	trade.version = 1
	var payload := JSON.stringify(data, "", true, true)
	var file := FileAccess.open(directory.path_join("v1.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"format": Model.SAVE_FORMAT, "format_version": 1, "payload": payload, "sha256": payload.sha256_text()}))
	file.close()
	var loaded := Model.new()
	_check(loaded.load_game(directory.path_join("v1.json")).ok, "Load a historical market with the v1 shape")
	_check(loaded.data.village.city_trade.version == 2 and loaded.data.village.city_trade.inventory.oil_lamp == 1, "Preserve original trade entries and add v2 entries")
	_check(loaded.data.resources == model.data.resources and loaded.data.calendar == model.data.calendar and Trade.selected_horse(loaded.data).is_empty(), "Migration changes no money, time or owned mount")


func _test_progress_and_era() -> void:
	var model := _adult()
	var basic := _offer(model, PACK_MARE)
	var road := _offer(model, ROAD_HORSE)
	var elite := _offer(model, COURIER_HORSE)
	_check(basic.price < road.price and road.price < elite.price and basic.horse.pace < road.horse.pace and road.horse.pace < elite.horse.pace, "Price and performance increase together")
	_check(basic.horse.handling > elite.horse.handling, "The faster horse still demands more confident handling")
	_check(not road.can_buy and str(road.reason).contains("Versorgungslieferung") and not elite.can_buy, "Trade gives a reason for progression locks")
	# Isolate the evaluator from full mission playback and from affordability.
	var adult: Dictionary = model.data.duplicate(true)
	var road_item: Dictionary = Catalog.ITEMS[ROAD_HORSE]
	var elite_item: Dictionary = Catalog.ITEMS[COURIER_HORSE]
	adult.frontier.completed = true
	_check(Trade._purchase_access_reason(adult, road_item).is_empty() and str(Trade._purchase_access_reason(adult, elite_item)).contains("verteidigt"), "A confirmed delivery opens the travel class only")
	adult.village.raid.won = 1
	_check(Trade._purchase_access_reason(adult, elite_item).is_empty(), "Delivery plus defense opens the courier class")
	var want := str(road_item.era)
	_check(not Era.available(want, Calendar.to_jdn(-59, 12, 31)) and Era.available(want, Calendar.to_jdn(-58, 1, 1)), "The fictional roster obeys the campaign epoch boundary")
	adult.calendar.clock = Calendar.new_clock(Calendar.to_jdn(-59, 12, 31), 0)
	_check(str(Trade._purchase_access_reason(adult, road_item)).contains("Epoche"), "The purchase rules read the date, not platform time")
