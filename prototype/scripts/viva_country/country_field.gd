extends Node3D
## Imported geometry is the source of truth. Grass and gravel never affect physics.
const ROOT := "res://assets/viva_country/"
const Soil := preload("res://shaders/viva_country/soil.gdshader")
const Blades := preload("res://shaders/viva_country/blades.gdshader")
const Scenery := preload("res://scripts/viva_country/country_scenery.gd")
const PROFILE := {
	"low": [0.10,0.035,0.20,0.055,0.20],
	"balanced": [0.28,0.10,0.42,0.13,0.65],
	"high": [0.56,0.20,0.72,0.24,1.0],
	"very_high": [0.88,0.32,1.0,0.40,1.0]
}
var manifest: Dictionary = {}
var groups: Array[Dictionary] = []
var terrain: Array[MeshInstance3D] = []
var errors: Array[String] = []
var scenery: Node3D
var soil_mat: ShaderMaterial
var blade_mat: ShaderMaterial
var stone_mat: StandardMaterial3D
var wind_time := 0.0
var wind_paused := false
var profile := "high"
var counts := {"grass":0,"stones":0,"triangles":0}
var _last_profile := ""
var _last_zone := -999

static func center(z: float) -> float:
	return 1.95*sin(z*0.178)+0.73*sin(z*0.37+0.4)-0.35

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child: Node in node.find_children("*","MeshInstance3D",true,false):
		result.append(child as MeshInstance3D)
	return result

func _load_scene(path: String) -> Node3D:
	if not ResourceLoader.exists(path,"PackedScene"):
		errors.append("Missing 3D resource: "+path)
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		errors.append("Invalid 3D scene: "+path)
		return null
	return packed.instantiate() as Node3D

func _json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("Missing JSON: "+path)
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func build() -> bool:
	if not terrain.is_empty() or not groups.is_empty():
		return errors.is_empty() and terrain.size()==3 and groups.size()==24
	var data: Variant = _json(ROOT+"manifest.json")
	if not data is Dictionary or data.get("schema",0)!=1:
		errors.append("Invalid country manifest")
		return false
	manifest=data
	soil_mat=ShaderMaterial.new()
	soil_mat.shader=Soil
	blade_mat=ShaderMaterial.new()
	blade_mat.shader=Blades
	stone_mat=StandardMaterial3D.new()
	stone_mat.vertex_color_use_as_albedo=true
	stone_mat.roughness=0.82
	stone_mat.metallic_specular=0.24
	for k in range(3):
		var node := _load_scene(ROOT+"terrain_%d.glb"%k)
		if node==null:
			return false
		add_child(node)
		var shapes := _meshes(node)
		if shapes.size()!=1 or shapes[0].mesh==null:
			errors.append("Expected one terrain mesh per sector")
			return false
		var item := shapes[0]
		item.material_override=soil_mat
		terrain.append(item)
		var body := StaticBody3D.new()
		body.name="CountryGround_%d"%k
		body.collision_layer=1
		body.collision_mask=0
		add_child(body)
		body.global_transform=item.global_transform
		var collider := CollisionShape3D.new()
		var trimesh := item.mesh.create_trimesh_shape()
		if trimesh==null:
			errors.append("Missing terrain physics")
			return false
		trimesh.backface_collision=true
		collider.shape=trimesh
		body.add_child(collider)
	var library := _load_scene(ROOT+"scatter_library.glb")
	if library==null:
		return false
	var meshes := {}
	for item: MeshInstance3D in _meshes(library):
		var key := String(item.name)
		if item.mesh!=null:
			if not key.begins_with("grass_") and not key.begins_with("stone_"):
				key=item.mesh.resource_name
			meshes[key]=item.mesh
	library.free()
	if meshes.size()!=8:
		errors.append("Expected eight distinct 3D scatter prototypes")
		return false
	for k in range(3):
		var spec: Variant=_json(ROOT+"scatter_%d.json"%k)
		if not spec is Dictionary or spec.get("chunk",-1)!=k or not spec.get("groups") is Array or spec.groups.size()!=8:
			errors.append("Invalid scatter chunk")
			return false
		var seen := {}
		for group: Dictionary in spec.groups:
			var id := str(group.get("mesh",""))
			if not meshes.has(id) or seen.has(id) or not group.get("rows") is Array:
				errors.append("Unknown or duplicate mesh "+id)
				return false
			seen[id]=true
			var rows: Array=group.rows
			var mm:=MultiMesh.new()
			mm.transform_format=MultiMesh.TRANSFORM_3D
			mm.use_colors=true
			mm.mesh=meshes[id] as Mesh
			mm.instance_count=rows.size()
			for i in rows.size():
				var row: Variant=rows[i]
				if not row is Array or row.size()!=10:
					errors.append("Invalid scatter row")
					return false
				for v: Variant in row:
					if not (v is float or v is int) or not is_finite(float(v)):
						errors.append("Invalid scatter number")
						return false
				if minf(float(row[4]),minf(float(row[5]),float(row[6])))<=0.0:
					errors.append("Invalid scatter scale")
					return false
				var basis:=Basis(Vector3.UP,float(row[3])).scaled_local(Vector3(row[4],row[5],row[6]))
				mm.set_instance_transform(i,Transform3D(basis,Vector3(row[0],row[1],row[2])))
				mm.set_instance_color(i,Color(row[7],row[8],row[9],1.0))
			var batch:=MultiMeshInstance3D.new()
			batch.name="Country_%d_%s"%[k,id]
			batch.multimesh=mm
			var is_grass:=id.begins_with("grass_")
			batch.material_override=blade_mat if is_grass else stone_mat
			batch.extra_cull_margin=0.35 if is_grass else 0.1
			add_child(batch)
			groups.append({"node":batch,"chunk":k,"grass":is_grass,"total":rows.size(),"triangles":int(manifest.stats.prototypeTriangles[id])})
	scenery=Scenery.new()
	scenery.name="CountryHinterland"
	add_child(scenery)
	if not scenery.build(soil_mat):
		errors.append_array(scenery.errors)
		return false
	set_detail("high",Vector3(0,0,2),true)
	return true

func set_detail(value: String, camera_position: Vector3, force: bool=false) -> void:
	profile=value if PROFILE.has(value) else "balanced"
	# Hysteresis through 2 m quantization, no per-instance CPU animation.
	var zone:=floori(camera_position.z/2.0)
	if not force and _last_profile==profile and zone==_last_zone:
		return
	_last_profile=profile
	_last_zone=zone
	var settings: Array=PROFILE[profile]
	var gc:=0
	var sc:=0
	var triangles:=int(manifest.get("stats",{}).get("terrainTriangles",0))
	for group: Dictionary in groups:
		var batch: MultiMeshInstance3D=group.node
		var near:=absf(float(zone)*2.0+1.0-(float(group.chunk)*12.0+6.0))<=10.0
		var factor: float
		if group.grass:
			factor=float(settings[0] if near else settings[1])
		else:
			factor=float(settings[2] if near else settings[3])
		var n:=clampi(roundi(float(group.total)*factor),0,int(group.total))
		batch.multimesh.visible_instance_count=n
		batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if near and profile in ["high","very_high"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		triangles+=n*int(group.triangles)
		if group.grass:
			gc+=n
		else:
			sc+=n
	if soil_mat!=null:
		soil_mat.set_shader_parameter("quality",float(settings[4]))
	var trees:=0
	if is_instance_valid(scenery):
		scenery.set_detail(profile,camera_position)
		trees=int(scenery.visible_trees)
		triangles+=int(scenery.triangles)+int(manifest.stats.hinterland.triangles)
	counts={"grass":gc,"stones":sc,"trees":trees,"triangles":triangles}

func set_wind_time(value: float) -> void:
	if is_finite(value) and value>=0.0:
		wind_time=value
		if blade_mat!=null:
			blade_mat.set_shader_parameter("wind_time",wind_time)
		if is_instance_valid(scenery):
			scenery.set_wind_time(wind_time)

func _process(delta: float) -> void:
	if not wind_paused:
		set_wind_time(wind_time+delta)
