extends RefCounted
## Historical world calendar for IMPERATHEN. Pure static arithmetic, no state.
##
## Year conventions (see docs/37_world_calendar/WORLD_CALENDAR.md):
## - historical year: signed, as used by saves and content data
##   (-58 = 58 v. Chr., -1 = 1 v. Chr., 1 = 1 n. Chr.). There is NO year 0:
##   1 v. Chr. is followed directly by 1 n. Chr. Zero is always invalid.
## - astronomical year: internal arithmetic only (1 v. Chr. = 0, 58 v. Chr. = -57).
## - day number: Julian Day Number (JDN, integer, noon-based) on the proleptic
##   Julian calendar. It is the canonical, save-friendly instant of a day.
##
## Dates before the Julian reform (1 January 45 v. Chr.) are nominal Roman
## dates placed on the proleptic Julian grid. The drift of the pre-reform
## Republican calendar and the Augustan leap-year correction are not modelled.

const SCHEMA := 1
const SYSTEM := "julian_proleptic_jdn"
const DAY_SECONDS := 86400
const INVALID := -1
## Season turns may be negative (before the origin year), so they use their own sentinel.
const INVALID_TURN := -(1 << 62)
## JDN 0 is 1 January 4713 v. Chr.; the supported range keeps every JDN >= 0.
const MIN_YEAR := -4713
const MAX_YEAR := 9999
## Provisional campaign start: Kalendae Maiae 58 v. Chr. The mission sheet only
## gives "58 v. Chr."; Caesar leads the three legions out of their winter
## quarters around Aquileia after the Ides of April (BG 1.7.6, 1.10.3). Owner
## decision pending; changing it only moves the default for new games.
const CAMPAIGN_START := {"year": -58, "month": 5, "day": 1}
## Derived from all dated mission sheets (age = year - birth year): 70 v. Chr.
## Day and month are an open owner decision (see campaign_timeline.gd).
const PROTAGONIST_BIRTH := {"year": -70}
const SEASON_IDS := ["spring", "summer", "autumn", "winter"]
const SEASON_NAMES_DE := ["Frühling", "Sommer", "Herbst", "Winter"]
const SEASON_START_MONTH := [3, 6, 9, 12]
const MONTH_NAMES_DE := ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]
const MONTH_NAMES_EN := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const MONTH_NAMES_LA := ["Ianuarius", "Februarius", "Martius", "Aprilis", "Maius", "Iunius", "Quintilis", "Sextilis", "September", "October", "November", "December"]
const MONTH_ABBR_LA := ["Ian.", "Feb.", "Mart.", "Apr.", "Mai.", "Iun.", "Quint.", "Sext.", "Sept.", "Oct.", "Nov.", "Dec."]
## Quintilis was renamed Iulius in 44 v. Chr., Sextilis Augustus in 8 v. Chr.
## (Macrobius, Saturnalia 1.12.34-35; Cicero complains about "Nonis Iuliis" in July 44).
const IULIUS_FROM_YEAR := -44
const AUGUSTUS_FROM_YEAR := -8
## The Julian calendar is in force from 1 January 45 v. Chr. (Macrobius, Saturnalia 1.14).
const JULIAN_REFORM := {"year": -45, "month": 1, "day": 1}
## Varronian era: Rome founded 753 v. Chr., counted with the consular year from
## 1 January, so 1 n. Chr. = 754 a.u.c. Contemporaries dated official business
## by consuls; a.u.c. is an optional learned display. The Fasti Capitolini use
## 752 v. Chr. and would show one year less.
const AUC_OFFSET := 753
const AUC_SOURCE_NOTE := "a.u.c. nach varronischer Zählung (Gründung 753 v. Chr.; 1 n. Chr. = 754 a.u.c.). Zeitgenössisch amtlich nach Konsuln datiert; die Fasti Capitolini zählen ab 752 v. Chr."


# --- Year conventions -------------------------------------------------------

static func is_valid_year(year: int) -> bool:
	return year != 0 and year >= MIN_YEAR and year <= MAX_YEAR


static func to_astronomical(year: int) -> int:
	## Historical signed year -> astronomical year. Callers must pass a valid year.
	return year + 1 if year < 0 else year


static func from_astronomical(astronomical: int) -> int:
	return astronomical - 1 if astronomical <= 0 else astronomical


static func add_years(year: int, years: int) -> int:
	## Year arithmetic without year 0: add_years(-1, 1) == 1. Returns 0 (never a
	## valid year) when the input or the result is out of range. Note that -1 is
	## a valid historical year (1 v. Chr.), so year results never use INVALID.
	if not is_valid_year(year):
		return 0
	var result := from_astronomical(to_astronomical(year) + years)
	return result if is_valid_year(result) else 0


static func years_between(from_year: int, to_year: int) -> int:
	## Signed number of calendar years between two historical years (-1 -> 1 is 1).
	return to_astronomical(to_year) - to_astronomical(from_year)


static func is_leap_year(year: int) -> bool:
	## Proleptic Julian rule: every astronomical year divisible by four
	## (1 v. Chr., 5 v. Chr., 45 v. Chr., 4 n. Chr. ...).
	return is_valid_year(year) and posmod(to_astronomical(year), 4) == 0


static func days_in_month(year: int, month: int) -> int:
	if not is_valid_year(year) or month < 1 or month > 12:
		return 0
	if month == 2:
		return 29 if is_leap_year(year) else 28
	return 30 if month in [4, 6, 9, 11] else 31


static func days_in_year(year: int) -> int:
	return (366 if is_leap_year(year) else 365) if is_valid_year(year) else 0


static func is_valid_date(year: int, month: int, day: int) -> bool:
	return is_valid_year(year) and month >= 1 and month <= 12 and day >= 1 and day <= days_in_month(year, month)


# --- Julian Day Number ------------------------------------------------------

static func to_jdn(year: int, month: int, day: int) -> int:
	## Historical date -> JDN. INVALID for year 0 or impossible dates.
	if not is_valid_date(year, month, day):
		return INVALID
	var a := _fdiv(14 - month, 12)
	var y := to_astronomical(year) + 4800 - a
	var m := month + 12 * a - 3
	return day + _fdiv(153 * m + 2, 5) + 365 * y + _fdiv(y, 4) - 32083


static func date_to_jdn(date: Dictionary) -> int:
	if not is_integral(date.get("year")) or not is_integral(date.get("month", 1)) or not is_integral(date.get("day", 1)):
		return INVALID
	return to_jdn(int(date.year), int(date.get("month", 1)), int(date.get("day", 1)))


static func from_jdn(jdn: int) -> Dictionary:
	## JDN -> {"year": historical, "month", "day"}; empty for out-of-range input.
	if jdn < 0 or jdn > max_jdn():
		return {}
	var c := jdn + 32082
	var d := _fdiv(4 * c + 3, 1461)
	var e := c - _fdiv(1461 * d, 4)
	var m := _fdiv(5 * e + 2, 153)
	var day := e - _fdiv(153 * m + 2, 5) + 1
	var month := m + 3 - 12 * _fdiv(m, 10)
	var astronomical := d - 4800 + _fdiv(m, 10)
	return {"year": from_astronomical(astronomical), "month": month, "day": day}


static func max_jdn() -> int:
	return _raw_jdn(MAX_YEAR, 12, 31)


static func year_of(jdn: int) -> int:
	return int(from_jdn(jdn).get("year", 0))


static func first_day_of_year(year: int) -> int:
	return to_jdn(year, 1, 1)


static func last_day_of_year(year: int) -> int:
	return to_jdn(year, 12, 31)


# --- Durations ----------------------------------------------------------------

static func add_days(jdn: int, days: int) -> int:
	var result := jdn + days
	return result if jdn >= 0 and result >= 0 and result <= max_jdn() else INVALID


static func days_between(from_jdn_value: int, to_jdn_value: int) -> int:
	return to_jdn_value - from_jdn_value


static func add_calendar_years(jdn: int, years: int) -> int:
	## Same month and day n years later; 29 February becomes 28 February in common years.
	var date := from_jdn(jdn)
	if date.is_empty():
		return INVALID
	var year := add_years(int(date.year), years)
	if not is_valid_year(year):
		return INVALID
	var day := mini(int(date.day), days_in_month(year, int(date.month)))
	return to_jdn(year, int(date.month), day)


static func add_months(jdn: int, months: int) -> int:
	var date := from_jdn(jdn)
	if date.is_empty():
		return INVALID
	var index := to_astronomical(int(date.year)) * 12 + int(date.month) - 1 + months
	var year := from_astronomical(_fdiv(index, 12))
	var month := posmod(index, 12) + 1
	if not is_valid_year(year):
		return INVALID
	return to_jdn(year, month, mini(int(date.day), days_in_month(year, month)))


# --- Ages ---------------------------------------------------------------------

static func age_on(birth: Dictionary, on_jdn: int) -> int:
	## Completed years of life on a day. A birth record may carry only a year
	## (precision "year": the age then counts from 1 January of that year, the
	## convention of the mission sheets). A 29 February birthday counts from
	## 1 March in common years. INVALID before birth or for invalid input.
	if not is_integral(birth.get("year")) or not is_valid_year(int(birth.year)):
		return INVALID
	var on := from_jdn(on_jdn)
	if on.is_empty():
		return INVALID
	var month := int(birth.get("month", 0)) if is_integral(birth.get("month", 0)) else -1
	var day := int(birth.get("day", 0)) if is_integral(birth.get("day", 0)) else -1
	if month == 0 and day == 0:
		var years := years_between(int(birth.year), int(on.year))
		return years if years >= 0 else INVALID
	var birth_jdn := to_jdn(int(birth.year), month, day)
	if birth_jdn == INVALID or on_jdn < birth_jdn:
		return INVALID
	var age := years_between(int(birth.year), int(on.year))
	if int(on.month) < month or (int(on.month) == month and int(on.day) < day):
		age -= 1
	return age


static func age_in_year(birth_year: int, year: int) -> int:
	## Age reached at the birthday within the given historical year.
	if not is_valid_year(birth_year) or not is_valid_year(year):
		return INVALID
	var age := years_between(birth_year, year)
	return age if age >= 0 else INVALID


static func birth_year_for_age(age: int, year: int) -> int:
	## Historical birth year for an age reached in a year; 0 when invalid.
	if age < 0 or not is_valid_year(year):
		return 0
	return add_years(year, -age)


# --- Seasons ------------------------------------------------------------------

static func season_index(jdn: int, latitude: float = 45.0) -> int:
	## Meteorological seasons for the Mediterranean (spring = March-May).
	## Southern latitudes are shifted by two seasons, like season_campaign.gd.
	var date := from_jdn(jdn)
	if date.is_empty():
		return INVALID
	var index := _fdiv(posmod(int(date.month) - 3, 12), 3)
	return (index + 2) % 4 if latitude < 0.0 else index


static func season_year(jdn: int) -> int:
	## Historical year that owns the season; January and February belong to the
	## winter that started in December of the previous year.
	var date := from_jdn(jdn)
	if date.is_empty():
		return 0
	return add_years(int(date.year), -1) if int(date.month) <= 2 else int(date.year)


static func season_start(year: int, index: int) -> int:
	if index < 0 or index > 3:
		return INVALID
	return to_jdn(year, SEASON_START_MONTH[index], 1)


static func season_turn(jdn: int, origin_year: int = CAMPAIGN_START.year) -> int:
	## Turn 0 is spring of origin_year; four turns per year, monotonic over 1 v./1 n. Chr.
	var owner := season_year(jdn)
	if not is_valid_year(owner) or not is_valid_year(origin_year):
		return INVALID_TURN
	return 4 * years_between(origin_year, owner) + season_index(jdn)


static func season_turn_start(turn: int, origin_year: int = CAMPAIGN_START.year) -> int:
	if turn == INVALID_TURN:
		return INVALID
	var year := add_years(origin_year, _fdiv(turn, 4))
	if not is_valid_year(year):
		return INVALID
	return season_start(year, posmod(turn, 4))


# --- Display --------------------------------------------------------------------

static func format_year(year: int, language: String = "de") -> String:
	if not is_valid_year(year):
		return "?"
	if language == "en":
		return "%d BC" % -year if year < 0 else "AD %d" % year
	return "%d v. Chr." % -year if year < 0 else "%d n. Chr." % year


static func format_date(jdn: int, language: String = "de") -> String:
	var date := from_jdn(jdn)
	if date.is_empty():
		return "?"
	var names := MONTH_NAMES_EN if language == "en" else MONTH_NAMES_DE
	if language == "en":
		return "%d %s %s" % [date.day, names[int(date.month) - 1], format_year(int(date.year), "en")]
	return "%d. %s %s" % [date.day, names[int(date.month) - 1], format_year(int(date.year), language)]


static func auc_year(year: int) -> int:
	return to_astronomical(year) + AUC_OFFSET if is_valid_year(year) else INVALID


static func roman_numeral(value: int) -> String:
	if value <= 0 or value >= 4000:
		return ""
	var numerals := [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"], [50, "L"], [40, "XL"], [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]
	var rest := value
	var text := ""
	for pair: Array in numerals:
		while rest >= int(pair[0]):
			text += str(pair[1])
			rest -= int(pair[0])
	return text


static func latin_month_name(year: int, month: int) -> String:
	if month == 7 and year >= IULIUS_FROM_YEAR:
		return "Iulius"
	if month == 8 and year >= AUGUSTUS_FROM_YEAR:
		return "Augustus"
	return MONTH_NAMES_LA[month - 1] if month >= 1 and month <= 12 else ""


static func latin_month_abbreviation(year: int, month: int) -> String:
	if month == 7 and year >= IULIUS_FROM_YEAR:
		return "Iul."
	if month == 8 and year >= AUGUSTUS_FROM_YEAR:
		return "Aug."
	return MONTH_ABBR_LA[month - 1] if month >= 1 and month <= 12 else ""


static func roman_day(jdn: int) -> String:
	## Inclusive Roman count to Kalendae, Nonae or Idus ("a.d. V Kal. Apr.").
	## In leap years 25 February is shown as "a.d. bis VI Kal. Mart." (display
	## convention; which of the doubled days was "bis" is disputed).
	var date := from_jdn(jdn)
	if date.is_empty():
		return ""
	var year := int(date.year)
	var month := int(date.month)
	var day := int(date.day)
	var length := days_in_month(year, month)
	if month == 2 and length == 29:
		if day == 25:
			return "a.d. bis VI Kal. Mart."
		if day > 25:
			day -= 1
		length = 28
	var nones := 7 if month in [3, 5, 7, 10] else 5
	var ides := nones + 8
	var here := latin_month_abbreviation(year, month)
	if day == 1:
		return "Kal. " + here
	if day < nones:
		return _count_label(nones - day + 1, "Non.", here)
	if day == nones:
		return "Non. " + here
	if day < ides:
		return _count_label(ides - day + 1, "Id.", here)
	if day == ides:
		return "Id. " + here
	var next_year := year if month < 12 else add_years(year, 1)
	var next := latin_month_abbreviation(next_year, month % 12 + 1)
	return _count_label(length - day + 2, "Kal.", next)


static func format_roman(jdn: int, with_auc: bool = true) -> String:
	var label := roman_day(jdn)
	if label.is_empty():
		return ""
	return label + (" %s a.u.c." % roman_numeral(auc_year(year_of(jdn))) if with_auc else "")


# --- Save representation ----------------------------------------------------------

static func new_clock(jdn: int, second_of_day: int = 0) -> Dictionary:
	if jdn < 0 or jdn > max_jdn() or second_of_day < 0 or second_of_day >= DAY_SECONDS:
		return {}
	return {"schema": SCHEMA, "system": SYSTEM, "jdn": jdn, "second": second_of_day}


static func campaign_start_jdn() -> int:
	return date_to_jdn(CAMPAIGN_START)


static func validate_clock(clock: Variant) -> bool:
	if not clock is Dictionary or (clock as Dictionary).size() != 4:
		return false
	var value: Dictionary = clock
	if not is_integral(value.get("schema")) or int(value.schema) != SCHEMA or value.get("system") != SYSTEM:
		return false
	if not is_integral(value.get("jdn")) or not is_integral(value.get("second")):
		return false
	return int(value.jdn) >= 0 and int(value.jdn) <= max_jdn() and int(value.second) >= 0 and int(value.second) < DAY_SECONDS


static func normalize_clock(clock: Variant) -> Dictionary:
	## JSON turns integers into floats; restore exact integers after validation.
	if not validate_clock(clock):
		return {}
	return new_clock(int(clock.jdn), int(clock.second))


static func advance_clock(clock: Dictionary, seconds: int) -> Dictionary:
	if not validate_clock(clock) or seconds < 0:
		return {}
	var total := int(clock.second) + seconds
	var jdn := add_days(int(clock.jdn), _fdiv(total, DAY_SECONDS))
	return new_clock(jdn, posmod(total, DAY_SECONDS)) if jdn != INVALID else {}


static func clock_date(clock: Dictionary) -> Dictionary:
	if not validate_clock(clock):
		return {}
	var date := from_jdn(int(clock.jdn))
	date["season"] = SEASON_IDS[season_index(int(clock.jdn))]
	date["season_year"] = season_year(int(clock.jdn))
	return date


## Proposed save block for world_model.gd schema 6 (top-level key "calendar"):
## {"schema", "clock", "origin_year", "births": {actor_id: birth}, "divergences": {}}.
## Ages and seasons are derived from clock and births; cached copies elsewhere
## must equal the derived values. "divergences" holds EraRegistry overrides and
## is checked by EraRegistry.validate_overrides() in the caller.
static func new_world_time(jdn: int, second_of_day: int, origin_year: int, births: Dictionary = {}) -> Dictionary:
	var clock := new_clock(jdn, second_of_day)
	var value := {"schema": SCHEMA, "clock": clock, "origin_year": origin_year, "births": births.duplicate(true), "divergences": {}}
	return value if validate_world_time(value) else {}


static func validate_world_time(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var keys: Array = (value as Dictionary).keys()
	keys.sort()
	if keys != ["births", "clock", "divergences", "origin_year", "schema"]:
		return false
	if not is_integral(value.schema) or int(value.schema) != SCHEMA or not validate_clock(value.clock):
		return false
	if not is_integral(value.origin_year) or not is_valid_year(int(value.origin_year)) or int(value.clock.jdn) < first_day_of_year(int(value.origin_year)):
		return false
	if not value.births is Dictionary or not value.divergences is Dictionary:
		return false
	for actor_id: Variant in value.births:
		if typeof(actor_id) != TYPE_STRING or str(actor_id).is_empty() or not valid_birth(value.births[actor_id]):
			return false
	return true


static func normalize_world_time(value: Variant) -> Dictionary:
	if not validate_world_time(value):
		return {}
	var births := {}
	for actor_id: String in value.births:
		var birth: Dictionary = value.births[actor_id]
		births[actor_id] = {"year": int(birth.year)} if not birth.has("month") else {"year": int(birth.year), "month": int(birth.month), "day": int(birth.day)}
	var result := {"schema": SCHEMA, "clock": normalize_clock(value.clock), "origin_year": int(value.origin_year), "births": births, "divergences": (value.divergences as Dictionary).duplicate(true)}
	return result


static func valid_birth(birth: Variant) -> bool:
	## {"year"} (year precision) or {"year", "month", "day"}; never year 0.
	if not birth is Dictionary:
		return false
	var keys: Array = (birth as Dictionary).keys()
	keys.sort()
	if keys == ["year"]:
		return is_integral(birth.year) and is_valid_year(int(birth.year))
	if keys != ["day", "month", "year"]:
		return false
	return is_integral(birth.year) and is_integral(birth.month) and is_integral(birth.day) and is_valid_date(int(birth.year), int(birth.month), int(birth.day))


static func world_time_age(world_time: Dictionary, actor_id: String) -> int:
	if not validate_world_time(world_time) or not world_time.births.has(actor_id):
		return INVALID
	return age_on(world_time.births[actor_id], int(world_time.clock.jdn))


# --- Internals ----------------------------------------------------------------------

static func _count_label(count: int, anchor: String, month: String) -> String:
	if count == 2:
		return "prid. %s %s" % [anchor, month]
	return "a.d. %s %s %s" % [roman_numeral(count), anchor, month]


static func _raw_jdn(year: int, month: int, day: int) -> int:
	var a := _fdiv(14 - month, 12)
	var y := to_astronomical(year) + 4800 - a
	var m := month + 12 * a - 3
	return day + _fdiv(153 * m + 2, 5) + 365 * y + _fdiv(y, 4) - 32083


static func is_integral(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_finite(value) and value == floor(value) and absf(value) < 9007199254740992.0


@warning_ignore("integer_division")
static func _fdiv(numerator: int, denominator: int) -> int:
	## Floor division for signed integers (GDScript "/" truncates toward zero).
	var quotient: int = numerator / denominator
	if numerator % denominator != 0 and ((numerator < 0) != (denominator < 0)):
		quotient -= 1
	return quotient
