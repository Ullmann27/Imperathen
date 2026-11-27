extends Node3D
## Runtime wrapper of the original Blender standard. Only a bounded local
## fold is animated. A matching procedural fallback is explicit, never a box.
const Art := preload("res://scripts/world/village_art.gd")
const ClothShader := preload("res://scripts/cinematic/i00_vexillum.gdshader")
const ASSET := "res://assets/cinematic/i00_vexillum.glb"
const WIDTH := .68
const HEIGHT := .68
const TOP := 2.82
const FRONT := .082
const GRID := 24
const FRINGE := 24
var cloth: MeshInstance3D
var textile: ShaderMaterial
var imported := false
var _phase := 0.0


func build(wood: Material, bronze: Material, phase_offset: float) -> void:
	if cloth != null:
		return
	_phase = phase_offset
	if ResourceLoader.exists(ASSET, "PackedScene"):
		var scene := load(ASSET) as PackedScene
		if scene:
			var instance := scene.instantiate()
			var model := instance as Node3D
			if model:
				var candidate := model.find_child("VexillumCloth", true, false) as MeshInstance3D
				if has_original_textile(candidate):
					add_child(model)
					cloth = candidate
					imported = true
			if not imported and is_instance_valid(instance):
				instance.free()
	if cloth == null:
		_build_fallback(wood, bronze)
	var source := cloth.mesh.surface_get_material(0) as StandardMaterial3D
	textile = ShaderMaterial.new()
	textile.shader = ClothShader
	if source and source.albedo_texture:
		textile.set_shader_parameter("textile_atlas", source.albedo_texture)
		textile.set_shader_parameter("use_atlas", true)
	textile.set_shader_parameter("wind_phase", _phase)
	textile.set_shader_parameter("wind_seconds", 0.0)
	cloth.material_override = textile
	cloth.extra_cull_margin = .25
	cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Accept the original asset only if its deformable mesh and baked textile
## are both present. A broken import must never be reported as original.
static func has_original_textile(candidate: MeshInstance3D) -> bool:
	if not is_instance_valid(candidate) or not candidate.mesh is ArrayMesh:
		return false
	var mesh := candidate.mesh as ArrayMesh
	if mesh.get_surface_count() != 1 or mesh.surface_get_array_len(0) <= 500:
		return false
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	if vertices.is_empty() or uvs.size() != vertices.size():
		return false
	var source := mesh.surface_get_material(0) as StandardMaterial3D
	return source != null and source.albedo_texture != null


func sample_wind(seconds: float) -> void:
	if textile != null and is_finite(seconds):
		textile.set_shader_parameter("wind_seconds", fposmod(seconds, 40.0))


## Identical local-space displacement as the shader and Blender preview.
static func displaced(vertex: Vector3, uv: Vector2, seconds: float, phase_offset: float = 0.0) -> Vector3:
	var v := clampf(uv.y, 0.0, 1.1)
	var a := TAU*(.60*seconds+1.10*uv.x)+3.6*v+phase_offset
	var b := TAU*(1.25*seconds-.80*uv.x)+5.0*v+phase_offset
	return vertex+Vector3(0,0,v*v*(.09+.075*sin(a)+.028*sin(b)))


func _build_fallback(wood: Material, bronze: Material) -> void:
	Art.cylinder(self,.035,3.04,Vector3(0,1.52,0),wood).name = "Mast"
	var crossbar := Art.cylinder(self,.018,WIDTH+.16,Vector3(0,TOP+.018,FRONT),wood)
	crossbar.name = "Crossbar"
	crossbar.rotation.z = PI*.5
	Art.cylinder(self,.045,.12,Vector3(0,TOP+.018,0),bronze).name = "CrossbarFitting"
	Art.cylinder(self,.042,.21,Vector3(0,3.105,0),bronze,.002).name = "Finial"
	for side: float in [-1.0,1.0]:
		var cap := Art.cylinder(self,.027,.048,Vector3(side*(WIDTH*.5+.056),TOP+.018,FRONT),bronze)
		cap.rotation.z = PI*.5
	cloth = MeshInstance3D.new()
	cloth.name = "VexillumCloth"
	cloth.mesh = _cloth_mesh()
	add_child(cloth)


static func _cloth_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in GRID+1:
		for col in GRID+1:
			var uv := Vector2(float(col)/GRID,float(row)/GRID)
			vertices.append(Vector3((uv.x-.5)*WIDTH,TOP-uv.y*HEIGHT,FRONT))
			normals.append(Vector3.BACK)
			uvs.append(uv)
	for row in GRID:
		for col in GRID:
			var a := row*(GRID+1)+col
			var b := a+1
			var c := a+GRID+1
			indices.append_array(PackedInt32Array([a,b,c,b,c+1,c]))
	for i in FRINGE:
		var u0 := (float(i)+.18)/FRINGE
		var u1 := (float(i)+.82)/FRINGE
		var v1 := 1.0+.055/HEIGHT*(.85+.15*cos(float(i)*1.7))
		var start := vertices.size()
		for uv: Vector2 in [Vector2(u0,1),Vector2(u1,1),Vector2(u0,v1),Vector2(u1,v1)]:
			vertices.append(Vector3((uv.x-.5)*WIDTH,TOP-uv.y*HEIGHT,FRONT))
			normals.append(Vector3.BACK)
			uvs.append(uv)
		indices.append_array(PackedInt32Array([start,start+1,start+2,start+1,start+3,start+2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},0)
	return mesh
