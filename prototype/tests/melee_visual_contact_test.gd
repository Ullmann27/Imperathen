extends SceneTree
## D-026 on the rendered rigs: the melee core drives real VillagePerson /
## Meshy actors through the presenter; every frame the test measures the
## weapon actually posed on screen (prop mesh / skinned fist) and checks that
## damage and blocks are booked exactly when that rendered geometry reaches
## the body or the rendered shield - never before - and that hit-stop holds.

const Core = preload("res://scripts/domain/melee/melee_core.gd")
const Tracks = preload("res://scripts/domain/melee/melee_tracks.gd")
const Geo = preload("res://scripts/domain/melee/melee_geometry.gd")
const Probe = preload("res://tests/melee_rig_probe.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const Presenter = preload("res://scripts/visuals/melee_presenter.gd")
const Pose = preload("res://scripts/visuals/melee_pose.gd")
const TOLERANCE := 0.012
var checks := 0
var failures: Array[String] = []
var _done := false
var _actors := {}


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_actors.legionary = _legionary()
	_actors.axe_fighter = _axe_fighter()
	_actors.youth_unarmed = _youth()
	_scenario("legionary thrust -> axe fighter (no shield)", "legionary", "thrust", "axe_fighter", false, "", 0.0, "hit")
	_scenario("axe overhead -> legionary (no shield)", "axe_fighter", "axe_overhead", "legionary", false, "", 0.0, "hit")
	_scenario("legionary cut_inward -> axe fighter (no shield)", "legionary", "cut_inward", "axe_fighter", false, "", 0.0, "hit")
	_scenario("axe overhead -> legionary guard_high", "axe_fighter", "axe_overhead", "legionary", true, "guard_high", 0.0, "block")
	_scenario("legionary thrust -> axe fighter guard_front", "legionary", "thrust", "axe_fighter", true, "guard_front", 0.0, "block")
	_scenario("legionary thrust -> axe fighter side (guard_front)", "legionary", "thrust", "axe_fighter", true, "guard_front", 90.0, "hit")
	_scenario("youth jab_right -> legionary (no shield)", "youth_unarmed", "jab_right", "legionary", false, "", 0.0, "hit")
	_footwork("legionary", "idle")
	_footwork("axe_fighter", "guard")
	_approach_then_strike()
	_reaction_zones()
	for failure in failures:
		printerr("FAIL: " + failure)
	print("MELEE_VISUAL_CONTACT_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("MELEE_VISUAL_CONTACT_PASS" if failures.is_empty() else "MELEE_VISUAL_CONTACT_FAIL")
	quit(0 if failures.is_empty() else 1)
	return true


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Root moved 1.8 m at 1.2 m/s while idle/guarding: planted feet must not
## slide (<= 15 mm per support phase), must walk the distance and settle.
func _footwork(kit: String, mode: String) -> void:
	var actor: Dictionary = _actors[kit]
	var p: Node3D = actor.node
	var state := Core.new_state(3)
	Core.add_fighter(state, "f", kit, {"team":"f"})
	var presenter := Presenter.new()
	presenter.bind_person(p, kit, "f")
	if mode == "guard":
		Core.command(state, "f", "guard", {"style":"guard_front"})
	var skeleton := Probe.skeleton_of(p.body)
	var anchors := {}
	var start := {}
	var worst := 0.0
	var steps := 0
	var floor_y := INF
	for frame in 150:
		if frame < 90:
			Core.place(state, "f", 0.0, -1.2 * (frame + 1) / 60.0, 0.0)
		Core.step(state, 1.0 / 60.0)
		presenter.apply(state)
		for side: String in ["L", "R"]:
			var foot: Vector3 = p.global_transform * Probe.bone_in(p, skeleton, "Foot_" + side).origin
			if frame == 0:
				start[side] = foot
				floor_y = minf(floor_y, foot.y)
			var planted := foot.y <= floor_y + 0.01
			if planted:
				if not anchors.has(side):
					anchors[side] = foot
				worst = maxf(worst, Vector2(foot.x - anchors[side].x, foot.z - anchors[side].z).length())
			elif anchors.has(side):
				anchors.erase(side)
				steps += 1
	var root := Vector3(float(state.fighters.f.x), 0.0, float(state.fighters.f.z))
	var settled := 0.0
	var natural := presenter.pose.stance_feet()
	for side: String in ["L", "R"]:
		var foot: Vector3 = p.global_transform * Probe.bone_in(p, skeleton, "Foot_" + side).origin
		var n: Vector3 = natural[side.to_lower()]
		var target := root + Vector3(n.x, 0.0, -n.z)
		settled = maxf(settled, Vector2(foot.x - target.x, foot.z - target.z).length())
		_check(start[side].z - foot.z > 1.5, "%s %s: the %s foot walks with the body (%.2f m)" % [kit, mode, side, start[side].z - foot.z])
	_check(worst <= 0.015, "%s %s: planted feet slide %.4f m (motion-gate limit 0.015)" % [kit, mode, worst])
	_check(settled <= 0.10, "%s %s: feet settle at the stance after stopping (%.3f m)" % [kit, mode, settled])
	_check(steps >= 6, "%s %s: the approach is walked in real steps (%d)" % [kit, mode, steps])
	print("footwork %s %s: max planted slip %.4f m, steps %d, settle error %.3f m" % [kit, mode, worst, steps, settled])


## Walk in with footwork, then thrust: the feet must not jump when the strike
## starts and the rendered blade must stay on the measured track.
func _approach_then_strike() -> void:
	var actor: Dictionary = _actors.legionary
	var p: Node3D = actor.node
	var state := Core.new_state(4)
	Core.add_fighter(state, "f", "legionary", {"team":"f"})
	var presenter := Presenter.new()
	presenter.bind_person(p, "legionary", "f")
	var skeleton := Probe.skeleton_of(p.body)
	for frame in 75:
		if frame < 60:
			Core.place(state, "f", 0.0, -1.2 * (frame + 1) / 60.0, 0.0)
		Core.step(state, 1.0 / 60.0)
		presenter.apply(state)
	var feet_before := {}
	for side: String in ["L", "R"]:
		feet_before[side] = p.global_transform * Probe.bone_in(p, skeleton, "Foot_" + side).origin
	Core.command(state, "f", "attack", {"move":"thrust"})
	var timing := Tracks.timing("legionary", "thrust")
	var worst_track := 0.0
	var jump := 0.0
	for frame in int(timing.frames) - 1:
		Core.step(state, 1.0 / 60.0)
		presenter.apply(state)
		if frame == 0:
			for side: String in ["L", "R"]:
				var foot: Vector3 = p.global_transform * Probe.bone_in(p, skeleton, "Foot_" + side).origin
				jump = maxf(jump, Vector2(foot.x - feet_before[side].x, foot.z - feet_before[side].z).length())
		var f: Dictionary = state.fighters.f
		if f.action != "attack":
			break
		var rendered := _rendered_strike(actor)
		var measured := Core.strike_world(f, Tracks.frame_of(float(f.t)))
		worst_track = maxf(worst_track, maxf((rendered[0] as Vector3).distance_to(measured[0]), (rendered[1] as Vector3).distance_to(measured[1])))
	_check(jump <= 0.01, "Feet do not jump when a strike starts after footwork (%.4f m)" % jump)
	_check(worst_track <= 0.01, "After footwork the rendered blade stays on the measured track (%.4f m)" % worst_track)
	print("approach then thrust: foot jump %.4f m, max blade deviation from track %.4f m" % [jump, worst_track])


## Individual reactions: the same push produces different bodies per zone.
func _reaction_zones() -> void:
	var p: Node3D = _actors.legionary.node
	var pose := Pose.new()
	pose.bind(p.body, "legionary")
	var skeleton := Probe.skeleton_of(p.body)
	pose.stance_pose()
	var head_basis0: Basis = Probe.bone_in(p, skeleton, "Head").basis.orthonormalized()
	var pelvis0: Vector3 = Probe.bone_in(p, skeleton, "Pelvis").origin
	var shoulder := {}
	var result := {}
	for zone: String in ["head", "torso", "leg", "arm_weapon", "arm_shield"]:
		pose.reaction(Vector3(0, 0, -1), 0.75, 0.15, 0.5, Vector3.ZERO, zone)
		var head_basis: Basis = Probe.bone_in(p, skeleton, "Head").basis.orthonormalized()
		var snap := rad_to_deg((head_basis0.inverse() * head_basis).get_rotation_quaternion().get_angle())
		var pelvis: Vector3 = Probe.bone_in(p, skeleton, "Pelvis").origin
		var arm_r: Vector3 = Probe.bone_in(p, skeleton, "Arm_R").origin
		result[zone] = {"head_snap_deg":snap, "pelvis_drop":pelvis0.y - pelvis.y}
		shoulder[zone] = arm_r.z
	for zone: String in ["torso", "leg", "arm_weapon", "arm_shield"]:
		_check(float(result.head.head_snap_deg) > float(result[zone].head_snap_deg), "A head hit snaps the head more than a %s hit (%.1f vs %.1f deg)" % [zone, result.head.head_snap_deg, result[zone].head_snap_deg])
	_check(float(result.leg.pelvis_drop) > float(result.torso.pelvis_drop) + 0.03, "A leg hit buckles the knees (pelvis drop %.3f vs %.3f m)" % [result.leg.pelvis_drop, result.torso.pelvis_drop])
	_check(absf(float(shoulder.arm_weapon) - float(shoulder.arm_shield)) > 0.03, "Weapon- and shield-arm hits twist the shoulders differently (%.3f m)" % absf(float(shoulder.arm_weapon) - float(shoulder.arm_shield)))
	print("reaction zones: " + JSON.stringify(result))


func _attachment(root: Node, prefix: String) -> BoneAttachment3D:
	for a: Node in root.find_children("*", "BoneAttachment3D", true, false):
		if String(a.name).begins_with(prefix):
			return a as BoneAttachment3D
	return null


func _legionary() -> Dictionary:
	var p := Person.new()
	get_root().add_child(p)
	p.configure("player", "italia", 18)
	p.set_service_gear(true)
	p.sample_service_combat("thrust", 0.0)
	var sword := _attachment(p.body, "ServiceGladius")
	var shield := _attachment(p.body, "ServiceScutum")
	var sprop := sword.get_child(0).get_child(0).get_child(0) as Node3D
	var shprop := shield.get_child(0).get_child(0).get_child(0) as Node3D
	return {"node":p, "strike":Probe.prop_blade(sprop), "strike_attach":sword, "strike_prop":sprop,
		"shield_attach":shield, "shield_prop":shprop, "shield_box":Probe.prop_box(shprop)}


func _axe_fighter() -> Dictionary:
	var p := Person.new()
	get_root().add_child(p)
	p.configure("enemy", "germania", 30)
	p.configure_meshy("unit_germanic_axe_fighter")
	p.sample_armed_pose("cut_inward", 0.0)
	var axe := _attachment(p.body, "MeshyEquipment_weap")
	var shield := _attachment(p.body, "MeshyEquipment_gear")
	var aprop := axe.get_child(0).get_child(0) as Node3D
	var shprop := shield.get_child(0).get_child(0) as Node3D
	var disc := Probe.prop_box(shprop)
	return {"node":p, "strike":Probe.prop_axe(aprop), "strike_attach":axe, "strike_prop":aprop,
		"shield_attach":shield, "shield_prop":shprop, "shield_box":disc, "disc":true}


func _youth() -> Dictionary:
	var p := Person.new()
	get_root().add_child(p)
	p.configure("player", "italia", 12)
	return {"node":p, "strike":Probe.skin_strike(p.body, "Hand_R", Vector3.ZERO, "HandGrip"), "bone":"Hand_R"}


func _rendered_strike(actor: Dictionary) -> Array:
	var p: Node3D = actor.node
	var skeleton := Probe.skeleton_of(p.body)
	var xf: Transform3D
	if actor.has("bone"):
		xf = p.global_transform * Probe.bone_in(p, skeleton, actor.bone)
	else:
		xf = p.global_transform * Probe.prop_in(p, skeleton, actor.strike_attach, actor.strike_prop)
	# Global transform -> ground frame: the actor root stands 0.9 m up.
	var base: Vector3 = xf * (actor.strike.base as Vector3)
	var tip: Vector3 = xf * (actor.strike.tip as Vector3)
	return [base, tip]


func _rendered_shield(actor: Dictionary) -> Array:
	var p: Node3D = actor.node
	var skeleton := Probe.skeleton_of(p.body)
	var xf: Transform3D = p.global_transform * Probe.prop_in(p, skeleton, actor.shield_attach, actor.shield_prop)
	var c: Vector3 = actor.shield_box.center
	var center := xf * c
	return [center, (xf * (c + Vector3.RIGHT) - center).normalized(), (xf * (c + Vector3.UP) - center).normalized(), actor.shield_box.half]


func _scenario(label: String, attacker_kit: String, move: String, defender_kit: String, shield: bool, guard: String, bearing_deg: float, expect: String) -> void:
	var a: Dictionary = _actors[attacker_kit]
	var d: Dictionary = _actors[defender_kit]
	for actor: Dictionary in [a, d]:
		(actor.node as Node3D).visible = true
	var timing := Tracks.timing(attacker_kit, move)
	var body := Tracks.kit(defender_kit)
	var tip: Vector3 = Tracks.segment(attacker_kit, move, int(timing.peak))[1]
	var flat := Vector2(tip.x, tip.z)
	var distance := flat.length() + float(timing.radius) + float(body.radius) - 0.02
	var state := Core.new_state(17)
	Core.add_fighter(state, "a", attacker_kit, {"team":"a"})
	# Defender on the strike's own bearing, rotated so the attack arrives
	# from `bearing_deg` relative to its facing (+ = its weapon side).
	var spot := flat.normalized() * distance
	Core.add_fighter(state, "d", defender_kit, {"team":"d", "x":spot.x, "z":spot.y})
	Core.face(state, "d", "a")
	state.fighters.d.yaw = float(state.fighters.d.yaw) + deg_to_rad(bearing_deg)
	state.fighters.d.has_shield = shield
	var pa := Presenter.new()
	var pd := Presenter.new()
	_check(pa.bind_person(a.node, attacker_kit, "a") and pd.bind_person(d.node, defender_kit, "d"), label + ": presenters bind to the real rigs")
	if not guard.is_empty():
		Core.command(state, "d", "guard", {"style":guard})
		Core.step(state, 0.5)
	Core.command(state, "a", "attack", {"move":move})
	var radius := float(timing.radius) * float(state.fighters.a.scale)
	var event := {}
	var previous: Array = []
	var held := -1
	for frame in int(timing.frames) + 20:
		var events := Core.step(state, 1.0 / 60.0)
		pa.apply(state)
		pd.apply(state)
		var rendered := _rendered_strike(a)
		var axis := Geo.body_axis(Vector3(float(state.fighters.d.x), 0.0, float(state.fighters.d.z)), float(state.fighters.d.radius), float(state.fighters.d.height))
		var gap := float(Geo.segment_segment(rendered[0], rendered[1], axis[0], axis[1])[2]) - radius - float(state.fighters.d.radius)
		var shield_entry := -1.0
		if shield:
			var box := _rendered_shield(d)
			var half: Vector3 = box[3]
			if d.get("disc", false):
				half = Vector3(half.x * 0.8862 / 1.0, half.y * 0.8862, half.z)
			shield_entry = Geo.segment_box(rendered[0], rendered[1], box[0], box[1], box[2], half, radius + TOLERANCE)
		for e: Dictionary in events:
			if e.type in ["hit", "block", "parry", "whiff", "guard_broken"] and e.get("attacker", "a") == "a":
				event = e
		if event.is_empty():
			# Nothing booked yet: the rendered weapon must not be inside the body.
			_check(gap > -TOLERANCE, "%s: frame %d rendered weapon penetrates the body by %.3f m before any contact event" % [label, frame + 1, -gap])
		else:
			if held < 0:
				held = frame
				if event.type == "hit":
					_check(gap <= TOLERANCE, "%s: on the hit frame the rendered weapon touches the body (gap %.3f m)" % [label, gap])
				elif event.type in ["block", "parry"]:
					_check(shield_entry >= 0.0, "%s: on the block frame the rendered weapon touches the rendered shield" % label)
				print("%s -> %s on clip frame %d (rendered gap %.4f m, shield entry %.3f)" % [label, event.type, int(event.get("clip_frame", -1)), gap, shield_entry])
			elif frame - held <= int(event.hitstop_frames) - 1 and not previous.is_empty():
				var still := maxf(rendered[0].distance_to(previous[0]), rendered[1].distance_to(previous[1]))
				_check(still < 0.002, "%s: hit-stop holds the rendered weapon on frame %d (moved %.4f m)" % [label, frame - held, still])
		previous = rendered
		if not event.is_empty() and frame - held > 8:
			break
	_check(event.get("type", "") == expect, "%s: expected %s, got %s" % [label, expect, event.get("type", "-")])
