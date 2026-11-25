extends SceneTree
## Physical city pedestrian micro-simulation: no new campaign or trader state.
const Ambient = preload("res://scripts/world/city_ambient_people.gd")
const MAP_PATH := "res://assets/city_detail/shops/city_market_anchors.json"
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("Isolated city NPC test requested.")
		quit(2)
		return
	_run.call_deferred()


func _check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		printerr("FAIL: "+description)


func _create_wall(parent: Node3D) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = "ActualStoneHouseWall"
	wall.collision_layer = 1
	wall.position = Vector3(0.60,0.65,0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2,1.3,2.4)
	shape.shape = box
	wall.add_child(shape)
	parent.add_child(wall)
	return wall


func _run() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	_check(data is Dictionary and data.shops.size()==6, "Six authored shop anchors are available")
	if not data is Dictionary:
		quit(1)
		return
	var stage := Node3D.new()
	stage.name = "ActualCityFixture"
	root.add_child(stage)
	var city := Node3D.new()
	city.name = "RomanCity"
	stage.add_child(city)
	var originals := {}
	for item: Dictionary in data.shops:
		var original := MeshInstance3D.new()
		original.name = str(item.stand_node)
		original.mesh = BoxMesh.new()
		original.position = Vector3(float(item.center_godot_m[0]),0.0,float(item.center_godot_m[2]))
		city.add_child(original)
		originals[str(item.stand_node)] = original.get_instance_id()
	var floor := StaticBody3D.new()
	floor.collision_layer = 1
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(120,0.2,80)
	floor_shape.shape = floor_box
	floor.position = Vector3(0,-0.1,48)
	floor.add_child(floor_shape)
	stage.add_child(floor)
	var existing_camera := Camera3D.new()
	existing_camera.current = true
	existing_camera.position = Vector3(0,3,24)
	stage.add_child(existing_camera)
	var layer := Ambient.new()
	stage.add_child(layer)
	_check(not layer.setup(city,existing_camera,"unknown").ok,"Unknown profile is a non-mutating error")
	var report: Dictionary = layer.setup(city,existing_camera,"balanced")
	_check(report.ok and report.merchants==2 and report.visitors==2 and report.actors==4,
		"Balanced mode creates precisely two merchant/visitor pairs")
	_check(not report.transaction_authority and not report.campaign_changed,
		"Ambient visitors do not claim money or game-state authority")
	_check(layer.citizens.size()==2,"Two independent behavior timelines exist")
	for record: Dictionary in layer.citizens:
		_check(is_instance_valid(record.vendor) and is_instance_valid(record.customer),
			"Both actually instantiated characters exist")
		_check((record.customer as CharacterBody3D).collision_mask==1,
			"Mobile person uses actual scenery collision, not teleports")
		_check((record.vendor as Node3D).has_node("Figure") and (record.customer as Node3D).has_node("Figure"),
			"Every citizen uses an actual rigged visual character")
	var first := layer.citizens[0] as Dictionary
	var walker := first.customer as CharacterBody3D
	var start: Vector3 = walker.position
	for tick in 70:
		await physics_frame
	_check(Vector2(walker.position.x-start.x,walker.position.z-start.z).length()>0.25,
		"A real strolling citizen moves during the first phase")
	_check(walker.get_node("Figure").speed <= 1.25,
		"Pedestrian animation speed follows the bounded actual body velocity")
	layer.set_active(false)
	var stopped := walker.position
	for tick in 12:
		await physics_frame
	_check(walker.position.distance_to(stopped)<0.002,
		"Pause really stops the citizen instead of only hiding animation")
	layer.set_active(true)
	_check(layer._clear_speech_line(Vector3(0,0,0),Vector3(1.2,0,0)),
		"Actual clear sidewalk permits face-to-face speech within 1.5m")
	var blocker := _create_wall(stage)
	await physics_frame
	await physics_frame
	_check(not layer._clear_speech_line(Vector3(0,0,0),Vector3(1.2,0,0)),
		"A real 1.3m wall blocks both residents despite eye-level visibility")
	blocker.free()
	await physics_frame
	await physics_frame
	_check(layer._clear_speech_line(Vector3(0,0,0),Vector3(1.2,0,0)),
		"Speech can resume once the obstacle is physically removed")
	_check(not layer._clear_speech_line(Vector3(0,0,0),Vector3(3.5,0,0)),
		"A distant citizen is never a conversation partner")
	var low: Dictionary = layer.setup(city,existing_camera,"low")
	_check(low.ok and layer.citizens.is_empty(),"Low mode unloads optional city visitors")
	var high: Dictionary = layer.setup(city,existing_camera,"high")
	_check(high.ok and high.actors==8,"High mode has exactly four bounded pairs")
	_check(stage.find_children("*","Camera3D",true,false).size()==1,
		"Existing city camera remains the only camera")
	for item: Dictionary in data.shops:
		var node := city.get_node(str(item.stand_node))
		_check(node.get_instance_id()==originals[str(item.stand_node)],
			"Original authored building remains untouched: "+str(item.shop_id))
	layer.free()
	stage.free()
	print("CITY_AMBIENT_PEOPLE_RESULT checks=%d failures=%d" % [checks,failures.size()])
	print("CITY_AMBIENT_PEOPLE_PASS" if failures.is_empty() else "CITY_AMBIENT_PEOPLE_FAIL")
	quit(0 if failures.is_empty() else 1)
