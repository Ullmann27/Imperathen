extends SceneTree
## Domain fixtures move to authoritative points; this is not a navigation or playtime test.
## All quest transitions, rewards, work and persistence go through the actual WorldModel.

const WorldModel = preload("res://scripts/domain/world_model.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const Life = preload("res://scripts/story/village_life.gd")
const Economy = preload("res://scripts/domain/village_economy.gd")
var checks := 0
var failures: Array[String] = []
var directory := "user://village_childhood_%s" % Time.get_ticks_usec()


func _initialize() -> void:
	_test_fresh_opt_in_and_legacy()
	_test_idle_and_bypasses()
	_test_action_transactions()
	_test_nearby_work_and_save()
	_test_full_journey_and_guard()
	_test_branch_and_replay()
	_test_screenplay_failure_and_relationship_branches()
	_test_night_hide_consequences()
	_test_invalid_persistence_and_read_isolation()
	_cleanup()
	print("VILLAGE_CHILDHOOD_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("VILLAGE_CHILDHOOD_PASS" if failures.is_empty() else "VILLAGE_CHILDHOOD_FAIL")
	quit(0 if failures.is_empty() else 1)


func _new():
	var model = WorldModel.new()
	model.new_game("italia", true, true)
	_check(Childhood.enabled(model.data), "Explicit fresh-game opt-in creates childhood")
	_check(model._validate_state(model.data).is_empty(), "Initial complete world validates: " + model._validate_state(model.data))
	return model


func _at(model, point: Vector2) -> void:
	model.set_player_position(Vector3(point.x, 1.0, point.y))


func _near(model, id: String) -> void:
	_at(model, Life.actor_position(model.data, id))


func _meet(model, id: String) -> bool:
	_near(model, id)
	if Life.relationship(model.data, id).get("met", false):
		return true
	return _ok(model.execute("village_talk", {"npc_id":id, "choice":"meet"}), "Actual first meeting: " + id)


func _action(model, id: String, replay_id := "") -> Dictionary:
	return model.execute("village_childhood_action", {"action_id":id}, replay_id)


func _current(model) -> String:
	return str(Childhood.view(model.data).get("stage", "invalid"))


func _complete(model, trade_choice := "market_fair") -> bool:
	var view: Dictionary = Childhood.view(model.data)
	if view.is_empty():
		_check(false, "A valid next childhood action exists")
		return false
	var stage := str(view.get("stage", ""))
	if stage in ["i02_basket", "i02_correct", "i03_marcus", "i08_tracks", "i08_report", "i11_forge", "i12_father", "i13_morning", "i14_oath"]:
		_at(model, view.point)
		if not str(view.get("target_npc", "")).is_empty() and not _meet(model, str(view.target_npc)):
			return false
		var screenplay_actions: Dictionary = {
			"i02_basket":"basket_check",
			"i02_correct":"basket_correct",
			"i03_marcus":"marcus_friend",
			"i08_tracks":"i08_inspect",
			"i08_report":"i08_report",
			"i11_forge":"i11_forge",
			"i12_father":"i12_father",
			"i13_morning":"i13_morning",
			"i14_oath":"i14_oath"
		}
		var screenplay_action: String = str(screenplay_actions.get(stage, ""))
		if not _ok(_action(model, screenplay_action), "Complete screenplay bridge: " + stage):
			return false
		_check(model.data.player.age == 12 and model.data.player.role == "child", "Screenplay bridge cannot change life stage: " + stage)
		return true
	if int(view.completed_steps) >= Childhood.STEPS.size():
		_check(false, "A valid next childhood action exists")
		return false
	var step: Dictionary = Childhood.STEPS[int(view.completed_steps)]
	_at(model, view.point)
	if step.has("npc") and not _meet(model, step.npc):
		return false
	if step.has("seconds"):
		if not _ok(_action(model, "begin_" + str(step.id)), "Begin nearby work: " + str(step.id)):
			return false
		model.advance(float(step.seconds))
		_check(is_equal_approx(float(model.data.village.childhood.work_seconds), float(step.seconds)), "Actual active time counts at station: " + str(step.id))
	var selected: String = trade_choice if step.id == "market_trade" else str(step.id)
	if not _ok(_action(model, selected), "Complete ordered action: " + selected):
		return false
	_check(model.data.player.age == 12 and model.data.player.role == "child" and model.data.progress.years_elapsed == 0, "No action silently changes life stage: " + selected)
	return true


func _until(model, stage: String, trade_choice := "market_fair") -> bool:
	for _index in Childhood.STEPS.size() + 16:
		if _current(model) == stage:
			return true
		if not _complete(model, trade_choice):
			return false
	_check(false, "Requested stage is reachable: " + stage)
	return false


func _test_fresh_opt_in_and_legacy() -> void:
	var model = _new()
	_check(model.data.village.economy.people.size() == 14 and Life.npc_catalog(model.data).size() == 10, "Parents and smith reuse the fourteen real adults and expand seven dialogue people to ten")
	_check(model.data.buildings.is_empty() and _current(model) == "mother_morning", "Family beginning needs no newly built hut")
	_check(Life.relationship(model.data, "julia").met and Life.relationship(model.data, "silvanus").met and not Life.relationship(model.data, "sextus").met, "Parents are already known; the smith is met in play")
	for place: Dictionary in model.data.village.economy.workplaces.values():
		_check(place.condition == 100, "The fresh existing village is not a ruin awaiting reconstruction")
	_check(Economy.day_length(model.data) == 3600.0 and model.data.village.childhood.day == 1, "Narrative day one and the longer economic cycle are distinct")
	var before := _snapshot(model.data)
	_check(not Childhood.start(model.data) and _snapshot(model.data) == before, "Repeated initialization cannot erase an existing childhood")
	# Reproduce the first playable childhood identity layout and prove that the
	# save loader migrates it without losing progress, trust or actor continuity.
	var legacy_names: Dictionary = model.data.duplicate(true)
	legacy_names.village.childhood.version = 1
	legacy_names.village.childhood.erase("screenplay")
	legacy_names.village.history.start_year = 100
	legacy_names.village.childhood.relationships = {
		"antonia": legacy_names.village.childhood.relationships.julia.duplicate(true),
		"sextus": legacy_names.village.childhood.relationships.silvanus.duplicate(true),
		"quintus": legacy_names.village.childhood.relationships.sextus.duplicate(true)
	}
	for person: Dictionary in legacy_names.village.economy.people:
		if person.id == "antonia": person.profession = "Deine Mutter · Töpferin"
		if person.id == "sextus": person.profession = "Dein Vater · Zimmermann"
		if person.id == "quintus": person.profession = "Dorfschmied"
		if person.id == "julia":
			person.profession = "Bäuerin"
			person.assignment = "farm"
		if person.id == "silvanus": person.profession = "Lastenträger"
	_write(_path("legacy-childhood-names"), legacy_names)
	var migrated_names = WorldModel.new()
	_ok(migrated_names.load_game(_path("legacy-childhood-names")), "Load and migrate version-one childhood actor identities")
	_check(migrated_names.data.village.childhood.version == Childhood.VERSION, "Nested childhood identity migration advances its own version")
	_check(migrated_names.data.village.history.start_year == -58, "Legacy childhood migration moves the campaign anchor from the old Trajan-era marker to 58 BCE")
	_check(migrated_names.data.village.childhood.relationships.has("julia") and migrated_names.data.village.childhood.relationships.has("silvanus") and migrated_names.data.village.childhood.relationships.has("sextus"), "Legacy relationships become Julia, Silvanus and Sextus")
	_check(not migrated_names.data.village.childhood.relationships.has("antonia") and not migrated_names.data.village.childhood.relationships.has("quintus"), "Legacy family/smith aliases do not remain authoritative")
	_check(Life.relationship(migrated_names.data, "julia").met and Life.relationship(migrated_names.data, "silvanus").met and not Life.relationship(migrated_names.data, "sextus").met, "Migration preserves known parents and not-yet-met smith state")
	_check(_person(migrated_names, "julia").profession == "Deine Mutter" and _person(migrated_names, "silvanus").profession == "Dein Vater" and _person(migrated_names, "sextus").profession.begins_with("Dorfschmied"), "Canonical actors receive screenplay roles after migration")
	var old = WorldModel.new()
	old.new_game("italia", true)
	Life.ensure(old.data)
	_check(not Childhood.enabled(old.data) and Economy.day_length(old.data) == 120.0 and Life.npc_catalog(old.data).size() == 7, "Legacy village initialization and ensure never retrofit the new story")
	_ok(old.save_game(_path("legacy-village")), "Save a schema-five legacy village")
	_ok(model.load_game(_path("legacy-village")), "Load a schema-five legacy village into a former childhood model")
	_check(not Childhood.enabled(model.data), "Loading old progress preserves its chosen life path")
	var foreign = WorldModel.new()
	foreign.new_game("germania", true, true)
	_check(not Childhood.enabled(foreign.data), "The Roman family story is not injected into another origin")
	var oldest = WorldModel.new()
	oldest.new_game()
	var v4: Dictionary = oldest.data.duplicate(true)
	v4.schema_version = 4
	v4.erase("village")
	_write(_path("legacy-v4"), v4)
	_ok(model.load_game(_path("legacy-v4")), "Run existing version-four migration")
	_check(model.data.schema_version == 5 and not Childhood.enabled(model.data) and not model.data.village.enabled, "Version migration preserves legacy adulthood rules without inventing a childhood history")


func _test_idle_and_bypasses() -> void:
	var model = _new()
	model.advance(600.0)
	_check(model.data.world_seconds > 599.9 and model.data.player.age == 12 and model.data.progress.years_elapsed == 0, "Ten minutes of actual idle simulation do not age the child")
	_check(_current(model) == "mother_morning" and model.data.village.childhood.day == 1 and model.data.village.raid.status == "quiet", "Idle time cannot finish a task, end a narrative day or start the old timed raid")
	_check(model.data.village.economy.day == 0 and model.data.village.economy.day_seconds > 599.9, "Six hundred seconds do not turn into five economic days")
	_check(not Life.training_ready(model.data), "The legacy training gate stays closed")
	var before := _snapshot(model.data)
	for item: Array in [["train", {}], ["village_childhood_begin_raid", {}], ["village_request_work", {}], ["village_assign", {"resident_id":"sextus", "workplace_id":"quarry"}], ["village_shift", {"resident_id":"severus", "duty":"defense"}], ["frontier_talk", {"npc_id":"marcus"}]]:
		_check(not model.execute(item[0], item[1]).ok and _snapshot(model.data) == before, "Old authority or chapter shortcut is atomically rejected: " + str(item[0]))
	_meet(model, "cassia")
	before = _snapshot(model.data)
	for item: Array in [["village_talk", {"npc_id":"cassia", "choice":"help"}], ["village_talk", {"npc_id":"cassia", "choice":"decline"}], ["village_learn", {"npc_id":"cassia"}], ["village_ally", {"npc_id":"cassia"}]]:
		_check(not model.execute(item[0], item[1]).ok and _snapshot(model.data) == before, "Generic mentor shortcut cannot bypass the authored errands: " + str(item[0]))


func _test_action_transactions() -> void:
	var model = _new()
	_at(model, Vector2(70.0, 70.0))
	var before := _snapshot(model.data)
	_check(not _action(model, "mother_morning").ok and _snapshot(model.data) == before, "Remote parent action cannot advance or grant an item")
	_near(model, "julia")
	before = _snapshot(model.data)
	for args: Dictionary in [{"action_id":"night_rest"}, {"action_id":"unknown"}, {"action_id":"mother_morning", "denarii":999}, {"action_id":42}, {"action_id":NAN}, {}]:
		_check(not model.execute("village_childhood_action", args).ok and _snapshot(model.data) == before, "Out-of-order, fabricated or malformed quest command stays atomic")
	_ok(_action(model, "mother_morning", "mother-once"), "Accept the household errand once")
	_check(model.data.village.childhood.carried == ["household_coin"] and model.data.resources.denarii == 30, "The reserved household coin is not spendable reward money")
	before = _snapshot(model.data)
	_ok(_action(model, "mother_morning", "mother-once"), "An exact command retry returns its saved successful result")
	_check(_snapshot(model.data) == before, "Exact replay neither duplicates the coin nor increments the revision")
	_check(not _action(model, "mother_morning").ok and _snapshot(model.data) == before, "A new request cannot repeat a completed errand")
	_check(not _action(model, "fill_water", "mother-once").ok and _snapshot(model.data) == before, "Reusing an id for another action cannot alter the world")
	_check(_complete(model), "Actually collect water inside the house")
	_check(model.data.village.childhood.carried == ["household_coin", "water_jug"], "Water and reserved payment are separate carried objects")
	_check(_complete(model), "Actually deliver the water to father")
	_check(not model.data.village.childhood.carried.has("water_jug"), "Father receives the exact carried object")
	if not _until(model, "deliver_food"):
		return
	_check(model.data.village.childhood.carried == ["family_parcel"] and model.data.resources.denarii == 30, "Actual purchase consumes the reserved coin and creates one delivery parcel")
	_at(model, Vector2(50.0, 50.0))
	before = _snapshot(model.data)
	_check(not _action(model, "deliver_food").ok and _snapshot(model.data) == before, "Buying the parcel does not count as a remote delivery")
	_check(_complete(model) and model.data.village.childhood.carried.is_empty(), "Delivery at mother consumes the parcel once")


func _test_nearby_work_and_save() -> void:
	var model = _new()
	if not _until(model, "forge_bellows"):
		return
	_check(model.data.village.childhood.day == 2 and model.data.village.childhood.apprenticeship == "trial", "An explicit home rest begins the agreed trial day")
	_at(model, Childhood.POINTS.bellows)
	var before := _snapshot(model.data)
	_check(not _action(model, "forge_bellows").ok and _snapshot(model.data) == before, "Station work cannot finish before an explicit start")
	_ok(_action(model, "begin_forge_bellows"), "Begin real station work")
	model.advance(2.5)
	_check(is_equal_approx(float(model.data.village.childhood.work_seconds), 2.5), "Partial work uses actual active seconds")
	before = _snapshot(model.data)
	_check(not _action(model, "forge_bellows").ok and _snapshot(model.data) == before, "Finishing too early has no partial side effects")
	_at(model, Childhood.POINTS.bellows + Vector2(2.0, 0.0))
	model.advance(20.0)
	_check(is_equal_approx(float(model.data.village.childhood.work_seconds), 2.5), "Walking outside the station pauses the job rather than counting waiting elsewhere")
	var frozen := _snapshot(model.data.village.childhood)
	for delta: float in [-1.0, NAN, INF, 3601.0]:
		Childhood.advance(model.data, delta)
	_check(_snapshot(model.data.village.childhood) == frozen, "Invalid or offline catch-up deltas cannot advance station work")
	_ok(model.save_game(_path("midwork")), "Save a partially worked station while away")
	var resumed = WorldModel.new()
	_ok(resumed.load_game(_path("midwork")), "Reload the actual mid-work save")
	_check(_snapshot(resumed.data.village.childhood) == frozen, "Save/load preserves partial work, tasks, possessions and family relations")
	_at(resumed, Childhood.POINTS.bellows)
	var whole = WorldModel.new()
	whole.data = resumed.data.duplicate(true)
	resumed.advance(2.0)
	resumed.advance(3.5)
	whole.advance(5.5)
	_check(_snapshot(resumed.data.village.childhood) == _snapshot(whole.data.village.childhood), "Split and whole active intervals produce the same work state")
	_check(_current(resumed) == "forge_bellows" and resumed.data.village.childhood.work_seconds == 8.0, "Finishing the time budget still needs a deliberate handover")
	before = _snapshot(resumed.data)
	_check(not _action(resumed, "begin_forge_bellows").ok and _snapshot(resumed.data) == before, "Starting twice cannot reset or farm a completed work interval")
	_ok(_action(resumed, "forge_bellows"), "Explicit handover completes the station")
	_check(_current(resumed) == "forge_anvil" and resumed.data.village.childhood.work_seconds == 0.0 and resumed.data.village.childhood.active_work == "", "The next physical station begins with no free work progress")
	_check(Childhood.POINTS.bellows.distance_to(Childhood.POINTS.anvil) > 1.6, "The next station requires moving beyond the previous interaction radius")
	var next: Array[Dictionary] = Childhood.interactables(resumed.data)
	_check(next.size() == 1 and next[0].point == Childhood.POINTS.anvil and next[0].action_id == "begin_forge_anvil", "The world exposes the authoritative next station, not a remote finish button")


func _test_full_journey_and_guard() -> void:
	var model = _new()
	if not _until(model, "patrol_inner"):
		return
	_check(model.data.village.childhood.day == 3 and model.data.village.childhood.apprenticeship == "apprentice" and model.data.village.social.profession == "smith", "Actual trial work, delivery, trust and family rest establish a beginning apprenticeship")
	_check(model.data.village.childhood.relationships.sextus.learned and model.data.village.childhood.relationships.sextus.trust >= 8, "The smith records earned trust and the agreed apprenticeship")
	_check(model.data.village.social.ledger.denarii == 4, "The first delivery and fair-price choice pay exactly four real denarii")
	_at(model, Childhood.POINTS.patrol_gate)
	var before := _snapshot(model.data)
	_check(not _action(model, "patrol_inner").ok and not _action(model, "patrol_gate").ok and _snapshot(model.data) == before, "Jumping straight to the gate cannot satisfy earlier physical patrol observations")
	if not _until(model, "rest_patrol"):
		return
	var guard_before: Dictionary = _person(model, "severus").duplicate(true)
	_check(_complete(model), "Rest explicitly starts the sick-neighbor episode")
	_check(model.data.village.childhood.day == 4 and model.data.village.childhood.guard_absence.active, "The illness belongs to the fourth narrated day, not a timer")
	_check(_person(model, "severus").assignment == "idle" and _person(model, "severus").health == 30 and _duty_count(model, "watchpost") == 1, "The sick guard is really absent from the shared two-person watch roster")
	_check(Life.actor_position(model.data, "severus") == Childhood.POINTS.sick_guard, "The ill guard is physically located by the healer")
	if not _until(model, "borrow_gear"):
		return
	_check(_person(model, "severus").health == 50 and _person(model, "severus").assignment == "idle", "The actual medicine delivery improves condition without silently filling the guard shift")
	_check(_complete(model), "Receive the agreed temporary equipment")
	_check(Childhood.view(model.data).gear_loaned and Childhood.view(model.data).loaned_items == ["Leihhelm", "Hölzerner Leihschild"], "The loan contains only the helmet and wooden shield represented in this build")
	_ok(model.save_game(_path("loan")), "Save the real equipment loan and guard absence")
	var resumed = WorldModel.new()
	_ok(resumed.load_game(_path("loan")), "Load the unfinished guard substitution")
	_check(resumed.data.village.childhood.gear == "loaned" and _person(resumed, "severus").assignment == "idle", "Reload neither loses the loan nor resurrects a second worker")
	if not _until(resumed, "family_evening"):
		return
	_check(not Childhood.view(resumed.data).gear_loaned and Childhood.view(resumed.data).loaned_items.is_empty() and resumed.data.village.childhood.gear == "returned", "The real handover removes the borrowed equipment")
	_check(not resumed.data.village.childhood.guard_absence.active and _person(resumed, "severus").health == guard_before.health and _person(resumed, "severus").assignment == guard_before.assignment and _duty_count(resumed, "watchpost") == 2, "The same guard resumes his available former job without duplicating staff")
	_check(resumed.data.village.social.ledger.denarii == 6, "All three modest earned rewards total exactly six denarii on the fair-price branch")
	_check(_complete(resumed), "Actually return to the family for the evening")
	resumed.advance(30.0)
	_check(_current(resumed) == "night_rest" and resumed.data.village.raid.status == "quiet", "An evening conversation and waiting still do not start the attack")
	_check(_complete(resumed), "Explicitly go to bed after the completed village beginning")
	_check(resumed.data.village.childhood.completed.size() == Childhood.STEPS.size() and Childhood.view(resumed.data).night_raid_pending and not resumed.data.village.raid.active, "The completed beginning prepares a night event without claiming a cinematic has played")
	resumed.advance(300.0)
	_check(resumed.data.village.raid.status == "quiet" and resumed.data.player.age == 12 and resumed.data.village.childhood.day == 4, "Pending night waits indefinitely for its scene and cannot become adulthood")
	_ok(resumed.save_game(_path("pending-night")), "Save the completed chapter and pending scene")
	var night = WorldModel.new()
	_ok(night.load_game(_path("pending-night")), "Load the pending night without releasing it")
	_check(Childhood.view(night.data).night_raid_pending and night.data.player.age == 12, "Persistence does not manufacture a played scene or six lost years")
	_ok(night.execute("village_childhood_begin_raid"), "The explicit scene-completion command releases the first raid")
	_check(night.data.village.raid.active and night.data.village.childhood.night_event == "released" and night.data.village.raid.number == 1, "Only the explicit release starts one actual raid")
	before = _snapshot(night.data)
	_check(not night.execute("village_childhood_begin_raid").ok and _snapshot(night.data) == before, "Releasing the scene twice cannot duplicate raiders or reset combat")
	_check(not Life.training_ready(night.data) and not night.execute("train").ok, "Even reaching the night does not unlock the discarded adulthood jump")
	_test_released_combat(night)
	print("CHILDHOOD_JOURNEY stages=%d narrative_days=%d age=%d earned_denarii=%d" % [Childhood.STEPS.size(), resumed.data.village.childhood.day, resumed.data.player.age, resumed.data.village.social.ledger.denarii])


func _test_released_combat(model) -> void:
	# The enemy exists because the full authored arc and release command ran above.
	# No fixture injects raid state, health, attack clocks or combat experience.
	# Domain timing uses explicit geometry; actual wall/body sweeps are separate.
	model.combat_sight_check = func(_from: Vector2, _to: Vector2) -> bool: return true
	model.combat_motion_check = func(from: Vector2, _to: Vector2) -> Vector2: return from
	_check(model.data.village.raid.rescue_person_id == "julia" and model.data.village.raid.rescue_available, "Canonical night raid exposes Julia as the actual rescue target")
	_at(model, Life.RESCUE_POINT)
	_ok(model.execute("village_rescue"), "Defend path physically rescues Julia before the raid outcome")
	_check(model.data.village.raid.rescued and _person(model, "julia").alive, "Julia rescue is recorded on the same real resident")
	var first: Dictionary = model.data.village.raid.enemies[0]
	var initial_health := int(first.health)
	var initial_experience := int(model.data.village.attributes.combat)
	_at(model, Vector2(float(first.x), float(first.z) + 1.0))
	_ok(model.execute("village_unarmed_attack", {"technique":"jab_left", "target_id":first.id, "facing_x":0.0, "facing_z":-1.0}), "Begin a real jab against a legitimately spawned attacker")
	_check(model.data.village.raid.enemies[0].health == initial_health and model.data.village.raid.player_hits == 0, "Accepted attack input is not a free hit")
	model.advance(0.1)
	_check(model.data.village.raid.enemies[0].health == initial_health, "The real enemy remains unharmed during wind-up")
	model.advance(0.1)
	_check(model.data.village.raid.enemies[0].health == initial_health - 6 and model.data.village.raid.player_hits == 1 and model.data.village.unarmed.resolved_hits == 1, "The measured impact changes one actual enemy once")
	_check(model.data.village.attributes.combat == initial_experience + 1 and model.data.village.raid.stamina == 100.0, "An actual impact earns experience without charging the old stamina pool")
	model.advance(0.5)
	_ok(model.execute("village_unarmed_guard"), "Start guard after the jab has recovered")
	var player_health := int(model.data.player.health)
	model.advance(0.2)
	_check(model.data.player.health == player_health and model.data.village.raid.blocks == 1, "The guard intercepts an actual enemy attack on the same real-time clock")
	model.advance(1.8)
	_check(model.data.village.unarmed.guard_remaining == 0.0 and model.data.village.raid.block_window == 0.0 and model.data.player.health < player_health, "Expired guard no longer protects against the following actual attack")
	_check(model.data.player.age == 12 and model._validate_state(model.data).is_empty(), "Actual hit and damage accounting preserve the valid childhood world")
	_at(model, Childhood.POINTS.family_rest)
	model.advance(160.0)
	_check(not model.data.village.raid.active and model.data.village.raid.completed == 1, "The released raid reaches a real bounded outcome")
	_check(_current(model) == "i11_forge", "A completed night raid releases I-11 instead of restarting the old village loop")
	_check(_complete(model), "Play I-11 at the forge")
	_check(not _person(model, "sextus").alive and _person(model, "sextus").health == 0, "Sextus dies as a persistent shared resident in I-11")
	_check(_complete(model), "Play I-12 at Silvanus")
	_check(not _person(model, "silvanus").alive and _person(model, "julia").alive and model.data.village.childhood.screenplay.julia_outcome == "survived", "Defend/rescue path kills Silvanus but preserves the actually rescued Julia")
	_check(_complete(model), "Play I-13 with Aurelia")
	_check(_complete(model), "Play I-14 at the ridge")
	_check(model.data.village.childhood.screenplay.oath and model.data.village.childhood.night_event == "resolved" and model.data.village.childhood.carried.has("memory_token"), "The oath and keepsake close I-14 without granting adulthood")
	_ok(model.save_game(_path("oath-defend")), "Save the defended oath outcome")
	var oath_reload = WorldModel.new()
	_ok(oath_reload.load_game(_path("oath-defend")), "Reload the defended oath outcome")
	_check(oath_reload.data.village.childhood.screenplay.julia_outcome == "survived" and oath_reload.data.village.childhood.screenplay.oath and _person(oath_reload, "julia").alive, "Rescue, oath and Julia survival persist across save/load")
	model.advance(600.0)
	_check(model.data.village.raid.status == "aftermath" and model.data.village.raid.number == 1, "An ended childhood raid cannot restart itself on the old repeating timer")


func _test_branch_and_replay() -> void:
	var model = _new()
	if not _until(model, "market_trade"):
		return
	var other = WorldModel.new()
	other.data = model.data.duplicate(true)
	_near(model, "cassia")
	_near(other, "cassia")
	_ok(_action(model, "market_fair", "fair-once"), "Choose the agreed full price")
	_ok(_action(other, "market_neighbor", "neighbor-once"), "Choose the voluntary one-denarius neighbor concession")
	_check(model.data.resources.denarii == other.data.resources.denarii + 1 and model.data.village.social.ledger.denarii == other.data.village.social.ledger.denarii + 1, "The trade choice changes real money and its conservation ledger together")
	_check(other.data.village.childhood.relationships.julia.trust == model.data.village.childhood.relationships.julia.trust + 2, "Voluntary help has a distinct relationship consequence")
	var before := _snapshot(other.data)
	_ok(_action(other, "market_neighbor", "neighbor-once"), "Replay the saved market decision")
	_check(_snapshot(other.data) == before and not _action(other, "market_fair").ok and _snapshot(other.data) == before, "The alternative cannot be collected after the saved choice")
	_ok(other.save_game(_path("branch")), "Save the exact selected trade branch")
	var saved = WorldModel.new()
	_ok(saved.load_game(_path("branch")), "Reload the selected trade branch")
	_check(saved.data.village.childhood.completed.has("market_neighbor") and not saved.data.village.childhood.completed.has("market_fair"), "The choice is persisted as history rather than inferred from the latest UI")


func _test_screenplay_failure_and_relationship_branches() -> void:
	var model = _new()
	_until(model, "i02_basket")
	_near(model, "aurelia")
	_meet(model, "aurelia")
	_ok(_action(model, "basket_rush"), "I-02 permits the wrong basket without reloading")
	_check(_current(model) == "i02_correct" and model.data.village.childhood.screenplay.i02_outcome == "wrong", "Wrong basket creates a correction world state")
	_near(model, "julia")
	_ok(_action(model, "basket_correct"), "Julia helps correct the basket mistake")
	_check(_current(model) == "i03_marcus" and not model.data.companion.met, "I-03 follows I-02 with Marcus still undecided")
	_at(model, Childhood.POINTS.marcus)
	_ok(_action(model, "marcus_rival"), "I-03 permits a rivalry outcome")
	_check(model.data.companion.met and model.data.companion.choice == "decline" and model.data.companion.trust == -5, "Marcus rivalry uses the persistent companion state")
	_check(model.data.village.childhood.screenplay.i03_outcome == "rival", "I-03 concrete memory is stored in childhood screenplay state")
	var before := _snapshot(model.data)
	_check(not _action(model, "marcus_friend").ok and _snapshot(model.data) == before, "I-03 cannot be collected twice or silently rewritten")
	_ok(model.save_game(_path("screenplay-branches")), "Save I-02/I-03 branch state")
	var reloaded = WorldModel.new()
	_ok(reloaded.load_game(_path("screenplay-branches")), "Reload I-02/I-03 branch state")
	_check(reloaded.data.village.childhood.screenplay.i02_outcome == "wrong" and reloaded.data.village.childhood.screenplay.i03_outcome == "rival", "Failure and relationship memories survive save/load")


func _test_night_hide_consequences() -> void:
	var model = _new()
	if not _until(model, "i10_choice"):
		return
	_at(model, Childhood.POINTS.father)
	_ok(_action(model, "i10_hide"), "I-10 permits hiding with the parents as a real branch")
	_check(model.data.village.raid.status == "aftermath" and model.data.village.raid.completed == 1 and not model.data.village.raid.active, "Hiding does not erase the attack; it resolves persistent raid losses")
	_check(model.data.village.childhood.screenplay.raid_path == "hide" and _current(model) == "i11_forge", "Hide branch stores its path and still reaches the forge aftermath")
	_check(_complete(model), "Hide route plays I-11")
	_check(_complete(model), "Hide route plays I-12")
	_check(not _person(model, "sextus").alive and not _person(model, "silvanus").alive and not _person(model, "julia").alive, "Hide route leaves Sextus, Silvanus and Julia dead in the shared resident roster")
	_check(model.data.village.childhood.screenplay.julia_outcome == "dead", "Hide route records Julia's death explicitly")
	_check(_complete(model) and _complete(model), "Hide route reaches morning and the oath")
	_check(model.data.village.childhood.screenplay.oath and model.data.village.childhood.carried.has("memory_token"), "Hide route can swear the same investigation oath without rewriting its losses")
	_ok(model.save_game(_path("oath-hide")), "Save the hidden oath outcome")
	var reloaded = WorldModel.new()
	_ok(reloaded.load_game(_path("oath-hide")), "Reload the hidden oath outcome")
	_check(not _person(reloaded, "julia").alive and not _person(reloaded, "silvanus").alive and not _person(reloaded, "sextus").alive, "Hide-route deaths remain real after reload")


func _test_invalid_persistence_and_read_isolation() -> void:
	var model = _new()
	var invalids: Array[Dictionary] = []
	for key: String in ["day", "version", "gear", "night_event", "completed", "carried", "active_work", "work_seconds"]:
		var bad: Dictionary = model.data.duplicate(true)
		bad.village.childhood[key] = {"day":2, "version":true, "gear":"loaned", "night_event":"released", "completed":["night_rest"], "carried":["family_parcel"], "active_work":"forge_bellows", "work_seconds":NAN}[key]
		invalids.append(bad)
	var absent: Dictionary = model.data.duplicate(true)
	absent.village.childhood.relationships.erase("julia")
	invalids.append(absent)
	var apprentice: Dictionary = model.data.duplicate(true)
	apprentice.village.childhood.relationships.sextus.met = true
	apprentice.village.childhood.relationships.sextus.learned = true
	invalids.append(apprentice)
	var parent: Dictionary = model.data.duplicate(true)
	parent.village.childhood.relationships.silvanus.met = false
	invalids.append(parent)
	var early_raid: Dictionary = model.data.duplicate(true)
	early_raid.village.raid.status = "warning"
	early_raid.village.raid.number = 1
	invalids.append(early_raid)
	for bad: Dictionary in invalids:
		_check(not Childhood.validate(bad).is_empty(), "Contradictory or malformed childhood payload is rejected")
		# Binary snapshots retain the deliberately invalid NaN bit pattern without
		# asking JSON to stringify a number that its format cannot represent.
		var before := var_to_bytes(bad)
		_check(not Childhood.execute(bad, "village_childhood_action", {"action_id":"mother_morning"}).ok and var_to_bytes(bad) == before, "An invalid state cannot partially execute an action")
	var forged: Dictionary = model.data.duplicate(true)
	forged.village.childhood.night_event = "released"
	_write(_path("forged"), forged)
	var before := _snapshot(model.data)
	_check(not model.load_game(_path("forged")).ok and _snapshot(model.data) == before, "A correctly checksummed but contradictory save cannot replace the live world")
	var display: Dictionary = Childhood.view(model.data)
	display.relationships.julia.trust = 99
	display.carried.append("Invented goods")
	var relation: Dictionary = Life.relationship(model.data, "julia")
	relation.trust = -100
	var catalog: Array[Dictionary] = Life.npc_catalog(model.data)
	catalog.back().name = "Invented name"
	_check(_snapshot(model.data) == before, "Mutating returned UI views, relationship copies or catalogs cannot alter authoritative state")
	var copy: Dictionary = model.data.duplicate(true)
	_check(Childhood.view(copy).objective.length() > 0 and Childhood.dialogue(copy, "julia").choices.size() == 1, "Fresh state exposes an actionable family conversation")


func _person(model, id: String) -> Dictionary:
	for person: Dictionary in model.data.village.economy.people:
		if person.id == id:
			return person
	return {}


func _duty_count(model, duty: String) -> int:
	var count := 0
	for person: Dictionary in model.data.village.economy.people:
		count += 1 if person.assignment == duty else 0
	return count


func _snapshot(data: Dictionary) -> String:
	return JSON.stringify(data, "", true, true)


func _path(name: String) -> String:
	return directory.path_join(name + ".json")


func _write(path: String, state: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var payload := _snapshot(state)
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "Create a checksummed persistence fault fixture")
	if file != null:
		file.store_string(JSON.stringify({"format":WorldModel.SAVE_FORMAT, "format_version":1, "payload":payload, "sha256":payload.sha256_text()}))
		file.close()


func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(directory)
	var folder := DirAccess.open(absolute)
	if folder == null:
		return
	for filename: String in folder.get_files():
		DirAccess.remove_absolute(absolute.path_join(filename))
	DirAccess.remove_absolute(absolute)


func _ok(result: Dictionary, message: String) -> bool:
	var success: bool = result.get("ok", false)
	_check(success, message + " — " + str(result.get("message", "")))
	return success


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
