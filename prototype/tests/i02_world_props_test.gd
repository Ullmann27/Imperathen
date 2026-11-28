extends SceneTree
## Actual GameWorld wiring of the independently verified I02 presentation.
## No substitute rig is accepted: production CI stages the original civil youth.
const World = preload("res://scripts/world/game_world.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Life = preload("res://scripts/story/village_life.gd")
const FIXTURE := "res://tests/fixtures/mission_bridge_data/handoff_i02_correct_v5.json"
const LIMIT := .001
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("I02_WORLD_FAIL ", label)
	return condition

func _settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame

func _cleanup(path: String) -> void:
	for suffix: String in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))

func _fixture():
	var path := "user://i02_world_fixture_%s.json" % Time.get_ticks_usec()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not _check(file != null, "Isolated fixture can be opened"):
		return null
	file.store_string(FileAccess.get_file_as_string(FIXTURE))
	file.close()
	var model := Model.new()
	var result: Dictionary = model.load_game(path)
	_cleanup(path)
	return model if _check(bool(result.get("ok",false)), "Actual WorldModel migration and load") else null

func _check_anchor(world, props, key: String, label: String) -> void:
	_check(props.basket_in_hand(), label + ": actual basket is carried")
	var anchor: Vector3 = world.get_cinematic_anchor(key)
	var grip: Vector3 = props.grip_world()
	_check(anchor.is_finite() and grip.is_finite() and anchor.distance_to(grip) < LIMIT, label + ": camera uses actual global handle")
	var actor = world.get_cinematic_figure("player")
	var rigs: Array[Node] = actor.body.find_children("*","Skeleton3D",true,false)
	if not _check(rigs.size() == 1, label + ": original imported rig"):
		return
	var rig := rigs[0] as Skeleton3D
	var bone := rig.find_bone("Hand_L")
	if not _check(bone >= 0, label + ": real Hand_L exists"):
		return
	var wrist := rig.global_transform * rig.get_bone_global_pose(bone).origin
	_check(wrist.is_finite() and grip.is_finite() and wrist.distance_to(grip) < LIMIT, label + ": real wrist-to-handle contact within 1 mm")

func _move_to(world, model, npc: String) -> void:
	var point: Vector2 = Life.actor_position(model.data,npc)
	var target := Vector3(point.x,float(model.data.player.position[1]),point.y)
	world.get_node("Player").position = target
	model.set_player_position(target)

func _absent(world, props, label: String) -> void:
	_check(not props.basket_in_hand() and not props.basket_node().is_visible_in_tree(), label + ": no visible phantom basket")
	_check(not world.get_cinematic_anchor("i02_basket").is_finite() and not world.get_cinematic_anchor("i02_correct").is_finite(), label + ": no fabricated prop anchor")

func _run() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		quit(2)
		return
	var model = _fixture()
	if model == null:
		_finish()
		return
	var world := World.new()
	root.add_child(world)
	var before := JSON.stringify(model.data)
	world.setup(model.data)
	world.set_process(false)
	world.set_physics_process(false)
	var actor = world.get_cinematic_figure("player")
	actor.set_process(false)
	actor.set_physics_process(false)
	if not _check(actor.youth_outfit == "civil" and actor.active_model_path == actor.youth_path(actor.detail), "Exact staged original civil youth used in the live world"):
		world.free()
		_finish()
		return
	var props = world.i02_props
	if not _check(is_instance_valid(props) and props.get_parent() == world, "GameWorld owns exactly one I02 container"):
		world.free()
		_finish()
		return
	await _settle()
	_check(JSON.stringify(model.data) == before, "Setup and presentation do not mutate the authoritative state")
	if not _check(is_instance_valid(props.basket_node()), "Actual original basket instantiated from the saved correction"):
		world.free()
		_finish()
		return
	var item: Node3D = props.basket_node()
	var identity := item.get_instance_id()
	_check(str(item.get_meta("source_model","")) == "res://assets/legio/neighbour_basket.glb", "Original GLB, not an invented model")
	_check_anchor(world,props,"i02_correct","Migrated correction")
	actor.sample_pose("march",.25)
	await _settle()
	_check_anchor(world,props,"i02_correct","Animated wrist")

	# The anchor is already world-space; a translated world must not add its
	# translation twice. Restore the physical fixture before domain commands.
	var old_grip: Vector3 = props.grip_world()
	var translation := Vector3(3.0,0.0,-2.0)
	world.position += translation
	await _settle()
	_check_anchor(world,props,"i02_correct","Translated world")
	_check(props.grip_world().distance_to(old_grip+translation) < LIMIT,"Translation is applied exactly once")
	world.position -= translation
	await _settle()

	for lod: int in [1,2,3,0]:
		actor._reload(lod)
		actor.sample_pose("march",.35)
		await _settle()
		_check(actor.detail == lod and actor.active_model_path == actor.youth_path(lod),"Exact original civil LOD %d" % lod)
		_check(item.get_instance_id() == identity and item.get_parent() == props and props.get_child_count() == 1,"World-owned item survives LOD %d without duplicate" % lod)
		_check_anchor(world,props,"i02_correct","LOD %d" % lod)

	var saved_path := "user://i02_world_restore_%s.json" % Time.get_ticks_usec()
	var saved: Dictionary = model.save_game(saved_path)
	_check(bool(saved.get("ok",false)), "Real correction save")
	var restored := Model.new()
	var loaded: Dictionary = restored.load_game(saved_path)
	_cleanup(saved_path)
	if _check(bool(loaded.get("ok",false)),"Real correction reload"):
		model = restored
		world.setup(model.data)
		await _settle()
		_check(props.basket_node().get_instance_id() == identity and props.get_child_count() == 1,"Save/Load retains the same single world object")
		_check_anchor(world,props,"i02_correct","Restored correction")

	_move_to(world,model,"julia")
	var corrected: Dictionary = model.execute("village_childhood_action",{"action_id":"basket_correct"})
	_check(bool(corrected.get("ok",false)) and model.data.village.childhood.screenplay.i02 == "complete","Actual Julia correction completes")
	world.sync_state(model.data)
	_absent(world,props,"Julia handover")
	var checked = _fixture()
	if checked == null:
		world.free()
		_finish()
		return
	checked.data.village.childhood.screenplay.i02 = "pending"
	checked.data.village.childhood.screenplay.i02_outcome = ""
	_check(checked._validate_state(checked.data).is_empty(),"Actual pending branch fixture remains valid")
	world.setup(checked.data)
	await _settle()
	_check_anchor(world,props,"i02_basket","Aurelia pending")
	_move_to(world,checked,"aurelia")
	var reviewed: Dictionary = checked.execute("village_childhood_action",{"action_id":"basket_check"})
	_check(bool(reviewed.get("ok",false)) and checked.data.village.childhood.screenplay.i02_outcome == "checked","Actual Aurelia check completes")
	world.sync_state(checked.data)
	_absent(world,props,"Aurelia handover")
	var fresh := Model.new()
	fresh.new_game("italia",true,true)
	world.setup(fresh.data)
	_absent(world,props,"New childhood before pickup")
	var legacy := Model.new()
	legacy.new_game("italia",true)
	world.setup(legacy.data)
	_absent(world,props,"Legacy game")
	_check(not props.visible and not props.is_processing() and not props.is_physics_processing(),"Legacy presentation is disabled without extra frame work")
	world.free()
	_finish()

func _finish() -> void:
	print("I02_WORLD_RESULT checks=%d failures=%d" % [checks,failures.size()])
	print("I02_WORLD_PASS" if failures.is_empty() else "I02_WORLD_FAIL")
	quit(0 if failures.is_empty() else 1)
