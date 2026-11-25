class_name CityMarketSignage
extends RefCounted
## Read-only sign layer for the six real stall meshes in the Roman test city.
## It never creates a WorldModel, player, currency, shop transaction or camera.

const MANIFEST_PATH := "res://assets/city_detail/shops/city_market_anchors.json"
const GROUP_NAME := "ImperathenMarketSign"
const OWNER_META := "imperathen_city_market_signage_v1"
const PROFILE_IDS := ["low", "balanced", "high", "very_high"]
const SHOP_COUNT := 6


static func install(city: Node3D, profile: String = "balanced") -> Dictionary:
	var result := {
		"ok":false, "status":"unavailable", "read_only":true,
		"shops":0, "signs":0, "removed":0, "missing_stalls":[],
		"world_model_created":false, "trading_enabled":false
	}
	if not is_instance_valid(city) or city.name != "RomanCity":
		result.status = "unsupported_city"
		return result
	if profile not in PROFILE_IDS:
		result.status = "unsupported_profile"
		return result
	if not FileAccess.file_exists(MANIFEST_PATH):
		result.status = "missing_manifest"
		return result
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if typeof(payload) != TYPE_DICTIONARY:
		result.status = "invalid_manifest"
		return result
	var data: Dictionary = payload
	if data.get("format","") != "imperathen-city-market-anchors" or int(data.get("version",0)) != 1:
		result.status = "invalid_manifest"
		return result
	if data.get("authoritative_commerce_enabled", true) != false or typeof(data.get("shops")) != TYPE_ARRAY or data.shops.size() != SHOP_COUNT:
		result.status = "invalid_manifest"
		return result
	var previous: Array[Node] = []
	var anchors: Array[Node3D] = []
	var entries: Array[Dictionary] = []
	var used: Dictionary = {}
	for candidate: Variant in data.shops:
		if typeof(candidate) != TYPE_DICTIONARY:
			result.status = "invalid_manifest"
			return result
		var entry: Dictionary = candidate
		var shop_id: String = str(entry.get("shop_id",""))
		var stand_name: String = str(entry.get("stand_node",""))
		var label_text: String = str(entry.get("display_label",""))
		if shop_id.is_empty() or stand_name.is_empty() or label_text.is_empty() or used.has(shop_id):
			result.status = "invalid_manifest"
			return result
		used[shop_id] = true
		var stand := city.find_child(stand_name, true, false) as Node3D
		if not is_instance_valid(stand):
			result.missing_stalls.append(stand_name)
			continue
		var old: Node = stand.get_node_or_null(NodePath(GROUP_NAME))
		if is_instance_valid(old) and old.get_meta(OWNER_META, false) != true:
			result.status = "foreign_sign_conflict"
			return result
		anchors.append(stand)
		previous.append(old)
		entries.append(entry)
	if not result.missing_stalls.is_empty():
		result.status = "incomplete_city"
		return result
	if profile == "low":
		result.removed = _remove_owned(previous)
		result.ok = true
		result.status = "disabled_for_low"
		result.shops = SHOP_COUNT
		return result
	# Build off-tree, preserving an existing working sign set until all
	# six manifest records and their original city nodes have been checked.
	var candidates: Array[Node3D] = []
	for entry: Dictionary in entries:
		candidates.append(_make_sign(str(entry.shop_id), str(entry.display_label), profile))
	result.removed = _remove_owned(previous)
	for i in anchors.size():
		anchors[i].add_child(candidates[i])
	result.ok = true
	result.status = "installed"
	result.shops = SHOP_COUNT
	result.signs = candidates.size()
	return result


static func _remove_owned(nodes: Array[Node]) -> int:
	var count := 0
	for node in nodes:
		if not is_instance_valid(node) or node.get_meta(OWNER_META, false) != true:
			continue
		node.get_parent().remove_child(node)
		node.free()
		count += 1
	return count


static func _make_sign(shop_id: String, title: String, profile: String) -> Node3D:
	var root := Node3D.new()
	root.name = GROUP_NAME
	root.set_meta(OWNER_META, true)
	root.set_meta("shop_id", shop_id)
	root.set_meta("commerce_connected", false)
	var board := MeshInstance3D.new()
	board.name = "WoodenNameboard"
	var geometry := BoxMesh.new()
	geometry.size = Vector3(3.0, 0.61, 0.085)
	board.mesh = geometry
	board.position = Vector3(0, 2.40, 1.62)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("60462e")
	wood.roughness = 0.94
	board.material_override = wood
	var range_limit := 58.0 if profile == "balanced" else 90.0
	board.visibility_range_end = range_limit
	board.visibility_range_end_margin = 6.0
	root.add_child(board)
	var lettering := Label3D.new()
	lettering.name = "SignText"
	lettering.text = title
	lettering.font_size = 38
	lettering.pixel_size = 0.006
	lettering.outline_size = 5
	lettering.modulate = Color("f5e9ca")
	lettering.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lettering.no_depth_test = false
	lettering.position = Vector3(0, 2.40, 1.685)
	lettering.visibility_range_end = range_limit
	lettering.visibility_range_end_margin = 6.0
	root.add_child(lettering)
	return root
