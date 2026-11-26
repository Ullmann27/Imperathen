extends SceneTree
## Outfit policy of the original youth (D-032). Passes with or without the
## private youth derivatives installed; installed variants are checked too.
const Model = preload("res://scripts/domain/world_model.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const YouthOutfit = preload("res://scripts/visuals/youth_outfit.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("YOUTH_OUTFIT_FAIL: " + label)


func _run() -> void:
	var model := Model.new()
	model.new_game("italia", true, true)
	var childhood: Dictionary = model.data
	var before := JSON.stringify(childhood)
	_check(YouthOutfit.for_state(childhood) == "civil", "Band I childhood shows the civilian outfit")
	_check(int(childhood.village.history.start_year) == -58 and int(childhood.player.age) == 12, "childhood starts in 58 BC at age 12")
	_check(JSON.stringify(childhood) == before, "outfit policy never writes the save")
	# A saved and reloaded childhood state keeps its outfit (presentation only).
	var reloaded: Variant = JSON.parse_string(before)
	_check(reloaded is Dictionary and YouthOutfit.for_state(reloaded) == "civil", "reloaded childhood save shows the civilian outfit")
	model.new_game("italia")
	_check(YouthOutfit.for_state(model.data) == "armoured", "legacy village game keeps the original armoured look")
	_check(YouthOutfit.for_state({}) == "armoured", "empty state falls back to the original")
	_check(Person.MESHY_YOUTH_OUTFITS.has("civil") and Person.MESHY_YOUTH_OUTFITS.has("armoured"), "outfit registry lists both variants")
	_check(not Person.youth_outfit_installed("missing"), "unknown outfit is never installed")

	var actor := Person.new()
	root.add_child(actor)
	actor.set_process(false)
	actor.configure("player", "italia", 12)
	var armoured := Person.youth_outfit_installed("armoured")
	var civil := Person.youth_outfit_installed("civil")
	_check(actor.configure_meshy_youth(true, "missing") == armoured, "unknown request uses the armoured original when installed")
	_check(actor.youth_outfit == "armoured" and actor.requested_youth_outfit == "armoured", "unknown request is normalised")
	var shown := actor.configure_meshy_youth(true, "civil")
	_check(actor.requested_youth_outfit == "civil", "civilian request is kept")
	_check(actor.youth_outfit == ("civil" if civil else "armoured"), "civilian request falls back only when not installed")
	_check(shown == (civil or armoured), "youth selected exactly when a variant is installed")
	if civil:
		_check(actor.active_model_path == "res://assets/characters/hero_meshy_italia_civil_%d.glb" % maxi(0, actor.detail), "civilian LOD path in use")
		_check(actor._uses_youth_mocap(), "civilian variant uses the original MoCap route")
		actor.configure("player", "italia", 18)
		_check(not actor.configure_meshy_youth(true, "civil"), "adult player never receives the youth body")
	actor.free()
	print("YOUTH_OUTFIT_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "armoured_installed": armoured, "civil_installed": civil}))
	print("YOUTH_OUTFIT_PASS" if failures.is_empty() else "YOUTH_OUTFIT_FAIL")
	quit(0 if failures.is_empty() else 1)
