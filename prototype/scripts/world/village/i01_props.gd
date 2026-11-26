extends Node3D
## I-01 props: the three named family cups and the family jug. Presentation
## only – every position is derived from the saved I-01 state (shelf, hand,
## table) and never changes it. Carrying is a greybox: the cups and the jug
## follow the boy's Hand_R/Hand_L bones; there is no authored carry clip yet.

const I01 = preload("res://scripts/story/i01_three_cups.gd")
const Art = preload("res://scripts/world/village_art.gd")
const FLOOR := 0.3925
## Family home baker_home sits at (-13, 0, 11) with yaw 0; room-local offsets.
const ROOM := Vector3(-13.0, FLOOR, 11.0)
const SHELF_SLOTS := {"julia":Vector3(-2.32, 1.08, -0.27), "silvanus":Vector3(-2.32, 1.08, 0.03), "player":Vector3(-2.32, 1.08, 0.33)}
const SHELF_ORIGIN := Vector3(0.0, 0.0, 1.05)
const TABLE_SLOTS := {"julia":Vector3(-1.35, 0.865, -0.98), "silvanus":Vector3(-1.70, 0.865, -0.30), "player":Vector3(-0.70, 0.865, -0.30)}
const JUG_TABLE := Vector3(-0.55, 0.865, -0.85)
const JUG_BENCH := Vector3(1.93, 0.515, 0.18)
const HAND_CUPS := {"julia":Vector3(0.0, -0.02, 0.05), "silvanus":Vector3(0.0, 0.10, 0.05), "player":Vector3(0.0, 0.22, 0.05)}

var _cups: Dictionary = {}
var _water: Dictionary = {}
var _jug: MeshInstance3D
var _hand_right: Node3D
var _hand_left: Node3D
var _figure_body: Node3D
var _bench_jug: Node3D
var _signature := ""


func _init() -> void:
	name = "I01FamilyProps"


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
	var clay := {"julia":Art.material(Color("a56343")), "silvanus":Art.material(Color("8a5238")), "player":Art.material(Color("c18b5e"))}
	var water := Art.material(Color("4f6a66"), .12)
	for owner: String in I01.CUPS:
		var cup := MeshInstance3D.new()
		cup.name = "FamilyCup_" + owner
		# The boy's cup is the "crooked" one from Silvanus' joke: its rim leans.
		cup.mesh = _vessel([Vector2(.07,0),Vector2(.075,.02),Vector2(.095,.13),Vector2(.105,.15),Vector2(.083,.15),Vector2(.071,.035)], 0.13 if owner == "player" else 0.0)
		cup.material_override = clay[owner]
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
		surface.position = Vector3(0.006 if owner == "player" else 0.0, .118, 0)
		cup.add_child(surface)
		_water[owner] = surface
	_jug = MeshInstance3D.new()
	_jug.name = "FamilyJug"
	_jug.mesh = _vessel([Vector2(.15,0),Vector2(.25,.12),Vector2(.31,.36),Vector2(.24,.57),Vector2(.12,.65),Vector2(.115,.76),Vector2(.14,.77),Vector2(.14,.81),Vector2(.095,.81),Vector2(.095,.72),Vector2(.08,.66)], 0.0)
	_jug.material_override = Art.material(Color("c18b5e"))
	_jug.scale = Vector3.ONE * .48
	add_child(_jug)


## Called from GameWorld.sync_state with the authoritative state.
func sync_state(state: Dictionary, figure: Node3D) -> void:
	_build()
	var enabled: bool = state.get("village", {}).has("childhood")
	visible = enabled
	_find_bench_jug()
	if not enabled:
		if is_instance_valid(_bench_jug):
			_bench_jug.visible = true
		return
	var view := I01.presentation(state)
	_ensure_hands(figure)
	var cup_state: Dictionary = view.cups
	var filled: bool = str(view.water) in ["poured", "silvanus"] or str(view.status) == "legacy"
	for owner: String in I01.CUPS:
		var cup: MeshInstance3D = _cups[owner]
		var where := str(cup_state.get(owner, "shelf"))
		if where == "hand" and is_instance_valid(_hand_right):
			_place(cup, _hand_right, HAND_CUPS[owner], Basis.IDENTITY)
		elif where == "table":
			_place(cup, self, world_point(TABLE_SLOTS[owner]), Basis(Vector3.UP, 0.35 * I01.CUPS.find(owner)))
		else:
			_place(cup, self, world_point(SHELF_ORIGIN + SHELF_SLOTS[owner]), Basis.IDENTITY)
		_water[owner].visible = filled and where == "table"
	match str(view.jug):
		"hand":
			if is_instance_valid(_hand_left):
				_place(_jug, _hand_left, Vector3(0.0, -0.34, 0.06), Basis.IDENTITY)
			_jug.visible = true
		"table":
			_place(_jug, self, world_point(JUG_TABLE), Basis.IDENTITY)
			_jug.visible = true
		"away":
			_jug.visible = false
		_:
			_place(_jug, self, world_point(JUG_BENCH), Basis.IDENTITY)
			_jug.visible = true
	# The original bench jug stands for the same object; never show two.
	if is_instance_valid(_bench_jug):
		_bench_jug.visible = false


func cup_location(owner: String) -> String:
	if not _cups.has(owner):
		return ""
	var cup: Node3D = _cups[owner]
	if cup.get_parent() == _hand_right:
		return "hand"
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


func _place(item: Node3D, parent: Node3D, at: Vector3, basis: Basis) -> void:
	var size := 0.48 if item == _jug else 1.0
	if item.get_parent() != parent:
		if item.get_parent() != null:
			item.get_parent().remove_child(item)
		parent.add_child(item)
	item.position = at
	item.basis = basis.scaled(Vector3.ONE * size)
	if parent != self and item.is_inside_tree():
		# Bone attachments carry the rig's scale; keep the prop at metre size.
		var world_scale := parent.global_basis.get_scale()
		item.basis = basis.scaled(Vector3(size / maxf(world_scale.x, 0.001), size / maxf(world_scale.y, 0.001), size / maxf(world_scale.z, 0.001)))


func _ensure_hands(figure: Node3D) -> void:
	if not is_instance_valid(figure):
		return
	var body: Variant = figure.get("body")
	if not body is Node3D:
		return
	if body == _figure_body and is_instance_valid(_hand_right) and is_instance_valid(_hand_left):
		return
	_figure_body = body
	var skeletons: Array[Node] = (body as Node3D).find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	_hand_right = _attachment(skeleton, "Hand_R", "I01CarryRight")
	_hand_left = _attachment(skeleton, "Hand_L", "I01CarryLeft")


func _attachment(skeleton: Skeleton3D, bone: String, label: String) -> Node3D:
	var index := skeleton.find_bone(bone)
	if index < 0:
		return null
	var existing := skeleton.get_node_or_null(label)
	if existing != null:
		return existing.get_node("Props") as Node3D
	var attachment := BoneAttachment3D.new()
	attachment.name = label
	attachment.bone_name = bone
	attachment.override_pose = false
	skeleton.add_child(attachment)
	var props := Node3D.new()
	props.name = "Props"
	# Upright in model space at rest, like the borrowed practice gear.
	props.basis = skeleton.get_bone_global_rest(index).basis.inverse()
	attachment.add_child(props)
	return props


func _find_bench_jug() -> void:
	if is_instance_valid(_bench_jug):
		return
	var world := get_parent()
	if world == null:
		return
	var home := world.find_child("FamilyHome", true, false)
	if home != null:
		_bench_jug = home.get_node_or_null("DrinkingJug") as Node3D


func _vessel(profile: Array[Vector2], lean: float) -> ArrayMesh:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 14
	var top := profile.reduce(func(best: float, p: Vector2) -> float: return maxf(best, p.y), 0.0) as float
	for row in profile.size() - 1:
		for index in SEGMENTS:
			var a := TAU * index / SEGMENTS
			var b := TAU * (index + 1) / SEGMENTS
			var low: Vector2 = profile[row]
			var high: Vector2 = profile[row + 1]
			var low_shift := lean * low.y / maxf(top, 0.001) * 0.09
			var high_shift := lean * high.y / maxf(top, 0.001) * 0.09
			var points := [Vector3(cos(a)*low.x + low_shift, low.y, sin(a)*low.x), Vector3(cos(b)*low.x + low_shift, low.y, sin(b)*low.x),
				Vector3(cos(b)*high.x + high_shift, high.y, sin(b)*high.x), Vector3(cos(a)*high.x + high_shift, high.y, sin(a)*high.x)]
			for corner in [0, 2, 1, 0, 3, 2]:
				mesh.add_vertex(points[corner])
	mesh.generate_normals()
	return mesh.commit()
