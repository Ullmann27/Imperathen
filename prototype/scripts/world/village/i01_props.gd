extends Node3D
## I-01 props: the three named family cups and the family jug. Presentation
## only – every position is derived from the saved I-01 state (shelf, hand,
## table) and never changes it. The jug follows the live wrist with a
## bounded procedural pickup/pour/setdown transition; saves settle directly.

const Objects := preload("res://scripts/story/mission_documents.gd")
const I01 = preload("res://scripts/story/i01_three_cups.gd")
const Art = preload("res://scripts/world/village_art.gd")
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
var _jug_mode := ""
var _jug_pending := ""
var _jug_action := ""
var _jug_clock := 0.0
var _jug_duration := .32
var _jug_from := Transform3D.IDENTITY
var _jug_goal := Transform3D.IDENTITY

func begin_jug_action(action: String) -> void:
	if action in ["i01_well","i01_park_jug","i01_pour","fill_water","father_morning"]:
		_jug_pending = action

func jug_in_hand() -> bool:
	return visible and _holding_jug

func jug_animating() -> bool:
	return not _jug_action.is_empty()



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
	if not enabled:
		_jug_action = ""
		_jug_pending = ""
		_jug_mode = ""
		_jug.hide()
		set_process(false)
		if is_instance_valid(_bench_jug):
			_bench_jug.visible = true
		return
	var view := I01.presentation(state)
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
		_water[owner].visible = filled and where == "table"
	var next_mode := str(view.jug)
	if next_mode != _jug_mode and _jug_pending.is_empty():
		_jug_action = ""
	_jug_mode = next_mode
	_holding_jug = next_mode == "hand"
	if _holding_jug:
		_ensure_hands()
		if _left_bone >= 0:
			_jug_goal = _hand_transform(_left_bone,_left_rest,JUG_HAND,1.0)
	elif next_mode == "away":
		_jug_goal = prior
	else:
		var destination := JUG_TABLE if next_mode == "table" else JUG_BENCH
		_jug_goal = global_transform*Transform3D(Basis.IDENTITY,world_point(destination))
	if not _jug_pending.is_empty():
		_jug_action = _jug_pending
		_jug_pending = ""
		_jug_clock = 0.0
		_jug_duration = .50 if _jug_action == "i01_pour" else .32
		_jug_from = prior
		if _holding_jug and (_jug_action == "i01_well" or not prior_visible or prior.origin.distance_to(_jug_goal.origin) > .85):
			# The well action starts locally, never flies from the family bench.
			_jug_from = _jug_goal
			_jug_from.origin.y -= .24
		if not _holding_jug and next_mode == "table" and prior.origin.distance_to(_jug_goal.origin) > .85:
			# Interaction range exceeds arm reach: use a local tabletop
			# approach rather than stretching the model or flying a prop.
			_jug_from = _jug_goal
			_jug_from.origin.y += .18
		_jug.global_transform = _jug_from
		_jug.show()
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
		_jug_clock += maxf(delta,0.0)
		var t := clampf(_jug_clock/_jug_duration,0.0,1.0)
		var eased := t*t*(3.0-2.0*t)
		var pose := _jug_from.interpolate_with(_jug_goal,eased)
		if _jug_action == "i01_pour":
			pose.basis = pose.basis*Basis(Vector3.RIGHT,.68*sin(PI*t))
			pose.origin.y += .10*sin(PI*t)
		_jug.global_transform = pose
		if t >= 1.0:
			_jug_action = ""
			_jug.global_transform = _jug_goal
			_jug.visible = _jug_mode != "away"
			set_process(_holding_jug or not _held_cups.is_empty())


func _sync_hands() -> void:
	_ensure_hands()
	_move_held_props()


func _move_held_props() -> void:
	for owner in _held_cups:
		_follow_hand(_cups[owner], _right_bone, _right_rest, HAND_CUPS[owner], 1.0)
	if _holding_jug and is_instance_valid(_skeleton) and _left_bone >= 0:
		_jug_goal = _hand_transform(_left_bone,_left_rest,JUG_HAND,1.0)
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
