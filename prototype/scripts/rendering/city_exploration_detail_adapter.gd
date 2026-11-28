class_name CityExplorationDetailAdapter
extends RefCounted
## Optional local art details for the observed 5b5eecad RomanCity hierarchy.
## Keeps the existing city, Meshy temple, player, camera, save and trade authority.

const Architecture := preload("res://scripts/rendering/city_architecture_detail.gd")
const GROUP_NAME := "CityArchitectureSupport"
const OWNER_META := "imperathen_city_exploration_detail_adapter"
const OWNER_VERSION := 1
const STREET_NAME := "Main_Streets"
const POTTERY_NAME := "Market_32_Type3_Build1_Size1"
const FOOD_NAME := "Market_35_Type6_Build1_Size1"
const SURFACE_HEIGHT := 0.115
const PROFILE_IDS := ["low", "balanced", "high", "very_high"]


static func install(city_root: Node3D, profile: String = "balanced") -> Dictionary:
	var report := {
		"ok": false, "status": "unsupported_city", "profile": profile,
		"created_groups": 0, "removed_groups": 0, "paving_instances": 0,
		"local_collision_bodies": 0, "surface_height": SURFACE_HEIGHT,
		"missing_nodes": [], "reason": "",
	}
	if not is_instance_valid(city_root) or city_root.name != "RomanCity":
		report.reason = "Expected the existing RomanCity node; nothing changed."
		return report
	if profile not in PROFILE_IDS:
		report.status = "unsupported_profile"
		report.reason = "Unknown quality profile; nothing changed."
		return report
	var street := city_root.find_child(STREET_NAME, true, false) as Node3D
	var pottery := city_root.find_child(POTTERY_NAME, true, false) as Node3D
	var food := city_root.find_child(FOOD_NAME, true, false) as Node3D
	for pair: Array in [[STREET_NAME, street], [POTTERY_NAME, pottery], [FOOD_NAME, food]]:
		if not is_instance_valid(pair[1]):
			report.missing_nodes.append(pair[0])
	if not report.missing_nodes.is_empty():
		report.reason = "The observed street/market hierarchy is incomplete; nothing changed."
		return report
	var parents: Array[Node3D] = [city_root, pottery, food]
	var previous: Array[Node] = []
	for parent in parents:
		var existing := parent.get_node_or_null(NodePath(GROUP_NAME))
		if existing != null and existing.get_meta(OWNER_META, 0) != OWNER_VERSION:
			report.status = "foreign_group_conflict"
			report.reason = "An unrelated node already uses the support name; nothing changed."
			return report
		previous.append(existing)
	if not ResourceLoader.exists(Architecture.LIBRARY_PATH, "PackedScene") or not FileAccess.file_exists(Architecture.MANIFEST_PATH):
		report.status = "detail_assets_unavailable"
		report.reason = "Detail resources are not imported; existing city and details remain."
		return report
	# Graphics profiles change visual LOD and range, never the walkable
	# surface or the physical market objects. LOD2 retains their silhouette.
	var lod := 2 if profile == "low" else (1 if profile == "balanced" else 0)
	var distance_limit := 45.0 if profile == "low" else (75.0 if profile == "balanced" else (100.0 if profile == "high" else 130.0))
	var road_group := _new_group("street")
	road_group.transform = _relative_transform(street, city_root)
	var placements: Array[Transform3D] = []
	for x: float in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		for z: float in [60.0, 64.0, 68.0]:
			placements.append(Transform3D(Basis.IDENTITY, Vector3(x, SURFACE_HEIGHT, z)))
	var paving := Architecture.create_multimesh("basoli_4m", placements, lod)
	var pottery_group := _new_group("pottery")
	var amphorae := Architecture.create_module("amphora_pair", lod, true)
	var food_group := _new_group("food")
	var counter := Architecture.create_module("dolia_counter", lod, true)
	if paving == null or amphorae == null or counter == null:
		for candidate in [paving, amphorae, counter, road_group, pottery_group, food_group]:
			if is_instance_valid(candidate):
				candidate.free()
		report.status = "detail_build_failed"
		report.reason = "Could not build all detail resources; existing city and details remain."
		return report
	road_group.add_child(paving)
	_add_walk_surface(road_group)
	amphorae.position = Vector3(3.3, 0, 0)
	pottery_group.add_child(amphorae)
	# The original stand is 4.6 m wide. This 2.6 m counter stays beside it,
	# outside its central approach and well inside the 12.419 m plot spacing.
	counter.position = Vector3(3.85, 0, 0)
	food_group.add_child(counter)
	var candidates: Array[Node3D] = [road_group, pottery_group, food_group]
	for candidate in candidates:
		_set_visibility(candidate, distance_limit)
	# Build off-tree first. A failure never deletes an already working detail set.
	report.removed_groups = _remove_owned(previous)
	for index in parents.size():
		parents[index].add_child(candidates[index])
	report.ok = true
	report.status = "installed"
	report.created_groups = candidates.size()
	report.paving_instances = placements.size()
	report.local_collision_bodies = 3
	report.lod = lod
	report.visibility_distance = distance_limit
	report.reason = "Local architecture details installed; existing city authority preserved."
	return report


static func _new_group(role: String) -> Node3D:
	var group := Node3D.new()
	group.name = GROUP_NAME
	group.set_meta(OWNER_META, OWNER_VERSION)
	group.set_meta("detail_role", role)
	return group


static func _remove_owned(nodes: Array[Node]) -> int:
	var count := 0
	for node in nodes:
		if not is_instance_valid(node) or node.get_meta(OWNER_META, 0) != OWNER_VERSION:
			continue
		node.get_parent().remove_child(node)
		node.free()
		count += 1
	return count


static func _relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


static func _set_visibility(group: Node3D, distance_limit: float) -> void:
	for child in group.find_children("*", "GeometryInstance3D", true, false):
		var geometry := child as GeometryInstance3D
		geometry.visibility_range_end = distance_limit
		geometry.visibility_range_end_margin = 5.0


static func _add_walk_surface(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "LocalStreetSurface"
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.name = "SurfaceBox"
	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 0.02, 12.0)
	collision.shape = shape
	collision.position = Vector3(0, SURFACE_HEIGHT - 0.01, 64.0)
	body.add_child(collision)
	parent.add_child(body)
