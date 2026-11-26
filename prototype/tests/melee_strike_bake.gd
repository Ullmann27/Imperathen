extends SceneTree
## Measures every level-A strike, guard and shield pose on the actual rigs at
## 60 Hz and derives contact data from the displayed geometry.
##   --write   regenerate res://scripts/domain/melee/melee_track_data.gd
##   (default) re-measure and fail if the committed data drifted
## Derivation rules (documented in the generated header):
##  * strike primitive: capsule segment base->tip with radius, all measured
##    from skin vertices (bind pose + hand-grip morph) or the attached prop mesh
##  * peak frame: first frame within 5 mm of the maximum forward tip reach
##  * live window: contiguous frames around the peak; before the peak the tip
##    must advance (de/dt >= -0.2 m/s) at >= 20 % of the move's top speed or be
##    within 3 cm of peak reach; after the peak it must stay within 3 cm of peak
##    reach or keep sweeping (speed >= 20 %, radial speed >= -0.3 m/s); always
##    in front of the attacker's own torso radius.

const Probe = preload("res://tests/melee_rig_probe.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const Pose = preload("res://scripts/visuals/melee_pose.gd")
const Combat = preload("res://scripts/domain/combat_actions.gd")
const OUT := "res://scripts/domain/melee/melee_track_data.gd"
const FPS := 60.0
const LIVE_SPEED_FRACTION := 0.20
const PEAK_BAND := 0.03
const PEAK_ONSET := 0.005
const ROUND := 10000.0
const AXE_MOVES := {"axe_overhead":1.0, "axe_cut_inward":0.9, "axe_cut_outward":0.9}
const SPEAR_MOVES := {"spear_thrust":0.95}
const GUARD_FRAMES := 12

var _done := false
var _write := false
var _write_path := OUT
var _kits := {}
var _moves := {}
var _guards := {}
var _findings := {}
var _log: Array[String] = []


func _initialize() -> void:
	_write = "--write" in OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			_write_path = arg.trim_prefix("--output=")


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_bake_youth()
	_bake_legionary()
	_bake_axe_fighter()
	_bake_spearman()
	_bake_raider()
	_legacy_findings()
	var text := _render()
	if _write:
		var file := FileAccess.open(_write_path, FileAccess.WRITE)
		if file == null:
			printerr("Cannot write measured strike table: " + _write_path)
			quit(1)
			return true
		file.store_string(text)
		file.close()
		for line in _log:
			print(line)
		print("MELEE_TRACKS_WRITTEN moves=%d guards=%d" % [_moves.size(), _guards.size()])
		quit(0)
		return true
	var failures := _compare()
	for line in _log:
		print(line)
	for failure in failures:
		printerr("FAIL: " + failure)
	print("MELEE_TRACKS_RESULT moves=%d guards=%d failures=%d" % [_moves.size(), _guards.size(), failures.size()])
	print("MELEE_TRACKS_PASS" if failures.is_empty() else "MELEE_TRACKS_FAIL")
	quit(0 if failures.is_empty() else 1)
	return true


# --- rigs ---------------------------------------------------------------

func _hero(years: int, gear: bool) -> Node3D:
	var p := Person.new()
	get_root().add_child(p)
	p.configure("player", "italia", years)
	p.set_service_gear(gear)
	return p


func _attachment(root: Node, prefix: String) -> BoneAttachment3D:
	for a: Node in root.find_children("*", "BoneAttachment3D", true, false):
		if String(a.name).begins_with(prefix):
			return a as BoneAttachment3D
	return null


func _actor_point(actor: Node3D, ground: float, xf: Transform3D, local: Vector3) -> Vector3:
	# Actor-local Godot frame (+X right, -Z forward), origin moved to the ground.
	var p := xf * local
	return Vector3(p.x, p.y + ground, p.z)


func _body(actor: Node3D, model: Node3D, ground: float, mass: float, extra: Dictionary) -> Dictionary:
	var skeleton := Probe.skeleton_of(model)
	var mesh := Probe.body_mesh(model)
	var to_actor := Probe.relative(skeleton, actor)
	var torso := PackedVector3Array()
	# Torso surface from every visible skinned layer (the hero's chest is the
	# tunic mesh, not the body skin underneath).
	for layer: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if layer.skin == null or not layer.is_visible_in_tree():
			continue
		for bone: String in ["Spine", "Pelvis"]:
			var rest := skeleton.get_bone_global_rest(skeleton.find_bone(bone))
			for v in Probe.bone_vertices(layer, skeleton, bone):
				torso.append(_actor_point(actor, ground, to_actor * rest, v))
	var c := Probe.centroid(torso)
	var radii: Array[float] = []
	for p in torso:
		radii.append(Vector2(p.x - c.x, p.z - c.z).length())
	radii.sort()
	var head_rest := skeleton.get_bone_global_rest(skeleton.find_bone("Head"))
	var top := -INF
	var head_low := INF
	for v in Probe.bone_vertices(mesh, skeleton, "Head"):
		var p := _actor_point(actor, ground, to_actor * head_rest, v)
		top = maxf(top, p.y)
		head_low = minf(head_low, p.y)
	var hip := _actor_point(actor, ground, to_actor * skeleton.get_bone_global_rest(skeleton.find_bone("Thigh_L")), Vector3.ZERO).y
	var shoulder := _actor_point(actor, ground, to_actor * skeleton.get_bone_global_rest(skeleton.find_bone("Arm_L")), Vector3.ZERO)
	var result := {"radius":_r(radii[int(radii.size() * 0.95)]), "height":_r(top), "head_low":_r(head_low), "hip":_r(hip),
		"shoulder_y":_r(shoulder.y), "shoulder_half_width":_r(absf(shoulder.x)), "mass_kg":mass}
	result.merge(extra, true)
	return result


# --- kits ---------------------------------------------------------------

func _bake_youth() -> void:
	var p := _hero(12, false)
	var skeleton := Probe.skeleton_of(p.body)
	var head_axis := skeleton.get_bone_global_rest(skeleton.find_bone("Head")).basis.inverse() * Vector3(0, 0, 1)
	var strikes := {
		"fist_l":Probe.skin_strike(p.body, "Hand_L", Vector3.ZERO, "HandGrip"),
		"fist_r":Probe.skin_strike(p.body, "Hand_R", Vector3.ZERO, "HandGrip"),
		"foot_r":Probe.skin_strike(p.body, "Foot_R", Vector3.ZERO),
		"head":Probe.skin_strike(p.body, "Head", head_axis)}
	_kits.youth_unarmed = _body(p, p.body, 0.9, 40.0, {"rig":"hero_quality (age 12, body scale 1.0)", "armor":"linen", "shield":"", "weapon":"fist",
		"adult_scale":1.14})
	for id: String in Combat.TECHNIQUES:
		if Combat.is_armed(id):
			continue
		var key := "fist_l" if id.ends_with("left") else "fist_r"
		if id.ends_with("kick"):
			key = "foot_r"
		elif id == "headbutt":
			key = "head"
		var strike: Dictionary = strikes[key]
		var duration := float(Combat.TECHNIQUES[id].duration)
		var family := "fist" if key.begins_with("fist") else ("foot" if key == "foot_r" else "head")
		_measure("youth_unarmed", id, duration, family, float(strike.radius), p, 0.9,
			func(t: float): p.sample_combat(id, t / duration),
			func() -> Array:
				var xf := Probe.bone_in(p, skeleton, strike.bone)
				return [_actor_point(p, 0.9, xf, strike.base), _actor_point(p, 0.9, xf, strike.tip)],
			Callable(), skeleton)
	# Adult unarmed is the same pose on the 1.14 body; verify the scale claim.
	var adult := _hero(18, false)
	var askel := Probe.skeleton_of(adult.body)
	var fist: Dictionary = strikes.fist_r
	var worst := 0.0
	for f in 38:
		var t := f / FPS
		p.sample_combat("jab_right", t / 0.68)
		adult.sample_combat("jab_right", t / 0.68)
		var young := _actor_point(p, 0.9, Probe.bone_in(p, skeleton, "Hand_R"), fist.tip)
		var grown := _actor_point(adult, 0.9, Probe.bone_in(adult, askel, "Hand_R"), fist.tip * 1.0)
		worst = maxf(worst, (young * 1.14).distance_to(grown))
	_kits.youth_unarmed.adult_scale_error_m = _r(worst)
	_log.append("youth adult-scale check: max |1.14*youth - adult| fist tip = %.4f m" % worst)
	adult.queue_free()
	p.queue_free()


func _bake_legionary() -> void:
	var p := _hero(18, true)
	p.sample_service_combat("thrust", 0.0)
	var pose := Pose.new()
	pose.bind(p.body, "legionary")
	var skeleton := Probe.skeleton_of(p.body)
	var sword := _attachment(p.body, "ServiceGladius")
	var shield := _attachment(p.body, "ServiceScutum")
	var sword_prop := sword.get_child(0).get_child(0).get_child(0) as Node3D
	var shield_prop := shield.get_child(0).get_child(0).get_child(0) as Node3D
	var blade := Probe.prop_blade(sword_prop)
	var scutum := Probe.prop_box(shield_prop)
	# Scutum: width X, height Y, curved depth Z (boss outward on +Z).
	var shield_spec := {"shape":"box", "half":[_r(scutum.half.x), _r(scutum.half.y), _r(scutum.half.z)], "material":"wood_leather_bronze_boss", "mass_kg":7.0}
	_kits.legionary = _body(p, p.body, 0.9, 68.0, {"rig":"hero_quality (age 18, body scale 1.14) + service gladius/scutum", "armor":"mail", "weapon":"gladius",
		"weapon_mass_kg":1.0, "blade_length":_r(blade.blade_length), "shield":shield_spec})
	var shield_fn := func() -> Array:
		var xf := Probe.prop_in(p, skeleton, shield, shield_prop)
		return _frame_of(p, 0.9, xf, scutum.center)
	for id: String in ["thrust", "cut_inward", "cut_outward", "overhead", "turn_cut"]:
		var duration := float(Combat.TECHNIQUES[id].duration)
		_measure("legionary", id, duration, "gladius", float(blade.radius), p, 0.9,
			func(t: float): pose.strike(id, t / duration),
			func() -> Array:
				var xf := Probe.prop_in(p, skeleton, sword, sword_prop)
				return [_actor_point(p, 0.9, xf, blade.base), _actor_point(p, 0.9, xf, blade.tip)],
			shield_fn, skeleton)
	for style: String in Pose.GUARDS:
		_measure_guard("legionary", style, func(t: float): pose.guard(style, t), shield_fn)
	_measure_stance("legionary", func(): pose.stance_pose(), shield_fn)
	_log.append("gladius blade %.3f m (guard top %.3f, tip %.3f), half-width %.3f; scutum half %s" % [blade.blade_length, blade.base.y, blade.tip.y, blade.radius, str(scutum.half)])
	p.queue_free()


func _bake_axe_fighter() -> void:
	var p := Person.new()
	get_root().add_child(p)
	p.configure("enemy", "germania", 30)
	if not p.configure_meshy("unit_germanic_axe_fighter"):
		_log.append("axe fighter unavailable")
		return
	p.sample_armed_pose("cut_inward", 0.0)
	var pose := Pose.new()
	pose.bind(p.body, "axe_fighter")
	var skeleton := Probe.skeleton_of(p.body)
	var axe := _attachment(p.body, "MeshyEquipment_weap")
	var shield := _attachment(p.body, "MeshyEquipment_gear")
	var axe_prop := axe.get_child(0).get_child(0) as Node3D
	var shield_prop := shield.get_child(0).get_child(0) as Node3D
	var head := Probe.prop_axe(axe_prop)
	var disc := Probe.prop_box(shield_prop)
	var shield_spec := {"shape":"disc", "radius":_r(maxf(disc.half.x, disc.half.y)), "half_thickness":_r(disc.half.z), "material":"wood_iron_boss", "mass_kg":3.5}
	_kits.axe_fighter = _body(p, p.body, 0.9, 76.0, {"rig":"Meshy unit_germanic_axe_fighter (axe + round shield: rare reconstructed variant)", "armor":"wool_leather", "weapon":"axe",
		"weapon_mass_kg":0.9, "axe_head_height":_r(head.head_height), "shield":shield_spec})
	var shield_fn := func() -> Array:
		return _frame_of(p, 0.9, Probe.prop_in(p, skeleton, shield, shield_prop), disc.center)
	for id: String in AXE_MOVES:
		var duration := float(AXE_MOVES[id])
		_measure("axe_fighter", id, duration, "axe", float(head.radius), p, 0.9,
			func(t: float): pose.strike(id, t / duration),
			func() -> Array:
				var xf := Probe.prop_in(p, skeleton, axe, axe_prop)
				return [_actor_point(p, 0.9, xf, head.base), _actor_point(p, 0.9, xf, head.tip)],
			shield_fn, skeleton)
	for style: String in Pose.GUARDS:
		_measure_guard("axe_fighter", style, func(t: float): pose.guard(style, t), shield_fn)
	_measure_stance("axe_fighter", func(): pose.stance_pose(), shield_fn)
	_log.append("axe head %.3f..%.3f m on the haft, swept radius %.3f; round shield %s" % [head.base.y, head.tip.y, head.radius, str(disc.half)])
	p.queue_free()


func _bake_spearman() -> void:
	var actor := Node3D.new()
	get_root().add_child(actor)
	var model := (load("res://assets/soldiers/spear_near.glb") as PackedScene).instantiate() as Node3D
	model.rotation.y = PI
	actor.add_child(model)
	var skeleton := Probe.skeleton_of(model)
	var mesh := Probe.body_mesh(model)
	var hand := Probe.bone_vertices(mesh, skeleton, "Hand_R")
	var far := Vector3.ZERO
	for v in hand:
		if v.length() > far.length():
			far = v
	var axis := far.normalized()
	var spear_head := PackedVector3Array()
	for v in hand:
		if v.dot(axis) > far.length() - 0.30:
			spear_head.append(v)
	var lateral: Array[float] = []
	for v in spear_head:
		lateral.append((v - axis * v.dot(axis)).length())
	lateral.sort()
	var spear := {"base":axis * (far.length() - 0.30), "tip":far, "radius":lateral[int(lateral.size() * 0.9)], "length_from_hand":far.length()}
	var shield_verts := Probe.bone_vertices(mesh, skeleton, "Hand_L")
	var box := AABB(shield_verts[0], Vector3.ZERO)
	for v in shield_verts:
		box = box.expand(v)
	var pose := Pose.new()
	pose.bind(model, "spearman", axis)
	_kits.spearman = _body(actor, model, 0.0, 70.0, {"rig":"soldiers/spear_near.glb (battle rig, skinned spear and shield)", "armor":"mail", "weapon":"spear",
		"weapon_mass_kg":1.6, "spear_from_hand":_r(far.length()),
		"shield":{"shape":"box", "half":[_r(box.size.x * 0.5), _r(box.size.y * 0.5), _r(box.size.z * 0.5)], "material":"wood_leather", "mass_kg":4.0}})
	var shield_fn := func() -> Array:
		return _frame_of(actor, 0.0, Probe.bone_in(actor, skeleton, "Hand_L"), box.get_center())
	for id: String in SPEAR_MOVES:
		var duration := float(SPEAR_MOVES[id])
		_measure("spearman", id, duration, "spear", float(spear.radius), actor, 0.0,
			func(t: float): pose.strike(id, t / duration),
			func() -> Array:
				var xf := Probe.bone_in(actor, skeleton, "Hand_R")
				return [_actor_point(actor, 0.0, xf, spear.base), _actor_point(actor, 0.0, xf, spear.tip)],
			shield_fn, skeleton)
	for style: String in Pose.GUARDS:
		_measure_guard("spearman", style, func(t: float): pose.guard(style, t), shield_fn)
	_measure_stance("spearman", func(): pose.stance_pose(), shield_fn)
	_log.append("spear tip %.3f m from the hand, spearhead radius %.3f; Hand_L shield box %s" % [far.length(), spear.radius, str(box.size)])
	actor.queue_free()


## Body-only target: the village raid's raider (frontier spearman appearance).
func _bake_raider() -> void:
	var p := Person.new()
	get_root().add_child(p)
	p.configure("enemy", "germania", 28)
	p.configure_appearance("spearman", 0)
	_kits.raider = _body(p, p.body, 0.9, 70.0, {"rig":"frontier_spearman (village raid raider)", "armor":"wool_leather", "shield":"", "weapon":""})
	p.queue_free()


## Shield frame: centre plus width (u) and height (v) axes in fighter space.
func _frame_of(actor: Node3D, ground: float, xf: Transform3D, center: Vector3) -> Array:
	var c := _actor_point(actor, ground, xf, center)
	var u := _actor_point(actor, ground, xf, center + Vector3.RIGHT) - c
	var v := _actor_point(actor, ground, xf, center + Vector3.UP) - c
	return [c, u.normalized(), v.normalized()]


# --- measurement ----------------------------------------------------------

func _measure(kit: String, id: String, duration: float, family: String, radius: float, actor: Node3D, ground: float, sample: Callable, strike_fn: Callable, shield_fn: Callable, skeleton: Skeleton3D) -> void:
	var n := int(floor(duration * FPS + 0.000001))
	var bases: Array[Vector3] = []
	var tips: Array[Vector3] = []
	var shields: Array = []
	var feet := {"L":[], "R":[]}
	var pelvis: Array[Vector3] = []
	var hands: Array[Vector3] = []
	for f in n + 1:
		sample.call(f / FPS)
		hands.append(_actor_point(actor, ground, Probe.bone_in(actor, skeleton, "Hand_R" if family != "foot" and not id.ends_with("left") else ("Foot_R" if family == "foot" else "Hand_L")), Vector3.ZERO))
		var seg: Array = strike_fn.call()
		bases.append(seg[0])
		tips.append(seg[1])
		if shield_fn.is_valid():
			shields.append(shield_fn.call())
		for side: String in ["L", "R"]:
			feet[side].append(_actor_point(actor, ground, Probe.bone_in(actor, skeleton, "Foot_" + side), Vector3.ZERO))
		pelvis.append(_actor_point(actor, ground, Probe.bone_in(actor, skeleton, "Pelvis"), Vector3.ZERO))
	var own_radius := float(_kits[kit].radius)
	var e: Array[float] = []
	var speed: Array[float] = []
	var radial: Array[float] = []
	var top_speed := 0.0
	var turn := 0.0
	var bone_speed := 0.0
	for f in range(1, n + 1):
		bone_speed = maxf(bone_speed, hands[f].distance_to(hands[f - 1]) * FPS)
	for f in n + 1:
		if f > 0:
			var d0 := (tips[f - 1] - bases[f - 1]).normalized()
			var d1 := (tips[f] - bases[f]).normalized()
			turn = maxf(turn, rad_to_deg(acos(clampf(d0.dot(d1), -1.0, 1.0))) * FPS)
		e.append(-tips[f].z)
		speed.append(0.0 if f == 0 else tips[f].distance_to(tips[f - 1]) * FPS)
		radial.append(0.0 if f == 0 else (Vector2(tips[f].x, tips[f].z).length() - Vector2(tips[f - 1].x, tips[f - 1].z).length()) * FPS)
		top_speed = maxf(top_speed, speed[f])
	# Animation peak: the first frame whose forward reach is within 5 mm of the
	# maximum. Sweeping strikes plateau (a hook holds 0.359-0.361 m for five
	# frames); the strike visibly arrives at the plateau onset, not at the
	# last-millimetre argmax.
	var e_max := -INF
	for f in n + 1:
		e_max = maxf(e_max, e[f])
	var peak := 0
	while e[peak] < e_max - PEAK_ONSET:
		peak += 1
	var live := LIVE_SPEED_FRACTION * top_speed
	var start := peak
	while start > 1:
		var g := start - 1
		var advancing := (e[g] - e[g - 1]) * FPS >= -0.2
		if e[g] < own_radius or not ((advancing and speed[g] >= live) or e[peak] - e[g] <= PEAK_BAND):
			break
		start = g
	var finish := peak
	while finish < n:
		var g := finish + 1
		if e[g] < own_radius or not (e[peak] - e[g] <= PEAK_BAND or (speed[g] >= live and radial[g] >= -0.3)):
			break
		finish = g
	var reach := 0.0
	var arc_min := INF
	var arc_max := -INF
	var y_min := INF
	var y_max := -INF
	var window_speed := 0.0
	for f in range(start, finish + 1):
		reach = maxf(reach, Vector2(tips[f].x, tips[f].z).length())
		var angle := rad_to_deg(atan2(tips[f].x, -tips[f].z))
		arc_min = minf(arc_min, angle)
		arc_max = maxf(arc_max, angle)
		y_min = minf(y_min, minf(tips[f].y, bases[f].y))
		y_max = maxf(y_max, maxf(tips[f].y, bases[f].y))
		window_speed = maxf(window_speed, speed[f])
	var slip := _support_slip(feet)
	var shift := _weight(feet, pelvis, peak)
	var record := {"kit":kit, "family":family, "duration":duration, "frames":n + 1, "radius":_r(radius),
		"peak":peak, "start":start, "end":finish, "reach":_r(reach + radius), "peak_forward":_r(e[peak]),
		"arc_deg":[_r(arc_min), _r(arc_max)], "height":[_r(y_min), _r(y_max)],
		"top_speed":_r(top_speed), "peak_speed":_r(speed[peak]), "window_top_speed":_r(window_speed),
		"support_slip_m":_r(slip), "max_axis_turn_deg_s":_r(turn), "driving_bone_top_speed":_r(bone_speed), "pelvis_forward_at_peak":_r(shift.forward), "pelvis_outside_support_m":_r(shift.outside),
		"base":_flat(bases), "tip":_flat(tips)}
	if not shields.is_empty():
		record.shield = _flat_frames(shields)
	_moves[kit + "/" + id] = record
	_log.append("%-28s frames=%2d peak=%2d (%.3fs) live=%2d..%2d reach=%.3f fwd=%.3f arc=[%.0f,%.0f] y=[%.2f,%.2f] v_top=%.2f v_peak=%.2f bone=%.2f turn=%.0fdeg/s slip=%.4f pelvis_out=%.3f" % [kit + "/" + id, n + 1, peak, peak / FPS, start, finish, reach + radius, e[peak], arc_min, arc_max, y_min, y_max, top_speed, speed[peak], bone_speed, turn, slip, shift.outside])


func _measure_guard(kit: String, style: String, sample: Callable, shield_fn: Callable) -> void:
	var frames: Array = []
	for f in GUARD_FRAMES:
		sample.call(f / FPS)
		frames.append(shield_fn.call())
	_guards[kit + "/" + style] = {"frames":GUARD_FRAMES, "shield":_flat_frames(frames)}
	var last: Array = frames[GUARD_FRAMES - 1]
	var normal: Vector3 = (last[1] as Vector3).cross(last[2])
	_log.append("%-28s shield centre=%s normal=%s" % [kit + "/" + style, str(_rv(last[0])), str(_rv(normal))])


func _measure_stance(kit: String, sample: Callable, shield_fn: Callable) -> void:
	sample.call()
	_guards[kit + "/stance"] = {"frames":1, "shield":_flat_frames([shield_fn.call()])}


## Worst horizontal drift of a foot during each run of frames where it is
## within 1 cm of its lowest height (planted).
func _support_slip(feet: Dictionary) -> float:
	var worst := 0.0
	for side: String in ["L", "R"]:
		var track: Array = feet[side]
		var floor_y := INF
		for p: Vector3 in track:
			floor_y = minf(floor_y, p.y)
		var anchor := Vector3.INF
		for p: Vector3 in track:
			if p.y <= floor_y + 0.01:
				if anchor == Vector3.INF:
					anchor = p
				worst = maxf(worst, Vector2(p.x - anchor.x, p.z - anchor.z).length())
			else:
				anchor = Vector3.INF
	return worst


func _weight(feet: Dictionary, pelvis: Array[Vector3], peak: int) -> Dictionary:
	var outside := 0.0
	for f in pelvis.size():
		var a: Vector3 = feet.L[f]
		var b: Vector3 = feet.R[f]
		var p := Vector2(pelvis[f].x, pelvis[f].z)
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.z)
		var t := clampf((p - a2).dot(b2 - a2) / maxf(0.000001, (b2 - a2).length_squared()), 0.0, 1.0)
		# Feet are ~0.24 m long; the support region is the stance line
		# widened by half a foot length.
		outside = maxf(outside, maxf(0.0, p.distance_to(a2.lerp(b2, t)) - 0.12))
	return {"forward":pelvis[0].z - pelvis[peak].z, "outside":outside}


# --- legacy findings ------------------------------------------------------

func _legacy_findings() -> void:
	# The previously shipped armed presentation, measured the same way. Kept as
	# documented evidence only; level A no longer derives contact from it.
	var hero := _hero(18, true)
	var skeleton := Probe.skeleton_of(hero.body)
	var sword := _attachment(hero.body, "ServiceGladius")
	var prop := sword.get_child(0).get_child(0).get_child(0) as Node3D
	for id: String in ["thrust", "cut_inward", "overhead"]:
		var duration := float(Combat.TECHNIQUES[id].duration)
		var best := -INF
		var tip_y := 0.0
		for f in int(duration * FPS) + 1:
			hero.sample_service_combat(id, f / FPS / duration)
			var tip := _actor_point(hero, 0.9, Probe.prop_in(hero, skeleton, sword, prop), Vector3(0, 0.70, 0))
			if -tip.z > best:
				best = -tip.z
				tip_y = tip.y
		_findings["legacy_armed_pose/" + id] = {"peak_forward_tip":_r(best), "tip_height_at_peak":_r(tip_y)}
	hero.queue_free()
	var axe := Person.new()
	get_root().add_child(axe)
	axe.configure("enemy", "germania", 30)
	if axe.configure_meshy("unit_germanic_axe_fighter"):
		var askel := Probe.skeleton_of(axe.body)
		var att := _attachment(axe.body, "MeshyEquipment_weap")
		var aprop := att.get_child(0).get_child(0) as Node3D
		var best := -INF
		var jump := 0.0
		var prev := Vector3.ZERO
		for f in 49:
			axe.sample_armed_pose("overhead", f / 48.0)
			var tip := _actor_point(axe, 0.9, Probe.prop_in(axe, askel, att, aprop), Vector3(0, 0.44, 0))
			best = maxf(best, -tip.z)
			if f > 0:
				jump = maxf(jump, tip.distance_to(prev))
			prev = tip
		_findings["legacy_meshy_attack_clip/overhead"] = {"peak_forward_head":_r(best), "max_single_frame_jump_m":_r(jump)}
	axe.queue_free()
	# Battle spear rig: its own "attack" clip, played exactly as soldier_visual
	# does (model unrotated in the GLB; actor faces the model's +Z).
	var holder := Node3D.new()
	get_root().add_child(holder)
	var soldier := (load("res://assets/soldiers/spear_near.glb") as PackedScene).instantiate() as Node3D
	soldier.rotation.y = PI
	holder.add_child(soldier)
	var sskel := Probe.skeleton_of(soldier)
	var mesh := Probe.body_mesh(soldier)
	var far := Vector3.ZERO
	for v in Probe.bone_vertices(mesh, sskel, "Hand_R"):
		if v.length() > far.length():
			far = v
	var player := soldier.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play("attack")
	var ahead := -INF
	var behind := INF
	for f in int(player.current_animation_length * FPS) + 1:
		player.seek(f / FPS, true)
		player.advance(0)
		var tip := _actor_point(holder, 0.0, Probe.bone_in(holder, sskel, "Hand_R"), far)
		ahead = maxf(ahead, -tip.z)
		behind = minf(behind, -tip.z)
	_findings["legacy_soldier_spear_attack_clip"] = {"max_forward_tip":_r(ahead), "max_backward_tip":_r(-behind)}
	holder.queue_free()
	for key: String in _findings:
		_log.append("finding %-36s %s" % [key, JSON.stringify(_findings[key])])


# --- output ---------------------------------------------------------------

func _r(value: float) -> float:
	return roundf(value * ROUND) / ROUND


func _rv(v: Vector3) -> Vector3:
	return Vector3(_r(v.x), _r(v.y), _r(v.z))


func _flat(points: Array[Vector3]) -> Array:
	var out := []
	for p in points:
		out.append_array([_r(p.x), _r(p.y), _r(p.z)])
	return out


func _flat_frames(frames: Array) -> Array:
	var out := []
	for frame: Array in frames:
		for v: Vector3 in frame:
			out.append_array([_r(v.x), _r(v.y), _r(v.z)])
	return out


func _render() -> String:
	var lines: Array[String] = []
	lines.append("extends RefCounted")
	lines.append("## GENERATED by res://tests/melee_strike_bake.gd --write. Do not edit by hand.")
	lines.append("## Measured at 60 Hz from the displayed poses of the actual rigs and props.")
	lines.append("## Actor space (Godot): +X right, +Y up from the ground, -Z forward, metres.")
	lines.append("## Strike primitive per frame: capsule segment base->tip with `radius`.")
	lines.append("## peak = first frame within 5 mm of maximum forward tip reach; start..end = live window")
	lines.append("## (advancing >= 20 % of top speed or within 3 cm of peak reach before the")
	lines.append("## peak; within 3 cm or still sweeping after it; never inside the own torso).")
	lines.append("## Shield frames: centre, width axis u, height axis v (normal = u x v).")
	lines.append("")
	lines.append("const FPS := 60")
	lines.append("const KITS := " + _literal(_kits))
	lines.append("const MOVES := " + _literal(_moves))
	lines.append("const GUARDS := " + _literal(_guards))
	lines.append("const FINDINGS := " + _literal(_findings))
	return "\n".join(lines) + "\n"


func _literal(value: Variant) -> String:
	# Stable, sorted, compact literal so regeneration diffs stay readable.
	match typeof(value):
		TYPE_DICTIONARY:
			var keys: Array = (value as Dictionary).keys()
			keys.sort()
			var parts: Array[String] = []
			for key in keys:
				parts.append("\"%s\":%s" % [key, _literal(value[key])])
			return "{" + ", ".join(parts) + "}"
		TYPE_ARRAY:
			var parts: Array[String] = []
			for item in value:
				parts.append(_literal(item))
			return "[" + ",".join(parts) + "]"
		TYPE_STRING:
			return JSON.stringify(value)
		TYPE_FLOAT:
			var text := String.num(value, 4)
			return text if text.contains(".") or text.contains("e") else text + ".0"
		TYPE_VECTOR3:
			return "[%s,%s,%s]" % [_literal(_r(value.x)), _literal(_r(value.y)), _literal(_r(value.z))]
	return str(value)


func _compare() -> Array[String]:
	var failures: Array[String] = []
	if not ResourceLoader.exists(OUT):
		return ["Committed track data is missing: " + OUT]
	var data: GDScript = load(OUT)
	for key: String in _moves:
		if not data.MOVES.has(key):
			failures.append("Move missing from committed data: " + key)
			continue
		var fresh: Dictionary = _moves[key]
		var old: Dictionary = data.MOVES[key]
		for field: String in ["frames", "peak", "start", "end"]:
			if int(fresh[field]) != int(old[field]):
				failures.append("%s %s drifted: committed %s, measured %s" % [key, field, str(old[field]), str(fresh[field])])
		for field: String in ["base", "tip"]:
			var worst := 0.0
			for i in mini(fresh[field].size(), old[field].size()):
				worst = maxf(worst, absf(float(fresh[field][i]) - float(old[field][i])))
			if worst > 0.002 or fresh[field].size() != old[field].size():
				failures.append("%s %s geometry drifted by %.4f m" % [key, field, worst])
		if float(fresh.driving_bone_top_speed) > 12.0:
			failures.append("%s driving bone moves %.2f m/s (> 12 m/s motion-gate rig limit)" % [key, fresh.driving_bone_top_speed])
		if float(fresh.support_slip_m) > 0.015:
			failures.append("%s support foot slides %.4f m during the strike (> 0.015 m motion-gate limit)" % [key, fresh.support_slip_m])
	for key: String in data.MOVES:
		if not _moves.has(key):
			failures.append("Committed move no longer measured: " + key)
	for key: String in _guards:
		if not data.GUARDS.has(key):
			failures.append("Guard missing from committed data: " + key)
	if float(_kits.youth_unarmed.adult_scale_error_m) > 0.002:
		failures.append("Adult unarmed body is not a uniform 1.14 scale of the youth pose")
	return failures
