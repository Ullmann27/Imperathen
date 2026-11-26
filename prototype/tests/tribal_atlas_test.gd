extends SceneTree
## The strategy atlas shows the tribal world of the save itself: settlements,
## strength classes and relation states come from TribalWorld.atlas_view.

const AtlasScreen = preload("res://scripts/strategy/atlas_screen.gd")
const Seasons = preload("res://scripts/strategy/season_campaign.gd")
const Tribes = preload("res://scripts/domain/tribal_world.gd")
const Relations = preload("res://scripts/domain/actor_relations.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> bool:
	checks += 1
	if not condition:
		failures.append(description)
	return condition


func _run() -> void:
	var state := Tribes.new_state(19)
	Tribes.advance_ticks(state, 60)
	var atlas = AtlasScreen.new()
	atlas.data = Seasons.new_game("italia")
	atlas.tribes = state
	atlas.selected = "germania"
	root.add_child(atlas)
	await process_frame
	atlas._select("germania", true)
	var text: String = atlas.tribal.text
	var view := Tribes.atlas_view(state, "valdora")
	var shown := 0
	for item: Dictionary in view:
		if item.atlas_region != "germania":
			continue
		shown += 1
		_check(text.contains(str(item.name)), "Atlas names %s" % item.name)
		if item.status == "active":
			_check(text.contains("%s (%.0f)" % [item.strength_class, float(item.strength)]), "Atlas shows the simulated strength class of %s" % item.name)
			for relation: Dictionary in item.relations:
				if relation.stance != "neutral":
					_check(text.contains("%s %s" % [relation.name, AtlasScreen.STANCES[relation.stance]]), "Atlas shows %s -> %s as %s" % [item.name, relation.name, relation.stance])
	_check(shown >= 5, "All Rhine groups appear under the Germania region (%d)" % shown)
	_check(text.contains(Tribes.calendar(state).label), "Atlas uses the tribal calendar of the save")
	var pins := Tribes.settlement_points(state, "valdora")
	_check(atlas.globe.settlement_pins.size() == pins.size() and pins.size() >= 5, "Every visible settlement is pinned on the globe (%d)" % pins.size())
	atlas._select("italia", true)
	_check(not atlas.tribal.text.contains("Reiter ohne Feldzeichen"), "The unknown riders near Valdora stay hidden before anyone has met them")
	Relations.introduce(state.relations, "valdora", "red_seal_riders", "test_evidence", int(state.tick), "evidence")
	atlas.refresh()
	_check(atlas.tribal.text.contains("Reiter ohne Feldzeichen"), "Known riders appear in the Italia region")
	# The atlas reads the same dictionary the simulation advances.
	Tribes.advance_ticks(state, 13)
	atlas._select("germania", true)
	_check(atlas.tribal.text.contains(Tribes.calendar(state).label), "After a season the atlas shows the advanced world without a copy")
	atlas.tribes = Tribes.new_state(19, Tribes.NO_SCENARIO)
	atlas.refresh()
	_check(atlas.tribal.text.contains("keine Gruppenaufstellung"), "An era without roster says so instead of inventing groups")
	atlas.tribes = {}
	atlas.refresh()
	_check(atlas.tribal.text.contains("nicht mit diesem Spielstand verbunden"), "An unconnected atlas says so")
	atlas.queue_free()
	await process_frame
	if failures.is_empty():
		print("TRIBAL_ATLAS_PASS %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			print("FAILED: ", failure)
		print("TRIBAL_ATLAS_FAIL %d failures / %d checks" % [failures.size(), checks])
		quit(1)
