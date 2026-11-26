extends Node3D
## I-04 props in Sextus' forge: the delivered kindling bundle at the quench
## trough, the stack the boy builds beside the bellows, the armful he
## carries, the two tongs on the anvil, the cold bent nail on the anvil block
## and Sextus' wax tablet. Presentation only – everything is derived from the
## saved I-04 state and never changes it.

const Documents = preload("res://scripts/story/mission_documents.gd")
const I04 = preload("res://scripts/story/i04_workshop.gd")
const Art = preload("res://scripts/world/village_art.gd")
## World positions inside the existing forge (settlement_dressing VillageForge
## at (34.1, 0, -26.2): anvil at local z 1.0, hearth at z -2.85).
const BUNDLE := Vector3(33.25, 0.0, -23.75)
const STACK := Vector3(33.05, 0.0, -29.15)
const ANVIL_TOP := Vector3(34.1, 0.97, -25.2)
const BLOCK_TOP := Vector3(33.83, 0.535, -25.2)
const HEARTH := Vector3(34.15, 0.80, -29.05)

var _built := false
var _bundle: Array[Node3D] = []
var _stack: Array[Node3D] = []
var _armful: Node3D
var _tongs: Node3D
var _nail: Node3D
var _note: Node3D
var _hand_right: Node3D
var _hand_left: Node3D
var _figure_body: Node3D
var _wood: Material
var _wood_cut: Material


func _init() -> void:
	name = "I04ForgeProps"


## Cinematic anchors in this node's space (the world root).
func anchor(key: String) -> Vector3:
	match key:
		"i04_hearth": return HEARTH
		"i04_bundle": return BUNDLE + Vector3(0.0, 0.14, 0.0)
		"i04_tongs": return ANVIL_TOP + Vector3(0.0, 0.02, 0.0)
		"i04_nail": return BLOCK_TOP
		"i04_stack": return STACK + Vector3(0.0, 0.14, 0.0)
	return Vector3.INF


func _stick(parent: Node3D, length: float, radius: float, at: Vector3, yaw: float, roll: float) -> void:
	var stick := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.88
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 9
	mesh.rings = 1
	stick.mesh = mesh
	stick.material_override = _wood
	stick.position = at
	stick.rotation = Vector3(PI * 0.5 + roll, yaw, 0.0)
	parent.add_child(stick)
	# Pale split end, so the pile reads as cut kindling and not as rods.
	var cut := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius * 0.86
	disc.bottom_radius = radius * 0.86
	disc.height = 0.004
	disc.radial_segments = 9
	cut.mesh = disc
	cut.material_override = _wood_cut
	cut.position = Vector3(0.0, length * 0.5 + 0.001, 0.0)
	stick.add_child(cut)


## One armful: seven split sticks of slightly different length and lie.
func _armful_node(label: String, seed_value: int) -> Node3D:
	var node := Node3D.new()
	node.name = label
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	for index in 7:
		var row := index / 4
		var column := float(index % 4) + (0.0 if row == 0 else 0.5)
		_stick(node, random.randf_range(0.36, 0.46), random.randf_range(0.017, 0.026),
			Vector3((column - 1.5) * 0.052, 0.026 + row * 0.047, random.randf_range(-0.02, 0.02)),
			random.randf_range(-0.10, 0.10), random.randf_range(-0.03, 0.03))
	return node


func _build() -> void:
	if _built:
		return
	_built = true
	_wood = Art.material(Color("7a5a3a"), 0.92)
	_wood_cut = Art.material(Color("c9a878"), 0.9)
	var iron := Art.material(Color("3b3d40"), 0.55)
	iron.metallic = 0.4
	for index in I04.STICKS:
		var waiting := _armful_node("BundleArmful%d" % index, 41 + index)
		waiting.position = BUNDLE + Vector3(0.0, index * 0.10, 0.0)
		waiting.rotation.y = 0.35 + index * 0.5
		add_child(waiting)
		_bundle.append(waiting)
		var stacked := _armful_node("StackArmful%d" % index, 77 + index)
		# Crosswise layers leave air between the sticks.
		stacked.position = STACK + Vector3(0.0, index * 0.10, 0.0)
		stacked.rotation.y = PI * 0.5 * index
		add_child(stacked)
		_stack.append(stacked)
	# The cord of the delivered bundle stays where it was untied.
	var cord := MeshInstance3D.new()
	cord.name = "BundleCord"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.105
	ring.outer_radius = 0.117
	ring.rings = 20
	ring.ring_segments = 6
	cord.mesh = ring
	cord.material_override = Art.material(Color("b9a47c"), 0.95)
	cord.position = BUNDLE + Vector3(0.0, 0.10, 0.0)
	cord.rotation = Vector3(PI * 0.5, 0.35, 0.0)
	cord.scale = Vector3(1.0, 1.0, 0.9)
	add_child(cord)
	_bundle.append(cord)
	_tongs = Node3D.new()
	_tongs.name = "TongsOnAnvil"
	_tongs.position = ANVIL_TOP
	add_child(_tongs)
	for index in 2:
		var pair := Node3D.new()
		pair.name = "Tongs%d" % index
		pair.position = Vector3(-0.16 + index * 0.30, 0.012, 0.0)
		pair.rotation.y = 0.12 - index * 0.2
		_tongs.add_child(pair)
		for side: float in [-1.0, 1.0]:
			var rein := MeshInstance3D.new()
			var bar := BoxMesh.new()
			bar.size = Vector3(0.016, 0.014, 0.30)
			rein.mesh = bar
			rein.material_override = iron
			rein.position = Vector3(side * 0.012, 0.0, 0.03)
			rein.rotation.y = side * 0.07
			pair.add_child(rein)
			var jaw := MeshInstance3D.new()
			var bit := BoxMesh.new()
			bit.size = Vector3(0.02, 0.016, 0.07)
			jaw.mesh = bit
			jaw.material_override = iron
			jaw.position = Vector3(-side * 0.013, 0.0, -0.15)
			jaw.rotation.y = -side * 0.16
			pair.add_child(jaw)
		var rivet := MeshInstance3D.new()
		var head := CylinderMesh.new()
		head.top_radius = 0.011
		head.bottom_radius = 0.011
		head.height = 0.02
		head.radial_segments = 10
		rivet.mesh = head
		rivet.material_override = iron
		rivet.position = Vector3(0.0, 0.002, -0.105)
		pair.add_child(rivet)
		if index == 1:
			# The fine crack at the joint of the second pair: bright fresh iron.
			var crack := MeshInstance3D.new()
			var line := BoxMesh.new()
			line.size = Vector3(0.022, 0.0025, 0.0025)
			crack.mesh = line
			crack.material_override = Art.material(Color("c9ccd0"), 0.35)
			crack.name = "Crack"
			crack.position = Vector3(0.008, 0.0085, -0.092)
			crack.rotation.y = 0.6
			pair.add_child(crack)
	_nail = Node3D.new()
	_nail.name = "BentNail"
	_nail.position = BLOCK_TOP
	add_child(_nail)
	for part: Array in [[Vector3(0.0, 0.004, 0.0), 0.0, 0.052], [Vector3(0.036, 0.004, 0.012), 0.62, 0.034]]:
		var shank := MeshInstance3D.new()
		var rod := CylinderMesh.new()
		rod.top_radius = 0.0022 if float(part[2]) < 0.04 else 0.0034
		rod.bottom_radius = 0.0034
		rod.height = float(part[2])
		rod.radial_segments = 6
		shank.mesh = rod
		shank.material_override = iron
		shank.position = part[0]
		shank.rotation = Vector3(0.0, float(part[1]), PI * 0.5)
		_nail.add_child(shank)
	var nail_head := MeshInstance3D.new()
	var cap := CylinderMesh.new()
	cap.top_radius = 0.0075
	cap.bottom_radius = 0.0075
	cap.height = 0.004
	cap.radial_segments = 8
	nail_head.mesh = cap
	nail_head.material_override = iron
	nail_head.position = Vector3(-0.027, 0.004, 0.0)
	nail_head.rotation.z = PI * 0.5
	_nail.add_child(nail_head)
	_make_carried()


func _make_carried() -> void:
	_armful = _armful_node("CarriedArmful", 9)
	_armful.visible = false
	add_child(_armful)
	_note = Node3D.new()
	_note.name = "WaxTablet"
	_note.visible = false
	add_child(_note)


## Called from GameWorld.sync_state with the authoritative state; `index` is
## the completed[] size at which the visit is open.
func sync_state(state: Dictionary, figure: Node3D, index: int, trial_index: int) -> void:
	var enabled: bool = state.get("village", {}).has("childhood")
	visible = enabled
	if not enabled:
		return
	_build()
	if not is_instance_valid(_armful) or not is_instance_valid(_note):
		# Carried props hung on a figure body that has since been replaced.
		_make_carried()
	var child: Dictionary = state.village.childhood
	var s: Dictionary = child.screenplay
	var status := str(s.get("i04s", ""))
	var completed: int = child.completed.size()
	var sticks := int(s.get("i04_sticks", 0))
	var in_hand := bool(s.get("i04_hand", false))
	# The bundle lies at the trough from its delivery until the visit is over
	# (what was not stacked by the boy, Sextus puts away himself afterwards).
	var delivered: bool = status != "legacy" and completed == index
	var remaining := I04.STICKS - sticks - (1 if in_hand else 0)
	for layer in I04.STICKS:
		_bundle[layer].visible = delivered and layer < remaining
		_stack[layer].visible = status in ["pending", "complete"] and layer < sticks
	_bundle[I04.STICKS].visible = delivered
	_tongs.visible = status in ["pending", "complete"] and completed >= index and completed <= trial_index and (not str(s.get("i04_topic", "")).is_empty() or _talk_open(s))
	_nail.visible = I04.nail_kept(state)
	var held := Documents.held(state)
	var noted := not held.is_empty()
	if noted and str(_note.get_meta("document_id","")) != held[0]:
		for old in _note.get_children():
			old.free()
		var scene := load(Documents.ENTRIES[held[0]].model) as PackedScene
		_note.add_child(scene.instantiate())
		_note.set_meta("document_id", held[0])
	if in_hand or noted:
		_ensure_hands(figure)
	_carry(_armful, _hand_left, in_hand, Vector3(0.0, -0.20, 0.10))
	_carry(_note, _hand_right, noted, Vector3(0.0, -0.10, 0.05))


static func _talk_open(s: Dictionary) -> bool:
	match str(s.get("i04_work", "")):
		"stack": return int(s.get("i04_sticks", 0)) >= I04.STICKS
		"message": return str(s.get("i04_note", "")) == "given"
		"watch": return true
	return false


func bundle_armfuls() -> int:
	var count := 0
	for layer in I04.STICKS:
		count += 1 if _built and _bundle[layer].visible and visible else 0
	return count


func stack_armfuls() -> int:
	var count := 0
	for layer in I04.STICKS:
		count += 1 if _built and _stack[layer].visible and visible else 0
	return count


func carrying(what: String) -> bool:
	var item: Node3D = _armful if what == "kindling" else _note
	return _built and is_instance_valid(item) and item.visible and item.get_parent() != self


func shows(what: String) -> bool:
	var item: Node3D = _tongs if what == "tongs" else _nail
	return _built and visible and item.visible


func _carry(item: Node3D, hand: Node3D, held: bool, offset: Vector3) -> void:
	if held and is_instance_valid(hand):
		if item.get_parent() != hand:
			item.get_parent().remove_child(item)
			hand.add_child(item)
		var world_scale := hand.global_basis.get_scale() if hand.is_inside_tree() else Vector3.ONE
		item.position = offset
		item.basis = Basis.IDENTITY.scaled(Vector3(1.0 / maxf(world_scale.x, 0.001), 1.0 / maxf(world_scale.y, 0.001), 1.0 / maxf(world_scale.z, 0.001)))
		item.visible = true
		return
	if item.get_parent() != self:
		item.get_parent().remove_child(item)
		add_child(item)
	item.visible = false


func _ensure_hands(figure: Node3D) -> void:
	if not is_instance_valid(figure):
		return
	var body: Variant = figure.get("body")
	if not body is Node3D or body == _figure_body and is_instance_valid(_hand_left) and is_instance_valid(_hand_right):
		return
	_figure_body = body
	var skeletons: Array[Node] = (body as Node3D).find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	_hand_left = _attachment(skeleton, "Hand_L", "I04CarryLeft")
	_hand_right = _attachment(skeleton, "Hand_R", "I04CarryRight")


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
	props.basis = skeleton.get_bone_global_rest(index).basis.inverse()
	attachment.add_child(props)
	return props
