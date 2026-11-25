extends SceneTree
## The actual original VIVA-3D props must attach to authored city meshes
## without adding physics, replacing architecture, or changing economic state.
const Decor := preload("res://scripts/rendering/city_viva_closeup_props.gd")
const NAMES := ["Pistrinum_Bakery","Fabrica_Blacksmith","Mercator_Store","Market_34_Type5_Build1_Size1"]
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST")!="1":
		printerr("Use an isolated test account.")
		quit(2)
		return
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: "+message)


func _snapshot(city: Node3D) -> Dictionary:
	var original := {}
	for shop: String in NAMES:
		var node := city.find_child(shop,true,false) as MeshInstance3D
		original[shop]={"instance_id":node.get_instance_id(),
			"mesh_id":node.mesh.get_instance_id(),"transform":node.transform}
	return original


func _run() -> void:
	_check(not Decor.install(null).ok,"Invalid city is not modified")
	var world := Node3D.new()
	root.add_child(world)
	var city := Node3D.new()
	city.name = "RomanCity"
	world.add_child(city)
	for i: int in NAMES.size():
		var item := MeshInstance3D.new()
		item.name = NAMES[i]
		item.mesh = BoxMesh.new()
		item.position = Vector3(float(i)*8.0,0.0,47.0)
		city.add_child(item)
	var player := CharacterBody3D.new()
	world.add_child(player)
	var camera := Camera3D.new()
	world.add_child(camera)
	var collision := StaticBody3D.new()
	collision.collision_layer = 1
	world.add_child(collision)
	var originals := _snapshot(city)
	var high: Dictionary = Decor.install(city,"high")
	_check(high.ok and high.portals==3 and high.helmets==1 and high.loaded_lod==0,
		"High connects three existing detailed portals and one genuine bronze helmet")
	_check(high.colliders_added==0 and high.originals_modified==0,
		"High installs visual assets, never new gameplay physics")
	var group := city.get_node_or_null(Decor.ROOT_NAME)
	_check(is_instance_valid(group) and group.get_child_count()==4,
		"High uses four shared existing 3D asset anchors")
	if is_instance_valid(group):
		for anchor: Node3D in group.get_children():
			_check(anchor.get_child_count()==1,"One original VIVA asset per anchor")
			var instance := anchor.get_child(0) as Node3D
			_check(instance.find_children("*","MeshInstance3D",true,false).size()>=1,
				"Packed GLB contains authored triangles: "+str(instance.name))
			_check(instance.find_children("*","CollisionObject3D",true,false).is_empty(),
				"Closeup mesh has no hidden physics obstacles: "+str(instance.name))
	_check(_snapshot(city)==originals,"Original city meshes, transforms and IDs remain unchanged")
	_check(world.find_children("*","Camera3D",true,false).size()==1
		and world.find_children("*","CharacterBody3D",true,false).size()==1,
		"Visual attachment does not create another player or camera")
	var balanced: Dictionary = Decor.install(city,"balanced")
	_check(balanced.ok and balanced.loaded_lod==1 and balanced.portals==3 and balanced.helmets==1,
		"Balanced switches only closeup models to economical LOD1")
	_check(city.find_children(Decor.ROOT_NAME,"Node3D",true,false).size()==1,
		"Revisiting the same scene never duplicates closeup assets")
	var low: Dictionary = Decor.install(city,"low")
	_check(low.ok and low.status=="disabled_low" and city.get_node_or_null(Decor.ROOT_NAME)==null,
		"Low profile removes the optional closeup geometry")
	_check(_snapshot(city)==originals,"Low profile preserves authored buildings")
	var foreign := Node3D.new()
	foreign.name = Decor.ROOT_NAME
	city.add_child(foreign)
	_check(not Decor.install(city,"high").ok and foreign.get_parent()==city,
		"Foreign artist-owned nodes cannot be deleted during installation")
	city.remove_child(foreign)
	foreign.free()
	var missing := city.find_child(NAMES[2],true,false)
	city.remove_child(missing)
	_check(not Decor.install(city,"high").ok and city.get_node_or_null(Decor.ROOT_NAME)==null,
		"Missing original shop fails closed without a half-installed visual package")
	city.add_child(missing)
	_check(Decor.install(city,"very_high").ok,"Very High restores the actual high-poly originals")
	_check(_snapshot(city)==originals,"Final high-detail state does not modify underlying city")
	world.free()
	print("CITY_VIVA_PROPS_RESULT checks=%d failures=%d" % [checks,failures.size()])
	print("CITY_VIVA_PROPS_PASS" if failures.is_empty() else "CITY_VIVA_PROPS_FAIL")
	quit(0 if failures.is_empty() else 1)
