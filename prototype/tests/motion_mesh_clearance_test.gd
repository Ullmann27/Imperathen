extends SceneTree
const Clearance = preload("res://tests/motion_mesh_clearance.gd")
var checks := 0
var failures := 0


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _cube(at: Vector3, size: float) -> Dictionary:
	var mesh := BoxMesh.new()
	mesh.size=Vector3.ONE*size
	var faces := mesh.get_faces()
	for i in faces.size(): faces[i]+=at
	var indices := PackedInt32Array()
	indices.resize(faces.size())
	for i in indices.size(): indices[i]=i
	return Clearance.geometry([{"vertices":faces,"indices":indices}])


func _seamed_cube(transform: Transform3D, seam_gap: float, open_face: bool=false, topology_key: String="") -> Dictionary:
	# get_faces duplicates each triangle vertex, as imported material/UV seams do.
	var mesh := BoxMesh.new()
	mesh.size=Vector3.ONE*2.0
	var faces := mesh.get_faces()
	faces[0].x+=seam_gap
	if open_face: faces.resize(faces.size()-3)
	var indices := PackedInt32Array()
	indices.resize(faces.size())
	for index in indices.size(): indices[index]=index
	var surface := {"vertices":transform*faces,"indices":indices}
	if not topology_key.is_empty(): surface.topology_key=topology_key
	return Clearance.geometry([surface])


func _bridged_cube(topology_key: String="") -> Dictionary:
	# A middle copy must not join two corner copies farther apart than EPS.
	# Each extreme is within EPS of the middle, but not of the other extreme.
	var mesh := BoxMesh.new()
	mesh.size=Vector3.ONE*2.0
	var faces := mesh.get_faces()
	var corner := faces[0]
	var ordinal := 0
	var indices := PackedInt32Array()
	indices.resize(faces.size())
	for index in faces.size():
		indices[index]=index
		if faces[index]==corner:
			if ordinal>0: faces[index].x+=Clearance.EPSILON*(.9 if ordinal%2==1 else -.9)
			ordinal+=1
	var surface := {"vertices":faces,"indices":indices}
	if not topology_key.is_empty(): surface.topology_key=topology_key
	return Clearance.geometry([surface])


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var body := _cube(Vector3.ZERO,2.0)
	_check(not body.has("error") and body.closed,"Closed oriented authored cube recognised")
	var separate := Clearance.compare(body,_cube(Vector3(4,0,0),1.0),[])
	_check(separate.finite and separate.upper_bound_m==0.0 and not separate.intersection,"Separated mesh has proven zero intersection")
	var overlap := Clearance.compare(body,_cube(Vector3(1.2,0,0),1.0),[])
	_check(overlap.finite and overlap.intersection and absf(float(overlap.upper_bound_m)-.3)<.0001,"Actual crossing gives conservative separation bound")
	var contained := Clearance.compare(body,_cube(Vector3.ZERO,.2),[])
	_check(contained.finite and contained.intersection and contained.contained,"Fully enclosed object cannot escape surface-only checks")
	var intended := Clearance.compare(body,_cube(Vector3.ZERO,.2),[{"position":Vector3.ZERO,"radius":.2}])
	_check(intended.finite and intended.upper_bound_m==0.0,"Explicit grip contact volume is the only excluded region")
	var unbound := Clearance.compare(body,{"error":"missing real triangles"},[])
	_check(not unbound.finite,"Missing geometry never becomes zero clearance")
	# A sub-tolerance split across a spatial hash boundary is still the same
	# closed seam. Translation/rotation must not change that classification.
	var transforms: Array[Transform3D]=[
		Transform3D.IDENTITY,
		Transform3D(Basis.IDENTITY,Vector3(Clearance.EPSILON*.6,0,0)),
		Transform3D(Basis.from_euler(Vector3(.23,.59,.31)),Vector3(.4,1.3,-.3))]
	for transform: Transform3D in transforms:
		var seamed := _seamed_cube(transform,Clearance.EPSILON*.6)
		_check(not seamed.has("error") and seamed.closed,"Sub-tolerance imported seam stays closed through rigid transforms")
	var cracked := _seamed_cube(Transform3D.IDENTITY,Clearance.EPSILON*4.0)
	_check(not cracked.closed,"Actual gap beyond the existing tolerance remains open")
	_check(not _bridged_cube().closed,"A midpoint never welds corner copies separated by more than EPS")
	var cache_key := "clearance-seam-opening-regression"
	var cached_closed := _seamed_cube(Transform3D.IDENTITY,Clearance.EPSILON*.6,false,cache_key)
	_check(cached_closed.closed,"The cache regression begins with a genuinely closed sub-tolerance seam")
	var cached_open := _seamed_cube(Transform3D.IDENTITY,Clearance.EPSILON*1.5,false,cache_key)
	var fresh_open := _seamed_cube(Transform3D.IDENTITY,Clearance.EPSILON*1.5)
	_check(not cached_open.closed and not fresh_open.closed,"Cached and fresh topology both reject a seam opened beyond the same EPS")
	var bridge_key := "clearance-cached-midpoint-regression"
	var bridge_initial := _seamed_cube(Transform3D.IDENTITY,0.0,false,bridge_key)
	_check(bridge_initial.closed and not _bridged_cube(bridge_key).closed,"Cache rechecks every cluster pair when opposite seam copies move apart")
	var open_cube := _seamed_cube(Transform3D.IDENTITY,0.0,true)
	var unknown := Clearance.compare(open_cube,_cube(Vector3.ZERO,.2),[])
	_check(not open_cube.closed and not unknown.finite,"Missing face still blocks unproven solid containment")
	var scutum := (load("res://assets/weapons/scutum_lod0.glb") as PackedScene).instantiate() as Node3D
	root.add_child(scutum)
	var imported := Clearance.geometry(Clearance.rigid_surfaces(scutum))
	_check(not imported.has("error") and imported.closed,"Actual imported scutum material seams form a closed mesh")
	scutum.free()
	print("MOTION_CLEARANCE_TEST ",checks," checks; ",failures," failed")
	quit(0 if failures==0 else 1)
