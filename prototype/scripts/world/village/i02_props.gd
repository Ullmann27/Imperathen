extends Node3D
## I-02 neighbour basket presentation. The authoritative childhood state owns
## pickup, correction and handover; this module only displays that state.
## The original GLB stays under this world-owned container across LOD swaps.

const Documents = preload("res://scripts/story/mission_documents.gd")
const BASKET_ID := "neighbor_basket"
## Centreline of the authored braided handle, derived from
## tools/world/build_valdora_handgoods.py: 0.148 + 0.155 metres.
const HANDLE_GRIP := Vector3(0.0, 0.303, 0.0)

var _built := false
var _basket: Node3D
var _carrier: Node3D
var _figure_body: Node3D
var _hand: Node3D
var _holding := false


func _init() -> void:
	name = "I02BasketProps"
	# Reconcile after the default-priority actor motion and animation updates.
	process_priority = 10
	process_physics_priority = 10
	set_process(false)
	set_physics_process(false)


func _build() -> bool:
	if _built:
		return is_instance_valid(_basket)
	_built = true
	var entry: Dictionary = Documents.ENTRIES.get(BASKET_ID, {})
	var source := str(entry.get("model", ""))
	if source.is_empty():
		push_error("I-02 neighbour basket has no registered original model")
		return false
	var packed := load(source) as PackedScene
	if packed == null:
		push_error("I-02 original basket cannot be loaded: " + source)
		return false
	_basket = packed.instantiate() as Node3D
	if _basket == null:
		push_error("I-02 original basket did not instantiate a Node3D")
		return false
	_basket.name = "NeighbourBasket"
	_basket.visible = false
	_basket.set_meta("source_model", source)
	_basket.set_meta("handle_grip_local", HANDLE_GRIP)
	add_child(_basket)
	return true


## Called by the world with the validated, authoritative state. No state or
## carried-item list is modified here, including for legacy or malformed saves.
func sync_state(state: Dictionary, figure: Node3D) -> void:
	var village: Variant = state.get("village", {})
	var enabled: bool = village is Dictionary and village.get("childhood") is Dictionary
	visible = enabled
	_carrier = figure if enabled else null
	if not enabled:
		_holding = false
		set_process(false)
		set_physics_process(false)
		if is_instance_valid(_basket):
			_basket.hide()
		return
	var child: Dictionary = village.childhood
	var screenplay: Dictionary = child.get("screenplay", {})
	var status := str(screenplay.get("i02", ""))
	var carried: Array = child.get("carried", [])
	_holding = status in ["pending", "correction"] and carried.has(BASKET_ID)
	var ready := _build() if _holding else is_instance_valid(_basket)
	set_process(_holding and ready)
	set_physics_process(_holding and ready)
	if _holding and ready:
		_ensure_hand(_carrier)
	_carry()


func basket_in_hand() -> bool:
	return _built and visible and _holding and is_instance_valid(_basket) and _basket.is_visible_in_tree() and is_instance_valid(_hand)


func basket_node() -> Node3D:
	return _basket


func grip_world() -> Vector3:
	return _basket.to_global(HANDLE_GRIP) if basket_in_hand() else Vector3.INF


func hand_world() -> Vector3:
	return _hand.global_position if basket_in_hand() else Vector3.INF


func attachment_error_m() -> float:
	return grip_world().distance_to(hand_world()) if basket_in_hand() else INF


## Real moving prop anchor for an insert; no invented fixed story location.
func anchor(key: String) -> Vector3:
	return grip_world() if key in ["i02_basket", "i02_correct"] else Vector3.INF


func _process(_delta: float) -> void:
	_follow_hand()


func _physics_process(_delta: float) -> void:
	_follow_hand()


func _follow_hand() -> void:
	if not _holding or not _build():
		return
	_ensure_hand(_carrier)
	_carry()


func _carry() -> void:
	if not is_instance_valid(_basket):
		return
	if _holding and is_instance_valid(_hand):
		# Put the measured handle centreline exactly on the actual wrist socket.
		# The basket hangs below it without rescaling the original asset.
		var basis := _hand.global_basis.orthonormalized()
		_basket.global_transform = Transform3D(basis, _hand.global_position - basis * HANDLE_GRIP)
		_basket.show()
	else:
		_basket.hide()


func _ensure_hand(figure: Node3D) -> void:
	if not is_instance_valid(figure):
		_hand = null
		return
	var body: Variant = figure.get("body")
	if not body is Node3D:
		_figure_body = null
		_hand = null
		return
	if body == _figure_body and is_instance_valid(_hand):
		return
	_figure_body = body as Node3D
	_hand = null
	var skeletons: Array[Node] = (body as Node3D).find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	_hand = _attachment(skeletons[0] as Skeleton3D, "Hand_L", "I02CarryLeft")


func _attachment(skeleton: Skeleton3D, bone: String, label: String) -> Node3D:
	var index := skeleton.find_bone(bone)
	if index < 0:
		return null
	var existing := skeleton.get_node_or_null(label)
	if existing != null:
		return existing.get_node_or_null("Props") as Node3D
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
