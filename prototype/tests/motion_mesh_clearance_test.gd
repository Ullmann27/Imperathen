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


func _initialize() -> void:
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
	print("MOTION_CLEARANCE_TEST ",checks," checks; ",failures," failed")
	quit(0 if failures==0 else 1)
