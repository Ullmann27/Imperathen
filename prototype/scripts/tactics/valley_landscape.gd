extends Node3D
## The mesh, command cursor and formation slots sample the same height function.
const Rules = preload("res://scripts/battle/battle_model.gd")
var sun := DirectionalLight3D.new()
var foliage: Array[MultiMeshInstance3D] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 2707
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 1.25
	for z in range(-48,49):
		for x in range(-60,61):
			var p := Vector2(x,z) * step
			var h := Rules.ground_height(p.x,p.y)
			var ridge := 0.5 + 0.25 * sin(p.x * 0.42 + p.y * 0.19) + 0.25 * sin(p.y * 0.83)
			var tint := Color("#405738").lerp(Color("#72884d"),ridge)
			var road := absf(p.x - 7.0 * sin(p.y * 0.054) + 0.1 * sin(p.y * 1.7))
			tint = Color("#ae926c").lerp(tint, smoothstep(1.0, 2.6, road))
			surface.set_color(tint)
			surface.set_uv(p * 0.43)
			surface.set_normal(Vector3(Rules.ground_height(p.x-0.1,p.y)-Rules.ground_height(p.x+0.1,p.y),0.2,Rules.ground_height(p.x,p.y-0.1)-Rules.ground_height(p.x,p.y+0.1)).normalized())
			surface.add_vertex(Vector3(p.x,h,p.y))
	for z in 96:
		for x in 120:
			var base := z * 121 + x
			for offset in [0,1,122,0,122,121]:
				surface.add_index(base+offset)
	var ground := MeshInstance3D.new()
	ground.mesh = surface.commit()
	var grass := StandardMaterial3D.new()
	grass.vertex_color_use_as_albedo = true
	grass.vertex_color_is_srgb = true
	grass.albedo_texture = preload("res://assets/terrain/earth_basecolor.png")
	grass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	ground.material_override = grass
	add_child(ground)
	sun.rotation_degrees = Vector3(-43, -32, 0)
	sun.light_color = Color("#ffdfa9")
	sun.light_energy = 1.12
	add_child(sun)
	for obstacle in Rules.OBSTACLES:
		var p := Vector2(obstacle.x, obstacle.z)
		var r := float(obstacle.radius)
		var rock := SphereMesh.new()
		rock.radial_segments = 7
		rock.rings = 3
		_prop(rock, p, 0.03, Vector3(r*1.86,r*0.83,r*1.78), Color("#7b7969"))
	# A camp outside the deployment area and cypress groves beyond both flanks.
	for i in range(5):
		var tent := PrismMesh.new()
		tent.size = Vector3(3, 1.9, 3.8)
		_prop(tent, Vector2(-22.5 + i*2.7, 16 + (i%2)*2.8), 0.95, Vector3.ONE, Color("#ba926e") if i%2 else Color("#d4bd8d"))
	var objective: Vector2 = Rules.OBJECTIVE
	_prop(BoxMesh.new(),objective,1.6,Vector3(0.16,3.2,0.16),Color("#6e4d2f"))
	_prop(BoxMesh.new(),objective + Vector2(0.62,0),2.7,Vector3(1.25,0.8,0.06),Color("#9e433f"))
	for i in range(3):
		var p := Vector2(-22 + i*5, 14.8)
		_prop(BoxMesh.new(),p,2.1,Vector3(0.11,4.2,0.11), Color("#704627"))
		_prop(BoxMesh.new(),p + Vector2(0.55,0),3.62,Vector3(1.1,0.86,0.06),Color("#933d32"))
	var leaves := SphereMesh.new()
	leaves.radial_segments = 7
	leaves.rings = 4
	var trunk := CylinderMesh.new()
	trunk.radial_segments = 5
	var crowns: Array[Transform3D] = []
	var stems: Array[Transform3D] = []
	for i in 136:
		var belt := rng.randf_range(26,52)
		var p := Vector2(belt * (-1 if i%2 else 1),rng.randf_range(-46,43))
		var height := rng.randf_range(2.4,6.2)
		var base := Vector3(p.x, Rules.ground_height(p.x,p.y),p.y)
		crowns.append(Transform3D(Basis.from_scale(Vector3(height * 0.37,height * 0.53,height * 0.37)),base+Vector3.UP*height*0.66))
		crowns.append(Transform3D(Basis.from_scale(Vector3(height*0.26,height*0.47,height*0.26)),base+Vector3.UP*height))
		stems.append(Transform3D(Basis.from_scale(Vector3(0.35,height*0.18,0.35)),base+Vector3.UP*height*0.18))
	_batch(leaves, crowns, Color("#405d43"))
	_batch(trunk, stems, Color("#674d37"))
	var blade := PrismMesh.new()
	blade.size = Vector3(0.19,0.32,0.085)
	var blades: Array[Transform3D] = []
	for i in 1150:
		var p := Vector2(rng.randf_range(-32,32),rng.randf_range(-24,24))
		if absf(p.x-7.0*sin(p.y*0.054)) > 2.25:
			blades.append(Transform3D(Basis(Vector3.UP,rng.randf_range(0,PI)),Vector3(p.x, Rules.ground_height(p.x,p.y)+0.1,p.y)))
	foliage.append(_batch(blade,blades,Color("#788348")))

func _prop(mesh: Mesh, p: Vector2, y: float, size: Vector3, tint: Color) -> void:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.position = Vector3(p.x,Rules.ground_height(p.x,p.y)+y,p.y)
	item.scale = size
	item.material_override = _paint(tint)
	add_child(item)

func _paint(tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.94
	return mat

func _batch(mesh: Mesh, places: Array[Transform3D], tint: Color) -> MultiMeshInstance3D:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = places.size()
	for i in places.size():
		batch.set_instance_transform(i,places[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = batch
	node.material_override = _paint(tint)
	add_child(node)
	return node

func apply_quality(profile: String) -> void:
	sun.shadow_enabled = profile != "low"
	sun.directional_shadow_max_distance = 85.0 if profile == "high" else 48.0
	for node in foliage:
		var fraction := 1.0 if profile == "high" else (0.6 if profile == "balanced" else 0.22)
		node.multimesh.visible_instance_count = int(node.multimesh.instance_count * fraction)
