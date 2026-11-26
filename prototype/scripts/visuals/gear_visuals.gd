extends RefCounted
## Bought equipment as it is seen: a prop on a shop table, or carried on a rig.
## Presentation only. Which piece someone owns and wears is decided by
## scripts/domain/gear_market.gd; this helper never grants or changes anything.
##
## Quality is visible in two ways (handbook p. 82): material state on the
## textured mesh (rust film and dullness for Q0/Q1, polish for Q3/Q4) and
## small authored fittings inside the same GLB. A fitting node is named
## Q_GE<n>_… (shown from quality n upward) or Q_LE<n>_… (shown up to n).

const Gear = preload("res://scripts/domain/gear_market.gd")
const WEAR_EDGE := 128
## Where a piece sits on the rig. Offsets are metres in skeleton space at rest:
## the character faces +Z there, its right side is -X.
const ATTACH := {
	"hand_right": {"bone": "Hand_R", "socket": "SOCKET_RIGHT_HAND", "offset": Vector3(0.02, -0.055, 0.095), "turn": Vector3(0, PI / 2, 0)},
	"hand_left": {"bone": "Hand_L", "socket": "SOCKET_LEFT_HAND", "offset": Vector3(-0.02, -0.055, 0.095), "turn": Vector3.ZERO},
	"hip_right": {"bone": "Pelvis", "socket": "SOCKET_HIP", "offset": Vector3(-0.19, 0.03, 0.03), "turn": Vector3(0.12, 0, PI)},
	"hip_left": {"bone": "Pelvis", "socket": "SOCKET_HIP", "offset": Vector3(0.19, 0.04, 0.04), "turn": Vector3.ZERO},
	"back": {"bone": "Spine", "socket": "SOCKET_BACK", "offset": Vector3(-0.06, 0.2, -0.15), "turn": Vector3(0, 0, -0.3)}
}
static var _scenes: Dictionary = {}
static var _materials: Dictionary = {}
static var _wear_masks: Dictionary = {}
static var _rust: ImageTexture


## A free-standing prop with the look of its quality, or null without a model.
static func instantiate(item_id: String, quality: int, lod: int = 0) -> Node3D:
	var path := Gear.model_path(item_id, lod)
	if path.is_empty():
		return null
	if not _scenes.has(path):
		_scenes[path] = load(path) as PackedScene if ResourceLoader.exists(path, "PackedScene") else null
	if not _scenes[path] is PackedScene:
		return null
	var prop := (_scenes[path] as PackedScene).instantiate() as Node3D
	if prop == null:
		return null
	prop.set_meta("gear_item", item_id)
	prop.set_meta("gear_quality", quality)
	prop.set_meta("model_path", path)
	apply_quality(prop, quality)
	return prop


static func fitting_visible(node_name: String, quality: int) -> bool:
	if node_name.begins_with("Q_GE") and node_name.length() > 4:
		return quality >= int(node_name.substr(4, 1))
	if node_name.begins_with("Q_LE") and node_name.length() > 4:
		return quality <= int(node_name.substr(4, 1))
	return true


static func apply_quality(prop: Node3D, quality: int) -> void:
	var tiers: Array = Gear.catalog().get("quality", [])
	if quality < 0 or quality >= tiers.size():
		return
	var look: Dictionary = tiers[quality].look
	var meshes: Array[Node] = prop.find_children("*", "MeshInstance3D", true, false)
	if prop is MeshInstance3D:
		meshes.append(prop)
	for node: Node in meshes:
		var shape := node as MeshInstance3D
		var fitting := str(shape.name).begins_with("Q_")
		if fitting:
			shape.visible = fitting_visible(str(shape.name), quality)
			continue
		if shape.mesh == null or quality == 2:
			continue
		for surface in shape.mesh.get_surface_count():
			var source := shape.mesh.surface_get_material(surface) as BaseMaterial3D
			# Authored single-colour fittings (shank, head) keep their material.
			if source == null or source.albedo_texture == null:
				continue
			shape.set_surface_override_material(surface, _variant(source, quality, look))


static func _variant(source: BaseMaterial3D, quality: int, look: Dictionary) -> BaseMaterial3D:
	var key := "%d:%d" % [source.get_rid().get_id(), quality]
	if _materials.has(key):
		return _materials[key]
	var material := source.duplicate() as BaseMaterial3D
	var tint: Array = look.tint
	material.albedo_color = Color(source.albedo_color.r * float(tint[0]), source.albedo_color.g * float(tint[1]), source.albedo_color.b * float(tint[2]), source.albedo_color.a)
	material.roughness = clampf(source.roughness * float(look.roughness), 0.04, 1.0)
	material.metallic = clampf(source.metallic * float(look.metallic), 0.0, 1.0)
	var wear := float(look.get("wear", 0.0))
	if wear > 0.0:
		material.detail_enabled = true
		material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		material.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
		material.detail_albedo = _rust_texture()
		material.detail_mask = _wear_mask(wear)
	_materials[key] = material
	return material


static func _noise(x: int, y: int, cell: int, seed_value: int) -> float:
	# Tileable value noise from an integer hash; deterministic on every device.
	var period := WEAR_EDGE / cell
	var gx := x / cell
	var gy := y / cell
	var fx := float(x % cell) / cell
	var fy := float(y % cell) / cell
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var corner := func(cx: int, cy: int) -> float:
		var h := hash(Vector3i(cx % period, cy % period, seed_value))
		return float(h % 1000) / 999.0
	return lerpf(lerpf(corner.call(gx, gy), corner.call(gx + 1, gy), fx), lerpf(corner.call(gx, gy + 1), corner.call(gx + 1, gy + 1), fx), fy)


static func _wear_mask(wear: float) -> ImageTexture:
	var key := roundi(wear * 100.0)
	if _wear_masks.has(key):
		return _wear_masks[key]
	var image := Image.create(WEAR_EDGE, WEAR_EDGE, false, Image.FORMAT_RGBA8)
	for y in WEAR_EDGE:
		for x in WEAR_EDGE:
			var blotch := 0.55 * _noise(x, y, 32, 11) + 0.3 * _noise(x, y, 16, 23) + 0.15 * _noise(x, y, 4, 37)
			# A thin film everywhere plus patches where moisture sat.
			var value := clampf(wear * (0.22 + 1.5 * smoothstep(0.46, 0.7, blotch)), 0.0, 0.9)
			image.set_pixel(x, y, Color(value, value, value, 1.0))
	image.generate_mipmaps()
	_wear_masks[key] = ImageTexture.create_from_image(image)
	return _wear_masks[key]


static func _rust_texture() -> ImageTexture:
	if _rust == null:
		var image := Image.create(WEAR_EDGE, WEAR_EDGE, false, Image.FORMAT_RGBA8)
		for y in WEAR_EDGE:
			for x in WEAR_EDGE:
				var grain := 0.6 * _noise(x, y, 8, 53) + 0.4 * _noise(x, y, 2, 71)
				image.set_pixel(x, y, Color(0.27, 0.13, 0.06).lerp(Color(0.5, 0.29, 0.13), grain))
		image.generate_mipmaps()
		_rust = ImageTexture.create_from_image(image)
	return _rust


## Where each equipped piece is carried. A thrown or long weapon moves to the
## back when the right hand already holds the main weapon.
static func placements(pieces: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var right_hand_taken := false
	for piece: Dictionary in pieces:
		if str(piece.get("slot", "")) == "main_hand" and str(piece.get("attach", "")) == "hand_right":
			right_hand_taken = true
	for piece: Dictionary in pieces:
		var place := str(piece.get("attach", ""))
		if place == "hand_right" and right_hand_taken and str(piece.get("slot", "")) != "main_hand":
			place = "back"
		if not ATTACH.has(place):
			continue
		var entry: Dictionary = piece.duplicate()
		entry["place"] = place
		result.append(entry)
	return result


static func clear(model: Node3D) -> void:
	if model == null:
		return
	for skeleton: Node in model.find_children("*", "Skeleton3D", true, false):
		for child: Node in skeleton.get_children():
			if child.get_meta("market_gear", false):
				skeleton.remove_child(child)
				child.free()


## Attaches the equipped pieces (GearMarket.equipped_models) to the first rig
## below model. detail is the body LOD 0-3. Returns the attachment nodes.
static func attach(model: Node3D, pieces: Array, detail: int) -> Array[Node3D]:
	var result: Array[Node3D] = []
	clear(model)
	if model == null or pieces.is_empty():
		return result
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty():
		return result
	var rig := rigs[0] as Skeleton3D
	var scale := rig.global_transform.basis.get_scale() if rig.is_inside_tree() else model.scale
	for piece: Dictionary in placements(pieces):
		var spec: Dictionary = ATTACH[piece.place]
		var bone := rig.find_bone(str(spec.bone))
		if bone < 0:
			continue
		var lods := int(piece.get("lods", 1))
		var lod := mini(detail, lods - 1) if lods > 2 else (0 if detail <= 1 else lods - 1)
		var prop := instantiate(str(piece.item_id), int(piece.quality), lod)
		if prop == null:
			continue
		var socket := prop.find_child(str(spec.socket), true, false) as Node3D
		if socket == null:
			prop.free()
			continue
		var attachment := BoneAttachment3D.new()
		attachment.name = "MarketGear_" + str(piece.slot)
		attachment.bone_name = str(spec.bone)
		attachment.override_pose = false
		attachment.set_meta("market_gear", true)
		attachment.set_meta("item_id", str(piece.item_id))
		attachment.set_meta("quality", int(piece.quality))
		attachment.set_meta("place", str(piece.place))
		attachment.set_meta("model_path", str(prop.get_meta("model_path", "")))
		rig.add_child(attachment)
		var grip := Node3D.new()
		grip.name = "Grip"
		var inverse := rig.get_bone_global_rest(bone).basis.orthonormalized().inverse()
		var turn: Vector3 = spec.turn
		grip.basis = inverse * Basis.from_euler(turn)
		grip.position = inverse * (spec.offset as Vector3)
		# Keep the piece at its real size on a scaled body.
		if scale.x > 0.001:
			grip.scale = Vector3.ONE / scale.x
		attachment.add_child(grip)
		var align := Node3D.new()
		align.name = "SocketAlignment"
		align.position = -socket.position
		grip.add_child(align)
		prop.name = "Prop"
		align.add_child(prop)
		result.append(attachment)
	return result
