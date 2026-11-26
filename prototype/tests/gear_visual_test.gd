extends SceneTree
## Runtime models of the shop equipment: budgets, metric size, sockets, visible
## quality tiers and the pieces carried on the adult player's rig.

const Gear = preload("res://scripts/domain/gear_market.gd")
const Visuals = preload("res://scripts/visuals/gear_visuals.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
## Longest edge in metres of the near tier, from gear_profiles.json.
const LENGTHS := {"gladius": 0.68, "pugio": 0.33, "pilum": 2.0, "spear": 2.0, "cavalry_lance": 2.3, "scutum": 1.06,
	"cavalry_shield": 1.1, "sling": 0.62, "riding_horse": 2.02, "spatha": 0.9}
const HAND_SOCKET := {"hand_right": "SOCKET_RIGHT_HAND", "hand_left": "SOCKET_LEFT_HAND", "hip_right": "SOCKET_HIP", "hip_left": "SOCKET_HIP"}
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)


func _triangles(node: Node, with_fittings: bool, only_names: Variant = null) -> int:
	var total := 0
	var shapes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	for value: Node in shapes:
		var shape := value as MeshInstance3D
		if shape.mesh == null or (not with_fittings and str(shape.name).begins_with("Q_")):
			continue
		if only_names != null and not only_names.has(str(shape.name)):
			continue
		for surface in shape.mesh.get_surface_count():
			var arrays := shape.mesh.surface_get_arrays(surface)
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			total += (indices.size() if indices != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return total


func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for value: Node in node.find_children("*", "MeshInstance3D", true, false):
		var shape := value as MeshInstance3D
		if shape.mesh == null or str(shape.name).begins_with("Q_"):
			continue
		var box: AABB = shape.global_transform * shape.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func _main_material(prop: Node3D) -> BaseMaterial3D:
	for value: Node in prop.find_children("*", "MeshInstance3D", true, false):
		var shape := value as MeshInstance3D
		if shape.mesh == null or str(shape.name).begins_with("Q_"):
			continue
		for surface in shape.mesh.get_surface_count():
			var material := shape.get_active_material(surface) as BaseMaterial3D
			if material != null and material.albedo_texture != null:
				return material
	return null


func _fittings(prop: Node3D, visible_only: bool) -> Array[String]:
	var result: Array[String] = []
	for value: Node in prop.find_children("Q_*", "MeshInstance3D", true, false):
		if not visible_only or (value as MeshInstance3D).visible:
			result.append(str(value.name))
	result.sort()
	return result


func _run() -> void:
	var build_path := ProjectSettings.globalize_path("res://").path_join("../docs/20_meshy_assets/gear-build.json")
	var build: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(build_path)) if FileAccess.file_exists(build_path) else {}
	_check(build.get("new_generation_submitted", true) == false, "Build report states that no hosted generation was submitted")
	var stage := Node3D.new()
	root.add_child(stage)
	var catalog := Gear.catalog()
	for id: String in catalog.items:
		var entry: Dictionary = catalog.items[id]
		if not bool(entry.get("listed", true)):
			_check(Visuals.instantiate(id, 2) == null, "Held-back item has no prop: " + id)
			continue
		var record: Dictionary = build.get("gear", {}).get(str(entry.model), {})
		var permanent_names: Array[String] = []
		for accent: Variant in record.get("accents", []):
			if not str(accent).begins_with("Q_"):
				permanent_names.append(str(accent))
		var previous := 1 << 30
		for lod in int(entry.lods):
			var prop := Visuals.instantiate(id, 2, lod)
			_check(prop != null, "%s LOD %d instantiates" % [id, lod])
			if prop == null:
				continue
			stage.add_child(prop)
			var triangles := _triangles(prop, false)
			_check(triangles > 0 and triangles <= previous, "%s LOD %d does not grow (%d triangles)" % [id, lod, triangles])
			previous = triangles
			if not record.is_empty():
				var permanent := _triangles(prop, false, permanent_names)
				var expected_permanent := int(record.tiers[lod].get("permanent_triangles", 0))
				var base_triangles := triangles - permanent
				_check(permanent == expected_permanent, "%s LOD %d permanent fittings match exact build record (%d/%d)" % [id, lod, permanent, expected_permanent])
				_check(base_triangles > 0 and base_triangles <= int(record.tiers[lod].triangles) + 2, "%s LOD %d base mesh matches its unchanged build budget (%d/%d)" % [id, lod, base_triangles, int(record.tiers[lod].triangles)])
				var texture := _main_material(prop)
				_check(texture != null and texture.albedo_texture.get_width() <= int(record.tiers[lod].texture_edges.base_color), "%s LOD %d texture stays in budget" % [id, lod])
				_check(texture != null and texture.normal_enabled and texture.normal_texture != null, "%s LOD %d keeps its normal map" % [id, lod])
			if HAND_SOCKET.has(str(entry.attach)):
				_check(prop.find_child(HAND_SOCKET[str(entry.attach)], true, false) != null, "%s LOD %d carries its socket" % [id, lod])
			if lod == 0 and LENGTHS.has(id):
				var size := _bounds(prop).size
				var longest := maxf(size.x, maxf(size.y, size.z))
				_check(absf(longest - float(LENGTHS[id])) < 0.03 * float(LENGTHS[id]) + 0.01, "%s is metric: %.3f m, expected %.2f m" % [id, longest, float(LENGTHS[id])])
			stage.remove_child(prop)
			prop.free()
		# Visible quality: fittings and material state.
		if entry.has("fixed_quality"):
			continue
		var low := Visuals.instantiate(id, 0)
		var solid := Visuals.instantiate(id, 2)
		var fine := Visuals.instantiate(id, 4)
		var low_material := _main_material(low)
		var solid_material := _main_material(solid)
		var fine_material := _main_material(fine)
		_check(low_material != solid_material and fine_material != solid_material, id + ": each tier has its own material state")
		_check(low_material.roughness >= solid_material.roughness and solid_material.roughness >= fine_material.roughness and low_material.roughness > fine_material.roughness, id + ": worn is duller than master work")
		_check(low_material.detail_enabled and low_material.detail_mask != null and not solid_material.detail_enabled and not fine_material.detail_enabled, id + ": only worn tiers carry the rust film")
		_check(low_material.albedo_color.v < solid_material.albedo_color.v, id + ": worn is darker")
		if not _fittings(solid, false).is_empty():
			_check(_fittings(low, true) != _fittings(solid, true) or _fittings(fine, true) != _fittings(solid, true), id + ": fittings change with quality")
			for fitting: String in _fittings(low, true):
				_check(fitting.begins_with("Q_LE"), id + " Q0 shows only repair fittings: " + fitting)
			for fitting: String in _fittings(fine, true):
				_check(fitting.begins_with("Q_GE"), id + " Q4 shows only master fittings: " + fitting)
			_check(_fittings(solid, true).is_empty(), id + " Q2 is the plain model")
		for prop: Node3D in [low, solid, fine]:
			prop.free()
	# The sword tiers are the owner's explicit point: five distinct states.
	var states := {}
	for quality in 5:
		var sword := Visuals.instantiate("gladius", quality)
		var material := _main_material(sword)
		states["%s|%.3f|%.3f|%s" % [",".join(PackedStringArray(_fittings(sword, true))), material.roughness, material.albedo_color.v, str(material.detail_enabled)]] = true
		sword.free()
	_check(states.size() == 5, "The gladius has five visibly distinct quality states")
	_check(Visuals.fitting_visible("Q_GE3_GuardPlate", 3) and not Visuals.fitting_visible("Q_GE3_GuardPlate", 2) and Visuals.fitting_visible("Q_LE0_RepairThong", 0) and not Visuals.fitting_visible("Q_LE0_RepairThong", 1) and Visuals.fitting_visible("Shank", 0), "Fitting names decide visibility")
	# Horse and resource props: sockets and simple collision.
	var horse := Visuals.instantiate("riding_horse", 2)
	stage.add_child(horse)
	_check(horse.find_child("SOCKET_SADDLE", true, false) != null and horse.find_child("SOCKET_RIDER", true, false) != null and horse.find_child("SOCKET_HEAD", true, false) != null, "Horse carries saddle, rider and head sockets")
	_check(not horse.find_children("*", "CollisionShape3D", true, false).is_empty(), "Horse has a simplified collision body")
	_check(horse.find_children("*", "Skeleton3D", true, false).is_empty(), "Horse is a static model: riding is not claimed")
	var saddle := horse.find_child("SOCKET_SADDLE", true, false) as Node3D
	_check(saddle != null and saddle.position.y > 1.2 and saddle.position.y < 1.6, "Back height suits an ancient cavalry horse: %.2f m" % (saddle.position.y if saddle else 0.0))
	stage.remove_child(horse)
	horse.free()
	for resource: String in ["resource_firewood", "resource_iron_ore", "resource_clay", "resource_limestone", "resource_copper_ore"]:
		for lod in 3:
			var path := "res://assets/meshy/props/%s_%d.glb" % [resource, lod]
			_check(ResourceLoader.exists(path, "PackedScene"), "Resource prop exists: " + path)
			if lod == 0 and ResourceLoader.exists(path, "PackedScene"):
				var prop := (load(path) as PackedScene).instantiate() as Node3D
				stage.add_child(prop)
				_check(not prop.find_children("*", "CollisionShape3D", true, false).is_empty(), resource + " has a collision hull")
				_check(absf(_bounds(prop).position.y) < 0.02, resource + " stands on the ground")
				stage.remove_child(prop)
				prop.free()
	# Carried on the character.
	var pieces: Array = [
		{"slot": "main_hand", "item_id": "gladius", "quality": 3, "wear": 0.0, "model": "weap_roman_gladius_pompeii", "model_dir": "equipment", "lods": 3, "attach": "hand_right"},
		{"slot": "sidearm", "item_id": "pugio", "quality": 2, "wear": 0.0, "model": "weap_roman_pugio", "model_dir": "equipment", "lods": 3, "attach": "hip_right"},
		{"slot": "missile", "item_id": "pilum", "quality": 2, "wear": 0.0, "model": "weap_roman_pilum", "model_dir": "equipment", "lods": 3, "attach": "hand_right"},
		{"slot": "shield", "item_id": "scutum", "quality": 1, "wear": 0.0, "model": "gear_roman_scutum", "model_dir": "equipment", "lods": 3, "attach": "hand_left"},
		{"slot": "mount", "item_id": "riding_horse", "quality": 2, "wear": 0.0, "model": "mount_legacy_bay_horse", "model_dir": "mounts", "lods": 3, "attach": "stable"}]
	var placed := Visuals.placements(pieces)
	_check(placed.size() == 4 and placed[2].place == "back", "The pilum goes on the back while the gladius is in hand; the horse stays in the stable")
	var actor := Person.new()
	stage.add_child(actor)
	actor.set_process(false)
	actor.configure("player", "italia", 12)
	actor.set_market_gear(pieces)
	_check(actor._market_nodes.is_empty() and actor._market_gear.is_empty(), "The twelve-year-old shows no shop equipment even if a caller asks")
	actor.configure("player", "italia", 18)
	actor.set_market_gear(pieces)
	await process_frame
	_check(actor._market_nodes.size() == 4, "Adult carries four pieces (%d)" % actor._market_nodes.size())
	var rig := actor.body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for node: Node3D in actor._market_nodes:
		var attachment := node as BoneAttachment3D
		var place := str(attachment.get_meta("place"))
		var socket := attachment.find_child(str(Visuals.ATTACH[place].socket), true, false) as Node3D
		_check(socket != null, "Carried piece keeps its socket: " + place)
		if socket == null:
			continue
		var reach := socket.global_position.distance_to(attachment.global_position)
		_check(reach < 0.36 * rig.global_transform.basis.get_scale().x, "%s sits at its bone (%.3f m away)" % [place, reach])
		var prop := attachment.find_child("Prop", true, false) as Node3D
		_check(absf(prop.global_transform.basis.get_scale().y - 1.0) < 0.02, "%s keeps its real size on the scaled body" % place)
		_check(str(attachment.get_meta("model_path")).ends_with("_0.glb"), "Near body uses the near tier: " + place)
	var hand := rig.find_bone("Hand_R")
	var sword := actor._market_nodes[0] as BoneAttachment3D
	var before := sword.global_position
	rig.set_bone_pose_rotation(hand, rig.get_bone_pose_rotation(hand) * Quaternion(Vector3.RIGHT, 0.4))
	var arm := rig.find_bone("Arm_R")
	rig.set_bone_pose_rotation(arm, rig.get_bone_pose_rotation(arm) * Quaternion(Vector3.FORWARD, 0.5))
	await process_frame
	_check(sword.global_position.distance_to(before) > 0.02, "The sword follows the moving hand")
	_check(not (sword.find_child("Q_GE3_GuardPlate", true, false) as MeshInstance3D == null) and (sword.find_child("Q_GE3_GuardPlate", true, false) as MeshInstance3D).visible, "The carried Q3 gladius shows its brass guard plate")
	actor._reload(3)
	_check(actor._market_nodes.size() == 4, "A body LOD change keeps the pieces")
	for node: Node3D in actor._market_nodes:
		_check(str(node.get_meta("model_path")).ends_with("_2.glb"), "Far body uses the far tier")
	actor.set_market_gear(pieces)
	_check(actor.body.find_children("MarketGear_*", "BoneAttachment3D", true, false).size() == 4, "Setting the same pieces again creates no duplicates")
	actor.set_market_gear([])
	_check(actor._market_nodes.is_empty() and actor.body.find_children("MarketGear_*", "BoneAttachment3D", true, false).is_empty(), "Unequipping removes the pieces")
	actor.configure("resident", "italia", 30)
	actor.set_market_gear(pieces)
	_check(actor._market_nodes.is_empty(), "Only the player shows bought equipment")
	actor.free()
	stage.free()
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("GEAR_VISUALS_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("GEAR_VISUALS_PASS" if failures.is_empty() else "GEAR_VISUALS_FAIL")
	quit(0 if failures.is_empty() else 1)
