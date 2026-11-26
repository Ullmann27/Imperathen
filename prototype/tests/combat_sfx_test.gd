extends SceneTree
## Combat/movement SFX API: every documented material pair, mechanism, target
## and surface resolves to imported sounds; round robin never repeats the same
## variant twice in a row; energy maps to level; buses exist with ducking.

const CombatSfx = preload("res://scripts/audio/combat_sfx.gd")
const AudioBuses = preload("res://scripts/audio/audio_buses.gd")

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var sfx := CombatSfx.new()
	root.add_child(sfx)
	sfx.seed_variation(42)
	for bus in AudioBuses.BUSES:
		_check(AudioServer.get_bus_index(bus) != -1, "bus %s exists" % bus)
	for bus in [AudioBuses.MUSIC, AudioBuses.AMBIENCE]:
		var index := AudioServer.get_bus_index(bus)
		var ducked := false
		for i in AudioServer.get_bus_effect_count(index):
			var effect := AudioServer.get_bus_effect(index, i)
			if effect is AudioEffectCompressor and (effect as AudioEffectCompressor).sidechain == AudioBuses.VOICE:
				ducked = true
		_check(ducked, "%s is side-chain ducked by Voice" % bus)
	for a in CombatSfx.MATERIALS:
		for b in CombatSfx.MATERIALS:
			var pair := CombatSfx.pair_group(a, b)
			if pair.is_empty():
				continue
			for energy in [0.2, 0.9]:
				var record := sfx.play_impact(a, b, energy, Vector3.ZERO)
				_check(not record.is_empty() and ResourceLoader.exists(record.path), "impact %s/%s e=%.1f -> %s" % [a, b, energy, record.get("path", "none")])
				_check(str(record.get("group", "")).ends_with("_heavy" if energy >= 0.55 else "_light"), "energy %.1f selects level (%s)" % [energy, record.get("group", "")])
	_check(CombatSfx.pair_group("metal", "wood") == CombatSfx.pair_group("wood", "metal"), "material order is symmetric")
	for required in ["metal_metal", "metal_wood", "metal_leather", "metal_flesh"]:
		var parts: PackedStringArray = required.split("_")
		_check(CombatSfx.pair_group(parts[0], parts[1]) == required, "required pair %s is synthesised directly" % required)
	for key: String in CombatSfx.MECHANISMS:
		var parts := key.split(":")
		var record := sfx.play_weapon_event(parts[0], parts[1], Vector3(1, 0, 0))
		_check(not record.is_empty(), "weapon event %s" % key)
	for target in CombatSfx.PROJECTILE_TARGETS:
		_check(not sfx.play_projectile_impact(target, Vector3.ZERO).is_empty(), "projectile impact on %s" % target)
	for surface in CombatSfx.SURFACES:
		_check(not sfx.play_footstep(surface, Vector3.ZERO, 1.4).is_empty(), "footstep on %s" % surface)
	# Round robin: 40 consecutive heavy blade clashes never repeat a variant back to back.
	var last := -1
	var repeats := 0
	var seen := {}
	for i in 40:
		var r := sfx.play_impact("metal", "metal", 0.9, Vector3.ZERO)
		if int(r.index) == last:
			repeats += 1
		last = int(r.index)
		seen[last] = true
		_check(absf(float(r.pitch) - 1.0) <= 0.08 and float(r.volume_db) <= 1.6, "variation within bounds (pitch %.3f, %.1f dB)" % [r.pitch, r.volume_db])
	_check(repeats == 0 and seen.size() >= 4, "round robin uses all variants without immediate repeats (repeats=%d, variants=%d)" % [repeats, seen.size()])
	# Unknown material is rejected without crashing.
	_check(sfx.play_impact("glass", "metal", 0.5, Vector3.ZERO).is_empty(), "unknown material yields no sound")
	print("COMBAT_SFX_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	print("COMBAT_SFX_PASS" if failures.is_empty() else "COMBAT_SFX_FAIL")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
