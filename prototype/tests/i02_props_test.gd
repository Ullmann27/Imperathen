extends SceneTree
## I-02 basket presentation through the original prop and production youth rig.
## Uses an isolated real save fixture; never touches the player's normal saves.

const Props = preload("res://scripts/world/village/i02_props.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Life = preload("res://scripts/story/village_life.gd")
const FIXTURE := "res://tests/fixtures/mission_bridge_data/handoff_i02_correct_v5.json"
const SAVE_PATH := "user://i02_props_test_save.json"

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("I-02 props require IMPERATHEN_ISOLATED_TEST=1")
		quit(2)
		return
	_cleanup()
	var actor := Person.new()
	root.add_child(actor)
	actor.set_process(false)
	actor.configure("player", "italia", 12)
	_check(actor.configure_meshy_youth(true, "civil"), "Original civil youth rig is installed")
	var props := Props.new()
	root.add_child(props)
	var model = _load_correction()
	if model == null:
		_cleanup()
		_finish()
		return
	_check(str(model.data.village.childhood.screenplay.i02) == "correction", "Real v5 fixture migrates to I-02 correction")
	_check(model.data.village.childhood.carried.has("neighbor_basket"), "Correction still owns the neighbour basket")
	props.sync_state(model.data, actor)
	_check(props.basket_in_hand(), "Correction displays exactly one carried basket")
	_check_original_asset(props)
	_check(props.attachment_error_m() >= 0.0 and props.attachment_error_m() < 0.001, "Authored handle meets actual Hand_L within 1 mm")
	_check(props.anchor("i02_correct").is_finite(), "Correction insert uses the live prop anchor")
	_check(not props.anchor("unrelated").is_finite(), "Unknown anchors do not invent a world position")
	var before := JSON.stringify(model.data)
	props.sync_state(model.data, actor)
	_check(JSON.stringify(model.data) == before, "Presentation never mutates the authoritative correction state")

	var pending: Dictionary = model.data.duplicate(true)
	pending.village.childhood.screenplay.i02 = "pending"
	pending.village.childhood.screenplay.i02_outcome = ""
	_check(model._validate_state(pending).is_empty(), "Pending presentation fixture remains valid")
	var pending_before := JSON.stringify(pending)
	props.sync_state(pending, actor)
	_check(props.basket_in_hand(), "Pending pickup is visible")
	_check(JSON.stringify(pending) == pending_before, "Pending presentation is read-only")

	var saved: Dictionary = model.save_game(SAVE_PATH)
	_check(bool(saved.get("ok", false)), "Correction saves through the production save contract")
	var resumed = _load_from_path(SAVE_PATH)
	if resumed != null:
		_check(str(resumed.data.village.childhood.screenplay.i02) == "correction", "Save/Load preserves correction")
		props.sync_state(resumed.data, actor)
		_check(props.basket_in_hand(), "Save/Load restores the same visible basket, not a duplicate")
		await _contact_samples(props, actor, resumed.data)
		await _lod_replacements(props, actor, resumed.data)

	model.set_player_position(Life.actor_position(model.data, "julia"))
	var corrected: Dictionary = model.execute("village_childhood_action", {"action_id":"basket_correct"})
	_check(bool(corrected.get("ok", false)), "Julia's real correction command completes")
	_check(str(model.data.village.childhood.screenplay.i02) == "complete", "Correction reaches complete")
	_check(not model.data.village.childhood.carried.has("neighbor_basket"), "Handover removes ownership exactly once")
	props.sync_state(model.data, actor)
	_check(not props.basket_in_hand() and not props.basket_node().is_visible_in_tree(), "Completed handover leaves no phantom basket")
	var completed_save: Dictionary = model.save_game(SAVE_PATH)
	_check(bool(completed_save.get("ok", false)), "Completed state saves")
	var completed = _load_from_path(SAVE_PATH)
	if completed != null:
		props.sync_state(completed.data, actor)
		_check(not props.basket_in_hand(), "Completed Save/Load stays basket-free")
		var malformed: Dictionary = completed.data.duplicate(true)
		malformed.village.childhood.carried.append("neighbor_basket")
		props.sync_state(malformed, actor)
		_check(not props.basket_in_hand(), "Even malformed completed input cannot resurrect a phantom")

	# The other authored branch: checking with Aurelia also completes exactly once.
	var checked = _load_correction()
	if checked != null:
		var candidate: Dictionary = checked.data.duplicate(true)
		candidate.village.childhood.screenplay.i02 = "pending"
		candidate.village.childhood.screenplay.i02_outcome = ""
		checked.data = candidate
		checked.set_player_position(Life.actor_position(checked.data, "aurelia"))
		var review: Dictionary = checked.execute("village_childhood_action", {"action_id":"basket_check"})
		_check(bool(review.get("ok", false)), "Aurelia's real basket review completes")
		_check(str(checked.data.village.childhood.screenplay.i02_outcome) == "checked", "Checked outcome is preserved")
		_check(not checked.data.village.childhood.carried.has("neighbor_basket"), "Checked handover removes the basket once")
		props.sync_state(checked.data, actor)
		_check(not props.basket_in_hand(), "Checked handover is also phantom-free")

	props.queue_free()
	actor.queue_free()
	await process_frame
	_cleanup()
	_finish()


func _contact_samples(props, actor, state: Dictionary) -> void:
	for phase: float in [0.0, 0.25, 0.5, 0.75]:
		actor.sample_pose("march", phase)
		props.sync_state(state, actor)
		await physics_frame
		await process_frame
		_check(props.basket_in_hand(), "Basket remains held at march phase %.2f" % phase)
		_check(props.attachment_error_m() < 0.001, "Handle follows animated wrist at phase %.2f" % phase)


func _lod_replacements(props, actor, state: Dictionary) -> void:
	var original_id: int = props.basket_node().get_instance_id()
	for level: int in [1, 2, 3, 0]:
		actor._reload(level)
		props.sync_state(state, actor)
		await process_frame
		_check(props.basket_node().get_instance_id() == original_id, "World-owned basket survives LOD %d" % level)
		_check(props.basket_in_hand(), "Basket rebinds after LOD %d" % level)
		_check(props.attachment_error_m() < 0.001, "Rebound handle remains within 1 mm at LOD %d" % level)
		var skeletons: Array[Node] = actor.body.find_children("*", "Skeleton3D", true, false)
		_check(not skeletons.is_empty() and (skeletons[0] as Skeleton3D).find_bone("Hand_L") >= 0, "Production Hand_L exists at LOD %d" % level)


func _check_original_asset(props) -> void:
	var node: Node3D = props.basket_node()
	_check(str(node.get_meta("source_model", "")) == "res://assets/legio/neighbour_basket.glb", "Presentation uses the registered original GLB")
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	_check(not meshes.is_empty(), "Original basket contains actual mesh geometry")
	var maximum_y := -INF
	for value: Node in meshes:
		var instance := value as MeshInstance3D
		_check(instance.mesh != null and instance.mesh.get_surface_count() > 0, "Basket mesh has a real surface")
		maximum_y = maxf(maximum_y, instance.get_aabb().end.y)
	_check(absf(maximum_y - 0.3083849549) < 0.0002, "Original braided handle height matches the GLB within 0.2 mm")


func _load_correction():
	var text := FileAccess.get_file_as_string(FIXTURE)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_check(false, "Cannot create isolated fixture save")
		return null
	file.store_string(text)
	file.close()
	return _load_from_path(SAVE_PATH)


func _load_from_path(path: String):
	var model = Model.new()
	var result: Dictionary = model.load_game(path)
	_check(bool(result.get("ok", false)), "Production save loads: " + str(result.get("message", "")))
	return model if bool(result.get("ok", false)) else null


func _cleanup() -> void:
	for path: String in [SAVE_PATH, SAVE_PATH + ".bak", SAVE_PATH + ".tmp", SAVE_PATH + ".bak.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("I02_PROPS_FAIL ", message)


func _finish() -> void:
	print("I02_PROPS_RESULT checks=%d failures=%d" % [checks, failures.size()])
	if failures.is_empty():
		print("I02_PROPS_PASS")
	quit(failures.size())
