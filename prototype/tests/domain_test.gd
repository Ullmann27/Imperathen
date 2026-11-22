extends SceneTree
## Run without the game scene:
## godot --headless --path prototype --script res://tests/domain_test.gd

const WorldModel = preload("res://scripts/domain/world_model.gd")

var checks := 0
var failures: Array[String] = []
var suites := 0
var test_directory := "user://domain_tests_%s" % Time.get_ticks_usec()


func _initialize() -> void:
	_run()


func _run() -> void:
	_test_initial_state_and_invalid_input()
	_test_atomic_gather_and_idempotency()
	_test_companion_choices()
	_test_build_placement_and_real_work()
	_test_single_worker_and_delta_partition()
	_test_age_training_and_recruitment()
	_test_combat_and_persistent_losses()
	_test_story_branches_and_terminal_death()
	_test_save_roundtrip_and_command_replay()
	_test_backup_and_interrupted_save()
	_test_invalid_saves_do_not_replace_live_state()
	_test_save_failure_preserves_previous_file()
	_cleanup_directory()
	print("DOMAIN_TEST_RESULT suites=%d checks=%d failures=%d" % [suites, checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	print("DOMAIN_TEST_PASS" if failures.is_empty() else "DOMAIN_TEST_FAIL")
	quit(0 if failures.is_empty() else 1)


func _test_initial_state_and_invalid_input() -> void:
	_suite("initial state, finite input and rejected command atomicity")
	var model = WorldModel.new()
	_check(model.data.player.position == [0.0, 1.0, 8.0], "Start position matches the shared API")
	_check(model.data.player.age == 12 and model.data.resources.wood == 0, "No pre-awarded adult status or wood")
	_check(model.data.resource_nodes.size() == 3 and model.data.population.workers == 4, "Source and labour pools exist")
	var before := _snapshot(model)
	_check(not model.execute("gather", {"node_id": "timber_0"}).ok, "Gathering from the start position is too far away")
	_check(_snapshot(model) == before, "Rejected distant gathering changes nothing")
	for args in [{"x": NAN, "z": 3.0}, {"x": INF, "z": 3.0}, {"x": "8", "z": 3.0}, {"x": 8.0}]:
		_check(not model.execute("build", args).ok, "Non-finite, text or incomplete coordinates rejected")
	_check(not model.execute("gather", {"node_id": "timber_0", "amount": 400}).ok, "Caller cannot choose a hidden gather amount")
	_check(not model.execute("receive_damage", {"amount": -8}).ok, "Negative damage cannot heal")
	_check(not model.execute("receive_damage", {"amount": 1.5}).ok, "Fractional damage is rejected")
	_check(not model.execute("unknown", {}).ok, "Unknown command rejected")
	model.set_player_position(Vector3(NAN, 1.0, 0.0))
	model.set_player_position(Vector3(201.0, 1.0, 0.0))
	for delta in [0.0, -1.0, NAN, INF, 3601.0]:
		model.advance(delta)
	_check(_snapshot(model) == before, "Rejected commands, positions and deltas are all non-mutating")


func _test_atomic_gather_and_idempotency() -> void:
	_suite("resource conservation and durable command identities")
	var model = WorldModel.new()
	model.set_player_position(Vector3(-8.0, 1.0, 2.0))
	var first: Dictionary = model.execute("gather", {"node_id": "timber_0"}, "gather-once")
	_check(first.ok, "First gathering succeeds")
	var after := _snapshot(model)
	_check(model.execute("gather", {"node_id": "timber_0"}, "gather-once") == first, "Repeated ID returns the original result")
	_check(_snapshot(model) == after, "Repeated ID never debits or awards again")
	_check(not model.execute("gather", {"node_id": "timber_1"}, "gather-once").ok, "Same ID with different payload is rejected")
	_check(_snapshot(model) == after, "Conflicting ID leaves the world unchanged")
	for index in 3:
		_check(model.execute("gather", {"node_id": "timber_0"}).ok, "Remaining wood can be collected")
	_check(model.data.resources.wood == 16 and model.data.resource_nodes[0].amount == 0, "Source loss equals inventory gain")
	after = _snapshot(model)
	_check(not model.execute("gather", {"node_id": "timber_0"}).ok, "Empty node cannot produce more wood")
	_check(_snapshot(model) == after, "Exhausted-node failure is atomic")


func _test_companion_choices() -> void:
	_suite("companion range, costs, alternatives and once-only decisions")
	var helped = WorldModel.new()
	_check(not helped.execute("choose_companion", {"choice": "decline"}).ok, "Companion interaction requires presence")
	helped.set_player_position(Vector3(-3.0, 1.0, 4.0))
	var before := _snapshot(helped)
	_check(not helped.execute("choose_companion", {"choice": "help"}).ok, "Help without four wood is rejected")
	_check(_snapshot(helped) == before and not helped.data.companion.met, "Failed help does not lock a choice or award trust")
	_collect(helped, 1)
	helped.set_player_position(Vector3(-3.0, 1.0, 4.0))
	_check(helped.execute("choose_companion", {"choice": "help"}).ok, "Help succeeds with actual resources")
	_check(helped.data.resources.wood == 0 and helped.data.companion.trust == 20, "Help cost and relationship commit together")
	before = _snapshot(helped)
	_check(not helped.execute("choose_companion", {"choice": "decline"}).ok, "Choice cannot be switched afterward")
	_check(_snapshot(helped) == before, "Second companion decision changes nothing")
	var declined = WorldModel.new()
	declined.set_player_position(Vector3(-3.0, 1.0, 4.0))
	_check(declined.execute("choose_companion", {"choice": "decline"}).ok, "Declining needs no wood")
	_check(declined.data.resources.wood == 0 and declined.data.companion.trust == -5, "Declining has its own persistent consequence")


func _test_build_placement_and_real_work() -> void:
	_suite("valid plot, spacing and construction using real elapsed work")
	var model = WorldModel.new()
	_collect(model, 4)
	var before := _snapshot(model)
	_check(not model.execute("build", {"x": 4.99, "z": 5.0}).ok, "Outside the licensed plot is rejected")
	_check(not model.execute("build", {"x": 8.0, "z": 13.01}).ok, "Plot edge is enforced")
	_check(_snapshot(model) == before, "Invalid plot costs nothing")
	_check(model.execute("build", {"x": 8.0, "z": 5.0}, "hut-order").ok, "Valid hut starts")
	_check(model.data.resources.wood == 8 and model.data.buildings[0].progress == 0.0, "Paid building is initially unfinished")
	before = _snapshot(model)
	_check(not model.execute("build", {"x": 10.0, "z": 5.0}).ok, "Overlapping huts are rejected")
	_check(_snapshot(model) == before, "Overlap rejection does not consume remaining wood")
	model.advance(100.0)
	_check(model.data.buildings[0].progress == 0.0, "A distant player does not supply construction labour")
	model.set_player_position(Vector3(8.0, 1.0, 5.0))
	model.advance(6.0)
	_check(is_equal_approx(model.data.buildings[0].progress, 0.5), "Six real seconds perform half of the work")
	_check(not model.data.buildings[0].completed, "Half-built hut is not marked complete")
	var partial_path := _path("partial_build")
	_check(model.save_game(partial_path).ok, "A paid but unfinished construction process can be saved")
	var resumed = WorldModel.new()
	_check(resumed.load_game(partial_path).ok, "Partial construction loads without a new payment")
	_check(is_equal_approx(resumed.data.buildings[0].progress, 0.5) and resumed.data.resources.wood == 8, "Saved work and material expenditure remain exactly associated")
	model = resumed
	model.advance(6.0)
	_check(model.data.buildings[0].completed and model.data.buildings[0].progress == 1.0, "Twelve real seconds complete the hut")
	_check(model.data.progress.stage == "settlement", "Completion advances the first chapter state")
	_check(model.execute("build", {"x": 13.0, "z": 5.0}).ok, "Exactly five metres of separation is allowed")
	_check(model.data.resources.wood == 0, "Two huts consume exactly sixteen wood")


func _test_single_worker_and_delta_partition() -> void:
	_suite("single-worker conservation and frame partition invariance")
	var model = WorldModel.new()
	_collect(model, 4)
	model.execute("build", {"x": 8.0, "z": 5.0})
	model.execute("build", {"x": 13.0, "z": 5.0})
	model.set_player_position(Vector3(10.5, 1.0, 5.0))
	model.advance(6.0)
	var total: float = model.data.buildings[0].progress + model.data.buildings[1].progress
	_check(is_equal_approx(total, 0.5), "One worker cannot work six seconds on two sites simultaneously")
	model.advance(18.0)
	_check(model.data.buildings[0].completed and model.data.buildings[1].completed, "Remaining work budget proceeds sequentially between sites")
	var fragmented = WorldModel.new()
	_collect(fragmented, 2)
	fragmented.execute("build", {"x": 8.0, "z": 5.0})
	fragmented.set_player_position(Vector3(8.0, 1.0, 5.0))
	for index in 120:
		fragmented.advance(0.1)
	_check(fragmented.data.buildings[0].completed, "120 steps of 0.1 seconds also complete twelve seconds of work")
	_check(is_equal_approx(fragmented.data.world_seconds, 12.0), "Frame partition does not change the accumulated world time")


func _test_age_training_and_recruitment() -> void:
	_suite("age transition, training limits and worker-to-soldier bookkeeping")
	var child = WorldModel.new()
	_check(not child.execute("train").ok, "No training transition without home and companion encounter")
	_check(not child.execute("training_hit").ok, "No training credit before entering training")
	_check(not child.execute("recruit").ok, "Child cannot recruit soldiers")
	_check(not child.execute("start_skirmish").ok, "Child cannot start the adult skirmish")
	var model = _settled("help")
	_check(not model.execute("train").ok, "Training starts only at the instructor")
	model.set_player_position(Vector3(-11.0, 1.0, -3.0))
	_check(model.execute("gather", {"node_id": "timber_1"}).ok, "A second source supports the second real building order")
	_check(model.execute("build", {"x": 13.0, "z": 5.0}).ok, "Second hut creates an unfinished process before the age jump")
	model.set_player_position(Vector3(0.0, 1.0, -7.0))
	var waiting := _snapshot(model)
	_check(not model.execute("train").ok and _snapshot(model) == waiting, "Age transition cannot silently skip pending player-supplied work")
	model.set_player_position(Vector3(13.0, 1.0, 5.0))
	model.advance(12.0)
	model.set_player_position(Vector3(0.0, 1.0, -7.0))
	var old_time: float = model.data.world_seconds
	_check(model.execute("train").ok, "Instructor starts the explicit adult chapter")
	_check(model.data.player.age == 18 and model.data.companion.age == 18, "Player and companion age on the same timeline")
	_check(model.data.world_seconds == old_time + 6.0 * WorldModel.YEAR_SECONDS, "Age transition is recorded in world time")
	var after := _snapshot(model)
	_check(not model.execute("train").ok and _snapshot(model) == after, "The age jump cannot be repeated")
	model.set_player_position(Vector3(15.0, 1.0, 5.0))
	_check(not model.execute("training_hit").ok, "Distant training strikes are rejected")
	model.set_player_position(Vector3(0.0, 1.0, -7.0))
	_check(model.execute("training_hit").ok, "First valid training hit counts")
	_check(not model.execute("training_hit").ok and model.data.progress.training_hits == 1, "Training recovery prevents duplicate immediate hits")
	for index in 2:
		model.advance(0.65)
		_check(model.execute("training_hit").ok, "Separated training hits count")
	_check(model.data.progress.training_complete and model.data.player.role == "soldier", "Exactly three valid hits complete training")
	_check(not model.execute("training_hit").ok, "Completed training cannot award further hits")
	for index in 3:
		_check(model.execute("recruit").ok, "Recruitment within the limit succeeds")
	_check(model.data.squad.alive == 3 and model.data.population.workers == 1, "Three actual workers became three soldiers")
	_check(model.data.resources.denarii == 15 and model.data.resources.grain == 6, "Recruitment costs conserve money and food")
	after = _snapshot(model)
	_check(not model.execute("recruit").ok and _snapshot(model) == after, "Fourth recruit rejected without a partial charge")


func _test_combat_and_persistent_losses() -> void:
	_suite("range-checked combat, casualties, one-time resolution and saved encounter")
	var model = _trained("help", 3)
	_check(model.execute("start_skirmish").ok, "Qualified squad starts an encounter")
	_check(not model.execute("resolve_skirmish").ok, "Cannot award victory while enemies live")
	_check(not model.execute("strike_enemy", {"enemy_id": "enemy_0"}).ok, "A remote attack misses")
	_check(not model.execute("receive_damage", {"amount": 8}).ok, "Remote enemy cannot damage the player")
	model.set_player_position(Vector3(6.0, 1.0, -10.0))
	_check(model.execute("strike_enemy", {"enemy_id": "enemy_0"}, "opening-strike").ok, "Actual nearby attack changes one enemy")
	_check(model.data.encounter.enemies[0].health == 28, "Squad support has a defined bounded attack effect")
	var before := _snapshot(model)
	_check(not model.execute("strike_enemy", {"enemy_id": "enemy_0"}).ok, "Immediate second strike is blocked by recovery")
	_check(_snapshot(model) == before, "Rejected strike has no partial result")
	_check(model.execute("receive_damage", {"amount": 8}).ok, "Nearby enemy hit causes actual player damage")
	before = _snapshot(model)
	_check(not model.execute("receive_damage", {"amount": 8}).ok and _snapshot(model) == before, "Enemy attack cooldown prevents duplicate damage")
	for index in 3:
		model.advance(1.3)
		_check(model.execute("receive_damage", {"amount": 8}).ok, "Later valid enemy attacks accumulate")
	_check(model.data.player.health == 68 and model.data.squad.alive == 2, "Sustained pressure produces a permanent squad casualty")
	_check(model.data.population.soldiers == 2 and model.data.population.dead == 1 and model.data.population.workers == 1, "Dead soldier is not restored as a worker")
	var path := _path("active_combat")
	_check(model.save_game(path).ok, "Mid-encounter save succeeds")
	var restored = WorldModel.new()
	_check(restored.load_game(path).ok, "Mid-encounter save loads")
	_check(restored.data.encounter.active and restored.data.encounter.enemies[0].health == 28 and restored.data.player.health == 68, "Enemy, player and encounter statuses survive loading")
	_check(restored.data.squad.alive == 2 and restored.data.population.dead == 1, "Casualty survives loading")
	_check(not restored.execute("receive_damage", {"amount": 8}).ok, "Saved attack cooldown prevents reload abuse")
	_win(restored)
	_check(restored.data.progress.skirmish_won and not restored.data.encounter.active, "Last real enemy defeat resolves the encounter automatically")
	_check(restored.data.resources.denarii == 30 and restored.data.resources.grain == 10, "Victory awards are paid once after actual defeat")
	before = _snapshot(restored)
	_check(not restored.execute("resolve_skirmish").ok and _snapshot(restored) == before, "Repeated resolution never awards duplicate loot")
	_check(not restored.execute("start_skirmish").ok, "Encounter cannot silently reset enemies or casualties")


func _test_story_branches_and_terminal_death() -> void:
	_suite("causal story alternatives, chapter end and terminal life end")
	var helped = _trained("help", 1)
	_check(not helped.execute("choose_story", {"choice": "protect"}).ok, "No follow-up choice before its prerequisites")
	helped.execute("start_skirmish")
	_win(helped)
	_check(helped.data.story.text.contains("vertraut"), "Helped companion has the supported post-battle context")
	_check(helped.execute("choose_story", {"choice": "protect"}).ok, "Valid protection branch commits")
	_check(helped.data.resources.grain == 18 and helped.data.companion.trust == 25, "Protection consequences are concrete and balanced")
	_check(helped.data.progress.chapter_complete and not helped.data.progress.career_terminal, "A small chapter ending does not invent a terminal career")
	var before := _snapshot(helped)
	_check(not helped.execute("choose_story", {"choice": "pursue"}).ok and _snapshot(helped) == before, "Alternative branch cannot also pay out")
	var declined = _trained("decline", 1)
	declined.execute("start_skirmish")
	_win(declined)
	_check(declined.data.story.text.contains("Ablehnung"), "Declined companion remembers the different earlier event")
	_check(declined.execute("choose_story", {"choice": "pursue"}).ok, "Pursuit branch commits independently")
	_check(declined.data.resources.denarii == 52 and declined.data.companion.trust == -10, "Pursuit has different one-time costs and consequences")
	var dying = _trained("decline", 3)
	dying.execute("start_skirmish")
	dying.set_player_position(Vector3(6.0, 1.0, -10.0))
	for index in 13:
		dying.advance(1.3)
		_check(dying.execute("receive_damage", {"amount": 8}).ok, "Each actual hit in the fatal encounter is processed")
	_check(dying.data.player.health == 0 and dying.data.progress.career_terminal and dying.data.progress.stage == "fallen", "Fatal damage commits an explicit terminal life state")
	_check(dying.data.squad.alive == 0 and dying.data.population.dead == 3, "Fatal encounter does not recreate the squad")
	var terminal_path := _path("terminal_life")
	_check(dying.save_game(terminal_path).ok, "Terminal life and its casualties can be saved")
	var terminal = WorldModel.new()
	_check(terminal.load_game(terminal_path).ok and terminal.data.progress.career_terminal, "Reload cannot erase the terminal career event")
	_check(not terminal.execute("resolve_skirmish").ok, "Reloaded death cannot become a fabricated victory")
	before = _snapshot(dying)
	dying.advance(100.0)
	dying.set_player_position(Vector3(-8.0, 1.0, 2.0))
	_check(not dying.execute("gather", {"node_id": "timber_0"}).ok and _snapshot(dying) == before, "Terminal life cannot keep moving, working or issuing commands")


func _test_save_roundtrip_and_command_replay() -> void:
	_suite("strict save roundtrip and cross-reload idempotency")
	var model = WorldModel.new()
	model.set_player_position(Vector3(-8.0, 1.0, 2.0))
	var original: Dictionary = model.execute("gather", {"node_id": "timber_0"}, "persisted-gather")
	var path := _path("roundtrip")
	_check(model.save_game(path).ok, "A valid world can be saved")
	_check(FileAccess.file_exists(path + ".bak"), "First save includes a verified recovery file")
	var loaded = WorldModel.new()
	var load_result: Dictionary = loaded.load_game(path)
	_check(load_result.ok and not load_result.recovered_backup, "Normal load uses the primary file")
	_check(loaded.data.world_id == model.data.world_id and loaded.data.revision == model.data.revision, "World identity and revision survive the roundtrip")
	var old: Dictionary = loaded.data.duplicate(true)
	old.erase("valley")
	old.schema_version = 1
	var old_path := _path("v1")
	_write_envelope(old_path,old)
	var old_bytes := FileAccess.get_file_as_string(old_path)
	_check(loaded.load_game(old_path).ok and loaded.data.valley.is_empty() and loaded.data.schema_version == WorldModel.SCHEMA_VERSION, "A PR 20 save gains the regional ledger")
	_check(FileAccess.get_file_as_string(old_path) == old_bytes,"Migration only touches the validated in-memory candidate")
	var before := _snapshot(loaded)
	_check(loaded.execute("gather", {"node_id": "timber_0"}, "persisted-gather") == original, "Original successful command is still recognized after reload")
	_check(_snapshot(loaded) == before and loaded.data.resources.wood == 4, "Reload cannot duplicate an accepted gathering transaction")
	_check(not loaded.execute("gather", {"node_id": "timber_1"}, "persisted-gather").ok, "Conflicting persisted ID remains rejected")
	var branch = _trained("decline", 1)
	branch.execute("start_skirmish")
	_win(branch)
	branch.execute("choose_story", {"choice": "pursue"})
	_check(branch.save_game(_path("branch")).ok, "Chosen branch saves")
	_check(loaded.load_game(_path("branch")).ok, "Chosen branch loads")
	_check(loaded.data.story.choice == "pursue" and loaded.data.progress.chapter_complete, "The exact selected branch persists")
	_check(not loaded.execute("choose_story", {"choice": "protect"}).ok, "Reload cannot choose the alternative branch for a second reward")


func _test_backup_and_interrupted_save() -> void:
	_suite("verified backup recovery and ignored incomplete temp files")
	var model = WorldModel.new()
	model.set_player_position(Vector3(-8.0, 1.0, 2.0))
	model.execute("gather", {"node_id": "timber_0"})
	var path := _path("recovery")
	_check(model.save_game(path).ok, "First generation saved")
	model.execute("gather", {"node_id": "timber_0"})
	_check(model.save_game(path).ok, "Second generation atomically replaces the primary")
	var backup_bytes := FileAccess.get_file_as_string(path + ".bak")
	_write_text(path + ".tmp", "{unfinished")
	var recovered = WorldModel.new()
	_check(recovered.load_game(path).ok and recovered.data.resources.wood == 8, "An interrupted temp file is never mistaken for a committed save")
	_write_text(path, "{corrupt")
	var result: Dictionary = recovered.load_game(path)
	_check(result.ok and result.recovered_backup and recovered.data.resources.wood == 4, "Corrupt primary falls back explicitly to the previous valid generation")
	_check(recovered.save_game(path).ok, "Saving after recovery repairs the primary")
	_check(FileAccess.get_file_as_string(path + ".bak") == backup_bytes, "Corrupt primary is never promoted over a valid backup")
	_write_text(path, "broken")
	_write_text(path + ".bak", "also broken")
	var before := _snapshot(recovered)
	_check(not recovered.load_game(path).ok and _snapshot(recovered) == before, "If both files are invalid, the active world stays untouched")


func _test_invalid_saves_do_not_replace_live_state() -> void:
	_suite("structural, numeric, identity and conservation validation of signed saves")
	var live = _settled("help")
	var before := _snapshot(live)
	var clean = WorldModel.new()
	for kind in ["negative", "string", "fraction", "position", "node_id", "schema", "extra", "labour", "phase", "chapter", "forged_wood", "ledger"]:
		var altered: Dictionary = clean.data.duplicate(true)
		match kind:
			"negative": altered.resources.grain = -1
			"string": altered.resources.wood = "0"
			"fraction": altered.resources.wood = 0.5
			"position": altered.player.position = [0.0, 1.0]
			"node_id": altered.resource_nodes[0].id = "unknown_node"
			"schema": altered.schema_version = 99
			"extra": altered["unrecognized_system"] = {}
			"labour": altered.population.workers = 3
			"phase": altered.encounter.active = true
			"chapter": altered.progress.chapter_complete = true
			"forged_wood": altered.resources.wood = 4
			"ledger": altered.command_log = {"forged": {"fingerprint": "x".repeat(64), "result": {"ok": true}}}
		var path := _path("invalid_" + kind)
		_write_envelope(path, altered)
		_check(not live.load_game(path).ok, "Recomputed hash does not bypass domain validation: " + kind)
		_check(_snapshot(live) == before, "Invalid save keeps the live world intact: " + kind)
	var checksum_path := _path("bad_checksum")
	_write_text(checksum_path, JSON.stringify({"format": WorldModel.SAVE_FORMAT, "format_version": 1, "payload": JSON.stringify(clean.data), "sha256": "0".repeat(64)}))
	_check(not live.load_game(checksum_path).ok and _snapshot(live) == before, "Mismatched checksum is rejected before loading")
	var oversized := _path("oversized")
	_write_text(oversized, " ".repeat(WorldModel.MAX_SAVE_BYTES + 1))
	_check(not live.load_game(oversized).ok and _snapshot(live) == before, "Oversized files are bounded before parsing")


func _test_save_failure_preserves_previous_file() -> void:
	_suite("failed save never silently replaces a valid save")
	var model = WorldModel.new()
	var path := _path("preserve")
	_check(model.save_game(path).ok, "Baseline save exists")
	var saved := FileAccess.get_file_as_string(path)
	model.data.resources.wood = 4
	_check(not model.save_game(path).ok, "Invalid in-memory resource balance is refused")
	_check(FileAccess.get_file_as_string(path) == saved, "Refused save leaves previous primary bytes intact")
	model.new_game()
	_check(not model.save_game("res://forbidden.json").ok, "Save cannot overwrite project resources")
	_check(not model.save_game("relative.json").ok, "Ambiguous relative save paths are rejected")
	var directory_path := ProjectSettings.globalize_path(test_directory.path_join("directory_destination"))
	DirAccess.make_dir_recursive_absolute(directory_path)
	var before := _snapshot(model)
	_check(not model.save_game(directory_path).ok, "An existing directory cannot be replaced by a save file")
	_check(_snapshot(model) == before and DirAccess.dir_exists_absolute(directory_path), "Filesystem failure preserves model and existing directory")
	DirAccess.remove_absolute(directory_path)


func _settled(choice: String):
	var model = WorldModel.new()
	_collect(model, 4)
	model.set_player_position(Vector3(-3.0, 1.0, 4.0))
	_check(model.execute("choose_companion", {"choice": choice}).ok, "Fixture companion choice succeeds")
	_check(model.execute("build", {"x": 8.0, "z": 5.0}).ok, "Fixture hut order succeeds")
	model.set_player_position(Vector3(8.0, 1.0, 5.0))
	model.advance(12.0)
	_check(model.data.buildings[0].completed, "Fixture hut is finished by actual work")
	return model


func _trained(choice: String, recruits: int):
	var model = _settled(choice)
	model.set_player_position(Vector3(0.0, 1.0, -7.0))
	_check(model.execute("train").ok, "Fixture adult transition succeeds")
	for index in 3:
		model.advance(0.65)
		_check(model.execute("training_hit").ok, "Fixture training hit succeeds")
	for index in recruits:
		_check(model.execute("recruit").ok, "Fixture recruitment succeeds")
	return model


func _win(model) -> void:
	for index in model.data.encounter.enemies.size():
		var enemy: Dictionary = model.data.encounter.enemies[index]
		model.set_player_position(Vector3(enemy.x, 1.0, enemy.z))
		var attempts := 0
		while int(model.data.encounter.enemies[index].health) > 0 and attempts < 4:
			model.advance(0.65)
			_check(model.execute("strike_enemy", {"enemy_id": enemy.id}).ok, "A nearby recovered attack succeeds")
			attempts += 1
	_check(model.data.progress.skirmish_won, "Encounter won through actual strike commands")


func _collect(model, actions: int) -> void:
	model.set_player_position(Vector3(-8.0, 1.0, 2.0))
	for index in actions:
		_check(model.execute("gather", {"node_id": "timber_0"}).ok, "Fixture wood is actually collected")


func _snapshot(model) -> String:
	return JSON.stringify(model.data)


func _path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_directory))
	return test_directory.path_join(name + ".json")


func _write_envelope(path: String, state: Dictionary) -> void:
	var payload := JSON.stringify(state)
	_write_text(path, JSON.stringify({"format": WorldModel.SAVE_FORMAT, "format_version": 1, "payload": payload, "sha256": payload.sha256_text()}))


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "Test fault fixture can be written")
	if file == null:
		return
	file.store_string(text)
	file.close()


func _cleanup_directory() -> void:
	var absolute := ProjectSettings.globalize_path(test_directory)
	var directory := DirAccess.open(absolute)
	if directory == null:
		return
	for filename in directory.get_files():
		DirAccess.remove_absolute(absolute.path_join(filename))
	DirAccess.remove_absolute(absolute)


func _suite(name: String) -> void:
	suites += 1
	print("DOMAIN_SUITE %02d %s" % [suites, name])


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
