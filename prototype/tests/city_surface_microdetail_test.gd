extends SceneTree
## Actual Godot MultiMesh transforms/materials: facade variation without a
## fake second city or an additional collision/navmesh authority.
const Detail = preload("res://scripts/rendering/city_surface_microdetail.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("Isolated model check required.")
		quit(2)
		return
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: " + message)


func _fixture() -> Node3D:
	var world := Node3D.new()
	world.name = "OriginalWorld"
	var city := Node3D.new()
	city.name = "RomanCity"
	world.add_child(city)
	var street := MeshInstance3D.new()
	street.name = "Main_Streets"
	street.mesh = BoxMesh.new()
	city.add_child(street)
	for spec: Array in [
		["Residential_001_insula",Vector3(-12,0,32)],
		["Residential_002_artisan",Vector3(12,0,31)],
		["Residential_003_domus",Vector3(-25,0,58)],
		["Residential_004_atrium",Vector3(28,0,57)],
		["Residential_005_villa",Vector3(8,0,80)],
		["Residential_006_insula",Vector3(15,0,94)],
		["Residential_007_artisan",Vector3(-31,0,102)],
	]:
		var original := MeshInstance3D.new()
		original.name = spec[0]
		original.position = spec[1]
		var shape := BoxMesh.new()
		shape.size = Vector3(16,8,16)
		original.mesh = shape
		city.add_child(original)
	var player := CharacterBody3D.new()
	player.name = "ExistingPlayer"
	world.add_child(player)
	var camera := Camera3D.new()
	camera.name = "OriginalCamera"
	world.add_child(camera)
	var physical := StaticBody3D.new()
	physical.name = "CityCollision_Main_Streets"
	world.add_child(physical)
	return world


func _snapshot(city: Node3D) -> Dictionary:
	var original := {}
	for n: Node in city.find_children("Residential_*","MeshInstance3D",true,false):
		var body := n as MeshInstance3D
		original[str(body.name)] = {"id":body.get_instance_id(),
			"mesh":body.mesh.get_instance_id(),"transform":body.transform}
	var street := city.get_node("Main_Streets") as MeshInstance3D
	original["street"] = {"id":street.get_instance_id(),"mesh":street.mesh.get_instance_id(),"transform":street.transform}
	return original


func _run() -> void:
	_check(not Detail.install(null).ok, "Invalid city is rejected without mutation")
	var world := _fixture()
	root.add_child(world)
	var city := world.get_node("RomanCity") as Node3D
	var original: Dictionary = _snapshot(city)
	_check(not Detail.install(city,"ultra").ok, "Unknown profile does not mutate originals")
	var report := Detail.install(city,"balanced")
	_check(report.ok and report.status=="installed", "Real city fixture accepts microdetail")
	_check(report.houses==6, "Existing compatible facades selected and open villa omitted")
	_check(report.brick_instances>20 and report.plaster_instances==18 and report.wood_instances==18, "Three kinds of varied facade detail have actual instances")
	_check(report.street_instances==60, "Sixty bounded worn paving marks in one batch")
	_check(report.added_colliders==0 and report.replaced_original_meshes==0,"No extra physical obstacles or original mesh replacement")
	var group := city.get_node(Detail.GROUP) as Node3D
	_check(group.get_child_count()==4, "Only four GPU MultiMesh draw groups are created")
	var different_colors: Dictionary = {}
	for visual: MultiMeshInstance3D in group.get_children():
		_check(visual.multimesh!=null and visual.multimesh.instance_count>0, "Each visual batch has a real GPU MultiMesh: "+visual.name)
		_check(visual.visibility_range_end==75.0, "Balanced profile bounds microdetail viewing range")
		_check(visual.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Small details do not generate per-block shadows")
		for index in visual.multimesh.instance_count:
			var t := visual.multimesh.get_instance_transform(index)
			_check(t.origin.is_finite(), "Every detail instance has a finite transform")
			different_colors[str(visual.multimesh.get_instance_color(index))] = true
	print("CITY_SURFACE_COLOR_DIAGNOSTIC count=%d values=%s" % [different_colors.size(),JSON.stringify(different_colors.keys())])
	_check(different_colors.size()>6, "Multiple masonry, plaster and wood color variations are generated")
	_check(_snapshot(city)==original,"Existing building mesh identities and transforms remain unchanged")
	_check(world.find_children("*","CharacterBody3D",true,false).size()==1 and world.find_children("*","Camera3D",true,false).size()==1,
		"Detail work never creates a replacement character or camera")
	_check(world.find_children("*","CollisionObject3D",true,false).size()==2,"No unseen blocking wall is added")
	var high := Detail.install(city,"very_high")
	_check(high.ok and high.houses==6 and city.find_children(Detail.GROUP,"Node3D",true,false).size()==1,"Profile rebuild replaces only its own group")
	_check(_snapshot(city)==original,"LOD update preserves the original buildings")
	var low := Detail.install(city,"low")
	_check(low.ok and low.status=="disabled_for_low" and city.get_node_or_null(Detail.GROUP)==null,"Low profile removes optional details")
	_check(_snapshot(city)==original,"Low mode restores the identical source city")
	var foreign := Node3D.new()
	foreign.name = Detail.GROUP
	city.add_child(foreign)
	var conflicting := Detail.install(city,"high")
	_check(not conflicting.ok and conflicting.status=="foreign_group_conflict" and foreign.get_parent()==city,"Foreign authoring objects are not deleted")
	city.remove_child(foreign)
	foreign.free()
	var street := city.get_node("Main_Streets")
	city.remove_child(street)
	_check(not Detail.install(city).ok and city.get_node_or_null(Detail.GROUP)==null,"Missing original main road fails closed")
	city.add_child(street)
	_check(Detail.install(city,"high").ok,"Normal detail resumes after restoring the road")
	world.free()
	print("CITY_SURFACE_MICRODETAIL_RESULT checks=%d failures=%d" % [checks,failures.size()])
	print("CITY_SURFACE_MICRODETAIL_PASS" if failures.is_empty() else "CITY_SURFACE_MICRODETAIL_FAIL")
	quit(0 if failures.is_empty() else 1)
