extends SceneTree
## Real imported houses, colliding floors, door passages and household continuity.

const Neighborhood = preload("res://scripts/world/village/childhood_neighborhood.gd")
const Regional = preload("res://scripts/world/regional_village.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const Art = preload("res://scripts/world/village_art.gd")
var checks := 0
var failures: Array[String] = []
var stage: Node3D
var probe: CharacterBody3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	Art.box_collider(stage,Vector3(180,.5,170),Vector3(0,-.25,-15))
	var regional := Regional.new()
	stage.add_child(regional)
	regional.show_origin("italia")
	var neighborhood := Neighborhood.new()
	stage.add_child(neighborhood)
	neighborhood.build(regional)
	var living := {"village":{"childhood":{"enabled":true},"economy":{"people":[{"id":"julia","alive":true},{"id":"silvanus","alive":true},{"id":"sextus","alive":true}]}}}
	neighborhood.sync_state(living)
	_check(neighborhood.homes.size()==3,"Three functional houses use existing architecture instances")
	_check(regional.house_count==15,"Two compact households extend thirteen existing houses")
	var body_count: int = neighborhood.snapshot().collision_bodies
	neighborhood.build(regional)
	_check(neighborhood.snapshot().collision_bodies==body_count,"Repeated setup does not duplicate colliders or household objects")
	_check(neighborhood.snapshot().new_residents==0,"Interior presentation creates no duplicate people")
	for id: String in Neighborhood.HOMES:
		var home: Node3D = neighborhood.homes[id]
		_check(home.has_node("ChildhoodInterior/ContinuousFloor"),"A solid continuous floor exists: "+id)
		_check(home.has_node("ChildhoodInterior/EntranceSlopeBody"),"A matching colliding entrance slope exists: "+id)
		_check(home.find_child("DrinkingCup",true,false)!=null,"House has a real drinking vessel: "+id)
		_check(home.find_child("DrinkingJug",true,false)!=null,"House has a filled jug: "+id)
		_check(not neighborhood._roofs[id].is_empty(),"Actual original roof meshes can be hidden: "+id)
	var family: Node3D = neighborhood.homes.family
	_check(family.find_child("FamilyBed",true,false)!=null and family.find_child("ChildSleepingMat",true,false)!=null,"Parents and child have separate sleeping places")
	_check(neighborhood.homes.smith.find_child("SmithWorkbench",true,false)!=null,"Sextus has a furnished workshop")
	for new_id in ["south_baker_home","south_weaver_home"]:
		var definition: Dictionary = {}
		for home: Dictionary in Layout.HOMES:
			if home.id == new_id: definition = home
		for other: Dictionary in Layout.HOMES:
			if other.id != new_id:
				_check(not Layout.house_footprint(definition,.35).intersects(Layout.house_footprint(other,.35)),"House and usable clearance do not overlap "+new_id+" / "+str(other.id))
		_check(not Layout.house_footprint(definition,.35).intersects(Rect2(5,-4,19,17)),"Existing player building area remains free: "+new_id)
	probe = CharacterBody3D.new()
	probe.name = "ActualPlayerCapsule"
	probe.collision_layer = 2
	probe.collision_mask = 1
	probe.floor_snap_length = .25
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .28
	capsule.height = 1.8
	shape.shape = capsule
	probe.add_child(shape)
	stage.add_child(probe)
	await physics_frame
	await physics_frame
	var space := stage.get_world_3d().direct_space_state
	for person in [["julia",Vector2(-4,24.9)],["silvanus",Vector2(-6.8,24.8)],["sextus",Vector2(37.2,-27.3)]]:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.collision_mask = 1
		query.margin = .005
		query.transform.origin = Vector3(person[1].x,Neighborhood.FLOOR_HEIGHT+.92,person[1].y)
		_check(space.intersect_shape(query,1).is_empty(),"Story person stands clear of walls and furniture: "+person[0])
	for id: String in Neighborhood.HOMES:
		var at: Vector3 = Neighborhood.HOMES[id].at
		var door := Neighborhood.entrance_position(id)
		var inner := Neighborhood._to_world(id,Vector3(0,Neighborhood.FLOOR_HEIGHT,.65))
		probe.position = door+Vector3.UP*1.05
		probe.velocity = Vector3.ZERO
		await physics_frame
		_check(await _walk_to(inner,240),"CharacterBody enters through the actual door and ramp: "+id)
		_check(absf(probe.position.y-.9-Neighborhood.FLOOR_HEIGHT)<.055,"Feet stay on the visible interior floor: "+id)
		neighborhood.update_view(probe.position)
		_check(neighborhood.snapshot().houses[id].roof_hidden,"Interior camera hides only the occupied house roof: "+id)
		var roof_hidden := true
		for roof: MeshInstance3D in neighborhood._roofs[id]: roof_hidden = roof_hidden and not roof.visible
		_check(roof_hidden,"Original roof nodes really hide on entry: "+id)
		_check(await _walk_to(door,240),"CharacterBody can leave the house again: "+id)
		_check(probe.position.y>.85 and probe.position.y<1.0,"CharacterBody returns to ground height: "+id)
		neighborhood.update_view(probe.position)
		_check(not neighborhood.snapshot().houses[id].roof_hidden,"Roof returns after leaving: "+id)
		var directed := Neighborhood.navigation_target(at+Vector3(-5,1,4),inner)
		_check(directed.distance_to(door)<.001,"Outdoor compass points first to the actual door: "+id)
		var crossing := Neighborhood._to_world(id,Vector3(0,.8,2.55))
		var guided := Neighborhood.navigation_target(crossing,inner)
		_check(Neighborhood._to_local(id,guided).z<2.0,"The compass continues inward without oscillating back to the outside: "+id)
		print("HOUSE_PASSAGE_DONE "+id)
	var after_raid: Dictionary = living.duplicate(true)
	after_raid.village.economy.people[1].alive = false
	after_raid.village.economy.people[2].alive = false
	neighborhood.sync_state(after_raid)
	_check(neighborhood._memorials.family.visible and neighborhood._memorials.smith.visible,"Saved deaths produce quiet household memorials")
	_check(neighborhood._work_cover.visible,"The smith's anvil remains unused after his saved death")
	_check(not "Julia" in neighborhood._memorials.family.get_node("Names").text,"The surviving mother is not included in the memorial")
	neighborhood.sync_state(living)
	_check(not neighborhood._memorials.family.visible and not neighborhood._work_cover.visible,"Loading an earlier living state restores its own presentation")
	neighborhood.sync_state({})
	_check(not neighborhood.enabled,"Legacy games do not acquire childhood household state")
	for body: StaticBody3D in neighborhood._solids:
		_check(body.collision_layer==0,"Optional chapter collisions disable for legacy mode")
	stage.free()
	await process_frame
	print("CHILDHOOD_NEIGHBORHOOD_RESULT checks=%d failures=%d"%[checks,failures.size()])
	for message: String in failures: printerr("FAIL: "+message)
	quit(0 if failures.is_empty() else 1)


func _walk_to(target: Vector3,frames: int) -> bool:
	for frame in frames:
		var offset := Vector3(target.x-probe.position.x,0,target.z-probe.position.z)
		if offset.length()<.08:
			probe.velocity.x = 0
			probe.velocity.z = 0
			return true
		probe.velocity.x = offset.normalized().x*1.45
		probe.velocity.z = offset.normalized().z*1.45
		probe.velocity.y = -.3 if probe.is_on_floor() else probe.velocity.y-19.6/60.0
		probe.move_and_slide()
		await physics_frame
	return false


func _check(value: bool,message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)
