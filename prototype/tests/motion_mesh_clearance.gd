extends RefCounted
## Actual posed triangle meshes, with BVH-accelerated segment intersections.
## On a detected intersection, the reported depth is a conservative upper
## bound: the least axis translation that separates the two complete AABBs.
## Zero is reported only after both edge directions and containment checks.
## A bound above the limit fails conservatively; it is never presented as an
## exact anatomical penetration distance. Intended contact is restricted to
## the explicitly provided grip volume around the actual hand.

const EPSILON := .00001
static var _topology_cache: Dictionary = {}


static func geometry(surfaces: Array) -> Dictionary:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var keys: Array[String] = []
	var cacheable := not surfaces.is_empty()
	for surface: Dictionary in surfaces:
		var start := vertices.size()
		vertices.append_array(surface.vertices as PackedVector3Array)
		for index: int in surface.indices: indices.append(start+index)
		if not surface.has("topology_key"): cacheable=false
		else: keys.append(str(surface.topology_key))
	if vertices.is_empty() or indices.is_empty() or indices.size()%3!=0:
		return {"error":"No complete actual mesh triangles"}
	var bounds := AABB(vertices[0],Vector3.ZERO)
	for vertex: Vector3 in vertices:
		if not vertex.is_finite(): return {"error":"Non-finite mesh vertex"}
		bounds = bounds.expand(vertex)
	var key := "|".join(keys)
	var topology: Dictionary = _topology_cache.get(key,{}) if cacheable else {}
	if topology.is_empty():
		var edges := PackedInt32Array()
		var seen := {}
		var boundary_edges := {}
		var welded := {}
		var weld_members := {}
		var weld_pairs := PackedInt32Array()
		var weld_ids := PackedInt32Array()
		for index in vertices.size():
			var point := vertices[index]
			var cell := Vector3i(floori(point.x/EPSILON),floori(point.y/EPSILON),floori(point.z/EPSILON))
			var representative := -1
			# A grid cell is only a search bucket. Material/UV seam copies can
			# straddle its boundary while remaining within the same tolerance.
			# Every pair in a cluster must remain within EPS. Matching only
			# its representative would let a midpoint bridge a wider opening.
			for x in range(-1,2):
				for y in range(-1,2):
					for z in range(-1,2):
						for candidate: int in welded.get(cell+Vector3i(x,y,z),[]):
							if point.distance_squared_to(vertices[candidate])<=EPSILON*EPSILON:
								var fits := true
								for member: int in weld_members[candidate]:
									if point.distance_squared_to(vertices[member])>EPSILON*EPSILON:
										fits=false
										break
								if fits and (representative<0 or candidate<representative): representative=candidate
			if representative>=0:
				# Cache every checked pair, so deformation cannot open a seam
				# that a representative-only recheck would still accept.
				for member: int in weld_members[representative]:
					weld_pairs.append(member)
					weld_pairs.append(index)
			else:
				representative=index
				if not welded.has(cell): welded[cell]=[]
				welded[cell].append(index)
				weld_members[representative]=[]
			weld_members[representative].append(index)
			weld_ids.append(representative)
		for triangle in range(0,indices.size(),3):
			for edge in 3:
				var a := indices[triangle+edge]
				var b := indices[triangle+(edge+1)%3]
				if a<0 or b<0 or a>=vertices.size() or b>=vertices.size(): return {"error":"Invalid triangle index"}
				var pa := weld_ids[a]
				var pb := weld_ids[b]
				if pa!=pb:
					var boundary_key := Vector2i(mini(pa,pb),maxi(pa,pb))
					boundary_edges[boundary_key]=int(boundary_edges.get(boundary_key,0))+(1 if pa<pb else -1)
				var pair := Vector2i(mini(a,b),maxi(a,b))
				if seen.has(pair): continue
				seen[pair]=true
				edges.append(a)
				edges.append(b)
		var closed := true
		for balance in boundary_edges.values(): closed=closed and int(balance)==0
		topology={"edges":edges,"indices":indices,"closed":closed,"weld_pairs":weld_pairs,"vertex_count":vertices.size()}
		if cacheable: _topology_cache[key]=topology
	if vertices.size()!=int(topology.vertex_count) or indices!=topology.indices:
		return {"error":"Mesh topology changed within a clearance fixture"}
	var closed: bool=topology.closed
	var pairs: PackedInt32Array=topology.weld_pairs
	for pair in range(0,pairs.size(),2):
		closed=closed and vertices[pairs[pair]].distance_squared_to(vertices[pairs[pair+1]])<=EPSILON*EPSILON
	if cacheable and bool(topology.closed) and not closed:
		# Separate closed components may have touched in the cached pose.
		# Rebuild from current triangles when those welds separate; a real
		# opened seam must still pass the same complete-link closure check.
		_topology_cache.erase(key)
		return geometry(surfaces)
	var faces := PackedVector3Array()
	faces.resize(indices.size())
	for index in indices.size(): faces[index]=vertices[indices[index]]
	var edge_ids: PackedInt32Array=topology.edges
	var edges := PackedVector3Array()
	edges.resize(edge_ids.size())
	for index in edge_ids.size(): edges[index]=vertices[edge_ids[index]]
	var bvh := TriangleMesh.new()
	if not bvh.create_from_faces(faces): return {"error":"Cannot build actual mesh BVH"}
	return {"bvh":bvh,"bounds":bounds,"edges":edges,"seeds":vertices,"closed":closed}


static func rigid_surfaces(parent: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for child: Node in parent.find_children("*","MeshInstance3D",true,false):
		var mesh := child as MeshInstance3D
		if mesh.mesh==null or not mesh.is_visible_in_tree() or mesh.skin!=null: continue
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = mesh.global_transform*(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				indices.resize(vertices.size())
				for i in vertices.size(): indices[i]=i
			result.append({"vertices":vertices,"indices":indices,"topology_key":str(mesh.get_instance_id())+":"+str(surface)})
	return result


static func _intended(point: Vector3, grips: Array[Dictionary]) -> bool:
	for grip: Dictionary in grips:
		if point.distance_to(grip.position) <= float(grip.radius): return true
	return false


static func _outside_grip_intersection(source: Dictionary, target: Dictionary, grips: Array[Dictionary]) -> Dictionary:
	var bvh := target.bvh as TriangleMesh
	var bounds: AABB = target.bounds
	var edges: PackedVector3Array = source.edges
	for edge in range(0,edges.size(),2):
		var at := edges[edge]
		var end := edges[edge+1]
		if at.distance_squared_to(end) < EPSILON*EPSILON: continue
		if bounds.intersects_segment(at,end)==null: continue
		var direction := (end-at).normalized()
		for crossing in 128:
			var hit := bvh.intersect_segment(at,end)
			if hit.is_empty(): break
			var point: Vector3 = hit.position
			if not _intended(point,grips): return {"intersection":point}
			at = point+direction*EPSILON
			if direction.dot(end-at) <= EPSILON: break
			if crossing==127: return {"error":"Triangle intersection iteration limit reached"}
	return {}


static func _inside(point: Vector3, target: Dictionary) -> Dictionary:
	var bvh := target.bvh as TriangleMesh
	var direction := Vector3(1.0,.371,.527).normalized()
	var bounds: AABB = target.bounds
	var end := point+direction*(bounds.size.length()*3.0+1.0)
	var at := point
	var winding := 0
	for iteration in 128:
		var hit := bvh.intersect_segment(at,end)
		if hit.is_empty(): return {"inside":winding!=0}
		at = Vector3(hit.position)+direction*EPSILON
		# Signed crossings handle multiple overlapping closed components;
		# parity would incorrectly classify an overlap of two shells outside.
		winding += 1 if Vector3(hit.normal).dot(direction)>0.0 else -1
	return {"error":"Containment intersection iteration limit reached"}


static func _contained(source: Dictionary, target: Dictionary, grips: Array[Dictionary]) -> Dictionary:
	var bounds: AABB = target.bounds
	for point: Vector3 in source.seeds:
		if _intended(point,grips) or not bounds.has_point(point): continue
		var observed := _inside(point,target)
		if observed.has("error"): return observed
		if bool(observed.inside): return {"intersection":point,"contained":true}
	return {}


static func compare(body: Dictionary, prop: Dictionary, grips: Array[Dictionary]) -> Dictionary:
	if body.has("error"): return {"finite":false,"error":body.error}
	if prop.has("error"): return {"finite":false,"error":prop.error}
	var a: AABB = body.bounds
	var b: AABB = prop.bounds
	if not a.intersects(b): return {"finite":true,"upper_bound_m":0.0,"intersection":false}
	var hit := _outside_grip_intersection(prop,body,grips)
	if hit.is_empty(): hit = _outside_grip_intersection(body,prop,grips)
	if hit.is_empty() and (not bool(body.closed) or not bool(prop.closed)):
		return {"finite":false,"error":"Open or inconsistently oriented overlapping mesh: solid containment is not proven"}
	if hit.is_empty(): hit = _contained(prop,body,grips)
	if hit.is_empty(): hit = _contained(body,prop,grips)
	if hit.has("error"): return {"finite":false,"error":hit.error}
	if hit.is_empty(): return {"finite":true,"upper_bound_m":0.0,"intersection":false}
	var separation := INF
	for axis in 3:
		separation = minf(separation,minf(a.end[axis]-b.position[axis],b.end[axis]-a.position[axis]))
	return {"finite":is_finite(separation),"upper_bound_m":maxf(0.0,separation),
		"intersection":true,"point":str(hit.intersection),"contained":hit.get("contained",false)}
