extends Node3D
## I-03 props on Cassia's stall, the table of the village trading shelter:
## the two salt measures, Marcus' clay pot, his two asses, the tally stick and
## the water jug of the alternative service. Presentation only – everything
## is derived from the saved I-03 state and never changes it.

const I03 = preload("res://scripts/story/i03_shortcut.gd")
const Art = preload("res://scripts/world/village_art.gd")
## Free front strip of the existing table (its own goods stand further back).
const COINS := Vector3(-1.02, 0.004, 0.46)
const POT := Vector3(-1.32, 0.0, 0.36)
const SMALL_MEASURE := Vector3(-0.72, 0.0, 0.42)
const LARGE_MEASURE := Vector3(-0.50, 0.0, 0.42)
const TALLY := Vector3(-0.24, 0.011, 0.47)

var _built := false
var _coins: Node3D
var _pot: MeshInstance3D
var _salt: MeshInstance3D
var _notch: MeshInstance3D
var _jug: MeshInstance3D
var _hand_left: Node3D
var _figure_body: Node3D
var _stall: Node3D


func _init() -> void:
	name = "I03MarketProps"


## Cinematic anchors in this node's space (the world root).
func anchor(key: String) -> Vector3:
	match key:
		"i03_stall": return I03.STALL_TABLE
		"i03_coins": return I03.STALL_TABLE + COINS
		"i03_pot": return I03.STALL_TABLE + POT + Vector3(0.0, 0.12, 0.0)
		"i03_lane": return Vector3(I03.POINTS.lane.x, 0.0, I03.POINTS.lane.y)
	return Vector3.INF


func _box(parent: Node3D, label: String, size: Vector3, at: Vector3, material: Material, turn := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.rotation = turn
	node.material_override = material
	parent.add_child(node)
	return node


func _build() -> void:
	if _built:
		return
	_built = true
	var clay := Art.material(Color("a9643f"), 0.78)
	var salt := Art.material(Color("e9e4d8"), 0.97)
	var bronze := Art.material(Color("9a6b3a"), 0.42)
	bronze.metallic = 0.35
	var stall := Node3D.new()
	stall.name = "StallGoods"
	stall.position = I03.STALL_TABLE
	add_child(stall)
	_stall = stall
	for entry: Array in [["SmallMeasure", SMALL_MEASURE, 0.72], ["LargeMeasure", LARGE_MEASURE, 1.0]]:
		var measure := MeshInstance3D.new()
		measure.name = entry[0]
		measure.mesh = _lathe([Vector2(0.0, 0.0), Vector2(0.055, 0.0), Vector2(0.062, 0.012), Vector2(0.066, 0.11), Vector2(0.071, 0.118), Vector2(0.058, 0.118), Vector2(0.054, 0.02), Vector2(0.0, 0.016)])
		measure.material_override = bronze
		measure.position = entry[1]
		measure.scale = Vector3.ONE * float(entry[2])
		stall.add_child(measure)
	_pot = MeshInstance3D.new()
	_pot.name = "MarcusPot"
	_pot.mesh = _lathe([Vector2(0.0, 0.0), Vector2(0.06, 0.0), Vector2(0.105, 0.05), Vector2(0.12, 0.12), Vector2(0.10, 0.19), Vector2(0.078, 0.215), Vector2(0.092, 0.235), Vector2(0.074, 0.236), Vector2(0.066, 0.21), Vector2(0.088, 0.185), Vector2(0.105, 0.12), Vector2(0.09, 0.055), Vector2(0.0, 0.02)])
	_pot.material_override = clay
	_pot.position = POT
	stall.add_child(_pot)
	_salt = MeshInstance3D.new()
	_salt.name = "PotSalt"
	_salt.mesh = _lathe([Vector2(0.086, 0.0), Vector2(0.05, 0.012), Vector2(0.0, 0.02)])
	_salt.material_override = salt
	_pot.add_child(_salt)
	_coins = Node3D.new()
	_coins.name = "MarcusAsses"
	_coins.position = COINS
	stall.add_child(_coins)
	for index in 2:
		var coin := MeshInstance3D.new()
		coin.name = "As%d" % (index + 1)
		var disc := CylinderMesh.new()
		disc.top_radius = 0.0135
		disc.bottom_radius = 0.014
		disc.height = 0.0035
		disc.radial_segments = 20
		coin.mesh = disc
		coin.material_override = bronze
		coin.position = Vector3(index * 0.034, 0.0, index * 0.011)
		coin.rotation = Vector3(0.0, 0.7 * index, 0.04 * index)
		_coins.add_child(coin)
	var tally := _box(stall, "TallyStick", Vector3(0.20, 0.016, 0.022), TALLY, Art.material(Color("c9b68a"), 0.9), Vector3(0.0, 0.5, 0.0))
	_notch = _box(tally, "FreshNotch", Vector3(0.006, 0.006, 0.024), Vector3(0.05, 0.007, 0.0), Art.material(Color("f1e6c8"), 0.9))
	_jug = _make_jug()
	add_child(_jug)


func _make_jug() -> MeshInstance3D:
	var jug := MeshInstance3D.new()
	jug.name = "StallWaterJug"
	jug.mesh = _lathe([Vector2(0.0, 0.0), Vector2(0.072, 0.0), Vector2(0.12, 0.058), Vector2(0.149, 0.173), Vector2(0.115, 0.274), Vector2(0.058, 0.312), Vector2(0.055, 0.365), Vector2(0.067, 0.37), Vector2(0.067, 0.389), Vector2(0.046, 0.389), Vector2(0.046, 0.346), Vector2(0.0, 0.317)])
	jug.material_override = Art.material(Color("c18b5e"), 0.80)
	jug.visible = false
	return jug


## Called from GameWorld.sync_state with the authoritative state.
func sync_state(state: Dictionary, figure: Node3D) -> void:
	var enabled: bool = state.get("village", {}).has("childhood")
	visible = enabled
	if not enabled:
		return
	_build()
	var s: Dictionary = state.village.childhood.screenplay
	var stance := str(s.get("i03_stance", ""))
	var salt := str(s.get("i03_salt", ""))
	var open: bool = str(s.get("i03s", "")) == "pending"
	var at_stall: bool = open and stance in ["watch", "offer", "object"]
	# Marcus' asses lie on the stall until the matter is settled either way.
	_coins.visible = at_stall and salt.is_empty()
	_pot.visible = at_stall
	_salt.visible = at_stall and salt in ["small", "large", "debt"]
	_salt.position = Vector3(0.0, 0.085 if salt == "small" else 0.165, 0.0)
	_salt.scale = Vector3.ONE * (0.92 if salt == "small" else 1.0)
	_notch.visible = salt == "debt" and open
	if not is_instance_valid(_jug):
		# The jug hung on a hand of a figure body that has since been replaced.
		_jug = _make_jug()
		add_child(_jug)
	var carrying: bool = state.village.childhood.get("carried", []).has("stall_water")
	if carrying:
		_ensure_hand(figure)
	if carrying and is_instance_valid(_hand_left):
		_place_in_hand()
	elif _jug.get_parent() != self:
		_jug.get_parent().remove_child(_jug)
		add_child(_jug)
	_jug.visible = carrying and _jug.get_parent() != self


func coins_visible() -> bool:
	return _built and _coins.visible and visible


func pot_fill() -> String:
	if not _built or not _pot.visible:
		return "absent"
	if not _salt.visible:
		return "empty"
	return "small" if _salt.position.y < 0.1 else "large"


func jug_in_hand() -> bool:
	return _built and _jug.visible and _jug.get_parent() != self


func _place_in_hand() -> void:
	if _jug.get_parent() != _hand_left:
		_jug.get_parent().remove_child(_jug)
		_hand_left.add_child(_jug)
	var world_scale := _hand_left.global_basis.get_scale() if _hand_left.is_inside_tree() else Vector3.ONE
	_jug.position = Vector3(0.0, -0.34, 0.06)
	_jug.basis = Basis.IDENTITY.scaled(Vector3(1.0 / maxf(world_scale.x, 0.001), 1.0 / maxf(world_scale.y, 0.001), 1.0 / maxf(world_scale.z, 0.001)))


func _ensure_hand(figure: Node3D) -> void:
	if not is_instance_valid(figure):
		return
	var body: Variant = figure.get("body")
	if not body is Node3D or body == _figure_body and is_instance_valid(_hand_left):
		return
	_figure_body = body
	var skeletons: Array[Node] = (body as Node3D).find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	var index := skeleton.find_bone("Hand_L")
	if index < 0:
		return
	var existing := skeleton.get_node_or_null("I03CarryLeft")
	if existing != null:
		_hand_left = existing.get_node("Props") as Node3D
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "I03CarryLeft"
	attachment.bone_name = "Hand_L"
	attachment.override_pose = false
	skeleton.add_child(attachment)
	var props := Node3D.new()
	props.name = "Props"
	props.basis = skeleton.get_bone_global_rest(index).basis.inverse()
	attachment.add_child(props)
	_hand_left = props


## Smooth lathe: shared vertices per ring, so normals interpolate around the
## vessel; the profile supplies the hard edges at rims.
func _lathe(profile: Array[Vector2]) -> ArrayMesh:
	const SEGMENTS := 28
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(0)
	for row in profile.size():
		for index in SEGMENTS + 1:
			var angle := TAU * index / SEGMENTS
			tool.set_uv(Vector2(float(index) / SEGMENTS, float(row) / maxf(1.0, profile.size() - 1.0)))
			tool.add_vertex(Vector3(cos(angle) * profile[row].x, profile[row].y, sin(angle) * profile[row].x))
	for row in profile.size() - 1:
		for index in SEGMENTS:
			var a := row * (SEGMENTS + 1) + index
			var b := a + 1
			var c := a + SEGMENTS + 1
			var d := c + 1
			for corner: int in [a, c, b, b, c, d]:
				tool.add_index(corner)
	tool.generate_normals()
	return tool.commit()
