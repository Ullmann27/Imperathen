extends RefCounted
## CPU evaluation of the actual imported skin, weights and active morphs.
## This fixture observes production poses; it never modifies a skeleton.

var surfaces: Array[Dictionary] = []
var errors: Array[String] = []
var foot_vertices := {"L":0,"R":0}
var _packed_disabled: Dictionary = {}
var packed_validation_error_m := 0.0


func bind(model: Node3D) -> void:
	surfaces.clear()
	errors.clear()
	foot_vertices = {"L":0,"R":0}
	_packed_disabled.clear()
	packed_validation_error_m=0.0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.skin == null or mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var rig := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		if rig == null:
			errors.append(str(mesh.get_path()) + ": skinned mesh has no bound skeleton")
			continue
		var bones := PackedInt32Array()
		var binds: Array[Transform3D] = []
		var names: Array[String] = []
		for index in mesh.skin.get_bind_count():
			var name := String(mesh.skin.get_bind_name(index))
			var bone := rig.find_bone(name) if not name.is_empty() else mesh.skin.get_bind_bone(index)
			if bone < 0 or bone >= rig.get_bone_count():
				errors.append(str(mesh.get_path()) + ": invalid skin bone " + str(index))
			bones.append(bone)
			binds.append(mesh.skin.get_bind_pose(index))
			names.append(rig.get_bone_name(bone) if bone >= 0 else "")
		for surface in mesh.mesh.get_surface_count():
			var data := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
			var joints: PackedInt32Array = data[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = data[Mesh.ARRAY_WEIGHTS]
			if vertices.is_empty() or joints.size() != weights.size() or joints.size() % vertices.size() != 0:
				errors.append(str(mesh.get_path()) + ": incomplete skin vertex data")
				continue
			var influences := joints.size() / vertices.size()
			if influences not in [4,8]:
				errors.append(str(mesh.get_path()) + ": unsupported skin influence count")
				continue
			var feet := PackedInt32Array()
			feet.resize(vertices.size())
			for vertex in vertices.size():
				var left := 0.0
				var right := 0.0
				var total := 0.0
				for slot in influences:
					var offset := vertex * influences + slot
					var joint := joints[offset]
					var weight := weights[offset]
					if joint < 0 or joint >= bones.size() or not is_finite(weight) or weight < 0.0:
						errors.append(str(mesh.get_path()) + ": invalid skin influence")
						continue
					total += weight
					if names[joint] == "Foot_L": left += weight
					if names[joint] == "Foot_R": right += weight
				if absf(total-1.0) > .002:
					errors.append(str(mesh.get_path()) + ": unnormalised skin weights")
				if left >= .5:
					feet[vertex] = 1
					foot_vertices.L += 1
				elif right >= .5:
					feet[vertex] = 2
					foot_vertices.R += 1
			var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				indices.resize(vertices.size())
				for vertex in vertices.size(): indices[vertex] = vertex
			var edges := PackedInt32Array()
			var limits := PackedFloat32Array()
			var seen := {}
			for triangle in range(0, indices.size()-2, 3):
				for edge in 3:
					var a := indices[triangle+edge]
					var b := indices[triangle+(edge+1)%3]
					var key := Vector2i(mini(a,b),maxi(a,b))
					if seen.has(key): continue
					seen[key] = true
					edges.append(a)
					edges.append(b)
					# Same severe-tearing criterion as meshy_character_test.gd.
					# It is a project threshold, not a claim about human anatomy.
					limits.append(vertices[a].distance_to(vertices[b])*7.0+.03)
			var morphs: Array = []
			if mesh.mesh is ArrayMesh:
				morphs = (mesh.mesh as ArrayMesh).surface_get_blend_shape_arrays(surface)
			var morph_deltas: Array[Dictionary] = []
			var morph_vertices := PackedByteArray()
			morph_vertices.resize(vertices.size())
			var relative := mesh.mesh is ArrayMesh and (mesh.mesh as ArrayMesh).blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE
			for morph in morphs:
				var changed := PackedInt32Array()
				var deltas := PackedVector3Array()
				var targets: PackedVector3Array = morph[Mesh.ARRAY_VERTEX]
				for vertex in vertices.size():
					var delta := targets[vertex] if relative else targets[vertex]-vertices[vertex]
					if delta.length_squared()>0.0:
						changed.append(vertex)
						deltas.append(delta)
						morph_vertices[vertex]=1
				morph_deltas.append({"indices":changed,"deltas":deltas})
			var group_lists: Array[Dictionary]=[]
			for bone in bones.size(): group_lists.append({"indices":[],"vertices":[],"weights":[]})
			for vertex in vertices.size():
				for slot in influences:
					var offset:=vertex*influences+slot
					var joint:=joints[offset]
					var weight:=weights[offset]
					if weight==0.0 or joint<0 or joint>=bones.size(): continue
					group_lists[joint].indices.append(vertex)
					group_lists[joint].vertices.append(vertices[vertex])
					group_lists[joint].weights.append(weight)
			var groups: Array[Dictionary]=[]
			for bone in group_lists.size():
				if group_lists[bone].indices.is_empty(): continue
				groups.append({"bone":bone,"indices":PackedInt32Array(group_lists[bone].indices),
					"vertices":PackedVector3Array(group_lists[bone].vertices),"weights":PackedFloat32Array(group_lists[bone].weights)})
			var deforming_edges:=PackedInt32Array()
			var deforming_limits:=PackedFloat32Array()
			for edge in limits.size():
				var a:=edges[edge*2]
				var b:=edges[edge*2+1]
				var identical:=morph_vertices[a]==0 and morph_vertices[b]==0
				for slot in influences:
					identical=identical and joints[a*influences+slot]==joints[b*influences+slot] and weights[a*influences+slot]==weights[b*influences+slot]
				if not identical:
					deforming_edges.append(a)
					deforming_edges.append(b)
					deforming_limits.append(limits[edge])
			surfaces.append({"mesh":mesh,"surface":surface,"rig":rig,"vertices":vertices,"joints":joints,
				"weights":weights,"influences":influences,"bones":bones,"binds":binds,
				"feet":feet,"edges":edges,"indices":indices,"limits":limits,"morphs":morph_deltas,"ordinal":surfaces.size(),
				"groups":groups,"deforming_edges":deforming_edges,"deforming_limits":deforming_limits})
	if surfaces.is_empty(): errors.append("No visible imported skinned surface was measured")
	if foot_vertices.L == 0 or foot_vertices.R == 0:
		errors.append("Actual left and right sole skin vertices are required")


func _cpu_vertex(vertex: int, vertices: PackedVector3Array, transforms: Array[Transform3D], joints: PackedInt32Array, weights: PackedFloat32Array, influences: int) -> Vector3:
	var value:=Vector3.ZERO
	for slot in influences:
		var offset:=vertex*influences+slot
		var weight:=weights[offset]
		if weight==0.0: continue
		var joint:=joints[offset]
		if joint>=0 and joint<transforms.size(): value+=(transforms[joint]*vertices[vertex])*weight
	return value


func sample(force_cpu: bool=false) -> Dictionary:
	var finite := errors.is_empty()
	var violations := 0
	var lowest := INF
	var lowest_info: Dictionary = {}
	var contacts := {}
	var packed_surfaces := 0
	var worst_edge: Dictionary = {}
	for surface: Dictionary in surfaces:
		var mesh := surface.mesh as MeshInstance3D
		var rig := surface.rig as Skeleton3D
		var transforms: Array[Transform3D] = []
		for index in surface.bones.size():
			var bone: int = surface.bones[index]
			if bone < 0:
				transforms.append(Transform3D.IDENTITY)
				finite = false
			else:
				transforms.append(rig.get_bone_global_pose(bone)*surface.binds[index])
		# Packed arrays stored in a Dictionary can share writable backing
		# storage. Preserve the source before applying any current morph.
		var vertices: PackedVector3Array = surface.vertices.duplicate()
		for morph in surface.morphs.size():
			var amount := mesh.get_blend_shape_value(morph)
			if absf(amount) > .000001:
				var changed: PackedInt32Array = surface.morphs[morph].indices
				var deltas: PackedVector3Array = surface.morphs[morph].deltas
				for index in changed.size(): vertices[changed[index]] += deltas[index]*amount
		var posed := PackedVector3Array()
		posed.resize(vertices.size())
		var influences: int = surface.influences
		var joints: PackedInt32Array = surface.joints
		var weights: PackedFloat32Array = surface.weights
		var feet: PackedInt32Array = surface.feet
		var original: PackedVector3Array = surface.vertices
		var mesh_id := mesh.get_instance_id()
		var packed := not force_cpu and not _packed_disabled.has(mesh_id)
		if packed:
			# The full matrix loop executes in engine C++, independently of
			# RenderingServer. Every weight still contributes to the result.
			for group: Dictionary in surface.groups:
				var changed: PackedVector3Array = transforms[int(group.bone)]*(group.vertices as PackedVector3Array)
				var ids: PackedInt32Array = group.indices
				var amounts: PackedFloat32Array = group.weights
				for index in ids.size(): posed[ids[index]] += changed[index]*amounts[index]
			for vertex in vertices.size():
				var delta := vertices[vertex]-original[vertex]
				if delta.length_squared()==0.0: continue
				for slot in influences:
					var offset := vertex*influences+slot
					var weight := weights[offset]
					if weight==0.0: continue
					var joint := joints[offset]
					if joint>=0 and joint<transforms.size(): posed[vertex] += (transforms[joint].basis*delta)*weight
			# Verify current packed output against the full scalar reference
			# every frame. A difference selects the reference for that mesh.
			var stride := maxi(1,vertices.size()/64)
			for vertex in range(0,vertices.size(),stride):
				var expected := _cpu_vertex(vertex,vertices,transforms,joints,weights,influences)
				var difference := expected.distance_to(posed[vertex])
				packed_validation_error_m = maxf(packed_validation_error_m,difference)
				if not posed[vertex].is_finite() or difference>.00002:
					packed = false
					_packed_disabled[mesh_id] = "Packed/CPU pose mismatch"
					break
		if packed: packed_surfaces += 1
		for vertex in vertices.size():
			var value := posed[vertex] if packed else _cpu_vertex(vertex,vertices,transforms,joints,weights,influences)
			posed[vertex] = value
			finite = finite and value.is_finite()
			if feet[vertex] != 0:
				var world_point := rig.global_transform*value
				if world_point.y<lowest:
					lowest_info = {"mesh":str(mesh.name),"surface":int(surface.surface),"vertex":vertex,"position":str(world_point)}
				lowest = minf(lowest,world_point.y)
				# Actual sole vertices within the explicit 2 cm contact band.
				if world_point.y<=.02:
					var key := (int(surface.ordinal)<<32)|(vertex<<1)|(feet[vertex]-1)
					contacts[key] = world_point
		var edge_indices: PackedInt32Array = surface.edges
		var edge_limits: PackedFloat32Array = surface.limits
		var bounded := not force_cpu
		for transform: Transform3D in transforms:
			# Frobenius norm bounds the operator norm. With normalized
			# identical weights at both ends and no affected morph, a <=6
			# bound cannot exceed the existing 7*rest+.03 tearing limit.
			bounded = bounded and transform.basis.x.length_squared()+transform.basis.y.length_squared()+transform.basis.z.length_squared()<=36.0
		if bounded:
			edge_indices = surface.deforming_edges
			edge_limits = surface.deforming_limits
		for edge in edge_limits.size():
			var a := edge_indices[edge*2]
			var b := edge_indices[edge*2+1]
			var posed_length:=posed[a].distance_to(posed[b])
			if posed_length>edge_limits[edge]:
				violations+=1
				var excess:=posed_length-edge_limits[edge]
				if excess>float(worst_edge.get("excess_m",-1.0)):
					var bindings: Array[Dictionary]=[]
					for vertex: int in [a,b]:
						var weights_by_bone: Dictionary={}
						for slot in influences:
							var offset:=vertex*influences+slot
							if weights[offset]>0.0:
								weights_by_bone[rig.get_bone_name(int(surface.bones[joints[offset]]))]=weights[offset]
						bindings.append(weights_by_bone)
					worst_edge={"mesh":str(mesh.name),"surface":int(surface.surface),"a":a,"b":b,
						"rest_length_m":original[a].distance_to(original[b]),"posed_length_m":posed_length,
						"limit_m":edge_limits[edge],"excess_m":excess,"bindings":bindings,
						"rest_a":str(original[a]),"rest_b":str(original[b]),
						"posed_a":str(posed[a]),"posed_b":str(posed[b])}
		surface["last_posed"] = posed
	return {"finite":finite and is_finite(lowest),"skin_edge_violations":violations,
		"max_sole_penetration_m":maxf(0.0,-lowest) if is_finite(lowest) else null,
		"lowest_sole_m":lowest if is_finite(lowest) else null,"contact_points":contacts,
		"lowest_sole_vertex":lowest_info,"worst_skin_edge":worst_edge,
		"packed_surfaces":packed_surfaces,"packed_validation_error_m":packed_validation_error_m}


func world_surfaces() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for surface: Dictionary in surfaces:
		if not surface.has("last_posed"):
			return []
		var rig := surface.rig as Skeleton3D
		result.append({"vertices":rig.global_transform*(surface.last_posed as PackedVector3Array),
			"indices":surface.indices,"edges":surface.edges,
			"topology_key":str((surface.mesh as MeshInstance3D).get_instance_id())+":"+str(surface.surface)})
	return result
