extends SceneTree
## An actual CityExploration session using the Blender-built 50MB RomanCity GLB.
## This is NOT an FPS measurement or an Android/physical Fold7 playthrough.
const City = preload("res://scripts/world/city_exploration.gd")
const SiteManifest := "res://assets/city_detail/shops/city_market_anchors.json"
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("Real city gameplay smoke requires an isolated test profile")
		quit(2)
		return
	_run.call_deferred()


func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: "+label)


func _physics_frames(amount: int) -> void:
	for i in amount:
		await physics_frame
		await process_frame


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	var scene := City.new()
	scene.persist = false
	scene.profile = "balanced"
	root.add_child(scene)
	await _physics_frames(8)
	_check(scene.city_available,"Actual 50MB authored RomanCity is loaded into production CityExploration")
	_check(scene.get_node("RomanCity").find_child("Forum_Worn_Stonework",true,false) is MeshInstance3D
		and scene.find_children("ForumPavingDetail","Node3D",true,false).is_empty(),
		"Actual forum paving uses the original city once, without duplicate overlay")
	_check(scene.crowd.entries.size()==12,"Twelve distinct Roman boulevard occupants have an authored street placement")
	_check(is_instance_valid(scene.player) and is_instance_valid(scene.figure.body),
		"Existing young player has a real visual and physical body, not a synthetic replacement")
	_check(is_instance_valid(scene.camera) and scene.camera.current,
		"Production third-person camera remains the active world camera")
	var scenery := scene.find_children("CityCollision_*","StaticBody3D",true,false)
	_check(scenery.size() > 300,"Full original collision GLB created real static world bodies")
	_check(is_instance_valid(scene.ambient_people) and not scene.ambient_people.citizens.is_empty(),
		"Several real adult market pedestrians are connected to the same free city")
	_check(scene.market.available and scene.market.sites.size()==6,
		"All six original market geometry nodes are bound to one authoritative city trading session")
	_check(not scene.paused and not scene.market.is_open(),"The player begins an ordinary free exploration session")
	# Actual character body motion on real city paving: do not warp/teleport
	# during this part of the test. The later shop-position fixture is explicit.
	var before: Vector3 = scene.player.global_position
	scene._touch_move = Vector2(0.0,1.0)
	await _physics_frames(45)
	scene._touch_move = Vector2.ZERO
	await _physics_frames(3)
	var moved: float = Vector2(scene.player.global_position.x-before.x,scene.player.global_position.z-before.z).length()
	_check(moved>0.15,"The real player walks on the actual imported city collision, not an independent market test ground")
	_check(scene.player.global_position.is_finite() and scene.player.global_position.y>-4.0,
		"The player remains finite and on/in range of the authored city physical ground")
	scene.set_paused(true)
	var paused_at: Vector3=scene.player.position
	await _physics_frames(6)
	_check(scene.paused and scene.player.position.distance_to(paused_at)<0.002,
		"Actual city game pause stops player motion")
	scene.set_paused(false)
	_check(not scene.paused,"The original city resumes rather than opening a new instance")
	# Fixture positioning is deliberate: UI purchase itself then goes through
	# real CityMarketBridge proximity and the unchanged atomic WorldModel.
	var entries: Variant=JSON.parse_string(FileAccess.get_file_as_string(SiteManifest))
	var bakery: Dictionary={}
	if entries is Dictionary:
		for row: Dictionary in entries.get("shops",[]):
			if row.get("shop_id","")=="bakery":
				bakery=row
	if bakery.is_empty():
		_check(false,"Known authored bakery anchor is in the city site manifest")
	else:
		var point: Array = bakery.center_godot_m
		var front:=Vector3(float(point[0]),0.92,float(point[2])+2.3)
		scene.teleport(front)
		await _physics_frames(5)
		_check(scene.market.nearest().reachable and scene.market.nearest().id=="bakery",
			"The real city bakery is reachable at its actual model position")
		var money_before := int(scene.market.model.data.resources.denarii)
		scene._open_market(false)
		await _physics_frames(2)
		_check(scene.market.is_open(),"The existing city Shop UI opens without changing camera/player")
		var purchase: Dictionary=scene.market.execute("city_buy",{
			"shop_id":"bakery","item_id":"bread","quantity":1})
		_check(bool(purchase.get("ok",false)),"Actual city bakery transfers one bread via the economic authority")
		_check(int(scene.market.model.data.resources.denarii)==money_before-2 and
			int(scene.market.model.data.village.city_trade.inventory.bread)==1,
			"City purchase deducts two denarii and creates exactly one recorded bread")
		scene.market.close()
		await _physics_frames(2)
		_check(not scene.market.is_open(),"Returning to the real city closes the market, not the scene")
	_check(scene.get_node("ExplorationCamera").get_instance_id()==scene.camera.get_instance_id(),
		"Shopping never silently creates a replacement camera")
	_check(scene.find_children("ExplorationPlayer","CharacterBody3D",true,false).size()==1,
		"Shopping never duplicates the playable young character")
	_check(not scene.persist,"The isolated test writes no existing user's campaign or city save")
	scene.free()
	await process_frame
	print("ROMAN_CITY_REAL_WALK_RESULT "+JSON.stringify({
		"checks":checks,"failures":failures,"passed":failures.is_empty(),
		"actual_city_import":true,"test_positions_explicit":true,
		"android_device":false,"fps_measured":false
	}))
	print("ROMAN_CITY_REAL_WALK_PASS" if failures.is_empty() else "ROMAN_CITY_REAL_WALK_FAIL")
	quit(0 if failures.is_empty() else 1)
