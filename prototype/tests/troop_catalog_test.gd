extends SceneTree
## Troop catalog: loading, era filter, validation failures and item-gated upgrades.

const Catalog := preload("res://scripts/battle/troop_catalog.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	var catalog := Catalog.load_default()
	check(catalog.ok and catalog.errors.is_empty(), "Default catalog validates: " + str(catalog.errors))
	if not catalog.ok:
		_finish(catalog)
		return
	_test_contents(catalog)
	_test_era_filter(catalog)
	_test_rejections()
	_test_upgrades(catalog)
	_test_calendar()
	_finish(catalog)


func _finish(catalog: Dictionary) -> void:
	var counts := {"attested": 0, "plausible": 0, "design_assumption": 0}
	for t: Dictionary in catalog.troops.values():
		counts[t.attestation] += 1
	print("TROOP_CATALOG_RESULT checks=%d failures=%d troops=%d families=%d appointments=%d attestation=%s available_-58=%d" % [
		checks, failures, catalog.troops.size(), catalog.families.size(), catalog.appointments.size(), counts,
		Catalog.available(catalog, -58).size() if catalog.ok else 0])
	quit(1 if failures else 0)


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", message)


func _docs() -> Array:
	return [Catalog.read_json(Catalog.FAMILIES_PATH), Catalog.read_json(Catalog.TROOPS_PATH), Catalog.read_json(Catalog.PEOPLE_PATH)]


func _test_contents(catalog: Dictionary) -> void:
	check(catalog.troops.size() >= 11, "At least the eleven planned entries load (got %d)" % catalog.troops.size())
	var cultures := {}
	for t: Dictionary in catalog.troops.values():
		cultures[t.culture] = true
		check(t.attestation in Catalog.ATTESTATIONS and (t.attestation == "design_assumption" or not t.sources.is_empty()), "Attestation and sources: " + t.troop_id)
		check(not t.notes.is_empty() or t.attestation != "design_assumption", "Design assumptions carry a reason: " + t.troop_id)
		for item: Dictionary in t.loadout.values():
			check(catalog.families.has(item.family_id), "Loadout family exists: %s %s" % [t.troop_id, item.family_id])
	check(cultures.has("roman") and cultures.has("germanic"), "Roman and Germanic entries present")
	var axe: Dictionary = Catalog.troop(catalog, "germanic_axe_shield")
	check(axe.attestation == "design_assumption" and axe.rarity == "rare" and axe.reconstruction == "artistic" and axe.variant_of == "germanic_levy",
		"Axe and shield is a rare, artistically reconstructed variant, not the Germanic standard (D-024)")
	var standard := 0
	for t: Dictionary in catalog.troops.values():
		if t.culture == "germanic" and t.get("rarity", "common") == "common":
			standard += 1
	check(standard >= 6, "Several common Germanic warrior families exist besides the axe variant")
	var allied := Catalog.available(catalog, -52, "germanic", "roman")
	check(allied == ["germanic_eques_auxiliaris"] and Catalog.available(catalog, -58, "germanic", "roman").is_empty(),
		"Germanic culture can serve Rome from 52 BC (culture is not enmity)")
	var registry: Dictionary = Catalog.read_json("res://assets/meshy/loadouts.json")
	var visual_ids := {}
	for entry: Dictionary in registry.loadouts:
		visual_ids[entry.id] = true
	for t: Dictionary in catalog.troops.values():
		check(t.visual.meshy_loadout == "" or visual_ids.has(t.visual.meshy_loadout), "Visual loadout reference exists: " + t.troop_id)
	check(catalog.appointments.has("legatus") and Catalog.valid_at(catalog.appointments.legatus, -58) and Catalog.valid_at(catalog.appointments.dux, -58),
		"Command appointments exist for 58 BC")
	var miles := Catalog.resolve_loadout(catalog, "roman_miles")
	check(miles.missile == {"family_id": "pilum", "quality": 1, "count": 2} and miles.shield.family_id == "scutum", "Issued kit resolves family, minimum quality and count")
	check(Catalog.entry_xp(catalog, "roman_miles") == 120 and Catalog.entry_xp(catalog, "roman_tiro") == 0, "Entry experience follows the upgrade thresholds")


func _test_era_filter(catalog: Dictionary) -> void:
	var at_58 := Catalog.available(catalog, -58)
	check(at_58.has("roman_miles") and at_58.has("germanic_levy") and at_58.has("aux_sagittarius_creticus") and at_58.has("aux_eques_gallicus"), "58 BC offers the Caesarian army and Germanic groups")
	var segmentata := false
	var late_helmet := false
	for id in at_58:
		segmentata = segmentata or "lorica_segmentata" in Catalog.families_of(catalog, id)
		late_helmet = late_helmet or "helmet_imperial_gallic" in Catalog.families_of(catalog, id)
	check(not segmentata and not late_helmet, "A 58 BC filter yields no lorica segmentata and no imperial helmet")
	check(not at_58.has("roman_legionarius_principate") and not at_58.has("germanic_eques_auxiliaris"), "Later variants are absent in 58 BC")
	var at_9 := Catalog.available(catalog, 9)
	check(at_9.has("roman_legionarius_principate") and "lorica_segmentata" in Catalog.families_of(catalog, "roman_legionarius_principate"), "AD 9 offers the segmentata variant")
	check(not at_9.has("roman_miles"), "Republican kit leaves the filter after its span")
	check(Catalog.available(catalog, 0).is_empty(), "Year 0 matches nothing")
	check(Catalog.troop(catalog, "missing").is_empty(), "Unknown troop yields an empty copy")
	var copy := Catalog.troop(catalog, "roman_miles")
	copy.loadout.clear()
	check(not Catalog.troop(catalog, "roman_miles").loadout.is_empty(), "Queries return copies")


func _mutated(change: Callable) -> Dictionary:
	var docs := _docs()
	change.call(docs[0], docs[1], docs[2])
	return Catalog.build(docs[0], docs[1], docs[2])


func _troop(doc: Dictionary, id: String) -> Dictionary:
	for t: Dictionary in doc.troops:
		if t.troop_id == id:
			return t
	return {}


func _rejects(label: String, needle: String, change: Callable) -> void:
	var built := _mutated(change)
	var mentioned := false
	for e: String in built.errors:
		mentioned = mentioned or e.contains(needle)
	check(not built.ok and built.troops.is_empty() and mentioned, "Rejects %s (%s)" % [label, str(built.errors)])


func _test_rejections() -> void:
	_rejects("missing family_id", "family_id fehlt", func(_f, t, _p): _troop(t, "roman_miles").loadout.head.erase("family_id"))
	_rejects("year zero", "Zeitspanne", func(_f, t, _p): _troop(t, "roman_miles").valid_from = 0)
	_rejects("reversed dates", "Zeitspanne", func(_f, t, _p): _troop(t, "roman_miles").valid_to = -200)
	_rejects("fractional year", "Zeitspanne", func(_f, t, _p): _troop(t, "roman_miles").valid_from = -58.5)
	_rejects("missing date", "Zeitspanne", func(_f, t, _p): _troop(t, "germanic_levy").erase("valid_to"))
	_rejects("segmentata in the Caesar phase", "lorica_segmentata", func(_f, t, _p): _troop(t, "roman_miles").loadout.torso.family_id = "lorica_segmentata")
	_rejects("unknown family", "unbekannte family_id", func(_f, t, _p): _troop(t, "germanic_levy").loadout.shield.family_id = "tower_shield")
	_rejects("quality outside Q0-Q4", "Qualitätsspanne", func(_f, t, _p): _troop(t, "germanic_levy").loadout.shield.q_max = 5)
	_rejects("upgrade without items", "ohne Gegenstand", func(_f, t, _p): _troop(t, "roman_tiro").upgrades[0].items = [])
	_rejects("upgrade item without family", "ohne family_id", func(_f, t, _p): _troop(t, "roman_tiro").upgrades[0].items[0].erase("family_id"))
	_rejects("artistic reconstruction marked as attested", "künstlerische Rekonstruktion", func(_f, t, _p): _troop(t, "germanic_axe_shield").attestation = "attested")
	_rejects("archer kind without a bow", "Hauptwaffe", func(_f, t, _p): _troop(t, "aux_sagittarius_creticus").loadout.main_hand.family_id = "spear")
	_rejects("family with year zero", "Zeitspanne", func(f, _t, _p): f.families[0].valid_to = 0)
	_rejects("attested entry without sources", "Quellen", func(_f, t, _p): _troop(t, "roman_miles").sources = [])
	_rejects("downward upgrade", "höhere Stufe", func(_f, t, _p): _troop(t, "roman_miles").upgrades[0].to = "roman_tiro")
	check(Catalog.load_default().ok and Catalog.load_default().troops.has("roman_miles"), "Rejected variants never replace the loaded catalog")


func _test_upgrades(catalog: Dictionary) -> void:
	var recruit := {"uid": "t_00", "troop_id": "roman_tiro", "xp": 130, "service": []}
	var stock := [{"family_id": "lorica_hamata", "quality": 0, "count": 1}, {"family_id": "lorica_hamata", "quality": 3, "count": 1},
		{"family_id": "lorica_hamata", "quality": 1, "count": 1}, {"family_id": "pilum", "quality": 2, "count": 2}]
	var before := stock.duplicate(true)
	var too_green := recruit.duplicate(true)
	too_green.xp = 40
	for attempt in [[too_green, -58, ["depot"], "Erfahrung"], [recruit, -58, [], "Befugnis"], [recruit, 9, ["depot"], "Zielstufe"]]:
		var r := Catalog.apply_upgrade(catalog, attempt[0], "roman_miles", attempt[1], stock, attempt[2])
		check(not r.ok and r.message.contains(attempt[3]) and r.record.is_empty() and stock == before, "Upgrade rejected atomically: " + attempt[3])
	var no_mail := [{"family_id": "lorica_hamata", "quality": 0, "count": 3}, {"family_id": "pilum", "quality": 2, "count": 2}]
	var missing := Catalog.apply_upgrade(catalog, recruit, "roman_miles", -58, no_mail, ["depot"])
	check(not missing.ok and missing.message.contains("lorica_hamata"), "Without a sufficient real item there is no upgrade")
	var done := Catalog.apply_upgrade(catalog, recruit, "roman_miles", -58, stock, ["depot"])
	check(done.ok and done.record.troop_id == "roman_miles" and recruit.troop_id == "roman_tiro" and stock == before, "Upgrade returns new copies")
	check(done.consumed == [{"family_id": "lorica_hamata", "quality": 1, "count": 1}, {"family_id": "pilum", "quality": 2, "count": 1}], "Consumes the lowest sufficient quality exactly once")
	check(done.inventory == [{"family_id": "lorica_hamata", "quality": 0, "count": 1}, {"family_id": "lorica_hamata", "quality": 3, "count": 1}, {"family_id": "pilum", "quality": 2, "count": 1}], "Remaining stock is exact")
	check(done.record.service.back() == {"event": "promoted", "ref": "roman_miles", "year": -58, "step": -1}, "Service record notes the promotion")
	var youth := {"uid": "g_00", "troop_id": "germanic_youth_javelin", "xp": 100, "service": []}
	var gift := [{"family_id": "spear", "quality": 1, "count": 1}, {"family_id": "shield_round", "quality": 2, "count": 1}]
	check(Catalog.apply_upgrade(catalog, youth, "germanic_levy", -58, gift, ["kin"]).ok, "Germanic youth is armed by kin with spear and shield")
	check(not Catalog.apply_upgrade(catalog, youth, "germanic_levy", -58, gift, ["depot"]).ok, "A Roman depot cannot arm a Germanic youth")
	check(not Catalog.apply_upgrade(catalog, youth, "germanic_warrior", -58, gift, ["kin"]).ok, "No skipping tiers outside the defined paths")


func _test_calendar() -> void:
	check(Catalog.years_between(-58, 9) == 66 and Catalog.years_between(-1, 1) == 1 and Catalog.years_between(-58, -52) == 6 and Catalog.years_between(9, -58) == -66, "Elapsed years skip the missing year zero")
	check(Catalog.year_label(-58) == "58 v. Chr." and Catalog.year_label(9) == "9 n. Chr.", "Year labels")
	check(not Catalog.valid_year(0) and Catalog.valid_year(-58) and not Catalog.valid_year(-58.5), "Year validation")
