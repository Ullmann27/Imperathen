extends SceneTree
## Production Main/UI/world integration. Scene travel uses explicit fixture
## positions; separate physics tests and the Android harness exercise movement.

const Entry = preload("res://main.tscn")
const Childhood = preload("res://scripts/story/childhood_story.gd")
const Neighborhood = preload("res://scripts/world/village/childhood_neighborhood.gd")
const Diagnostics = preload("res://scripts/ui/android_village_diagnostics.gd")
var game
var observer
var checks := 0
var failures: Array[String] = []
var capture_dir := ""


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("Use a disposable XDG account and IMPERATHEN_ISOLATED_TEST=1.")
		quit(2)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	if not capture_dir.is_empty() and (not capture_dir.is_absolute_path() or DisplayServer.get_name() == "headless"):
		printerr("Screenshots require a graphical renderer and an absolute output directory.")
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	var settings := ConfigFile.new()
	settings.set_value("input", "touch_controls", true)
	settings.save("user://imperathen_ui.cfg")
	game = Entry.instantiate()
	root.add_child(game)
	await _frames()
	game.set_process(false)
	game.world.set_physics_process(false)
	game.ui._finish_intro()
	game.ui.action_requested.emit("new_game", {})
	_check(game.screen == "opening" and game.opening_sequence.id == "childhood_first_day", "Actual New Life uses the family opening")
	game._opening_skip()
	game._opening_next()
	await _frames()
	_check(game.screen == "playing" and Childhood.enabled(game.model.data), "The final opening objective hands control to the authored childhood")
	observer = Diagnostics.new()
	observer.session = game
	game.add_child(observer)
	observer.set_process(false)
	var observed: Dictionary = observer.snapshot()
	_check(observed.childhood.day == 1 and observed.childhood.age == 12 and observed.actors == 15, "Read-only Android diagnostics expose the real child and existing residents")
	_check(observed.childhood.objective.npc_id == "julia", "The first real objective points to the mother")
	_check(observed.controls.has("movement") and observed.controls.has("interact"), "Native movement and interaction geometry are observable")
	_check(game.ui.get("_hud_labels").time.text == "TAG 1 · Morgen", "The HUD uses the authored German day and phase")
	_check(game.world.childhood_neighborhood.snapshot().houses.size() == 3, "The family, neighbors and smith have actual interiors")
	await _capture("01-childhood-home")
	game.ui.action_requested.emit("village_panel", {})
	await _frames()
	var village_text := _text(game.ui)
	_check(game.screen == "village_panel" and village_text.contains("Dorftag 1"), "The actual village panel shares the authored day")
	_check(village_text.contains("14 lebende Einwohner") and not village_text.contains("zwei Spielminuten"), "The panel reports living people and explicit sleep instead of the old timer")
	root.go_back_requested.emit()
	_check(game.screen == "playing", "Back returns from the child village overview")

	var before: String = _state()
	game.ui.action_requested.emit("train", {})
	game.world.action_requested.emit("build", {"x":8.0,"z":4.0})
	_check(_state() == before and game.model.data.player.age == 12, "Old training and building inputs cannot bypass the childhood")
	_move(Vector3(-5,1.0,28.3))
	var nav: Dictionary = game.world.childhood_navigation()
	_check(nav.available and str(nav.label).begins_with("Hauseingang"), "An indoor goal first guides the player to its usable doorway")
	_move(Vector3(-1.6,1.0,24.9))
	_check(not game.world.can_talk_childhood("julia"), "The external side wall prevents a near-distance conversation")
	await _step("family_morning", "promise", "father_lunch")
	_check(game.model.data.village.childhood.cargo.meal == 2, "The actual choice puts the two purchased rations in the basket")
	var after_promise: Dictionary = game.model.data.duplicate(true)
	game._show_menu()
	game._continue_game()
	_check(game.screen == "playing" and game.model.data.village.childhood.scene_id == "father_lunch", "Continue restores the actual accepted first task")
	_check(JSON.parse_string(JSON.stringify(game.model.data)) == JSON.parse_string(JSON.stringify(after_promise)), "Restart adds neither a day nor a second basket payment")
	await _frames()
	game.ui.action_requested.emit("childhood_open", {})
	await _frames()
	var journal_text := _text(game.ui)
	_check(game.screen == "childhood_journal" and journal_text.contains("Den Korb übernehmen") and not journal_text.contains("family_morning"), "The journal renders the chosen human sentence instead of internal IDs")
	var frozen := _state()
	game._process(20.0)
	_check(_state() == frozen, "Reading the childhood journal freezes simulation")
	root.go_back_requested.emit()
	_check(game.screen == "playing", "Android Back closes the childhood journal")
	await _step("father_lunch", "deliver", "friend_well")
	await _step("friend_well", "join", "well_search")
	_check(game.world.get_node("WorldCamera").global_transform.is_finite(), "Marcus dialogue leaves a finite camera even though he uses the companion actor")
	await _step("well_search", "inspect", "friend_return")
	await _step("friend_return", "return", "day1_evening")
	await _step("day1_evening", "tell", "day1_sleep")
	_check(game.model.data.village.childhood.day == 1, "Finishing errands alone does not finish the day")
	await _step("day1_sleep", "sleep", "father_invitation")
	_check(game.model.data.village.childhood.day == 2 and game.model.data.player.age == 12, "The actual bed choice opens the second morning without an age jump")
	await _step("father_invitation", "ask", "smith_first")
	await _step("smith_first", "help", "smith_material")
	await _step("smith_material", "take", "smith_work")
	var money_before := int(game.model.data.resources.denarii)
	await _step("smith_work", "careful", "smith_account")
	_check(int(game.model.data.resources.denarii) == money_before + 1, "The real smith-work choice credits exactly one denarius")
	await _step("smith_account", "truth", "day2_evening")
	await _capture("03-smith-workshop")

	var market: Vector2 = Childhood.actor_position(game.model.data,"cassia")
	_move(Vector3(market.x,1.0,market.y-1.0))
	game.world.action_requested.emit("village_npc", {"npc_id":"cassia"})
	await _frames()
	_check(game.screen == "village_dialog", "The real market resident opens her existing conversation")
	_press_named("FrontierChoice_open_trade")
	await _frames()
	_check(game.screen == "trade_dialog", "Cassia's actual conversation button opens priced trade")
	var trade_view: Dictionary = game.VillageTrade.view(game.model.data)
	var buy: Dictionary = {}
	for item: Dictionary in trade_view.choices:
		if item.command == "village_trade_buy" and item.args.resource == "grain" and item.enabled:
			buy = item
			break
	_check(not buy.is_empty(), "The smith's wage can buy an actual offered grain quantity")
	if not buy.is_empty():
		var stock_before := int(game.model.data.resources.grain)
		_press_named("FrontierChoice_" + str(buy.id))
		await _frames()
		_check(game.model.data.resources.grain == stock_before + int(buy.args.quantity), "The visible buy button transfers the advertised real goods")
	var trading_state := _state()
	game._process(30.0)
	_check(_state() == trading_state, "The trade panel holds both the economy and the story clock")
	await _capture("04-cassia-trade")
	root.go_back_requested.emit()
	_check(game.screen == "playing", "Android Back returns from trade")
	root.size = Vector2i(900,920)
	await _frames()
	game.ui.action_requested.emit("childhood_open", {})
	await _frames()
	var screen_control: Control = game.ui.get("_screen")
	_check(screen_control.get_global_rect().size.x <= 900.1, "The childhood journal adapts to a square logical display")
	root.go_back_requested.emit()
	game.queue_free()
	await _frames()
	print("CHILDHOOD_EXPERIENCE_RESULT checks=%d failures=%d" % [checks,failures.size()])
	for failure: String in failures:
		printerr(failure)
	print("CHILDHOOD_EXPERIENCE_PASS" if failures.is_empty() else "CHILDHOOD_EXPERIENCE_FAIL")
	quit(0 if failures.is_empty() else 1)


func _step(scene_id: String, choice: String, expected: String) -> void:
	_check(game.model.data.village.childhood.scene_id == scene_id, "Expected current scene: " + scene_id)
	var objective: Dictionary = game.model.get_childhood_objective()
	var p := Vector2(float(objective.position[0]),float(objective.position[1]))
	_move(Vector3(p.x-0.65,Neighborhood.floor_height_at(p)+0.95,p.y+0.65))
	await _frames()
	game.world.action_requested.emit("childhood_interact", {"npc_id":objective.npc_id})
	await _frames()
	_check(game.screen == "childhood_dialog", "Actual spatial dialogue opens: " + scene_id)
	var held := _state()
	game._process(3.0)
	_check(_state() == held, "The dialogue holds simulation: " + scene_id)
	if scene_id == "family_morning":
		await _capture("02-julia-dialogue")
	_press_named("FrontierChoice_" + choice)
	await _frames()
	_check(game.model.data.village.childhood.scene_id == expected, "The real choice advances once: " + choice)
	_check(game.model._read_save(ProjectSettings.globalize_path(game.SAVE_PATH)).ok, "The accepted choice has a validated on-disk save")
	root.go_back_requested.emit()
	_check(game.screen == "playing", "Back returns to the village after: " + scene_id)
	await _frames()


func _move(position: Vector3) -> void:
	game.world.get_node("Player").position = position
	game.model.set_player_position(position)
	game.world.sync_state(game.model.data)
	game.world._update_camera(0.05)


func _press_named(name: String) -> void:
	var button: Button = game.ui.find_child(name,true,false)
	_check(button != null and button.is_visible_in_tree() and not button.disabled, "An enabled live button exists: " + name)
	if button != null and not button.disabled:
		button.pressed.emit()


func _text(node: Node) -> String:
	var result := ""
	if node is Label or node is RichTextLabel:
		result += str(node.text) + "\n"
	for child: Node in node.get_children():
		result += _text(child)
	return result


func _state() -> String:
	return JSON.stringify(game.model.data)


func _frames(count := 4) -> void:
	for index in count:
		await process_frame


func _capture(name: String) -> void:
	if capture_dir.is_empty(): return
	await _frames(6)
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	_check(not picture.is_empty() and picture.save_png(capture_dir.path_join(name+".png")) == OK, "Real rendered capture saved: " + name)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
