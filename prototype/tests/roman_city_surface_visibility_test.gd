extends SceneTree
## The ground, main-street and plot surfaces under every house front and gate of
## the ACTUAL RomanCity GLB must lie inside the visibility range that the
## production CityExploration assigns in the low and balanced profiles.
## Godot hides a mesh by the camera distance to its AABB centre (with
## hysteresis: hidden beyond end+margin, shown again only inside end-margin).
## A surface counts as visible only when even the farthest third-person camera
## (8 m zoom) stays inside end-margin. Headless geometry check, not a render.
const City = preload("res://scripts/world/city_exploration.gd")
const SURFACES := ["City_Ground", "Main_Streets", "Residential_Roads"]
const CAMERA_REACH := 8.4  # maximum zoom distance 8.0 m plus 0.4 m camera anchor
const FRONT_OFFSET := 1.0
var checks := 0
var failures: Array[String] = []
var results := {}


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("Isolated test profile required")
		quit(2)
		return
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: "+label)


func _run() -> void:
	for profile in ["low", "balanced"]:
		var scene := City.new()
		scene.persist = false
		scene.profile = profile
		root.add_child(scene)
		for i in 4:
			await physics_frame
			await process_frame
		_check(scene.city_available, profile+": actual RomanCity GLB is loaded")
		if scene.city_available:
			results[profile] = _measure(scene.get_node("RomanCity") as Node3D, profile)
		scene.free()
		await process_frame
	print("ROMAN_CITY_SURFACE_VISIBILITY_RESULT "+JSON.stringify({"checks":checks,"failures":failures.slice(0,12),
		"failure_count":failures.size(),"profiles":results,"passed":failures.is_empty(),
		"renderer_note":"headless geometry of real imported meshes; Xvfb renders are separate evidence"}))
	print("ROMAN_CITY_SURFACE_VISIBILITY_PASS" if failures.is_empty() else "ROMAN_CITY_SURFACE_VISIBILITY_FAIL")
	quit(0 if failures.is_empty() else 1)


func _surface_meshes(city: Node3D, family: String) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	var node := city.find_child(family, true, false)
	if node is MeshInstance3D:
		found.append(node as MeshInstance3D)
	elif node != null:
		for child: Node in node.find_children("*", "MeshInstance3D", true, false):
			found.append(child as MeshInstance3D)
	return found


func _measure(city: Node3D, profile: String) -> Dictionary:
	var surfaces := {}
	for family: String in SURFACES:
		var meshes := _surface_meshes(city, family)
		_check(not meshes.is_empty(), profile+": "+family+" surface meshes exist in the GLB")
		surfaces[family] = meshes
	var probes: Array[Dictionary] = []
	for node: Node in city.find_children("Residential_*", "MeshInstance3D", true, false):
		var parts := str(node.name).split("_")
		if parts.size() != 3 or parts[1].length() != 3 or not parts[1].is_valid_int():
			continue
		var house := node as MeshInstance3D
		var local := house.get_aabb()
		# Blender local -Y (the doorway side) is Godot local +Z.
		var front := house.global_transform * Vector3(local.get_center().x, 0.0, local.end.z + FRONT_OFFSET)
		probes.append({"name":str(house.name), "point":front, "host":house, "needs":["City_Ground", "Residential_Roads"]})
	for gate: Node in city.find_children("Porta_*", "MeshInstance3D", true, false):
		probes.append({"name":str(gate.name), "point":(gate as Node3D).global_position, "host":gate, "needs":["City_Ground", "Main_Streets"]})
	_check(probes.size() == 244, profile+": 240 house fronts and 4 gates are probed")
	var violations := 0
	var hidden_even_when_seen := 0
	var worst := -1.0e9
	var probes_failed := {}
	var probes_hidden := {}
	var drawn_without_surface := 0
	for probe: Dictionary in probes:
		var point: Vector3 = probe.point
		for family: String in probe.needs:
			var under: Array[MeshInstance3D] = []
			for mesh: MeshInstance3D in surfaces[family]:
				var box: AABB = mesh.global_transform * mesh.get_aabb()
				if point.x >= box.position.x and point.x <= box.end.x and point.z >= box.position.z and point.z <= box.end.z:
					under.append(mesh)
			if under.is_empty():
				violations += 1
				probes_failed[probe.name] = true
				_check(false, "%s: no %s surface under %s" % [profile, family, probe.name])
				continue
			for mesh: MeshInstance3D in under:
				var centre: Vector3 = (mesh.global_transform * mesh.get_aabb()).get_center()
				var distance := Vector2(point.x-centre.x, point.z-centre.z).length()
				var guaranteed := mesh.visibility_range_end - mesh.visibility_range_end_margin
				worst = maxf(worst, distance + CAMERA_REACH - guaranteed)
				if distance > mesh.visibility_range_end + mesh.visibility_range_end_margin:
					hidden_even_when_seen += 1
					probes_hidden[probe.name] = true
				# Whenever the building itself can still be drawn (camera within
				# its end+margin), the surface under it must be guaranteed drawn.
				var host := probe.host as MeshInstance3D
				var host_centre: Vector3 = (host.global_transform * host.get_aabb()).get_center()
				var host_last_drawn := host.visibility_range_end + host.visibility_range_end_margin
				var apart := Vector2(host_centre.x-centre.x, host_centre.z-centre.z).length()
				if mesh.visibility_range_end > 0.0 and host_last_drawn + apart > guaranteed:
					drawn_without_surface += 1
					probes_failed[probe.name] = true
					_check(false, "%s: %s can be drawn while %s under it is culled (%.1f + %.1f > %.1f m)" % [
						profile, probe.name, mesh.name, host_last_drawn, apart, guaranteed])
				if mesh.visibility_range_end > 0.0 and distance + CAMERA_REACH > guaranteed:
					violations += 1
					probes_failed[probe.name] = true
					_check(false, "%s: %s at %s is %.1f m from its AABB centre; range %.0f-%.0f m" % [
						profile, mesh.name, probe.name, distance, mesh.visibility_range_end, mesh.visibility_range_end_margin])
	return {"probes":probes.size(), "violations":violations, "probes_with_violation":probes_failed.size(),
		"building_drawn_while_surface_culled":drawn_without_surface,
		"probes_with_surface_beyond_end_plus_margin":probes_hidden.size(),
		"hidden_beyond_end_plus_margin":hidden_even_when_seen,
		"worst_excess_m":snappedf(worst, 0.1),
		"tiles":{"City_Ground":surfaces.City_Ground.size(), "Main_Streets":surfaces.Main_Streets.size(),
			"Residential_Roads":surfaces.Residential_Roads.size()}}
