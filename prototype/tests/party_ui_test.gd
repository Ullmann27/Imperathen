extends SceneTree
## Real Main / world / controls. Fixture placement between conversations and at the
## practice post isolates the UI transaction from the separate navigation test.

const Main = preload("res://scripts/main.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const Support = preload("res://tests/i03_support.gd")
const Party = preload("res://scripts/domain/travel_party.gd")

var game
var checks := 0
var failures := []
var output := ""
var frames := ""


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		quit(2)
		return
	output = OS.get_environment("IMPERATHEN_PARTY_CAPTURE_DIR")
	frames = OS.get_environment("IMPERATHEN_PARTY_FRAMES")
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(960, 640) if frames.is_empty() else Vector2i(720, 404)
	game = Main.new()
	root.add_child(game)
	await process_frame
	game.model.new_game("italia", true, true, false, true)
	var observations: Callable = game.model.npc_observations
	game.model.npc_observations = Callable()
	for i in 80:
		if game.model.data.companion.met:
			break
		var view: Dictionary = Childhood.view(game.model.data)
		var result: Dictionary
		if str(view.stage).begins_with("i03_"):
			result = Support.play_stage(game.model)
		else:
			Support.place_player(game.model, view.point)
			var npc := str(view.get("target_npc", ""))
			if not npc.is_empty() and not Childhood.relationship(game.model.data, npc).get("met", false):
				game.model.execute("village_talk", {"npc_id":npc,"choice":"meet"})
			view = Childhood.view(game.model.data)
			var action: String = "basket_check" if view.stage == "i02_basket" else view.actions[0].payload.action_id
			result = game.model.execute("village_childhood_action", {"action_id":action})
		if not _check(result.ok, "Story stage " + str(view.stage) + " " + str(result.message)):
			_finish()
			return
	if not _check(game.model.data.companion.met and game.model.data.companion.choice == "help", "Regular I-03 friendship"):
		_finish()
		return
	var tree_node: Dictionary = game.model.data.resource_nodes[0]
	game.model.set_player_position(Vector3(tree_node.x, 1, tree_node.z))
	_check(game.model.execute("gather", {"node_id":tree_node.id}).ok, "Wood from actual stock")
	if not output.is_empty() or not frames.is_empty():
		# Daylight for a repeatable review camera. Fixture booking uses the world clock.
		var clock = preload("res://scripts/domain/world_clock.gd")
		clock.book(game.model.data, "wait", 5 * 3600, "Prüfansicht am Vormittag")
	game.model.npc_observations = observations
	game.session_started = true
	game.world.show()
	game.world.setup(game.model.data)
	game.ui._touch_enabled = true
	game._resume()
	for npc: String in ["marcus","silvanus"]:
		var actor: Node3D = game.world._story_companions.actor(npc)
		game.world._player.global_position = actor.global_position + Vector3(1, 0.85, 0)
		if npc == "marcus":
			game._show_companion()
		else:
			game._show_village_npc(npc)
		if not _click("Um persönliche Begleitung bitten"):
			_finish()
			return
		_check(game.screen == "playing", "Invitation returns to play")
	if not _check(game.model.party_view().members.size() == 2, "Two companions via the dialogue choices"):
		_finish()
		return
	var post := Vector3(Party.POST.x, 1, Party.POST.y)
	game.world._player.global_position = post + Vector3(0, 0, 1.85)
	game.world._companion.global_position = post + Vector3(1.3, -1, .65)
	game.world.village_life_world.actors.silvanus.global_position = post + Vector3(-1.4, -1, .85)
	game.model.capture_npc_observations()
	await process_frame
	var dock: Button = game.ui._screen.find_child("PartyQuickOrders", true, false)
	if not _check(is_instance_valid(dock), "Touch action in the normal HUD"):
		_finish()
		return
	for press in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 3
		touch.pressed = press
		touch.position = dock.get_global_rect().get_center() if is_instance_valid(dock) else Vector2.ZERO
		root.push_input(touch, true)
	if not _check(game.screen == "party_wheel", "ScreenTouch opens the command wheel"):
		_finish()
		return
	await _capture("befehlsrad")
	if not _click("Warten"):
		_finish()
		return
	for person: Dictionary in game.model.party_view().members:
		_check(person.order == "wait", "Group request reaches " + str(person.name))
	_click("Gefolge")
	_click("Gefährten ansehen")
	var picker: OptionButton = game.ui._screen.find_child("PartyTarget", true, false)
	_check(picker != null and picker.item_count == 2, "Picker has both actual people")
	_click("Wanderstab geben")
	var uid: String = game.ui.party_target
	var member: Dictionary = game.model.data.world_state.party.members[uid]
	_check(member.equipment.get("tool") == "walking_staff", "Individual inventory accepts staff")
	var figure: Node3D = game.world.get_cinematic_figure(Party.local_id(game.model.data, uid))
	_check(figure.find_child("Party_walking_staff", true, false) != null, "The equipped item is visible on the live owner")
	await _capture("ausruestung")
	var portrait = game.ui._screen.find_child("PartyPortrait", true, false)
	if _check(portrait != null, "Live 3D preview"):
		var before: float = portrait.pivot.rotation.y
		var contact := InputEventScreenTouch.new()
		contact.index = 7
		contact.pressed = true
		portrait._gui_input(contact)
		var drag := InputEventScreenDrag.new()
		drag.index = 7
		drag.relative = Vector2(16, 0)
		portrait._gui_input(drag)
		contact.pressed = false
		portrait._gui_input(contact)
		_check(portrait.pivot.rotation.y != before, "Touch drag rotates the inspection mesh")
	_click("Wahrnehmung üben")
	var training: Dictionary = game.model.data.world_state.party.members[uid]
	_check(game.screen == "playing" and training.order == "train", "Training returns to active simulation")
	if not output.is_empty():
		var camera := Camera3D.new()
		game.world.add_child(camera)
		camera.global_position = post + Vector3(-.25, 1.43, 5.8)
		camera.look_at(post + Vector3(0, -.06, .80))
		camera.fov = 39
		camera.current = true
		game.world.set_presentation_time(4.0)
		game.ui.hide()
		await _capture("uebungsplatz")
		game.ui.show()
		camera.queue_free()
		game.world._camera.current = true
	game.model.advance(Party.LESSON_SECONDS)
	_check(int(game.model.data.world_state.party.members[uid].skills.get("perception",0)) == 1, "Attended practice earns the skill")
	_click("Gefolge")
	_click("Gefährten ansehen")
	if not output.is_empty():
		await process_frame
		var scroll := game.ui._screen.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
		var training_button := game.ui._screen.find_child("Wahrnehmung üben", true, false) as Button
		if training_button:
			scroll.ensure_control_visible(training_button)
	await _capture("training")
	_check(game.ui.handle_back() and game.screen == "playing", "Android Back closes the folio")
	if not frames.is_empty() and failures.is_empty():
		await _film(post, uid)
	if output.is_empty() and frames.is_empty():
		for profile: String in ["low","balanced","very_high"]:
			game.world.set_quality(profile)
			for level in [3,0]:
				figure._reload(level)
				var attached := figure.find_children("Party_walking_staff","BoneAttachment3D",true,false)
				_check(attached.size() == 1, "%s LOD %d keeps exactly one staff" % [profile,level])
		await _test_compact_layout()
		_test_legacy_friend()
	_finish()


func _test_legacy_friend() -> void:
	game.model.new_game("germania")
	var node: Dictionary = game.model.data.resource_nodes[0]
	game.model.set_player_position(Vector3(node.x, 1, node.z))
	_check(game.model.execute("gather", {"node_id":node.id}).ok, "Legacy friend's existing introduction cost")
	game.model.set_player_position(Vector3(-3, 1, 4))
	_check(game.model.execute("choose_companion", {"choice":"help"}).ok, "Existing regional introduction")
	game.world.setup(game.model.data)
	game._resume()
	game._show_companion()
	if not _click("Um persönliche Begleitung bitten"):
		return
	var members: Array = game.model.party_view().members
	if not _check(members.size() == 1, "Non-Italian legacy friend personally joins"):
		return
	_check(members[0].actor_uid == Party.FRIEND and str(members[0].name).to_lower() == str(game.model.data.companion.id), "Origin's original companion name and UID")
	_click("Gefolge")
	_click("Gefährten ansehen")
	_check(game.ui._screen.find_child("PartyPortrait",true,false) != null, "Existing non-Italian friend gets the same three-dimensional inspection")


func _test_compact_layout() -> void:
	for actual: Vector2i in [Vector2i(400, 800), Vector2i(800, 400)]:
		root.size = actual
		await process_frame
		game._show_party("party_wheel")
		await process_frame
		var rects := []
		for id: String in ["follow","assist","home","wait"]:
			var button: Button = game.ui._screen.find_child("Order_" + id, true, false)
			var rect := button.get_global_rect()
			_check(rect.size.x >= 48 and rect.size.y >= 48, "Comfortable touch area " + id)
			for other: Rect2 in rects:
				_check(not rect.intersects(other), "Distinct wheel targets " + str(actual))
			rects.append(rect)
		game._show_party("party_folio")
		await process_frame
		var portrait = game.ui._screen.find_child("PartyPortrait", true, false)
		_check(portrait != null and (portrait.get_parent() as BoxContainer).vertical == (game.ui._area().x < 520), "Responsive companion portrait " + str(actual))
		game.ui.handle_back()


## A continuous engine take at 12 fps. Only the initial blocking and camera
## are fixture placements. Frames after the first use real movement, a gear
## transaction and a second supervised lesson in the running campaign.
func _film(post: Vector3, uid: String) -> void:
	if not _check(DisplayServer.get_name() != "headless", "Movie needs a graphical renderer"):
		return
	DirAccess.make_dir_recursive_absolute(frames)
	game.world.set_quality("low")
	game.world._player.global_position = post + Vector3(.15, 0, 1.65)
	game.world._companion.global_position = post + Vector3(2.6, -1, .9)
	game.world.village_life_world.actors.silvanus.global_position = post + Vector3(-2.45, -1, .9)
	game.model.capture_npc_observations()
	if not _check(game._command("party_equip", {"actor_uid":uid,"item_id":"walking_staff"}).ok, "Staff returned before demonstration"):
		return
	game._command("party_order", {"actor_uid":"all","order":"follow"})
	var camera := Camera3D.new()
	game.world.add_child(camera)
	camera.global_position = post + Vector3(.85, 1.28, 6.0)
	camera.look_at(post + Vector3(0, -.12, 1.0))
	camera.fov = 44
	camera.current = true
	game.ui.hide()
	game.world._camera_yaw = 0
	game.world.set_touch_move(Vector2(-.55, -.12))
	var completed_before := int(game.model.data.world_state.party.members[uid].skills.get("endurance", 0))
	var begin: Vector3 = game.world._companion.global_position
	for index in 108:
		if index == 10:
			game.world.set_touch_move(Vector2.ZERO)
		if index == 22:
			_check(game.world._companion.global_position.distance_to(begin) > .25, "Visible companion walks")
			_check(game._command("party_equip", {"actor_uid":uid,"item_id":"walking_staff"}).ok, "Live equipment change")
		if index == 29:
			_check(game._command("party_train", {"actor_uid":uid,"skill":"endurance"}).ok, "Live supervised lesson")
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		if frame == null or frame.save_png(frames.path_join("frame_%03d.png" % index)) != OK:
			_check(false, "Frame readback failed at %d" % index)
			break
	_check(int(game.model.data.world_state.party.members[uid].skills.get("endurance",0)) > completed_before, "Filmed practice completed through physics time")
	print("PARTY_MOVIE frames=108 fps=12")


func _click(caption: String) -> bool:
	for button: Button in game.ui._screen.find_children("*", "Button", true, false):
		if button.text == caption and button.is_visible_in_tree() and not button.disabled:
			button.pressed.emit()
			return _check(true, caption)
	return _check(false, "Missing visible button " + caption + " on " + str(game.screen))


func _capture(id: String) -> void:
	if output.is_empty():
		return
	if not _check(DisplayServer.get_name() != "headless", "A real display is used for captures"):
		return
	DirAccess.make_dir_recursive_absolute(output)
	for frame in 3:
		await process_frame
	RenderingServer.force_draw(true)
	var picture := root.get_texture().get_image()
	_check(picture != null and not picture.is_empty() and picture.save_webp(output.path_join(id + ".webp"), false, 0.92) == OK, "Screenshot " + id)


func _check(value: bool, description: String) -> bool:
	checks += 1
	if not value:
		failures.append(description)
		printerr("FAIL ", description)
	return value


func _finish() -> void:
	print("PARTY_UI_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("PARTY_UI_PASS" if failures.is_empty() else "PARTY_UI_FAIL")
	game.queue_free()
	quit(0 if failures.is_empty() else 1)
