extends SceneTree

const Battle := preload("res://scripts/battle/battle_model.gd")
const Valley := preload("res://scripts/tactics/valley_scene.gd")
const World := preload("res://scripts/domain/world_model.gd")
const CAV := "aux_eques_gallicus"
const LEVY := "cisalpine_militia_spear"
const BOWS := "aux_sagittarius_creticus"
const UNIT := "muster_" + CAV
var tests := 0
var failures := 0


func check(condition: bool, label: String) -> void:
	tests += 1
	if not condition:
		failures += 1
		push_error(label)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := {"player": {"age": 12, "role": "child"}, "squad": {"alive": 2},
		"progress": {"training_complete": true, "skirmish_won": true}}
	check(Battle.campaign_authority(world).is_empty(), "The child has no military authority")
	world.player = {"age": 18, "role": "trader"}
	check(Battle.campaign_authority(world).is_empty(), "An adult civilian has no army appointment")
	world.player.role = "soldier"
	var campaign := Battle.new()
	check(campaign.set_commander(Battle.campaign_authority(world)) and campaign.order(["valley_spears"], "hold").ok, "Delegated adult patrol accepts orders")
	check(not campaign.order(["valley_guard"], "hold").ok and not campaign.muster(CAV).ok, "Patrol cannot command a legion or draw on the practice depot")
	var bench := Battle.Muster.scenario(Battle.VALLEY_SCENARIO, [])
	var catalog := Battle.Catalog.load_default()
	var forms := Battle.Catalog.organization_options(catalog, "roman", -58).map(func(form): return form.id)
	check("republic_legion" in forms and not "principate_aux_cohort" in forms, "Republican and imperial organizations are time restricted")
	check(not Battle.Catalog.available(catalog, -58, "germanic", "roman").has("germanic_eques_auxiliaris") and Battle.Catalog.available(catalog, -52, "germanic", "roman").has("germanic_eques_auxiliaris"), "Germanic mounted auxiliary service dated from its catalog record")
	var adult := Battle.new(58, bench)
	var ledger := World.new()
	ledger.new_game("italia", true)
	ledger.data.progress.skirmish_won = true # Would otherwise fail the pre-existing checkpoint gate.
	var untouched := ledger.data.duplicate(true)
	check(not ledger.checkpoint_valley(adult) and untouched == ledger.data, "Direct practice checkpoint cannot move campaign clock or treasury")
	var original: Array = adult.squads.valley_guard.uids.duplicate()
	adult.set_commander("")
	check(not adult.muster(LEVY).ok, "Refuse muster without a commission")
	adult.set_commander("legatus_valdora")
	check(adult.muster(CAV).ok and adult.muster(LEVY).ok, "Two equipped allied contingents join the muster")
	var riders: Dictionary = adult.squads[UNIT]
	var paid := adult.snapshot()
	check(not adult.muster(CAV).ok and not adult.muster(BOWS).ok and paid == adult.snapshot(), "Duplicates and unfunded contracts leave all accounts untouched")
	check(Battle.Muster.remaining(adult.scenario.contracts) == {"denarii": 0, "grain": 3, "horses": 0, "fodder": 0}, "Depot charges each contract once")
	check(adult.squads.valley_guard.uids == original and riders.strength == 4 and riders.loadout.mount.family_id == "horse_service", "Existing identities and issued mounts")
	for person: Dictionary in riders.people.values():
		check(person.age >= 18 and person.origin.group_id == "aeduian_allies" and person.troop_id == CAV, "Adult named mounted candidate from the contracted origin")
	var historical_year := adult.year
	adult.year = 100
	check(not adult.order(["valley_guard"], "form", "testudo").ok, "Troop's era is checked alongside scutum and drill")
	adult.year = historical_year
	check(not adult.order([UNIT], "form", "testudo").ok and adult.order([UNIT], "form", "wedge").ok, "Kit restricts formation choices")
	adult.tick(2.0)
	check(riders.formation == "wedge", "Wedge physically formed after reaction time")
	check(adult.order([UNIT], "dismount").ok and not riders.mounted, "Riders dismount once stationary")
	var on_foot := Battle.new(58, bench)
	check(on_foot.restore(adult.snapshot()), "Dismounted IDs and kit survive save")
	adult.tick(2.0)
	on_foot.tick(2.0)
	check(adult.order([UNIT], "mount").ok and riders.mounted, "Remount same issued horses")
	adult.tick(2.0)
	on_foot.tick(2.0)
	var start := Vector2(riders.x, riders.z)
	var point := start + Vector2(0, -5)
	for model in [adult, on_foot]:
		check(model.order([UNIT], "move", point).ok, "Move accepted")
		model.tick(1.8)
	var d1 := start.distance_to(Vector2(riders.x, riders.z))
	var foot: Dictionary = on_foot.squads[UNIT]
	var d2 := start.distance_to(Vector2(foot.x, foot.z))
	check(d1 > d2 + 0.25 and d2 > 0, "Horses change actual simulated movement")
	var resumed := Battle.new(58, bench)
	check(resumed.restore(JSON.parse_string(JSON.stringify(adult.snapshot(), "", true, true))), "Restore in a fresh practice battle")
	check(resumed.squads[UNIT].people.keys() == riders.people.keys() and resumed.squads[UNIT].mounted, "No replacement soldiers after reload")
	check(not campaign.restore(adult.snapshot()), "Practice reinforcements cannot enter campaign saves")
	var forged := adult.snapshot()
	forged.scenario += "+" + CAV
	check(not resumed.restore(forged) and not resumed.muster(BOWS).ok, "Forged receipt and late muster refused")
	var begin := Time.get_ticks_usec()
	for _i in 50:
		adult.tick(Battle.STEP)
	print("MUSTER_MEASURE ", JSON.stringify({"initial_people": 69, "fixed_steps": 50, "cpu_usec": Time.get_ticks_usec() - begin, "mounted_move_m": d1, "dismounted_move_m": d2}))
	await _ui(bench)
	print("VALLEY_MUSTER_RESULT checks=%d failures=%d" % [tests, failures])
	if failures == 0:
		print("VALLEY_MUSTER_PASS")
	quit(1 if failures else 0)


func _ui(bench: Dictionary) -> void:
	var scene := Valley.new()
	scene.model = Battle.new(58, bench)
	scene.distance = 12.0
	scene.azimuth = 1.4
	scene.focus = Vector2(-15, 13)
	root.add_child(scene)
	await process_frame
	var popup: PopupMenu = scene.hud.muster_button.get_popup()
	popup.index_pressed.emit(0)
	check(scene.selected == [UNIT] and scene.standards.has(UNIT) and scene.hud.card_by_id.has(UNIT), "Tap on the muster menu creates a real selectable company")
	scene._process(0.0)
	var first: String = scene.model.squads[UNIT].uids[0]
	var rider: Node3D = scene.actors.get(first)
	check(rider != null and rider._pose.available and rider._pose.pelvis_world().distance_to(rider._seat.global_position) < 0.03, "Visible mounted soldier sits on moving skeletal socket")
	await _capture("reiteraufgebot")
	scene._action("rolls")
	check(scene.hud.rolls.visible and scene.hud.roll_text.text.contains("Haeduische Reiter") and scene.hud.roll_text.text.contains("Contubernium"), "Army report resolves officers and actual offers")
	scene.hud.rolls.hide()
	var identity_count: int = scene.agents.counters.created
	scene.distance = 175.0
	scene._place_camera()
	scene._sync_units()
	check(scene.agents.agents[first].level == scene.Levels.LEVEL_C and not scene.actors.has(first), "Far camera aggregates riders with their original UIDs")
	scene.distance = 15.0
	scene._place_camera()
	scene._sync_units()
	check(scene.actors.has(first) and scene.agents.counters.created == identity_count, "Near rig resumes the same agent after the aggregate level")
	scene._action("select", "valley_guard")
	scene._issue("charge", "ridge_guard")
	scene._action("select", UNIT)
	scene._issue("charge", "ridge_guard")
	scene._action("pause")
	scene.set_process(false)
	var struck := false
	var cavalry: Dictionary = scene.model.squads[UNIT]
	for i in 900:
		scene._process(1.0 / 30.0)
		var guard: Dictionary = scene.model.squads.valley_guard
		if cavalry.last_action == "attack" and guard.last_action == "attack":
			struck = true
			break
	check(struck and cavalry.wear.weapon > 0, "Mounted and foot companies execute their orders against the same game target")
	check(scene.agents.counters.rejected_resurrections == 0, "No dismissed battle agents returned after casualties")
	if struck:
		var enemy: Dictionary = scene.model.squads.ridge_guard
		scene.focus = Vector2(cavalry.x + enemy.x, cavalry.z + enemy.z) * 0.5
		scene.distance = 14.5
		scene.azimuth = 0.72
		scene._place_camera()
		scene._sync_units()
		scene._process(0.0)
		var saw_highland := false
		for uid: String in scene.model.squads.ridge_guard.uids:
			var figure = scene.actors.get(uid)
			if figure is Valley.TribalFigure and figure.family == "forest_swordsman" and figure._body.scene_file_path.contains("germanic_warriors"):
				saw_highland = true
		check(saw_highland, "Höhenbund uses the authored Germanic swordsman with distinct clothing, weapon and shield")
		await _capture("gemeinsames-gefecht")
		if OS.get_cmdline_user_args().size() > 1 and DisplayServer.get_name() != "headless":
			await _film(scene, OS.get_cmdline_user_args()[1])
	scene.queue_free()
	await process_frame


func _capture(name: String) -> void:
	if OS.get_cmdline_user_args().is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var directory := OS.get_cmdline_user_args()[0]
	check(root.get_texture().get_image().save_webp(directory.path_join(name + ".webp"), false, 0.88) == OK, "Engine capture " + name)


## Optional consecutive game frames. The exporter controls only the camera
## and the fixed sampling interval. Combat, wear and deaths still run live.
func _film(scene: Node, frame_dir: String) -> void:
	for frame in 75:
		for tick in 2:
			scene._process(1.0 / 30.0)
		var horse: Dictionary = scene.model.squads[UNIT]
		var enemy: Dictionary = scene.model.squads.ridge_guard
		var at := Vector2(horse.x + enemy.x, horse.z + enemy.z) * 0.5
		scene.focus = scene.focus.lerp(at, 0.15)
		scene._place_camera()
		await RenderingServer.frame_post_draw
		var path := frame_dir.path_join("frame-%03d.png" % frame)
		if root.get_texture().get_image().save_png(path) != OK:
			check(false, "Could not capture combat frame")
			return
