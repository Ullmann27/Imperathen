extends SceneTree
## Fixture-only test of the real coordinate/domain/UI connection.
## No claim of a final city walk-through or Android performance.
const Bridge = preload("res://scripts/world/city_market_bridge.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Trade = preload("res://scripts/city_trade.gd")
const Session = preload("res://scripts/world/city_life_session.gd")
const Calendar = preload("res://scripts/domain/world_calendar.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func _run() -> void:
	var campaign = Model.new()
	var saved := JSON.stringify(campaign.data)
	var city := Node3D.new()
	city.name = "RomanCity"
	root.add_child(city)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Bridge.MANIFEST))
	for entry: Dictionary in manifest.shops:
		var stand := MeshInstance3D.new()
		stand.name = str(entry.stand_node)
		stand.mesh = BoxMesh.new()
		city.add_child(stand)
		stand.position = Vector3(float(entry.center_godot_m[0]), float(entry.center_godot_m[1]), float(entry.center_godot_m[2]))
	var player := CharacterBody3D.new()
	root.add_child(player)
	var bridge := Bridge.new()
	root.add_child(bridge)
	var sites: Dictionary = Bridge.verified_sites(city)
	_check(sites.size() == 6, "six actual authored positions resolved")
	_check(bridge.setup(city, player, false), "isolated commerce session created")
	if bridge.available:
		var bakery: Vector3 = sites.bakery
		var initial: int = int(bridge.model.data.resources.denarii)
		bridge.model.set_player_position(Vector3(-10.0, 1.0, -8.0))
		var args := {"shop_id": "bakery", "item_id": "bread", "quantity": 1}
		_check(not bridge.model.execute("city_buy", args).ok, "old miniature district cannot buy in real city")
		_check(not bridge.open_shop(), "cannot open a distant shop")
		player.position = bakery
		var session := Session.new()
		var clock := Calendar.new_clock(Calendar.campaign_start_jdn(), 12 * 3600)
		var ready := session.start(clock, 20261126)
		_check(ready, "city life session starts from the supplied calendar")
		if ready:
			for _slice in range(100):
				if bool(session.sync_to(clock).get("done", false)):
					break
			_check(bool(session.last_sync.get("done", false)), "city simulation reaches supplied clock")
			_check(not session.sync_to(Calendar.new_clock(int(clock.jdn), int(clock.second) - 1)).ok, "clock rollback refused")
			_check(not session.sync_to(Calendar.new_clock(Calendar.first_day_of_year(-57), 0)).ok, "unimplemented era migration refused")
			bridge.persist = true
			_check(not bridge.attach_living_city(session), "separate persistent save is refused")
			bridge.persist = false
			_check(bridge.attach_living_city(session), "QA bridge attaches to city life")
		var business := -1 if not ready else session.life.business_for_shop("bakery")
		_check(business >= 0, "mapped bakery business exists")
		var stock := int(session.life.state.businesses[business].stock.bread) if business >= 0 else -1
		var till := int(session.life.state.businesses[business].till) if business >= 0 else -1
		_check(bridge.open_shop(), "real shop opens at its authored frontage")
		_check(bridge.panel.shop_id == "bakery" and not bridge.panel.pad.visible, "one embedded modal, no extra touch stick")
		_check(bridge.execute("city_buy", args).ok, "buy bread at actual frontage")
		_check(int(bridge.model.data.resources.denarii) == initial - 2, "authoritative debit")
		_check(int(bridge.model.data.village.city_trade.inventory.bread) == 1, "authoritative inventory")
		if business >= 0:
			_check(int(session.life.state.businesses[business].stock.bread) == stock - 1, "city population and player shop share the booked stock movement")
			_check(int(session.life.state.businesses[business].till) == till + 2 * 64, "city cash equals authoritative player debit")
			_check(session.life.audit().ok, "city ledger balances")
		player.position += Vector3(8, 0, 0)
		var before_rejection := JSON.stringify(session.save_state(), "", true)
		_check(not bridge.execute("city_buy", args).ok, "open modal does not bypass proximity")
		_check(JSON.stringify(session.save_state(), "", true) == before_rejection, "failed WorldModel command leaves city simulation unchanged")
		_check(int(bridge.model.data.resources.denarii) == initial - 2, "rejected purchase did not charge")
		player.position = bakery
		_check(bridge.execute("city_sell", args).ok, "sale is booked through the same bridge")
		_check(int(bridge.model.data.resources.denarii) == initial - 1, "sale credits exact catalog price")
		if business >= 0:
			_check(int(session.life.state.businesses[business].stock.bread) == stock, "sale restores simulated stock")
			_check(int(session.life.state.businesses[business].till) == till + 64, "net cash matches purchase and sale")
			_check(session.life.audit().ok, "ledger remains balanced after sale")
		bridge.close()
		_check(bridge.open_inventory(), "inventory opens independently of shop")
		bridge.close()
		_check(JSON.stringify(campaign.data) == saved, "campaign remains untouched")
	var first := city.get_child(0) as Node3D
	first.position.x += 2
	_check(Bridge.verified_sites(city).is_empty(), "moved source node fails closed")
	print("CITY_MARKET_BRIDGE_RESULT checks=%d failures=%d" % [checks, failures])
	print("CITY_MARKET_BRIDGE_PASS" if failures == 0 else "CITY_MARKET_BRIDGE_FAIL")
	quit(0 if failures == 0 else 1)
