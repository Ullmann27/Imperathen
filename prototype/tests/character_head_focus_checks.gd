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
	player.clear_gaze_target()
	_tick(player, 0.9)
	check.call(absf(_angle(player)) < 3.0, "Clear focus returns to neutral")
	player.set_ambient_gaze(true)
	first.position = Vector3(-0.9, 0, -1.5)
	second.position = Vector3(0, 0, 8)
	_tick(player, 0.6)
	check.call(player._social_focus.target() == first and _angle(player) > 12.0, "Near NPC pass-by triggers brief focus")
	first.position = Vector3(-8, 0, -1.5)
	_tick(player, 0.8)
	check.call(absf(_angle(player)) < 4.0, "Departing person releases focus")
	player.set_ambient_gaze(false)
	first.position = Vector3(-1, 0, -2)
	player.set_gaze_target(first)
	player.drive(1.2)
	_tick(player, 0.7)
	check.call(player.clip == "march" and _angle(player) > 12.0 and absf(_angle(player)) <= 42.0, "Walking gaze retains march and bounds")
	player.sample_combat("jab_right", 0.4)
	check.call(player._gaze._saved.is_empty(), "Combat samples clear gaze before authoring the pose")
	player._process(1.0 / 60.0)
	check.call(player._gaze._saved.is_empty(), "Combat cannot be overwritten by gaze")
	player.cancel_action()
	player.clear_gaze_target()
	player.drive(0.0)
	_tick(player, 0.8)
	check.call(absf(_angle(player)) < 3.0, "Idle recovers after combat")
	# Fallback is explicit rather than assuming that painted eyes can rotate.
	check.call(player._gaze.eyes.is_empty() and first._gaze.eyes.is_empty(), "Current source rigs expose no independent eye pair")
	print("HEAD_FOCUS_ACTUAL_MODELS ", player.active_model_path, " | ", first.active_model_path)
	scene.free()
