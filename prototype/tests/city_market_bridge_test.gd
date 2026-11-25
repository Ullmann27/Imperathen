extends SceneTree
## Fixture-only test of the real coordinate/domain/UI connection.
## No claim of a final city walk-through or Android performance.
const Bridge = preload("res://scripts/world/city_market_bridge.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Trade = preload("res://scripts/city_trade.gd")
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
		_check(bridge.open_shop(), "real shop opens at its authored frontage")
		_check(bridge.panel.shop_id == "bakery" and not bridge.panel.pad.visible, "one embedded modal, no extra touch stick")
		_check(bridge.execute("city_buy", args).ok, "buy bread at actual frontage")
		_check(int(bridge.model.data.resources.denarii) == initial - 2, "authoritative debit")
		_check(int(bridge.model.data.village.city_trade.inventory.bread) == 1, "authoritative inventory")
		player.position += Vector3(8, 0, 0)
		_check(not bridge.execute("city_buy", args).ok, "open modal does not bypass proximity")
		_check(int(bridge.model.data.resources.denarii) == initial - 2, "rejected purchase did not charge")
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
