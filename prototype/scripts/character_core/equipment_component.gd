class_name EquipmentComponent
extends Node
## Explicit read-only presentation adapter for a CharacterCore child node.
## WorldModel remains the only inventory authority. No idle frame scanning.
## The caller/animation owner must supply the actual socket commit event.
signal equipment_changed
signal equipment_rejected(reason: String)
signal socket_switched(slot: String, place: String)
signal switch_finished(slot: String, committed: bool)

const Gear = preload("res://scripts/domain/gear_market.gd")
const Visuals = preload("res://scripts/visuals/gear_visuals.gd")
const Piece = preload("res://scripts/character_core/armor_piece_resource.gd")
var _actor: CharacterCore
var _rig: Skeleton3D
var _pieces: Dictionary = {}
var _attachments: Dictionary = {}
var _props: Dictionary = {}
var _places: Dictionary = {}
var _snapshot: Array[Dictionary] = []
var _detail: int = -1
var _pending_slot: String = ""
var _pending_place: String = ""
var _pending_seconds: float = 0.0
var _committed: bool = false

func _ready() -> void:
	set_physics_process(false)
	_actor = get_parent() as CharacterCore
	if not is_instance_valid(_actor):
		return
	_actor.rig_bound.connect(_on_rig_bound)
	if _actor.is_character_ready():
		_on_rig_bound(_actor.get_character_skeleton())

func _exit_tree() -> void:
	if is_instance_valid(_actor) and _actor.rig_bound.is_connected(_on_rig_bound):
		_actor.rig_bound.disconnect(_on_rig_bound)
	_clear(false)
	_rig = null

func _on_rig_bound(skeleton: Skeleton3D) -> void:
	if _rig == skeleton:
		return
	_clear(false)
	_rig = skeleton

func is_equipment_ready() -> bool:
	return is_instance_valid(_actor) and _actor.is_character_ready() and is_instance_valid(_rig) and _rig.is_inside_tree() and _actor.get_character_skeleton() == _rig

func get_attachment(slot: String) -> BoneAttachment3D:
	var value: Variant = _attachments.get(slot)
	return value as BoneAttachment3D if is_instance_valid(value) else null

func get_place(slot: String) -> String:
	return str(_places.get(slot, "")) if get_attachment(slot) != null else ""

func is_switch_pending() -> bool:
	return not _pending_slot.is_empty()

## Call on authoritative equipment, era or LOD changes, not each simulation tick.
## Unsupported owned mount entries are handled by the mount system, not worn.
## Any invalid or unsupported wearable snapshot clears old presentation.
func sync_from_world(data: Dictionary, detail: int = 0) -> bool:
	if not is_equipment_ready() or detail < 0 or detail > 3:
		return _reject_snapshot("Invalid rig or body detail")
	if not Gear.enabled(data):
		_clear(true)
		return true
	var error: String = Gear.validate(data)
	if not error.is_empty():
		return _reject_snapshot(error)
	var pieces: Array[Dictionary] = []
	for row: Dictionary in Gear.equipped_models(data):
		if str(row.slot) in ["mount", "mount_gear"]:
			continue
		if not Gear.era_open(str(row.item_id), Gear.world_jdn(data)):
			return _reject_snapshot("Equipped item outside its registered era")
		pieces.append(row)
	if pieces == _snapshot and detail == _detail and _all_live():
		return true
	var layout: Array[Dictionary] = Visuals.placements(pieces)
	if layout.size() != pieces.size():
		return _reject_snapshot("No certified rigid socket for equipped garment")
	var staged: Dictionary = {}
	var used: Dictionary = {}
	for row: Dictionary in layout:
		var slot: String = str(row.slot)
		var desc: ArmorPieceResource = Piece.from_catalog(str(row.item_id), int(row.quality), detail)
		if desc == null or desc.slot != slot or staged.has(slot):
			return _reject_staged(staged, "Unsupported wearable or duplicate slot")
		var place: String = str(row.place)
		var former: ArmorPieceResource = _pieces.get(slot) as ArmorPieceResource
		if former != null and former.item_id == desc.item_id and former.quality == desc.quality:
			place = str(_places.get(slot, place))
		if used.has(place) or not desc.supports_place(place):
			return _reject_staged(staged, "Occupied or unsupported socket: " + place)
		var prop: Node3D = Visuals.instantiate(desc.item_id, desc.quality, desc.lod)
		if prop == null:
			return _reject_staged(staged, "Missing imported equipment")
		var pose: Dictionary = _resolve_pose(desc, prop, place)
		if pose.is_empty():
			prop.free()
			return _reject_staged(staged, "Missing or invalid authored socket: " + place)
		var attachment: BoneAttachment3D = BoneAttachment3D.new()
		attachment.name = "Phase2_" + slot
		attachment.bone_name = str(pose.bone)
		attachment.override_pose = false
		attachment.set_meta("phase2_equipment", true)
		attachment.set_meta("item_id", desc.item_id)
		attachment.set_meta("quality", desc.quality)
		attachment.set_meta("model_path", desc.model_path)
		var grip: Node3D = Node3D.new()
		grip.name = "Grip"
		grip.transform = pose.grip
		attachment.add_child(grip)
		prop.name = "Prop"
		grip.add_child(prop)
		staged[slot] = {"desc": desc, "attachment": attachment, "prop": prop, "place": place}
		used[place] = true
	# All resources and sockets checked before changing the displayed set.
	_clear(false)
	for slot: String in staged:
		var item: Dictionary = staged[slot]
		var attachment: BoneAttachment3D = item.attachment
		_rig.add_child(attachment)
		_pieces[slot] = item.desc
		_attachments[slot] = attachment
		_props[slot] = item.prop
		_places[slot] = item.place
	_snapshot = pieces.duplicate(true)
	_detail = detail
	equipment_changed.emit()
	return true

## Presentation-only draw/stow request. clip is supplied by the animation owner;
## the original review rig has no certified draw/dress animation.
## The deadline is a fail-safe, never a substitute for an animation marker.
func request_socket_switch(slot: String, place: String, clip: StringName, timeout_seconds: float = 1.5) -> bool:
	if is_switch_pending() or not is_equipment_ready() or not is_finite(timeout_seconds) or timeout_seconds <= 0.0 or timeout_seconds > 10.0 or clip.is_empty():
		return _reject("Invalid or busy socket transition")
	if get_place(slot) == place or _occupied(slot, place) or _switch_pose(slot, place).is_empty():
		return _reject("Socket transition is unavailable")
	if not _actor.set_upper_body_clip(clip, 1.0):
		return _reject("No authored animation with that name")
	_pending_slot = slot
	_pending_place = place
	_pending_seconds = timeout_seconds
	_committed = false
	set_physics_process(true)
	return true

## Called once by the external animation marker. No domain state changes.
func commit_socket_switch() -> bool:
	if not is_switch_pending() or _committed:
		return false
	var slot: String = _pending_slot
	var place: String = _pending_place
	if not is_equipment_ready() or _occupied(slot, place):
		finish_socket_switch()
		return _reject("Socket became unavailable")
	var pose: Dictionary = _switch_pose(slot, place)
	var attachment: BoneAttachment3D = get_attachment(slot)
	if pose.is_empty() or attachment == null:
		finish_socket_switch()
		return _reject("Socket target or prop was lost")
	var grip: Node3D = attachment.get_node_or_null("Grip") as Node3D
	if grip == null:
		finish_socket_switch()
		return _reject("Missing equipment grip")
	attachment.bone_name = str(pose.bone)
	attachment.bone_idx = int(pose.index)
	grip.transform = pose.grip
	_places[slot] = place
	_committed = true
	socket_switched.emit(slot, place)
	return true

## Also used on cancellation/timeout. A committed switch stays committed.
func finish_socket_switch() -> void:
	if not is_switch_pending():
		return
	var slot: String = _pending_slot
	var committed: bool = _committed
	_pending_slot = ""
	_pending_place = ""
	_pending_seconds = 0.0
	_committed = false
	set_physics_process(false)
	if is_instance_valid(_actor) and _actor.is_character_ready():
		_actor.clear_upper_body()
	switch_finished.emit(slot, committed)

func clear_equipment() -> void:
	_clear(true)

func _physics_process(delta: float) -> void:
	if not is_switch_pending():
		set_physics_process(false)
		return
	_pending_seconds -= delta
	if _pending_seconds <= 0.0 or not is_equipment_ready() or get_attachment(_pending_slot) == null:
		finish_socket_switch()

func _occupied(slot: String, place: String) -> bool:
	for other: String in _places:
		if other != slot and str(_places[other]) == place:
			return true
	return false

func _switch_pose(slot: String, place: String) -> Dictionary:
	var desc: ArmorPieceResource = _pieces.get(slot) as ArmorPieceResource
	var value: Variant = _props.get(slot)
	if desc == null or not is_instance_valid(value):
		return {}
	return _resolve_pose(desc, value as Node3D, place)

func _resolve_pose(desc: ArmorPieceResource, prop: Node3D, place: String) -> Dictionary:
	if not is_instance_valid(_rig) or not is_instance_valid(prop) or not desc.supports_place(place) or not Visuals.ATTACH.has(place):
		return {}
	var spec: Dictionary = Visuals.ATTACH[place]
	var bone: int = _rig.find_bone(str(spec.bone))
	if bone < 0:
		return {}
	var markers: Array[Node] = prop.find_children(str(spec.socket), "Node3D", true, false)
	if markers.size() != 1:
		return {}
	# Include the complete authored marker hierarchy and root transform.
	var cursor: Node3D = markers[0] as Node3D
	var local: Transform3D = Transform3D.IDENTITY
	while cursor != null and cursor != prop:
		local = cursor.transform * local
		cursor = cursor.get_parent() as Node3D
	if cursor != prop:
		return {}
	local = prop.transform * local
	if not local.is_finite() or absf(local.basis.determinant()) < 0.000001:
		return {}
	var scale: Vector3 = _rig.global_basis.get_scale()
	if not scale.is_finite() or scale.x <= 0.001 or absf(scale.x - scale.y) > 0.001 or absf(scale.x - scale.z) > 0.001 or _rig.global_basis.determinant() <= 0.0:
		return {}
	var rest: Basis = _rig.get_bone_global_rest(bone).basis.orthonormalized()
	if not rest.is_finite() or absf(rest.determinant()) < 0.000001:
		return {}
	var inverse: Basis = rest.inverse()
	var turn: Vector3 = spec.turn
	var offset: Vector3 = spec.offset
	var target: Transform3D = Transform3D((inverse * Basis.from_euler(turn)).scaled(Vector3.ONE / scale.x), inverse * offset / scale.x)
	var grip: Transform3D = target * local.affine_inverse()
	if not grip.is_finite():
		return {}
	return {"bone": str(spec.bone), "index": bone, "grip": grip}

func _all_live() -> bool:
	if _attachments.size() != _snapshot.size():
		return false
	for slot: String in _attachments:
		var attachment: BoneAttachment3D = get_attachment(slot)
		var prop: Variant = _props.get(slot)
		if attachment == null or attachment.get_parent() != _rig or not is_instance_valid(prop):
			return false
	return true

func _clear(notify: bool) -> void:
	finish_socket_switch()
	for value: Variant in _attachments.values():
		if is_instance_valid(value):
			value.free()
	_attachments.clear()
	_props.clear()
	_pieces.clear()
	_places.clear()
	_snapshot.clear()
	_detail = -1
	if notify:
		equipment_changed.emit()

func _reject_staged(staged: Dictionary, reason: String) -> bool:
	for row: Dictionary in staged.values():
		var attachment: BoneAttachment3D = row.attachment
		attachment.free()
	return _reject_snapshot(reason)

func _reject_snapshot(reason: String) -> bool:
	_clear(true)
	return _reject(reason)

func _reject(reason: String) -> bool:
	equipment_rejected.emit(reason)
	return false
