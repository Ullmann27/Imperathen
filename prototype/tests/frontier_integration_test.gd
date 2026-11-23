extends SceneTree
## Actual MainScene/UI/world checks. Disposable user paths are mandatory.
const EntryScene = preload("res://main.tscn")
const Chapter = preload("res://scripts/story/frontier_chapter.gd")
const VillageLife = preload("res://scripts/story/village_life.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const OpeningStory = preload("res://scripts/story/opening_story.gd")
var checks := 0
var failures: Array[String] = []
var game


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		push_error("Run through tools/check_prototype.py with disposable XDG data/config/cache directories.")
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(960, 540)
	game = EntryScene.instantiate()
	root.add_child(game)
	await _frames()
	# Fixed calls below drive the real production process method deterministically.
	# The physics server still contains the actual collision/raycast scene.
	game.set_process(false)
	game.world.set_physics_process(false)
	game.ui._finish_intro()
	game.ui.action_requested.emit("new_game", {})
	await _frames()
	# Earlier groups share this disposable user directory and may leave a save.
	# Take the same replacement confirmation as a player instead of deleting it.
	if game.screen == "dialog":
		var can_replace := false
		for entry: Dictionary in game.ui._dialog_data.get("choices", []):
			can_replace = can_replace or entry.get("action", "") == "confirm_new_game"
		_check(can_replace, "Existing saved world offers the real new-life confirmation")
		if can_replace:
			game.ui.action_requested.emit("confirm_new_game", {})
			await _frames()
	_enter_opening("childhood_home")
	_check(game.screen == "playing" and game.model.data.player.age == 12 and Childhood.enabled(game.model.data), "Actual entry creates the new saved family childhood world")
	_load_legacy_village()
	_enter_opening("first_day")
	_check(game.world.population.actors.size() >= 16, "Main world contains the enlarged populated village")
	for npc_id: String in Chapter.NPCS:
		var actual: Vector3 = game.world.get_frontier_npc_position(npc_id)
		var expected := Chapter.npc_position(npc_id)
		_check(actual.is_finite() and Vector2(actual.x, actual.z).distance_to(Vector2(expected.x, expected.z)) < 0.01, "World and domain agree on the reachable speaker: " + npc_id)
	var before := _snapshot()
	game.world.action_requested.emit("frontier_talk", {"npc_id": "livia"})
	_check(game.screen == "playing" and _snapshot() == before, "Distant world event cannot open or book a conversation")
	if not await _open_resident("aulus"):
		_finish.call_deferred()
		return
	_check(game.ui._frontier_dialog_data.choices.is_empty() and game.ui._frontier_dialog_data.text.contains("zwölf"), "Child meets Aulus through the real Interact signal with age-appropriate dialogue")
	var clock: float = game.model.data.world_seconds
	var residents: Array = game.world.population.snapshot()
	game._process(20.0)
	_check(game.model.data.world_seconds == clock and game.world.population.snapshot() == residents, "Conversation freezes simulation and resident routines")
	await _check_dialog_layout(Vector2i(960, 540))
	await _check_dialog_layout(Vector2i(900, 900))
	_request_back()
	_check(game.screen == "playing" and game.world._frontier_focus.is_empty(), "Android Back closes the conversation and releases camera focus")
	game._pause()
	clock = game.model.data.world_seconds
	game._process(5.0)
	_check(game.model.data.world_seconds == clock, "Ordinary pause also stops world time")
	_request_back()
	_check(game.screen == "playing", "Android Back returns from pause without losing the story")
	await _complete_original_chapter()
	if not game.model.data.progress.chapter_complete:
		_finish.call_deferred()
		return
	game._refresh()
	_check(game.model.get_frontier_objective().npc_id == "livia", "Old chapter completion exposes the new first objective")
	_check(game.ui._hud_labels.objective_title.text == "Brot für die Straße", "HUD shows the new objective instead of the old completed-chapter placeholder")
	_check(not game.model.data.has("frontier_objective"), "Presentation objective never contaminates the authoritative save schema")
	if not await _open_resident("livia"):
		_finish.call_deferred()
		return
	await _check_dialog_layout(Vector2i(960, 540))
	await _check_dialog_layout(Vector2i(900, 900))
	before = _snapshot()
	game.ui.action_requested.emit("frontier_choice", {"npc_id": "cassian", "choice": "open"})
	game.ui.action_requested.emit("frontier_choice", {"npc_id": "livia", "choice": []})
	game.ui.action_requested.emit("frontier_choice", {"npc_id": "livia", "choice": "unavailable"})
	_check(_snapshot() == before and game.screen == "frontier_dialog", "Wrong speaker, malformed answer and unavailable answer leave the real modal recoverable")
	var grain: int = game.model.data.resources.grain
	var trust: int = game.model.data.companion.trust
	_press_choice("share")
	_check(game.model.data.resources.grain == grain - 2 and game.model.data.companion.trust == trust + 2, "Real Livia button commits cost and trust through Main")
	before = _snapshot()
	game.ui.action_requested.emit("frontier_choice", {"npc_id": "livia", "choice": "share"})
	_check(_snapshot() == before and game.screen == "frontier_dialog", "A stale second reply cannot spend the grain twice")
	_close_button()
	_check(game.screen == "playing" and game.ui._hud_labels.objective_title.text == "Was in der Liste steht", "Close button restores play and next objective")
	if not await _open_resident("cassian"):
		_finish.call_deferred()
		return
	_press_choice("letter")
	_close_button()
	if not await _open_resident("titus"):
		_finish.call_deferred()
		return
	_press_choice("work")
	_check(game.model.data.frontier.work_seconds == 0.0 and game.screen == "frontier_dialog", "Work choice stays in dialogue without silently advancing labour")
	game._process(15.0)
	_check(game.model.data.frontier.work_seconds == 0.0, "Leaving the work conversation open cannot complete the job")
	_close_button()
	_move(Vector3(3, 1, 29))
	game._process(5.0)
	_check(game.model.data.frontier.work_seconds == 0.0, "Running world away from the wagon earns no work")
	_move_to_resident("titus")
	game._process(5.0)
	game._refresh()
	_check(is_equal_approx(game.model.data.frontier.work_seconds, 5.0), "Five nearby simulation seconds produce five real work seconds")
	_check(game.ui._hud_labels.objective_text.text.contains("5/12"), "Visible objective shows actual partial work")
	game.ui.action_requested.emit("pause", {})
	game._process(20.0)
	_check(game.model.data.frontier.work_seconds == 5.0, "Pausing the real scene freezes partial work")
	_request_back()
	game.ui.action_requested.emit("save", {})
	game._show_menu()
	game.ui.action_requested.emit("continue", {})
	_check(game.screen == "playing" and game.model.data.frontier.work_seconds == 5.0, "Main Continue restores partial work and gameplay")
	_check(game.ui._hud_labels.objective_text.text.contains("5/12"), "Continue rebuilds the correct partial objective")
	var loaded: Dictionary = game.model._read_save(ProjectSettings.globalize_path(game.SAVE_PATH))
	_check(loaded.ok and not loaded.state.has("frontier_objective"), "Actual saved payload contains only authoritative story state")
	game._process(7.0)
	game._refresh()
	_check(game.model.data.frontier.step == 3 and game.model.data.frontier.work_seconds == 12.0, "Remaining seven seconds finish the work after reload")
	_check(game.ui._hud_labels.objective_title.text == "Ein eigener Weg", "Finished work points the HUD to Aulus")
	if not await _open_resident("aulus"):
		_finish.call_deferred()
		return
	await _check_dialog_layout(Vector2i(960, 540))
	_press_choice("craft")
	_close_button()
	if not await _open_resident("titus"):
		_finish.call_deferred()
		return
	var money: int = game.model.data.resources.denarii
	var handover := _find_button("FrontierChoice_handover")
	_check(handover != null, "Actual final reward button exists")
	if handover != null:
		handover.pressed.emit()
		# The old button can still have one queued activation before deferred deletion.
		handover.pressed.emit()
	_check(game.model.data.resources.denarii == money + 8 and game.model.data.frontier.completed, "Queued duplicate final activation pays exactly once")
	_close_button()
	_check(game.ui._hud_labels.objective_text.text.contains("Handwerk"), "Completed recommendation is named in the visible objective")
	game.ui.action_requested.emit("save", {})
	game._show_menu()
	game.ui.action_requested.emit("continue", {})
	_check(game.model.data.frontier.completed and game.model.data.frontier.vocation == "craft" and game.model.data.resources.denarii == money + 8, "Completed chapter, chosen vocation and exact payout survive the actual Continue path")
	_check(game.model._validate_state(game.model.data).is_empty(), "Integrated main/UI path preserves every strict world invariant")
	await _paid_alternative()
	_finish()


func _paid_alternative() -> void:
	_load_legacy_village()
	await _frames()
	_enter_opening("first_day")
	await _complete_original_chapter()
	if not game.model.data.progress.chapter_complete:
		return
	if not await _open_resident("livia"):
		return
	var grain: int = game.model.data.resources.grain
	_press_choice("reserve")
	_close_button()
	_check(game.model.data.resources.grain == grain, "Real reserve choice preserves owned grain")
	if not await _open_resident("cassian"):
		return
	_press_choice("open")
	_close_button()
	if not await _open_resident("titus"):
		return
	var money: int = game.model.data.resources.denarii
	_press_choice("pay")
	_check(game.model.data.resources.denarii == money - 4 and game.model.data.frontier.step == 3 and game.model.data.frontier.work_seconds == 0.0, "Paid branch debits four through UI without awarding fabricated labour")
	_close_button()


func _load_legacy_village() -> void:
	# The frontier chapter remains reachable for existing campaigns. Load an
	# explicit old-mode save, rather than fast-forwarding the new family story.
	var legacy := Model.new()
	legacy.new_game("italia", true, false)
	var saved: Dictionary = legacy.save_game(game.SAVE_PATH)
	_check(saved.get("ok", false) and not Childhood.enabled(legacy.data), "The frontier compatibility fixture is a valid saved legacy village")
	game._show_menu()
	game.ui.action_requested.emit("continue", {})
	_check(game.screen == "playing" and game.model.data.world_id == legacy.data.world_id and not Childhood.enabled(game.model.data), "Continue restores the explicit legacy village without inventing childhood progress")
	game._begin_opening(OpeningStory.sequence("italia"))


func _complete_original_chapter() -> void:
	_move(Vector3(-8, 1, 2))
	for count in 3:
		game.world.action_requested.emit("gather", {"node_id": "timber_0"})
	_move(Vector3(-3, 1, 4))
	game.world.action_requested.emit("companion_interact", {})
	game.ui.action_requested.emit("companion_help", {})
	game.world.action_requested.emit("build", {"x": 8.0, "z": 5.0})
	_move(Vector3(8, 1, 5))
	game._process(12.0)
	_complete_village_phase()
	_move(Vector3(0, 1, -7))
	game.ui.action_requested.emit("train", {})
	_enter_opening("adulthood")
	for hit in 3:
		game._process(0.65)
		game.world.action_requested.emit("training_hit", {})
	game.ui.action_requested.emit("recruit", {})
	game.ui.action_requested.emit("skirmish", {})
	for enemy: Dictionary in game.model.data.encounter.enemies.duplicate(true):
		_move(Vector3(enemy.x, 1, enemy.z))
		for strike in 3:
			game._process(0.65)
			if game.model.data.encounter.active:
				game.world.action_requested.emit("strike_enemy", {"enemy_id": enemy.id})
	_check(game.screen == "dialog" and game.model.data.progress.skirmish_won, "Existing prologue reaches victory through valid Main/world commands")
	game.ui.action_requested.emit("story_choice", {"choice": "protect"})
	_check(game.screen == "playing" and game.model.data.progress.chapter_complete and game.model.data.player.age == 18, "Existing consequence UI completes adulthood without a shortcut")
	await _frames()


func _open_resident(npc_id: String) -> bool:
	_move_to_resident(npc_id)
	await physics_frame
	game.ui.action_requested.emit("interact", {})
	await _frames()
	var opened: bool = game.screen == "frontier_dialog" and game.frontier_npc == npc_id
	_check(opened, "Actual Interact finds and opens visible resident " + npc_id)
	return opened


func _move_to_resident(npc_id: String) -> void:
	var actual: Vector3 = game.world.get_frontier_npc_position(npc_id)
	_move(actual + Vector3(0, 1.0, 1.5))


func _move(at: Vector3) -> void:
	game.world.get_node("Player").global_position = at
	game.world.get_node("Player").velocity = Vector3.ZERO
	game.model.set_player_position(at)
	game._refresh()


func _find_button(node_name: String) -> Button:
	return game.ui._screen.find_child(node_name, true, false) as Button


func _press_choice(choice: String) -> void:
	var button := _find_button("FrontierChoice_" + choice)
	_check(button != null and not button.disabled, "Real enabled dialogue button exists: " + choice)
	if button != null and not button.disabled:
		button.pressed.emit()


func _close_button() -> void:
	var button := _find_button("FrontierConversationClose")
	_check(button != null, "Conversation always has an explicit close control")
	if button != null:
		button.pressed.emit()


func _check_dialog_layout(size: Vector2i) -> void:
	root.size = size
	await _frames()
	await _frames()
	var panel := game.ui._screen.find_child("FrontierConversation", true, false) as Control
	var scroll := game.ui._screen.find_child("FrontierConversationScroll", true, false) as ScrollContainer
	_check(panel != null and scroll != null, "Conversation builds scrollable panel at " + str(size))
	if panel == null or scroll == null:
		return
	var safe := Rect2(Vector2.ZERO, Vector2(size))
	var bounds := panel.get_global_rect()
	_check(bounds.position.x >= -0.1 and bounds.position.y >= -0.1 and bounds.end.x <= safe.end.x + 0.1 and bounds.end.y <= safe.end.y + 0.1, "Panel stays inside actual viewport at " + str(size) + ": " + str(bounds))
	_check(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and scroll.follow_focus, "Mobile conversation wraps and follows focus")
	var close_button := _find_button("FrontierConversationClose")
	_check(close_button != null and close_button.size.y >= 44.0, "Touch close target remains usable at " + str(size))
	if close_button != null:
		scroll.ensure_control_visible(close_button)
		await _frames()
		var close_rect := close_button.get_global_rect()
		var visible_rect := scroll.get_global_rect()
		_check(close_rect.position.y >= visible_rect.position.y - 1 and close_rect.end.y <= visible_rect.end.y + 1, "Last exit control can be scrolled fully into view at " + str(size))


func _request_back() -> void:
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	root.go_back_requested.emit()


func _enter_opening(expected_sequence: String) -> void:
	var opened: bool = game.screen == "opening" and game.opening_sequence.get("id", "") == expected_sequence
	_check(opened, "Expected cinematic precedes the next playable phase: " + expected_sequence)
	if not opened:
		return
	var before := _snapshot()
	game.opening_overlay._request_skip()
	_check(game.screen == "opening" and bool(game.opening_sequence.beats[game.opening_index].get("final", false)), "Skipping keeps the explicit objective handoff: " + expected_sequence)
	game.opening_overlay._request_advance()
	_check(game.screen == "playing" and _snapshot() == before, "Accepting the objective releases play without changing the campaign: " + expected_sequence)


func _frames() -> void:
	for frame in 4:
		await process_frame


func _snapshot() -> String:
	return JSON.stringify(game.model.data)


func _check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)


func _finish() -> void:
	for failure in failures:
		printerr("FRONTIER_INTEGRATION_FAIL " + failure)
	print("FRONTIER_INTEGRATION_RESULT checks=%d failures=%d" % [checks, failures.size()])
	if failures.is_empty():
		print("FRONTIER_INTEGRATION_PASS")
	if is_instance_valid(game):
		game.free()
	quit(0 if failures.is_empty() else 1)


func _complete_village_phase() -> void:
	# Saved legacy villages require real encounters and a resolved first raid
	# before their adulthood/persistence scenario. Never inject completion flags.
	for npc_id: String in ["decimus", "aelia", "varro"]:
		var at: Vector2 = VillageLife.actor_position(game.model.data, npc_id)
		_move(Vector3(at.x, 1.0, at.y + 1.0))
		game.world.action_requested.emit("village_npc", {"npc_id":npc_id})
		_check(game.screen == "village_dialog" and game.model.data.village.social.npcs[npc_id].met, "Required village resident is met through the actual conversation gateway: " + npc_id)
		game.ui.action_requested.emit("resume", {})
	# This fixture observes the real loss branch from a safe position. It neither
	# creates a victory nor awards combat XP; the dedicated experience test fights.
	_move(Vector3(35.0, 1.0, 20.0))
	var saw_warning := false
	var saw_attack := false
	for step in 70:
		game._process(5.0)
		saw_warning = saw_warning or game.model.data.village.raid.status == "warning"
		saw_attack = saw_attack or game.model.data.village.raid.active
		if VillageLife.training_ready(game.model.data):
			break
	_check(saw_warning and saw_attack and game.model.data.village.raid.completed == 1, "The real warning and first village attack finish before adulthood")
	_check(VillageLife.training_ready(game.model.data) and game.model.data.village.social.seconds >= 2.0 * VillageLife.DAY_SECONDS, "Three encounters and two lived village days still satisfy the legacy training gate")
