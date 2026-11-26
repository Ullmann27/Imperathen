extends SceneTree
## WorldCalendar: no year zero, JDN round trips, durations and ages across
## 1 v. Chr. -> 1 n. Chr., seasons, Roman display and the save clock.

const Calendar = preload("res://scripts/domain/world_calendar.gd")
const Policy = preload("res://scripts/story/life_path_policy.gd")
var checks := 0
var failures := 0


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func _initialize() -> void:
	_years()
	_day_numbers()
	_durations()
	_ages()
	_seasons()
	_roman_display()
	_clock()
	print("WORLD_CALENDAR checks=%d failures=%d" % [checks, failures])
	if failures == 0:
		print("WORLD_CALENDAR_PASS")
	quit(1 if failures else 0)


func _years() -> void:
	check(not Calendar.is_valid_year(0), "year 0 does not exist")
	check(Calendar.to_astronomical(-1) == 0 and Calendar.to_astronomical(-58) == -57 and Calendar.to_astronomical(1) == 1, "historical -> astronomical")
	check(Calendar.from_astronomical(0) == -1 and Calendar.from_astronomical(1) == 1 and Calendar.from_astronomical(-57) == -58, "astronomical -> historical")
	var broken := 0
	var previous := Calendar.to_astronomical(Calendar.MIN_YEAR) - 1
	for year in range(Calendar.MIN_YEAR, Calendar.MAX_YEAR + 1):
		if year == 0:
			continue
		var astronomical := Calendar.to_astronomical(year)
		if Calendar.from_astronomical(astronomical) != year or astronomical != previous + 1 or Calendar.from_astronomical(astronomical) == 0:
			broken += 1
		previous = astronomical
	check(broken == 0, "every year round-trips and astronomical years are gapless (%d broken)" % broken)
	check(Calendar.add_years(-1, 1) == 1, "-1 + 1 year = +1 (1 v. Chr. -> 1 n. Chr.)")
	check(Calendar.add_years(1, -1) == -1, "1 n. Chr. - 1 year = 1 v. Chr.")
	check(Calendar.add_years(-58, 57) == -1 and Calendar.add_years(-58, 58) == 1, "58 v. Chr. + 58 years = 1 n. Chr.")
	check(Calendar.add_years(-70, 79) == 10 and Calendar.add_years(-1, 0) == -1, "additions across the era boundary")
	check(Calendar.add_years(0, 1) == 0 and Calendar.add_years(Calendar.MAX_YEAR, 1) == 0, "invalid input or range yields 0, never a fake year")
	check(Calendar.years_between(-1, 1) == 1 and Calendar.years_between(-58, -52) == 6, "elapsed years without year zero")
	check(Calendar.years_between(-58, 9) == 66 and Calendar.years_between(-58, 80) == 137 and Calendar.years_between(9, -58) == -66, "Varus battle and Colosseum distances")
	var parity := true
	for a: int in [-100, -58, -45, -2, -1, 1, 2, 9, 80]:
		for b: int in [-100, -58, -45, -2, -1, 1, 2, 9, 80]:
			if b >= a and Policy.elapsed_years(a, b) != Calendar.years_between(a, b):
				parity = false
	check(parity, "LifePathPolicy.elapsed_years agrees with WorldCalendar")
	check(Calendar.is_leap_year(-1) and Calendar.is_leap_year(-5) and Calendar.is_leap_year(-45) and Calendar.is_leap_year(4), "proleptic Julian leap years 1, 5, 45 v. Chr. and 4 n. Chr.")
	check(not Calendar.is_leap_year(-4) and not Calendar.is_leap_year(1) and not Calendar.is_leap_year(-58) and not Calendar.is_leap_year(0), "common years")
	check(Calendar.days_in_year(-1) == 366 and Calendar.days_in_year(-58) == 365 and Calendar.days_in_year(0) == 0, "year lengths")
	check(Calendar.days_in_month(-45, 2) == 29 and Calendar.days_in_month(-44, 2) == 28 and Calendar.days_in_month(-44, 4) == 30 and Calendar.days_in_month(0, 1) == 0, "month lengths")


func _day_numbers() -> void:
	check(Calendar.to_jdn(-4713, 1, 1) == 0, "JDN 0 is 1 January 4713 v. Chr. (Julian)")
	check(Calendar.to_jdn(1, 1, 1) == 1721424, "1 January 1 n. Chr. = JDN 1721424")
	check(Calendar.to_jdn(-1, 12, 31) == 1721423 and Calendar.to_jdn(-1, 1, 1) == 1721058, "1 v. Chr. is a 366-day year directly before 1 n. Chr.")
	check(Calendar.to_jdn(1999, 12, 19) == 2451545, "Julian 19 Dec 1999 = Gregorian 1 Jan 2000 = JDN 2451545")
	check(Calendar.to_jdn(-44, 3, 15) == 1705426, "Ides of March 44 v. Chr. = JDN 1705426")
	check(Calendar.to_jdn(0, 1, 1) == Calendar.INVALID and Calendar.to_jdn(-58, 2, 29) == Calendar.INVALID and Calendar.to_jdn(-58, 13, 1) == Calendar.INVALID, "year 0 and impossible dates are rejected")
	check(Calendar.to_jdn(-57, 2, 29) != Calendar.INVALID, "57 v. Chr. is a leap year")
	check(Calendar.from_jdn(1721424) == {"year": 1, "month": 1, "day": 1} and Calendar.from_jdn(1721423) == {"year": -1, "month": 12, "day": 31}, "JDN -> date across the boundary")
	check(Calendar.from_jdn(-1).is_empty() and Calendar.from_jdn(Calendar.max_jdn() + 1).is_empty(), "out-of-range JDN")
	var broken := 0
	var first := Calendar.to_jdn(-100, 1, 1)
	var last := Calendar.to_jdn(100, 12, 31)
	var previous: Dictionary = Calendar.from_jdn(first - 1)
	for jdn in range(first, last + 1):
		var date := Calendar.from_jdn(jdn)
		if Calendar.date_to_jdn(date) != jdn or int(date.year) == 0:
			broken += 1
		elif int(date.day) != int(previous.day) + 1 and not (int(date.day) == 1 and int(previous.day) == Calendar.days_in_month(int(previous.year), int(previous.month))):
			broken += 1
		previous = date
	check(broken == 0, "daily round trip and continuity 100 v. Chr. - 100 n. Chr. (%d broken)" % broken)
	broken = 0
	for jdn in range(0, Calendar.max_jdn() + 1, 997):
		if Calendar.date_to_jdn(Calendar.from_jdn(jdn)) != jdn:
			broken += 1
	check(broken == 0, "sparse round trip over the supported range")
	check(Calendar.campaign_start_jdn() == Calendar.to_jdn(-58, 5, 1) and Calendar.campaign_start_jdn() == 1700359, "provisional campaign start 1 May 58 v. Chr.")


func _durations() -> void:
	var last_bc := Calendar.to_jdn(-1, 12, 31)
	var first_ad := Calendar.to_jdn(1, 1, 1)
	check(Calendar.days_between(last_bc, first_ad) == 1 and Calendar.add_days(last_bc, 1) == first_ad, "31 Dec 1 v. Chr. is followed by 1 Jan 1 n. Chr.")
	check(Calendar.days_between(Calendar.to_jdn(-1, 1, 1), first_ad) == 366, "1 v. Chr. lasts 366 days")
	check(Calendar.add_calendar_years(Calendar.to_jdn(-1, 1, 1), 1) == first_ad, "one calendar year after 1 Jan 1 v. Chr.")
	check(Calendar.add_calendar_years(Calendar.to_jdn(-5, 2, 29), 1) == Calendar.to_jdn(-4, 2, 28), "29 February clamps in a common year")
	check(Calendar.add_calendar_years(Calendar.campaign_start_jdn(), 6) == Calendar.to_jdn(-52, 5, 1), "legacy six-year jump lands in 52 v. Chr.")
	check(Calendar.add_calendar_years(Calendar.to_jdn(-10, 6, 1), 20) == Calendar.to_jdn(11, 6, 1), "20 years from 10 v. Chr. is 11 n. Chr.")
	check(Calendar.add_months(Calendar.to_jdn(-1, 12, 15), 1) == Calendar.to_jdn(1, 1, 15) and Calendar.add_months(Calendar.to_jdn(1, 1, 31), -1) == last_bc, "months across the boundary")
	check(Calendar.add_months(Calendar.to_jdn(-45, 1, 31), 1) == Calendar.to_jdn(-45, 2, 29), "month end clamps to 29 Feb 45 v. Chr.")
	check(Calendar.add_days(0, -1) == Calendar.INVALID, "durations stay in range")


func _ages() -> void:
	var hero := Calendar.PROTAGONIST_BIRTH
	check(Calendar.age_on(hero, Calendar.campaign_start_jdn()) == 12, "protagonist is 12 at campaign start")
	check(Calendar.age_on(hero, Calendar.to_jdn(-44, 3, 15)) == 26 and Calendar.age_on(hero, Calendar.to_jdn(-27, 1, 16)) == 43, "ages 26 at the Ides and 43 in 27 v. Chr.")
	var varus := Calendar.age_on(hero, Calendar.to_jdn(9, 9, 9))
	check(varus == 78 and varus != 70 + 9, "age at the Varus battle is 78, not the naive 79")
	check(Calendar.age_in_year(-70, -58) == 12 and Calendar.age_in_year(-70, 9) == 78 and Calendar.age_in_year(-70, -1) == 69 and Calendar.age_in_year(-70, 1) == 70, "age by year across the era boundary")
	check(Calendar.age_in_year(0, -58) == Calendar.INVALID and Calendar.age_in_year(-58, -70) == Calendar.INVALID, "invalid or pre-birth ages")
	var dated := {"year": -70, "month": 3, "day": 10}
	check(Calendar.age_on(dated, Calendar.to_jdn(-58, 3, 9)) == 11 and Calendar.age_on(dated, Calendar.to_jdn(-58, 3, 10)) == 12, "birthday boundary")
	check(Calendar.age_on(dated, Calendar.to_jdn(-44, 3, 15)) == 26 and Calendar.age_on(dated, Calendar.to_jdn(-70, 3, 9)) == Calendar.INVALID, "full-date ages and before birth")
	var boundary := {"year": -2, "month": 6, "day": 1}
	check(Calendar.age_on(boundary, Calendar.to_jdn(2, 5, 31)) == 2 and Calendar.age_on(boundary, Calendar.to_jdn(2, 6, 1)) == 3, "born 2 v. Chr. is 3 on the birthday in 2 n. Chr.")
	var leap := {"year": -5, "month": 2, "day": 29}
	check(Calendar.age_on(leap, Calendar.to_jdn(-4, 2, 28)) == 0 and Calendar.age_on(leap, Calendar.to_jdn(-4, 3, 1)) == 1 and Calendar.age_on(leap, Calendar.to_jdn(4, 2, 29)) == 8, "29 February birthdays count from 1 March")
	check(Calendar.age_on({"year": 0}, Calendar.campaign_start_jdn()) == Calendar.INVALID and Calendar.age_on({"year": -70, "month": 2}, Calendar.campaign_start_jdn()) == Calendar.INVALID, "incomplete or impossible birth records")
	check(Calendar.birth_year_for_age(12, -58) == -70 and Calendar.birth_year_for_age(78, 9) == -70 and Calendar.birth_year_for_age(1, 1) == -1 and Calendar.birth_year_for_age(3, 0) == 0, "birth years")


func _seasons() -> void:
	var start := Calendar.campaign_start_jdn()
	check(Calendar.season_index(start) == 0 and Calendar.season_index(Calendar.to_jdn(-58, 6, 1)) == 1 and Calendar.season_index(Calendar.to_jdn(-58, 9, 1)) == 2, "spring, summer, autumn")
	check(Calendar.season_index(Calendar.to_jdn(-58, 12, 1)) == 3 and Calendar.season_index(Calendar.to_jdn(-57, 2, 15)) == 3, "winter spans the turn of the year")
	check(Calendar.season_index(start, -30.0) == 2, "southern latitudes are shifted like season_campaign.gd")
	check(Calendar.season_year(Calendar.to_jdn(-57, 1, 15)) == -58 and Calendar.season_year(Calendar.to_jdn(1, 1, 15)) == -1 and Calendar.season_year(Calendar.to_jdn(-1, 12, 1)) == -1, "January belongs to the previous winter")
	check(Calendar.season_turn(start) == 0 and Calendar.season_turn(Calendar.to_jdn(-57, 3, 1)) == 4, "turn 0 is spring 58 v. Chr.")
	check(Calendar.season_turn(Calendar.to_jdn(-1, 12, 1)) == 231 and Calendar.season_turn(Calendar.to_jdn(1, 1, 15)) == 231 and Calendar.season_turn(Calendar.to_jdn(1, 3, 1)) == 232, "turns stay contiguous over 1 v. -> 1 n. Chr.")
	check(Calendar.season_turn_start(0) == Calendar.to_jdn(-58, 3, 1) and Calendar.season_turn_start(231) == Calendar.to_jdn(-1, 12, 1) and Calendar.season_turn_start(232) == Calendar.to_jdn(1, 3, 1), "turn starts")
	var broken := 0
	for turn in range(-8, 401):
		if Calendar.season_turn(Calendar.season_turn_start(turn)) != turn:
			broken += 1
	check(broken == 0, "season turn round trip")
	check(Calendar.add_years(Calendar.CAMPAIGN_START.year, floori(232 / 4.0)) == 1, "season_campaign year for turn 232 is 1 n. Chr.")
	check(Calendar.season_turn(-5) == Calendar.INVALID_TURN and Calendar.season_turn_start(Calendar.INVALID_TURN) == Calendar.INVALID, "invalid season input")


func _roman_display() -> void:
	check(Calendar.roman_day(Calendar.to_jdn(-58, 3, 28)) == "a.d. V Kal. Apr.", "a.d. V Kal. Apr. = 28 March (BG 1.6.4)")
	check(Calendar.roman_day(Calendar.to_jdn(-58, 4, 13)) == "Id. Apr.", "Ides of April = 13 April (BG 1.7.6)")
	var expected := {[-44, 3, 15]: "Id. Mart.", [-44, 3, 14]: "prid. Id. Mart.", [-44, 3, 1]: "Kal. Mart.", [-44, 3, 7]: "Non. Mart.",
		[-44, 3, 6]: "prid. Non. Mart.", [-44, 3, 2]: "a.d. VI Non. Mart.", [-44, 3, 8]: "a.d. VIII Id. Mart.", [-44, 1, 13]: "Id. Ian.",
		[-44, 1, 5]: "Non. Ian.", [-44, 12, 31]: "prid. Kal. Ian.", [-44, 12, 14]: "a.d. XIX Kal. Ian.", [-44, 2, 13]: "Id. Feb.",
		[-44, 2, 14]: "a.d. XVI Kal. Mart.", [-44, 2, 24]: "a.d. VI Kal. Mart.", [-44, 2, 28]: "prid. Kal. Mart.",
		[-45, 2, 24]: "a.d. VI Kal. Mart.", [-45, 2, 25]: "a.d. bis VI Kal. Mart.", [-45, 2, 26]: "a.d. V Kal. Mart.", [-45, 2, 29]: "prid. Kal. Mart.",
		[-44, 7, 7]: "Non. Iul.", [-45, 7, 7]: "Non. Quint.", [-44, 6, 20]: "a.d. XII Kal. Iul.", [-45, 6, 30]: "prid. Kal. Quint.",
		[-8, 8, 1]: "Kal. Aug.", [-9, 8, 1]: "Kal. Sext.", [-9, 7, 31]: "prid. Kal. Sext.", [1, 1, 1]: "Kal. Ian.", [-1, 12, 31]: "prid. Kal. Ian."}
	for key: Array in expected:
		var label := Calendar.roman_day(Calendar.to_jdn(key[0], key[1], key[2]))
		check(label == expected[key], "Roman day %s: %s (got %s)" % [str(key), expected[key], label])
	check(Calendar.latin_month_name(-45, 7) == "Quintilis" and Calendar.latin_month_name(-44, 7) == "Iulius", "Quintilis becomes Iulius in 44 v. Chr.")
	check(Calendar.latin_month_name(-9, 8) == "Sextilis" and Calendar.latin_month_name(-8, 8) == "Augustus", "Sextilis becomes Augustus in 8 v. Chr.")
	check(Calendar.auc_year(-58) == 696 and Calendar.auc_year(-44) == 710 and Calendar.auc_year(-1) == 753 and Calendar.auc_year(1) == 754 and Calendar.auc_year(9) == 762 and Calendar.auc_year(-753) == 1, "Varronian a.u.c. years")
	check(Calendar.auc_year(0) == Calendar.INVALID and not Calendar.AUC_SOURCE_NOTE.is_empty(), "a.u.c. needs a valid year and carries a source note")
	check(Calendar.roman_numeral(696) == "DCXCVI" and Calendar.roman_numeral(710) == "DCCX" and Calendar.roman_numeral(1999) == "MCMXCIX" and Calendar.roman_numeral(0) == "", "Roman numerals")
	var ides := Calendar.to_jdn(-44, 3, 15)
	check(Calendar.format_roman(ides) == "Id. Mart. DCCX a.u.c." and Calendar.format_roman(ides, false) == "Id. Mart.", "Roman date with optional a.u.c.")
	check(Calendar.format_year(-58) == "58 v. Chr." and Calendar.format_year(1) == "1 n. Chr." and Calendar.format_year(0) == "?", "German year labels")
	check(Calendar.format_year(-58, "en") == "58 BC" and Calendar.format_year(9, "en") == "AD 9", "English year labels")
	check(Calendar.format_date(ides) == "15. März 44 v. Chr." and Calendar.format_date(ides, "en") == "15 March 44 BC", "date labels")


func _clock() -> void:
	var start := Calendar.campaign_start_jdn()
	var clock := Calendar.new_clock(start, 21600)
	check(Calendar.validate_clock(clock), "new clock is valid")
	var parsed: Variant = JSON.parse_string(JSON.stringify(clock))
	check(parsed is Dictionary and parsed.jdn is float, "JSON turns integers into floats")
	check(Calendar.validate_clock(parsed) and Calendar.normalize_clock(parsed) == clock and Calendar.normalize_clock(parsed).jdn is int, "clock survives a JSON round trip exactly")
	check(JSON.stringify(Calendar.new_clock(start, 21600)) == JSON.stringify(clock), "clock serialization is deterministic")
	check(Calendar.new_clock(-5).is_empty() and Calendar.new_clock(start, Calendar.DAY_SECONDS).is_empty() and Calendar.new_clock(start, -1).is_empty(), "invalid clocks are not created")
	var extra := clock.duplicate()
	extra["year"] = -58
	var fractional := clock.duplicate()
	fractional.jdn = 1700359.5
	var schema := clock.duplicate()
	schema.schema = 2
	var system := clock.duplicate()
	system.system = "gregorian"
	check(not Calendar.validate_clock(extra) and not Calendar.validate_clock(fractional) and not Calendar.validate_clock(schema) and not Calendar.validate_clock(system), "unknown fields, fractions, schema or system are rejected")
	var later := Calendar.advance_clock(clock, 3 * Calendar.DAY_SECONDS + 3600)
	check(int(later.jdn) == start + 3 and int(later.second) == 25200 and Calendar.advance_clock(clock, -1).is_empty(), "advancing the clock")
	var night := Calendar.new_clock(Calendar.to_jdn(-1, 12, 31), 82800)
	var morning := Calendar.advance_clock(night, 7200)
	check(int(morning.jdn) == Calendar.to_jdn(1, 1, 1) and int(morning.second) == 3600 and int(Calendar.clock_date(morning).year) == 1, "the clock crosses from 1 v. Chr. into 1 n. Chr.")
	var date := Calendar.clock_date(clock)
	check(date.season == "spring" and int(date.season_year) == -58 and int(date.year) == -58, "clock date carries season and season year")
	var births := {"player": Calendar.PROTAGONIST_BIRTH.duplicate(), "julia": {"year": -92, "month": 6, "day": 10}}
	var world_time := Calendar.new_world_time(start, 21600, -58, births)
	check(Calendar.validate_world_time(world_time) and Calendar.world_time_age(world_time, "player") == 12 and Calendar.world_time_age(world_time, "julia") == 33, "save block derives ages from births")
	var reloaded: Variant = JSON.parse_string(JSON.stringify(world_time))
	check(Calendar.normalize_world_time(reloaded) == world_time and Calendar.normalize_world_time(reloaded).births.julia.month is int, "save block survives a JSON round trip exactly")
	check(Calendar.new_world_time(start, 0, 0).is_empty() and Calendar.new_world_time(start, 0, -57).is_empty(), "origin year 0 or a clock before the origin year is rejected")
	check(Calendar.new_world_time(start, 0, -58, {"x": {"year": 0}}).is_empty() and Calendar.new_world_time(start, 0, -58, {"x": {"year": -70, "month": 3}}).is_empty() and Calendar.new_world_time(start, 0, -58, {"x": {"year": -70, "month": 2, "day": 30}}).is_empty(), "invalid births are rejected")
	var unknown := world_time.duplicate(true)
	unknown["age"] = 12
	check(not Calendar.validate_world_time(unknown) and Calendar.world_time_age(world_time, "nobody") == Calendar.INVALID, "unknown save fields or actors are rejected")
