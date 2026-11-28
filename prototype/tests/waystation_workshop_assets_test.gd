extends SceneTree
## Original workshop plants installed in the actual streamed Weidenhof yard.
## No additional campaign authority; verify actual mesh/physics/profile/lifecycle.
const Terrain = preload("res://scripts/world/regional_terrain.gd")
const Waystation = preload("res://scripts/world/regional_waystation.gd")
const Freight = preload("res://scripts/domain/regional_freight.gd")
const Footpath = preload("res://scripts/world/regional_footpath.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		quit(2)
		return
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ",label)

func _frames(count: int) -> void:
	for _index: int in count:
		await process_frame
		await physics_frame

func _signature(view: Node3D) -> Array:
	var result: Array = []
	for entry: Dictionary in view.layout.vegetation:
		result.append([entry.asset,entry.position,entry.yaw,entry.scale])
	return result

func _run() -> void:
	var terrain := Terrain.new()
	root.add_child(terrain)
	var at := Vector3(Waystation.COUNTER.x,Terrain.surface_height(Waystation.COUNTER)+0.9,Waystation.COUNTER.y)
	for _i: int in 10:
		terrain.follow(at,"low")
		await physics_frame
	var stop: Node3D = terrain.waystation
	var receipt: Dictionary = Freight.empty_receipt()
	var before: String = JSON.stringify(receipt)
	stop.update_nearby(at,receipt)
	await _frames(3)
	var view: Node3D = stop.get_node_or_null("Yard/WorkshopGrove") as Node3D
	var trunks: StaticBody3D = stop.get_node_or_null("Yard/WorkshopTreeTrunks") as StaticBody3D
	_check(is_instance_valid(view) and is_instance_valid(trunks), "All original workshop plant families actually enter the regional world")
	if is_instance_valid(view) and is_instance_valid(trunks):
		var expected: Array[String] = ["field_elm","cypress","laurel"]
		_check(view.layout.vegetation.size()==3 and view.asset_library.assets.size()==3,"Exactly three original plant types in one yard")
		for id: String in expected:
			var asset: Dictionary = view.asset_library.assets.get(id,{})
			_check(not asset.is_empty() and asset.meshes.size()==3 and asset.triangles[0]>asset.triangles[1] and asset.triangles[1]>asset.triangles[2],"Three genuine decreasing LOD tiers: "+id)
		var old: MultiMeshInstance3D = stop.get_node("Yard/WillowGroves") as MultiMeshInstance3D
		_check(old.multimesh.instance_count>35,"Original willow grove remains substantial")
		for entry: Dictionary in view.layout.vegetation:
			var p: Vector3 = entry.position
			var global_at: Vector3 = stop.to_global(p)
			_check(absf(global_at.y-Terrain.surface_height(Vector2(global_at.x,global_at.z)))<0.002,"Plant root rests on actual terrain: "+str(entry.asset))
			_check(stop._workshop_site_clear(Vector2(global_at.x,global_at.z),[] as Array[Vector2]),"Plant cannot obstruct established road, loading bay or spring")
			var duplicate: bool = false
			for i: int in old.multimesh.instance_count:
				duplicate = duplicate or old.multimesh.get_instance_transform(i).origin.distance_to(p)<0.001
			_check(not duplicate,"No overlapping old willow at the replaced position")
		_check(trunks.get_child_count()==2 and trunks.collision_layer==1,"Two real solid trunks; laurel remains flexible brush")
		var physics: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state
		var shapes: Array[Shape3D] = []
		for child: Node in trunks.get_children():
			var collider := child as CollisionShape3D
			_check(is_instance_valid(collider) and collider.shape is ConvexPolygonShape3D and collider.shape.points.size()>=12,"Collider is derived from actual original woody mesh")
			shapes.append(collider.shape)
			var centre: Vector3 = collider.global_position + Vector3.UP*0.6
			var hit: Dictionary = physics.intersect_ray(PhysicsRayQueryParameters3D.create(centre+Vector3.LEFT*1.5,centre+Vector3.RIGHT*1.5,1))
			_check(not hit.is_empty() and hit.get("collider")==trunks,"Real world-space horizontal ray stops at authored tree trunk")
		stop._update_workshop_grove(at,"low",12.5,0.0,0.1)
		var low: Dictionary = view.report()
		_check(low.distance_enabled_lod_instances[0]==0,"Low profile never draws the expensive near workshop plant meshes")
		stop._update_workshop_grove(at,"very_high",12.5,1.0,0.1)
		var high: Dictionary = view.report()
		_check(high.distance_enabled_lod_instances[0]==3,"Very high profile uses all three authored near meshes")
		for i: int in shapes.size():
			_check(trunks.get_child(i).shape==shapes[i],"Graphics profile never changes the collision shape")
		for material: ShaderMaterial in view.asset_library.wind_materials:
			_check(is_equal_approx(float(material.get_shader_parameter("wind_time")),12.5) and is_equal_approx(float(material.get_shader_parameter("wind_strength")),0.6),"Uses supplied world clock and local wind, not independent weather")
		var initial: Array = _signature(view)
		stop.update_nearby(at+Vector3(250,0,0),receipt)
		_check(not is_instance_valid(view) and not is_instance_valid(trunks),"Leaving releases plant batches, meshes and trunk bodies")
		stop.update_nearby(at,receipt)
		var restored: Node3D = stop.get_node_or_null("Yard/WorkshopGrove") as Node3D
		_check(is_instance_valid(restored) and _signature(restored)==initial,"Reentry restores identical authored positions")
	_check(JSON.stringify(receipt)==before,"The existing freight receipt is never mutated")
	terrain.free()
	await process_frame
	print("WAYSTATION_WORKSHOP_ASSETS_RESULT checks=%d failures=%d" % [checks,failures.size()])
	if failures.is_empty():
		print("WAYSTATION_WORKSHOP_ASSETS_PASS")
	quit(0 if failures.is_empty() else 1)
