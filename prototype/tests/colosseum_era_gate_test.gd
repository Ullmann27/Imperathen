extends SceneTree
## D-053: the Flavian Amphitheatre is hidden in 58 BC and shown from AD 80;
## its Domitianic hypogeum and the Meta Sudans appear only later.
const Era := preload("res://scripts/domain/era_registry.gd")
const Calendar := preload("res://scripts/domain/world_calendar.gd")
const ColosseumScript := preload("res://scripts/monuments/colosseum.gd")
const Showcase := preload("res://scripts/monuments/colosseum_showcase.gd")
const Gate := preload("res://scripts/monuments/era_gate.gd")
var failures: Array[String] = []


func check(condition: bool, text: String) -> void:
	if not condition:
		failures.append(text)
		printerr("FAIL: " + text)


func _initialize() -> void:
	_run.call_deferred()


func _stage(year: int) -> Node3D:
	var scene: Node3D = Showcase.new()
	scene.set("profile", "low")
	scene.set("year", year)
	root.add_child(scene)
	return scene


func _run() -> void:
	var bc58 := Calendar.to_jdn(-58, 3, 28)
	check(not ColosseumScript.available_at(bc58), "not available in 58 BC")
	check(not ColosseumScript.available_at(Calendar.to_jdn(79, 12, 31)), "not available on 31 Dec AD 79")
	check(ColosseumScript.available_at(Calendar.to_jdn(80, 1, 1)), "available from AD 80")
	check(not ColosseumScript.hypogeum_at(Calendar.to_jdn(80, 6, 1)) and ColosseumScript.hypogeum_at(Calendar.to_jdn(96, 1, 1)), "hypogeum is a later phase")
	check(not Era.available("building.meta_sudans", Calendar.to_jdn(80, 6, 1)) and Era.available("building.meta_sudans", Calendar.to_jdn(100, 1, 1)), "Meta Sudans is Domitianic")
	check(Era.available("decor.street_furniture.late_republic", bc58) and not Era.available("decor.street_furniture.imperial", bc58), "58 BC uses the Late Republic street set only")
	check(Era.available("decor.street_furniture.imperial", Calendar.to_jdn(80, 1, 1)), "imperial street set in AD 80")
	for year: int in [-58, 80, 100]:
		var scene := _stage(year)
		await process_frame
		var building := scene.get_node_or_null("Colosseum")
		if year < 80:
			check(building == null, "showcase of 58 BC contains no amphitheatre")
			check(scene.find_children("*olosseum*", "", true, false).is_empty(), "no amphitheatre node of any kind in 58 BC")
		else:
			check(building != null, "showcase of AD %d contains the amphitheatre" % year)
			if building != null:
				var traps := building.find_child("Arena_Trapdoors", true, false) as Node3D
				check(traps != null and traps.visible == (year >= 90), "trapdoors AD %d" % year)
				check(int(building.stats.facade_instances) >= 320, "80 bays on four storeys instanced")
		var meta := scene.find_child("Meta_Sudans*", true, false)
		if scene.get_node_or_null("Piazza") != null:
			check((meta != null) == (year >= 96), "Meta Sudans presence in AD %d" % year)
			var cippi := scene.find_child("*Cippi*", true, false)
			check((cippi != null) == (year >= 80), "amphitheatre boundary stones in %d" % year)
		scene.free()
	# Legacy city GLB: its amphitheatre nodes carry era_min_ce = 80 and must be hidden in 58 BC.
	var city_path := "res://assets/world/roman_city_test.glb"
	if ResourceLoader.exists(city_path):
		var city := (load(city_path) as PackedScene).instantiate()
		root.add_child(city)
		var result: Dictionary = Gate.apply(city, bc58)
		var names: Array = result.hidden
		var amphitheatre := names.filter(func(n: String) -> bool: return n.begins_with("Colosseum"))
		check(amphitheatre.size() >= 13, "legacy city: all amphitheatre parts hidden in 58 BC, got %d" % amphitheatre.size())
		for node: Node in city.find_children("Colosseum*", "Node3D", true, false):
			check(not (node as Node3D).is_visible_in_tree(), "legacy node %s hidden" % node.name)
		var late_city := (load(city_path) as PackedScene).instantiate()
		var later: Dictionary = Gate.apply(late_city, Calendar.to_jdn(300, 1, 1))
		check((later.hidden as Array).is_empty(), "nothing hidden in AD 300")
		late_city.free()
		print("COLOSSEUM_ERA_GATE legacy_hidden=%d kept=%d" % [names.size(), int(result.kept)])
		city.free()
	else:
		print("COLOSSEUM_ERA_GATE legacy city GLB not installed; legacy check skipped")
	print("COLOSSEUM_ERA_GATE %d failures" % failures.size())
	if failures.is_empty():
		print("COLOSSEUM_ERA_GATE_PASS")
	quit(0 if failures.is_empty() else 1)
