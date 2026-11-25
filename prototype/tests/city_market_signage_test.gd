extends SceneTree
## Real Godot-node regression of the generated city's six shop nameboards.
## This fixture does not load the 900-m city mesh or certify an Android frame.
const Signs = preload("res://scripts/world/city_market_signage.gd")
const SOURCE := "res://assets/city_detail/shops/city_market_anchors.json"
const EXPECTED_KINDS := {
	"foodstall":0, "bakery":2, "pottery":3,
	"clothier":4, "armorer":5, "thermopolium":6
}
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("Isolated profile is required for this scene test.")
		quit(2)
		return
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: " + message)


func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	_check(parsed is Dictionary, "Anchor manifest is readable as JSON")
	if not parsed is Dictionary:
		quit(1)
		return
	var market: Dictionary = parsed
	_check(market.format == "imperathen-city-market-anchors", "Correct source format")
	_check(not market.authoritative_commerce_enabled, "Signage cannot activate trading")
	_check(market.shops.size() == 6, "Exactly six distinct shop roles")
	var world := Node3D.new()
	world.name = "ExplorationFixture"
	root.add_child(world)
	var city := Node3D.new()
	city.name = "RomanCity"
	world.add_child(city)
	var player := CharacterBody3D.new()
	player.name = "ExplorationPlayer"
	world.add_child(player)
	var camera := Camera3D.new()
	camera.name = "ExplorationCamera"
	world.add_child(camera)
	var originals: Dictionary = {}
	for record: Dictionary in market.shops:
		var shop: String = str(record.shop_id)
		var index := int(record.stall_index_zero)
		var expected_kind := int(EXPECTED_KINDS.get(shop,-1))
		var expected_name := "Market_%02d_Type%d_Build%d_Size%d" % [index+1,index%7,int(index/7)%3,int(index/21)]
		_check(expected_kind == int(record.authored_kind), "Typology matches the catalog: " + shop)
		_check(str(record.stand_node) == expected_name, "Exact generated GLB node: " + shop)
		_check(index % 7 == expected_kind, "Goods geometry agrees with the shop label: " + shop)
		var x := -385.0+float(index)*770.0/62.0
		_check(absf(float(record.center_godot_m[0])-x)<0.00001 and absf(float(record.center_godot_m[2])-47.0)<0.00001,
			"Coordinates match the actual Blender row and Godot axis mapping: " + shop)
		var stand := MeshInstance3D.new()
		stand.name = expected_name
		var box := BoxMesh.new()
		box.size = Vector3(4.0, 3.0, 3.0)
		stand.mesh = box
		stand.position = Vector3(x,0,47)
		stand.set_meta("original_city_asset",true)
		city.add_child(stand)
		originals[shop] = {"id":stand.get_instance_id(), "mesh":box.get_instance_id(), "position":stand.position}
	var installed: Dictionary = Signs.install(city,"balanced")
	_check(installed.ok and installed.signs == 6 and installed.read_only and not installed.trading_enabled,
		"Six shop signs installed with no economy authority")
	_check(world.find_children("*","CharacterBody3D",true,false).size()==1 and
		world.find_children("*","Camera3D",true,false).size()==1,
		"Neither player nor camera is recreated")
	for record: Dictionary in market.shops:
		var shop: String = str(record.shop_id)
		var stand := city.get_node(str(record.stand_node)) as MeshInstance3D
		_check(stand.get_instance_id()==originals[shop].id and stand.mesh.get_instance_id()==originals[shop].mesh and stand.position==originals[shop].position,
			"Original stall mesh, transform and object are untouched: " + shop)
		var sign := stand.get_node_or_null(Signs.GROUP_NAME)
		_check(is_instance_valid(sign), "Standalone sign attached to authored stall: " + shop)
		if is_instance_valid(sign):
			_check(str(sign.get_meta("shop_id",""))==shop and not bool(sign.get_meta("commerce_connected",true)),
				"Semantic shop ID exists with inactive commerce: " + shop)
			var label := sign.get_node("SignText") as Label3D
			var board := sign.get_node("WoodenNameboard") as MeshInstance3D
			_check(label.text==str(record.display_label) and label.visibility_range_end==58.0,
				"Legible label and balanced visibility bound: " + shop)
			_check(board.mesh!=null and board.visibility_range_end==58.0, "Physical wooden signboard: " + shop)
			_check(sign.find_children("*","CollisionObject3D",true,false).is_empty(), "Sign does not obstruct access: " + shop)
	var double_apply: Dictionary = Signs.install(city,"high")
	_check(double_apply.ok and double_apply.removed==6 and double_apply.signs==6, "Idempotent high-profile rebuild")
	var low: Dictionary = Signs.install(city,"low")
	_check(low.ok and low.removed==6 and low.status=="disabled_for_low", "Low profile removes only signage")
	for record: Dictionary in market.shops:
		_check(city.get_node(str(record.stand_node)).get_node_or_null(Signs.GROUP_NAME)==null,
			"No sign nodes remain after low profile: " + str(record.shop_id))
	var occupied := city.get_node(str(market.shops[0].stand_node))
	var stranger := Node3D.new()
	stranger.name = Signs.GROUP_NAME
	occupied.add_child(stranger)
	var conflict: Dictionary = Signs.install(city,"high")
	_check(not conflict.ok and conflict.status=="foreign_sign_conflict", "Foreign node name is protected")
	_check(stranger.get_parent()==occupied, "Foreign content is not deleted")
	occupied.remove_child(stranger)
	stranger.free()
	var missing_node := city.get_node(str(market.shops[1].stand_node))
	city.remove_child(missing_node)
	var missing: Dictionary = Signs.install(city)
	_check(not missing.ok and missing.status=="incomplete_city" and not missing.missing_stalls.is_empty(), "Missing original stand causes no partial installation")
	city.add_child(missing_node)
	_check(not Signs.install(city,"invalid").ok, "Unsupported profile is rejected")
	_check(not Signs.install(world).ok, "Different city hierarchy is never mutated")
	_check(Signs.install(city,"very_high").signs==6, "Complete hierarchy supports highest profile")
	world.free()
	print("CITY_MARKET_SIGNAGE_RESULT checks=%d failures=%d" % [checks,failures.size()])
	print("CITY_MARKET_SIGNAGE_PASS" if failures.is_empty() else "CITY_MARKET_SIGNAGE_FAIL")
	quit(0 if failures.is_empty() else 1)
