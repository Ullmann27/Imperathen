extends SceneTree
## Actual main-menu -> authored workshop -> same main-menu lifecycle.
## Never starts a new life or mutates a campaign save.
const Entry = preload("res://main.tscn")
const MixerTeardown = preload("res://tests/audio_mixer_teardown.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		quit(2)
		return
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("WORLD_WORKSHOP_ENTRY_FAIL ", label)

func _frames(count: int) -> void:
	for _index in count:
		await process_frame
		await physics_frame

func _save_receipt(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"

func _run() -> void:
	root.size = Vector2i(1280,720)
	var game = Entry.instantiate()
	root.add_child(game)
	await _frames(3)
	game.ui._finish_intro()
	await _frames(3)
	var before := JSON.stringify(game.model.data)
	var save_before := _save_receipt(game.SAVE_PATH)
	var backup_before := _save_receipt(game.SAVE_PATH + ".bak")
	var original_world: Node3D = game.world
	var button := game.ui.find_child("WorldWorkshopEntry",true,false) as Button
	_check(game.screen == "menu" and button != null and not button.disabled, "Actual main menu contains usable workshop action")
	if button != null:
		button.pressed.emit()
	await _frames(4)
	var workshop: Node3D = game._world_workshop
	_check(game.screen == "world_workshop" and is_instance_valid(workshop), "Main opens original WorldWorkshop scene")
	if is_instance_valid(workshop):
		_check(workshop.load_error.is_empty() and workshop.library.assets.size() == 7, "All seven authored asset families load")
		var tiers := 0
		for asset: Dictionary in workshop.library.assets.values():
			tiers += asset.meshes.size()
		_check(tiers == 21, "All 21 real LOD meshes imported")
		_check(workshop.camera.current and not (original_world.get_node("WorldCamera") as Camera3D).current, "Workshop owns the camera")
		_check(not original_world.visible and original_world.process_mode == Node.PROCESS_MODE_DISABLED, "Existing village is parked")
		_check(workshop.settlement.profile == game.ui.get_quality(), "Existing graphics preference preserved")
		for view in range(4):
			workshop.set_view_mode(view)
			_check(workshop.view_mode == view, "Existing workshop view %d selectable" % view)
		game._on_ui_action("world_workshop", {})
		_check(game._world_workshop == workshop, "Repeated entry cannot instantiate a second workshop")
		workshop._return()
		await _frames(4)
		_check(not is_instance_valid(workshop), "Return frees original workshop")
		_check(game.screen == "menu" and game.world == original_world and original_world.visible and (original_world.get_node("WorldCamera") as Camera3D).current, "Return restores same main scene, world and camera")
		game._on_ui_action("world_workshop", {})
		await _frames(4)
		_check(is_instance_valid(game._world_workshop), "Workshop can be reopened")
		game._on_go_back_requested()
		await _frames(4)
		_check(game.screen == "menu" and not is_instance_valid(game._world_workshop), "Android Back restores menu")
	_check(JSON.stringify(game.model.data) == before and not game.session_started, "Preview never changes authoritative campaign data")
	_check(_save_receipt(game.SAVE_PATH) == save_before and _save_receipt(game.SAVE_PATH + ".bak") == backup_before, "Save and backup unchanged")
	game.free()
	await process_frame
	await MixerTeardown.drain(self)
	print("WORLD_WORKSHOP_ENTRY_RESULT checks=%d failures=%d" % [checks,failures.size()])
	if failures.is_empty():
		print("WORLD_WORKSHOP_ENTRY_PASS")
	quit(0 if failures.is_empty() else 1)
