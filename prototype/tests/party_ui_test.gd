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


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		quit(2)
		return
	output = OS.get_environment("IMPERATHEN_PARTY_CAPTURE_DIR")
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(960, 640)
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
	game.world._player.global_position = post
	game.world._companion.global_position = post + Vector3(1, 0, 0)
	game.world.village_life_world.actors.silvanus.global_position = post + Vector3(-1, -0.7, 0)
	game.model.capture_npc_observations()
	if not _click("Gefolge"):
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
		portrait._turn(16.0)
		_check(portrait.pivot.rotation.y != before, "Inspection rotates mesh")
	_click("Wahrnehmung üben")
	var training: Dictionary = game.model.data.world_state.party.members[uid]
	_check(game.screen == "playing" and training.order == "train", "Training returns to active simulation")
	if not output.is_empty():
		var camera := Camera3D.new()
		game.world.add_child(camera)
		camera.global_position = post + Vector3(2.4, 1.65, -4.5)
		camera.look_at(post + Vector3(0, .44, 0))
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
	await _capture("training")
	_check(game.ui.handle_back() and game.screen == "playing", "Android Back closes the folio")
	_finish()


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
