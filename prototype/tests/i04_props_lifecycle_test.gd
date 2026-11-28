extends SceneTree
## Actual I04 WorldModel paths and imported production VillagePerson rig.
## This public-source fixture does not claim private Meshy youth or visual acceptance.
const WorldModel = preload("res://scripts/domain/world_model.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const Props = preload("res://scripts/world/village/i04_props.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const Documents = preload("res://scripts/story/mission_documents.gd")
const Support = preload("res://tests/i03_support.gd")
const CONTACT_LIMIT := .001
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("I04_PROPS_FAIL ", label)
	return condition

func _stage(model) -> String:
	return str(Childhood.view(model.data).get("stage", ""))

func _play(model, action := "") -> bool:
	var view: Dictionary = Childhood.view(model.data)
	var stage := str(view.get("stage", ""))
	if stage.begins_with("i03_"):
		return _check(bool(Support.play_stage(model).get("ok", false)), "Actual I03 bridge " + stage)
	var point: Vector2 = view.point
	model.set_player_position(Vector3(point.x, 1.35, point.y))
	var npc := str(view.get("target_npc", ""))
	if not npc.is_empty() and not bool(Childhood.relationship(model.data, npc).get("met", false)):
		model.execute("village_talk", {"npc_id":npc, "choice":"meet"})
	view = Childhood.view(model.data)
	if action.is_empty():
		var actions: Array = view.get("actions", [])
		if not _check(not actions.is_empty(), "Available authored action for " + stage):
			return false
		action = "basket_check" if stage == "i02_basket" else str(actions[0].payload.action_id)
	var result: Dictionary = model.execute("village_childhood_action", {"action_id":action})
	return _check(bool(result.get("ok", false)), "Actual action %s: %s" % [action, str(result.get("message", ""))])

func _at_forge():
	var model = WorldModel.new()
	model.new_game("italia", true, true, false, true)
	for _index in 80:
		if _stage(model) == "i04_work":
			return model
		if not _play(model):
			return null
	_check(false, "Reach actual forge visit")
	return null

func _sync(props, model, actor: Node3D) -> void:
	var before := JSON.stringify(model.data)
	var ctx: Dictionary = Childhood.i04_ctx(model.data)
	props.sync_state(model.data, actor, int(ctx.index), int(ctx.trial_index))
	_check(JSON.stringify(model.data) == before, "Presentation leaves the entire authoritative state unchanged")

func _actor(at: Vector3):
	var actor := Person.new()
	root.add_child(actor)
	actor.configure("player", "italia", 12)
	actor.position = at
	actor.set_process(false)
	actor.set_physics_process(false)
	return actor

func _rig(actor) -> Skeleton3D:
	if not is_instance_valid(actor) or not is_instance_valid(actor.body):
		return null
	var rigs: Array[Node] = actor.body.find_children("*", "Skeleton3D", true, false)
	for node: Node in rigs:
		var rig := node as Skeleton3D
		if rig.find_bone("Hand_L") >= 0 and rig.find_bone("Hand_R") >= 0:
			return rig
	return null

func _check_pose(item: Node3D, actor, bone: String, offset: Vector3, label: String) -> void:
	var rig := _rig(actor)
	if not _check(is_instance_valid(rig), label + ": actual imported rig exists"):
		return
	var index := rig.find_bone(bone)
	var pose := rig.global_transform * rig.get_bone_global_pose(index)
	var rest_inverse := rig.get_bone_global_rest(index).basis.inverse()
	var hand := pose * Transform3D(rest_inverse, Vector3.ZERO)
	var expected := Transform3D(hand.basis.orthonormalized(), hand * offset)
	_check(item.is_visible_in_tree() and item.global_transform.is_finite(), label + ": carried prop is visible and finite")
	_check(item.global_position.distance_to(expected.origin) < CONTACT_LIMIT, label + ": actual world hand position within 1 mm")
	_check(item.global_basis.is_equal_approx(expected.basis), label + ": actual hand orientation, without scale distortion")

func _settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame

func _run() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("I04 props lifecycle requires IMPERATHEN_ISOLATED_TEST=1")
		quit(2)
		return
	var first = _actor(Vector3(4.0, 1.35, 3.0))
	var second = _actor(Vector3(-7.0, 1.35, -6.0))
	second.rotation.y = .8
	if not _check(is_instance_valid(_rig(first)) and is_instance_valid(_rig(second)), "Two actual public production player rigs imported"):
		_finish()
		return
	print("I04_PROPS_RIG ", first.active_model_path, " / ", second.active_model_path)
	var props := Props.new()
	root.add_child(props)
	var model = _at_forge()
	if model == null:
		_finish()
		return
	if not _play(model, "i04_stack") or not _play(model, "i04_stack_take"):
		_finish()
		return
	_check(bool(model.data.village.childhood.screenplay.i04_hand), "Actual take command grants one carried armful")
	_sync(props, model, first)
	var armful := props.get_node_or_null("CarriedArmful") as Node3D
	var note := props.get_node_or_null("WaxTablet") as Node3D
	if not _check(is_instance_valid(armful) and is_instance_valid(note), "World owns both actual prop containers"):
		_finish()
		return
	var original_id := armful.get_instance_id()
	await _settle()
	_check_pose(armful, first, "Hand_L", Vector3(0,-.20,.10), "Initial armful")
	_check(not note.is_visible_in_tree(), "No tablet on stack route")
	_check(props.bundle_armfuls() == 1 and props.stack_armfuls() == 0, "Original bundle and stack accounting")

	for phase: float in [0.0,.25,.5,.75]:
		first.sample_pose("march", phase)
		await _settle()
		_check_pose(armful, first, "Hand_L", Vector3(0,-.20,.10), "Actual march %.2f" % phase)

	# Loss of the carrier is not loss of the authoritative object. The first
	# actor deliberately stays alive, to expose stale but valid hand sockets.
	_sync(props, model, null)
	_check(not props.carrying("kindling") and not armful.is_visible_in_tree(), "Null carrier hides armful immediately")
	first.sample_pose("run", .4)
	await _settle()
	_check(not armful.is_visible_in_tree(), "Old live actor cannot resurrect hidden armful")
	_sync(props, model, second)
	await _settle()
	_check(armful.get_instance_id() == original_id, "New carrier reuses exact world-owned armful")
	_check_pose(armful, second, "Hand_L", Vector3(0,-.20,.10), "Carrier exchange")
	var held_transform := armful.global_transform
	first.sample_pose("march", .85)
	await _settle()
	_check(armful.global_transform.is_equal_approx(held_transform), "Former carrier animation cannot move the new carrier's prop")

	for lod: int in [1,2,3,0]:
		second._reload(lod)
		second.sample_pose("march", .35)
		await _settle()
		_check(second.detail == lod, "Actual production LOD %d loaded" % lod)
		_check(armful.get_instance_id() == original_id and armful.get_parent() == props, "LOD %d preserves world-owned identity" % lod)
		_check_pose(armful, second, "Hand_L", Vector3(0,-.20,.10), "LOD %d" % lod)

	# Detached (but not freed) actor must not retain ownership of presentation.
	root.remove_child(second)
	props._physics_process(0.0)
	_check(not armful.visible, "Detached carrier hides armful")
	root.add_child(second)
	_sync(props, model, second)
	await _settle()
	_check_pose(armful, second, "Hand_L", Vector3(0,-.20,.10), "Reattached actor")
	if not _play(model, "i04_stack_put"):
		_finish()
		return
	_sync(props, model, second)
	_check(not armful.visible and not props.carrying("kindling") and props.stack_armfuls() == 1, "Real put-down hides carried armful and stacks once")
	_check(not props.is_processing() and not props.is_physics_processing(), "No per-frame carry updates with empty hands")

	var message = _at_forge()
	if message == null or not _play(message, "i04_message"):
		_finish()
		return
	_sync(props, message, first)
	await _settle()
	_check(note.get_child_count() == 1 and note.get_child(0).scene_file_path == Documents.ENTRIES.sextus_note.model, "Actual original wax tablet instance")
	_check_pose(note, first, "Hand_R", Vector3(0,-.10,.05), "Message route")
	_check(not armful.visible, "No phantom armful on message route")
	var note_id := note.get_instance_id()
	var model_id := note.get_child(0).get_instance_id()
	var save_path := "user://i04_props_lifecycle_%s.json" % Time.get_ticks_usec()
	var result: Dictionary = message.save_game(save_path)
	_check(bool(result.get("ok", false)), "Real save of carried tablet")
	var loaded = WorldModel.new()
	var loaded_result: Dictionary = loaded.load_game(save_path)
	if _check(bool(loaded_result.get("ok", false)), "Real load of carried tablet"):
		message = loaded
		_sync(props, message, second)
		await _settle()
		_check(note.get_instance_id() == note_id and note.get_child_count() == 1 and note.get_child(0).get_instance_id() == model_id, "Save/Load retains the single authored tablet")
		_check_pose(note, second, "Hand_R", Vector3(0,-.10,.05), "Reloaded tablet")
	for suffix: String in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))

	props.sync_state({}, first, 0, 0)
	_check(not props.visible and not note.visible and not armful.visible, "Legacy/non-childhood state clears both carried objects")
	_check(not props.is_processing() and not props.is_physics_processing(), "Disabled presentation stops both update loops")
	_sync(props, message, first)
	await _settle()
	_check_pose(note, first, "Hand_R", Vector3(0,-.10,.05), "Restored tablet")
	if _play(message, "i04_note_give"):
		_sync(props, message, first)
		_check(not note.visible and not props.carrying("note"), "Actual delivery hides wax tablet")
		_check(not props.is_processing() and not props.is_physics_processing(), "Final delivery disconnects carry updates")
	props.free()
	first.free()
	second.free()
	_finish()

func _finish() -> void:
	print("I04_PROPS_LIFECYCLE_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("I04_PROPS_LIFECYCLE_PASS" if failures.is_empty() else "I04_PROPS_LIFECYCLE_FAIL")
	quit(0 if failures.is_empty() else 1)
