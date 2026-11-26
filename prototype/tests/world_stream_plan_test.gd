extends SceneTree

const World := preload("res://scripts/world/world_stream_plan.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_test_coordinates()
	_test_terrain()
	_test_budgets()
	_test_transitions()
	_test_routes()
	print("WORLD_STREAM_PLAN_RESULT checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL ",label)


func _test_coordinates() -> void:
	var bounds: Dictionary = World.bounds()
	_check(bounds.area_km2 == 1024 and bounds.sector_count == 16384,"Explicit own world area and sector count")
	_check(World.sector_for_position(Vector3.ZERO) == Vector2i(64,64),"Origin sector")
	_check(World.sector_for_position(Vector3(-0.1,0,-0.1)) == Vector2i(63,63),"Negative coordinates do not truncate toward zero")
	_check(World.sector_for_position(Vector3(-16000,0,-16000)) == Vector2i.ZERO,"Minimum world boundary")
	_check(World.sector_for_position(Vector3(16000,0,16000)) == Vector2i(127,127),"Maximum world boundary safely clamps")
	_check(World.sector_for_position(Vector3(30000,0,-30000)) == Vector2i(127,0),"Outside demand stays within the modeled world")
	_check(not World.plan(Vector3(NAN,0,0)).ok and not World.plan(Vector3(INF,0,0)).ok,"Nonfinite demands rejected")
	_check(World.sector_id(Vector2i(-1,0)).is_empty(),"Invalid sector has no identity")
	_check(not World.sector_origin(Vector2i(128,0)).is_finite(),"Invalid sector cannot masquerade as origin")
	for point in [Vector3(-15999.0,12.0,-100.5),Vector3(12.0,1.0,8.0),Vector3(15999.0,-4.0,15999.0)]:
		var local: Dictionary = World.local_coordinates(point)
		var reconstructed := Vector3(local.origin[0]+local.local[0],local.origin[1]+local.local[1],local.origin[2]+local.local[2])
		_check(reconstructed.is_equal_approx(point) and local.local[0] >= 0 and local.local[0] < 250 and local.local[2] >= 0 and local.local[2] < 250,"Local origin roundtrip")
	_check(World.region_at(Vector3.ZERO).name == "Grenztal","Start village retains central region")
	_check(World.region_at(Vector3(4000,0,0)).name == "Steinbruchhügel","Region border assigned once")


func _test_terrain() -> void:
	for position in [Vector2.ZERO,Vector2(100,0),Vector2(-80,80),Vector2(0,125)]:
		_check(World.terrain_height(position) == 0.0,"Existing village footprint stays flat")
	_check(not is_finite(World.terrain_height(Vector2(NAN,0))),"Invalid terrain input is not a valid flat sample")
	var varied := false
	for x in range(-16000,16001,1000):
		for z in range(-16000,16001,1000):
			var position := Vector2(x,z)
			var height: float = World.terrain_height(position)
			_check(is_finite(height) and height >= -35 and height <= 320,"Terrain height remains bounded")
			_check(height == World.terrain_height(position),"Global coordinate height is deterministic")
			var border_next: float = World.terrain_height(position+Vector2(0.01,0))
			_check(absf(height-border_next) < 0.02,"Sector-coordinate sample stays continuous")
			varied = varied or absf(height) > 10
	_check(varied,"Regional terrain contains actual height variation")


func _test_budgets() -> void:
	for quality in World.PROFILES:
		for point in [Vector3.ZERO,Vector3(-16000,0,-16000),Vector3(15999,0,15999),Vector3(3999,0,-4001)]:
			var plan: Dictionary = World.plan(point,quality)
			var seen := {}
			var counts := [0,0,0]
			for sector in plan.sectors:
				_check(not seen.has(sector.id) and World.sector_valid(Vector2i(sector.x,sector.z)),"Unique valid sector " + quality)
				seen[sector.id] = true
				counts[sector.lod] += 1
				_check(sector.collision == (sector.lod == 0) and sector.full_simulation == (sector.lod == 0),"Collision and full simulation remain near player")
			_check(counts == plan.counts and plan.sectors.size() <= plan.active_limit,"Accurate bounded counts " + quality)
			_check(counts[0] <= plan.limits[0] and counts[1] <= plan.limits[1] and counts[2] <= plan.limits[2],"Per-LOD caps " + quality)
			_check(plan.sectors[0].id == World.sector_id(World.sector_for_position(point)) and plan.sectors[0].lod == 0,"Player sector always gets first detailed slot")
			_check(plan == World.plan(point,quality),"Deterministic demand " + quality)
	_check(World.plan(Vector3.ZERO,"invalid").quality == "balanced","Unknown quality falls back consistently")
	var overview: Dictionary = World.overview()
	_check(overview.playable_place_ids == ["home_village","willow_station"] and overview.status.contains("Fernorte") and overview.status.contains("geplant"),"Regional plan does not claim complete playable world")
	var serialized: Dictionary = JSON.parse_string(JSON.stringify(overview))
	_check(serialized.places.size() == overview.places.size() and serialized.area_km2 == 1024,"Overview persists as plain JSON")


func _test_transitions() -> void:
	var current: Dictionary = World.plan(Vector3.ZERO)
	var first: Dictionary = World.transition({},current,4)
	_check(first.create.size() == 4 and first.pending == current.sectors.size()-4 and first.unload.is_empty(),"Frame creation budget respected")
	_check(first.create[0].id == current.sectors[0].id,"First request protects player sector")
	var stable: Dictionary = World.transition(current,current)
	_check(stable.create.is_empty() and stable.unload.is_empty() and stable.pending == 0,"Stationary plan reuses sectors")
	var shifted: Dictionary = World.plan(Vector3(250,0,0))
	var move: Dictionary = World.transition(current,shifted,2)
	_check(move.create.size() <= 2 and move.pending > 0 and not move.unload.is_empty(),"Moving one sector produces bounded incremental work")
	var changed: Dictionary = World.transition(current,World.plan(Vector3.ZERO,"very_high"),3)
	_check(changed.create.size() == 3 and changed.pending > 0,"Quality increase also obeys spawn budget")
	_check(World.transition({},current,0).create.is_empty(),"Zero budget performs no loading")
	_check(not World.transition(current,{"ok":false}).ok,"Invalid demand cannot unload a valid active world")
	var old_copy := current.duplicate(true)
	move.create[0].lod = 999
	_check(current == old_copy,"Returned requests do not mutate previous plan")


func _test_routes() -> void:
	var places: Array = World.points_of_interest()
	var ids := {}
	var planned := 0
	var workplaces: Array[String] = []
	for place in places:
		_check(not ids.has(place.id),"Unique place " + place.id)
		ids[place.id] = true
		planned += int(place.content_status == "planned")
		if place.content_status == "visible_workplace":
			workplaces.append(place.id)
		_check(absf(place.position[0]) < 16000 and absf(place.position[2]) < 16000,"Place lies inside world " + place.id)
	_check(workplaces == ["stone_quarry"] and planned == places.size()-3 and ids.has("willow_station"),"The inhabited village and waystation and the visible quarry are distinct from planned locations")
	var reachable := {"home_village":true}
	var links: Array = World.roads()
	for road in links:
		_check(ids.has(road.from) and ids.has(road.to) and road.distance_m > 0,"Road endpoints exist and distance is positive")
	for pass_index in places.size():
		for road in links:
			if reachable.has(road.from):
				reachable[road.to] = true
			if reachable.has(road.to):
				reachable[road.from] = true
	_check(reachable.size() == places.size(),"Every planned location connects to village via road graph")
	places[0].name = "Changed copy"
	_check(World.points_of_interest()[0].name == "Unser Grenzdorf","Caller cannot mutate canonical places")
