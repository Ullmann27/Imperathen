extends SceneTree
## Mission timeline: 113 sheets, owner band ranges, one birth year, page
## references, hand-verified samples and every finding listed (not fixed).

const Calendar = preload("res://scripts/domain/world_calendar.gd")
const Era = preload("res://scripts/domain/era_registry.gd")
const Timeline = preload("res://scripts/domain/campaign_timeline.gd")
const Bible = preload("res://scripts/story/campaign_bible.gd")
var checks := 0
var failures := 0


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func _initialize() -> void:
	Timeline.reset_cache_for_tests()
	Bible.reset_cache_for_tests()
	var data := Timeline.data()
	var report := Timeline.validate(data)
	check(bool(report.ok), "timeline validates: %s" % str(report.errors))
	check(report.counts == {1: 32, 2: 25, 3: 25, 4: 31}, "32 / 25 / 25 / 31 missions per band")
	check(report.birth_years == [-70] and int(report.birth_year) == -70 and int(report.birth_year) == int(Calendar.PROTAGONIST_BIRTH.year), "all ages fit exactly one birth year: 70 v. Chr.")
	var conflicts := (report.findings as Array).filter(func(item: Dictionary) -> bool: return item.severity == "conflict")
	check(conflicts.is_empty(), "no mission contradicts the owner band ranges or the birth year")
	var acknowledged: Array = data.get("acknowledged_findings", []).duplicate()
	acknowledged.sort()
	check(Timeline.finding_keys(report) == acknowledged, "computed findings equal the reviewed list (new inconsistencies must be reviewed): %s" % str(Timeline.finding_keys(report)))
	for item: Dictionary in report.findings:
		print("FINDING %s %s pages=%s %s" % [item.severity, item.key, str(item.pdf_pages), item.detail])
	_bible_agreement()
	_samples()
	_ages_and_windows()
	_broken_inputs(data)
	check(JSON.stringify(Timeline.validate(data)) == JSON.stringify(report), "validation is deterministic")
	print("MISSION_TIMELINE missions=%d findings=%d checks=%d failures=%d" % [Timeline.missions().size(), (report.findings as Array).size(), checks, failures])
	if failures == 0:
		print("MISSION_TIMELINE_PASS")
	quit(1 if failures else 0)


func _bible_agreement() -> void:
	var same := true
	var count := 0
	for band in range(1, 5):
		for authored: Dictionary in Bible.band(band).get("main_missions", []):
			count += 1
			var item := Timeline.mission(str(authored.id))
			if item.is_empty() or item.title != authored.title or int(item.band) != band:
				same = false
				push_error("campaign_arc.json and the handbook differ for %s" % str(authored.id))
	check(same and count == 113 and Bible.main_mission_count() == 113, "the 113 IDs and titles match campaign_arc.json")


func _samples() -> void:
	## Hand-verified against the PDF (pdftotext -layout of the listed pages).
	var i01 := Timeline.mission("I-01")
	check(i01.date_text == "58 v. Chr." and int(i01.age_min) == 12 and i01.place == "Familienhaus Valdora" and i01.canon_kind == "FICTIONAL THREAD", "I-01 header (PDF S. 126)")
	check(int(i01.pdf_page) == 126 and int(i01.sheet_page) == 68 and i01.register_ref == "S. 068" and int(i01.register_pdf_page) == 49, "I-01 page references")
	var i18 := Timeline.mission("I-18")
	check(i18.date_kind == "split_year" and int(i18.year_from) == -57 and int(i18.year_to) == -56 and int(i18.age_min) == 13 and int(i18.pdf_page) == 143, "I-18 57/56 v. Chr., ca. 13 (PDF S. 143)")
	var i31 := Timeline.mission("I-31")
	check(i31.title == "Der Quartiermeister mit dem roten Wachs" and int(i31.pdf_page) == 156, "I-31 wrapped title (PDF S. 156)")
	var ii13 := Timeline.mission("II-13")
	check(int(ii13.year_from) == -49 and int(ii13.year_to) == -48 and int(ii13.age_min) == 22 and ii13.place == "Adria" and int(ii13.pdf_page) == 170, "II-13 49/48 v. Chr., ca. 22 (PDF S. 170)")
	var iii22 := Timeline.mission("III-22")
	check(iii22.date is Dictionary and Calendar.date_to_jdn(iii22.date) == int(Era.entry("anchor.ides_of_march").from_jdn) and int(iii22.age_min) == 26, "III-22 is the Ides anchor (PDF S. 204)")
	var iv18 := Timeline.mission("IV-18")
	check(iv18.date_kind == "year_range" and int(iv18.year_from) == -34 and int(iv18.year_to) == -32 and int(iv18.age_min) == 34 and int(iv18.age_max) == 36, "IV-18 34–32 v. Chr., ca. 34–36 (PDF S. 225)")
	var iv24 := Timeline.mission("IV-24")
	check(iv24.date_kind == "open_after" and int(iv24.year_from) == -27 and iv24.year_to == null and int(iv24.age_min) == 43, "IV-24 27 v. Chr. und danach (PDF S. 231)")
	var iv28 := Timeline.mission("IV-28")
	check(iv28.date_kind == "from_year" and iv28.canon_kind == "COUNTERFACTUAL" and bool(iv28.age_open) and int(iv28.age_min) == 26, "IV-28 ab 44 v. Chr., ca. 26+ (PDF S. 235)")
	var iv30 := Timeline.mission("IV-30")
	check(iv30.date_kind == "epilogue" and iv30.year_from == null and bool(iv30.age_variable) and int(iv30.pdf_page) == 237, "IV-30 epilogue (PDF S. 237)")
	var offset_ok := true
	for item: Dictionary in Timeline.missions():
		if int(item.pdf_page) != int(item.sheet_page) + 58 or item.register_ref != "S. %03d" % int(item.sheet_page):
			offset_ok = false
	check(offset_ok, "every PDF page equals sheet page + 58 and matches section G")
	check(Timeline.protected_ids() == ["I-10"], "I-10 is the protected story event (D-020)")


func _ages_and_windows() -> void:
	var exact := true
	for item: Dictionary in Timeline.missions():
		if item.date_kind in ["exact_year", "exact_date"] and Calendar.age_in_year(-70, int(item.year_from)) != int(item.age_min):
			exact = false
	check(exact, "every single-year sheet age equals year - 70 v. Chr.")
	var window := Timeline.mission_window("I-10")
	check(int(window.from_jdn) == Calendar.to_jdn(-58, 1, 1) and int(window.to_jdn) == Calendar.to_jdn(-58, 12, 31), "I-10 window is the year 58 v. Chr.")
	check(int(Timeline.mission_window("III-23").from_jdn) == Calendar.to_jdn(-44, 3, 15), "III-23 window is the Ides")
	check(int(Timeline.mission_window("IV-25").to_jdn) == Calendar.INVALID and Timeline.mission_window("IV-29").is_empty(), "open and undated windows")
	var band_one := Timeline.band_missions(1)
	check(band_one.size() == 32 and band_one[0].id == "I-00" and band_one[31].id == "I-31", "band query")


func _broken_inputs(data: Dictionary) -> void:
	var zero := _modified(data, "I-05", "year_from", 0)
	check(not bool(Timeline.validate(zero).ok), "year 0 is a structural error")
	var reversed := _modified(_modified(data, "IV-18", "year_from", -32), "IV-18", "year_to", -34)
	check(not bool(Timeline.validate(reversed).ok), "from > to is a structural error")
	var page := _modified(data, "II-02", "pdf_page", 200)
	check(not bool(Timeline.validate(page).ok), "a wrong PDF page is a structural error")
	var outside := _modified(_modified(data, "II-05", "year_from", -52), "II-05", "year_to", -52)
	var outside_report := Timeline.validate(outside)
	check(bool(outside_report.ok) and "outside_band_range:II-05" in Timeline.finding_keys(outside_report), "a year outside the band range is listed, not fixed")
	var age := _modified(_modified(data, "I-16", "age_min", 14), "I-16", "age_max", 14)
	var age_report := Timeline.validate(age)
	check("age_birth_year:I-16" in Timeline.finding_keys(age_report) and int(age_report.birth_year) == 0, "an age that breaks the single birth year is listed")
	var order := _modified(_modified(data, "I-21", "year_from", -58), "I-21", "year_to", -58)
	order = _modified(_modified(order, "I-21", "age_min", 12), "I-21", "age_max", 12)
	var order_keys := Timeline.finding_keys(Timeline.validate(order))
	check("chronology_order:I-20+I-21" in order_keys and "age_birth_year:I-21" not in order_keys, "a mission placed before its predecessor is listed")
	var bands := data.duplicate(true)
	bands.band_ranges[1].from = 0
	check(not bool(Timeline.validate(bands).ok), "a band range with year 0 is rejected")
	var missing := data.duplicate(true)
	(missing.missions as Array).remove_at(5)
	check(not bool(Timeline.validate(missing).ok), "a missing mission is rejected")


func _modified(data: Dictionary, mission_id: String, key: String, value: Variant) -> Dictionary:
	var copy := data.duplicate(true)
	for item: Dictionary in copy.missions:
		if item.id == mission_id:
			item[key] = value
	return copy
