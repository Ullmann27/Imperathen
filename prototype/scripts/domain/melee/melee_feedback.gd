extends RefCounted
## Material-dependent impact feedback derived from a melee event: which
## particles (sparks, splinters, dust, fibre) and which impact sound. Pure
## data so tests, level B and the presentation agree on the same mapping.
##
## Sound ids name procedurally SYNTHESIZED placeholders (melee_impact_audio.gd)
## pending recorded foley; they are not presented as final audio.

## Fold7 budget: at most this many particles in one burst and this many
## simultaneous bursts (measured worst case 6 x 48 = 288 CPU particles).
const MAX_BURST := 48
const MAX_ACTIVE_BURSTS := 6
const HARD := ["iron", "bronze"]
const MISSILE_AS := {"projectile_hit":"hit", "projectile_block":"block", "projectile_miss":"ground"}


## Returns {"bursts":[{kind, count, speed, spread_deg, lifetime, gravity}],
## "sound":{id, gain_db, pitch}} for hit/block/parry/guard_broken/whiff/
## shield_broken events and missile impacts; {} for events without one.
static func for_event(event: Dictionary) -> Dictionary:
	# A missile meeting a surface sounds and scatters like a blow on it.
	var type := str(MISSILE_AS.get(event.get("type", ""), event.get("type", "")))
	var energy := float(event.get("energy_j", 0.0))
	var weapon := str(event.get("weapon_material", ""))
	var surface := str(event.get("surface_material", ""))
	# Loudness and particle count follow impact energy on a log scale.
	var level := clampf(log(1.0 + energy) / log(1.0 + 300.0), 0.05, 1.0)
	match type:
		"whiff":
			return {"bursts":[], "sound":{"id":"swish", "gain_db":-14.0, "pitch":1.0}}
		"shield_broken":
			return {"bursts":[_burst("splinters", 1.0, 2.6, 70.0, 1.1), _burst("dust", 0.6, 0.9, 80.0, 1.4)],
				"sound":{"id":"wood_crack", "gain_db":-2.0, "pitch":1.0}}
		"ground":
			return {"bursts":[_burst("dust", level * 0.6, 0.9, 70.0, 1.0)], "sound":{"id":"body_thud", "gain_db":lerpf(-20.0, -6.0, level), "pitch":0.9}}
		"hit", "block", "parry", "guard_broken":
			pass
		_:
			return {}
	var bursts: Array = []
	var sound := "body_thud"
	if weapon in HARD and surface in HARD:
		bursts.append(_burst("sparks", level, 4.5, 55.0, 0.32))
		sound = "metal_ring" if surface == "bronze" else "metal_clang"
	elif weapon in HARD and surface == "wood":
		bursts.append(_burst("splinters", level, 2.2, 50.0, 0.9))
		bursts.append(_burst("dust", level * 0.5, 0.7, 70.0, 1.0))
		sound = "wood_chop"
	elif surface in HARD:
		# Fist or foot against mail: no sparks, a dull ring of the rings.
		bursts.append(_burst("dust", level * 0.4, 0.6, 60.0, 0.8))
		sound = "mail_rattle"
	elif surface in ["leather", "cloth"]:
		bursts.append(_burst("fibre" if surface == "cloth" else "dust", level * 0.7, 0.9, 60.0, 0.9))
		sound = "leather_slap" if weapon in HARD or surface == "leather" else "body_thud"
	else:
		bursts.append(_burst("dust", level * 0.5, 0.7, 60.0, 0.8))
		sound = "body_thud"
	if type == "parry":
		for burst: Dictionary in bursts:
			burst.count = mini(MAX_BURST, int(burst.count * 1.3))
	return {"bursts":bursts, "sound":{"id":sound, "gain_db":lerpf(-18.0, -1.0, level), "pitch":lerpf(1.08, 0.92, level)}}


static func _burst(kind: String, level: float, speed: float, spread: float, lifetime: float) -> Dictionary:
	var count := clampi(int(round(MAX_BURST * clampf(level, 0.0, 1.0))), 4, MAX_BURST)
	var gravity: float = {"sparks":-6.0, "splinters":-9.8, "dust":-0.6, "fibre":-1.2}[kind]
	return {"kind":kind, "count":count, "speed":speed * lerpf(0.6, 1.0, level), "spread_deg":spread,
		"lifetime":lifetime, "gravity":gravity}
