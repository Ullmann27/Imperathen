extends SceneTree

const Raiders = preload("res://scripts/world/childhood_raiders.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for elapsed in [0.0,0.01,8.0,16.0,24.0,31.99,32.0]:
		var sequence := {"phase":"approach", "elapsed":elapsed, "seed":173}
		var riders: Array[Dictionary] = Raiders.sample_riders(sequence)
		_check(riders.size() == 30, "thirty individual horses at " + str(elapsed))
		var ids := {}
		var minimum := INF
		for index in riders.size():
			ids[riders[index].id] = true
			for other in range(index + 1, riders.size()):
				minimum = minf(minimum, (riders[index].position as Vector3).distance_to(riders[other].position))
		_check(ids.size() == 30, "unique visual identities at " + str(elapsed))
		_check(minimum > 3.6, "horse bodies have genuine separation at " + str(elapsed))
		var restored: Dictionary = JSON.parse_string(JSON.stringify(sequence))
		_check(Raiders.sample_riders(restored) == riders, "save/restore reproduces positions, variants and gait")
	var start: Array[Dictionary] = Raiders.sample_riders({"phase":"approach", "elapsed":0.0, "seed":173})
	var finish: Array[Dictionary] = Raiders.sample_riders({"phase":"approach", "elapsed":32.0, "seed":173})
	_check(start[0].position.z == -142.0 and finish[0].position.z == -58.0, "approach stops outside the northern settlement")
	_check(start[29].position.z == -196.0 and finish[29].position.z == -112.0, "last row keeps its reserved corridor")
	_check(start[0].speed == 0.0 and finish[0].speed == 0.0, "arrival and departure do not slide stationary gait")
	_check(Raiders.sample_riders({"phase":"attack", "elapsed":0.0, "seed":173}) == finish, "phase transition does not teleport the formation")
	for phase in ["dormant", "aftermath", "unknown"]:
		_check(Raiders.sample_riders({"phase":phase, "elapsed":0.0, "seed":173}).is_empty(), "no riders outside explicit active phases: " + phase)
	for invalid in [NAN,INF,-1.0,"8",false]:
		_check(Raiders.sample_riders({"phase":"approach", "elapsed":invalid, "seed":173}).is_empty(), "invalid saved time rejected: " + str(invalid))
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(12,10,-50)
	camera.look_at(Vector3(0,1,-85))
	camera.current = true
	var visual := Raiders.new()
	scene.add_child(visual)
	visual.set_ground_sampler(func(_at: Vector2) -> float: return 2.0)
	var data := {"village":{"enabled":true, "childhood":{"night_raid":{"phase":"approach", "elapsed":32.0, "seed":173, "decision":"defend", "support_confirmed":false, "support_kind":"", "consequences_applied":false, "outcome":""}}, "economy":{"people":[{"id":"silvanus", "alive":true}]}}}
	_check(Raiders.sample_riders(data.village.childhood.night_raid).size() == 30, "real expanded narrative state keeps all thirty riders visible")
	var unchanged := JSON.stringify(data)
	await process_frame
	for profile: String in ["low", "balanced", "high", "very_high"]:
		visual.sync_state(data, profile)
		var proof: Dictionary = visual.debug_snapshot()
		_check(proof.visible and proof.riders == 30, profile + " retains all thirty story identities")
		_check(proof.near + proof.far + proof.culled == 30, profile + " accounts for every rider")
		_check(proof.near <= Raiders.PROFILES[profile].near_count, profile + " caps the detailed count")
		_check(proof.instances.near_body + proof.instances.far_body == 30, profile + " actually allocates thirty horse bodies")
		_check(proof.instances.near_limb + proof.instances.far_limb == 240, profile + " has four two-part legs per horse")
		_check(proof.multimesh_groups == 10, profile + " shares ten render groups instead of hundreds of unique meshes")
		_check(proof.colliders == 30, profile + " has bounded separate collision bodies")
		for triangles: Variant in proof.mesh_triangles.values():
			_check(int(triangles) > 0, profile + " generated geometry is not an empty placeholder")
	var body := visual.get_node("MountedBody_00") as StaticBody3D
	_check(is_equal_approx(body.position.y, 2.0), "mounted actor uses the actual ground sampler")
	_check(body.collision_layer == 1, "visible horse blocks movement through its body")
	visual.set_active(false)
	var held := body.transform
	await process_frame
	await process_frame
	_check(body.transform == held, "renderer frames do not advance paused story time")
	_check(JSON.stringify(data) == unchanged, "rendering does not change residents, survival, loot or narrative state")
	data.village.childhood.night_raid.phase = "aftermath"
	visual.sync_state(data, "balanced")
	_check(not visual.visible and visual.debug_snapshot().riders == 0, "aftermath hides the entire sequence")
	for child: Node in visual.get_children():
		if child is StaticBody3D:
			_check(child.collision_layer == 0, "hidden rider leaves no ghost collision")
	scene.queue_free()
	await process_frame
	for failure: String in failures:
		push_error(failure)
	print(JSON.stringify({"suite":"childhood_raiders", "checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
