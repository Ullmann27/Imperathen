extends SceneTree
## The production entry path, using an isolated campaign and presentation checkpoint.

const Entry = preload("res://main.tscn")
const Checkpoint = preload("res://scripts/cinematic/opening_checkpoint.gd")
const VillageLife = preload("res://scripts/story/village_life.gd")
const Model = preload("res://scripts/domain/world_model.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const OpeningStory = preload("res://scripts/story/opening_story.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const HouseFamily = preload("res://scripts/world/village/architecture/valdora_house_family.gd")
var failures: Array[String] = []
var checks := 0
var game


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("Use tools/check_prototype.py: an isolated user directory is required.")
		quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	game = Entry.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.world.set_physics_process(false)
	game.ui._finish_intro()
	game.ui.action_requested.emit("new_game", {})
	await process_frame
	_check(game.screen == "opening" and game.opening_sequence.id == "i00_aquileia" and Childhood.enabled(game.model.data), "New Life starts the historical I-00 cold open through the production UI path")
	_check(FileAccess.file_exists(game.SAVE_PATH), "The campaign is saved before its introduction")
	var campaign: String = JSON.stringify(game.model.data)
	var player: Vector3 = game.world.get_player_position()
	_advance_game(2.0)
	_check(JSON.stringify(game.model.data) == campaign and game.world.get_player_position() == player, "Cinematic playback changes neither simulation nor player position")
	game.ui.action_requested.emit("attack", {})
	game.world.action_requested.emit("gather", {"node_id": "timber_0"})
	_check(JSON.stringify(game.model.data) == campaign, "Hidden gameplay input cannot enter through either command gateway")
	root.go_back_requested.emit()
	var paused_time: float = game.opening_elapsed
	var paused_camera: Transform3D = game.opening_director.camera.global_transform
	_advance_game(50.0)
	_check(game.opening_paused and game.opening_elapsed == paused_time and game.opening_director.camera.global_transform == paused_camera, "Android Back pauses the cinematic clock and camera")
	game.opening_overlay._request_advance()
	root.go_back_requested.emit()
	game.opening_overlay._request_advance()
	_check(not game.opening_paused and game.opening_index == 1, "Paused Advance cannot lock the same subtitle after resuming")
	game.opening_overlay._toggle_reading()
	_advance_game(100.0)
	_check(game.opening_manual and game.opening_index == 1, "Reading mode holds the chosen subtitle after its camera travel completes")
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(game.opening_paused, "Application suspension holds the opening instead of skipping unseen lines")
	var checkpoint: Dictionary = Checkpoint.read(str(game.model.data.world_id))
	_check(checkpoint.get("sequence_id", "") == "i00_aquileia" and checkpoint.get("index", -1) == 1 and not bool(checkpoint.get("completed", true)), "Suspension checkpoints I-00 against this campaign identity")
	var world_id: String = game.model.data.world_id
	game._show_menu()
	await process_frame
	game._continue_game()
	_check(game.screen == "opening" and game.opening_sequence.id == "i00_aquileia" and game.opening_index == 1 and game.model.data.world_id == world_id, "Continue restores the pending I-00 scene for the same saved life")
	# The campaign loader represents JSON strategy numbers as floats. Compare
	# parsed values so 2 and 2.0 do not mask or imitate a gameplay change.
	_check(JSON.parse_string(JSON.stringify(game.model.data)) == JSON.parse_string(campaign), "Continuing the opening introduces no age jump, payment or repeated rewards")
	game.opening_overlay._request_skip()
	_check(game.screen == "opening" and game.opening_sequence.id == "i00_aquileia" and bool(game.opening_sequence.beats[game.opening_index].final), "Skip presents the I-00 handoff and waits for explicit confirmation")
	_check(game.opening_director.camera.global_transform.is_equal_approx(game.world.get_node("WorldCamera").global_transform), "The I-00 handoff lands on the exact eventual Valdora gameplay camera")
	_advance_game(500.0)
	_check(game.screen == "opening" and game.opening_sequence.id == "i00_aquileia", "Even a long idle interval cannot auto-confirm the historical handoff")
	game.opening_overlay._request_advance()
	_check(game.screen == "opening" and game.opening_sequence.id == "childhood_home" and game.opening_index == 0, "Confirming I-00 chains into the family opening instead of skipping to gameplay")
	_check(JSON.parse_string(JSON.stringify(game.model.data)) == JSON.parse_string(campaign), "Historical cold open and chain mutate no campaign state")
	checkpoint = Checkpoint.read(str(game.model.data.world_id))
	_check(checkpoint.get("sequence_id", "") == "childhood_home" and not bool(checkpoint.get("completed", true)), "The chained family scene replaces the completed prologue checkpoint")
	game.opening_overlay._request_skip()
	# I-01 VID-A (screenplay v4) ends with an interactive choice. Skip stops at
	# the open choice instead of making it (HB 3.0 S. 29, T20).
	_check(game.screen == "opening" and game.opening_sequence.id == "childhood_home" and str(game.opening_sequence.beats[game.opening_index].get("id", "")) == "i01_a_choice", "Skipping the family cinematic stops at its open choice")
	_check(JSON.parse_string(JSON.stringify(game.model.data)) == JSON.parse_string(campaign), "Skipping to the choice makes no decision")
	game.opening_overlay._request_advance()
	_check(str(game.opening_sequence.beats[game.opening_index].get("id", "")) == "i01_a_choice", "Advance cannot pass the open choice")
	game.opening_overlay.choice_requested.emit("i01_yard")
	_check(game.model.data.village.childhood.screenplay.i01_path == "yard", "The choice is committed through the real childhood command")
	game.opening_overlay._request_skip()
	_check(game.screen == "opening" and game.opening_sequence.id == "childhood_home" and bool(game.opening_sequence.beats[game.opening_index].final), "After the choice, skip stops at its real objective")
	game.opening_overlay._request_advance()
	_check(game.screen == "playing" and game.world.get_node("WorldCamera").current and game.world.get("_active"), "Explicit family-objective acceptance returns the ordinary camera and movement")
	_check_release_visuals("new campaign")
	_check(game.model.data.companion.choice == "" and game.model.data.resources.wood == 0, "Skipping both cinematics does not choose relationships or collect resources")
	game._show_menu()
	game._continue_game()
	_check(game.screen == "playing", "Completed I-00 and family introductions are not forced again on Continue")
	_check_release_visuals("continued campaign")
	_check(Checkpoint.read("another-life").is_empty(), "The sidecar cannot attach an introduction to another save")

	# Keep the previous six-year transition as a saved-campaign compatibility
	# scenario. Fresh Roman lives now follow the separate family childhood path.
	var legacy := Model.new()
	legacy.new_game("italia", true, false)
	var saved: Dictionary = legacy.save_game(game.SAVE_PATH)
	_check(saved.get("ok", false) and not Childhood.enabled(legacy.data), "An explicit extended-village legacy fixture is saved without creating childhood completion flags")
	game._show_menu()
	game.ui.action_requested.emit("continue", {})
	_check(game.screen == "playing" and game.model.data.world_id == legacy.data.world_id and game.model.data.world_id != world_id and not Childhood.enabled(game.model.data), "Continue loads the distinct legacy campaign without attaching the fresh child's checkpoint")
	game._begin_opening(OpeningStory.sequence("italia"))
	_check(game.screen == "opening" and game.opening_sequence.id == "first_day", "The saved legacy campaign still supports its original first-day presentation")
	game.opening_overlay._request_skip()
	game.opening_overlay._request_advance()
	_check(game.screen == "playing" and game.model.data.player.age == 12, "Legacy objective acceptance begins the old chapter without an age jump")

	_move(Vector3(-3, 1, 4))
	game.world.action_requested.emit("companion_interact", {})
	var choices: Array = game.ui.get("_dialog_data").choices
	_check(game.screen == "dialog" and not bool(choices[0].enabled), "A resource-poor player sees the actual help requirement")
	game.ui.action_requested.emit("companion_help", {})
	_check(game.screen == "dialog" and game.model.data.companion.choice == "", "An invalid help attempt keeps the dialogue available without a choice")
	game.ui.action_requested.emit("resume", {})
	_move(Vector3(-8, 1, 2))
	for count in 3:
		game.world.action_requested.emit("gather", {"node_id": "timber_0"})
	_move(Vector3(-3, 1, 4))
	game.world.action_requested.emit("companion_interact", {})
	game.ui.action_requested.emit("companion_help", {})
	_check(game.model.data.resources.wood == 8 and game.model.data.companion.trust == 20, "The real dialogue commits exactly its stated cost and relationship change")
	_move(Vector3(8, 1, 4))
	game.world.action_requested.emit("build", {"x": 8.0, "z": 4.0})
	_advance_game(13.0)
	_check(game.model.data.buildings[0].completed, "The opening leads into a real completed shelter")
	_complete_village_phase()
	_move(Vector3(0, 1, -7))
	var blocked_save := ProjectSettings.globalize_path(game.SAVE_PATH + ".tmp")
	_check(DirAccess.make_dir_recursive_absolute(blocked_save) == OK, "A disposable blocked save path can exercise real persistence failure")
	game.world.action_requested.emit("train", {})
	_check(game.screen == "paused" and not game.pending_opening.is_empty() and game.model.data.player.age == 18, "A failed campaign write pauses the transition instead of concealing a save error behind the montage")
	DirAccess.remove_absolute(blocked_save)
	game._resume()
	_check(game.screen == "opening" and game.opening_sequence.id == "adulthood", "The shared world-input path also triggers the confirmed age montage")
	_check(game.model.data.player.age == 18 and game.model.data.companion.age == 18 and game.opening_sequence.beats[1].text.contains("geteilt"), "Adult memory matches the committed childhood choice")
	var adult_state: String = JSON.stringify(game.model.data)
	game._show_menu()
	game._continue_game()
	# A sub-tick float may serialize with a different last decimal after JSON
	# reload; compare the complete parsed state, as for the childhood reload above.
	_check(game.screen == "opening" and game.opening_sequence.id == "adulthood" and JSON.parse_string(JSON.stringify(game.model.data)) == JSON.parse_string(adult_state), "Adult continuation cannot apply the six-year jump twice")
	game._opening_skip()
	_check(game.opening_sequence.beats[game.opening_index].advance_label == "Zur Ausbildung", "Adult handoff points to training, not the already completed first day")
	game._opening_next()
	game._show_menu()
	game._continue_game()
	_check(game.screen == "playing" and game.model.data.player.age == 18, "Completed adult transition resumes as ordinary gameplay")

	var file := FileAccess.open(Checkpoint.PATH, FileAccess.WRITE)
	file.store_string("broken-checkpoint")
	file.close()
	game._show_menu()
	game._continue_game()
	_check(game.screen == "playing", "A corrupt optional presentation marker never blocks a valid campaign")
	var invalid_marker := {"version": 1, "world_id": game.model.data.world_id,
		"sequence_id": "adulthood", "index": 1.5, "completed": false}
	file = FileAccess.open(Checkpoint.PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(invalid_marker))
	file.close()
	_check(Checkpoint.read(str(game.model.data.world_id)).is_empty(), "A fractional scene index is rejected instead of truncated")
	_check(Checkpoint.write(world_id, "first_day", -1, false) == ERR_INVALID_PARAMETER, "Invalid scene positions are rejected before writing")
	game.queue_free()
	await process_frame
	print("OPENING_FLOW_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		printerr(failure)
	print("OPENING_FLOW_PASS" if failures.is_empty() else "OPENING_FLOW_FAIL")
	quit(0 if failures.is_empty() else 1)


func _move(position: Vector3) -> void:
	game.world.get_node("Player").position = position
	game.model.set_player_position(position)
	game.world.sync_state(game.model.data)


## Run on the original-asset APK build, not optional developer fixtures.
## The ordinary New Life and Continue routes must both instantiate the assets.
func _check_release_visuals(context: String) -> void:
	if OS.get_environment("IMPERATHEN_FULL_ASSET_ACCEPTANCE") != "1":
		return
	for outfit: String in ["armoured", "civil"]:
		_check(Person.youth_outfit_installed(outfit), context + ": all original " + outfit + " youth LODs are installed")
		_check(FileAccess.file_exists(String(Person.MESHY_YOUTH_OUTFITS[outfit].motion)), context + ": original " + outfit + " retarget report is installed")
	var figure = game.world._figure
	_check(is_instance_valid(figure), context + ": the live player figure exists")
	if is_instance_valid(figure):
		_check(figure.age == 12 and figure.youth_outfit == "civil" and figure.active_model_path == String(Person.MESHY_YOUTH_OUTFITS.civil.path) % figure.detail, context + ": actual twelve-year-old Meshy civilian body, not a generic fallback")
		_check(figure._uses_youth_mocap(), context + ": original retargeted animation route drives the player")
		_check(is_instance_valid(figure.body) and figure.body.find_child("MeshyYouthBody", true, false) is MeshInstance3D, context + ": original skinned youth mesh is instantiated")
		for clip: String in ["march", "run", "jab_left", "jab_right", "block"]:
			_check(is_instance_valid(figure.animator) and figure.animator.has_animation(clip), context + ": live youth clip " + clip)
	var regional = game.world.regional
	_check(is_instance_valid(regional) and regional.current_origin == "italia", context + ": actual Valdora settlement is attached")
	if is_instance_valid(regional):
		_check(regional.house_count == Layout.HOMES.size(), context + ": all household buildings are placed")
		var variants := {}
		for home: Dictionary in Layout.HOMES:
			var house: Node = regional.get_node_or_null(String(home.id))
			_check(is_instance_valid(house), context + ": household " + String(home.id))
			if not is_instance_valid(house):
				continue
			var variant := String(house.get_meta("house_variant", ""))
			_check(variant == HouseFamily.variant_for(String(home.id)), context + ": original house variant " + String(home.id))
			_check(house.has_node("FamilyCollision"), context + ": original household collision " + String(home.id))
			variants[variant] = true
		_check(variants.size() == 8 and not variants.has(""), context + ": all eight authored building variants are used")
		_check(regional.has_node("ValdoraPaving") and regional.has_node("HouseInteriors") and regional.has_node("HouseholdsAndForge"), context + ": paving, interiors and forge are part of the playable village")
		var forge := regional.get_node_or_null("HouseholdsAndForge/VillageForge/Interior/AuthoredForgeShell") as Node3D
		_check(is_instance_valid(forge) and forge.scene_file_path == HouseFamily.FORGE_SCENE, context + ": original authored forge architecture is instantiated")
		if is_instance_valid(forge):
			var shell := forge.find_child("valdora_forge_shell", true, false) as MeshInstance3D
			_check(is_instance_valid(shell) and shell.mesh != null and shell.is_visible_in_tree(), context + ": original forge shell has visible mesh geometry")
			_check(forge.find_children("*", "MeshInstance3D", true, false).size() == 2, context + ": only compatible original shell and far proxy are attached, no duplicate legacy fixtures")
	var plants = game.world.vegetation
	_check(is_instance_valid(plants) and plants.is_inside_tree(), context + ": native vegetation field is attached")
	if is_instance_valid(plants):
		_check(plants.placed_trees > 1200, context + ": native field contains the authored landscape, not sparse placeholders")
	var scenery: Node = game.world.scenery
	_check(is_instance_valid(scenery) and scenery.has_node("TrackAndVerge") and scenery.has_node("BrookBedCollision") and scenery.has_node("Stream"), context + ": original ground, water and brook physics are attached")
	_check(is_instance_valid(game.world.far_relief) and game.world.far_relief.is_inside_tree(), context + ": native mountain relief is attached")
	print("IMPERATHEN_RELEASE_CAMPAIGN_ASSETS_CHECKED " + context)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _complete_village_phase() -> void:
	# The saved legacy village still requires encounters and a resolved first
	# raid before its adulthood/persistence scenario. Never inject completion flags.
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
		_advance_game(5.0)
		saw_warning = saw_warning or game.model.data.village.raid.status == "warning"
		saw_attack = saw_attack or game.model.data.village.raid.active
		if VillageLife.training_ready(game.model.data):
			break
	_check(saw_warning and saw_attack and game.model.data.village.raid.completed == 1, "The real warning and first village attack finish before adulthood")
	_check(VillageLife.training_ready(game.model.data) and game.model.data.village.social.seconds >= 2.0 * VillageLife.DAY_SECONDS, "Three encounters and two lived village days still satisfy the legacy training gate")


func _advance_game(delta: float) -> void:
	# Main owns the authoritative physics clock; presentation retains its own
	# process callback. Both run explicitly so awaited UI frames add no time.
	game._physics_process(delta)
	game._process(delta)
