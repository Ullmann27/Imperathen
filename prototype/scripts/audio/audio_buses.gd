extends RefCounted
## Runtime mix layout: Master <- Voice, SFX, Ambience, Music.
## Music and Ambience carry a side-chained compressor keyed by the Voice bus,
## so spoken lines duck them automatically (no scripted volume fades needed).
## Master ends in a hard limiter at -1 dBFS as a safety net for phone speakers.

const VOICE := &"Voice"
const SFX := &"SFX"
const AMBIENCE := &"Ambience"
const MUSIC := &"Music"
const BUSES := [VOICE, SFX, AMBIENCE, MUSIC]
## Static bus gains (dB). Existing players keep their own volume_db (menu music,
## frontier ambience), so routing them here does not change today's balance.
## The dialogue anchor is -20 LUFS per line on the Voice bus.
const BUS_VOLUME_DB := {VOICE: 0.0, SFX: 0.0, AMBIENCE: 0.0, MUSIC: 0.0}
## Ducking: up to ~9 dB gain reduction on music/ambience while a voice plays.
const DUCK_THRESHOLD_DB := -30.0
const DUCK_RATIO := 6.0
const DUCK_ATTACK_US := 20000.0
const DUCK_RELEASE_MS := 450.0


static func ensure_layout() -> void:
	for bus: StringName in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, &"Master")
			AudioServer.set_bus_volume_db(index, float(BUS_VOLUME_DB[bus]))
			_configure(bus, index)
	var master := AudioServer.get_bus_index(&"Master")
	if not _has_effect(master, "AudioEffectHardLimiter"):
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(master, limiter)


static func _configure(bus: StringName, index: int) -> void:
	match bus:
		VOICE:
			# Remove rumble below the voice fundamental range; keep it dry,
			# room acoustics belong to the 3D player's area/reverb, not the bus.
			var hpf := AudioEffectHighPassFilter.new()
			hpf.cutoff_hz = 70.0
			AudioServer.add_bus_effect(index, hpf)
		AMBIENCE, MUSIC:
			var duck := AudioEffectCompressor.new()
			duck.sidechain = VOICE
			duck.threshold = DUCK_THRESHOLD_DB
			duck.ratio = DUCK_RATIO
			duck.attack_us = DUCK_ATTACK_US
			duck.release_ms = DUCK_RELEASE_MS
			AudioServer.add_bus_effect(index, duck)
		SFX:
			var limiter := AudioEffectHardLimiter.new()
			limiter.ceiling_db = -2.0
			AudioServer.add_bus_effect(index, limiter)


static func _has_effect(bus_index: int, type_name: String) -> bool:
	for i in AudioServer.get_bus_effect_count(bus_index):
		if AudioServer.get_bus_effect(bus_index, i).get_class() == type_name:
			return true
	return false
