extends RefCounted
## The single authoritative world time (D-045). Pure static functions over the
## saved world dictionary; WorldModel is the only caller that writes.
##
## Two saved blocks belong together:
## - `calendar` is the #98 world-time record (WorldCalendar.new_world_time):
##   clock {jdn, second}, origin_year, births, divergences. Every reader of a
##   date, a season, an age or an era asks this clock.
## - `world_state.time` is the time ledger. The clock is never set directly: it is
##   always epoch + every booked passage of time + the passages derived from
##   the village economy clock and the played valley battle. A save whose clock
##   differs from this sum is contradictory and rejected.
##
## Causes of passing time:
## - village  (derived) legacy village economy: one economy day = one calendar
##            day from 06:00. The childhood chapter counts narrated days
##            instead (sleep), because its economy cycles run independently of
##            the narrated day (village_economy.gd day_length).
## - battle   (derived) seconds of the played valley battle.
## - sleep    the childhood "rest" steps and later sleep: to the next morning.
## - night    the childhood night rest before I-10: to 22:00 of the same day.
## - travel, wait, rest   WorldModel.pass_calendar_days (travel, waiting and
##            sleeping away from the family house, in whole days).
## - trade    a completed shop transaction takes TRADE_SECONDS.
## - jump     the time-jump contract (six years at the start of training).
## - season   one season of the regional campaign.
## - migration   days an old save had already lived when it gained a calendar.
##
## Ages derive from `calendar.births`; tribal weeks from the clock (tribal
## epoch 1 March of the scenario year); era and history anchors read the same
## JDN. Nothing else may count calendar time.

const Calendar = preload("res://scripts/domain/world_calendar.gd")
const Era = preload("res://scripts/domain/era_registry.gd")

const VERSION := 1
const MORNING := 21600
const NIGHT := 79200
const DAY := 86400
## Balance value (central, D-045 3): haggling and paying in a shop.
const TRADE_SECONDS := 1800
## Legacy careers keep their own Trajan-era timeline (D-044).
const LEGACY_ORIGIN_YEAR := 100
const CAMPAIGN_ORIGIN_YEAR := -58
const START_AGE := 12
const BOOKED := ["sleep", "night", "travel", "wait", "rest", "trade", "jump", "season", "migration"]
const COUNTED := ["sleep", "night", "travel", "wait", "rest", "trade", "jump", "season"]
## Causes a caller of WorldModel.pass_calendar_days may name -> ledger cause.
const PASS_CAUSES := {"travel": "travel", "wait": "wait", "sleep": "rest"}
const PASS_LABELS := {"travel": "Reise", "wait": "Warten", "sleep": "Schlaf unterwegs"}
const DERIVED := ["village", "battle"]
const MAX_PASS_DAYS := 3650
## Display labels of registry states (the registry carries ids and sources only).
const RULER_LABELS := {
	"political.rome.first_triumvirate": "Römische Republik · Erstes Triumvirat (Caesar, Pompeius, Crassus)",
	"political.rome.caesar_dictatorship": "Römische Republik · Diktatur Caesars",
	"political.rome.second_triumvirate": "Römische Republik · Zweites Triumvirat",
	"political.rome.principate_augustus": "Prinzipat des Augustus",
	"political.rome.principate_tiberius": "Prinzipat des Tiberius",
}
const ANCHOR_TITLES := {
	"anchor.helvetii_assembly": "Die Helvetier sammeln sich an der Rhone",
	"anchor.aquileia_legions": "Drei Legionen überwintern bei Aquileia",
	"anchor.alesia": "Belagerung von Alesia",
	"anchor.rubicon": "Caesar überschreitet den Rubikon",
	"anchor.pharsalus": "Schlacht bei Pharsalos",
	"anchor.ides_of_march": "Die Iden des März",
	"anchor.actium": "Schlacht bei Actium",
	"anchor.augustus_title": "Octavian erhält den Namen Augustus",
	"anchor.varus_battle": "Varusschlacht",
	"anchor.death_of_augustus": "Tod des Augustus",
}
## The older 100 AD careers keep their own documented anchors (D-044).
const LEGACY_ANCHORS := [
	{"id":"trajan_reign", "year_start":98, "year_end":117, "title":"Trajan regiert das Römische Reich", "kind":"documented", "source":"https://cultura.gov.it/luogo/parco-archeologico-del-colosseo-colonna-traiana"},
	{"id":"dacian_war_1", "year_start":101, "year_end":102, "title":"Erster Dakerkrieg Trajans", "kind":"documented", "source":"https://colonnatraiana.cultura.gov.it/"},
	{"id":"dacian_war_2", "year_start":105, "year_end":106, "title":"Zweiter Dakerkrieg Trajans", "kind":"documented", "source":"https://colonnatraiana.cultura.gov.it/"}
]


# --- construction -----------------------------------------------------------------

static func origin_year_of(world: Dictionary) -> int:
	var year := int(world.get("village", {}).get("history", {}).get("start_year", LEGACY_ORIGIN_YEAR))
	return year if Calendar.is_valid_year(year) else LEGACY_ORIGIN_YEAR


static func start_jdn(origin_year: int) -> int:
	## Campaign: Kalendae Maiae 58 v. Chr. (#98, provisional). Legacy: spring 100 AD.
	if origin_year == CAMPAIGN_ORIGIN_YEAR:
		return Calendar.campaign_start_jdn()
	return Calendar.season_start(origin_year, 0)


static func births_for(origin_year: int, age := START_AGE) -> Dictionary:
	## Year precision, the convention of the mission sheets (70 v. Chr. for 58 v. Chr.).
	var year := Calendar.add_years(origin_year, -age)
	return {"player": {"year": year}, "companion": {"year": year}}


static func new_calendar(origin_year: int, jdn: int, second: int, births: Dictionary) -> Dictionary:
	return Calendar.new_world_time(jdn, second, origin_year, births)


static func new_ledger(epoch_jdn: int, epoch_second: int) -> Dictionary:
	var passed := {}
	for cause: String in BOOKED:
		passed[cause] = 0
	var counts := {}
	for cause: String in COUNTED:
		counts[cause] = 0
	return {"version": VERSION, "epoch": {"jdn": epoch_jdn, "second": epoch_second}, "passed": passed, "counts": counts,
		"last": {"cause": "start", "reason": "Beginn der Weltzeit", "seconds": 0}}


## A new world: calendar and ledger at the start date of its timeline.
static func start(world: Dictionary) -> void:
	var origin := origin_year_of(world)
	var jdn := start_jdn(origin)
	world.calendar = new_calendar(origin, jdn, MORNING, births_for(origin))
	world.world_state.time = new_ledger(jdn, MORNING)


# --- derived passages -------------------------------------------------------------

static func village_seconds(world: Dictionary) -> int:
	## Legacy village: one economy day is one calendar day from the epoch.
	var village: Dictionary = world.get("village", {})
	if not bool(village.get("enabled", false)) or village.has("childhood") or not village.has("economy"):
		return 0
	var economy: Dictionary = village.economy
	var length := 120.0
	return int(economy.get("day", 0)) * DAY + floori(float(economy.get("day_seconds", 0.0)) * DAY / length)


static func battle_seconds(world: Dictionary) -> int:
	var valley: Variant = world.get("valley", {})
	if not valley is Dictionary or (valley as Dictionary).is_empty():
		return 0
	# BattleModel.STEP (0.2 s) per simulation step; preloading the battle
	# model here would pull the whole battle module into every clock read.
	@warning_ignore("integer_division")
	return int(valley.get("snapshot", {}).get("steps", 0)) / 5


static func total_seconds(world: Dictionary) -> int:
	var ledger: Dictionary = world.world_state.time
	var total := int(ledger.epoch.jdn) * DAY + int(ledger.epoch.second)
	for cause: String in BOOKED:
		total += int(ledger.passed[cause])
	return total + village_seconds(world) + battle_seconds(world)


static func expected_clock(world: Dictionary) -> Dictionary:
	var total := total_seconds(world)
	return Calendar.new_clock(floori(total / float(DAY)), posmod(total, DAY))


## Writes the clock from the ledger and every derived age; the only clock writer.
static func sync(world: Dictionary) -> void:
	var clock := expected_clock(world)
	if clock.is_empty():
		return
	world.calendar.clock = clock
	_sync_ages(world)


static func _sync_ages(world: Dictionary) -> void:
	var player_age := Calendar.world_time_age(world.calendar, "player")
	var companion_age := Calendar.world_time_age(world.calendar, "companion")
	if player_age >= 0 and world.has("player"):
		world.player.age = player_age
	if companion_age >= 0 and world.has("companion"):
		world.companion.age = companion_age
	if world.has("progress"):
		world.progress.years_elapsed = elapsed_years(world)


## Books a passage of time and moves the clock; returns the seconds booked.
static func book(world: Dictionary, cause: String, seconds: int, reason: String) -> int:
	if cause not in BOOKED or seconds < 0:
		return 0
	var ledger: Dictionary = world.world_state.time
	ledger.passed[cause] = int(ledger.passed[cause]) + seconds
	if COUNTED.has(cause):
		ledger.counts[cause] = int(ledger.counts[cause]) + 1
	ledger.last = {"cause": cause, "reason": reason.left(160), "seconds": seconds}
	sync(world)
	return seconds


static func seconds_to_morning(world: Dictionary) -> int:
	var second := int(world.calendar.clock.second)
	return (DAY - second) + MORNING if second >= MORNING else MORNING - second


static func sleep(world: Dictionary, reason := "Schlaf bis zum Morgen") -> int:
	return book(world, "sleep", seconds_to_morning(world), reason)


static func night(world: Dictionary, reason := "Nachtruhe") -> int:
	var second := int(world.calendar.clock.second)
	return book(world, "night", maxi(0, NIGHT - second), reason)


static func next_season_jdn(world: Dictionary) -> int:
	var origin := int(world.calendar.origin_year)
	var turn := Calendar.season_turn(int(world.calendar.clock.jdn), origin)
	return Calendar.season_turn_start(turn + 1, origin)


static func season(world: Dictionary, reason := "Eine Jahreszeit vergeht") -> int:
	var target := next_season_jdn(world) * DAY + MORNING
	var now := int(world.calendar.clock.jdn) * DAY + int(world.calendar.clock.second)
	return book(world, "season", maxi(0, target - now), reason)


# --- readers ----------------------------------------------------------------------

static func jdn(world: Dictionary) -> int:
	return int(world.calendar.clock.jdn)


static func year(world: Dictionary) -> int:
	return Calendar.year_of(jdn(world))


static func elapsed_years(world: Dictionary) -> int:
	return maxi(0, Calendar.years_between(int(world.calendar.origin_year), year(world)))


static func age(world: Dictionary, actor := "player") -> int:
	return Calendar.world_time_age(world.calendar, actor)


static func is_legacy(world: Dictionary) -> bool:
	return int(world.calendar.origin_year) != CAMPAIGN_ORIGIN_YEAR


## Days since a tribal epoch (1 March of `year`); the tribal world reads these.
static func days_since_spring(world: Dictionary, epoch_year: int) -> int:
	return Calendar.days_between(Calendar.season_start(epoch_year, 0), jdn(world))


## Season of the regional campaign round (turn % 4), for screens that show
## the round next to the world date.
static func season_name(index: int) -> String:
	return Calendar.SEASON_NAMES_DE[posmod(index, 4)]


static func view(world: Dictionary) -> Dictionary:
	## Presentation data, one source for HUD, atlas, panels and tests.
	if not world.has("calendar") or not Calendar.validate_world_time(world.calendar):
		return {}
	var day := jdn(world)
	var date := Calendar.from_jdn(day)
	var second := int(world.calendar.clock.second)
	var season_index := Calendar.season_index(day)
	var y := int(date.year)
	return {"jdn": day, "year": y, "month": int(date.month), "day": int(date.day), "second": second,
		"hour": floori(second / 3600.0), "minute": floori(posmod(second, 3600) / 60.0),
		"season": Calendar.SEASON_IDS[season_index], "season_name": Calendar.SEASON_NAMES_DE[season_index],
		"season_year": Calendar.season_year(day), "year_label": Calendar.format_year(y),
		"date_label": Calendar.format_date(day), "day_label": "%d. %s" % [int(date.day), Calendar.MONTH_NAMES_DE[int(date.month) - 1]], "roman_label": Calendar.format_roman(day, false),
		"night": second >= NIGHT or second < 18000, "origin_year": int(world.calendar.origin_year),
		"legacy_timeline": is_legacy(world), "player_age": age(world, "player"),
		"last": (world.get("world_state", {}).get("time", {}).get("last", {}) as Dictionary).duplicate()}


## Historical frame from the same date: ruler and anchors (registry for the
## campaign, own entries for the 100 AD careers, nothing for other peoples).
static func history_frame(world: Dictionary) -> Dictionary:
	return frame_at(jdn(world), is_legacy(world), str(world.get("origin_id", "italia")) == "italia", world.calendar.divergences)


## The frame of any date; `legacy` selects the 100 AD timeline (D-044).
static func frame_at(day: int, legacy: bool, roman: bool, divergences: Dictionary = {}) -> Dictionary:
	var y := Calendar.year_of(day)
	var anchors := []
	var ruler := "Bestehende Ortsverwaltung"
	if roman and legacy:
		for item: Dictionary in LEGACY_ANCHORS:
			anchors.append(item.duplicate(true))
		ruler = "Trajan" if y >= 98 and y <= 117 else "Römische Staatsgewalt"
	elif roman:
		for id: String in Era.active("historical_anchor", day, divergences):
			var entry := Era.entry(id)
			anchors.append({"id": id, "title": str(ANCHOR_TITLES.get(id, id)), "kind": str(entry.get("status", "")), "source": str(entry.get("source", ""))})
		ruler = "Römische Republik"
		for slot: String in ["rome.princeps", "rome.dictatorship", "rome.power_bloc"]:
			var state := Era.state_at(slot, day, divergences)
			if not state.is_empty():
				ruler = str(RULER_LABELS.get(state, state))
				break
	return {"year": y, "year_label": Calendar.format_year(y), "ruler": ruler, "anchors": anchors, "jdn": day}


# --- validation -----------------------------------------------------------------------

static func validate(world: Dictionary) -> String:
	if not Calendar.validate_world_time(world.get("calendar")):
		return "Die Weltzeit fehlt oder ist ungültig."
	if not world.calendar.divergences.is_empty() and not Era.validate_overrides(world.calendar.divergences).is_empty():
		return "Ungültige markierte Geschichtsdivergenz."
	var ledger: Variant = world.get("world_state", {}).get("time")
	if not _keys(ledger, ["version", "epoch", "passed", "counts", "last"]) or not _int(ledger.version, VERSION, VERSION):
		return "Das Zeitbuch der Weltzeit fehlt."
	if not _keys(ledger.epoch, ["jdn", "second"]) or not _int(ledger.epoch.jdn, 0, Calendar.max_jdn()) or not _int(ledger.epoch.second, 0, DAY - 1):
		return "Ungültiger Beginn der Weltzeit."
	if not _keys(ledger.passed, BOOKED) or not _keys(ledger.counts, COUNTED):
		return "Unbekannte Ursache im Zeitbuch."
	for cause: String in BOOKED:
		if not _int(ledger.passed[cause], 0, 9007199254740991):
			return "Ungültige gebuchte Zeitspanne."
	for cause: String in COUNTED:
		if not _int(ledger.counts[cause], 0, 1000000):
			return "Ungültiger Zähler im Zeitbuch."
	if not _keys(ledger.last, ["cause", "reason", "seconds"]) or typeof(ledger.last.cause) != TYPE_STRING or typeof(ledger.last.reason) != TYPE_STRING or not _int(ledger.last.seconds, 0, 9007199254740991):
		return "Ungültiger letzter Zeiteintrag."
	var origin := int(world.calendar.origin_year)
	if origin != origin_year_of(world):
		return "Weltzeit und Geschichtsrahmen gehören zu verschiedenen Zeitlinien."
	if expected_clock(world) != Calendar.normalize_clock(world.calendar.clock):
		return "Die Weltuhr widerspricht ihrem Zeitbuch; keine Zeit darf außerhalb der Weltzeit vergehen."
	for actor: String in ["player", "companion"]:
		if not world.calendar.births.has(actor):
			return "Geburtsdaten fehlen in der Weltzeit."
	if world.has("player") and int(world.player.age) != age(world, "player"):
		return "Das Alter der Spielfigur entsteht nur aus der Weltzeit."
	if world.has("companion") and int(world.companion.age) != age(world, "companion"):
		return "Das Alter des Gefährten entsteht nur aus der Weltzeit."
	if world.has("progress") and int(world.progress.years_elapsed) != elapsed_years(world):
		return "Vergangene Jahre und Weltzeit widersprechen sich."
	if world.has("strategy") and int(ledger.counts.season) != int(world.strategy.get("turn", 0)):
		return "Jahreszeiten der Regionalkampagne fehlen im Zeitbuch."
	if (int(ledger.counts.season) == 0) != (int(ledger.passed.season) == 0):
		return "Jahreszeitbuchung ohne Jahreszeit."
	if (int(ledger.counts.jump) == 0) != (int(ledger.passed.jump) == 0) or int(ledger.counts.jump) > 1:
		return "Ungültiger Zeitsprung im Zeitbuch."
	var village: Dictionary = world.get("village", {})
	if village.has("childhood"):
		if int(ledger.counts.sleep) != int(village.childhood.get("day", 1)) - 1:
			return "Erzählte Dorftage und Schlaf in der Weltzeit widersprechen sich."
		var night_done: bool = "night_rest" in village.childhood.get("completed", [])
		if int(ledger.counts.night) != (1 if night_done else 0):
			return "Die Nachtruhe fehlt in der Weltzeit."
	elif int(ledger.counts.sleep) != 0 or int(ledger.counts.night) != 0:
		return "Schlaf ohne Kindheitstag."
	return ""


static func normalize(world: Dictionary) -> void:
	world.calendar = Calendar.normalize_world_time(world.calendar)
	var ledger: Dictionary = world.world_state.time
	ledger.version = int(ledger.version)
	ledger.epoch.jdn = int(ledger.epoch.jdn)
	ledger.epoch.second = int(ledger.epoch.second)
	for cause: String in BOOKED:
		ledger.passed[cause] = int(ledger.passed[cause])
	for cause: String in COUNTED:
		ledger.counts[cause] = int(ledger.counts[cause])
	ledger.last.seconds = int(ledger.last.seconds)


static func _keys(value: Variant, keys: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or (value as Dictionary).size() != keys.size():
		return false
	for key: Variant in keys:
		if not value.has(key):
			return false
	return true


static func _int(value: Variant, low: int, high: int) -> bool:
	return Calendar.is_integral(value) and int(value) >= low and int(value) <= high
