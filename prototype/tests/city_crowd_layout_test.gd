extends SceneTree
## Validates the city pedestrian placements and actual authored character resources.
## Deliberately does not treat a static idle figure as a talking or pathfinding NPC.
const PATH := "res://assets/world/city_crowd_layout.json"
const Crowd := preload("res://scripts/world/city_exploration_crowd.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("Isolated file check required")
		quit(2)
		return
	_check_layout.call_deferred()


func require(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures.append(reason)
		printerr("FAIL: "+reason)


func _check_layout() -> void:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	require(value is Dictionary, "Crowd layout must be a JSON dictionary")
	if not value is Dictionary:
		quit(1)
		return
	var data: Dictionary = value
	require(data.get("format","")=="imperathen-city-idle-crowd" and int(data.get("version",0))==1,
		"Actual city idle-person format is version one")
	var entries: Array = data.get("entries",[])
	require(entries.size()==12,"Twelve distinct roles are available to high-profile city")
	var existing_ids: Dictionary = {}
	var points: Array[Vector2] = []
	var kinds: Dictionary = {}
	for row: Variant in entries:
		require(row is Dictionary,"Crowd entry has dictionary schema")
		if not row is Dictionary:
			continue
		var id := str(row.get("id",""))
		require(not existing_ids.has(id) and id.begins_with("CityGuest"),"Unique nonmerchant city occupant: "+id)
		existing_ids[id] = true
		var raw: Variant = row.get("position",[])
		require(raw is Array and raw.size()==3,"Exact metric city position: "+id)
		if not raw is Array or raw.size()!=3:
			continue
		var x := float(raw[0])
		var y := float(raw[1])
		var z := float(raw[2])
		require(is_finite(x) and is_finite(y) and is_finite(z),"Finite world transform: "+id)
		require(x>=-70.0 and x<=70.0 and z>=58.0 and z<=72.0 and absf(y-.92)<.01,
			"Character waits on the existing 14-m main road, not behind a house: "+id)
		for previous: Vector2 in points:
			require(previous.distance_to(Vector2(x,z))>2.0,"Different people have separate personal spaces: "+id)
		points.append(Vector2(x,z))
		var pattern := str(row.get("path",""))
		require(pattern.begins_with("res://assets/characters/frontier_") and pattern.ends_with("_%d.glb"),
			"Uses an existing properly LOD-ed Roman NPC resource: "+id)
		var quality_asset: String = pattern % 1
		require(ResourceLoader.exists(quality_asset,"PackedScene"),"Actually present character mesh: "+quality_asset)
		kinds[str(row.get("role",""))] = true
	require(kinds.size()>=5,"Crowd uses at least five established different character families")
	var stage := Node3D.new()
	root.add_child(stage)
	var crowd := Crowd.new()
	crowd.profile = "high"
	stage.add_child(crowd)
	await process_frame
	require(crowd.entries.size()==12,"Existing CityIdleCrowd controller accepts the manifest")
	require(crowd.limit()==12,"High uses at most twelve streamed background walkers/idle figures")
	crowd.profile = "balanced"
	require(crowd.limit()==8,"Balanced reduces streamed city burden")
	crowd.profile = "low"
	require(crowd.limit()==4,"Low keeps minimum crowd")
	stage.free()
	print("CITY_CROWD_LAYOUT_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"distinct_models":kinds.size(),
		"physical_fold7_test":false,"social_behaviour": "not_claimed_by_idle_crowd"}))
	print("CITY_CROWD_LAYOUT_PASS" if failures.is_empty() else "CITY_CROWD_LAYOUT_FAIL")
	quit(0 if failures.is_empty() else 1)
