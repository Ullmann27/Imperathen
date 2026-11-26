extends SceneTree

const Battle := preload("res://scripts/battle/battle_model.gd")
const Valley := preload("res://scripts/tactics/valley_scene.gd")
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
	var adult := Battle.new(58, bench)
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
	quit(1 if failures else 0)


func _ui(bench: Dictionary) -> void:
	var scene := Valley.new()
	scene.model = Battle.new(58, bench)
	scene.distance = 12.0
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
	if not OS.get_cmdline_user_args().is_empty() and DisplayServer.get_name() != "headless":
		scene.message = "Haeduische Reiter · 4 übernommene Dienstpferde"
		scene._refresh()
		await RenderingServer.frame_post_draw
		var path := OS.get_cmdline_user_args()[0]
		check(root.get_texture().get_image().save_png(path) == OK, "Mounted formation engine capture")
	scene.queue_free()
	await process_frame
