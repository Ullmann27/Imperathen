extends Node3D
## Rendering and decorative geometry for the playable frontier. Metres, +Y up.

const Art = preload("res://scripts/world/village_art.gd")
const PROFILE_DATA = preload("res://assets/quality_profiles.json")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const Hills = preload("res://scripts/world/village/backdrop_hills.gd")
const Land = preload("res://scripts/world/village/valdora_land.gd")
const LandSurface = preload("res://scripts/world/land/land_surface.gd")
const Brook = preload("res://scripts/world/village/brook.gd")
const WATER_LEVEL := Land.WATER_SURFACE_Y
const Look = preload("res://scripts/rendering/village_look.gd")
const HouseFamily = preload("res://scripts/world/village/architecture/valdora_house_family.gd")
const Grove = preload("res://scripts/visuals/grove.gd")
const WORKSHOP := Vector3(-9.2,0,-7.35)
const STORE := Vector3(-10.6,0,15.6)
const MARKET := Vector3(-9,0,0)
const RANGES := {"low":24.0,"balanced":40.0,"high":58.0,"very_high":72.0}
const FLORA_SITES := 5600
const CELL := 14.0
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
var _plant_kinds: Dictionary = {}
var _plant_meshes: Dictionary = {}
var _stockade: Array[MultiMeshInstance3D] = []
var _fence_near: Mesh
var _fence_far: Mesh
var _rain: MultiMeshInstance3D
var _time := 0.0
var _sky_tick := 0.0
var _fixed_time := -1.0
## Northern end of the visible brook water, at the foot of the backdrop hills.
var brook_source_z := -95.0
var land_materials: Array[ShaderMaterial] = []
var _season_tint := Color.WHITE

func _init() -> void:
	ground_material.shader = preload("res://scripts/world/village/ground.gdshader")
	ground_material.set_shader_parameter("road_color",preload("res://assets/village/look/trodden_earth_color.png"))
	# Compacted lane earth and dense turf (blades, dry strands, clover; no bright
	# specks), both from tools/world/village_look_textures.py.
	ground_material.set_shader_parameter("verge_color",preload("res://assets/village/look/meadow_sod_color.png"))
	ground_material.set_shader_parameter("road_relief",preload("res://assets/village/look/trodden_earth_relief.png"))
	ground_material.set_shader_parameter("verge_relief",preload("res://assets/village/look/meadow_sod_relief.png"))
	LandSurface.dress_village_ground(ground_material)
	land_materials.append(ground_material)
	water_material.shader = preload("res://scripts/world/village/water.gdshader")
	water_material.set_shader_parameter("ripple",preload("res://assets/landscape/water_ripple.png"))
	grass_material.shader = preload("res://scripts/world/village/breeze.gdshader")
	rain_material.shader = preload("res://scripts/world/village/drizzle.gdshader")
	sky_material.shader = preload("res://scripts/world/village/clouds.gdshader")
	sky_material.set_shader_parameter("cloud_field",preload("res://assets/village/sky_clouds.png"))

func set_presentation_time(seconds: float) -> void:
	_fixed_time = seconds
	Grove.set_wind_time(seconds)
	for material in [water_material,grass_material,rain_material]:
		material.set_shader_parameter("fixed_time",seconds)
	sky_material.set_shader_parameter("phase",seconds if seconds >= 0 else _time)

func set_origin(id: String) -> void:
	ground_material.set_shader_parameter("frontier_expanded",1.0 if id == "italia" else 0.0)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_sync_atmosphere()
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
	var sparse := profile in ["low","balanced"]
	for patch in _plants:
		patch.multimesh.visible_instance_count = ceili(patch.multimesh.instance_count * fraction)
		patch.visibility_range_end = RANGES[profile]
		# Mobile profiles draw each clump with about 60% of the blades.
		var pair: Array = _plant_meshes.get(_plant_kinds.get(patch,""),[])
		if not pair.is_empty():
			patch.multimesh.mesh = pair[1] if sparse else pair[0]
	grass_material.set_shader_parameter("fade_end",RANGES[profile])
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
	_season_tint = soil[season]
	LandSurface.apply_season(land_materials,season,_season_tint)
	grass_material.set_shader_parameter("season_tint",leaves[season])
	grass_material.set_shader_parameter("gust",GUST[season])
	grass_material.set_shader_parameter("bloom",[1.0,.85,.25,0.0][season])
	for material in [ground_material,water_material]:
		material.set_shader_parameter("wetness",WET[season])
	HouseFamily.set_wetness(WET[season])
	# Sun, sky, ambient and haze presets are owned by the look script.
	Look.apply_season_light(season,sun,environment,sky_material)
	if _rain:
		_rain.visible = season == 2 and profile != "low"

func create_land() -> void:
	brook_source_z = _brook_source()
	# One continuous ground: level land either side of the brook and the sunk
	# brook bed between them. The bed's collision is its visible surface.
	var ground := MeshInstance3D.new()
	ground.name = "TrackAndVerge"
	ground.mesh = Brook.ground_mesh(brook_source_z)
	ground.material_override = ground_material
	add_child(ground)
	for span: Vector2 in [Vector2(Brook.PLANE.position.x,Brook.STRIP_WEST_X),Vector2(Brook.STRIP_EAST_X,Brook.PLANE.end.x)]:
		Art.box_collider(self,Vector3(span.y-span.x,.50,Brook.PLANE.size.y),
			Vector3((span.x+span.y)*.5,-.26,Brook.PLANE.get_center().y))
	var bed := StaticBody3D.new()
	bed.name = "BrookBedCollision"
	bed.collision_layer = 1
	bed.collision_mask = 0
	var bed_shape := CollisionShape3D.new()
	bed_shape.shape = Brook.collision_shape(brook_source_z)
	bed.add_child(bed_shape)
	add_child(bed)
	ground_material.set_shader_parameter("brook_source_z",brook_source_z)
	ground_material.set_shader_parameter("water_surface_y",WATER_LEVEL)
	var stream := MeshInstance3D.new()
	stream.name = "Stream"
	stream.mesh = Brook.water_mesh(brook_source_z)
	stream.material_override = water_material
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stream)
	_make_ridge()
	_make_flora()
	_make_rain()
	set_quality(profile)

## Adds a material of the shared land shader (terrain, far relief): it then
## follows the village ground's textures, the season and the haze.
func register_land(material: ShaderMaterial) -> void:
	if material == null or land_materials.has(material):
		return
	land_materials.append(material)
	LandSurface.follow_village_ground(ground_material,land_materials.slice(1))
	LandSurface.apply_season(land_materials,season,_season_tint)

func _sync_atmosphere() -> void:
	var world := get_world_3d()
	var environment := world.environment if world else null
	var horizon: Variant = sky_material.get_shader_parameter("horizon")
	var zenith: Variant = sky_material.get_shader_parameter("zenith")
	LandSurface.sync_haze(land_materials,environment,horizon if horizon is Color else Color("92b8c8"))
	water_material.set_shader_parameter("sky_horizon",horizon if horizon is Color else Color("92b8c8"))
	water_material.set_shader_parameter("sky_zenith",zenith if zenith is Color else Color("3676aa"))

func _bank(z: float, side: int) -> Vector3:
	var x := -28.0+.52*sin(z*.18)+.23*sin(z*.46)
	return Vector3(x+side*(3.78+.18*sin(z*.56+side)),WATER_LEVEL,z)

## Northernmost row at which the brook and its banks lie on open ground:
## no lifted hill triangle reaches over them.
func _brook_source() -> float:
	var z := -60.0
	var limit := Brook.TERRAIN_OPENINGS[0].position.y+2.0
	while z > limit:
		var next := z-.1
		var reach := Land.brook_half_width(next)+Land.BANK_WIDTH_M+.3
		for side in [-1.0,-.5,0.0,.5,1.0]:
			var p := Vector2(Land.brook_x(next)+side*reach,next)
			if Hills.surface_height(p) > Hills.Terrain.surface_height(p)+.0001:
				return z
		z = next
	return z

func _make_ridge() -> void:
	# A closed landform on the regional ground: its back and ends run out onto
	# the terrain and its collision is the visible surface (world layer 1).
	var ridge := MeshInstance3D.new()
	ridge.name = "Foothills"
	ridge.mesh = Hills.build_mesh()
	var hill_material := Hills.material()
	ridge.material_override = hill_material
	register_land(hill_material)
	ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ridge)
	var body := StaticBody3D.new()
	body.name = "FoothillsCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = ridge.mesh.create_trimesh_shape()
	body.add_child(shape)
	ridge.add_child(body)

func _make_flora() -> void:
	# Dense mixed verges: fine meadow grass with clover, flowering clumps,
	# taller seed grass at walls, fences and field edges, and rushes on the
	# banks. Clumps right beside a trodden lane are smaller (worn edge).
	var rng := RandomNumberGenerator.new()
	rng.seed = 48117
	var clusters := {}
	for i in FLORA_SITES:
		var p: Vector2
		var z := rng.randf_range(-36,32)
		var side := -1 if i%2 else 1
		var kind := "meadow"
		var trodden := 1.0
		if i<1500:
			var offset := rng.randf_range(1.92,5.6)
			p = Vector2(side*offset+.21*sin(z*.17),z)
			trodden = smoothstep(1.85,3.3,offset)
		elif i<2250:
			var offset := rng.randf_range(1.58,4.2)
			p = Vector2(rng.randf_range(-24,27),4+side*offset)
			trodden = smoothstep(1.5,2.9,offset)
		elif i<2700:
			z = rng.randf_range(-56,38)
			p = Vector2(_bank(z,side).x+side*rng.randf_range(.08,.90),z)
			kind = "rush"
		elif i<3500:
			# Uncut grass at the foot of house walls, away from the door side.
			var home: Dictionary = Layout.HOMES[i%Layout.HOMES.size()]
			var rect := Layout.house_footprint(home,rng.randf_range(.5,.95))
			var edge := rng.randi_range(0,2)
			var t := rng.randf()
			var corners := [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
			var front := 2 if is_zero_approx(float(home.yaw)) else 3
			var from: Vector2 = corners[(front+1+edge)%4]
			var to: Vector2 = corners[(front+2+edge)%4]
			p = from.lerp(to,t)
			kind = "tall" if rng.randf()<.55 else "meadow"
		else:
			p = Vector2(rng.randf_range(-42,44),rng.randf_range(-48,34))
		if not _free_verge(p,kind):
			continue
		if kind == "meadow":
			var roll := rng.randf()
			if roll < .17*trodden:
				kind = "flowers"
			elif roll > 1.0-.13*trodden:
				kind = "tall"
		var key := "%s_%d_%d" % [kind,floori(p.x/CELL),floori(p.y/CELL)]
		if not clusters.has(key):
			clusters[key] = {"kind":kind,"sites":[]}
		var size := rng.randf_range(.72,1.30)*lerpf(.52,1.0,trodden)
		var basis := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3(size,size*rng.randf_range(.85,1.18),size))
		clusters[key].sites.append(Transform3D(basis,Vector3(p.x,.002,p.y)))
	for kind in ["meadow","rush","flowers","tall"]:
		_plant_meshes[kind] = [_plant_mesh(kind),_plant_mesh(kind,.6)]
	for key: String in clusters:
		var patch := _batch(_plant_meshes[clusters[key].kind][0],clusters[key].sites)
		_plant_kinds[patch] = clusters[key].kind
		patch.name = key
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		patch.extra_cull_margin = .25
		_plants.append(patch)
		add_child(patch)

func _free_verge(p: Vector2,kind: String) -> bool:
	if Layout.reserved(p,.45) or Layout.road(p):
		return false
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
	# Trodden squares and the western lane (see ground.gdshader) stay bare.
	if absf(p.x+7.0)<1.3 and p.y>-37.0 and p.y<-20.0:
		return false
	for square: Rect2 in [Rect2(-12.4,-5.3,13.4,10.9),Rect2(5.3,-25.8,14.4,5.6),Rect2(2.2,21.0,9.6,6.0)]:
		if square.has_point(p):
			return false
	return p.distance_squared_to(Vector2(-7,6))>1.48

func _leaf_vertex(mesh: SurfaceTool,p: Vector3,color: Color,tip: float,flower := false) -> void:
	mesh.set_uv(Vector2(1.0 if flower else 0.0,tip))
	mesh.set_color(color)
	mesh.set_normal(Vector3(.13,.98,.10))
	mesh.add_vertex(p)

func _blade(mesh: SurfaceTool,base: Vector3,axis: Vector3,height: float,width: float,lean: float,color: Color) -> Vector3:
	var cross := Vector3(-axis.z,0,axis.x)*width
	var middle := base+axis*height*lean*.26+Vector3.UP*height*.55
	var tip := base+axis*height*lean+Vector3.UP*height
	for v in [base-cross,base+cross,middle-cross*.67,base+cross,middle+cross*.67,middle-cross*.67,middle-cross*.67,middle+cross*.67,tip]:
		_leaf_vertex(mesh,v,color,clampf(v.y/height,0,1))
	return tip

func _plant_mesh(kind: String,share := 1.0) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = {"meadow":81,"flowers":47,"rush":224,"wheat":57,"tall":133}[kind]
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_material(grass_material)
	var reeds := kind == "rush"
	var crop := kind == "wheat"
	var tall := kind == "tall"
	var count: int = {"meadow":26,"flowers":20,"rush":11,"wheat":11,"tall":18}[kind]
	for i in ceili(count*share):
		var a := rng.randf_range(0,TAU)
		var axis := Vector3(cos(a),0,sin(a))
		var base := axis*rng.randf_range(.01,.24 if tall else .21)
		var height := rng.randf_range(.13,.34)*(2.55 if reeds or crop else (2.1 if tall else 1.0))
		# Fewer blades in a sparse clump are a little wider to keep the coverage.
		var width := rng.randf_range(.008,.019)*(1.40 if reeds else 1.0)*(1.0+(1.0-share)*.7)
		var color := Color("#56622f").lerp(Color("#a3ab5c"),rng.randf())
		if crop:
			color = Color("#9c8844").lerp(Color("#bda75c"),rng.randf())
		elif tall and i%3 == 0:
			color = Color("#8d8a4c").lerp(Color("#b8a565"),rng.randf())
		var tip := _blade(mesh,base,axis,height,width,.23 if crop else rng.randf_range(.45,.85),color)
		if crop or (reeds and i%4==0) or (tall and i%2==0):
			var seed_color := Color("#af944d") if crop else (Color("#705e40") if reeds else Color("#a89a66"))
			for j in 4:
				var seed := tip-Vector3.UP*(.035*j)
				var fan := Vector3(-axis.z,0,axis.x)*.016*(1.3 if j%2 else -1.3)
				for v in [seed-Vector3.UP*.06,seed+fan,seed+Vector3.UP*.025]:
					_leaf_vertex(mesh,v,seed_color,.95)
		if kind=="flowers" and i%3==0:
			# Petal colour comes from the instance (white, yellow, violet, poppy, blue).
			var bloom_at := tip+Vector3.UP*.012
			for j in 5:
				var petal := Vector3(cos(j*TAU/5),.12,sin(j*TAU/5))*.05
				var edge := Vector3(-petal.z,0,petal.x)*.45
				for v in [bloom_at,bloom_at+petal+edge,bloom_at+petal-edge]:
					_leaf_vertex(mesh,v,Color(1,1,1) if i%2 else Color(.94,.94,.9),1.0,true)
	if kind in ["meadow","flowers"]:
		# Low clover and plantain leaves fill the ground between the blades.
		for i in ceili(5*share):
			var a := rng.randf_range(0,TAU)
			var at := Vector3(cos(a),0,sin(a))*rng.randf_range(.04,.2)+Vector3.UP*.012
			var leaf_color := Color("#46552a").lerp(Color("#6f7a3c"),rng.randf())
			for j in 3:
				var dir := Vector3(cos(a+j*TAU/3),0,sin(a+j*TAU/3))
				var side := Vector3(-dir.z,0,dir.x)*.026
				var reach := at+dir*.07+Vector3.UP*.018
				for v in [at,at+dir*.035+side,reach,at,reach,at+dir*.035-side]:
					_leaf_vertex(mesh,v,leaf_color,.12)
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
