extends RefCounted
## Level-A melee authority (near the player): individually simulated strikes,
## shield blocks, parries, dodges, directional hit reactions, stamina,
## fatigue, injuries and morale. Fixed 60 Hz frames, deterministic per seed.
##
## Contact is never scheduled. Each clip frame of a live strike window sweeps
## the measured weapon capsule (melee_track_data.gd, measured from the
## displayed animation) from the previous frame to the current one against the
## defender's shield box and body capsule. Damage, block and reaction events
## carry the exact frame of that contact; nothing is booked earlier.
##
## State is plain JSON-compatible data so level B can persist, hand over and
## take back the same soldier identities without duplicating anyone.

const Tracks = preload("res://scripts/domain/melee/melee_tracks.gd")
const Geo = preload("res://scripts/domain/melee/melee_geometry.gd")
const Actions = preload("res://scripts/domain/combat_actions.gd")
const Damage = preload("res://scripts/domain/melee/melee_damage.gd")
const Weapons = preload("res://scripts/domain/melee/weapon_catalog.gd")
const Ranged = preload("res://scripts/domain/melee/melee_ranged.gd")
const Impacts = preload("res://scripts/domain/melee/combat_impacts.gd")

const VERSION := 1
const FPS := 60
const DT := 1.0 / 60.0
## Weapon physics and materials: weapon_catalog.gd (assets/combat/weapons.json).
## Damage base and stamina cost: the shared balance file (melee_damage.gd).
const PARRY_WINDOW := 0.20
const GUARD_MIN_STAMINA := 5.0
const DODGE_COST := 16.0
const STAMINA_LIMIT := 100.0
const STAMINA_RECOVERY := 12.0
const POISE_PER_KG := 1.6
## Impact pause of the striker in frames, growing with the impact energy
## (log scale, as loudness and particles do): a child's jab barely checks,
## a full axe blow sticks. A hard surface (shield) holds one frame longer.
const HITSTOP_RANGE := [2, 6]
const HITSTOP_BLOCK_EXTRA := 1
const HITSTOP_FULL_J := 300.0
const SUBSTEP_METRES := 0.03
const REACTIONS := {
	"flinch":{"duration":0.25, "step":0.0, "strength":0.35},
	"stagger":{"duration":0.50, "step":0.18, "strength":0.75},
	"stumble":{"duration":0.85, "step":0.40, "strength":1.1},
	"parried":{"duration":0.45, "step":0.12, "strength":0.7},
	"recoil":{"duration":0.30, "step":0.0, "strength":0.25},
	"guard_broken":{"duration":0.60, "step":0.20, "strength":0.9},
	"down":{"duration":1.60, "step":0.30, "strength":1.5}}
## Root motion in the fighter's Godot frame (forward is -Z).
const DODGES := {
	"dodge_back":{"duration":0.46, "root":Vector3(0.0, 0.0, 0.55)},
	"dodge_left":{"duration":0.46, "root":Vector3(-0.50, 0.0, 0.08)},
	"dodge_right":{"duration":0.46, "root":Vector3(0.50, 0.0, 0.08)}}
## Reactions that tear the shield out of line: for the first part of the
## reaction it covers nothing (the opening a broken guard gives).
const SHIELD_OPEN_REACTIONS := ["guard_broken", "stumble"]
const SHIELD_OPEN_UNTIL := 0.8
const MORALE_WAVERING := 35.0
const MORALE_BREAKING := 15.0


static func new_state(seed: int) -> Dictionary:
	return {"version":VERSION, "seed":seed, "frame":0, "accumulator":0.0, "rng":0, "fighters":{},
		"projectiles":[], "next_projectile":0, "silent":false}


## options: team, x, z, yaw, scale, health, armor (kit clothing), morale,
## stamina; for the D-042 formula skill (0-100 training), weapon_quality
## (grade 0-4) and armor_pieces {zone:{family, quality, wear}} (default: what
## the kit's clothing stands for); ranged (weapon ids carried) with ammo
## {id: count} (default: the catalogue's load).
static func add_fighter(state: Dictionary, id: String, kit_id: String, options: Dictionary = {}) -> String:
	var kit := Tracks.kit(kit_id)
	if kit.is_empty():
		return "Unbekannte Kampfausrüstung: " + kit_id
	if id.is_empty() or id.length() > 64 or state.fighters.has(id):
		return "Ungültige oder doppelte Kämpferkennung."
	var scale := float(options.get("scale", 1.0))
	var shield: Variant = kit.get("shield", "")
	state.fighters[id] = {
		"id":id, "kit":kit_id, "team":str(options.get("team", id)),
		"x":float(options.get("x", 0.0)), "z":float(options.get("z", 0.0)), "yaw":float(options.get("yaw", 0.0)),
		"scale":scale, "radius":float(kit.radius) * scale, "height":float(kit.height) * scale,
		"mass":float(kit.mass_kg) * pow(scale, 3.0), "armor":str(options.get("armor", kit.armor)),
		"has_shield":typeof(shield) == TYPE_DICTIONARY, "shield_integrity":1.0,
		"skill":clampf(float(options.get("skill", 55.0)), 0.0, 100.0), "weapon_quality":clampi(int(options.get("weapon_quality", 2)), 0, 4), "weapon_wear":0.0,
		"armor_pieces":(options.get("armor_pieces", Damage.kit_armor(str(options.get("armor", kit.armor)))) as Dictionary).duplicate(true),
		"shield_fouled":0, "ammo":_ammo(options), "ranged":{},
		"health":float(options.get("health", 100.0)), "max_health":float(options.get("health", 100.0)),
		"stamina":float(options.get("stamina", STAMINA_LIMIT)), "fatigue":0.0,
		"morale":float(options.get("morale", 70.0)), "morale_state":"steady",
		"action":"idle", "move":"", "t":0.0, "last_frame":-1, "resolved":true, "hitstop":0,
		"guard_style":"", "guard_t":0.0, "dodge":"", "dodge_t":0.0,
		"react":{}, "recoil":[], "injuries":[], "bleed":0.0, "concussion":0.0, "alive":true,
		"stats":{"hits":0, "blocks":0, "parries":0, "whiffs":0, "taken":0, "interrupted":0}}
	return ""


static func _ammo(options: Dictionary) -> Dictionary:
	var ammo := {}
	var given: Dictionary = options.get("ammo", {})
	for weapon_id: Variant in options.get("ranged", []):
		if Weapons.is_ranged(str(weapon_id)):
			ammo[str(weapon_id)] = maxi(0, int(given.get(weapon_id, Weapons.weapon(str(weapon_id)).ammo)))
	return ammo


static func fighter(state: Dictionary, id: String) -> Dictionary:
	return state.fighters.get(id, {})


## External locomotion (level B, raid AI, player controller). The caller is
## responsible for world collision; values must be finite.
static func place(state: Dictionary, id: String, x: float, z: float, yaw: float) -> bool:
	var f := fighter(state, id)
	if f.is_empty() or not (is_finite(x) and is_finite(z) and is_finite(yaw)):
		return false
	f.x = x
	f.z = z
	f.yaw = wrapf(yaw, -PI, PI)
	return true


static func face(state: Dictionary, id: String, target_id: String) -> bool:
	var f := fighter(state, id)
	var t := fighter(state, target_id)
	if f.is_empty() or t.is_empty():
		return false
	var d := Vector2(float(t.x) - float(f.x), float(t.z) - float(f.z))
	if d.length_squared() < 0.000001:
		return false
	f.yaw = atan2(-d.x, -d.y)
	return true


static func move_cost(kit_id: String, move_id: String) -> float:
	if kit_id in [Tracks.PLAYER_UNARMED, Tracks.PLAYER_ARMED] and Actions.TECHNIQUES.has(move_id):
		return float(Actions.TECHNIQUES[move_id].cost)
	return Weapons.stamina_cost(str(Tracks.move(kit_id, move_id).get("family", "")))


## Commands: attack {move}, guard {style}, release {}, dodge {style};
## missiles: draw {weapon, target?|yaw?,pitch?} (with an aim the shot follows
## as soon as the draw is complete), loose {target|yaw,pitch}, lower {}.
static func command(state: Dictionary, id: String, action: String, args: Dictionary = {}) -> Dictionary:
	var f := fighter(state, id)
	if f.is_empty() or not bool(f.alive):
		return {"ok":false, "message":"Kein handlungsfähiger Kämpfer."}
	if action in ["loose", "lower"]:
		return _ranged_command(state, f, action, args)
	if f.action in ["react", "down", "dodge", "attack", "ranged"]:
		return {"ok":false, "message":"Die laufende Bewegung ist noch nicht beendet."}
	match action:
		"draw":
			return _ranged_command(state, f, action, args)
		"attack":
			var move_id := str(args.get("move", ""))
			if not Tracks.has_move(str(f.kit), move_id):
				return {"ok":false, "message":"Diese Bewegung gehört nicht zu dieser Ausrüstung."}
			var cost := move_cost(str(f.kit), move_id)
			if float(f.stamina) + 0.000001 < cost:
				return {"ok":false, "message":"Zu erschöpft für diesen Schlag."}
			_spend(f, cost)
			f.action = "attack"
			f.move = move_id
			f.t = 0.0
			f.last_frame = 0
			f.resolved = false
			f.hitstop = 0
			f.guard_style = ""
			return {"ok":true, "message":move_id}
		"guard":
			var style := str(args.get("style", "guard_front"))
			if not style in Tracks.guard_styles():
				return {"ok":false, "message":"Unbekannte Deckung."}
			if float(f.stamina) < GUARD_MIN_STAMINA:
				return {"ok":false, "message":"Zu erschöpft für eine Deckung."}
			f.action = "guard"
			f.guard_style = style
			f.guard_t = 0.0
			return {"ok":true, "message":style}
		"release":
			if f.action == "guard":
				f.action = "idle"
				f.guard_style = ""
			return {"ok":true, "message":"idle"}
		"dodge":
			var style := str(args.get("style", "dodge_back"))
			if not DODGES.has(style):
				return {"ok":false, "message":"Unbekannte Ausweichbewegung."}
			if float(f.stamina) + 0.000001 < DODGE_COST:
				return {"ok":false, "message":"Zu erschöpft zum Ausweichen."}
			_spend(f, DODGE_COST)
			f.action = "dodge"
			f.dodge = style
			f.dodge_t = 0.0
			f.guard_style = ""
			return {"ok":true, "message":style}
	return {"ok":false, "message":"Unbekannter Kampfbefehl."}


## External morale events from level B (ally fell, officer present, rout nearby).
static func morale_event(state: Dictionary, id: String, delta: float, reason: String) -> Array:
	var f := fighter(state, id)
	var events: Array = []
	if not f.is_empty():
		_morale(state, f, delta, reason, events)
	return events


## Advance by real time. Whole 60 Hz frames only; the remainder carries over,
## so any tick partition yields the same frames and events.
## world_clear(from: Vector3, to: Vector3) -> bool optionally confirms a line
## of contact through world geometry (walls, other residents).
static func step(state: Dictionary, delta: float, world_clear: Callable = Callable()) -> Array:
	var events: Array = []
	if not is_finite(delta) or delta <= 0.0 or delta > 10.0:
		return events
	state.accumulator = float(state.accumulator) + delta
	while float(state.accumulator) + 0.0000001 >= DT:
		state.accumulator = float(state.accumulator) - DT
		state.frame = int(state.frame) + 1
		_frame(state, events, world_clear)
	if not bool(state.get("silent", false)):
		Impacts.publish(events)
	return events


static func _ids(state: Dictionary) -> Array:
	var ids: Array = state.fighters.keys()
	ids.sort()
	return ids


static func _frame(state: Dictionary, events: Array, world_clear: Callable) -> void:
	var ids := _ids(state)
	# 1. Timers, root motion, recovery.
	for id: String in ids:
		_tick(state, state.fighters[id], events)
	# 2. Contacts are found against the state at the start of the frame and
	#    applied afterwards, so simultaneous strikes trade fairly.
	var contacts: Array = []
	for id: String in ids:
		var f: Dictionary = state.fighters[id]
		if f.action != "attack" or not bool(f.alive):
			continue
		if int(f.hitstop) > 0:
			f.hitstop = int(f.hitstop) - 1
			# After the impact pause the weapon rebounds instead of playing its
			# free-air follow-through through the body or the shield.
			if int(f.hitstop) == 0 and not (f.recoil as Array).is_empty():
				var push := Vector3(float(f.recoil[0]), 0.0, float(f.recoil[1]))
				f.recoil = []
				_set_reaction(state, f, "recoil", push, events)
			continue
		var timing := Tracks.timing(str(f.kit), str(f.move))
		var old_t := float(f.t)
		var new_t := old_t + DT * _tempo(f)
		var to_frame := mini(Tracks.frame_of(new_t), int(timing.frames) - 1)
		for g in range(int(f.last_frame) + 1, to_frame + 1):
			if bool(f.resolved):
				break
			if g < int(timing.start) or g > int(timing.end):
				continue
			if g == int(timing.start):
				events.append(_swing_event(state, f, g))
			var contact := _sweep(state, f, g, world_clear)
			if not contact.is_empty():
				contacts.append(contact)
				f.resolved = true
		if not bool(f.resolved) and to_frame >= int(timing.end):
			f.resolved = true
			f.stats.whiffs = int(f.stats.whiffs) + 1
			events.append({"type":"whiff", "frame":state.frame, "attacker":id, "move":f.move, "clip_frame":int(timing.end)})
			_morale(state, f, -1.0, "whiff", events)
		f.t = new_t
		f.last_frame = to_frame
		if new_t + 0.000001 >= float(timing.duration):
			f.action = "idle"
			f.move = ""
			f.t = 0.0
			f.last_frame = -1
			f.resolved = true
			events.append({"type":"recovered", "frame":state.frame, "fighter":id})
	for contact: Dictionary in contacts:
		_resolve(state, contact, events)
	# 3. Missiles in flight.
	_fly(state, events, world_clear)


## The weapon starts cutting the air: first frame of the measured live window.
static func _swing_event(state: Dictionary, f: Dictionary, g: int) -> Dictionary:
	var m := Tracks.move(str(f.kit), str(f.move))
	var family := str(m.family)
	var speed := float(m.window_top_speed) * float(f.scale)
	return {"type":"swing", "frame":state.frame, "clip_frame":g, "attacker":f.id, "move":f.move, "family":family,
		"weapon_material":Weapons.material(family), "strike_kind":Weapons.strike_kind(family, str(f.move)),
		"speed_m_s":snappedf(speed, 0.001), "energy_j":snappedf(0.5 * Weapons.effective_mass(family) * pow(float(f.scale), 3.0) * speed * speed, 0.01),
		"point":strike_world(f, g)[1]}


static func _tick(state: Dictionary, f: Dictionary, events: Array) -> void:
	if not bool(f.alive):
		return
	var resting: bool = f.action == "idle"
	match str(f.action):
		"ranged":
			_ranged_tick(state, f, events)
		"guard":
			f.guard_t = float(f.guard_t) + DT
			if float(f.stamina) <= 0.0:
				f.action = "idle"
				f.guard_style = ""
		"dodge":
			var spec: Dictionary = DODGES[f.dodge]
			var before := dodge_offset(str(f.dodge), float(f.dodge_t)) * _leg_factor(f)
			f.dodge_t = float(f.dodge_t) + DT
			var after := dodge_offset(str(f.dodge), float(f.dodge_t)) * _leg_factor(f)
			_displace(state, f, Basis(Vector3.UP, float(f.yaw)) * (after - before))
			if float(f.dodge_t) + 0.000001 >= float(spec.duration):
				f.action = "idle"
				f.dodge = ""
				f.dodge_t = 0.0
		"react", "down":
			var r: Dictionary = f.react
			var duration := float(r.duration)
			var before := smoothstep(0.05, 0.40, float(r.t) / duration)
			r.t = float(r.t) + DT
			var after := smoothstep(0.05, 0.40, float(r.t) / duration)
			var step := Vector3(float(r.step[0]), 0.0, float(r.step[1]))
			_displace(state, f, step * (after - before))
			if float(r.t) + 0.000001 >= duration:
				if float(f.health) <= 0.0:
					f.alive = false
					events.append({"type":"killed", "frame":state.frame, "fighter":f.id})
				else:
					f.action = "idle"
					f.react = {}
					events.append({"type":"recovered", "frame":state.frame, "fighter":f.id})
	# Stamina, fatigue, bleeding, concussion.
	var rate := STAMINA_RECOVERY * (1.0 - 0.5 * float(f.fatigue))
	if float(f.morale) < MORALE_WAVERING:
		rate *= 0.6
	if resting:
		f.stamina = minf(STAMINA_LIMIT, float(f.stamina) + rate * DT)
		f.fatigue = maxf(0.0, float(f.fatigue) - 0.004 * DT)
	elif f.action == "guard":
		f.stamina = minf(STAMINA_LIMIT, float(f.stamina) + rate * 0.3 * DT)
	if float(f.bleed) > 0.0:
		f.health = maxf(0.0, float(f.health) - float(f.bleed) * DT)
		if float(f.health) <= 0.0 and f.action != "down":
			_set_reaction(state, f, "down", Vector3.ZERO, events)
	f.concussion = maxf(0.0, float(f.concussion) - 0.05 * DT)
	if float(f.stamina) < 15.0 and f.action != "idle":
		_morale(state, f, -0.5 * DT, "exhaustion", events)


static func dodge_offset(style: String, seconds: float) -> Vector3:
	if not DODGES.has(style):
		return Vector3.ZERO
	var spec: Dictionary = DODGES[style]
	return Vector3(spec.root) * smoothstep(0.06, 0.88, clampf(seconds / float(spec.duration), 0.0, 1.0))


static func _leg_factor(f: Dictionary) -> float:
	for injury: Dictionary in f.injuries:
		if injury.kind == "leg_wound":
			return 0.6
	return 1.0


## Root motion with capsule separation: a pushed fighter cannot pass through
## another body (no engine physics in the domain).
static func _displace(state: Dictionary, f: Dictionary, motion: Vector3) -> void:
	var target := Vector2(float(f.x) + motion.x, float(f.z) + motion.z)
	for other_id: String in _ids(state):
		var o: Dictionary = state.fighters[other_id]
		if o.id == f.id or not bool(o.alive):
			continue
		var c := Vector2(float(o.x), float(o.z))
		var minimum := float(f.radius) + float(o.radius)
		var offset := target - c
		if offset.length() < minimum:
			target = c + (offset.normalized() if offset.length() > 0.0001 else Vector2(motion.x, motion.z).normalized()) * minimum
	f.x = target.x
	f.z = target.y


static func _tempo(f: Dictionary) -> float:
	# Fatigue only slows a fighter once it is substantial (> 0.3).
	var tempo := 1.0 - 0.25 * maxf(0.0, float(f.fatigue) - 0.3) - float(f.concussion)
	for injury: Dictionary in f.injuries:
		if injury.kind == "arm_wound":
			tempo -= 0.10
	if float(f.morale) < MORALE_WAVERING:
		tempo -= 0.08
	return clampf(tempo, 0.6, 1.0)


static func _spend(f: Dictionary, cost: float) -> void:
	f.stamina = maxf(0.0, float(f.stamina) - cost)
	f.fatigue = minf(1.0, float(f.fatigue) + cost * 0.0015)


static func _origin(f: Dictionary) -> Vector3:
	return Vector3(float(f.x), 0.0, float(f.z))


## Whether the shield covers anything right now: it exists, the arm still has
## the strength to hold it up (an exhausted fighter's shield hangs) and it has
## not just been knocked out of line.
static func shield_usable(f: Dictionary) -> bool:
	if not bool(f.has_shield) or float(f.shield_integrity) <= 0.0:
		return false
	if shield_lowered(f):
		return false
	return not shield_open(f)


## Too exhausted to hold the shield up (outside a committed strike).
static func shield_lowered(f: Dictionary) -> bool:
	return bool(f.has_shield) and float(f.stamina) < GUARD_MIN_STAMINA and f.action != "attack"


## Knocked out of line by a guard break or a stumble.
static func shield_open(f: Dictionary) -> bool:
	if f.action != "react" or not str(f.react.get("kind", "")) in SHIELD_OPEN_REACTIONS:
		return false
	return float(f.react.t) < float(f.react.duration) * SHIELD_OPEN_UNTIL


## Current shield frame (world) of a defender, or [] without a usable shield.
static func shield_world(f: Dictionary) -> Array:
	if not shield_usable(f):
		return []
	var pose := "stance"
	var frame := 0
	match str(f.action):
		"guard":
			pose = str(f.guard_style)
			frame = Tracks.frame_of(float(f.guard_t))
		"attack":
			pose = str(f.move)
			frame = Tracks.frame_of(float(f.t))
	var local := Tracks.shield(str(f.kit), pose, frame)
	if local.is_empty():
		return []
	var o := _origin(f)
	var yaw := float(f.yaw)
	var s := float(f.scale)
	var basis := Basis(Vector3.UP, yaw)
	return [Geo.to_world(o, yaw, s, local[0]), basis * Vector3(local[1]), basis * Vector3(local[2])]


static func shield_half(f: Dictionary) -> Vector3:
	var spec: Dictionary = Tracks.kit(str(f.kit)).get("shield", {})
	var s := float(f.scale)
	if spec.get("shape", "") == "disc":
		# Equal-area square for the round shield's disc (half = R*sqrt(pi)/2).
		var half := float(spec.radius) * 0.8862 * s
		return Vector3(half, half, float(spec.half_thickness) * s)
	var h: Array = spec.get("half", [0.0, 0.0, 0.0])
	return Vector3(float(h[0]), float(h[1]), float(h[2])) * s


## World strike capsule of an attacker at a clip frame.
static func strike_world(f: Dictionary, frame: int) -> Array:
	var seg := Tracks.segment(str(f.kit), str(f.move), frame)
	if seg.is_empty():
		return []
	var o := _origin(f)
	return [Geo.to_world(o, float(f.yaw), float(f.scale), seg[0]), Geo.to_world(o, float(f.yaw), float(f.scale), seg[1])]


## Sweep the strike from clip frame g-1 to g against every opponent.
## Returns the earliest contact {defender, kind: body|shield, ...} or {}.
static func _sweep(state: Dictionary, f: Dictionary, g: int, world_clear: Callable) -> Dictionary:
	var m := Tracks.move(str(f.kit), str(f.move))
	var radius := float(m.radius) * float(f.scale)
	var prev := strike_world(f, g - 1)
	var cur := strike_world(f, g)
	var travel := maxf((cur[0] - prev[0]).length(), (cur[1] - prev[1]).length())
	var steps := clampi(int(ceil(travel / SUBSTEP_METRES)), 1, 16)
	var best := {}
	var best_key := INF
	for other_id: String in _ids(state):
		var d: Dictionary = state.fighters[other_id]
		if d.id == f.id or not bool(d.alive) or d.team == f.team or d.action == "down":
			continue
		var axis := Geo.body_axis(_origin(d), float(d.radius), float(d.height))
		var shield := shield_world(d)
		var half := shield_half(d) if not shield.is_empty() else Vector3.ZERO
		for k in range(1, steps + 1):
			var s := float(k) / float(steps)
			var a: Vector3 = prev[0].lerp(cur[0], s)
			var b: Vector3 = prev[1].lerp(cur[1], s)
			var order := float(g) + s
			if order >= best_key:
				break
			if not shield.is_empty():
				var entry := Geo.segment_box(a, b, shield[0], shield[1], shield[2], half, radius)
				if entry >= 0.0:
					var point := a.lerp(b, entry)
					if _clear(world_clear, f, point):
						best = _contact_record(state, f, d, g, k, steps, prev, cur, entry, point, "shield")
						best_key = order
					break
			var closest := Geo.segment_segment(a, b, axis[0], axis[1])
			if float(closest[2]) <= radius + float(d.radius):
				var on_strike: Vector3 = a.lerp(b, float(closest[0]))
				var on_axis: Vector3 = axis[0].lerp(axis[1], float(closest[1]))
				var outward := on_strike - on_axis
				var point := on_axis + (outward.normalized() if outward.length() > 0.0001 else Geo.forward(float(d.yaw))) * float(d.radius)
				if _clear(world_clear, f, point):
					best = _contact_record(state, f, d, g, k, steps, prev, cur, float(closest[0]), point, "body")
					best_key = order
				break
	return best


static func _clear(world_clear: Callable, f: Dictionary, point: Vector3) -> bool:
	if not world_clear.is_valid():
		return true
	var chest := _origin(f) + Vector3(0.0, float(f.height) * 0.72, 0.0)
	var result: Variant = world_clear.call(chest, point)
	return typeof(result) == TYPE_BOOL and result


static func _contact_record(state: Dictionary, f: Dictionary, d: Dictionary, g: int, k: int, steps: int, prev: Array, cur: Array, along: float, point: Vector3, kind: String) -> Dictionary:
	var v_base: Vector3 = (cur[0] - prev[0]) * FPS
	var v_tip: Vector3 = (cur[1] - prev[1]) * FPS
	var velocity := v_base.lerp(v_tip, clampf(along, 0.0, 1.0))
	return {"attacker":f.id, "defender":d.id, "move":f.move, "kind":kind, "clip_frame":g, "substep":float(k) / float(steps),
		"point":point, "velocity":velocity, "along":along, "frame":state.frame}


static func _resolve(state: Dictionary, c: Dictionary, events: Array) -> void:
	var f: Dictionary = state.fighters[c.attacker]
	var d: Dictionary = state.fighters[c.defender]
	if not bool(d.alive):
		return
	# The contact's own move: a strike that landed in the same frame may
	# already have knocked this attacker out of it (a fair trade).
	var move_id := str(c.move)
	var m := Tracks.move(str(f.kit), move_id)
	var family := str(m.family)
	var speed := (c.velocity as Vector3).length()
	# Drive speed: the fastest the striking point has moved inside the live
	# window up to this contact. A free-air clip decelerates into full
	# extension; a target met there still receives the stroke's momentum,
	# while a strike jammed early only carries what it has built up so far.
	var drive_speed := maxf(speed, Tracks.drive_speed(str(f.kit), move_id, int(c.clip_frame), float(c.along)) * float(f.scale))
	var energy := 0.5 * Weapons.effective_mass(family) * pow(float(f.scale), 3.0) * drive_speed * drive_speed
	# A strike caught early in its window (jammed) has not developed its drive.
	var progress := clampf(float(int(c.clip_frame) - int(m.start)) / maxf(1.0, float(int(m.peak) - int(m.start))), 0.0, 1.0)
	energy *= lerpf(0.5, 1.0, smoothstep(0.0, 0.6, progress))
	var push := Vector3((c.velocity as Vector3).x, 0.0, (c.velocity as Vector3).z)
	if push.length() < 0.05:
		push = Vector3(float(d.x) - float(f.x), 0.0, float(d.z) - float(f.z))
	push = push.normalized()
	var base_event := {"frame":state.frame, "clip_frame":int(c.clip_frame), "attacker":f.id, "defender":d.id,
		"move":move_id, "family":family, "energy_j":snappedf(energy, 0.01), "speed_m_s":snappedf(speed, 0.001), "drive_speed_m_s":snappedf(drive_speed, 0.001),
		"point":c.point, "direction":Geo.side_of(float(d.yaw), -push), "direction_vector":push,
		"weapon_material":Weapons.material(family), "strike_kind":Weapons.strike_kind(family, move_id)}
	if c.kind == "shield":
		_resolve_block(state, f, d, energy, push, c, base_event, events)
		return
	_resolve_hit(state, f, d, m, energy, push, c, base_event, events)


static func _resolve_block(state: Dictionary, f: Dictionary, d: Dictionary, energy: float, push: Vector3, c: Dictionary, base: Dictionary, events: Array) -> void:
	var braced: bool = d.action == "guard"
	var parry: bool = braced and float(d.guard_t) <= PARRY_WINDOW
	var cost := clampf(energy * 0.10, 3.0, 40.0)
	cost *= _shield_burden(d)
	if not braced:
		cost *= 1.5
	if parry:
		cost *= 0.5
	var shield_spec: Dictionary = Tracks.kit(str(d.kit)).shield
	var frame := shield_world(d)
	var local := Geo.to_local(frame[0], 0.0, c.point)
	var boss := Vector2(local.dot(frame[1]), local.dot(frame[2])).length() <= 0.09 * float(d.scale)
	var event := base.duplicate()
	event.type = "parry" if parry else "block"
	event.braced = braced
	event.surface_material = "bronze" if boss and str(shield_spec.material).contains("bronze") else ("iron" if boss else "wood")
	event.stamina_cost = snappedf(cost, 0.01)
	event.hitstop_frames = hitstop_frames(energy, true)
	_hold(f, int(event.hitstop_frames), push)
	f.weapon_wear = minf(1.0, float(f.weapon_wear) + float(Damage.Formula.balance().wear.weapon_per_hit.shield))
	d.shield_integrity = maxf(0.0, float(d.shield_integrity) - energy / 1500.0)
	event.shield_integrity = snappedf(float(d.shield_integrity), 0.0001)
	if float(d.stamina) + 0.000001 < cost:
		d.stamina = 0.0
		event.type = "guard_broken"
		events.append(event)
		_set_reaction(state, d, "guard_broken", push, events)
		_morale(state, d, -4.0, "guard_broken", events)
		return
	_spend(d, cost)
	d.stats.blocks = int(d.stats.blocks) + 1
	events.append(event)
	if float(d.shield_integrity) <= 0.0:
		events.append({"type":"shield_broken", "frame":state.frame, "fighter":d.id, "point":c.point})
	if parry:
		d.stats.parries = int(d.stats.parries) + 1
		_set_reaction(state, f, "parried", -push, events)
		_morale(state, d, 4.0, "parry", events)
		_morale(state, f, -3.0, "parried", events)
	else:
		_morale(state, d, 1.0, "block", events)
		if not braced:
			_set_reaction(state, d, "flinch", push, events)


## Impact pause and rebound of a striker who is still in the strike.
static func _hold(f: Dictionary, frames: int, push: Vector3) -> void:
	if f.action == "attack":
		f.hitstop = frames
		f.recoil = [-push.x, -push.z]


static func hitstop_frames(energy: float, on_shield: bool) -> int:
	var level := clampf(log(1.0 + maxf(0.0, energy)) / log(1.0 + HITSTOP_FULL_J), 0.0, 1.0)
	return roundi(lerpf(float(HITSTOP_RANGE[0]), float(HITSTOP_RANGE[1]), level)) + (HITSTOP_BLOCK_EXTRA if on_shield else 0)


static func _zone(d: Dictionary, point: Vector3) -> String:
	var kit := Tracks.kit(str(d.kit))
	var s := float(d.scale)
	var local := Geo.to_local(_origin(d), float(d.yaw), point)
	if point.y >= float(kit.head_low) * s:
		return "head"
	if point.y < float(kit.hip) * s:
		return "leg"
	if absf(local.x) > float(d.radius) * 0.6 and point.y <= float(kit.shoulder_y) * s + 0.05:
		return "arm_weapon" if local.x > 0.0 else "arm_shield"
	return "torso"


## Heavier shield arm work: a wounded shield arm, missiles stuck in the board.
static func _shield_burden(d: Dictionary) -> float:
	var burden := 1.0 + 0.5 * float(d.get("shield_fouled", 0))
	for injury: Dictionary in d.injuries:
		if injury.kind == "shield_arm_wound":
			burden *= 1.4
	return burden


## Poise of a defender against an impact (mass, stance, state), J.
static func _poise(d: Dictionary) -> float:
	var poise := float(d.mass) * POISE_PER_KG
	if d.action == "attack":
		poise *= 0.8
		if Weapons.one_legged(str(Tracks.move(str(d.kit), str(d.move)).get("family", ""))):
			poise *= 0.6
	elif d.action == "guard":
		poise *= 1.2
	poise *= 1.0 - 0.3 * float(d.fatigue)
	if _leg_factor(d) < 1.0:
		poise *= 0.7
	return poise


static func _reaction_of(d: Dictionary, ratio: float) -> String:
	if float(d.health) <= 0.0 or ratio >= 2.2:
		return "down"
	if ratio >= 1.2:
		return "stumble"
	if ratio >= 0.5:
		return "stagger"
	if ratio >= 0.15:
		return "flinch"
	return "absorbed"


## Book a body hit: the shared D-042 formula at this contact, health, wear,
## reaction, morale and injury. `source` describes the striker at the moment
## that counts (the attacker now, or the shooter at release).
static func _book_hit(state: Dictionary, d: Dictionary, source: Dictionary, zone: String, energy: float, reference: float, push: Vector3, event: Dictionary, events: Array) -> Dictionary:
	var result := Damage.compute({"weapon_id":source.weapon_id, "strike_kind":source.strike_kind, "weapon_quality":source.weapon_quality,
		"weapon_wear":source.weapon_wear, "skill":source.skill, "stamina":source.stamina, "injuries":source.injuries,
		"zone":zone, "defender_skill":float(d.skill), "armor_pieces":d.armor_pieces, "ranged":bool(source.get("ranged", false)),
		"impact":sqrt(energy / maxf(0.01, reference)), "contact_frame":int(event.get("clip_frame", -1))})
	var damage := float(result.damage)
	if (d.armor_pieces as Dictionary).has(zone):
		d.armor_pieces[zone].wear = minf(1.0, float(d.armor_pieces[zone].get("wear", 0.0)) + float(result.wear.armor))
	d.health = maxf(0.0, float(d.health) - damage)
	d.stats.taken = int(d.stats.taken) + 1
	event.zone = zone
	event.strike_kind = str(result.terms.get("strike", source.strike_kind))
	event.damage = int(damage)
	event.damage_terms = result.terms
	event.surface_material = Damage.surface_material(d.armor_pieces, str(d.armor), zone)
	event.health_after = snappedf(float(d.health), 0.01)
	var ratio := energy / maxf(1.0, _poise(d))
	event.impulse_ratio = snappedf(ratio, 0.001)
	event.reaction = _reaction_of(d, ratio)
	events.append(event)
	_morale(state, d, -(damage * 0.5 + 2.0), "took_hit", events)
	_injury(state, d, zone, damage, events)
	if event.reaction != "absorbed":
		_set_reaction(state, d, str(event.reaction), push, events, zone)
	return result


static func _resolve_hit(state: Dictionary, f: Dictionary, d: Dictionary, m: Dictionary, energy: float, push: Vector3, c: Dictionary, base: Dictionary, events: Array) -> void:
	var family := str(m.family)
	var reference := 0.5 * Weapons.effective_mass(family) * pow(float(f.scale), 3.0) * pow(float(m.window_top_speed) * float(f.scale), 2.0)
	var event := base.duplicate()
	event.type = "hit"
	event.hitstop_frames = hitstop_frames(energy, false)
	_hold(f, int(event.hitstop_frames), push)
	f.stats.hits = int(f.stats.hits) + 1
	# This frame is the measured contact; the one per-hit formula (D-042).
	var result := _book_hit(state, d, {"weapon_id":family, "strike_kind":str(base.strike_kind), "weapon_quality":int(f.weapon_quality),
		"weapon_wear":float(f.weapon_wear), "skill":float(f.skill), "stamina":float(f.stamina), "injuries":f.injuries},
		_zone(d, c.point), energy, reference, push, event, events)
	f.weapon_wear = minf(1.0, float(f.weapon_wear) + float(result.wear.weapon))
	_morale(state, f, 3.0, "landed_hit", events)


static func _injury(state: Dictionary, d: Dictionary, zone: String, damage: float, events: Array) -> void:
	var chance := clampf((damage - 5.0) / 25.0, 0.0, 0.8) * (1.2 if zone == "head" else 1.0)
	if _roll(state, "injury:%s:%d" % [d.id, int(state.frame)]) >= chance:
		return
	var kind: String = {"head":"concussion", "torso":"bleeding", "arm_weapon":"arm_wound", "arm_shield":"shield_arm_wound", "leg":"leg_wound"}[zone]
	var severity := clampf(damage / 30.0, 0.1, 1.0)
	d.injuries.append({"kind":kind, "zone":zone, "severity":snappedf(severity, 0.001), "frame":state.frame})
	match kind:
		"concussion":
			d.concussion = minf(0.3, float(d.concussion) + 0.15 * severity + 0.05)
		"bleeding":
			d.bleed = float(d.bleed) + 0.4 * severity
	events.append({"type":"injury", "frame":state.frame, "fighter":d.id, "kind":kind, "zone":zone, "severity":snappedf(severity, 0.001)})
	_morale(state, d, -8.0, "injury", events)


static func _set_reaction(state: Dictionary, d: Dictionary, kind: String, push: Vector3, events: Array, zone: String = "torso") -> void:
	var spec: Dictionary = REACTIONS[kind]
	var interrupted: bool = d.action == "attack" and not bool(d.resolved)
	if interrupted:
		d.stats.interrupted = int(d.stats.interrupted) + 1
		events.append({"type":"interrupted", "frame":state.frame, "fighter":d.id, "move":d.move, "clip_frame":int(d.last_frame)})
	var step := Vector3(push.x, 0.0, push.z).normalized() * float(spec.step) * _leg_factor(d)
	d.action = "down" if kind == "down" else "react"
	d.move = ""
	d.t = 0.0
	d.last_frame = -1
	d.resolved = true
	d.hitstop = 0
	d.recoil = []
	d.guard_style = ""
	d.dodge = ""
	if not (d.get("ranged", {}) as Dictionary).is_empty():
		events.append({"type":"interrupted", "frame":state.frame, "fighter":d.id, "weapon":d.ranged.weapon, "phase":d.ranged.phase})
		d.ranged = {}
	d.react = {"kind":kind, "t":0.0, "duration":float(spec.duration), "strength":float(spec.strength),
		"step":[step.x, step.z], "push":[push.x, push.z], "direction":Geo.side_of(float(d.yaw), -push), "zone":zone}
	events.append({"type":"reaction", "frame":state.frame, "fighter":d.id, "kind":kind, "direction":d.react.direction,
		"duration":float(spec.duration), "step_m":snappedf(step.length(), 0.001)})


static func _morale(state: Dictionary, f: Dictionary, delta: float, reason: String, events: Array) -> void:
	var before := str(f.morale_state)
	f.morale = clampf(float(f.morale) + delta, 0.0, 100.0)
	var now := "steady"
	if float(f.morale) < MORALE_BREAKING:
		now = "breaking"
	elif float(f.morale) < MORALE_WAVERING:
		now = "wavering"
	if now != before:
		f.morale_state = now
		events.append({"type":"morale", "frame":state.frame, "fighter":f.id, "state":now, "morale":snappedf(float(f.morale), 0.01), "reason":reason})


static func _roll(state: Dictionary, tag: String) -> float:
	state.rng = int(state.rng) + 1
	return Geo.unit_random("%d:%d:%s" % [int(state.seed), int(state.rng), tag])


## Yaw that points `move`'s own line (the bearing of its tip at the measured
## peak; cuts and the spear arrive off the body's centre line) at the target.
static func aim_yaw(state: Dictionary, id: String, target_id: String, move_id: String) -> float:
	var f := fighter(state, id)
	var t := fighter(state, target_id)
	var timing := Tracks.timing(str(f.get("kit", "")), move_id)
	if f.is_empty() or t.is_empty() or timing.is_empty():
		return float(f.get("yaw", 0.0))
	var d := Vector2(float(t.x) - float(f.x), float(t.z) - float(f.z))
	if d.length_squared() < 0.000001:
		return float(f.yaw)
	var tip: Vector3 = Tracks.segment(str(f.kit), move_id, int(timing.peak))[1]
	# Facing yaw turns forward (-Z) to (-sin, -cos); a tip that arrives to the
	# right of forward needs the body turned left by its bearing.
	return wrapf(atan2(-d.x, -d.y) + atan2(tip.x, -tip.z), -PI, PI)


## What `move` would meet if `id` struck now and nobody moved: {"kind":
## "body"|"shield"|"none", "defender", "clip_frame"}. Reads only; the AI uses
## it to see an opening before committing.
static func preview_strike(state: Dictionary, id: String, move_id: String, yaw: float = NAN) -> Dictionary:
	var f := fighter(state, id)
	if f.is_empty() or not Tracks.has_move(str(f.kit), move_id):
		return {"kind":"none", "defender":"", "clip_frame":-1}
	var probe := {"id":f.id, "kit":f.kit, "team":f.team, "x":f.x, "z":f.z, "yaw":f.yaw if is_nan(yaw) else yaw, "scale":f.scale, "height":f.height, "move":move_id}
	var timing := Tracks.timing(str(f.kit), move_id)
	for g in range(maxi(1, int(timing.start)), int(timing.end) + 1):
		var contact := _sweep(state, probe, g, Callable())
		if not contact.is_empty():
			return {"kind":contact.kind, "defender":contact.defender, "clip_frame":g}
	return {"kind":"none", "defender":"", "clip_frame":-1}


## Phase of an attacking fighter, from the measured window.
static func phase(f: Dictionary) -> String:
	if f.action != "attack":
		return str(f.action)
	var timing := Tracks.timing(str(f.kit), str(f.move))
	var frame := Tracks.frame_of(float(f.t))
	if frame < int(timing.start):
		return "windup"
	if frame <= int(timing.end):
		return "active"
	return "recovery"


## Nominal centre-to-centre distance at which `move` touches a defender of
## `defender_radius` at the animation peak (for AI spacing and level B).
static func nominal_reach(kit_id: String, move_id: String, defender_radius: float, scale: float = 1.0) -> float:
	var timing := Tracks.timing(kit_id, move_id)
	if timing.is_empty():
		return 0.0
	return float(timing.reach) * scale + defender_radius


## Level-B convenience: run one strike in a private state and return its
## first contact or whiff event (with clip frame, outcome, damage, reaction).
## `bearing_deg` is where the attacker stands relative to the defender's
## facing (0 = in front, +90 = on its weapon/right side). Deterministic.
static func simulate_strike(attacker_kit: String, move: String, defender_kit: String, distance: float, bearing_deg: float = 0.0, guard: String = "", seed: int = 1, defender_options: Dictionary = {}, attacker_options: Dictionary = {}) -> Dictionary:
	var state := new_state(seed)
	state.silent = true
	var bearing := deg_to_rad(bearing_deg)
	if not add_fighter(state, "defender", defender_kit, defender_options.merged({"team":"defender"}, true)).is_empty():
		return {}
	if not add_fighter(state, "attacker", attacker_kit, attacker_options.merged({"team":"attacker", "x":sin(bearing) * distance, "z":-cos(bearing) * distance}, true)).is_empty():
		return {}
	# Aim the strike's own bearing (measured at its peak) at the defender.
	var timing := Tracks.timing(attacker_kit, move)
	if timing.is_empty():
		return {}
	state.fighters.attacker.yaw = aim_yaw(state, "attacker", "defender", move)
	if not guard.is_empty():
		command(state, "defender", "guard", {"style":guard})
		step(state, 0.5)
	if not command(state, "attacker", "attack", {"move":move}).ok:
		return {}
	for i in int(timing.frames) + 2:
		for e: Dictionary in step(state, DT):
			if e.type in ["hit", "block", "parry", "guard_broken", "whiff"] and e.get("attacker", "attacker") == "attacker":
				return e
	return {}


# --- Missiles (thrown, bow, crossbow, sling) --------------------------------

static func _aim_args(state: Dictionary, args: Dictionary) -> Dictionary:
	if args.has("target"):
		return {"target":str(args.target)} if state.fighters.has(str(args.target)) else {}
	if args.has("yaw") and is_finite(float(args.yaw)) and is_finite(float(args.get("pitch", 0.0))):
		return {"yaw":float(args.yaw), "pitch":clampf(float(args.get("pitch", 0.0)), -1.4, 1.4)}
	return {}


static func _ranged_command(state: Dictionary, f: Dictionary, action: String, args: Dictionary) -> Dictionary:
	var r: Dictionary = f.get("ranged", {})
	match action:
		"draw":
			var weapon_id := str(args.get("weapon", ""))
			if not Weapons.is_ranged(weapon_id) or not (f.ammo as Dictionary).has(weapon_id):
				return {"ok":false, "message":"Diese Fernwaffe wird nicht geführt."}
			if int(f.ammo[weapon_id]) <= 0:
				return {"ok":false, "message":"Keine Geschosse mehr."}
			var cost := Weapons.stamina_cost(weapon_id)
			if float(f.stamina) + 0.000001 < cost:
				return {"ok":false, "message":"Zu erschöpft für diesen Schuss."}
			_spend(f, cost)
			f.action = "ranged"
			f.guard_style = ""
			f.ranged = {"weapon":weapon_id, "phase":"draw", "frame":0, "held":0, "aim":_aim_args(state, args), "event":"draw"}
			return {"ok":true, "message":weapon_id}
		"loose":
			if f.action != "ranged" or not str(r.get("phase", "")) in ["draw", "hold"]:
				return {"ok":false, "message":"Keine gespannte Fernwaffe."}
			var aim := _aim_args(state, args)
			if aim.is_empty():
				return {"ok":false, "message":"Kein gültiges Ziel."}
			r.aim = aim
			if r.phase == "hold":
				r.phase = "release"
				r.frame = 0
			return {"ok":true, "message":"loose"}
		"lower":
			if f.action == "ranged" and str(r.get("phase", "")) in ["draw", "hold"]:
				f.action = "idle"
				f.ranged = {}
			return {"ok":true, "message":"idle"}
	return {"ok":false, "message":"Unbekannter Kampfbefehl."}


## World point the missile leaves from (the weapon's release point).
static func release_point(f: Dictionary, weapon_id: String) -> Vector3:
	var p: Array = Weapons.weapon(weapon_id).release_point
	return Geo.to_world(_origin(f), float(f.yaw), float(f.scale), Vector3(float(p[0]), float(p[1]), float(p[2])))


static func _ranged_tick(state: Dictionary, f: Dictionary, events: Array) -> void:
	var r: Dictionary = f.ranged
	var weapon_id := str(r.weapon)
	var w := Weapons.weapon(weapon_id)
	var timing := Weapons.ranged_timing(weapon_id)
	if r.get("event", "") == "draw":
		# First frame of the draw: string, arm or sling starts to load.
		r.erase("event")
		events.append({"type":"draw", "frame":state.frame, "attacker":f.id, "weapon":weapon_id, "weapon_class":str(w.class),
			"energy_j":snappedf(Ranged.launch_energy(weapon_id), 0.01), "point":release_point(f, weapon_id)})
	match str(r.phase):
		"draw":
			r.frame = int(r.frame) + 1
			if int(r.frame) >= int(timing.draw):
				r.phase = "hold" if (r.aim as Dictionary).is_empty() else "release"
				r.frame = 0
		"hold":
			r.held = int(r.held) + 1
			f.stamina = maxf(0.0, float(f.stamina) - float(w.hold_stamina_per_s) * DT)
			if int(r.held) > int(timing.hold_max) or float(f.stamina) <= 0.0:
				events.append({"type":"lowered", "frame":state.frame, "fighter":f.id, "weapon":weapon_id})
				f.action = "idle"
				f.ranged = {}
		"release":
			r.frame = int(r.frame) + 1
			if int(r.frame) >= int(timing.release):
				_release(state, f, events)
				r.phase = "recover"
				r.frame = 0
		"recover":
			r.frame = int(r.frame) + 1
			if int(r.frame) >= int(timing.recover):
				f.action = "idle"
				f.ranged = {}
				events.append({"type":"recovered", "frame":state.frame, "fighter":f.id})


## The missile leaves the hand or string on exactly this frame.
static func _release(state: Dictionary, f: Dictionary, events: Array) -> void:
	var r: Dictionary = f.ranged
	var weapon_id := str(r.weapon)
	var aim: Dictionary = r.aim
	var target := fighter(state, str(aim.get("target", "")))
	if not target.is_empty():
		# Turn to the target, then aim from the actual release point.
		face(state, str(f.id), str(target.id))
		aim = Ranged.aim(weapon_id, release_point(f, weapon_id), _origin(target) + Vector3(0.0, float(target.height) * 0.62, 0.0))
	var error := Ranged.spread(weapon_id, float(f.skill), float(f.fatigue), float(r.held) * DT)
	var yaw := float(aim.yaw) + (_roll(state, "aim_yaw:" + str(f.id)) * 2.0 - 1.0) * error
	var pitch := float(aim.pitch) + (_roll(state, "aim_pitch:" + str(f.id)) * 2.0 - 1.0) * error
	f.yaw = wrapf(float(aim.yaw), -PI, PI)
	var origin := release_point(f, weapon_id)
	var speed := Ranged.launch_speed(weapon_id)
	var velocity := Ranged.direction(yaw, pitch) * speed
	f.ammo[weapon_id] = int(f.ammo[weapon_id]) - 1
	state.next_projectile = int(state.get("next_projectile", 0)) + 1
	if not state.has("projectiles"):
		state.projectiles = []
	state.projectiles.append({"id":int(state.next_projectile), "weapon":weapon_id, "owner":f.id, "team":f.team, "age":0, "born":int(state.frame),
		"p":[origin.x, origin.y, origin.z], "v":[velocity.x, velocity.y, velocity.z],
		"skill":float(f.skill), "stamina":float(f.stamina), "injuries":Damage.injury_kinds(f.injuries),
		"weapon_quality":int(f.weapon_quality)})
	events.append({"type":"release", "frame":state.frame, "attacker":f.id, "weapon":weapon_id, "weapon_class":Weapons.weapon_class(weapon_id),
		"projectile":int(state.next_projectile), "energy_j":snappedf(Ranged.launch_energy(weapon_id), 0.01), "speed_m_s":speed,
		"point":origin, "direction_vector":velocity.normalized(), "ammo_left":int(f.ammo[weapon_id]),
		"target":str(target.get("id", ""))})


static func _vec(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## Advance every missile one frame and sweep its path (<= 3 cm substeps)
## against shields, bodies, the world and the ground. Nothing is booked
## before the missile's path actually reaches the surface.
static func _fly(state: Dictionary, events: Array, world_clear: Callable) -> void:
	var flying: Array = []
	for p: Dictionary in state.get("projectiles", []):
		if int(p.born) == int(state.frame):
			# Released this frame: it is at the release point now and flies from the next frame.
			flying.append(p)
			continue
		p.age = int(p.age) + 1
		var weapon_id := str(p.weapon)
		var prev := _vec(p.p)
		var next := Ranged.advance(weapon_id, prev, _vec(p.v), DT)
		var cur: Vector3 = next[0]
		var velocity: Vector3 = next[1]
		if _missile_contact(state, p, prev, cur, velocity, events, world_clear) or int(p.age) >= Ranged.MAX_FLIGHT_FRAMES:
			continue
		p.p = [cur.x, cur.y, cur.z]
		p.v = [velocity.x, velocity.y, velocity.z]
		flying.append(p)
	state.projectiles = flying


static func _missile_event(state: Dictionary, p: Dictionary, type: String, point: Vector3, velocity: Vector3) -> Dictionary:
	var weapon_id := str(p.weapon)
	return {"type":type, "frame":state.frame, "clip_frame":-1, "attacker":p.owner, "weapon":weapon_id, "projectile":int(p.id),
		"weapon_class":Weapons.weapon_class(weapon_id), "weapon_material":Weapons.impact_material(weapon_id),
		"energy_j":snappedf(Ranged.energy(weapon_id, velocity), 0.01), "speed_m_s":snappedf(velocity.length(), 0.001),
		"point":point, "direction_vector":velocity.normalized(), "flight_frames":int(p.age)}


static func _missile_contact(state: Dictionary, p: Dictionary, prev: Vector3, cur: Vector3, velocity: Vector3, events: Array, world_clear: Callable) -> bool:
	var weapon_id := str(p.weapon)
	var spec: Dictionary = Weapons.weapon(weapon_id).projectile
	var radius := float(spec.radius_m)
	var steps := clampi(int(ceil((cur - prev).length() / SUBSTEP_METRES)), 1, 64)
	var targets: Array = []
	for id: String in _ids(state):
		var d: Dictionary = state.fighters[id]
		if d.id == p.owner or not bool(d.alive) or d.action == "down":
			continue
		# Only fighters the path can reach this frame.
		var reach := (cur - prev).length() + float(d.radius) + 1.2 * float(d.scale)
		if Vector2(float(d.x) - prev.x, float(d.z) - prev.z).length() > reach:
			continue
		var shield := shield_world(d)
		targets.append([d, Geo.body_axis(_origin(d), float(d.radius), float(d.height)), shield, shield_half(d) if not shield.is_empty() else Vector3.ZERO])
	for k in range(1, steps + 1):
		var a := prev.lerp(cur, float(k - 1) / float(steps))
		var b := prev.lerp(cur, float(k) / float(steps))
		for entry: Array in targets:
			var d: Dictionary = entry[0]
			var shield: Array = entry[2]
			if not shield.is_empty():
				var along := Geo.segment_box(a, b, shield[0], shield[1], shield[2], entry[3], radius)
				if along >= 0.0:
					_missile_block(state, p, d, a.lerp(b, along), velocity, events)
					return true
			var closest := Geo.segment_segment(a, b, entry[1][0], entry[1][1])
			if float(closest[2]) <= radius + float(d.radius):
				var on_path: Vector3 = a.lerp(b, float(closest[0]))
				var on_axis: Vector3 = (entry[1][0] as Vector3).lerp(entry[1][1], float(closest[1]))
				var outward := on_path - on_axis
				var point := on_axis + (outward.normalized() if outward.length() > 0.0001 else -velocity.normalized()) * float(d.radius)
				_missile_hit(state, p, d, point, velocity, events)
				return true
		if b.y <= 0.0:
			var t := clampf(a.y / maxf(0.000001, a.y - b.y), 0.0, 1.0)
			var miss := _missile_event(state, p, "projectile_miss", a.lerp(b, t), velocity)
			miss.surface_material = "soil"
			events.append(miss)
			return true
	if world_clear.is_valid():
		var clear: Variant = world_clear.call(prev, cur)
		if not (typeof(clear) == TYPE_BOOL and clear):
			var stopped := _missile_event(state, p, "projectile_miss", prev, velocity)
			stopped.surface_material = "world"
			events.append(stopped)
			return true
	return false


static func _missile_block(state: Dictionary, p: Dictionary, d: Dictionary, point: Vector3, velocity: Vector3, events: Array) -> void:
	var weapon_id := str(p.weapon)
	var spec: Dictionary = Weapons.weapon(weapon_id).projectile
	var energy := Ranged.energy(weapon_id, velocity)
	var braced: bool = d.action == "guard"
	var cost := clampf(energy * 0.10, 3.0, 40.0) * _shield_burden(d) * (1.0 if braced else 1.5)
	var shield_spec: Dictionary = Tracks.kit(str(d.kit)).shield
	var frame := shield_world(d)
	var local := Geo.to_local(frame[0], 0.0, point)
	var boss := Vector2(local.dot(frame[1]), local.dot(frame[2])).length() <= 0.09 * float(d.scale)
	var event := _missile_event(state, p, "projectile_block", point, velocity)
	event.defender = d.id
	event.braced = braced
	event.surface_material = "bronze" if boss and str(shield_spec.material).contains("bronze") else ("iron" if boss else "wood")
	# A missile sticks in the board, not in the metal boss; a sling bullet never does.
	event.lodged = bool(spec.lodges_in_shield) and not boss
	event.stamina_cost = snappedf(minf(cost, float(d.stamina)), 0.01)
	_spend(d, minf(cost, float(d.stamina)))
	d.shield_integrity = maxf(0.0, float(d.shield_integrity) - energy / 1500.0)
	event.shield_integrity = snappedf(float(d.shield_integrity), 0.0001)
	if bool(event.lodged) and bool(spec.bends):
		# A bent shank cannot be pulled out in the fight; it drags on the shield.
		d.shield_fouled = int(d.get("shield_fouled", 0)) + 1
	event.shield_fouled = int(d.get("shield_fouled", 0))
	d.stats.blocks = int(d.stats.blocks) + 1
	events.append(event)
	if float(d.shield_integrity) <= 0.0:
		events.append({"type":"shield_broken", "frame":state.frame, "fighter":d.id, "point":point})
	_morale(state, d, 1.0, "block", events)
	if not braced:
		_set_reaction(state, d, "flinch", Vector3(velocity.x, 0.0, velocity.z).normalized(), events)


static func _missile_hit(state: Dictionary, p: Dictionary, d: Dictionary, point: Vector3, velocity: Vector3, events: Array) -> void:
	var weapon_id := str(p.weapon)
	var energy := Ranged.energy(weapon_id, velocity)
	var push := Vector3(velocity.x, 0.0, velocity.z).normalized()
	var event := _missile_event(state, p, "projectile_hit", point, velocity)
	event.defender = d.id
	event.direction = Geo.side_of(float(d.yaw), -push)
	var owner := fighter(state, str(p.owner))
	if not owner.is_empty():
		owner.stats.hits = int(owner.stats.hits) + 1
	# The shooter's condition at release counts; the missile's remaining
	# energy relative to its launch energy is the contact factor.
	_book_hit(state, d, {"weapon_id":weapon_id, "strike_kind":"", "weapon_quality":int(p.weapon_quality), "weapon_wear":0.0,
		"skill":float(p.skill), "stamina":float(p.stamina), "injuries":p.injuries, "ranged":true},
		_zone(d, point), energy, Ranged.launch_energy(weapon_id), push, event, events)
	if not owner.is_empty():
		_morale(state, owner, 3.0, "landed_hit", events)
