extends Node3D
## Visual continuation of the authored walkable area. No new physics or save data.
const ROOT := "res://assets/viva_country/"
const LIBRARY := preload("res://scripts/world_expansion/asset_library.gd")
const SPECIES := ["field_elm","cypress","laurel"]
const RANGES := {"low":48.0,"balanced":75.0,"high":115.0,"very_high":155.0}
var library = LIBRARY.new()
var terrain_count := 0
var tree_count := 0
var visible_trees := 0
var triangles := 0
var errors: Array[String] = []
var batches: Array[Dictionary] = []
var _wind_materials: Array[ShaderMaterial] = []

func build(soil: ShaderMaterial) -> bool:
	if not ResourceLoader.exists(ROOT+"hinterland.glb","PackedScene"):
		errors.append("Missing real terrain continuation")
		return false
	var packed := load(ROOT+"hinterland.glb") as PackedScene
	if packed==null:
		return false
	var ground := packed.instantiate() as Node3D
	add_child(ground)
	for mesh: MeshInstance3D in ground.find_children("*","MeshInstance3D",true,false):
		mesh.material_override=soil
		terrain_count+=1
	if terrain_count!=4:
		errors.append("Expected four adjoining 3D landscape meshes")
		return false
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"hinterland_trees.json"))
	if not data is Dictionary or data.get("schema",0)!=1 or not data.get("trees") is Array:
		errors.append("Invalid landscape placement contract")
		return false
	var prototypes := {}
	for species: String in SPECIES:
		var path := "res://assets/world_expansion/vegetation/"+species+"_lod2.glb"
		var mesh: Mesh=library._import_mesh(path,true)
		if mesh==null:
			errors.append_array(library.errors)
			return false
		prototypes[species]=mesh
	_wind_materials=library.wind_materials
	var cells := {}
	for entry: Dictionary in data.trees:
		var species:=str(entry.get("species",""))
		if not prototypes.has(species):
			errors.append("Unknown tree species")
			return false
		var pos:=Vector3(float(entry.x),float(entry.y),float(entry.z))
		var scale:=float(entry.scale)
		var yaw:=float(entry.yaw)
		if not pos.is_finite() or not is_finite(scale) or not is_finite(yaw) or scale<=0:
			errors.append("Invalid tree placement")
			return false
		var cell:=Vector2i(floori(pos.x/32.0),floori(pos.z/32.0))
		var key:="%s_%d_%d"%[species,cell.x,cell.y]
		if not cells.has(key):
			cells[key]={"species":species,"center":Vector3((cell.x+0.5)*32.0,0,(cell.y+0.5)*32.0),"transforms":[]}
		var basis:=Basis(Vector3.UP,yaw).scaled_local(Vector3.ONE*scale)
		cells[key].transforms.append(Transform3D(basis,pos))
		tree_count+=1
	for key: String in cells:
		var group: Dictionary=cells[key]
		var mesh: Mesh=prototypes[group.species]
		var transforms: Array=group.transforms
		var mm:=MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.mesh=mesh
		mm.instance_count=transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i,transforms[i])
		var batch:=MultiMeshInstance3D.new()
		batch.name="Far_"+key
		batch.multimesh=mm
		batch.extra_cull_margin=0.5
		add_child(batch)
		batches.append({"node":batch,"center":group.center,"total":transforms.size(),"triangles":LIBRARY._triangle_count(mesh)})
	return errors.is_empty() and tree_count==data.trees.size()

func set_detail(profile: String, camera_position: Vector3) -> void:
	visible_trees=0
	triangles=0
	var range_m:=float(RANGES.get(profile,75.0))
	for group: Dictionary in batches:
		var node: MultiMeshInstance3D=group.node
		var center: Vector3=group.center
		var distance:=Vector2(center.x-camera_position.x,center.z-camera_position.z).length()
		node.visible=distance<=range_m+22.7
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if distance<34.0 and profile in ["high","very_high"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if node.visible:
			visible_trees+=int(group.total)
			triangles+=int(group.total)*int(group.triangles)

func set_wind_time(value: float) -> void:
	for mat: ShaderMaterial in _wind_materials:
		mat.set_shader_parameter("wind_time",value)
		mat.set_shader_parameter("wind_strength",0.55)
