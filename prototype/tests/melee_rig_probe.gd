extends RefCounted
## Engine-side measurement of the strike geometry that is actually displayed.
## Everything here is read from the imported skins, bind poses, blend shapes,
## attached prop meshes and the live presentation drivers. Nothing is authored.
## Output is in the canonical fighter frame: origin on the ground below the
## actor root, +X right, +Y up, -Z forward (Godot forward), metres.

const Person = preload("res://scripts/visuals/village_person.gd")
const FPS := 60
const CLUSTER_FRACTION := 0.08
const DOMINANT_WEIGHT := 0.55


## Vertices of `mesh_instance` dominated by `bone`, expressed in that bone's
## space (bind pose applied). `extra_shape` adds one blend shape at full weight
## (the hand grip morph closes the fist exactly as the presentation does).
static func bone_vertices(mesh_instance: MeshInstance3D, skeleton: Skeleton3D, bone: String, extra_shape: String = "") -> PackedVector3Array:
	var result := PackedVector3Array()
	var mesh := mesh_instance.mesh as ArrayMesh
	var skin := mesh_instance.skin
	if mesh == null or skin == null:
		return result
	var target := skeleton.find_bone(bone)
	var bind_for := {}
	for bind in skin.get_bind_count():
		var index := skin.get_bind_bone(bind)
		if index < 0:
			index = skeleton.find_bone(skin.get_bind_name(bind))
		if index == target:
			bind_for[bind] = skin.get_bind_pose(bind)
	if bind_for.is_empty():
		return result
	var shape_index := -1
	if not extra_shape.is_empty():
		for shape in mesh.get_blend_shape_count():
			if mesh.get_blend_shape_name(shape) == extra_shape:
				shape_index = shape
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if bones.is_empty() or weights.is_empty():
			continue
		var per := bones.size() / vertices.size()
		var deltas := PackedVector3Array()
		if shape_index >= 0:
			var blends := mesh.surface_get_blend_shape_arrays(surface)
			if shape_index < blends.size():
				deltas = blends[shape_index][Mesh.ARRAY_VERTEX]
		for v in vertices.size():
			var best := -1
			var best_weight := 0.0
			for k in per:
				var w := weights[v * per + k]
				if w > best_weight:
					best_weight = w
					best = bones[v * per + k]
			if best_weight < DOMINANT_WEIGHT or not bind_for.has(best):
				continue
			var point := vertices[v]
			if deltas.size() == vertices.size():
				point = deltas[v] if mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED else point + deltas[v]
			result.append((bind_for[best] as Transform3D) * point)
	return result


## Centroid of the outermost fraction of `points` along `axis` and its spread.
static func extremity(points: PackedVector3Array, axis: Vector3) -> Dictionary:
	if points.is_empty():
		return {}
	var projections: Array[float] = []
	for p in points:
		projections.append(p.dot(axis))
	var sorted := projections.duplicate()
	sorted.sort()
	var cut: float = sorted[clampi(int(floor(sorted.size() * (1.0 - CLUSTER_FRACTION))), 0, sorted.size() - 1)]
	var centroid := Vector3.ZERO
	var count := 0
	for i in points.size():
		if projections[i] >= cut:
			centroid += points[i]
			count += 1
	centroid /= float(count)
	var spread := 0.0
	for i in points.size():
		if projections[i] >= cut:
			var lateral := points[i] - centroid
			lateral -= axis * lateral.dot(axis)
			spread = maxf(spread, lateral.length())
	return {"point":centroid, "spread":spread, "count":count, "max":sorted[sorted.size() - 1]}


static func centroid(points: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for p in points:
		c += p
	return c / maxf(1.0, float(points.size()))


## Prop-space mesh vertices of a node subtree (static props such as weapons).
static func prop_vertices(prop: Node3D) -> PackedVector3Array:
	var result := PackedVector3Array()
	for mi: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
		var xf := relative(mi, prop)
		var mesh := mi.mesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for v in vertices:
				result.append(xf * v)
	return result


## Transform of `node` relative to `ancestor` from local transforms only, so
## no process frame or deferred BoneAttachment update is required.
static func relative(node: Node, ancestor: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cursor := node
	while cursor != null and cursor != ancestor:
		if cursor is Node3D:
			xf = (cursor as Node3D).transform * xf
		cursor = cursor.get_parent()
	return xf


## Bone pose in the actor's local frame, honouring the skeleton's ancestors.
static func bone_in(actor: Node3D, skeleton: Skeleton3D, bone: String) -> Transform3D:
	return relative(skeleton, actor) * skeleton.get_bone_global_pose(skeleton.find_bone(bone))


## Prop node (BoneAttachment3D child chain) in the actor's local frame. The
## attachment itself mirrors the bone pose; its children carry grip offsets.
static func prop_in(actor: Node3D, skeleton: Skeleton3D, attachment: BoneAttachment3D, prop: Node3D) -> Transform3D:
	return bone_in(actor, skeleton, attachment.bone_name) * relative(prop, attachment)


static func to_ground(actor_local: Vector3, ground_offset: float) -> Vector3:
	return Vector3(actor_local.x, actor_local.y + ground_offset, actor_local.z)


static func skeleton_of(node: Node) -> Skeleton3D:
	var found := node.find_children("*", "Skeleton3D", true, false)
	return null if found.is_empty() else found[0] as Skeleton3D


static func body_mesh(node: Node) -> MeshInstance3D:
	var best: MeshInstance3D = null
	var best_count := -1
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null or mi.mesh == null:
			continue
		var count := 0
		for surface in mi.mesh.get_surface_count():
			count += (mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		if count > best_count:
			best_count = count
			best = mi
	return best


## Strike primitive (base, tip, radius) in a bone's space from its skin.
static func skin_strike(model: Node3D, bone: String, axis_hint: Vector3, morph: String = "") -> Dictionary:
	var skeleton := skeleton_of(model)
	var mesh := body_mesh(model)
	var verts := bone_vertices(mesh, skeleton, bone, morph)
	var axis := axis_hint if axis_hint.length_squared() > 0.0 else centroid(verts).normalized()
	var ext := extremity(verts, axis.normalized())
	var tip: Vector3 = ext.point
	var base := Vector3.ZERO
	var lateral: Array[float] = []
	var seg := tip - base
	for v in verts:
		var t := clampf((v - base).dot(seg) / seg.length_squared(), 0.0, 1.0)
		lateral.append((v - (base + seg * t)).length())
	lateral.sort()
	return {"bone":bone, "base":base, "tip":tip, "radius":lateral[int(lateral.size() * 0.90)], "vertices":verts.size()}


static func prop_blade(prop: Node3D) -> Dictionary:
	var verts := prop_vertices(prop)
	var tip := -INF
	var widest := 0.0
	for v in verts:
		tip = maxf(tip, v.y)
	for v in verts:
		if v.y < tip * 0.5:
			widest = maxf(widest, absf(v.x))
	var guard_top := -INF
	for v in verts:
		if v.y < tip * 0.5 and absf(v.x) >= widest * 0.95:
			guard_top = maxf(guard_top, v.y)
	var half := 0.0
	for v in verts:
		if v.y > guard_top + 0.05 and v.y < tip - 0.10:
			half = maxf(half, absf(v.x))
	return {"base":Vector3(0, guard_top, 0), "tip":Vector3(0, tip, 0), "radius":half, "blade_length":tip - guard_top}


static func prop_axe(prop: Node3D) -> Dictionary:
	var verts := prop_vertices(prop)
	var haft: Array[float] = []
	var top := -INF
	for v in verts:
		top = maxf(top, v.y)
	for v in verts:
		if v.y < top * 0.4:
			haft.append(Vector2(v.x, v.z).length())
	haft.sort()
	var haft_r: float = haft[int(haft.size() * 0.5)]
	var head_low := INF
	var head_r := 0.0
	for v in verts:
		if absf(v.x) > haft_r * 2.5:
			head_low = minf(head_low, v.y)
			head_r = maxf(head_r, absf(v.x))
	return {"base":Vector3(0, head_low, 0), "tip":Vector3(0, top, 0), "radius":head_r, "haft_radius":haft_r, "head_height":top - head_low}


static func prop_box(prop: Node3D) -> Dictionary:
	var verts := prop_vertices(prop)
	var box := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		box = box.expand(v)
	return {"center":box.get_center(), "half":box.size * 0.5}
