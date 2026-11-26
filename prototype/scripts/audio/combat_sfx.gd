extends Node3D
## Epoch-independent combat and movement sound events.
##
## Callers describe PHYSICS, not a specific weapon: which materials touch,
## how much energy, which mechanism fires. New eras (e.g. later firearms or
## siege engines) add rows to MECHANISMS and sound groups; no API change.
##
##   play_impact(material_a, material_b, energy 0..1, position)
##   play_weapon_event(event, mechanism, position, energy)   # swing/draw/release/reload/flight
##   play_projectile_impact(target_material, position, energy)
##   play_footstep(surface, position, speed m/s)
##
## Variation: shuffle-bag round robin per group (no immediate repeats), random
## pitch (+-4 %, lower for heavier energy) and volume (+-1.5 dB). Attenuation:
## inverse distance, unit size 3 m, 60 m range, air absorption above 20 m.

const AudioBuses = preload("res://scripts/audio/audio_buses.gd")
const ROOT := "res://assets/audio/sfx/"
const MANIFEST := ROOT + "sfx_manifest.json"
const MATERIALS := ["metal", "wood", "leather", "flesh", "bone", "stone", "earth"]
## Canonical synthesised pairs; others map to the closest physical analogue.
const PAIRS := ["metal_metal", "metal_wood", "metal_leather", "metal_flesh", "wood_wood", "wood_flesh", "flesh_flesh", "leather_flesh", "metal_bone"]
const PAIR_FALLBACK := {"metal_stone": "metal_metal", "wood_stone": "wood_wood", "stone_flesh": "wood_flesh",
	"wood_leather": "wood_flesh", "leather_leather": "leather_flesh", "bone_flesh": "flesh_flesh",
	"wood_bone": "wood_flesh", "metal_earth": "metal_leather", "wood_earth": "wood_flesh", "earth_flesh": "flesh_flesh"}
## event:mechanism -> sound group. Mechanisms are physical, not historical.
const MECHANISMS := {
	"swing:light": "swish/light", "swing:heavy": "swish/heavy",
	"draw:bow": "bow/draw", "release:bow": "bow/release",
	"reload:crossbow": "crossbow/crank", "release:crossbow": "crossbow/release",
	"flight:arrow": "projectile/arrow_flight", "flight:bolt": "projectile/arrow_flight",
}
const PROJECTILE_TARGETS := ["wood", "flesh", "earth", "metal", "leather"]
const SURFACES := ["dirt", "stone", "wood", "grass", "gravel"]
const MAX_VOICES := 16

var _groups := {}       # "event/name" -> Array[String] of paths
var _bags := {}         # group -> Array[int] remaining indices
var _last := {}         # group -> last index
var _cache := {}        # path -> AudioStream
var _pool: Array[AudioStreamPlayer3D] = []
var _rng := RandomNumberGenerator.new()
## Last played record, used by tests and debugging overlays.
var last_event: Dictionary = {}


func _ready() -> void:
	AudioBuses.ensure_layout()
	_load_manifest()
	for i in MAX_VOICES:
		var p := AudioStreamPlayer3D.new()
		p.bus = AudioBuses.SFX
		p.unit_size = 3.0
		p.max_distance = 60.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.attenuation_filter_cutoff_hz = 6000.0
		p.attenuation_filter_db = -12.0
		add_child(p)
		_pool.append(p)


func seed_variation(value: int) -> void:
	_rng.seed = value


func _load_manifest() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)) if FileAccess.file_exists(MANIFEST) else null
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("CombatSfx: manifest missing: " + MANIFEST)
		return
	for entry: Dictionary in parsed.get("sounds", []):
		var group := "%s/%s" % [entry.event, entry.name]
		if not _groups.has(group):
			_groups[group] = []
		_groups[group].append(ROOT + str(entry.file))


func has_group(group: String) -> bool:
	return _groups.has(group)


static func pair_group(material_a: String, material_b: String) -> String:
	var a := material_a.to_lower()
	var b := material_b.to_lower()
	var ia := MATERIALS.find(a)
	var ib := MATERIALS.find(b)
	if ia == -1 or ib == -1:
		return ""
	var key := "%s_%s" % ([a, b] if ia <= ib else [b, a])
	if key in PAIRS:
		return key
	return str(PAIR_FALLBACK.get(key, ""))


func play_impact(material_a: String, material_b: String, energy: float, position: Vector3) -> Dictionary:
	var pair := pair_group(material_a, material_b)
	if pair.is_empty():
		push_warning("CombatSfx: unknown materials %s/%s" % [material_a, material_b])
		return {}
	var e := clampf(energy, 0.0, 1.0)
	var level := "heavy" if e >= 0.55 else "light"
	# Within a level, energy still scales loudness over a 9 dB window.
	var gain := lerpf(-9.0, 0.0, inverse_lerp(0.0 if level == "light" else 0.55, 0.55 if level == "light" else 1.0, e))
	return _play("impact/%s_%s" % [pair, level], position, gain, e)


func play_weapon_event(event: String, mechanism: String, position: Vector3, energy := 0.7) -> Dictionary:
	var group := str(MECHANISMS.get("%s:%s" % [event, mechanism], ""))
	if group.is_empty():
		push_warning("CombatSfx: no sound for %s:%s" % [event, mechanism])
		return {}
	return _play(group, position, lerpf(-6.0, 0.0, clampf(energy, 0.0, 1.0)), energy)


func play_projectile_impact(target_material: String, position: Vector3, energy := 0.8) -> Dictionary:
	var target := target_material.to_lower()
	if target not in PROJECTILE_TARGETS:
		target = "wood" if target in ["stone", "bone"] else "earth"
	return _play("projectile/arrow_impact_" + target, position, lerpf(-6.0, 0.0, clampf(energy, 0.0, 1.0)), energy)


func play_footstep(surface: String, position: Vector3, speed := 1.4) -> Dictionary:
	var s := surface if surface in SURFACES else "dirt"
	# Walking ~1.4 m/s, running ~4 m/s: louder and slightly brighter when running.
	var run := clampf((speed - 1.4) / 2.6, 0.0, 1.0)
	return _play("footstep/" + s, position, lerpf(-4.0, 2.0, run), 0.3 + 0.5 * run)


func _next_index(group: String) -> int:
	var count: int = _groups[group].size()
	var bag: Array = _bags.get(group, [])
	if bag.is_empty():
		for i in count:
			bag.append(i)
		# Fisher-Yates with our RNG for reproducible tests.
		for i in range(count - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var tmp: int = bag[i]
			bag[i] = bag[j]
			bag[j] = tmp
		if count > 1 and bag[0] == int(_last.get(group, -1)):
			bag.append(bag.pop_front())
	var index: int = bag.pop_front()
	_bags[group] = bag
	_last[group] = index
	return index


func _play(group: String, position: Vector3, gain_db: float, energy: float) -> Dictionary:
	if not _groups.has(group):
		push_warning("CombatSfx: missing group " + group)
		return {}
	var index := _next_index(group)
	var path: String = _groups[group][index]
	if not _cache.has(path):
		_cache[path] = load(path)
	var player := _free_player()
	player.stream = _cache[path]
	player.global_position = position
	player.pitch_scale = _rng.randf_range(0.96, 1.04) * lerpf(1.03, 0.97, clampf(energy, 0.0, 1.0))
	player.volume_db = gain_db + _rng.randf_range(-1.5, 1.5)
	player.play()
	last_event = {"group": group, "index": index, "path": path, "pitch": player.pitch_scale, "volume_db": player.volume_db}
	return last_event


func _free_player() -> AudioStreamPlayer3D:
	var oldest: AudioStreamPlayer3D = _pool[0]
	var oldest_pos := -1.0
	for p in _pool:
		if not p.playing:
			return p
		var pos := p.get_playback_position()
		if pos > oldest_pos:
			oldest_pos = pos
			oldest = p
	# Voice stealing: the sound that has played longest is closest to its tail.
	return oldest
