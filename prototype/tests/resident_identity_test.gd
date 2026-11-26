extends SceneTree
## Named residents and generic villagers: identity coverage, uniqueness, the
## owner's distinct pairs (D-018), LOD consistency, triangle/texture budgets
## per graphics profile and CPU-skinned clipping of identity pieces.

const Person := preload("res://scripts/visuals/village_person.gd")
const Identity := preload("res://scripts/visuals/resident_identity.gd")
const Look := preload("res://scripts/visuals/resident_look.gd")
const Layout := preload("res://scripts/world/village/village_layout.gd")
const Economy := preload("res://scripts/domain/village_economy.gd")
const Childhood := preload("res://scripts/story/village_childhood.gd")
const SkinFixture := preload("res://tests/motion_skin_measurement.gd")
## Same all-mesh tier budgets as frontier_people_test.gd; here only visible
## meshes of the configured person count, which is what is drawn.
const BUDGETS := [24000, 10000, 3500, 1300]
const MIN_FACE_DISTANCE := 0.9
const D018 := [["nerva", "sextus"], ["livia", "cassia"], ["priscilla", "aurelia"]]
const SOLDIER_KINDS := ["legionary", "officer", "spearman", "archer"]
## Unique texture memory for a village crowd at these camera distances, per
## profile, as imported here. Limits are this pass's measured values rounded
## up, so any growth has to be a deliberate decision. Most of it is the
## pre-existing frontier GLB textures (extracted lossless); the identity layer
## itself (shared masks and piece maps) is limited separately.
const CROWD_DISTANCES := [1.4, 3.0, 5.0, 8.0, 12.0, 18.0, 26.0, 36.0]
const TEXTURE_LIMIT_MIB := {"low": 38.0, "balanced": 58.0, "high": 60.0, "very_high": 68.0}
const IDENTITY_TEXTURE_LIMIT_MIB := 4.0
const PENETRATION_M := 0.006
const FAMILIES := {"Pelvis": ["Pelvis", "Spine", "Thigh_L", "Thigh_R"], "Spine": ["Spine", "Pelvis", "Arm_L", "Arm_R"],
	"Thigh_L": ["Thigh_L", "Pelvis", "Spine"], "Thigh_R": ["Thigh_R", "Pelvis", "Spine"],
	"Arm_L": ["Arm_L", "Spine"], "Arm_R": ["Arm_R", "Spine"], "Head": ["Head"]}
var checks := 0
var failures := 0
var report := {"budgets": {}, "clipping": {}, "textures": {}, "pairs": {}}


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)


## Every person the two live builders create, with the builder's appearance.
static func named() -> Dictionary:
	var result := {}
	for person: Dictionary in Economy.PEOPLE:
		var id := str(person.id)
		var appearance := "civilian_woman" if id in ["aelia", "aurelia", "cassia", "drusa", "julia", "valeria", "antonia"] else "civilian_man"
		result[id] = "legionary" if id == "severus" else appearance
	result["decimus"] = "elder"
	for item: Dictionary in Layout.RESIDENTS:
		result[str(item.id)] = str(item.appearance)
	for id: String in Childhood.EXTRA_NPCS:
		if not result.has(id):
			result[id] = ""
	for id: String in Childhood.NEIGHBORS:
		if not result.has(id):
			result[id] = ""
	return result


func _distance(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var total := 0.0
	for i in mini(a.size(), b.size()):
		total += (a[i] - b[i]) * (a[i] - b[i])
	return sqrt(total)


func _applied_face(look: Dictionary) -> PackedFloat32Array:
	# Soldier models carry no identity keys: only skin and hair are applied.
	var copy := look.duplicate(true)
	if look.get("soldier", false):
		for key: String in copy.face:
			copy.face[key] = 0.0
		copy.build = {}
	return Identity.face_vector(copy)


func _run() -> void:
	var people := named()
	var looks := {}
	for id: String in people:
		if Identity.EXTERNAL.has(id):
			continue
		_check(Identity.has_person(id), id + " has an authored visual identity")
		if Identity.has_person(id):
			looks[id] = Identity.look(id, str(people[id]), 0, 30)
			var kind := str(looks[id].kind)
			var expected := str(people[id])
			_check(expected.is_empty() or kind == expected, "%s identity kind %s matches its live appearance %s" % [id, kind, expected])
	_uniqueness(looks)
	_pairs(looks)
	_generic()
	_runtime(looks, people)
	_textures(looks)
	_clipping(looks)
	var file := FileAccess.open("user://resident_identity_report.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
	print("RESIDENT_IDENTITY_REPORT ", JSON.stringify(report))
	print("RESIDENT_IDENTITY ", checks, " checks, ", failures, " failed")
	quit(0 if failures == 0 else 1)


func _uniqueness(looks: Dictionary) -> void:
	var ids: Array = looks.keys()
	ids.sort()
	var signatures := {}
	var closest := INF
	var closest_pair := []
	for i in ids.size():
		var a: Dictionary = looks[ids[i]]
		var face_a := _applied_face(a)
		var signature := "%s#%s" % [Identity.outfit_signature(a), str(Array(face_a).map(func(v): return snappedf(v, 0.1)))]
		_check(not signatures.has(signature), "%s and %s share face and clothing" % [ids[i], signatures.get(signature, "")])
		signatures[signature] = ids[i]
		for j in range(i + 1, ids.size()):
			var b: Dictionary = looks[ids[j]]
			var distance := _distance(face_a, _applied_face(b))
			if a.get("soldier", false) or b.get("soldier", false):
				# Shared kit and head geometry: identity rests on skin/hair only.
				_check(distance >= 0.25, "%s/%s soldiers differ in skin or hair (%.2f)" % [ids[i], ids[j], distance])
				continue
			_check(Identity.outfit_signature(a) != Identity.outfit_signature(b), "%s/%s outfits are distinct" % [ids[i], ids[j]])
			if a.kind != b.kind:
				continue  # different base anatomy (man, woman, elder) already differs
			if distance < closest:
				closest = distance
				closest_pair = [ids[i], ids[j]]
			_check(distance >= MIN_FACE_DISTANCE, "%s/%s faces are distinct (%.2f)" % [ids[i], ids[j], distance])
	report["closest_civilian_faces"] = {"pair": closest_pair, "distance": snappedf(closest, 0.001)}


func _pairs(looks: Dictionary) -> void:
	for pair: Array in D018:
		var a: Dictionary = looks[pair[0]]
		var b: Dictionary = looks[pair[1]]
		var distance := _distance(_applied_face(a), _applied_face(b))
		var differences := 0
		differences += int(absf(float(a.look_age) - float(b.look_age)) >= 5)
		differences += int((a.hair.color as Color) != (b.hair.color as Color) or absf(float(a.hair.grey) - float(b.hair.grey)) > 0.2)
		differences += int(Look.visible_pieces(a) != Look.visible_pieces(b))
		differences += int((a.wear.tunic as Color) != (b.wear.tunic as Color))
		differences += int(a.kind != b.kind or absf(float(a.build.ID_Heavy) - float(b.build.ID_Heavy)) > 0.4)
		report.pairs["%s/%s" % pair] = {"face_distance": snappedf(distance, 0.01), "visible_differences": differences}
		_check(distance >= MIN_FACE_DISTANCE * 1.5, "D-018 %s and %s have clearly different faces" % pair)
		_check(differences >= 4, "D-018 %s and %s differ in age, hair, wear, colour and build" % pair)


func _generic() -> void:
	for appearance: String in ["civilian_man", "civilian_woman", "elder"]:
		var seen := {}
		var vectors: Array[PackedFloat32Array] = []
		for variation in 18:
			var look := Identity.look("", appearance, variation, 34)
			var signature := Identity.outfit_signature(look) + "#" + str(Array(Identity.face_vector(look)).map(func(v): return snappedf(v, 0.1)))
			_check(not seen.has(signature), "%s variant %d is not a clone of %s" % [appearance, variation, seen.get(signature, -1)])
			seen[signature] = variation
			var vector := Identity.face_vector(look)
			for other in vectors:
				_check(_distance(vector, other) >= MIN_FACE_DISTANCE, "%s variant %d face differs from earlier variants" % [appearance, variation])
			vectors.append(vector)
		_check(Identity.look("", appearance, 4, 34).hash() == Identity.look("", appearance, 4, 34).hash(), appearance + " generic look is deterministic")


func _spawn(id: String, appearance: String, look: Dictionary) -> Person:
	var actor := Person.new()
	root.add_child(actor)
	actor.set_process(false)
	actor.configure_resident("italia", int(look.look_age), appearance, 3, null, id)
	return actor


func _visible_triangles(person: Person) -> int:
	var count := 0
	for mesh: MeshInstance3D in person.body.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh and mesh.is_visible_in_tree():
			for surface in mesh.mesh.get_surface_count():
				count += mesh.mesh.surface_get_array_index_len(surface) / 3
	return count


func _runtime(looks: Dictionary, people: Dictionary) -> void:
	var worst := [0, 0, 0, 0]
	var worst_shapes := [0, 0, 0, 0]
	var worst_meshes := [0, 0, 0, 0]
	for id: String in looks:
		var look: Dictionary = looks[id]
		var appearance := str(people[id]) if not str(people[id]).is_empty() else str(look.kind)
		var person := _spawn(id, appearance, look)
		person.sample_pose("idle", 0.3)
		var tone_by_level: Array = []
		var tunic_by_level: Array = []
		var scale_by_level: Array = []
		var shown_by_level: Array = []
		for level in 4:
			person._reload(level)
			var path := person.active_model_path
			_check(path.ends_with("_%d.glb" % level) and path.contains("frontier_"), "%s LOD %d uses the frontier family (%s)" % [id, level, path])
			var triangles := _visible_triangles(person)
			worst[level] = maxi(worst[level], triangles)
			_check(triangles <= BUDGETS[level], "%s LOD %d visible triangles %d within %d" % [id, level, triangles, BUDGETS[level]])
			var body := person.body.find_child("HeroBody", true, false) as MeshInstance3D
			var active_shapes := 0
			var visible_meshes := 0
			for mesh: MeshInstance3D in person.body.find_children("*", "MeshInstance3D", true, false):
				if mesh.is_visible_in_tree():
					visible_meshes += 1
					for shape in mesh.mesh.get_blend_shape_count():
						active_shapes += int(absf(mesh.get_blend_shape_value(shape)) > 0.0001)
			worst_shapes[level] = maxi(worst_shapes[level], active_shapes)
			worst_meshes[level] = maxi(worst_meshes[level], visible_meshes)
			var skin := body.get_active_material(0) as ShaderMaterial
			_check(skin != null and skin.shader != null, "%s LOD %d skin uses the resident skin shader" % [id, level])
			if skin:
				tone_by_level.append(skin.get_shader_parameter("tone"))
			var eyes := (person.body.find_child("HeroEyes", true, false) as MeshInstance3D).get_active_material(0) as ShaderMaterial
			_check(eyes != null and eyes.get_shader_parameter("iris_color") == look.eyes, "%s LOD %d shows its own iris colour" % [id, level])
			var shown: Array[String] = []
			for mesh: MeshInstance3D in person.body.find_children("Identity*", "MeshInstance3D", true, false):
				if mesh.visible:
					shown.append(String(mesh.name))
					var slot := mesh.find_blend_shape_by_name("ID_Show")
					_check(slot >= 0 and is_equal_approx(mesh.get_blend_shape_value(slot), 1.0), "%s LOD %d piece %s is expanded" % [id, level, mesh.name])
			shown.sort()
			shown_by_level.append(shown.filter(func(name): return name not in ["IdentityPouch", "IdentityBrooch", "IdentityEarrings"]))
			if not look.get("soldier", false):
				var values := Look.weights(look)
				for key: String in ["ID_JawWidth", "ID_NoseLength", "ID_Heavy", "ID_Shoulders", "ID_Age"]:
					var slot := body.find_blend_shape_by_name(key)
					_check(slot >= 0, "%s LOD %d carries identity key %s" % [id, level, key])
					if slot >= 0:
						# Face detail on the two near tiers, silhouette on every tier.
						var expected := float(values.get(key, 0.0)) if level < 2 or key in Look.SILHOUETTE_KEYS else 0.0
						_check(is_equal_approx(body.get_blend_shape_value(slot), expected), "%s LOD %d applies %s" % [id, level, key])
				var tunic := (person.body.find_child("HeroTunic", true, false) as MeshInstance3D).get_active_material(0) as StandardMaterial3D
				tunic_by_level.append(tunic.albedo_color if tunic else Color.BLACK)
			scale_by_level.append(person.body.scale.y)
			_check(person.animator != null and person.animator.has_animation("march"), "%s LOD %d keeps its clips" % [id, level])
		for level in range(1, 4):
			_check(tone_by_level[level] == tone_by_level[0], "%s keeps its skin tone at LOD %d" % [id, level])
			_check(is_equal_approx(scale_by_level[level], scale_by_level[0]), "%s keeps its stature at LOD %d" % [id, level])
			_check(shown_by_level[level] == shown_by_level[0], "%s keeps hair, beard and clothing pieces at LOD %d" % [id, level])
			if not tunic_by_level.is_empty():
				_check(tunic_by_level[level] == tunic_by_level[0], "%s keeps its tunic colour at LOD %d" % [id, level])
		person.free()
	report.budgets["worst_visible_triangles_per_lod"] = worst
	# Each active blend shape and each visible mesh is skinning/draw work per frame.
	report.budgets["most_active_blend_shapes_per_lod"] = worst_shapes
	report.budgets["most_visible_meshes_per_lod"] = worst_meshes
	report.budgets["limits"] = BUDGETS


func _texture_bytes(texture: Texture2D) -> int:
	if texture == null:
		return 0
	var image := texture.get_image()
	return image.get_data_size() if image else texture.get_width() * texture.get_height() * 4


func _textures(looks: Dictionary) -> void:
	var ids: Array = looks.keys()
	ids.sort()
	for profile: String in TEXTURE_LIMIT_MIB:
		var camera := Camera3D.new()
		root.add_child(camera)
		var unique := {}
		var people: Array[Person] = []
		for index in CROWD_DISTANCES.size():
			var id: String = ids[(index * 5) % ids.size()]
			var look: Dictionary = looks[id]
			var person := Person.new()
			person.profile = profile
			root.add_child(person)
			person.set_process(false)
			person.position = Vector3(0, 0.9, -float(CROWD_DISTANCES[index]))
			person.configure_resident("italia", int(look.look_age), str(look.kind) if str(look.kind) in ["civilian_man", "civilian_woman", "elder"] else "civilian_man", index, camera, id)
			people.append(person)
			for mesh: MeshInstance3D in person.body.find_children("*", "MeshInstance3D", true, false):
				if not mesh.is_visible_in_tree() or not mesh.mesh:
					continue
				for surface in mesh.mesh.get_surface_count():
					var material := mesh.get_active_material(surface)
					var textures: Array = []
					if material is StandardMaterial3D:
						for property: String in ["albedo_texture", "normal_texture", "roughness_texture"]:
							textures.append(material.get(property))
					elif material is ShaderMaterial:
						for parameter: String in ["albedo_texture", "normal_texture", "roughness_texture", "identity_mask", "identity_detail"]:
							textures.append(material.get_shader_parameter(parameter))
					for texture in textures:
						if texture is Texture2D:
							unique[(texture as Texture2D).get_rid()] = texture
		var total := 0
		var identity := 0
		var largest := 0
		for texture: Texture2D in unique.values():
			var bytes := _texture_bytes(texture)
			total += bytes
			if texture.resource_path.begins_with("res://assets/village_characters/identity/"):
				identity += bytes
			largest = maxi(largest, maxi(texture.get_width(), texture.get_height()))
		var mib := float(total) / 1048576.0
		var identity_mib := float(identity) / 1048576.0
		report.textures[profile] = {"unique_textures": unique.size(), "mib": snappedf(mib, 0.01), "identity_layer_mib": snappedf(identity_mib, 0.01),
			"largest_edge": largest, "lods": people.map(func(p): return p.detail)}
		_check(mib <= float(TEXTURE_LIMIT_MIB[profile]), "%s crowd texture memory %.1f MiB within %.0f MiB" % [profile, mib, TEXTURE_LIMIT_MIB[profile]])
		_check(identity_mib <= IDENTITY_TEXTURE_LIMIT_MIB, "%s identity-layer textures %.2f MiB within %.0f MiB" % [profile, identity_mib, IDENTITY_TEXTURE_LIMIT_MIB])
		_check(largest <= 2048, profile + " uses no texture beyond 2048 px")
		for person in people:
			person.free()
		camera.free()


func _posed_normals(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for t in range(0, indices.size() - 2, 3):
		# Godot front faces are clockwise: (c - a) x (b - a) points outward.
		var a := vertices[indices[t]]
		var n := (vertices[indices[t + 2]] - a).cross(vertices[indices[t + 1]] - a)
		for k in 3:
			normals[indices[t + k]] += n
	for i in normals.size():
		normals[i] = normals[i].normalized()
	return normals


func _outer_skin(vertices: PackedVector3Array, normals: PackedVector3Array, grid: Dictionary) -> PackedByteArray:
	var outer := PackedByteArray()
	outer.resize(vertices.size())
	for i in vertices.size():
		var cell := Vector3i((vertices[i] / 0.025).floor())
		var average := Vector3.ZERO
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for dz in range(-1, 2):
					for j in grid.get(cell + Vector3i(dx, dy, dz), []):
						if vertices[i].distance_squared_to(vertices[j]) < 0.0004:
							average += normals[j]
		outer[i] = 1 if average.normalized().dot(normals[i]) > 0.35 else 0
	return outer


func _dominant_bones(surface: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	var influences: int = surface.influences
	var joints: PackedInt32Array = surface.joints
	var weights: PackedFloat32Array = surface.weights
	var rig := surface.rig as Skeleton3D
	var count: int = (surface.vertices as PackedVector3Array).size()
	result.resize(count)
	for vertex in count:
		var best := 0
		for slot in influences:
			if weights[vertex * influences + slot] > weights[vertex * influences + best]:
				best = slot
		result[vertex] = rig.get_bone_name(int(surface.bones[joints[vertex * influences + best]]))
	return result


func _nearest(p: Vector3, vertices: PackedVector3Array, grid: Dictionary, accept: Callable = Callable(), reach: int = 1) -> int:
	var cell := Vector3i((p / 0.025).floor())
	var best := -1
	var best_distance := INF
	for dx in range(-reach, reach + 1):
		for dy in range(-reach, reach + 1):
			for dz in range(-reach, reach + 1):
				for i in grid.get(cell + Vector3i(dx, dy, dz), []):
					var d := p.distance_squared_to(vertices[i])
					if d < best_distance and (not accept.is_valid() or accept.call(i)):
						best_distance = d
						best = i
	return best


func _clipping(looks: Dictionary) -> void:
	# Two measurements per identity piece and pose, against the outer skin:
	# * attached: each piece vertex keeps the skin vertex it covers in the
	#   reference pose; its signed distance along that vertex's posed normal
	#   shows the piece sinking into the region it belongs to (beard into the
	#   jaw, cape into the shoulder);
	# * foreign limb: the nearest outer vertex of a different limb (legs
	#   through an apron, arms through a mantle) within 2.5 cm.
	# A self-test sinks a real piece 1.5 cm and must be detected.
	# One subject per piece/kind combination (every piece of KIND_PIECES occurs).
	var subjects := ["sextus", "nerva", "decimus", "varro", "julia", "aurelia", "aelia", "fabius"]
	var poses := [["idle", 0.25], ["march", 0.0], ["march", 0.25], ["march", 0.5], ["march", 0.75], ["run", 0.3], ["work", 0.5], ["talk", 0.3]]
	var limbs := ["Thigh_L", "Thigh_R", "Shin_L", "Shin_R", "Foot_L", "Foot_R", "Arm_L", "Arm_R", "Forearm_L", "Forearm_R", "Hand_L", "Hand_R"]
	for id: String in subjects:
		var look: Dictionary = looks[id]
		var person := _spawn(id, str(look.kind), look)
		person._reload(0)  # densest skin: the decimated torso of tier 1 is too sparse to anchor
		var skin := SkinFixture.new()
		skin.bind(person.body)
		# The surface under a piece is the outer skin plus the tunic it is
		# worn over: the frontier body has no skin under the tunic, and a
		# leather apron sinking into the linen is visible clipping too.
		var under_indices: Array[int] = []
		for index in skin.surfaces.size():
			if String((skin.surfaces[index].mesh as MeshInstance3D).name) in ["HeroBody", "HeroTunic", "HeroTunicSkirt"]:
				under_indices.append(index)
		var bones := PackedStringArray()
		for index in under_indices:
			bones.append_array(_dominant_bones(skin.surfaces[index]))
		var attached := {}
		var reference := {}
		var worst := {}
		var anchored := {}
		var outer := PackedByteArray()
		var self_hits_total := 0
		var self_total := 0
		for pose: Array in poses:
			person.sample_pose(pose[0], pose[1])
			skin.sample(true)
			var surfaces := skin.world_surfaces()
			var body_vertices := PackedVector3Array()
			var normals := PackedVector3Array()
			var classify := outer.is_empty()
			for index in under_indices:
				var vertices: PackedVector3Array = surfaces[index].vertices
				var own_normals := _posed_normals(vertices, surfaces[index].indices)
				if classify:
					# Inner lip, nostril and ear folds face against their surroundings;
					# classified once in the reference pose.
					var own_grid := {}
					for i in vertices.size():
						var cell := Vector3i((vertices[i] / 0.025).floor())
						if not own_grid.has(cell):
							own_grid[cell] = []  # Array buckets: a packed array in a Dictionary is copied on append
						(own_grid[cell] as Array).append(i)
					outer.append_array(_outer_skin(vertices, own_normals, own_grid))
				body_vertices.append_array(vertices)
				normals.append_array(own_normals)
			var grid := {}
			for i in body_vertices.size():
				if outer[i]:
					var cell := Vector3i((body_vertices[i] / 0.025).floor())
					if not grid.has(cell):
						grid[cell] = []
					(grid[cell] as Array).append(i)
			for index in surfaces.size():
				var name := String((skin.surfaces[index].mesh as MeshInstance3D).name)
				if not name.begins_with("Identity") or name in ["IdentityPouch", "IdentityBrooch", "IdentityEarrings"]:
					continue
				var vertices: PackedVector3Array = surfaces[index].vertices
				var piece_bones := _dominant_bones(skin.surfaces[index])
				if not attached.has(name):
					var links := PackedInt32Array()
					for v in vertices.size():
						# Anchor on skin or tunic of the same bone family (an apron is
						# never anchored to a hand that happens to hang beside it); a
						# draped mantle hangs well off the tunic, hence the wide search.
						var family: Array = FAMILIES.get(piece_bones[v], [piece_bones[v]])
						links.append(_nearest(vertices[v], body_vertices, grid, func(i): return bones[i] in family, 6))
					attached[name] = links
				var links: PackedInt32Array = attached[name]
				var sunk := 0
				var intruded := 0
				var deepest := 0.0
				for v in vertices.size():
					var p := vertices[v]
					var b := links[v]
					if b < 0:
						continue
					# Signed clearance along the anchor's posed normal. Pieces are built
					# outside the skin, so sinking is measured against the reference
					# pose: a thick beard may sit "behind" a neck anchor at rest.
					var clearance := (p - body_vertices[b]).dot(normals[b])
					if pose == poses[0]:
						reference[name + str(v)] = clearance
						# Self-test: the same measurement on a copy sunk 1.5 cm under its anchor.
						var sunk_copy := body_vertices[b] - normals[b] * 0.015
						var copy_clearance := (sunk_copy - body_vertices[b]).dot(normals[b])
						self_total += 1
						if clearance - copy_clearance - maxf(clearance, 0.0) > PENETRATION_M:
							self_hits_total += 1
					var rest: float = reference.get(name + str(v), clearance)
					var depth := rest - clearance - maxf(rest, 0.0)
					if depth > PENETRATION_M:
						sunk += 1
						deepest = maxf(deepest, depth)
					var own := piece_bones[v]
					var related: Array = FAMILIES.get(own, [own])
					var foreign := _nearest(p, body_vertices, grid, func(i): return bones[i] in limbs and bones[i] not in related, 2)
					# A knee fully through an apron is up to a limb radius from its skin.
					if foreign >= 0 and p.distance_to(body_vertices[foreign]) < 0.06:
						var intrusion := -(p - body_vertices[foreign]).dot(normals[foreign])
						if intrusion > PENETRATION_M:
							intruded += 1
							deepest = maxf(deepest, intrusion)
				if pose == poses[0]:
					var count := 0
					for link in links:
						count += int(link >= 0)
					anchored[name] = float(count) / maxf(1.0, float(vertices.size()))
				var ratio := float(sunk + intruded) / maxf(1.0, float(vertices.size()))
				var key := "%s/%s" % [id, name]
				if not worst.has(key) or ratio > float(worst[key].ratio):
					worst[key] = {"ratio": snappedf(ratio, 0.0001), "sunk": sunk, "foreign_limb": intruded,
						"deepest_m": snappedf(deepest, 0.0001), "pose": "%s@%.2f" % pose}
		var self_test := float(self_hits_total) / maxf(1.0, float(self_total))
		_check(self_test > 0.99, "%s clipping self-test detects pieces sunk 1.5 cm (%.3f)" % [id, self_test])
		for name: String in anchored:
			_check(float(anchored[name]) >= 0.9, "%s/%s is measured against skin or tunic (%.2f anchored)" % [id, name, anchored[name]])
		for key: String in worst:
			worst[key]["anchored"] = snappedf(float(anchored.get(key.get_slice("/", 1), 0.0)), 0.01)
			report.clipping[key] = worst[key]
			# Allowance: a few shell vertices at fold lines; anything larger is visible clipping.
			_check(float(worst[key].ratio) <= 0.03, "%s penetrates the body (%s)" % [key, str(worst[key])])
		person.free()
