extends SceneTree
## Minimal observed hierarchy; never loads the large city GLBs or campaign.
const Adapter := preload("res://scripts/rendering/city_exploration_detail_adapter.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func verify(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _fixture() -> Node3D:
	var world := Node3D.new()
	world.name = "ExistingExploration"
	world.set_meta("campaign_sentinel", {"money": 41, "quest": "unchanged"})
	var city := Node3D.new()
	city.name = "RomanCity"
	world.add_child(city)
	for specification: Array in [
		["Main_Streets", Vector3.ZERO],
		["Market_32_Type3_Build1_Size1", Vector3(0, 0, 47)],
		["Market_35_Type6_Build1_Size1", Vector3(37.258064516, 0, 47)],
	]:
		var model := MeshInstance3D.new()
		model.name = specification[0]
		model.position = specification[1]
		model.mesh = BoxMesh.new()
		model.set_meta("original_city_asset", true)
		city.add_child(model)
	var temple := Node3D.new()
	temple.name = "MeshyTemple"
	temple.position = Vector3(0, 0, -55)
	world.add_child(temple)
	var player := CharacterBody3D.new()
	player.name = "ExplorationPlayer"
	player.position = Vector3(0, 0.92, 24)
	player.collision_layer = 2
	player.collision_mask = 1
	world.add_child(player)
	var camera := Camera3D.new()
	camera.name = "ExplorationCamera"
	camera.position = Vector3(0, 2, 28)
	world.add_child(camera)
	var original_floor := StaticBody3D.new()
	original_floor.name = "CityCollision_Main_Streets"
	original_floor.collision_layer = 1
	original_floor.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(835, 0.11, 14)
	collision.shape = shape
	collision.position = Vector3(0, 0.055, 65)
	original_floor.add_child(collision)
	world.add_child(original_floor)
	return world


func _original_snapshot(world: Node3D) -> Dictionary:
	var result := {"campaign": world.get_meta("campaign_sentinel").duplicate(true)}
	for node_name in ["Main_Streets", "Market_32_Type3_Build1_Size1", "Market_35_Type6_Build1_Size1", "MeshyTemple", "ExplorationPlayer", "ExplorationCamera", "CityCollision_Main_Streets"]:
		var original := world.find_child(node_name, true, false) as Node3D
		result[node_name] = {
			"id": original.get_instance_id(), "parent": original.get_parent().get_instance_id(),
			"transform": original.transform, "meta": original.get_meta_list(),
		}
		if original is MeshInstance3D:
			result[node_name].mesh = original.mesh.get_instance_id()
	return result


func _owned_count(world: Node) -> int:
	var count := 0
	for node in world.find_children("*", "Node3D", true, false):
		if node.get_meta(Adapter.OWNER_META, 0) == Adapter.OWNER_VERSION:
			count += 1
	return count


func _ray_height(world: Node3D, x: float, z: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 1, z), Vector3(x, -0.2, z), 1)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	return (hit.get("position", Vector3(0, -99, 0)) as Vector3).y


func _collision_signature(world: Node3D) -> Array[String]:
	var entries: Array[String] = []
	for node in world.find_children("*", "CollisionShape3D", true, false):
		var shape := node as CollisionShape3D
		var cursor: Node = shape
		while cursor != null and cursor != world:
			if cursor.get_meta(Adapter.OWNER_META, 0) == Adapter.OWNER_VERSION:
				var box := shape.shape as BoxShape3D
				if box != null:
					entries.append(str(shape.global_transform) + "|" + str(box.size))
				break
			cursor = cursor.get_parent()
	entries.sort()
	return entries


func _run() -> void:
	var invalid := Adapter.install(null)
	verify(not invalid.ok and invalid.status == "unsupported_city", "Null city is an explicit no-op")
	var world := _fixture()
	root.add_child(world)
	var city := world.get_node("RomanCity") as Node3D
	var original := _original_snapshot(world)
	var report := Adapter.install(city, "balanced")
	verify(report.ok and report.status == "installed", "Observed city hierarchy accepts adapter")
	verify(report.created_groups == 3 and _owned_count(world) == 3, "Exactly three owned groups are created")
	verify(report.paving_instances == 15 and report.local_collision_bodies == 3, "Report describes the bounded addition")
	var street_group := city.get_node(Adapter.GROUP_NAME) as Node3D
	var batches := street_group.find_children("*", "MultiMeshInstance3D", true, false)
	verify(batches.size() == 1, "Fifteen stones modules use one MultiMesh")
	var batch := batches[0] as MultiMeshInstance3D
	verify(batch.multimesh.instance_count == 15, "MultiMesh has exactly fifteen instances")
	verify(batch.visibility_range_end == 75.0, "Balanced detail has a bounded viewing range")
	var surface := street_group.get_node("LocalStreetSurface/SurfaceBox") as CollisionShape3D
	var box := surface.shape as BoxShape3D
	verify(box.size.is_equal_approx(Vector3(20, 0.02, 12)), "One simple collider covers the exact paving footprint")
	verify(is_equal_approx(surface.position.y + box.size.y * 0.5, 0.115), "Visual nominal top and physical top agree")
	var pottery := city.get_node(Adapter.POTTERY_NAME) as Node3D
	var food := city.get_node(Adapter.FOOD_NAME) as Node3D
	var amphorae := pottery.get_node(Adapter.GROUP_NAME + "/amphora_pair") as Node3D
	var counter := food.get_node(Adapter.GROUP_NAME + "/dolia_counter") as Node3D
	verify(amphorae.position == Vector3(3.3, 0, 0), "Amphorae sit beside the pottery stand on ground")
	verify(counter.position == Vector3(3.85, 0, 0), "Counter stays beside the existing central approach")
	verify(world.find_children("*", "CharacterBody3D", true, false).size() == 1, "No additional player is created")
	verify(world.find_children("*", "Camera3D", true, false).size() == 1, "No additional camera is created")
	verify(world.find_children("*", "Light3D", true, false).is_empty(), "No lighting is replaced or added")
	verify(_original_snapshot(world) == original, "Original node identity, hierarchy, transforms, meshes and campaign sentinel remain unchanged")
	await physics_frame
	await physics_frame
	verify(absf(_ray_height(world, -8, 60) - 0.115) < 0.0001, "Near corner has the exact local walk height")
	verify(absf(_ray_height(world, 8, 68) - 0.115) < 0.0001, "Far corner has the exact local walk height")
	verify(absf(_ray_height(world, 12, 64) - 0.11) < 0.0001, "Original road remains unchanged outside the detail patch")
	var physical := _collision_signature(world)
	verify(physical.size() == 4, "All four authored box shapes exist")
	var again := Adapter.install(city, "high")
	verify(again.ok and again.removed_groups == 3 and _owned_count(world) == 3, "Repeated application replaces only its three owned groups")
	verify(not is_instance_valid(street_group), "Previous owned group is freed rather than accumulated")
	verify(_original_snapshot(world) == original, "Original assets survive the quality rebuild unchanged")
	verify(_collision_signature(world) == physical, "High and balanced have identical physical shapes")
	var very_high := Adapter.install(city, "very_high")
	verify(very_high.ok and _collision_signature(world) == physical, "Very high preserves identical collision")
	var low := Adapter.install(city, "low")
	verify(low.ok and low.status == "installed" and low.removed_groups == 3 and low.lod == 2, "Low uses existing LOD2 instead of deleting physical objects")
	verify(_owned_count(world) == 3 and _collision_signature(world) == physical, "All low profile physics remains identical")
	var low_batch := city.get_node(Adapter.GROUP_NAME + "/basoli_4m_batch") as MultiMeshInstance3D
	verify(low_batch != null and low_batch.visibility_range_end == 45.0, "Low keeps a shorter bounded visual range")
	await physics_frame
	await physics_frame
	verify(absf(_ray_height(world, 0, 64) - 0.115) < 0.0001, "Low retains the exact authoritative walk height")
	verify(absf(_ray_height(world, 12, 64) - 0.11) < 0.0001, "Low preserves original street outside the patch")
	verify(_original_snapshot(world) == original, "Low mode preserves original world authority")
	# Explicitly clear only the owned fixture groups before testing first-install failures.
	for parent: Node3D in [city, pottery, food]:
		parent.get_node(Adapter.GROUP_NAME).free()
	var foreign := Node3D.new()
	foreign.name = Adapter.GROUP_NAME
	city.add_child(foreign)
	var conflict := Adapter.install(city)
	verify(not conflict.ok and conflict.status == "foreign_group_conflict", "An unowned group name causes a no-op")
	verify(is_instance_valid(foreign) and foreign.get_parent() == city and _owned_count(world) == 0, "The foreign node is preserved")
	city.remove_child(foreign)
	foreign.free()
	city.remove_child(pottery)
	var missing := Adapter.install(city)
	verify(not missing.ok and missing.missing_nodes.has(Adapter.POTTERY_NAME), "An unknown incomplete hierarchy is reported without a partial installation")
	verify(_owned_count(world) == 0, "Missing anchors do not leave partial details")
	city.add_child(pottery)
	var invalid_profile := Adapter.install(city, "unknown")
	verify(not invalid_profile.ok and _owned_count(world) == 0, "An unsupported profile changes nothing")
	city.name = "AnotherCity"
	var other := Adapter.install(city)
	verify(not other.ok and other.status == "unsupported_city", "A different city is an explicit no-op")
	city.name = "RomanCity"
	verify(_original_snapshot(world) == original, "All negative paths preserve original assets and state")
	world.free()
	print("CITY_EXPLORATION_DETAIL_ADAPTER_TEST: %d checks, %d failures; real city and GPU placement not loaded" % [checks, failures])
	print("CITY_EXPLORATION_DETAIL_PASS" if failures == 0 else "CITY_EXPLORATION_DETAIL_FAIL")
	quit(1 if failures else 0)
