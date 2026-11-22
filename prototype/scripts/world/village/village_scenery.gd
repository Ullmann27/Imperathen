extends Node3D
## Rendering and decorative geometry for the playable frontier. Metres, +Y up.

const Art = preload("res://scripts/world/village_art.gd")
const PROFILE_DATA = preload("res://assets/quality_profiles.json")
const WORKSHOP := Vector3(-9.2,0,-7.35)
const STORE := Vector3(-10.6,0,15.6)
const MARKET := Vector3(-9,0,0)
const RANGES := {"low":24.0,"balanced":40.0,"high":58.0,"very_high":72.0}
const GUST := [.78,.55,1.48,1.04]
const WET := [.2,.03,.83,.42]
var profile := "balanced"
var season := 0
var ground_material := ShaderMaterial.new()
var water_material := ShaderMaterial.new()
var grass_material := ShaderMaterial.new()
var rain_material := ShaderMaterial.new()
var sky_material := ShaderMaterial.new()
var _plants: Array[MultiMeshInstance3D] = []
var _stockade: Array[MultiMeshInstance3D] = []
var _fence_near: Mesh
var _fence_far: Mesh
var _rain: MultiMeshInstance3D
var _time := 0.0
var _sky_tick := 0.0
var _fixed_time := -1.0

func _init() -> void:
	ground_material.shader = preload("res://scripts/world/village/ground.gdshader")
	ground_material.set_shader_parameter("road_color",preload("res://assets/village/track_color.png"))
	ground_material.set_shader_parameter("verge_color",preload("res://assets/village/verge_color.png"))
	ground_material.set_shader_parameter("road_relief",preload("res://assets/village/track_relief.png"))
	ground_material.set_shader_parameter("verge_relief",preload("res://assets/village/verge_relief.png"))
	water_material.shader = preload("res://scripts/world/village/water.gdshader")
	grass_material.shader = preload("res://scripts/world/village/breeze.gdshader")
	rain_material.shader = preload("res://scripts/world/village/drizzle.gdshader")
	sky_material.shader = preload("res://scripts/world/village/clouds.gdshader")
	sky_material.set_shader_parameter("cloud_field",preload("res://assets/village/sky_clouds.png"))

func set_presentation_time(seconds: float) -> void:
	_fixed_time = seconds
	for material in [water_material,grass_material,rain_material]:
		material.set_shader_parameter("fixed_time",seconds)
	sky_material.set_shader_parameter("phase",seconds if seconds >= 0 else _time)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_sky_tick += delta
	if _sky_tick >= 2.0 and _fixed_time < 0 and profile != "low":
		_sky_tick = 0
		sky_material.set_shader_parameter("phase",_time)
	if _rain and _rain.visible:
		var camera := get_viewport().get_camera_3d()
		if camera:
			_rain.global_position = Vector3(camera.global_position.x,0,camera.global_position.z)

func set_quality(next_profile: String) -> void:
	profile = next_profile if RANGES.has(next_profile) else "balanced"
	var budget: Dictionary = PROFILE_DATA.data.profiles[profile]
	var fraction := float(budget.decoration_fraction)
	for patch in _plants:
		patch.multimesh.visible_instance_count = ceili(patch.multimesh.instance_count * fraction)
		patch.visibility_range_end = RANGES[profile]
	for bay in _stockade:
		bay.multimesh.mesh = _fence_far if profile == "low" else _fence_near
	ground_material.set_shader_parameter("relief_strength",.44 if profile == "low" else .78)
	water_material.set_shader_parameter("detail",0.0 if profile == "low" else 1.0)
	if _rain:
		_rain.multimesh.visible_instance_count = roundi(_rain.multimesh.instance_count*fraction)
		_rain.visible = season == 2 and profile != "low"

func apply_season(index: int, sun: DirectionalLight3D, environment: Environment) -> void:
	season = posmod(index,4)
	var soil := [Color("#e4ecb4"),Color("#e9d29e"),Color("#d8bea5"),Color("#c1c9c9")]
	var leaves := [Color("#f0ffcf"),Color("#f3daa1"),Color("#cca67a"),Color("#b6b9a4")]
	ground_material.set_shader_parameter("season_tint",soil[season])
	grass_material.set_shader_parameter("season_tint",leaves[season])
	grass_material.set_shader_parameter("gust",GUST[season])
	for material in [ground_material,water_material]:
		material.set_shader_parameter("wetness",WET[season])
	sun.light_color = [Color("#fff1d6"),Color("#ffebc7"),Color("#eee5d1"),Color("#e6edfa")][season]
	sun.light_energy = [.46,.55,.32,.44][season]
	sun.rotation_degrees = Vector3([-43.0,-56.0,-32.0,-27.0][season],[-34.0,-29.0,-47.0,-39.0][season],0)
	environment.ambient_light_color = [Color("#cbd6da"),Color("#d9d5c0"),Color("#c2cdd2"),Color("#d0dbe3")][season]
	environment.ambient_light_energy = [.60,.55,.65,.62][season]
	environment.fog_density = [.0020,.0027,.0055,.0046][season]
	environment.fog_light_color = [Color("#a6b3b0"),Color("#c4b8a0"),Color("#a5ada7"),Color("#b7bfc4")][season]
	sky_material.set_shader_parameter("coverage",[.43,.30,.86,.61][season])
	sky_material.set_shader_parameter("zenith",[Color("#3676aa"),Color("#4d83ac"),Color("#637e91"),Color("#62849c")][season])
	sky_material.set_shader_parameter("horizon",[Color("#92b8c8"),Color("#b2c2c3"),Color("#aab6b7"),Color("#a6bac3")][season])
	sky_material.set_shader_parameter("cloud_color",[Color("#efead9"),Color("#efe3cf"),Color("#bec7c4"),Color("#dae0dc")][season])
	if _rain:
		_rain.visible = season == 2 and profile != "low"

func create_land() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "TrackAndVerge"
	var plain := PlaneMesh.new()
	plain.size = Vector2(180,170)
	ground.mesh = plain
	ground.material_override = ground_material
	ground.position = Vector3(0,-.008,-15)
	add_child(ground)
	# Keep the same solid ground and bridge crossing under the continuous visual surface.
	Art.box_collider(self,Vector3(180,.50,170),Vector3(0,-.26,-15))
	var water := SurfaceTool.new()
	water.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 80:
		var z := -95.0+row*2.0
		var a := _bank(z,-1)
		var b := _bank(z,1)
		var c := _bank(z+2,1)
		var d := _bank(z+2,-1)
		for v in [a,b,d,b,c,d]:
			water.set_normal(Vector3.UP)
			water.set_uv(Vector2(v.x,v.z))
			water.set_tangent(Plane(1,0,0,1))
			water.add_vertex(v)
	var stream := MeshInstance3D.new()
	stream.name = "Stream"
	stream.mesh = water.commit()
	stream.material_override = water_material
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stream)
	_make_ridge()
	_make_flora()
	_make_rain()
	set_quality(profile)

func _bank(z: float, side: int) -> Vector3:
	var x := -28.0+.52*sin(z*.18)+.23*sin(z*.46)
	return Vector3(x+side*(3.78+.18*sin(z*.56+side)),.021,z)

func _make_ridge() -> void:
	# The far ridge begins beyond the northern play boundary. An irregular terrain
	# surface gives it a continuous silhouette with exposed stone above the scrub.
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.roughness = .96
	mesh.set_material(paint)
	for row in 10:
		for column in 81:
			var x := -163.0+column*4
			var z := -56.0-row*5
			for p in [Vector2(x,z),Vector2(x,z-5),Vector2(x+4,z),Vector2(x+4,z),Vector2(x,z-5),Vector2(x+4,z-5)]:
				var h := _ridge_height(p)
				var rock := smoothstep(9,20,h+3*sin(p.x*.14))
				var shade := Color("#687451").lerp(Color("#a1957b"),rock).darkened(.13*abs(sin(p.x*.3+p.y*.52)))
				mesh.set_color(shade.srgb_to_linear())
				mesh.add_vertex(Vector3(p.x,h,p.y))
	mesh.generate_normals()
	mesh.index()
	var ridge := MeshInstance3D.new()
	ridge.name = "Foothills"
	ridge.mesh = mesh.commit()
	ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ridge)

func _ridge_height(p: Vector2) -> float:
	var rise := smoothstep(0,1,(-p.y-56.0)/38.0)
	return -.15+rise*(11.0+4.2*sin(p.x*.069)+2.5*sin(p.x*.16+p.y*.079)+1.45*cos(p.x*.22-p.y*.14)+1.05*sin(p.x*.473+p.y*.24))

func _make_flora() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 48117
	var clusters := {}
	for i in 2200:
		var p: Vector2
		var z := rng.randf_range(-36,32)
		var side := -1 if i%2 else 1
		var kind := "meadow"
		if i<670:
			p = Vector2(side*rng.randf_range(2.05,4.55)+.21*sin(z*.17),z)
		elif i<1080:
			p = Vector2(rng.randf_range(-24,27),4+side*rng.randf_range(1.65,3.50))
		elif i<1410:
			z = rng.randf_range(-56,38)
			p = Vector2(_bank(z,side).x+side*rng.randf_range(.08,.90),z)
			kind = "rush"
		else:
			p = Vector2(rng.randf_range(-40,42),z)
		if not _free_verge(p,kind):
			continue
		if kind == "meadow" and i%9 == 0:
			kind = "flowers"
		var key := "%s_%d_%d" % [kind,floori(p.x/12),floori(p.y/12)]
		if not clusters.has(key):
			clusters[key] = {"kind":kind,"sites":[]}
		var size := rng.randf_range(.67,1.34)
		var basis := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*size)
		clusters[key].sites.append(Transform3D(basis,Vector3(p.x,.002,p.y)))
	var prototypes := {}
	for kind in ["meadow","rush","flowers"]:
		prototypes[kind] = _plant_mesh(kind)
	for key: String in clusters:
		var patch := _batch(prototypes[clusters[key].kind],clusters[key].sites)
		patch.name = key
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		patch.extra_cull_margin = .15
		_plants.append(patch)
		add_child(patch)

func _free_verge(p: Vector2,kind: String) -> bool:
	if absf(p.y-4)<1.53 and p.x>-34 and p.x<24:
		return false
	if absf(p.x)<1.80 or Rect2(4.8,-4.2,19.4,17.5).has_point(p):
		return false
	if kind != "rush" and absf(p.x-_bank(p.y,0).x)<3.88:
		return false
	for rect in [Rect2(-17.4,7.4,9.4,6.6),Rect2(-19.5,-14.1,11.4,6.0),
			Rect2(-10.8,-21.9,11.3,5.8),Rect2(14.2,-21.0,11.6,6.0),
			Rect2(8.1,-35.5,11.8,10.9),Rect2(5.9,-19.6,10.3,5.2),
			Rect2(-12.1,-9.6,5.8,4.5),Rect2(-13.0,13.5,4.8,4.0),
			Rect2(-11.0,-1.2,4.0,2.4),Rect2(-3.2,-9.7,6.4,5.4)]:
		if rect.has_point(p):
			return false
	return p.distance_squared_to(Vector2(-7,6))>1.48

func _leaf_vertex(mesh: SurfaceTool,p: Vector3,color: Color,tip: float) -> void:
	mesh.set_uv(Vector2(0,tip))
	mesh.set_color(color)
	mesh.set_normal(Vector3(.13,.98,.10))
	mesh.add_vertex(p)

func _plant_mesh(kind: String) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = {"meadow":81,"flowers":47,"rush":224,"wheat":57}[kind]
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_material(grass_material)
	var reeds := kind == "rush"
	var crop := kind == "wheat"
	for i in (11 if reeds or crop else 17):
		var a := rng.randf_range(0,TAU)
		var axis := Vector3(cos(a),0,sin(a))
		var base := axis*rng.randf_range(.015,.19)
		var height := rng.randf_range(.14,.32)*(2.55 if reeds or crop else 1.0)
		var width := rng.randf_range(.011,.024)*(1.40 if reeds else 1.0)
		var cross := Vector3(-axis.z,0,axis.x)*width
		var middle := base+axis*height*.18+Vector3.UP*height*.53
		var tip := base+axis*height*(.23 if crop else .71)+Vector3.UP*height
		var color := Color("#646f3b").lerp(Color("#a6ac63"),rng.randf())
		if crop:
			color = Color("#9c8844").lerp(Color("#bda75c"),rng.randf())
		for v in [base-cross,base+cross,middle-cross*.67,base+cross,middle+cross*.67,middle-cross*.67,middle-cross*.67,middle+cross*.67,tip]:
			_leaf_vertex(mesh,v,color,clampf(v.y/height,0,1))
		if crop or (reeds and i%4==0):
			var seed_color := Color("#af944d") if crop else Color("#705e40")
			for j in 4:
				var seed := tip-Vector3.UP*(.035*j)
				var fan := cross*(1.3 if j%2 else -1.3)
				for v in [seed-Vector3.UP*.06,seed+fan,seed+Vector3.UP*.025]:
					_leaf_vertex(mesh,v,seed_color,.95)
		if kind=="flowers" and i%4==0:
			for j in 5:
				var petal := Vector3(cos(j*TAU/5),.1,sin(j*TAU/5))*.047
				var edge := Vector3(-petal.z,0,petal.x)*.41
				for v in [tip,tip+petal+edge,tip+petal-edge]:
					_leaf_vertex(mesh,v,Color("#ded4a0") if i%8 else Color("#ddb461"),1.0)
	mesh.index()
	return mesh.commit()

func _make_rain() -> void:
	var streak := SurfaceTool.new()
	streak.begin(Mesh.PRIMITIVE_TRIANGLES)
	streak.set_material(rain_material)
	for v in [Vector3(-.022,.22,0),Vector3(.003,0,0),Vector3(.019,.22,0)]:
		streak.add_vertex(v)
	var rain := MultiMesh.new()
	rain.transform_format = MultiMesh.TRANSFORM_3D
	rain.use_custom_data = true
	rain.mesh = streak.commit()
	rain.instance_count = 260
	var rng := RandomNumberGenerator.new()
	rng.seed = 71591
	for i in rain.instance_count:
		var pos := Vector3(rng.randf_range(-11,11),rng.randf_range(7,11),rng.randf_range(-11,11))
		rain.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)),pos))
		rain.set_instance_custom_data(i,Color(rng.randf(),0,0,1))
	rain.custom_aabb = AABB(Vector3(-12,-3,-12),Vector3(24,15,24))
	_rain = MultiMeshInstance3D.new()
	_rain.name = "AutumnDrizzle"
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain.multimesh = rain
	_rain.hide()
	add_child(_rain)

func _batch(mesh: Mesh,sites: Array) -> MultiMeshInstance3D:
	var result := MultiMeshInstance3D.new()
	result.multimesh = MultiMesh.new()
	result.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	result.multimesh.mesh = mesh
	result.multimesh.instance_count = sites.size()
	for i in sites.size():
		result.multimesh.set_instance_transform(i,sites[i])
	return result

func add_businesses(parent: Node3D) -> void:
	var market := _place(preload("res://assets/village/market.glb"),parent,MARKET,"Market")
	Art.box_collider(market,Vector3(3,.16,1.2),Vector3(0,.85,0))
	var workshop := _place(preload("res://assets/village/workshop.glb"),parent,WORKSHOP,"CarpentryWorkshop")
	Art.box_collider(workshop,Vector3(4.65,2.42,.20),Vector3(0,1.21,-1.48))
	Art.box_collider(workshop,Vector3(.20,2.40,2.96),Vector3(-2.32,1.20,0))
	Art.box_collider(workshop,Vector3(.20,1.20,1.84),Vector3(2.32,.60,-.54))
	Art.box_collider(workshop,Vector3(2.25,.98,.85),Vector3(-.73,.49,.13))
	for x in [-2.32,0,2.32]:
		Art.box_collider(workshop,Vector3(.18,2.48,.18),Vector3(x,1.24,1.48))
	var store := _place(preload("res://assets/village/storehouse.glb"),parent,STORE,"ProvisionStore")
	store.rotation.y = PI
	for side in [-1,1]:
		Art.box_collider(store,Vector3(.20,2.12,2.42),Vector3(side*1.87,1.06,0))
		Art.box_collider(store,Vector3(1.35,2.08,.18),Vector3(side*1.19,1.04,1.19))
	Art.box_collider(store,Vector3(3.76,2.12,.20),Vector3(0,1.06,-1.20))

func _place(scene: PackedScene,parent: Node3D,at: Vector3,label_text: String) -> Node3D:
	var instance := scene.instantiate() as Node3D
	instance.name = label_text
	instance.position = at
	parent.add_child(instance)
	return instance

func palisade_bays(parent: Node3D,poses: Array) -> void:
	if _fence_near == null:
		_fence_near = _asset_mesh(preload("res://assets/village/palisade_bay.glb"))
		_fence_far = _asset_mesh(preload("res://assets/village/palisade_silhouette.glb"))
	var group := _batch(_fence_far if profile == "low" else _fence_near,poses)
	group.name = "SplitOakBays"
	_stockade.append(group)
	parent.add_child(group)

func _asset_mesh(scene: PackedScene) -> Mesh:
	var source := scene.instantiate()
	var child := source.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
	var mesh := child.mesh
	source.free()
	return mesh

func sow_field(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8714
	var sites := []
	for x in range(12):
		for j in range(15):
			var size := rng.randf_range(.69,1.04)
			var origin := Vector3(6.73+x*.75+rng.randf_range(-.08,.08),.035,-19.03+j*.29)
			sites.append(Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*size),origin))
	var grain := _batch(_plant_mesh("wheat"),sites)
	grain.name = "GrainHeads"
	grain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(grain)
