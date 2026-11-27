extends RefCounted
const Person := preload("res://scripts/visuals/village_person.gd")
const Gaze := preload("res://scripts/visuals/head_gaze.gd")

static func _figure(parent: Node3D, role: String, at: Vector3) -> Person:
	var person := Person.new()
	parent.add_child(person)
	person.configure(role, "italia", 12)
	person.position = at
	person.set_process(false)
	person.set_physics_process(false)
	return person

static func _tick(person: Person, seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		person._physics_process(1.0 / 60.0)
		person._process(1.0 / 60.0)

static func _angle(person: Person) -> float:
	return rad_to_deg(Gaze.angles_for(person._gaze.direction_world(), person.global_basis).x)

static func run(tree: SceneTree, check: Callable) -> void:
	var scene := Node3D.new()
	tree.root.add_child(scene)
	var player := _figure(scene, "player", Vector3.ZERO)
	if Person.youth_outfit_installed("civil"):
		player.configure_meshy_youth(true, "civil")
	var first := _figure(scene, "companion", Vector3(-1.0, 0.0, -2.0))
	var second := _figure(scene, "companion", Vector3(1.0, 0.0, -2.0))
	player.set_ambient_gaze(false)
	await tree.physics_frame
	check.call(player._gaze.available() and first._gaze.available(), "Head focus binds both real model rigs")
	if not player._gaze.available() or not first._gaze.available():
		scene.free()
		return
	if OS.get_environment("IMPERATHEN_FULL_ASSET_ACCEPTANCE") == "1":
		check.call(player.active_model_path.contains("hero_meshy_italia_civil_"), "Focus QA uses actual civil player")
		check.call(Person.MarcusModel.owns(first.active_model_path), "Focus QA uses actual Marcus")
	_tick(player, 1.0)
	_tick(first, 1.0)
	check.call(absf(_angle(player)) < 3.0 and absf(_angle(first)) < 3.0, "Idle front on actual imported player and Marcus")
	player.set_gaze_target(first)
	_tick(player, 0.8)
	check.call(_angle(player) > 18.0 and _angle(player) < 36.0, "Conversation target tracks left speaker")
	var before := _angle(player)
	player.set_gaze_speaker(second)
	_tick(player, 1.0 / 60.0)
	check.call(absf(_angle(player) - before) < 10.0, "Speaker switch has no snap")
	_tick(player, 0.9)
	check.call(_angle(player) < -18.0, "Active speaker overrides dialog partner")
	var tracked := _angle(player)
	player._reload(1)
	check.call(absf(_angle(player) - tracked) < 6.0, "Live gaze survives compatible LOD replacement")
	player._reload(0)
	player.clear_gaze_target()
	_tick(player, 0.9)
	check.call(absf(_angle(player)) < 3.0, "Clear focus returns to neutral")
	# Use an actual physics collider between the real character eye lines.
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(3, 3, 0.2)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	scene.add_child(wall)
	wall.position = Vector3(0, 0.5, -1.0)
	await tree.physics_frame
	await tree.physics_frame
	player.set_gaze_target(first)
	_tick(player, 0.8)
	check.call(player._social_focus.target() == null and absf(_angle(player)) < 4.0, "World geometry blocks conversation gaze")
	player.clear_gaze_target()
	wall.free()
	await tree.physics_frame
	player.set_ambient_gaze(true)
	first.position = Vector3(-0.9, 0, -1.5)
	second.position = Vector3(0, 0, 8)
	_tick(player, 0.6)
	check.call(player._social_focus.target() == first and _angle(player) > 12.0, "Near NPC pass-by triggers brief focus")
	first.position = Vector3(-8, 0, -1.5)
	_tick(player, 0.8)
	check.call(absf(_angle(player)) < 4.0, "Departing person releases focus")
	# No nearby character: the idle player still explores the scene with brief
	# bounded head turns instead of staring forward indefinitely.
	var scan_min := 180.0
	var scan_max := -180.0
	for i in 600:
		player._physics_process(1.0/60.0)
		player._process(1.0/60.0)
		var yaw := _angle(player)
		scan_min = minf(scan_min,yaw)
		scan_max = maxf(scan_max,yaw)
	check.call(scan_min < -7.0 and scan_max > 9.0 and scan_max-scan_min < 65.0, "Idle player performs restrained left/right environmental glances")
	player.set_ambient_gaze(false)
	first.position = Vector3(-1, 0, -2)
	player.set_gaze_target(first)
	player.drive(1.2)
	_tick(player, 0.7)
	check.call(player.clip == "march" and _angle(player) > 12.0 and absf(_angle(player)) <= 42.0, "Walking gaze retains march and bounds")
	player.drive(3.8)
	_tick(player, 0.5)
	check.call(player.clip == "run" and player._gaze._saved.is_empty(), "Sprint owns the unmodified animation pose")
	player.sample_combat("jab_right", 0.4)
	check.call(player._gaze._saved.is_empty(), "Combat samples clear gaze before authoring the pose")
	player._process(1.0 / 60.0)
	check.call(player._gaze._saved.is_empty(), "Combat cannot be overwritten by gaze")
	player.cancel_action()
	player.clear_gaze_target()
	player.drive(0.0)
	_tick(player, 0.8)
	check.call(absf(_angle(player)) < 3.0, "Idle recovers after combat")
	# The private Meshy youth still has no independently weighted globes.
	check.call(player._gaze.eyes.is_empty(), "Private youth uses honest head-only fallback")
	check.call(first._gaze.eyes.size() == 2, "Marcus binds the two independently weighted eyeballs")
	if first._gaze.eyes.size() == 2:
		first.position = Vector3.ZERO
		first.clear_gaze_target()
		_tick(first, 0.8)
		second.position = Vector3(-1.2, 0, -2)
		first.set_gaze_target(second)
		_tick(first, 1.0 / 60.0)
		var eye: int = first._gaze.eyes[0]
		var head_yaw := _angle(first)
		var eye_yaw := rad_to_deg(Gaze.angles_for(first._gaze.direction_world(eye), first.global_basis).x)
		check.call(eye_yaw > head_yaw + 2.0 and eye_yaw - head_yaw <= 14.5, "Actual eye joint leads head on new speaker")
		_tick(first, 0.7)
		first.clear_gaze_target()
		_tick(first, 0.9)
		check.call(absf(_angle(first)) < 3.0, "Marcus returns to neutral")
		first.configure("companion", "italia", 18)
		check.call(first._gaze.eyes.size() == 2 and first._gaze._eye_offsets.size() == 2, "Adult eye centre calibration survives rig rebind")
	print("HEAD_FOCUS_ACTUAL_MODELS ", player.active_model_path, " | ", first.active_model_path)
	print("HEAD_FOCUS_RIGS player=", player._gaze.skeleton.get_bone_count(), " neck=", player._gaze.neck, " eyes=", player._gaze.eyes.size(), " marcus=", first._gaze.skeleton.get_bone_count(), " neck=", first._gaze.neck, " eyes=", first._gaze.eyes.size())
	scene.free()
