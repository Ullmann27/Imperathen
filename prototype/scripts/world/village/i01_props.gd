extends Node3D
## I-01 props: the three named family cups and the family jug. Presentation
## only – every position is derived from the saved I-01 state (shelf, hand,
## table) and never changes it. The jug follows the live wrist with a
## bounded procedural pickup/pour/setdown transition; saves settle directly.

const Objects := preload("res://scripts/story/mission_documents.gd")
const I01 = preload("res://scripts/story/i01_three_cups.gd")
const Art = preload("res://scripts/world/village_art.gd")
const WaterMotion := preload("res://scripts/world/village/i01_water_motion.gd")
const FLOOR := 0.3925
## Family home baker_home sits at (-13, 0, 11) with yaw 0; room-local offsets.
const ROOM := Vector3(-13.0, FLOOR, 11.0)
const SHELF_SLOTS := {"julia":Vector3(-2.32, 1.08, -0.27), "silvanus":Vector3(-2.32, 1.08, 0.03), "player":Vector3(-2.32, 1.08, 0.33)}
const SHELF_ORIGIN := Vector3(0.0, 0.0, 1.05)
## Silvanus stands at the table's east end so his way to the door stays open.
const TABLE_SLOTS := {"julia":Vector3(-1.35, 0.865, -0.98), "silvanus":Vector3(-0.50, 0.865, -0.50), "player":Vector3(-0.85, 0.865, -0.15)}
const JUG_TABLE := Vector3(-0.55, 0.865, -0.85)
const JUG_BENCH := Vector3(1.93, 0.515, 0.18)
const JUG_HAND := Vector3(0.0, -0.34, 0.06)
# Measured from water_pitcher.glb: handle is on +X; rim is 0.389 m high.
const JUG_GRIP := Vector3(.168,.28,0)
const JUG_SUPPORT := Vector3(-.085,.055,0)
const JUG_MOUTH := Vector3(0,.389,0)
const WELL_DURATION := 6.6
const POUR_DURATION := 6.6
const POUR_START := 0.45
const POUR_CUP_SPAN := 1.75
const HAND_CUPS := {"julia":Vector3(0.0, -0.02, 0.05), "silvanus":Vector3(0.0, 0.10, 0.05), "player":Vector3(0.0, 0.22, 0.05)}

var _cups: Dictionary = {}
var _water: Dictionary = {}
var _jug: Node3D
var _skeleton: Skeleton3D
var _right_bone := -1
var _left_bone := -1
var _right_rest := Basis.IDENTITY
var _left_rest := Basis.IDENTITY
var _figure_body: Node3D
var _bench_jug: Node3D
var _carrier: Node3D
var _held_cups: Array[String] = []
var _holding_jug := false
var _full_jug := false
var _family_carry := false
var _water_motion := WaterMotion.new()
var _solving_grip := false
var _film_pour := false
var _jug_mode := ""
var _jug_pending := ""
var _jug_action := ""
var _jug_clock := 0.0
var _jug_duration := .32
var _jug_from := Transform3D.IDENTITY
var _jug_goal := Transform3D.IDENTITY

func begin_jug_action(action: String) -> void:
	if action in ["i01_take_jug","i01_well","i01_park_jug","i01_pour","fill_water","father_morning","i07_water_fetch","i07_water_bring"]:
		_jug_pending = action

func jug_in_hand() -> bool:
	return visible and _holding_jug

func full_jug_carried() -> bool:
	return jug_in_hand() and _full_jug

func jug_animating() -> bool:
	return not _jug_action.is_empty()

func water_interaction_active() -> bool:
	return _jug_action in ["i01_well","i01_pour","i01_take_jug"]

func begin_film_pour() -> void:
	_film_pour = _jug_action == "i01_pour"

func sample_film_pour(seconds: float) -> void:
	if _film_pour and _jug_action == "i01_pour":
		_jug_clock = clampf(seconds,0.0,_jug_duration)
		_sample_water_action()

## World-space centre of the physical pour, shared with the film camera.
## Presentation only; use the same timeline and actual imported props.
func cinematic_pour_focus() -> Vector3:
	if not _film_pour or _jug_action != "i01_pour" or not is_instance_valid(_jug):
		return Vector3.INF
	var index := clampi(floori((_jug_clock - POUR_START) / POUR_CUP_SPAN), 0, I01.CUPS.size() - 1)
	var owner: String = I01.CUPS[index]
	var cup: Node3D = _cups.get(owner)
	if not is_instance_valid(cup):
		return Vector3.INF
	var mouth := _cup_mouth(owner)
	# Blend between actual receivers while the jug travels to the next cup.
	# During the active stream both endpoints are the same as the water FX.
	if index > 0:
		var local := clampf((_jug_clock - POUR_START - float(index) * POUR_CUP_SPAN) / POUR_CUP_SPAN, 0.0, 1.0)
		mouth = _cup_mouth(I01.CUPS[index - 1]).lerp(mouth, smoothstep(0.0, 0.25, local))
	var lip := _jug.to_global(JUG_MOUTH)
	return mouth.lerp(lip, 0.5) if mouth.is_finite() and lip.is_finite() else Vector3.INF


func settle_film_pour() -> void:
	if _film_pour and _jug_action == "i01_pour":
		_jug_clock = _jug_duration
		_sample_water_action()
	_film_pour = false



func _init() -> void:
	name = "I01FamilyProps"
	# Follow the hands after VillagePerson updates the skeleton for this frame.
	process_priority = 10
	set_process(false)


static func world_point(local: Vector3) -> Vector3:
	return ROOM + local


static func anchor(key: String) -> Vector3:
	match key:
		"i01_table": return world_point(Vector3(-1.1, 0.865, -0.61))
		"i01_shelf": return world_point(SHELF_ORIGIN + Vector3(-2.32, 1.08, 0.0))
		"i01_bed": return Vector3(I01.POINTS.home_bed.x, FLOOR, I01.POINTS.home_bed.y)
		"i01_well": return Vector3(I01.POINTS.well.x, 0.0, I01.POINTS.well.y)
		"i01_julia": return Vector3(I01.POINTS.julia_table.x, FLOOR, I01.POINTS.julia_table.y)
		"i01_silvanus": return Vector3(I01.POINTS.silvanus_table.x, FLOOR, I01.POINTS.silvanus_table.y)
		"i01_player_table": return Vector3(I01.POINTS.player_table.x, FLOOR, I01.POINTS.player_table.y)
	return Vector3.INF


func _build() -> void:
	if not _cups.is_empty():
		return
	var water := Art.material(Color("4f6a66"), .12)
	for owner: String in I01.CUPS:
		var scene := load(Objects.ENTRIES["cup_"+owner].model) as PackedScene
		var cup := scene.instantiate() as Node3D
		cup.name = "FamilyCup_" + owner
		cup.set_meta("i01_cup", owner)
		add_child(cup)
		_cups[owner] = cup
		var surface := MeshInstance3D.new()
		surface.name = "Water"
		var disc := CylinderMesh.new()
		disc.top_radius = .084
		disc.bottom_radius = .084
		disc.height = .006
		disc.radial_segments = 12
		surface.mesh = disc
		surface.material_override = water
		surface.position = Vector3(0.033 if owner == "player" else 0.0, .118, 0)
		cup.add_child(surface)
		_water[owner] = surface
	_jug = (load(Objects.ENTRIES.water_jug.model) as PackedScene).instantiate() as Node3D
	_jug.name = "FamilyJug"
	add_child(_jug)
	_water_motion.setup(self)


## Called from GameWorld.sync_state with the authoritative state.
func sync_state(state: Dictionary, figure: Node3D) -> void:
	_build()
	var prior := _jug.global_transform
	var prior_visible := _jug.visible
	var enabled: bool = state.get("village", {}).has("childhood")
	visible = enabled
	_find_bench_jug()
	_carrier = figure
	_held_cups.clear()
	_holding_jug = false
	_full_jug = false
	_family_carry = false
	if not enabled:
		_water_motion.finish()
		_film_pour = false
		_jug_action = ""
		_jug_pending = ""
		_jug_mode = ""
		_jug.hide()
		set_process(false)
		if is_instance_valid(_bench_jug):
			_bench_jug.visible = true
		return
	var view := I01.presentation(state)
	_full_jug = str(view.water) == "jug"
	_family_carry = str(view.water) in ["empty_jug","jug"]
	var cup_state: Dictionary = view.cups
	var filled: bool = str(view.water) in ["poured", "silvanus"] or str(view.status) == "legacy"
	for owner: String in I01.CUPS:
		var cup: Node3D = _cups[owner]
		var where := str(cup_state.get(owner, "shelf"))
		if where == "hand":
			_held_cups.append(owner)
		elif where == "table":
			_place(cup, world_point(TABLE_SLOTS[owner]), Basis(Vector3.UP, 0.35 * I01.CUPS.find(owner)))
		else:
			_place(cup, world_point(SHELF_ORIGIN + SHELF_SLOTS[owner]), Basis.IDENTITY)
		if _jug_action != "i01_pour" and _jug_pending != "i01_pour":
			_water[owner].visible = filled and where == "table"
			_water[owner].position.y = .118
	var next_mode := str(view.jug)
	# The same family vessel also supplies the later supervised gate watch.
	# Do not inject a second inventory item or keep the I-01 carry flag alive.
	var child: Dictionary = state.village.childhood
	var watch_water := str(child.screenplay.get("i07_water","locked"))
	if watch_water == "carry":
		next_mode = "hand"
	elif watch_water == "complete" and child.get("gear","") == "loaned":
		next_mode = "gate"
	if next_mode != _jug_mode and _jug_pending.is_empty():
		_jug_action = ""
		_water_motion.finish()
		_film_pour = false
	_jug_mode = next_mode
	_holding_jug = next_mode == "hand"
	if _holding_jug:
		_ensure_hands()
		if _left_bone >= 0:
			_jug_goal = _carry_transform()
	elif next_mode == "away":
		_jug_goal = prior
		if _jug_pending == "father_morning" and is_instance_valid(_carrier):
			_jug_goal.origin += -_carrier.global_basis.z.normalized()*.15
	elif next_mode == "gate":
		# Next to, rather than in the middle of, the authored gate route.
		_jug_goal = global_transform*Transform3D(Basis.IDENTITY,Vector3(1.0,.04,-46.0))
	else:
		var destination := JUG_TABLE if next_mode == "table" else JUG_BENCH
		_jug_goal = global_transform*Transform3D(Basis.IDENTITY,world_point(destination))
	if not _jug_pending.is_empty():
		_jug_action = _jug_pending
		_jug_pending = ""
		_jug_clock = 0.0
		_jug_duration = POUR_DURATION if _jug_action == "i01_pour" else WELL_DURATION if _jug_action == "i01_well" else .32
		_jug_from = prior
		if _holding_jug and (_jug_action == "i07_water_fetch" or not prior_visible or prior.origin.distance_to(_jug_goal.origin) > 1.25):
			# The well action starts locally, never flies from the family bench.
			_jug_from = _jug_goal
			_jug_from.origin.y -= .24
		if not _holding_jug and _jug_action != "i01_pour" and next_mode in ["table","gate"] and prior.origin.distance_to(_jug_goal.origin) > .85:
			# Interaction range exceeds arm reach: use a local tabletop
			# approach rather than stretching the model or flying a prop.
			_jug_from = _jug_goal
			_jug_from.origin.y += .18
		_jug.global_transform = _jug_from
		_jug.show()
		if _jug_action == "i01_pour":
			for owner: String in I01.CUPS:
				_set_water_level(owner,0.0)
	elif _jug_action.is_empty():
		_jug.global_transform = _jug_goal
		_jug.visible = next_mode != "away" and (not _holding_jug or _left_bone >= 0)
	else:
		_jug.global_transform = prior
		_jug.visible = prior_visible
	var carrying := not _held_cups.is_empty() or _holding_jug or jug_animating()
	set_process(carrying)
	if carrying:
		_sync_hands()
	# The original bench jug stands for the same object; never show two.
	if is_instance_valid(_bench_jug):
		_bench_jug.visible = false


func cup_location(owner: String) -> String:
	if not _cups.has(owner):
		return ""
	var cup: Node3D = _cups[owner]
	if owner in _held_cups:
		return "hand" if cup.visible and _right_bone >= 0 else "elsewhere"
	var at := cup.global_position
	for slot: String in ["table", "shelf"]:
		var expected: Vector3 = world_point(TABLE_SLOTS[owner]) if slot == "table" else world_point(SHELF_ORIGIN + SHELF_SLOTS[owner])
		if at.distance_to(expected) < 0.02:
			return slot
	return "elsewhere"


func cup_node(owner: String) -> Node3D:
	return _cups.get(owner)


func jug_node() -> Node3D:
	return _jug


func _place(item: Node3D, at: Vector3, basis: Basis) -> void:
	item.transform = Transform3D(basis, at)
	item.visible = true


func _process(delta: float) -> void:
	_sync_hands()
	if jug_animating():
		if not _film_pour:
			_jug_clock += maxf(delta,0.0)
		_sample_water_action()
	elif _family_carry and _holding_jug:
		_grip(_jug.global_transform,_full_jug)


func _sample_water_action() -> void:
	var t := clampf(_jug_clock/_jug_duration,0.0,1.0)
	match _jug_action:
		"i01_well": _sample_well(_jug_clock)
		"i01_pour": _sample_pour(_jug_clock)
		_:
			_jug.global_transform = _jug_from.interpolate_with(_jug_goal,smoothstep(0,1,t))
			if _jug_action == "i01_take_jug":
				_grip(_jug.global_transform,false)
	if t >= 1.0:
		if _jug_action == "i01_pour":
			for owner: String in I01.CUPS:
				_set_water_level(owner,1.0)
		_water_motion.finish()
		_jug_action = ""
		_film_pour = false
		_jug.global_transform = _jug_goal
		_jug.visible = _jug_mode != "away"
		set_process(_holding_jug or not _held_cups.is_empty())


func _set_water_level(owner: String, amount: float) -> void:
	var surface: MeshInstance3D = _water[owner]
	surface.visible = amount > .001
	surface.position.y = lerpf(.024,.118,clampf(amount,0,1))


func _carry_transform() -> Transform3D:
	if not _family_carry:
		return _hand_transform(_left_bone,_left_rest,JUG_HAND,1.0)
	var wrist := _skeleton.to_global(_skeleton.get_bone_global_pose(_left_bone).origin)
	var basis := _skeleton.global_basis.orthonormalized()
	# The mesh handle is +X; rotate it to the left side of the actual rig.
	if _skeleton.get_bone_global_rest(_left_bone).origin.x < 0.0:
		basis *= Basis(Vector3.UP,PI)
	return Transform3D(basis,wrist+basis*Vector3(0,0,.035)-basis*JUG_GRIP)


func _grip(pose: Transform3D, support: bool) -> void:
	if not is_instance_valid(_carrier) or not _carrier.has_method("apply_water_wrists"):
		return
	var palm := pose.basis*Vector3(0,0,.035)
	_wrists(pose*JUG_GRIP-palm,pose*JUG_SUPPORT-palm if support else Vector3.INF,pose.basis)


func _wrists(left: Vector3, right: Vector3, basis: Basis) -> void:
	if not is_instance_valid(_carrier) or not _carrier.has_method("apply_water_wrists"):
		return
	_solving_grip = true
	_carrier.apply_water_wrists(left,right,basis)
	_solving_grip = false


func _sample_well(seconds: float) -> void:
	if not _water_motion.bind_well():
		# Missing imported parts are a QA failure, not a fabricated replacement.
		_jug.global_transform = _jug_from.interpolate_with(_jug_goal,smoothstep(0,1,seconds/WELL_DURATION))
		set_meta("well_visual_bound",false)
		return
	set_meta("well_visual_bound",true)
	var well := _water_motion.well
	var center := well.global_position
	var outward := _carrier.global_position-center if is_instance_valid(_carrier) else Vector3.RIGHT
	outward.y = 0
	outward = outward.normalized() if outward.length()>.01 else Vector3.RIGHT
	var jar_at := center+outward*.85+Vector3.UP*1.05
	var jar_pose := Transform3D(Basis.IDENTITY,jar_at)
	var base := _water_motion.bucket_base()
	var raised := base
	raised.origin.y = center.y+1.08
	var lowered := base
	lowered.origin.y = center.y+.09
	var bucket := base
	var amount := 0.0
	var tilt := 0.0
	_water_motion.clear_stream()
	if seconds < .75:
		_jug.global_transform = _jug_from.interpolate_with(jar_pose,smoothstep(0,.75,seconds))
		_grip(_jug.global_transform,false)
		bucket = base.interpolate_with(lowered,smoothstep(0,.75,seconds))
	elif seconds < 3.15:
		_jug.global_transform = jar_pose
		var lift := smoothstep(.75,3.15,seconds)
		bucket = lowered.interpolate_with(raised,lift)
		amount = 1.0
		# Animate the existing windlass, not a fictitious rope in empty air.
		# Reach residual is retained for visual QA; long arms are never invented.
		var crank_contact := _water_motion.windlass(bucket.origin.y-lowered.origin.y)
		if crank_contact.is_finite():
			_wrists(Vector3.INF,crank_contact,Basis.IDENTITY)
	elif seconds < 5.35:
		_jug.global_transform = jar_pose
		var phase := (seconds-3.15)/2.2
		var rotate := smoothstep(.20,.42,phase)*(1.0-smoothstep(.70,.88,phase))
		tilt = rotate*1.05
		var facing := Basis(Vector3.UP,atan2(outward.x,outward.z))
		var basis := facing*Basis(Vector3.RIGHT,tilt)
		var lip := jar_pose*JUG_MOUTH+Vector3.UP*.15-outward*.04
		var aimed := Transform3D(basis,lip-basis*WaterMotion.BUCKET_LIP)
		var reach := smoothstep(0,.22,phase)*(1.0-smoothstep(.86,1,phase))
		bucket = raised.interpolate_with(aimed,reach)
		var flow := smoothstep(.42,.47,phase)*(1.0-smoothstep(.64,.70,phase))
		amount = 1.0-smoothstep(.43,.68,phase)
		_water_motion.water_between(bucket*WaterMotion.BUCKET_LIP,jar_pose*JUG_MOUTH,flow)
		_wrists(bucket*WaterMotion.BUCKET_HANDLE,bucket*Vector3(-.12,.17,0),bucket.basis)
	else:
		var retreat := smoothstep(5.35,WELL_DURATION,seconds)
		bucket = raised.interpolate_with(base,retreat)
		_jug.global_transform = jar_pose.interpolate_with(_jug_goal,retreat)
		_grip(_jug.global_transform,true)
	_water_motion.bucket_at(bucket,amount,tilt)


func _cup_mouth(owner: String) -> Vector3:
	var cup: Node3D = _cups[owner]
	return cup.to_global(Vector3(.033 if owner == "player" else 0.0,.147,0))


func _pour_pose(owner: String, tilt: float) -> Transform3D:
	var mouth := _cup_mouth(owner)
	var direction := mouth-_carrier.global_position if is_instance_valid(_carrier) else Vector3.FORWARD
	direction.y = 0.0
	direction = direction.normalized() if direction.length()>.01 else Vector3.FORWARD
	var basis := Basis(Vector3.UP,atan2(direction.x,direction.z))*Basis(Vector3.RIGHT,tilt*1.08)
	var lip := mouth+Vector3.UP*.21-direction*.055
	return Transform3D(basis,lip-basis*JUG_MOUTH)


func _sample_pour(seconds: float) -> void:
	_water_motion.clear_stream()
	var start := POUR_START
	var span := POUR_CUP_SPAN
	for i in I01.CUPS.size():
		var owner: String = I01.CUPS[i]
		var local := clampf((seconds-start-float(i)*span)/span,0,1)
		_set_water_level(owner,smoothstep(.48,.79,local))
	if seconds < start:
		_jug.global_transform = _jug_from.interpolate_with(_pour_pose(I01.CUPS[0],0),smoothstep(0,start,seconds))
	elif seconds < start+span*I01.CUPS.size():
		var index := mini(int((seconds-start)/span),I01.CUPS.size()-1)
		var owner: String = I01.CUPS[index]
		var phase := fposmod(seconds-start,span)/span
		var tilt := smoothstep(.25,.48,phase)*(1.0-smoothstep(.79,1,phase))
		var previous := _pour_pose(I01.CUPS[maxi(index-1,0)],0)
		var pose := previous.interpolate_with(_pour_pose(owner,tilt),smoothstep(0,.25,phase))
		_jug.global_transform = pose
		var flow := smoothstep(.48,.53,phase)*(1.0-smoothstep(.74,.79,phase))
		_water_motion.water_between(pose*JUG_MOUTH,_cup_mouth(owner),flow)
	else:
		var end_pose := _pour_pose(I01.CUPS[-1],0)
		_jug.global_transform = end_pose.interpolate_with(_jug_goal,smoothstep(start+span*I01.CUPS.size(),POUR_DURATION,seconds))
	_grip(_jug.global_transform,true)


func _sync_hands() -> void:
	_ensure_hands()
	_move_held_props()


func _move_held_props() -> void:
	if _solving_grip:
		return
	for owner in _held_cups:
		_follow_hand(_cups[owner], _right_bone, _right_rest, HAND_CUPS[owner], 1.0)
	if _holding_jug and is_instance_valid(_skeleton) and _left_bone >= 0:
		_jug_goal = _carry_transform()
		if not jug_animating():
			_jug.global_transform = _jug_goal
			_jug.show()


func _hand_transform(bone: int,correction: Basis,at: Vector3,size: float) -> Transform3D:
	var pose := _skeleton.global_transform*_skeleton.get_bone_global_pose(bone)
	var orientation := (pose.basis*correction).orthonormalized().scaled(Vector3.ONE*size)
	return Transform3D(orientation,pose*(correction*at))


func _follow_hand(item: Node3D, bone: int, correction: Basis, at: Vector3, size: float) -> void:
	# Props stay under I01FamilyProps when a character model is replaced.
	item.visible = is_instance_valid(_skeleton) and bone >= 0
	if item.visible:
		var pose := _skeleton.global_transform * _skeleton.get_bone_global_pose(bone)
		var orientation := (pose.basis * correction).orthonormalized().scaled(Vector3.ONE * size)
		item.global_transform = Transform3D(orientation, pose * (correction * at))


func _ensure_hands() -> void:
	var body: Variant = _carrier.get("body") if is_instance_valid(_carrier) else null
	if is_instance_valid(_figure_body) and body == _figure_body:
		return
	if is_instance_valid(_skeleton):
		_skeleton.skeleton_updated.disconnect(_move_held_props)
	_skeleton = null
	_figure_body = null
	_right_bone = -1
	_left_bone = -1
	if not is_instance_valid(body) or not body is Node3D:
		return
	_figure_body = body
	var rigs := (body as Node3D).find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty():
		return
	_skeleton = rigs[0] as Skeleton3D
	_right_bone = _skeleton.find_bone("Hand_R")
	_left_bone = _skeleton.find_bone("Hand_L")
	if _right_bone >= 0:
		_right_rest = _skeleton.get_bone_global_rest(_right_bone).basis.inverse()
	if _left_bone >= 0:
		_left_rest = _skeleton.get_bone_global_rest(_left_bone).basis.inverse()
	# AnimationMixer can finish a pose after the regular node process.
	_skeleton.skeleton_updated.connect(_move_held_props)


func _find_bench_jug() -> void:
	if is_instance_valid(_bench_jug):
		return
	var world := get_parent()
	if world == null:
		return
	var home := world.find_child("FamilyHome", true, false)
	if home != null:
		_bench_jug = home.get_node_or_null("DrinkingJug") as Node3D
