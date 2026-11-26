extends SceneTree
## EraRegistry: content windows, slots, divergences, hooks and validation.

const Calendar = preload("res://scripts/domain/world_calendar.gd")
const Era = preload("res://scripts/domain/era_registry.gd")
const Policy = preload("res://scripts/story/life_path_policy.gd")
const City = preload("res://scripts/world/city_exploration.gd")
var checks := 0
var failures := 0


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)


func _initialize() -> void:
	Era.reset_cache_for_tests()
	var reg := Era.registry()
	check(bool(reg.ok), "shipped registry validates: %s" % str(reg.errors))
	check((reg.order as Array).size() >= 40, "registry carries the seed entries")
	_queries()
	_slots_and_divergence()
	_hooks()
	_city_import()
	_transitions()
	_calendar_agreement()
	_invalid_data()
	print("ERA_REGISTRY entries=%d checks=%d failures=%d" % [(reg.order as Array).size(), checks, failures])
	if failures == 0:
		print("ERA_REGISTRY_PASS")
	quit(1 if failures else 0)


func _queries() -> void:
	var start := Calendar.campaign_start_jdn()
	check(not Era.available("building.amphitheatrum_flavium", start), "no Colosseum in 58 v. Chr.")
	check(not Era.available("building.amphitheatrum_flavium", Calendar.to_jdn(79, 12, 31)) and Era.available("building.amphitheatrum_flavium", Calendar.to_jdn(80, 1, 1)), "Colosseum from 80 n. Chr.")
	check(Era.available("roman_test_city.amphitheatre", Calendar.to_jdn(80, 1, 1)) and Era.resolve("roman_test_city.amphitheatre") == "building.amphitheatrum_flavium", "builder alias resolves")
	check(not Era.available("building.basilica_iulia", start) and Era.available("roman_test_city.basilica", Calendar.to_jdn(-46, 1, 1)), "Basilica Iulia from 46 v. Chr.")
	check(Era.available("building.theatrum_pompei", Calendar.to_jdn(-44, 3, 15)) and not Era.available("building.theatrum_pompei", start), "Theatre of Pompey stands at the Ides, not in 58 v. Chr.")
	check(Era.available("IT-020", start) and Era.available("equipment.gladius_family", start), "mail and gladius in 58 v. Chr.")
	check(not Era.available("equipment.lorica_segmentata", start) and not Era.available("equipment.lorica_segmentata", Calendar.to_jdn(-27, 1, 16)) and Era.available("equipment.lorica_segmentata", Calendar.to_jdn(9, 1, 1)), "segmented armour not before 9 n. Chr. (provisional)")
	check(Era.available("settlement.valdora", start) and Era.available("clothing.rural_tunic", start), "open windows are always available")
	check(not Era.available("unknown.content", start) and Era.entry("unknown.content").is_empty() and Era.window("unknown.content").is_empty(), "unknown content is never available")
	check(not Era.available("settlement.valdora", -1), "negative day numbers are rejected")
	var troops := Era.active("troop_entry", start)
	check("troops.rome.aquileia_winter_legions" in troops and "troops.rome.cisalpine_levy_58" in troops and "troops.valley_skirmish_test_bench" in troops and "troops.rome.cisalpine_levy_57" not in troops, "troop entries in 58 v. Chr.")
	var later := Era.active("troop_entry", Calendar.to_jdn(-57, 1, 1))
	check("troops.rome.cisalpine_levy_57" in later and "troops.valley_skirmish_test_bench" not in later, "troop entries in 57 v. Chr.")
	check(Era.filter_available(["IT-020", "equipment.lorica_segmentata", "unknown", "IT-011"], start) == ["IT-020", "IT-011"], "catalog filter keeps order and drops unavailable content")
	check(Era.entry("equipment.germanic_axe_shield").get("tags", []).has("rare_variant"), "axe and shield is tagged as rare reconstructed variant")


func _slots_and_divergence() -> void:
	var start := Calendar.campaign_start_jdn()
	var ides := Calendar.to_jdn(-44, 3, 15)
	check(Era.state_at("rome.power_bloc", start) == "political.rome.first_triumvirate", "first triumvirate in 58 v. Chr.")
	check(Era.state_at("rome.power_bloc", Calendar.to_jdn(-50, 6, 1)) == "", "no power bloc in 50 v. Chr.")
	check(Era.state_at("rome.power_bloc", Calendar.to_jdn(-43, 12, 1)) == "political.rome.second_triumvirate", "second triumvirate in 43 v. Chr.")
	check(Era.state_at("rome.dictatorship", ides) == "political.rome.caesar_dictatorship" and Era.state_at("rome.dictatorship", ides + 1) == "", "Caesar's dictatorship ends on the Ides")
	check(Era.state_at("rome.princeps", Calendar.to_jdn(-27, 1, 15)) == "" and Era.state_at("rome.princeps", Calendar.to_jdn(-27, 1, 16)) == "political.rome.principate_augustus", "principate from 16 January 27 v. Chr.")
	check(Era.state_at("rome.princeps", Calendar.to_jdn(14, 8, 19)) == "political.rome.principate_augustus" and Era.state_at("rome.princeps", Calendar.to_jdn(14, 8, 20)) == "political.rome.principate_tiberius", "succession in 14 n. Chr.")
	check(Era.state_at("aegyptus.rule", start) == "region.aegyptus.ptolemaic_kingdom" and Era.state_at("aegyptus.rule", Calendar.to_jdn(-30, 8, 2)) == "region.aegyptus.roman_province", "Egypt changes in 30 v. Chr.")
	check(Era.state_at("china.dynasty", start) == "region.han.western_han" and Era.state_at("china.dynasty", Calendar.to_jdn(24, 6, 1)) == "", "Western Han in 58 v. Chr.; interregnum in 24 n. Chr.")
	var caesar_lives := {"political.rome.caesar_dictatorship": {"divergence_id": "IV-28.caesar_lives", "to": -40}}
	check(Era.validate_overrides(caesar_lives).is_empty(), "marked divergence is valid")
	check(Era.state_at("rome.dictatorship", ides + 1, caesar_lives) == "political.rome.caesar_dictatorship", "divergence IV-28 extends the dictatorship")
	var unmarked := {"political.rome.caesar_dictatorship": {"to": -40}}
	check(not Era.validate_overrides(unmarked).is_empty() and not Era.available("political.rome.caesar_dictatorship", ides, unmarked), "an override without divergence_id is rejected and blocks the content")
	var suppressed := {"building.basilica_iulia": {"divergence_id": "test.fire", "suppressed": true}}
	check(not Era.available("building.basilica_iulia", Calendar.to_jdn(-40, 1, 1), suppressed), "a divergence can suppress content")
	var early := {"building.amphitheatrum_flavium": {"divergence_id": "sandbox.free_build", "from": -58}}
	check(Era.available("building.amphitheatrum_flavium", start, early), "a marked divergence can justify later architecture")
	check(not Era.validate_overrides({"unknown.content": {"divergence_id": "x"}}).is_empty() and not Era.validate_overrides({"building.basilica_iulia": {"divergence_id": "x", "from": 0}}).is_empty(), "overrides for unknown content or year 0 are rejected")
	check(not Era.available("building.basilica_iulia", Calendar.to_jdn(-40, 1, 1), {"building.basilica_iulia": {"divergence_id": "x", "from": -30, "to": -35}}), "override with from after to blocks the content")


func _hooks() -> void:
	var start := Calendar.campaign_start_jdn()
	check(Era.era_min_visible(-100, start) and Era.era_min_visible(-1000, start) and Era.era_min_visible(-58, start), "builder houses and ground are visible in 58 v. Chr.")
	check(not Era.era_min_visible(-46, start) and not Era.era_min_visible(52, start) and not Era.era_min_visible(80, start) and not Era.era_min_visible(216, start) and not Era.era_min_visible(271, start), "later builder objects are hidden in 58 v. Chr.")
	check(not Era.era_min_visible(0, start) and Era.era_min_visible(1, Calendar.to_jdn(1, 1, 1)) and not Era.era_min_visible(1, Calendar.to_jdn(-1, 12, 31)), "era_min_ce has no year zero")
	var parity := true
	for year: int in [-100, -58, -46, -1, 1, 80]:
		for earliest: int in [-100, -58, -46, -1, 1, 80]:
			for latest: int in [0, -58, -1, 1, 80]:
				var jdn := Calendar.first_day_of_year(year)
				if Era.asset_available("story", jdn, earliest, latest) != Policy.asset_available("story", year, earliest, latest):
					parity = false
	check(parity, "asset_available agrees with LifePathPolicy.asset_available")
	check(Era.asset_available("sandbox", start, 80) and not Era.asset_available("story", start, 0) and not Era.asset_available("other", start, -58), "sandbox, invalid year and unknown mode")


func _city_import() -> void:
	var visual := Node3D.new()
	var collision := Node3D.new()
	var arena := MeshInstance3D.new()
	arena.name = "Colosseum_Arena"
	visual.add_child(arena)
	var monument := MeshInstance3D.new()
	monument.name = "Monument"
	monument.set_meta("extras", {"era_min_ce": 80})
	visual.add_child(monument)
	var lost_metadata := StaticBody3D.new()
	lost_metadata.name = "Monument_collision"
	collision.add_child(lost_metadata)
	var house := MeshInstance3D.new()
	house.name = "Domus"
	house.set_meta("extras", {"era_min_ce": -100})
	visual.add_child(house)
	for jdn: int in [Calendar.to_jdn(79, 12, 31), Calendar.to_jdn(80, 1, 1)]:
		var excluded := {}
		var rendered := visual.duplicate()
		var physical := collision.duplicate()
		City.prune_future_city_nodes(rendered, jdn, excluded)
		City.prune_future_city_nodes(physical, jdn, excluded)
		var inaugurated := jdn == Calendar.to_jdn(80, 1, 1)
		check(rendered.has_node("Colosseum_Arena") == inaugurated, "legacy arena follows official inauguration")
		check(rendered.has_node("Monument") == inaugurated, "glTF extras gate imported scene nodes")
		check(physical.has_node("Monument_collision") == inaugurated, "collision copy follows its visual even when import loses extras")
		check(rendered.has_node("Domus"), "an earlier building remains visible")
		rendered.free()
		physical.free()
	visual.free()
	collision.free()


func _transitions() -> void:
	var start := Calendar.campaign_start_jdn()
	var changes := Era.changes_between(start, Calendar.to_jdn(-57, 12, 31))
	var levy := {"jdn": Calendar.to_jdn(-57, 1, 1), "id": "troops.rome.cisalpine_levy_57", "kind": "troop_entry", "change": "begins"}
	var bench := {"jdn": Calendar.to_jdn(-57, 1, 1), "id": "troops.valley_skirmish_test_bench", "kind": "troop_entry", "change": "ends"}
	check(levy in changes and bench in changes, "transitions of 57 v. Chr.")
	check(changes == Era.changes_between(start, Calendar.to_jdn(-57, 12, 31)), "transitions are deterministic")
	var sorted := true
	for index in range(1, changes.size()):
		if int(changes[index].jdn) < int(changes[index - 1].jdn):
			sorted = false
	check(sorted, "transitions are sorted by day")
	var boundary := Era.changes_between(Calendar.to_jdn(-2, 1, 1), Calendar.to_jdn(10, 1, 1))
	var ids := boundary.map(func(item: Dictionary) -> String: return "%s:%s" % [item.id, item.change])
	check("region.han.western_han:ends" in ids and "region.han.xin:begins" in ids and "equipment.lorica_segmentata:begins" in ids and "anchor.varus_battle:begins" in ids, "transitions across 1 v. -> 1 n. Chr.")
	check(Era.changes_between(start, start).is_empty() and Era.changes_between(start, start - 10).is_empty(), "empty or backward windows have no transitions")
	var new_year := Calendar.to_jdn(-57, 1, 1)
	check(levy not in Era.changes_between(new_year, new_year + 30) and levy in Era.changes_between(new_year - 1, new_year), "transitions use the half-open interval (from, to]")


func _calendar_agreement() -> void:
	check(int(Era.entry("calendar.month_iulius").from) == Calendar.IULIUS_FROM_YEAR and int(Era.entry("calendar.month_augustus").from) == Calendar.AUGUSTUS_FROM_YEAR, "month renames agree with WorldCalendar")
	check(int(Era.entry("calendar.julian_reform").from_jdn) == Calendar.date_to_jdn(Calendar.JULIAN_REFORM), "Julian reform agrees with WorldCalendar")
	check(int(Era.entry("anchor.ides_of_march").from_jdn) == 1705426, "Ides anchor JDN")
	var documented_without_source := 0
	for id: String in Era.registry().order:
		var item: Dictionary = Era.registry().entries[id]
		if item.status == "documented" and (str(item.source).is_empty() or item.source_check == "none"):
			documented_without_source += 1
	check(documented_without_source == 0, "every documented entry names a checked or flagged source")


func _invalid_data() -> void:
	var base := {"format": Era.FORMAT, "schema": 1, "entries": []}
	var good := {"id": "building.test", "kind": "building", "from": -58, "to": -50, "status": "authored_default", "source": "", "source_check": "none"}
	check(bool(Era.build(_with(base, [good])).ok), "minimal entry is valid")
	_rejects(base, [_with_field(good, "from", 0)], "year 0 as start")
	_rejects(base, [_with_field(good, "to", 0)], "year 0 as end")
	_rejects(base, [_with_field(good, "from", {"year": 0, "month": 1, "day": 1})], "year 0 in a date")
	_rejects(base, [_with_field(good, "from", -40)], "from after to")
	_rejects(base, [_with_field(good, "from", {"year": -58, "month": 2, "day": 29})], "impossible date")
	_rejects(base, [_with_field(good, "from", {"year": -58, "month": 2})], "incomplete date")
	_rejects(base, [good, good], "duplicate id")
	_rejects(base, [_with_field(good, "kind", "spell")], "unknown kind")
	_rejects(base, [_with_field(good, "status", "documented")], "documented without source")
	_rejects(base, [_with_field(good, "id", "bad id!")], "invalid id characters")
	var aliased := _with_field(good, "aliases", ["building.other"])
	_rejects(base, [aliased, _with_field(_with_field(good, "id", "building.other"), "from", -58)], "alias colliding with an id")
	var slot_a := _with_field(_with_field(good, "slot", "rome.test"), "id", "political.a")
	var slot_b := _with_field(_with_field(_with_field(good, "slot", "rome.test"), "id", "political.b"), "from", -52)
	_rejects(base, [slot_a, slot_b], "overlapping states in one slot")
	var slot_c := _with_field(_with_field(_with_field(slot_b, "from", -49), "to", -40), "id", "political.c")
	check(bool(Era.build(_with(base, [slot_a, slot_c])).ok), "adjacent states in one slot are valid")
	check(not bool(Era.build({"format": "other", "schema": 1, "entries": []}).ok) and not bool(Era.build({}).ok), "unknown format")
	var broken := Era.build(_with(base, [_with_field(good, "from", 0)]))
	check(broken.entries.is_empty() and not Era.available("building.test", Calendar.campaign_start_jdn(), {}, broken), "invalid registries answer nothing")
	var custom := Era.build(_with(base, [good]))
	check(Era.available("building.test", Calendar.campaign_start_jdn(), {}, custom) and not Era.available("building.test", Calendar.to_jdn(-49, 1, 1), {}, custom), "queries against a custom registry")


func _rejects(base: Dictionary, entries: Array, label: String) -> void:
	var result := Era.build(_with(base, entries))
	check(not bool(result.ok) and not (result.errors as Array).is_empty(), "rejects " + label)


func _with(base: Dictionary, entries: Array) -> Dictionary:
	var copy := base.duplicate(true)
	copy.entries = entries.duplicate(true)
	return copy


func _with_field(entry: Dictionary, key: String, value: Variant) -> Dictionary:
	var copy := entry.duplicate(true)
	copy[key] = value
	return copy
