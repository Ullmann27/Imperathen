extends SceneTree
## Material feedback, Fold7 particle budget and the synthesized impact sounds.

const Feedback = preload("res://scripts/domain/melee/melee_feedback.gd")
const Audio = preload("res://scripts/visuals/melee_impact_audio.gd")
const Fx = preload("res://scripts/visuals/melee_impact_fx.gd")
const Core = preload("res://scripts/domain/melee/melee_core.gd")
var checks := 0
var failures: Array[String] = []
var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_test_material_mapping()
	_test_energy_scaling()
	_test_synthesized_sounds()
	_test_pool_budget_and_duel_events()
	for failure in failures:
		printerr("FAIL: " + failure)
	print("MELEE_FEEDBACK_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("MELEE_FEEDBACK_PASS" if failures.is_empty() else "MELEE_FEEDBACK_FAIL")
	quit(0 if failures.is_empty() else 1)
	return true


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _kinds(feedback: Dictionary) -> Array:
	return feedback.bursts.map(func(b): return b.kind)


func _test_material_mapping() -> void:
	var cases := [
		[{"type":"hit", "weapon_material":"iron", "surface_material":"iron", "energy_j":120.0}, "sparks", "metal_clang"],
		[{"type":"block", "weapon_material":"iron", "surface_material":"bronze", "energy_j":120.0}, "sparks", "metal_ring"],
		[{"type":"block", "weapon_material":"iron", "surface_material":"wood", "energy_j":120.0}, "splinters", "wood_chop"],
		[{"type":"hit", "weapon_material":"iron", "surface_material":"leather", "energy_j":80.0}, "dust", "leather_slap"],
		[{"type":"hit", "weapon_material":"flesh", "surface_material":"cloth", "energy_j":20.0}, "fibre", "body_thud"],
		[{"type":"hit", "weapon_material":"flesh", "surface_material":"iron", "energy_j":20.0}, "dust", "mail_rattle"],
		[{"type":"whiff"}, "", "swish"],
		[{"type":"shield_broken"}, "splinters", "wood_crack"]]
	for c: Array in cases:
		var fb := Feedback.for_event(c[0])
		if not str(c[1]).is_empty():
			_check(c[1] in _kinds(fb), "%s on %s produces %s" % [c[0].get("weapon_material", c[0].type), c[0].get("surface_material", ""), c[1]])
		_check(fb.sound.id == c[2], "%s on %s sounds like %s (got %s)" % [c[0].get("weapon_material", c[0].type), c[0].get("surface_material", ""), c[2], fb.sound.id])
	_check(not "sparks" in _kinds(Feedback.for_event({"type":"block", "weapon_material":"iron", "surface_material":"wood", "energy_j":200.0})), "Iron on a wooden board never sparks")
	_check(Feedback.for_event({"type":"recovered"}).is_empty(), "Non-impact events produce no feedback")


func _test_energy_scaling() -> void:
	var weak := Feedback.for_event({"type":"hit", "weapon_material":"iron", "surface_material":"iron", "energy_j":5.0})
	var strong := Feedback.for_event({"type":"hit", "weapon_material":"iron", "surface_material":"iron", "energy_j":250.0})
	_check(int(strong.bursts[0].count) > int(weak.bursts[0].count), "A harder blow throws more sparks")
	_check(float(strong.sound.gain_db) > float(weak.sound.gain_db), "A harder blow is louder")
	_check(int(strong.bursts[0].count) <= Feedback.MAX_BURST, "A burst never exceeds the Fold7 burst budget")


func _test_synthesized_sounds() -> void:
	_check(Audio.SYNTHESIZED and Audio.LABEL.contains("synthesized") and Audio.LABEL.contains("foley"), "Sounds are labelled as synthesized placeholders pending recorded foley")
	var centroids := {}
	for id: String in Audio.IDS:
		var samples := Audio.samples_for(id)
		var seconds := samples.size() / float(Audio.RATE)
		var peak := 0.0
		for v in samples:
			peak = maxf(peak, absf(v))
		_check(seconds > 0.05 and seconds < 1.0, "%s lasts %.3f s" % [id, seconds])
		_check(absf(peak - 0.9) < 0.01, "%s is normalized to a 0.9 peak (%.3f)" % [id, peak])
		_check(samples == Audio.samples_for(id), "%s is synthesized deterministically" % id)
		var wav := Audio.stream(id)
		_check(wav != null and wav.resource_name.contains("synthesized"), "%s stream carries the placeholder label" % id)
		centroids[id] = Audio.centroid(samples)
	_check(centroids.metal_clang > centroids.wood_chop and centroids.wood_chop > centroids.body_thud, "Spectral centroid orders metal > wood > body (%.0f / %.0f / %.0f Hz)" % [centroids.metal_clang, centroids.wood_chop, centroids.body_thud])
	_check(centroids.metal_ring < centroids.metal_clang, "The bronze boss rings lower than iron on iron (%.0f < %.0f Hz)" % [centroids.metal_ring, centroids.metal_clang])
	print("MELEE_AUDIO_CENTROIDS " + JSON.stringify(centroids))


func _test_pool_budget_and_duel_events() -> void:
	var fx = Fx.new()
	get_root().add_child(fx)
	for i in 20:
		fx.spawn({"type":"hit", "weapon_material":"iron", "surface_material":"iron", "energy_j":300.0}, Vector3(0, 1, 0), Vector3.BACK)
	_check(fx.active_particles() <= Feedback.MAX_BURST * Feedback.MAX_ACTIVE_BURSTS, "Concurrent particles stay within %d (got %d)" % [Feedback.MAX_BURST * Feedback.MAX_ACTIVE_BURSTS, fx.active_particles()])
	# Real duel events drive the same feedback.
	var state := Core.new_state(4)
	Core.add_fighter(state, "a", "axe_fighter", {"team":"t"})
	Core.add_fighter(state, "d", "legionary", {"team":"r", "x":0.05, "z":-1.30})
	Core.face(state, "d", "a")
	Core.command(state, "d", "guard", {"style":"guard_high"})
	Core.step(state, 0.4)
	Core.command(state, "a", "attack", {"move":"axe_overhead"})
	var sounds := []
	for i in 80:
		for e: Dictionary in Core.step(state, 1.0 / 60.0):
			var fb: Dictionary = fx.spawn(e, e.get("point", Vector3.ZERO), Vector3.UP)
			if not fb.is_empty():
				sounds.append(fb.sound.id)
	_check(sounds.size() >= 1 and sounds[0] in ["wood_chop", "metal_ring"], "An axe on the scutum sounds like wood or the bronze boss (%s)" % str(sounds))
	fx.queue_free()
