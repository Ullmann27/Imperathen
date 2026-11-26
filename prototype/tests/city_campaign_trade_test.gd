extends SceneTree

const Model := preload("res://scripts/domain/world_model.gd")
const Session := preload("res://scripts/world/city_life_session.gd")
const Checkpoint := preload("res://scripts/domain/city_checkpoint.gd")
const Calendar := preload("res://scripts/domain/world_calendar.gd")
const Sites := {"bakery": Vector3(88, 1, -30)}
const Bread := {"shop_id": "bakery", "item_id": "bread", "quantity": 1}
var path: String
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func _ready_city(session: Session, clock: Dictionary) -> bool:
	for _slice in 30000:
		var status := session.sync_to(clock)
		if not status.ok or status.done:
			return bool(status.ok) and bool(status.done)
	return false

func _run() -> void:
	path = OS.get_temp_dir().path_join("imperathen-iii-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()])
	var model := Model.new()
	model.new_game("italia", true, true)
	var origin: Array = model.data.player.position.duplicate()
	var household_cash: int = model.data.village.economy.stocks.merchant_denarii
	var start_cash: int = model.data.resources.denarii
	_check(model.advance_city_visit(6 * 3600).ok, "Weltuhr auf Mittag fortgeschrieben")
	var session := Session.new()
	_check(session.open_campaign(model.data, Callable()), "Bevölkerung auf der Kampagnenuhr gegründet")
	_check(_ready_city(session, model.data.calendar.clock), "Gründung abgeschlossen")
	_check(not session.quote("bakery", "bread").reason.is_empty(), "Unbesetzter Brotstand ist gesperrt")
	_check(model.execute_city_at("city_trade_enable", {}, "", session, Sites, Sites.bakery, path).ok, "Stadt und Inventar im gemeinsamen Save aktiviert")
	_check(FileAccess.file_exists(path), "Kampagnenspeicher existiert")
	_check(model.advance_city_visit(1500).ok and _ready_city(session, model.data.calendar.clock), "Anwohner erreichen auf gemeinsamen Kalender den Arbeitsplatz")
	var quote := session.quote("bakery", "bread")
	_check(quote.reason.is_empty(), "Bäcker bedient vor Ort: " + str(quote))
	var biz := session.life.business_for_shop("bakery")
	var stock: int = session.life.state.businesses[biz].stock.bread
	var till: int = session.life.state.businesses[biz].till
	var inactive := Session.new()
	_check(inactive.open_campaign(model.data, Callable()), "Zweite Sitzung liest vorherige Generation")
	_check(not model.execute_city_at("city_buy", Bread, "far", session, Sites, Vector3.ZERO, path).ok, "Entfernte Figur kann nicht kaufen")
	var broken := path.path_join("unwritable")
	var before: int = session.generation
	var failed := model.execute_city_at("city_buy", Bread, "receipt", session, Sites, Sites.bakery, broken)
	_check(not failed.ok and session.generation == before and not model.data.command_log.has("receipt"), "Schreibfehler verbraucht weder Generation noch Befehlskennung")
	_check(model.data.resources.denarii == start_cash and session.life.state.businesses[biz].stock.bread == stock and session.life.state.businesses[biz].till == till, "Schreibfehler verändert keine Kasse und keinen Vorrat")
	var bought := model.execute_city_at("city_buy", Bread, "receipt", session, Sites, Sites.bakery, path)
	_check(bought.ok, "Kauf gilt nach atomarem Schreiben: " + str(bought))
	_check(model.data.player.position == origin, "Marktkoordinaten verändern Dorfrückkehrposition nicht")
	_check(int(model.data.resources.denarii) == start_cash - 2 and int(model.data.village.city_trade.inventory.bread) == 1, "Ein Brot gegen zwei Denare")
	_check(int(session.life.state.businesses[biz].stock.bread) == stock - 1 and int(session.life.state.businesses[biz].till) == till + 128, "Stadtbetrieb erhält exakt 128 Quadranten")
	_check(int(model.data.village.economy.stocks.merchant_denarii) == household_cash, "Dorfkasse erhält keine zusätzliche Zahlung")
	_check(session.life.audit().ok, "Stadtbilanz stimmt")
	_check(not model.checkpoint_city(inactive, path).ok, "Veraltete Stadtsitzung darf Kauf nicht überschreiben")
	var reloaded := Model.new()
	_check(reloaded.load_game(path).ok, "Welt, Geld und Inventar im selben Neustart geladen")
	var resumed := Session.new()
	_check(resumed.open_campaign(reloaded.data, Callable()), "Haushalte und Betriebe aus Kampagnenslot wiederhergestellt")
	_check(resumed.life.state.businesses[biz].till == till + 128 and resumed.life.state.businesses[biz].stock.bread == stock - 1, "Bäcker hat nach Neustart denselben Bestand und dieselbe Kasse")
	_check(reloaded.execute_city_at("city_buy", Bread, "receipt", resumed, Sites, Sites.bakery, path) == bought, "Wiederholte Kennung liefert gespeicherten Beleg")
	_check(reloaded.data.village.city_trade.inventory.bread == 1, "Wiederholung vergibt kein zweites Brot")
	_check(not reloaded.execute_city_at("city_sell", Bread, "receipt", resumed, Sites, Sites.bakery, path).ok, "Widersprüchliche Kennung gesperrt")
	_check(_ready_city(resumed, reloaded.data.calendar.clock), "Nach dem Laden werden die 30 Handelsminuten aufgeholt")
	var sale_quote := resumed.quote("bakery", "bread")
	_check(sale_quote.reason.is_empty(), "Stand nach Wiederaufnahme besetzt")
	var sold := reloaded.execute_city_at("city_sell", Bread, "sell", resumed, Sites, Sites.bakery, path)
	_check(sold.ok and reloaded.data.resources.denarii == start_cash - 1 and reloaded.data.village.city_trade.inventory.bread == 0, "Verkauf über dieselbe Waren- und Geldbilanz")
	_check(reloaded.data.village.economy.stocks.merchant_denarii == household_cash and resumed.life.audit().ok, "Verkauf verändert nur den Stadtbetrieb")
	_check(not reloaded.execute("city_buy", Bread).ok, "Entfernter Sandbox-Befehl kann die Betriebsprüfung nicht umgehen")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("beschädigt")
	file.close()
	var recovery := Model.new()
	_check(recovery.load_game(path).get("recovered_backup", false), "Defekter Hauptslot fällt auf vollständigen vorherigen Stand zurück")
	_check(recovery.data.village.city_trade.inventory.bread == 1 and recovery.data.resources.denarii == start_cash - 2, "Sicherung stellt Spieler und Transaktion zusammen wieder her")
	var recovered_city := Session.new()
	_check(recovered_city.open_campaign(recovery.data, Callable()) and recovered_city.life.state.businesses[biz].stock.bread == stock - 1, "Betrieb im Sicherungsstand passt zur Ware")
	var pack: Dictionary = recovery.data.world_state.city
	print("CITY_SAVE compressed_base64_bytes=%d json_city_bytes=%d people=%d businesses=%d purchase_denarii=2 paid_quadrantes=128" % [str(pack.zstd).length(), int(pack.bytes), session.life.state.residents.size(), session.life.state.businesses.size()])
	# Carry pre-integration receipts forward without booking old cash into the
	# new city's till, and reject a city snapshot spliced from a different trade.
	var forged: Dictionary = recovered_city.life.save_state()
	forged.external.player += 64
	forged.external.hinterland -= 64
	var original: Dictionary = recovery.data.world_state.city
	recovery.data.world_state.city = Checkpoint.pack_city(forged, 99, recovered_city.opening_trade_balance)
	_check(not recovery.save_game(path).ok, "Eine fremde Stadtbuchung scheitert auch bei ausgeglichener Gesamtgeldmenge")
	recovery.data.world_state.city = original
	forged = recovered_city.life.save_state()
	forged.businesses[biz].stock.bread += 1
	_check(not Session.Life.validate(forged).is_empty(), "Ungedeckte Warenmenge wird bei der Wiederherstellung erkannt")
	var legacy := Model.new()
	legacy.new_game("italia", true, true)
	legacy.execute("city_trade_enable")
	legacy.set_player_position(Vector3(-10, 1, -8))
	_check(legacy.execute("city_buy", Bread).ok, "Vorhandene ältere römische Marktbuchung")
	var migrated := Session.new()
	_check(migrated.open_campaign(legacy.data, Callable()) and migrated.opening_trade_balance == -2, "Alter Kauf wird als Eröffnungsbilanz übernommen")
	_check(legacy.checkpoint_city(migrated, path).ok and migrated.life.state.external.player == 0 and legacy.data.village.city_trade.inventory.bread == 1, "Altkauf weder erneut berechnet noch verschenkt")
	# Close one year on a two-second boundary so the test needs no fictitious
	# full-year fast-forward. This exercises the campaign-only migration path.
	var crossing := Session.new()
	crossing.world_id = "year-fixture"
	var last := Calendar.new_clock(Calendar.to_jdn(-1, 12, 31), 86398)
	var next := Calendar.advance_clock(last, 5)
	_check(crossing.start(last, 20261126) and _ready_city(crossing, last), "Stadt vor Jahreswechsel gegründet")
	var member_name: String = crossing.life.state.residents[10].name
	var birth_year: int = crossing.life.state.residents[10].birth_year
	var count: int = crossing.life.state.residents.size()
	_check(_ready_city(crossing, next) and crossing.life.year == 1 and crossing.life.clock() == next, "Gemeinsamer Kalender von 1 v. Chr. nach 1 n. Chr.")
	_check(crossing.life.state.residents.size() == count and crossing.life.state.residents[10].name == member_name and crossing.life.state.residents[10].birth_year == birth_year and crossing.life.audit().ok, "Bevölkerung, Geburtsjahr und Bilanz bleiben über den Jahreswechsel erhalten")
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("CITY_CAMPAIGN_TRADE_RESULT checks=%d failures=%d" % [checks, failures])
	print("CITY_CAMPAIGN_TRADE_PASS" if failures == 0 else "CITY_CAMPAIGN_TRADE_FAIL")
	quit(0 if failures == 0 else 1)
