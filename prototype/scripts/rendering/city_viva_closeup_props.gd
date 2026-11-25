extends RefCounted
## Visual attachment of existing VIVA ROMA glTF assets to existing RomanCity
## architecture. Never creates a second city, navigation body or gameplay state.
const ROOT_NAME := "VivaCloseupVisuals"
const OWNER := "imperathen_viva_closeup_v1"
const PREFIX := "res://assets/viva_roma/props/"
const SHOP_FRONTS := ["Pistrinum_Bakery","Fabrica_Blacksmith","Mercator_Store"]
const ARMORER := "Market_34_Type5_Build1_Size1"

static func install(city: Node3D, profile: String = "balanced") -> Dictionary:
	var report := {"ok": false,"status":"not_installed","profile":profile,
		"portals":0,"helmets":0,"originals_modified":0,"colliders_added":0,
		"missing":[],"loaded_lod":-1}
	if not is_instance_valid(city) or city.name != "RomanCity":
		report.status = "unsupported_city"
		return report
	if profile not in ["low","balanced","high","very_high"]:
		report.status = "invalid_profile"
		return report
	var requested: Array[String] = []
	if profile != "low":
		for shop: String in SHOP_FRONTS:
			requested.append(shop)
		requested.append(ARMORER)
	var originals: Dictionary = {}
	for node_name: String in requested:
		var original := city.find_child(node_name,true,false) as Node3D
		if not is_instance_valid(original):
			report.missing.append(node_name)
		else:
			originals[node_name] = original
	if not report.missing.is_empty():
		report.status = "missing_original_mesh"
		return report
	var existing := city.get_node_or_null(NodePath(ROOT_NAME))
	if is_instance_valid(existing) and existing.get_meta(OWNER,false) != true:
		report.status = "foreign_visual_conflict"
		return report
	if profile == "low":
		if is_instance_valid(existing):
			city.remove_child(existing)
			existing.free()
		report.ok = true
		report.status = "disabled_low"
		return report
	var level: int = 1 if profile == "balanced" else 0
	var portal_path := PREFIX + "portal_lod%d.glb" % level
	var helmet_path := PREFIX + "helmet_lod%d.glb" % level
	var portal_resource: PackedScene = null
	var helmet_resource: PackedScene = null
	if ResourceLoader.exists(portal_path,"PackedScene"):
		portal_resource = load(portal_path) as PackedScene
	if ResourceLoader.exists(helmet_path,"PackedScene"):
		helmet_resource = load(helmet_path) as PackedScene
	if not is_instance_valid(portal_resource) or not is_instance_valid(helmet_resource):
		report.status = "missing_packed_gltf"
		return report
	# Prepare off-tree and only change presentation after all authoritative
	# originals and both original GLBs passed the availability checks.
	var visual := Node3D.new()
	visual.name = ROOT_NAME
	visual.set_meta(OWNER,true)
	visual.set_meta("visual_only",true)
	visual.set_meta("texture_source","VIVA ROMA original GLB")
	var created: Array[Node3D] = []
	for shop: String in SHOP_FRONTS:
		var portal := portal_resource.instantiate() as Node3D
		if portal == null:
			visual.free()
			report.status = "invalid_portal_scene"
			return report
		portal.name = shop + "_VivaPortal"
		portal.position = Vector3(0.0,0.0,5.03)
		portal.set_meta("source_shop",shop)
		var anchor := Node3D.new()
		anchor.name = shop + "_Anchor"
		anchor.transform = city.global_transform.affine_inverse()*originals[shop].global_transform
		visual.add_child(anchor)
		anchor.add_child(portal)
		created.append(portal)
	var display := helmet_resource.instantiate() as Node3D
	if display == null:
		visual.free()
		report.status = "invalid_helmet_scene"
		return report
	display.name = "Armorer_VivaHelmet"
	display.position = Vector3(-0.8,1.105,0.45)
	var helmet_anchor := Node3D.new()
	helmet_anchor.name = "Armorer_HelmetAnchor"
	helmet_anchor.transform = city.global_transform.affine_inverse()*originals[ARMORER].global_transform
	visual.add_child(helmet_anchor)
	helmet_anchor.add_child(display)
	created.append(display)
	for instance: Node3D in created:
		if instance.find_children("*","MeshInstance3D",true,false).is_empty():
			visual.free()
			report.status = "missing_actual_geometry"
			return report
		if not instance.find_children("*","CollisionObject3D",true,false).is_empty():
			visual.free()
			report.status = "unexpected_physics_in_visual_asset"
			return report
	if is_instance_valid(existing):
		city.remove_child(existing)
		existing.free()
	city.add_child(visual)
	report.portals = SHOP_FRONTS.size()
	report.helmets = 1
	report.loaded_lod = level
	report.ok = true
	report.status = "installed"
	return report
