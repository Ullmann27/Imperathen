extends SceneTree
## The shared world state (D-045): one world clock for calendar (#98), tribal
## world (#99) and military (#100); one save contract with a real migration
## chain; one person-id namespace; one write path into the relation graph.

const WorldModel = preload("res://scripts/domain/world_model.gd")
const WorldClock = preload("res://scripts/domain/world_clock.gd")
const WorldState = preload("res://scripts/domain/world_state.gd")
const WorldCalendar = preload("res://scripts/domain/world_calendar.gd")
const PersonRegistry = preload("res://scripts/domain/person_registry.gd")
const Tribes = preload("res://scripts/domain/tribal_world.gd")
const VillageLife = preload("res://scripts/story/village_life.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const BattleModel = preload("res://scripts/battle/battle_model.gd")
const AtlasScreen = preload("res://scripts/strategy/atlas_screen.gd")
const Seasons = preload("res://scripts/strategy/season_campaign.gd")
const Atlas = preload("res://scripts/strategy/atlas_data.gd")
const GameUi = preload("res://scripts/ui/game_ui.gd")
const OpeningStory = preload("res://scripts/story/opening_story.gd")
const FIXTURES := "res://tests/fixtures/mission_bridge_data/"
const DAY := 86400
var checks := 0
var failures: Array[String] = []
var directory := "user://world_state_test"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_test_one_clock()
	_test_no_year_zero_and_rulers()
	_test_single_ageing()
	_test_time_causes()
	_test_raid_booked_once()
	_test_soldiers_on_world_time()
	_test_v5_migration()
	_test_legacy_migration()
	_test_person_ids()
	_test_relation_api()
	_cleanup()
	if failures.is_empty():
		print("WORLD_STATE_PASS %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			print("FAILED: ", failure)
		print("WORLD_STATE_FAIL %d failures / %d checks" % [failures.size(), checks])
		quit(1)


func _check(condition: bool, description: String) -> bool:
	checks += 1
	if not condition:
		failures.append(description)
	return condition


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


## Normalised through JSON so that loader-restored integers compare equal to
## the floats a parsed payload carries.
func _same(a: Variant, b: Variant) -> bool:
	return _json(JSON.parse_string(_json(a))) == _json(JSON.parse_string(_json(b)))


func _path(name: String) -> String:
	return directory.path_join(name + ".json")


func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(directory)
	var dir := DirAccess.open(absolute)
	if dir == null:
		return
	for filename in dir.get_files():
		DirAccess.remove_absolute(absolute.path_join(filename))
	DirAccess.remove_absolute(absolute)


func _campaign() -> Variant:
	var model = WorldModel.new()
	model.new_game("italia", true, true)
	return model


func _write_envelope(path: String, state: Dictionary) -> void:
	var payload := JSON.stringify(state, "", true, true)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"format": WorldModel.SAVE_FORMAT, "format_version": 1, "payload": payload, "sha256": payload.sha256_text()}))
	file.close()


func _atlas_header(model) -> String:
	return AtlasScreen.header(model.world_time(), Seasons.summary(model.data.strategy), int(model.data.player.age) < 18, false)


## A legacy career at the gate of the adult chapter (same path as domain_test).
func _settled() -> Variant:
	var model = WorldModel.new()
	model.set_player_position(Vector3(-8.0, 1.0, 2.0))
	for index in 4:
		model.execute("gather", {"node_id": "timber_0"})
	model.set_player_position(Vector3(-3.0, 1.0, 4.0))
	model.execute("choose_companion", {"choice": "help"})
	model.execute("build", {"x": 8.0, "z": 5.0})
	model.set_player_position(Vector3(8.0, 1.0, 5.0))
	model.advance(12.0)
	model.set_player_position(Vector3(0.0, 1.0, -7.0))
	return model


func _veteran() -> Variant:
	var model = _settled()
	_check(model.execute("train").ok, "Fixture: the adult chapter starts")
	for index in 3:
		model.advance(0.65)
		model.execute("training_hit")
	for index in 3:
		model.execute("recruit")
	_check(model.execute("start_skirmish").ok, "Fixture: the village defence begins")
	for index in model.data.encounter.enemies.size():
		var enemy: Dictionary = model.data.encounter.enemies[index]
		model.set_player_position(Vector3(enemy.x, 1.0, enemy.z))
		var attempts := 0
		while int(model.data.encounter.enemies[index].health) > 0 and attempts < 6:
			model.advance(0.65)
			model.execute("strike_enemy", {"enemy_id": enemy.id})
			attempts += 1
	_check(model.data.progress.skirmish_won, "Fixture: the village defence is won by real strikes")
	_check(model.execute("choose_story", {"choice": "protect"}).ok, "Fixture: the chapter's decision is taken")
	return model


func _fight(model) -> Variant:
	var battle = BattleModel.new()
	var guard := 0
	while battle.outcome == "ongoing" and guard < 20000:
		battle.tick(0.2)
		guard += 1
		if guard == 3000:
			# A stalemate is ended the way the valley scene ends it: by retreat.
			var allies := []
			for squad: Dictionary in battle.squads.values():
				if squad.side == "ally":
					allies.append(squad.id)
			battle.order(allies, "retreat")
	_check(battle.outcome != "ongoing", "Fixture: the valley battle reaches an outcome (%s after %d steps)" % [battle.outcome, battle.steps])
	_check(model.checkpoint_valley(battle), "Fixture: the fought battle is stored in the world")
	return battle


# ------------------------------------------------------------------ one clock

func _test_one_clock() -> void:
	var model = _campaign()
	var time: Dictionary = model.world_time()
	_check(time.date_label == "1. Mai 58 v. Chr." and int(time.year) == -58 and int(time.hour) == 6 and time.season_name == "Frühling" and not time.legacy_timeline, "A new campaign starts on 1 May 58 BC at six: " + str(time.get("date_label", "?")))
	_check(int(model.data.player.age) == 12 and int(time.player_age) == 12 and int(model.data.calendar.births.player.year) == -70, "The twelve-year-old was born in 70 BC; the age is the clock's own")
	_check(Tribes.world_calendar_day(model.data) == 61 and model.calendar_day(model.data) == 61 and int(model.data.tribes.extra_days) == 0, "Tribal days are the days of the same clock since 1 March 58 BC")
	var life: Dictionary = VillageLife.view(model.data)
	_check(int(life.history.current_year) == -58 and life.history.year_label == "58 v. Chr.", "The village chronicle reads the same year")
	_check(str(life.ruler).contains("Erstes Triumvirat") and not str(life.ruler).contains("Trajan"), "58 BC names the triumvirate, never Trajan: " + str(life.ruler))
	var anchor_ids := []
	for anchor: Dictionary in life.history.anchors:
		anchor_ids.append(anchor.id)
	_check(anchor_ids.has("anchor.aquileia_legions") and not anchor_ids.has("trajan_reign"), "History anchors of 58 BC come from the era registry: " + str(anchor_ids))
	_check(GameUi.world_date_text(model.data) == "1. MAI 58 V. CHR.", "The HUD shows the date of the world clock: " + GameUi.world_date_text(model.data))
	var header := _atlas_header(model)
	_check(header.contains("Frühling 58 v. Chr.") and header.contains("1. Mai") and not header.contains("n. Chr."), "The atlas header shows 58 BC: " + header)
	var day := int(time.jdn)
	var anachronisms := []
	for id: String in Atlas.REGIONS:
		var region: Dictionary = Atlas.region_view(id, day)
		for word: String in ["Trajan", "100 n. Chr.", "220 n. Chr.", "Lugdunum", "Londinium", "Baetica", "Achaia", "Proconsularis", "römischen Ägypten", "Kuschan", "Östliche", "Moche-Traditionen", "nordischen römischen Eisenzeit"]:
			if str(region.name).contains(word) or str(region.note).contains(word):
				anachronisms.append("%s: %s" % [id, word])
	_check(anachronisms.is_empty(), "No atlas region describes 58 BC with a later name or ruler: " + str(anachronisms))
	_check(str(Atlas.region_view("italia", day).note).contains("Caesar, Pompeius und Crassus") and str(Atlas.region_view("han", day).name).begins_with("Westliche Han"), "The atlas notes of 58 BC follow the era registry")
	_check(Atlas.region_view("italia", WorldCalendar.to_jdn(100, 3, 1)).note == Atlas.REGIONS.italia.note and Atlas.region_view("italia").note.contains("Trajan"), "The 100 AD atlas keeps its Trajan-era notes")
	_check(OpeningStory.historical_prologue().location.contains("58 v. Chr.") and OpeningStory.childhood().location.contains("58 v. Chr."), "The opening names the calendar's campaign year")
	_check(model._validate_state(model.data).is_empty() and PersonRegistry.validate(model.data).is_empty(), "The new world is valid: " + model._validate_state(model.data))
	# No second clock: a clock that differs from its ledger is a contradiction.
	var skewed: Dictionary = model.data.duplicate(true)
	skewed.calendar.clock.jdn = int(skewed.calendar.clock.jdn) + 1
	_check(model._validate_state(skewed).contains("Weltuhr"), "A clock moved outside the time ledger is rejected: " + model._validate_state(skewed))
	var own_days: Dictionary = model.data.duplicate(true)
	own_days.tribes.extra_days = 7
	_check(model._validate_state(own_days).contains("eigene Tageszählung"), "The tribal world may not count days of its own: " + model._validate_state(own_days))
	var two_lines: Dictionary = model.data.duplicate(true)
	two_lines.calendar.origin_year = 100
	_check(not model._validate_state(two_lines).is_empty(), "Calendar and village history cannot belong to different timelines")
	# The technical simulation seconds are not a date.
	var seconds_before := float(model.data.world_seconds)
	_check(model.pass_calendar_days(3, "Weg nach Aquileia").ok and float(model.data.world_seconds) == seconds_before and model.world_time().date_label == "4. Mai 58 v. Chr.", "Travel moves the world clock, not the technical seconds")
	# Legacy careers keep their own timeline (D-044).
	var legacy = WorldModel.new()
	var legacy_time: Dictionary = legacy.world_time()
	_check(legacy_time.date_label == "1. März 100 n. Chr." and legacy_time.legacy_timeline and int(legacy.data.calendar.origin_year) == 100, "A legacy career starts in spring 100 AD: " + str(legacy_time.date_label))
	var legacy_life: Dictionary = VillageLife.view(legacy.data)
	_check(str(legacy_life.ruler).begins_with("Trajan") and legacy_life.history.anchors.size() == 3 and legacy_life.history.anchors[0].id == "trajan_reign", "100 AD keeps Trajan and its own anchors")
	_check(GameUi.world_date_text(legacy.data) == "1. MÄRZ 100 N. CHR." and _atlas_header(legacy).contains("100 n. Chr."), "HUD and atlas of a legacy career stay in 100 AD")
	# The legacy village day is a derived passage of the same clock.
	var village = WorldModel.new()
	village.new_game("italia", true)
	var start := int(village.data.calendar.clock.jdn)
	var guard := 0
	while int(village.data.village.economy.day) < 2 and guard < 4000:
		village.advance(0.5)
		guard += 1
	_check(int(village.data.village.economy.day) == 2 and int(village.data.calendar.clock.jdn) - start == 2, "Two village days are two calendar days (%d)" % (int(village.data.calendar.clock.jdn) - start))
	_check(village._validate_state(village.data).is_empty(), "The lived village days validate against the ledger")


func _test_no_year_zero_and_rulers() -> void:
	var model = _campaign()
	var world: Dictionary = model.data.duplicate(true)
	var last_day_bc := WorldCalendar.to_jdn(-1, 12, 31)
	WorldClock.book(world, "wait", (last_day_bc - int(world.calendar.clock.jdn)) * DAY, "Prüfung")
	var before: Dictionary = WorldClock.view(world)
	_check(int(before.year) == -1 and before.date_label == "31. Dezember 1 v. Chr.", "The last day before the era change is 31 December 1 BC")
	WorldClock.book(world, "wait", DAY, "Prüfung")
	var after: Dictionary = WorldClock.view(world)
	_check(int(after.year) == 1 and after.date_label == "1. Januar 1 n. Chr." and int(after.player_age) == 70, "1 AD follows 1 BC directly; the protagonist of 70 BC is 70")
	var frame: Dictionary = WorldClock.history_frame(world)
	_check(int(frame.year) == 1 and frame.year_label == "1 n. Chr." and frame.ruler == "Prinzipat des Augustus", "The history frame has no year zero and names Augustus in 1 AD: %s, %s" % [frame.year_label, frame.ruler])
	_check(int(VillageLife._history_frame(world).year) == 1, "The village chronicle never shows a year 0 (58 BC + 58 years is 1 AD)")
	var clockless := {"origin_id": "italia", "village": {"history": {"start_year": -58}}, "progress": {"years_elapsed": 58}}
	_check(int(VillageLife._history_frame(clockless).year) == 1, "Village data without a clock counts its years without a year 0 as well")
	var zero := 0
	var probe: Dictionary = model.data.duplicate(true)
	for step in 80:
		WorldClock.book(probe, "wait", 365 * DAY, "Prüfung")
		zero += int(int(WorldClock.view(probe).year) == 0 or int(VillageLife._history_frame(probe).year) == 0)
	_check(zero == 0, "Eighty years of days never produce a year 0")
	var ides: Dictionary = model.data.duplicate(true)
	WorldClock.book(ides, "wait", (WorldCalendar.to_jdn(-44, 3, 15) - int(ides.calendar.clock.jdn)) * DAY, "Prüfung")
	var ides_frame: Dictionary = WorldClock.history_frame(ides)
	var ids := []
	for anchor: Dictionary in ides_frame.anchors:
		ids.append(anchor.id)
	_check(ides_frame.ruler.contains("Diktatur Caesars") and ids.has("anchor.ides_of_march"), "On 15 March 44 BC ruler and anchor read the same date: %s %s" % [ides_frame.ruler, str(ids)])


# ---------------------------------------------------------------- ageing once

func _test_single_ageing() -> void:
	var model = _settled()
	_check(int(model.data.player.age) == 12 and int(model.data.world_state.time.counts.jump) == 0, "Before the jump: twelve, no jump booked")
	var start := int(model.data.calendar.clock.jdn)
	var jumped: Dictionary = model.execute("train")
	_check(jumped.ok, "The six-year jump runs through the time-jump contract: " + str(jumped.message))
	_check(int(model.data.player.age) == 18 and int(model.data.companion.age) == 18 and int(model.data.progress.years_elapsed) == 6, "Six years age the hero and the companion exactly once (%d, %d)" % [int(model.data.player.age), int(model.data.companion.age)])
	_check(int(model.data.world_state.time.counts.jump) == 1 and int(model.data.calendar.clock.jdn) == WorldCalendar.add_calendar_years(start, 6) and model.world_time().date_label == "1. März 106 n. Chr.", "The jump is one ledger entry of exactly six calendar years: " + str(model.world_time().date_label))
	_check(str(model.data.chronicle.back().text).contains("106 n. Chr.") and str(model.data.chronicle.back().text).contains("nicht simuliert"), "The chronicle shows the date and what the jump did not simulate")
	var after := _json(model.data)
	_check(not model.execute("train").ok and _json(model.data) == after, "The jump cannot be repeated")
	var older: Dictionary = model.data.duplicate(true)
	older.player.age = 19
	_check(not model._validate_state(older).is_empty(), "An age that the clock does not explain is rejected: " + model._validate_state(older))
	var both: Dictionary = model.data.duplicate(true)
	both.player.age = 19
	both.companion.age = 19
	_check(model._validate_state(both).contains("Weltzeit"), "Hero and companion cannot age together past the clock either: " + model._validate_state(both))
	var twice: Dictionary = model.data.duplicate(true)
	twice.world_state.time.counts.jump = 2
	_check(not model._validate_state(twice).is_empty(), "A second booked jump is rejected")
	var counter: Dictionary = model.data.duplicate(true)
	counter.progress.years_elapsed = 12
	_check(not model._validate_state(counter).is_empty(), "Elapsed years are no counter of their own")
	# Seasons of the regional campaign move the same clock.
	var veteran = _veteran()
	var ages := [int(veteran.data.player.age)]
	var labels := []
	for turn in 8:
		veteran.data.strategy.actions = 0
		var result: Dictionary = veteran.act_region("advance", str(veteran.data.strategy.home))
		_check(result.ok, "Season %d advances: %s" % [turn + 1, str(result.message)])
		ages.append(int(veteran.data.player.age))
		labels.append("%s %s" % [veteran.world_time().season_name, veteran.world_time().year_label])
	_check(ages == [18, 18, 18, 18, 19, 19, 19, 19, 20], "Eight seasons are two birthdays, one per year: " + str(ages))
	_check(labels[0] == "Sommer 106 n. Chr." and labels[3] == "Frühling 107 n. Chr." and labels[7] == "Frühling 108 n. Chr.", "Each season is the next season of the calendar: " + str(labels))
	_check(int(veteran.data.world_state.time.counts.season) == 8 and int(veteran.data.strategy.turn) == 8 and int(veteran.data.companion.age) == 20 and int(veteran.data.progress.years_elapsed) == 8, "Season turns and ledger agree; the companion ages with the hero")
	_check(veteran._validate_state(veteran.data).is_empty(), "The world after jump and seasons is valid: " + veteran._validate_state(veteran.data))
	var path := _path("ages")
	_check(veteran.save_game(path).ok, "Save after jump and seasons")
	var loaded = WorldModel.new()
	_check(loaded.load_game(path).ok and int(loaded.data.player.age) == 20 and _json(loaded.data.calendar) == _json(veteran.data.calendar) and _json(loaded.data.world_state) == _json(veteran.data.world_state), "Loading ages nobody: same clock, same ledger, same age")
	loaded.advance(1.0)
	_check(int(loaded.data.player.age) == 20, "The first frame after loading ages nobody")
	# A year of travel is one birthday.
	_check(veteran.pass_calendar_days(365, "Dienstreise").ok and int(veteran.data.player.age) == 21 and int(veteran.data.progress.years_elapsed) == 9, "A year of travel is exactly one more year of age")


# ------------------------------------------------------------- causes of time

func _test_time_causes() -> void:
	var model = _veteran()
	var ledger: Dictionary = model.data.world_state.time
	var day := int(model.data.calendar.clock.jdn)
	_check(model.pass_calendar_days(2, "", "travel").ok and model.pass_calendar_days(1, "", "wait").ok and model.pass_calendar_days(1, "", "sleep").ok, "Travel, waiting and sleeping away advance the clock")
	ledger = model.data.world_state.time
	_check(int(model.data.calendar.clock.jdn) == day + 4 and int(ledger.passed.travel) == 2 * DAY and int(ledger.passed.wait) == DAY and int(ledger.passed.rest) == DAY and ledger.last.cause == "rest", "Each span is booked under its cause")
	var before := _json(model.data)
	_check(not model.pass_calendar_days(1, "", "magic").ok and not model.pass_calendar_days(0).ok and not model.pass_calendar_days(4000).ok and _json(model.data) == before, "Unknown causes and invalid spans change nothing")
	# The sleep of the narrated childhood days and the night before I-10.
	var child = WorldModel.new()
	var source := FileAccess.get_file_as_string(FIXTURES + "handoff_i02_correct_v5.json")
	var file := FileAccess.open(_path("i02"), FileAccess.WRITE)
	file.store_string(source)
	file.close()
	_check(child.load_game(_path("i02")).ok, "Recorded day-1 childhood save loads")
	_check(child.world_time().date_label == "1. Mai 58 v. Chr." and int(child.data.village.childhood.day) == 1, "Narrated day 1 is 1 May 58 BC")
	var guard := 0
	while int(child.data.village.childhood.day) < 2 and guard < 60:
		guard += 1
		if not _play_step(child):
			break
	_check(int(child.data.village.childhood.day) == 2 and child.world_time().date_label == "2. Mai 58 v. Chr." and int(child.world_time().hour) == 6, "Sleeping at home ends day 1: the clock shows the morning of 2 May (%s after %d steps)" % [str(child.world_time().date_label), guard])
	_check(int(child.data.world_state.time.counts.sleep) == 1 and int(child.data.player.age) == 12, "The sleep is one ledger entry; nobody ages")
	var unslept: Dictionary = child.data.duplicate(true)
	unslept.world_state.time.counts.sleep = 0
	_check(not child._validate_state(unslept).is_empty(), "A narrated day without its sleep on the clock is rejected")
	# A shop transaction takes its time on the same clock.
	var trade: Dictionary = model.data.duplicate(true)
	var second := int(trade.calendar.clock.second)
	WorldClock.book(trade, "trade", WorldClock.TRADE_SECONDS, "Handel am Stand")
	_check(int(trade.calendar.clock.second) == second + WorldClock.TRADE_SECONDS and int(trade.world_state.time.counts.trade) == 1 and model._validate_state(trade).is_empty(), "A trade books its haggling time")


## Plays the next authored childhood step the way village_childhood_test does.
const SCREENPLAY_ACTIONS := {"i02_basket": "basket_check", "i02_correct": "basket_correct", "i03_marcus": "marcus_friend",
	"i07_water_fetch": "i07_water_fetch", "i07_water_bring": "i07_water_bring", "i08_tracks": "i08_inspect", "i08_report": "i08_report"}


func _meet(model, id: String) -> void:
	var at: Vector2 = VillageLife.actor_position(model.data, id)
	model.set_player_position(Vector3(at.x, 1.0, at.y))
	if not VillageLife.relationship(model.data, id).get("met", false):
		model.execute("village_talk", {"npc_id": id, "choice": "meet"})


func _play_step(model) -> bool:
	var view: Dictionary = Childhood.view(model.data)
	if view.is_empty():
		return false
	var stage := str(view.get("stage", ""))
	var point: Vector2 = view.point
	model.set_player_position(Vector3(point.x, 1.0, point.y))
	if SCREENPLAY_ACTIONS.has(stage):
		if not str(view.get("target_npc", "")).is_empty():
			_meet(model, str(view.target_npc))
		return model.execute("village_childhood_action", {"action_id": SCREENPLAY_ACTIONS[stage]}).ok
	if int(view.completed_steps) >= Childhood.STEPS.size():
		return false
	var step: Dictionary = Childhood.STEPS[int(view.completed_steps)]
	if step.has("npc"):
		_meet(model, str(step.npc))
		model.set_player_position(Vector3(point.x, 1.0, point.y))
	if step.has("seconds"):
		if not model.execute("village_childhood_action", {"action_id": "begin_" + str(step.id)}).ok:
			return false
		model.advance(float(step.seconds))
	var action := "market_fair" if step.id == "market_trade" else str(step.id)
	return model.execute("village_childhood_action", {"action_id": action}).ok


# ------------------------------------------------------------ raid booked once

func _plunder_lines(tribes: Dictionary) -> Array:
	var lines := []
	for line: Dictionary in tribes.ledger:
		if line.reason == "plunder_reported":
			lines.append(line)
	return lines


func _test_raid_booked_once() -> void:
	var model = WorldModel.new()
	var file := FileAccess.open(_path("i10"), FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(FIXTURES + "handoff_i10_choice_v5.json"))
	file.close()
	_check(model.load_game(_path("i10")).ok, "Recorded save before the night of the riders loads")
	model.finish_tribes()
	var riders_before := 0
	for stack: Dictionary in model.data.tribes.groups.red_seal_riders.troops.values():
		riders_before += int(stack.count)
	var grain_before := int(model.data.resources.grain)
	var food_before := int(model.data.tribes.groups.red_seal_riders.stock.food)
	_check(model.data.world_state.raids.is_empty() and _plunder_lines(model.data.tribes).is_empty() and riders_before >= 30, "Before the night nothing is booked; %d riders exist in the tribal roster" % riders_before)
	model.set_player_position(Vector3(Childhood.POINTS.father.x, 1.0, Childhood.POINTS.father.y))
	var hidden: Dictionary = model.execute("village_childhood_action", {"action_id": "i10_hide"})
	_check(hidden.ok and model.data.village.raid.status == "aftermath", "I-10 is played (hide branch): " + str(hidden.message))
	var raid: Dictionary = model.data.village.raid
	var record: Dictionary = model.data.world_state.raids.get("1", {})
	var stolen := int(raid.stolen)
	_check(stolen > 0 and int(model.data.resources.grain) == grain_before - stolen, "The village ledger loses %d grain once" % stolen)
	_check(record.get("status", "") == "booked" and int(record.get("stolen", -1)) == stolen and record.get("story", "") == "I-10" and record.get("outcome", "") == "hidden", "The raid has one record on the world date: " + str(record))
	var lines := _plunder_lines(model.data.tribes)
	_check(lines.size() == 1 and int(lines[0].qty) == stolen * 10 and lines[0].actor == "red_seal_riders", "The tribal ledger books the reported loot exactly once (%d lines)" % lines.size())
	_check(model.data.tribes.story["I-10"].status == "resolved" and int(record.jdn) == int(model.data.calendar.clock.jdn), "The story raid is resolved on the day of the world clock")
	var cause := {}
	for event: Dictionary in model.data.tribes.events:
		if event.kind == "raid_external":
			cause = event.get("conflict", {})
	_check(cause.get("cause", "") == "quest_dispute" and str(cause.get("source", "")) == "mission:I-10", "The conflict stores its cause (D-048): " + str(cause))
	_check(model._validate_state(model.data).is_empty(), "The world after the raid is valid: " + model._validate_state(model.data))
	# Frames, a save and a load never book it again.
	for frame in 40:
		model.advance(0.25)
	model.finish_tribes()
	_check(model.save_game(_path("raid")).ok, "Save after the raid")
	var loaded = WorldModel.new()
	_check(loaded.load_game(_path("raid")).ok, "Load after the raid")
	for frame in 40:
		loaded.advance(0.25)
	loaded.finish_tribes()
	_check(_plunder_lines(loaded.data.tribes).size() == 1 and int(loaded.data.resources.grain) == grain_before - stolen and loaded.data.world_state.raids.size() == 1, "After frames, save and load the loot is still booked once")
	var again: Dictionary = loaded.data.duplicate(true)
	_check(not WorldState.bridge_raids(again) and _plunder_lines(again.tribes).size() == 1, "The bridge has nothing left to book")
	var doubled: Dictionary = loaded.data.duplicate(true)
	doubled.world_state.raids["1"].booked.food = stolen * 20
	_check(loaded._validate_state(doubled).contains("genau einmal"), "A doubled booking record is rejected: " + loaded._validate_state(doubled))
	var reopened: Dictionary = loaded.data.duplicate(true)
	reopened.world_state.raids["1"].status = "committed"
	_check(not loaded._validate_state(reopened).is_empty(), "A booked raid cannot be reopened for a second booking")
	var invented: Dictionary = loaded.data.duplicate(true)
	invented.world_state.raids["2"] = reopened.world_state.raids["1"].duplicate(true)
	_check(not loaded._validate_state(invented).is_empty(), "A raid record without a village raid is rejected")
	_check(food_before >= 0, "Fixture: the riders' food stock is readable")


# ------------------------------------------------------ soldiers on world time

func _test_soldiers_on_world_time() -> void:
	var model = _veteran()
	_check(model.soldiers().is_empty() and int(model.data.world_state.military.battle_end_jdn) == -1, "No battle, no soldiers, no battle date")
	var muster_day := int(model.data.calendar.clock.jdn)
	_fight(model)
	var military: Dictionary = model.data.world_state.military
	_check(int(military.battle_start_jdn) == muster_day and int(military.battle_end_jdn) >= muster_day, "Muster and end of the battle are dated on the world clock")
	var dead := []
	var wounded := []
	var active := []
	for record: Dictionary in model.soldiers():
		match str(record.status):
			"dead": dead.append(record)
			"wounded": wounded.append(record)
			"active": active.append(record)
	_check(not dead.is_empty() and not wounded.is_empty() and not active.is_empty(), "The battle left dead (%d), wounded (%d) and unhurt (%d) soldiers" % [dead.size(), wounded.size(), active.size()])
	var slowest := 0
	for record: Dictionary in wounded:
		slowest = maxi(slowest, int(record.wound.recovery_days))
	var first: Dictionary = wounded[0]
	_check(model.promote_soldier(str(first.uid), "x").message.contains("Genesung") and model.promote_soldier(str(dead[0].uid), "x").message.contains("Gefallene"), "Wounded and fallen soldiers are not promoted")
	# Recovery runs on world time: travel, waiting and seasons all count.
	var half := maxi(1, int(first.wound.recovery_days) / 2)
	_check(model.pass_calendar_days(half, "Lazarett", "wait").ok, "Days pass")
	var midway: Dictionary = WorldState.soldier(model.data, str(first.uid))
	_check(int(first.wound.recovery_days) <= 1 or (midway.status == "wounded" and int(midway.wound.recovery_days) == int(first.wound.recovery_days) - half), "Half the time is half the recovery (%d of %d days left)" % [int(midway.get("wound", {}).get("recovery_days", 0)), int(first.wound.recovery_days)])
	_check(model.pass_calendar_days(slowest + 1, "Lazarett", "wait").ok, "The longest recovery passes")
	var still_dead := 0
	var still_wounded := 0
	var retired := 0
	for record: Dictionary in model.soldiers():
		still_wounded += int(record.status == "wounded")
		retired += int(record.status == "retired")
	for record: Dictionary in dead:
		still_dead += int(WorldState.soldier(model.data, str(record.uid)).status == "dead")
	_check(still_dead == dead.size() and still_wounded == 0, "After %d days every wounded soldier has recovered or retired (%d retired); the %d dead stay dead" % [slowest + 1 + half, retired, dead.size()])
	_check(model.pass_calendar_days(3000, "Jahre später", "wait").ok, "Years pass")
	still_dead = 0
	for record: Dictionary in dead:
		still_dead += int(WorldState.soldier(model.data, str(record.uid)).status == "dead")
	_check(still_dead == dead.size(), "Years later no fallen soldier is back")
	# The stored battle is untouched; recovery is derived from the clock.
	var snapshot_status := 0
	for squad: Dictionary in model.data.valley.snapshot.squads.values():
		for person: Dictionary in squad.people.values():
			snapshot_status += int(person.status == "wounded")
	_check(snapshot_status == wounded.size(), "The battle record keeps its %d wounded; no second copy can contradict it" % wounded.size())
	# The settlements hear of every change exactly once (D-043).
	var end_day := int(model.data.world_state.military.battle_end_jdn)
	var at_end: Array = WorldState.settlement_events(model.data, end_day)
	var now_events: Array = model.settlement_events()
	var counts := {}
	var seen := {}
	var duplicates := 0
	for event: Dictionary in now_events:
		counts[event.type] = int(counts.get(event.type, 0)) + 1
		duplicates += int(seen.has(event.id))
		seen[event.id] = true
	var total: int = model.soldiers().size()
	_check(int(counts.get("recruited", 0)) == total and int(counts.get("died", 0)) == dead.size() and int(counts.get("wounded", 0)) == wounded.size(), "Muster, wounds and deaths reach the settlements: " + str(counts))
	_check(int(counts.get("recovered", 0)) + int(counts.get("retired", 0)) == wounded.size() and int(counts.get("retired", 0)) == retired and duplicates == 0, "Every wounded soldier later recovers or retires exactly once; no event id occurs twice")
	_check(at_end.size() == total + dead.size() + wounded.size() and WorldState.settlement_events(model.data, muster_day).size() >= total, "On the day of the battle only muster, wounds and deaths have happened")
	_check(_json(model.settlement_events()) == _json(now_events), "Asking again books nothing twice: the same world gives the same events")
	var away := 0
	var people_lost := 0
	var still_hurt := 0
	for place: Dictionary in model.settlement_effects().values():
		away += int(place.totals.get("away", 0))
		people_lost -= int(place.totals.get("population", 0))
		still_hurt += int(place.totals.get("wounded", 0))
	_check(away == total - dead.size() - retired and people_lost == dead.size() and still_hurt == 0, "Per settlement the counts add up: %d still serving, %d fallen, nobody still wounded" % [away, people_lost])
	var told := false
	for entry: Dictionary in model.data.chronicle:
		told = told or str(entry.text).begins_with("Nachricht in die Heimatorte")
	_check(told, "The chronicle of the walkable world tells what the battle meant at home")
	# One soldier, one age: the muster age counts from the muster date.
	var sample: Dictionary = active[0]
	var years := WorldCalendar.years_between(WorldCalendar.year_of(muster_day), WorldClock.year(model.data))
	_check(PersonRegistry.soldier_age(model.data, sample) == int(sample.age) + years and years >= 8, "A soldier ages with the world clock exactly once (%d + %d years)" % [int(sample.age), years])
	# A save cannot bring a fallen soldier back.
	var path := _path("soldiers")
	_check(model.save_game(path).ok, "Save with the fought battle")
	var loaded = WorldModel.new()
	_check(loaded.load_game(path).ok, "Load with the fought battle")
	still_dead = 0
	for record: Dictionary in dead:
		still_dead += int(WorldState.soldier(loaded.data, str(record.uid)).status == "dead")
	_check(still_dead == dead.size() and _same(loaded.soldiers(), model.soldiers()), "The loaded world has the same soldiers, the dead included")
	var revived: Dictionary = loaded.data.duplicate(true)
	var day := int(revived.calendar.clock.jdn)
	revived.world_state.military.promotions.append({"uid": str(dead[0].uid), "from": str(dead[0].troop_id), "to": "roman_miles", "jdn": day, "year": WorldCalendar.year_of(day)})
	_check(loaded._validate_state(revived).contains("gefallener"), "A promotion of a fallen soldier is rejected in the save contract: " + loaded._validate_state(revived))
	var undated: Dictionary = loaded.data.duplicate(true)
	undated.world_state.military.battle_end_jdn = -1
	_check(not loaded._validate_state(undated).is_empty(), "A finished battle without a date is rejected")
	var future: Dictionary = loaded.data.duplicate(true)
	future.world_state.military.battle_end_jdn = day + 5
	_check(not loaded._validate_state(future).is_empty(), "A battle cannot end after today")
	# Promotion on world time. The gate (after the battle, recovered, alive,
	# a season in grade) is the world state's; the upgrade path, experience,
	# authority and era are the troop catalog's.
	var candidate := {}
	for record: Dictionary in model.soldiers():
		if record.status == "active" and not model.TroopCatalog.load_default().troops.get(str(record.troop_id), {}).get("upgrades", []).is_empty():
			candidate = record
			break
	if _check(not candidate.is_empty(), "An active soldier with an upgrade path exists"):
		var uid := str(candidate.uid)
		var upgrade: Dictionary = model.TroopCatalog.load_default().troops[str(candidate.troop_id)].upgrades[0]
		_check(WorldState.promotion_reason(model.data, uid).is_empty(), "A recovered, living soldier passes the world-time gate")
		var refused: Dictionary = model.promote_soldier(uid, str(upgrade.to), [], [str(upgrade.authority)])
		print("WORLD_STATE promotion through the catalog: %s" % str(refused.message))
		_check(not refused.ok and model.data.world_state.military.promotions.is_empty(), "A promotion the catalog refuses stores nothing: " + str(refused.message))
		var world: Dictionary = model.data.duplicate(true)
		WorldState.record_promotion(world, uid, str(candidate.troop_id), str(upgrade.to))
		var today := int(world.calendar.clock.jdn)
		_check(model._validate_state(world).is_empty() and WorldState.soldier(world, uid).troop_id == upgrade.to and int(world.world_state.military.promotions[0].jdn) == today, "A granted promotion carries its world date and changes the derived record: " + model._validate_state(world))
		_check(WorldState.soldier(world, uid, today - 1).troop_id == candidate.troop_id, "The day before, the soldier still held the old grade")
		_check(WorldState.promotion_reason(world, uid).contains("90 Tage"), "No second promotion on the same day: " + WorldState.promotion_reason(world, uid))
		WorldClock.book(world, "wait", 89 * DAY, "Dienst")
		_check(WorldState.promotion_reason(world, uid).contains("1 Tage"), "After 89 days one day in grade is missing")
		WorldClock.book(world, "wait", DAY, "Dienst")
		_check(WorldState.promotion_reason(world, uid).is_empty(), "After a season in grade the gate opens again")
		var hasty: Dictionary = world.duplicate(true)
		hasty.world_state.military.promotions.append({"uid": uid, "from": str(upgrade.to), "to": "x", "jdn": today + 10, "year": WorldCalendar.year_of(today + 10)})
		_check(model._validate_state(hasty).contains("Dienstzeit"), "A save with two promotions inside one season is rejected")
		var wrong_grade: Dictionary = model.data.duplicate(true)
		wrong_grade.world_state.military.promotions.append({"uid": uid, "from": "somebody_else", "to": str(upgrade.to), "jdn": today, "year": WorldCalendar.year_of(today)})
		_check(model._validate_state(wrong_grade).contains("tatsächlichen Stufe"), "A promotion from a grade the soldier never held is rejected")


# ------------------------------------------------------------------ migration

func _load_fixture(name: String) -> Array:
	var text := FileAccess.get_file_as_string(FIXTURES + name)
	var envelope: Dictionary = JSON.parse_string(text)
	var payload: Dictionary = JSON.parse_string(envelope.payload)
	var path := _path("fixture_" + name.get_basename())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var model = WorldModel.new()
	var result: Dictionary = model.load_game(path)
	_check(result.ok, "Recorded v5 save %s loads: %s" % [name, str(result.message)])
	return [model, payload, result.ok]


func _test_v5_migration() -> void:
	var expected := {"handoff_i02_correct_v5.json": "1. Mai 58 v. Chr.", "handoff_i08_report_v5.json": "", "handoff_i10_choice_v5.json": "4. Mai 58 v. Chr."}
	for name: String in expected:
		var loaded := _load_fixture(name)
		if not loaded[2]:
			continue
		var model = loaded[0]
		var payload: Dictionary = loaded[1]
		_check(int(payload.schema_version) == 5 and not payload.has("calendar") and not payload.has("tribes") and not payload.has("world_state"), "%s is a genuine v5 save" % name)
		var day := int(payload.village.childhood.day)
		var night: bool = "night_rest" in payload.village.childhood.completed
		var time: Dictionary = model.world_time()
		_check(int(model.data.schema_version) == 6 and int(time.jdn) == WorldCalendar.campaign_start_jdn() + day - 1 and int(time.second) == (WorldClock.NIGHT if night else WorldClock.MORNING), "%s: narrated day %d is %s, %02d:00" % [name, day, str(time.date_label), int(time.hour)])
		if not str(expected[name]).is_empty():
			_check(time.date_label == expected[name], "%s lands on %s" % [name, str(expected[name])])
		_check(int(model.data.world_state.time.counts.sleep) == day - 1 and int(model.data.world_state.time.counts.night) == int(night) and int(model.data.world_state.time.counts.jump) == 0, "%s: every lived night is booked as sleep" % name)
		_check(int(model.data.player.age) == int(payload.player.age) and int(model.data.calendar.births.player.year) == -70 and int(model.data.progress.years_elapsed) == int(payload.progress.years_elapsed), "%s: age and elapsed years are the saved ones" % name)
		var untouched := true
		for key: String in payload:
			if key in ["schema_version", "village"]:
				continue
			untouched = untouched and _same(model.data[key], payload[key])
		for key: String in payload.village:
			if key in ["behavior"]:
				continue
			untouched = untouched and _same(model.data.village[key], payload.village[key])
		_check(untouched, "%s: nothing the save had decided is changed" % name)
		_check(model.data.tribes.scenario == "bc58_rhine" and int(model.data.tribes.tick) == 0 and model.tribes_pending_weeks() == floori((61 + day - 1) / 7.0), "%s: the Rhine roster starts and waits for the clock" % name)
		model.finish_tribes()
		var again := _path("v6_" + name.get_basename())
		var second = WorldModel.new()
		_check(model.save_game(again).ok and second.load_game(again).ok and _json(second.data.calendar) == _json(model.data.calendar) and _json(second.data.world_state) == _json(model.data.world_state), "%s: the migrated world saves and loads as v6 with the same clock" % name)


func _strip(state: Dictionary, version: int) -> Dictionary:
	var old: Dictionary = state.duplicate(true)
	for key: String in ["tribes", "calendar", "world_state"]:
		old.erase(key)
	if version <= 4:
		old.erase("village")
	old.schema_version = version
	return old


func _test_legacy_migration() -> void:
	# A 100 AD career with jump, seasons and a fought battle, written the way
	# schema 4 wrote it (no recorded v4 file exists; same method as domain_test).
	var veteran = _veteran()
	for turn in 5:
		veteran.data.strategy.actions = 0
		veteran.act_region("advance", str(veteran.data.strategy.home))
	_fight(veteran)
	var old := _strip(veteran.data, 4)
	_write_envelope(_path("v4"), old)
	var loaded = WorldModel.new()
	var result: Dictionary = loaded.load_game(_path("v4"))
	_check(result.ok and int(loaded.data.schema_version) == 6, "A v4 career migrates v4 -> v5 -> v6: " + str(result.message))
	if result.ok:
		var time: Dictionary = loaded.world_time()
		_check(time.date_label == "1. Juni 107 n. Chr." and time.legacy_timeline and int(loaded.data.calendar.origin_year) == 100, "The 100 AD career keeps its own timeline: turn 5 is summer 107 AD (%s)" % str(time.date_label))
		_check(int(loaded.data.player.age) == int(old.player.age) and int(loaded.data.player.age) == 19 and int(loaded.data.progress.years_elapsed) == int(old.progress.years_elapsed), "Age %d and elapsed years are the saved ones" % int(old.player.age))
		var untouched := true
		for key: String in old:
			if key != "schema_version":
				untouched = untouched and _same(loaded.data[key], old[key])
		_check(untouched, "No value of the 100 AD save is rewritten (D-044)")
		_check(loaded.data.tribes.scenario == Tribes.NO_SCENARIO and loaded.data.tribes.groups.is_empty() and loaded.data.tribes.persons.is_empty(), "No 58 BC roster is forced onto a 100 AD career")
		_check(str(VillageLife.view(loaded.data).ruler).begins_with("Trajan") and GameUi.world_date_text(loaded.data) == "1. JUNI 107 N. CHR.", "Its history frame stays Trajan's")
		var ledger: Dictionary = loaded.data.world_state.time
		_check(int(ledger.counts.jump) == 1 and int(ledger.counts.season) == 5 and int(ledger.passed.season) > 0, "Jump and seasons are booked under their causes")
		_check(int(loaded.data.world_state.military.battle_end_jdn) == int(time.jdn), "The battle already fought is dated on the day of migration")
		var next: Dictionary = loaded.act_region("advance", str(loaded.data.strategy.home)) if int(loaded.data.strategy.actions) == 0 else {"ok": false}
		loaded.data.strategy.actions = 0
		if not next.ok:
			next = loaded.act_region("advance", str(loaded.data.strategy.home))
		_check(next.ok and loaded.world_time().date_label == "1. September 107 n. Chr." and int(loaded.data.player.age) == 19, "The migrated career continues on its own calendar: " + str(loaded.world_time().date_label))
		_check(loaded.save_game(_path("v4_as_v6")).ok and WorldModel.new().load_game(_path("v4_as_v6")).ok, "The migrated career saves and loads as v6")
	# A v5 legacy village with lived economy days keeps its date and age.
	var village = WorldModel.new()
	village.new_game("italia", true)
	var guard := 0
	while int(village.data.village.economy.day) < 3 and guard < 6000:
		village.advance(0.5)
		guard += 1
	var v5 := _strip(village.data, 5)
	_write_envelope(_path("v5_village"), v5)
	var migrated = WorldModel.new()
	var village_result: Dictionary = migrated.load_game(_path("v5_village"))
	_check(village_result.ok, "A v5 legacy village migrates: " + str(village_result.message))
	if village_result.ok:
		_check(migrated.world_time().date_label == "1. März 100 n. Chr." and int(migrated.data.player.age) == 12 and int(migrated.data.village.economy.day) == 3, "Its date stays spring 100 AD at age twelve; the three lived days lie before it")
		var jdn := int(migrated.data.calendar.clock.jdn)
		guard = 0
		while int(migrated.data.village.economy.day) < 4 and guard < 2000:
			migrated.advance(0.5)
			guard += 1
		_check(int(migrated.data.calendar.clock.jdn) == jdn + 1, "The next village day is the next calendar day")
	# The unpublished #99 interim form (v6 with tribes, without a clock).
	var interim = _campaign()
	var form: Dictionary = interim.data.duplicate(true)
	form.erase("calendar")
	form.erase("world_state")
	form.tribes.extra_days = 21
	_write_envelope(_path("v6_interim"), form)
	var folded = WorldModel.new()
	var folded_result: Dictionary = folded.load_game(_path("v6_interim"))
	_check(folded_result.ok and int(folded.data.tribes.extra_days) == 0 and int(folded.data.world_state.time.passed.travel) == 21 * DAY and folded.world_time().date_label == "22. Mai 58 v. Chr.", "Reported tribal days of the interim form become travel time on the clock: " + str(folded_result.message))
	# Unknown or damaged versions are never guessed.
	var broken: Dictionary = veteran.data.duplicate(true)
	broken.erase("calendar")
	_write_envelope(_path("broken"), broken)
	_check(not WorldModel.new().load_game(_path("broken")).ok, "A v6 save without its calendar is rejected, not repaired")
	var future: Dictionary = veteran.data.duplicate(true)
	future.schema_version = 7
	_write_envelope(_path("future"), future)
	_check(not WorldModel.new().load_game(_path("future")).ok, "A newer schema is rejected")


# ------------------------------------------------------------------ person ids

func _test_person_ids() -> void:
	var model = _campaign()
	model.finish_tribes()
	var registry: Dictionary = PersonRegistry.collect(model.data)
	var people: Dictionary = registry.people
	var spaces := {}
	for gid: String in people:
		var parts: Array = PersonRegistry.split(gid)
		spaces[parts[0]] = int(spaces.get(parts[0], 0)) + 1
	_check(people.has("pc:player") and people.has("pc:companion") and int(spaces.get("vil", 0)) >= 10 and int(spaces.get("trb", 0)) >= 10, "Player, companion, residents and tribal persons share one namespace: " + str(spaces))
	_check(PersonRegistry.validate(model.data).is_empty(), "Every person has exactly one id: " + PersonRegistry.validate(model.data))
	var companion := str(model.data.companion.id)
	_check(not people.has("vil:" + companion) and PersonRegistry.resolve(model.data, "vil:" + companion) == "pc:companion", "The companion is one person: his village id resolves to pc:companion")
	_check(PersonRegistry.resolve(model.data, "trb:player") == "pc:player" and PersonRegistry.relation_actor(model.data, "player") == "pc:player", "The tribal target 'player' is the player character")
	_check(PersonRegistry.resolve(model.data, "sol:nobody").is_empty() and PersonRegistry.resolve(model.data, "vil:julia") == "vil:julia", "Unknown ids resolve to nobody; known ids to themselves")
	_check(int(people["pc:player"].age) == 12 and int(people["pc:companion"].age) == 12, "Ages in the registry are the clock's")
	# Local ids of different systems can no longer collide.
	var names := {}
	var collisions := 0
	for gid: String in people:
		var local: String = PersonRegistry.split(gid)[1]
		collisions += int(names.has(local))
		names[local] = gid
	print("WORLD_STATE persons: %d people in namespaces %s; %d local ids occur in two systems and stay distinct" % [people.size(), str(spaces), collisions])
	var veteran = _veteran()
	_fight(veteran)
	var with_soldiers: Dictionary = PersonRegistry.collect(veteran.data).people
	var soldiers := 0
	var dead := 0
	for gid: String in with_soldiers:
		if gid.begins_with("sol:"):
			soldiers += 1
			dead += int(not bool(with_soldiers[gid].alive))
	_check(soldiers == veteran.soldiers().size() and soldiers > 0 and dead > 0 and PersonRegistry.validate(veteran.data).is_empty(), "All %d soldiers of the battle are persons of the world (%d fallen)" % [soldiers, dead])
	var stranger: Dictionary = model.data.duplicate(true)
	stranger.village.militia = ["nobody_at_all"]
	_check(not PersonRegistry.validate(stranger).is_empty(), "A militia member who is no resident is rejected")


# -------------------------------------------------------------- relation graph

func _test_relation_api() -> void:
	var model = _campaign()
	model.finish_tribes()
	var graph: Dictionary = model.data.tribes.relations
	_check(typeof(graph) == TYPE_DICTIONARY and graph.has("edges") and not graph.edges.is_empty(), "The relation graph is part of the saved state (%d edges)" % graph.edges.size())
	var trust_before := Tribes._rel(model.data.tribes, "ubii_rhine", "player", "trust")
	var gift: Dictionary = model.relation_event("pc:player", "ubii_rhine", "gift", "Salz für die Ubier")
	_check(gift.ok and Tribes._rel(model.data.tribes, "ubii_rhine", "player", "trust") == trust_before + 6.0, "A deed of the player changes what the group feels: " + str(gift))
	var edge: Dictionary = model.data.tribes.relations.edges.get("ubii_rhine>player", {})
	var known := false
	for event: Dictionary in model.data.tribes.events:
		known = known or event.id == gift.get("event", "")
	_check(not edge.is_empty() and edge.memories.back().event == gift.get("event", "") and known, "The change carries its event; nothing is written without one")
	var before := _json(model.data.tribes.relations)
	_check(not model.relation_event("vil:decimus", "ubii_rhine", "gift").ok and not model.relation_event("pc:player", "nobody", "gift").ok and not model.relation_event("pc:player", "ubii_rhine", "flattery").ok and _json(model.data.tribes.relations) == before, "Unknown actors, groups and deeds change nothing")
	var dispute: Dictionary = model.mission_dispute("sugambri_sieg", "ubii_rhine", "mission:I-18", "Streit um die Furt")
	var found := {}
	for item: Dictionary in model.data.tribes.disputes:
		if item.id == dispute.get("dispute", ""):
			found = item
	_check(dispute.ok and found.get("cause", "") == "quest_dispute" and found.get("source", "") == "mission:I-18", "A mission records its dispute with cause and source (D-048): " + str(found))
	_check(not model.mission_dispute("sugambri_sieg", "ubii_rhine", "Hunger").ok and not model.mission_dispute("sugambri_sieg", "sugambri_sieg", "mission:I-18").ok, "A dispute without a mission or quest as source is refused")
	_check(model._validate_state(model.data).is_empty() and PersonRegistry.validate(model.data).is_empty(), "The world with the new relations is valid")
	var path := _path("relations")
	var loaded = WorldModel.new()
	_check(model.save_game(path).ok and loaded.load_game(path).ok and _json(loaded.data.tribes.relations) == _json(model.data.tribes.relations), "The graph survives save and load exactly")
	var legacy = WorldModel.new()
	_check(not legacy.relation_event("pc:player", "ubii_rhine", "gift").ok, "A world without a tribal situation has no graph to write")
	# One write path: only the relation core changes edges, only the tribal
	# simulation calls it, and everything else goes through the world state.
	var writers := {}
	_scan("res://scripts", writers)
	var callers: Array = writers.get("calls", [])
	var raw: Array = writers.get("raw", [])
	callers.sort()
	_check(callers == ["res://scripts/domain/tribal_world.gd"], "Only the tribal simulation calls the relation core's writers: " + str(callers))
	_check(raw.is_empty(), "No script edits relation edges directly: " + str(raw))


func _scan(path: String, found: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan(path.path_join(sub), found)
	for filename in dir.get_files():
		if not filename.ends_with(".gd"):
			continue
		var file := path.path_join(filename)
		if file == "res://scripts/domain/actor_relations.gd":
			continue
		var text := FileAccess.get_file_as_string(file)
		for writer: String in ["Relations.apply(", "Relations.introduce(", "Relations.decay(", "Relations.decay_keys("]:
			if text.contains(writer):
				if not found.has("calls"):
					found["calls"] = []
				if not file in found.calls:
					found.calls.append(file)
		for pattern: String in ["relations\\.edges\\[[^\\]]*\\](\\.\\w+|\\[[^\\]]*\\])*\\s*[-+*/]?=[^=]", "relations\\.edges\\.(erase|clear|merge)\\(", "relations\\.edges\\s*=[^=]"]:
			var regex := RegEx.create_from_string(pattern)
			if regex.search(text) != null:
				if not found.has("raw"):
					found["raw"] = []
				found.raw.append(file)
