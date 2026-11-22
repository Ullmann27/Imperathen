extends SceneTree

const Scenery = preload("res://scripts/world/village/village_scenery.gd")
const NAMES := ["workshop","storehouse","market","palisade_bay","palisade_silhouette","training_dummy","timber_billet"]
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func require(ok: bool, reason: String) -> void:
	if not ok:
		failures.append(reason)

func run() -> void:
	var scenery := Scenery.new()
	root.add_child(scenery)
	scenery.create_land()
	scenery.add_businesses(scenery)
	scenery.sow_field(scenery)
	scenery.palisade_bays(scenery,[Transform3D.IDENTITY])
	var sun := DirectionalLight3D.new()
	scenery.add_child(sun)
	var environment := Environment.new()
	var shared_color: Texture2D
	for label in NAMES:
		var scene := load("res://assets/village/%s.glb" % label) as PackedScene
		var object := scene.instantiate()
		var meshes := object.find_children("*","MeshInstance3D",true,false)
		require(meshes.size()==1,label+" single mesh")
		var mesh: ArrayMesh = meshes[0].mesh
		var material := mesh.surface_get_material(0) as StandardMaterial3D
		require(mesh.get_surface_count()==1,label+" single surface")
		require(material.normal_enabled and material.normal_texture!=null and material.roughness_texture!=null and material.albedo_texture!=null,label+" PBR")
		if shared_color == null:
			shared_color = material.albedo_texture
		require(material.albedo_texture==shared_color,label+" shared atlas")
		var data: Dictionary = mesh.get("_surfaces")[0]
		var levels: Array = data.get("lods",[])
		if label.begins_with("palisade"):
			require(int(data.index_count)/3 < (160 if label.ends_with("silhouette") else 450),label+" authored budget")
		else:
			require(not levels.is_empty(),label+" generated LOD")
		print("VILLAGE_MESH ",label," vertices=",data.vertex_count," triangles=",int(data.index_count)/3," lods=",levels.size()/2," size_m=",mesh.get_aabb().size)
		object.free()
	var allocated := 0
	for patch in scenery._plants:
		allocated += patch.multimesh.instance_count
	require(allocated>500,"instanced flora")
	var previous := 0
	for profile in ["low","balanced","high","very_high"]:
		scenery.set_quality(profile)
		scenery.apply_season(2,sun,environment)
		require(scenery._stockade[0].multimesh.mesh == (scenery._fence_far if profile=="low" else scenery._fence_near),profile+" fence detail")
		var count := 0
		for patch in scenery._plants:
			count += patch.multimesh.visible_instance_count
			require(patch.visibility_range_end==Scenery.RANGES[profile],profile+" culling distance")
		require(count>=previous and count<=allocated,profile+" density")
		print("VILLAGE_PROFILE ",profile," visible_budget=",count," allocated=",allocated," batches=",scenery._plants.size()," range_m=",Scenery.RANGES[profile]," wetness=",scenery.water_material.get_shader_parameter("wetness"))
		previous=count
		require(scenery._rain.visible==(profile!="low"),profile+" drizzle")
		require(scenery.ground_material.get_shader_parameter("wetness")>.8,"autumn mud")
	scenery.apply_season(1,sun,environment)
	require(not scenery._rain.visible and scenery.water_material.get_shader_parameter("wetness")<.1,"summer dries")
	scenery.set_presentation_time(4)
	for material in [scenery.grass_material,scenery.water_material,scenery.rain_material]:
		require(material.get_shader_parameter("fixed_time")==4.0,"presentation time")
	require(scenery.sky_material.get_shader_parameter("phase")==4.0,"cloud phase")
	await physics_frame
	await physics_frame
	var space := root.world_3d.direct_space_state
	for entry in [["ProvisionStore",0.0],["CarpentryWorkshop",1.57]]:
		var building := scenery.get_node(String(entry[0])) as Node3D
		var render_mesh: Mesh = building.find_children("*","MeshInstance3D",true,false)[0].mesh
		var triangles := render_mesh.generate_triangle_mesh()
		for dx: float in [-.20,0.0,.20]:
			for h: float in [.21,1.0,1.77]:
				var a := Vector3(entry[1]+dx,h,2.8)
				var b := Vector3(entry[1]+dx,h,.40)
				require(triangles.intersect_segment(a,b).is_empty(),String(entry[0])+" mesh doorway")
				var query := PhysicsRayQueryParameters3D.create(building.to_global(a),building.to_global(b))
				require(space.intersect_ray(query).is_empty(),String(entry[0])+" physics doorway")
		var wall := PhysicsRayQueryParameters3D.create(building.to_global(Vector3(0,1,0)),building.to_global(Vector3(0,1,-2.6)))
		require(not space.intersect_ray(wall).is_empty(),String(entry[0])+" solid rear wall")
	scenery.free()
	print("VILLAGE_SCENERY errors ",failures)
	quit(0 if failures.is_empty() else 1)
