extends Node3D
## Original, metre-scale dressing derived only from the confirmed companion choice.
## The side brace is outside the existing well; it neither replaces its roof nor
## creates a collision, interaction, reward, repair timer, or second game state.

const WELL_POSITION := Vector3(-7.0, 0.0, 6.0)
const FOOT := Vector3(1.98, 0.15, -0.95)
const POST := Vector3(1.24, 1.57, -0.13)
const SPLINTERS := [-0.035, 0.025, -0.015, 0.048, -0.023, 0.013, -0.042, 0.020]

var _signature := ""
var _paints: Array[StandardMaterial3D] = []
var _surfaces: Array[SurfaceTool] = []
var _triangles: Array[int] = []
var _visual: MeshInstance3D


func _init() -> void:
	name = "OpeningWellRepair"
	position = WELL_POSITION


func sync_state(state: Dictionary) -> void:
	var origin := str(state.get("origin_id", ""))
	var choice := str(state.get("companion", {}).get("choice", ""))
	var signature := origin + ":" + choice
	if signature == _signature:
		return
	_signature = signature
	if is_instance_valid(_visual):
		remove_child(_visual)
		_visual.free()
		_visual = null
	visible = origin == "italia"
	if not visible:
		return
	if _paints.is_empty():
		_create_materials()
	_build(choice == "help")


func _create_materials() -> void:
	var oak := StandardMaterial3D.new()
	oak.resource_name = "Opening_Worn_Oak"
	oak.albedo_texture = preload("res://assets/weapons/gladius_lod0_oak_basecolor.png")
	oak.normal_texture = preload("res://assets/weapons/gladius_lod0_oak_normal.png")
	oak.roughness_texture = preload("res://assets/weapons/gladius_lod0_oak_roughness.png")
	oak.albedo_color = Color(0.74, 0.65, 0.53)
	oak.normal_enabled = true
	oak.normal_scale = 0.65
	oak.roughness = 0.92
	oak.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	oak.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var cut := oak.duplicate() as StandardMaterial3D
	cut.resource_name = "Opening_Fresh_Oak"
	cut.albedo_color = Color(1.0, 0.91, 0.72)
	cut.normal_scale = 0.4
	var hemp := StandardMaterial3D.new()
	hemp.resource_name = "Opening_Hemp_Binding"
	hemp.albedo_texture = preload("res://assets/weapons/scutum_lod0_linen_basecolor.png")
	hemp.normal_texture = preload("res://assets/weapons/scutum_lod0_linen_normal.png")
	hemp.roughness_texture = preload("res://assets/weapons/scutum_lod0_linen_roughness.png")
	hemp.albedo_color = Color(0.78, 0.65, 0.43)
	hemp.normal_enabled = true
	hemp.normal_scale = 0.45
	hemp.roughness = 0.98
	hemp.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	hemp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_paints = [oak, cut, hemp]


func _build(repaired: bool) -> void:
	_surfaces.clear()
	_triangles = [0, 0, 0]
	for material in _paints:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(material)
		_surfaces.append(surface)
	# A low peg and fastening block connect this small external safety brace.
	_timber(Vector3(1.98,0.02,-0.95), Vector3(1.98,0.39,-0.95),0.17,0.17,0)
	_timber(Vector3(1.24,1.43,-0.13), Vector3(1.24,1.68,-0.13),0.20,0.17,0)
	var direction := (POST - FOOT).normalized()
	if repaired:
		_timber(FOOT, POST, 0.15, 0.115, 1)
		var across := _frame(direction)[0]
		# Narrow splice plates and two bindings visibly distinguish the repair.
		for side in [-1.0, 1.0]:
			_timber(FOOT.lerp(POST,0.29)+across*0.089*side, FOOT.lerp(POST,0.73)+across*0.089*side,0.028,0.105,1)
		_binding(FOOT.lerp(POST,0.36),direction,0.116,0.082,4)
		_binding(FOOT.lerp(POST,0.66),direction,0.116,0.082,4)
	else:
		_timber(FOOT, FOOT.lerp(POST,0.43),0.15,0.115,0,false,true)
		_timber(FOOT.lerp(POST,0.59), POST,0.15,0.115,0,true,false)
		# Deterministic splinters lie beside the failed joint, outside the stone rim.
		for i in 4:
			var start := Vector3(1.52+i*0.13,0.028,-0.69-i*0.055)
			_timber(start,start+Vector3(0.18+0.025*i,0.018,0.09-0.035*i),0.025,0.019,1,false,true)
		var loose: Array[Vector3] = [POST+Vector3(0.06,-0.07,-0.04),POST+Vector3(0.08,-0.27,-0.08),POST+Vector3(0.13,-0.40,-0.04)]
		_tube(loose,0.011)
	_binding(FOOT+direction*0.065,direction,0.105,0.087,2)
	_binding(POST-direction*0.065,direction,0.105,0.087,2)
	var geometry := ArrayMesh.new()
	for index in _surfaces.size():
		if _triangles[index] > 0:
			_surfaces[index].generate_tangents()
			_surfaces[index].commit(geometry)
	_visual = MeshInstance3D.new()
	_visual.name = "RepairedSideBrace" if repaired else "BrokenSideBrace"
	_visual.mesh = geometry
	_visual.set_meta("triangle_count", _triangles.reduce(func(a,b): return a+b,0))
	_visual.set_meta("derived_from", "companion.choice")
	add_child(_visual)
	_surfaces.clear()


func _frame(direction: Vector3) -> Array[Vector3]:
	var right := direction.cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		right = direction.cross(Vector3.FORWARD)
	right = right.normalized()
	return [right, right.cross(direction).normalized()]


func _timber(from: Vector3, to: Vector3, width: float, depth: float, material: int, split_from := false, split_to := false) -> void:
	var direction := (to - from).normalized()
	var frame := _frame(direction)
	var bevel := minf(width,depth)*0.11
	var x := width*0.5
	var z := depth*0.5
	var section: Array[Vector2] = [Vector2(-x+bevel,-z),Vector2(x-bevel,-z),Vector2(x,-z+bevel),Vector2(x,z-bevel),Vector2(x-bevel,z),Vector2(-x+bevel,z),Vector2(-x,z-bevel),Vector2(-x,-z+bevel)]
	var low: Array[Vector3] = []
	var high: Array[Vector3] = []
	for i in section.size():
		var lateral := frame[0]*section[i].x + frame[1]*section[i].y
		low.append(from+lateral+direction*float(SPLINTERS[i])*(0.65 if split_from else 0.0))
		high.append(to+lateral+direction*float(SPLINTERS[(i+3)%8])*(0.65 if split_to else 0.0))
	for i in section.size():
		var next := (i+1)%section.size()
		_quad(low[i],high[i],high[next],low[next],material,Vector2(0.3,from.distance_to(to)*1.4))
		_tri(from,low[i],low[next],1 if split_from else material,Vector2(.5,.5),section[i]+Vector2(.5,.5),section[next]+Vector2(.5,.5))
		_tri(to,high[next],high[i],1 if split_to else material,Vector2(.5,.5),section[next]+Vector2(.5,.5),section[i]+Vector2(.5,.5))


func _binding(center: Vector3, direction: Vector3, width: float, depth: float, turns: int) -> void:
	var frame := _frame(direction)
	var points: Array[Vector3] = []
	var segments := turns*16
	for i in segments+1:
		var fraction := float(i)/segments
		var angle := fraction*turns*TAU
		points.append(center+frame[0]*cos(angle)*width+frame[1]*sin(angle)*depth+direction*(fraction-0.5)*turns*0.023)
	_tube(points,0.012)
	# Short end ties do not introduce dangling simulated rope or physics bodies.
	var knot: Array[Vector3] = [points[-1],points[-1]+frame[0]*0.035-direction*0.045,points[-1]-direction*0.075]
	_tube(knot,0.013)


func _tube(points: Array[Vector3], radius: float) -> void:
	if points.size() < 2:
		return
	var rings: Array = []
	for i in points.size():
		var tangent: Vector3 = points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]
		var frame := _frame(tangent.normalized())
		var ring: Array[Vector3] = []
		for side in 6:
			var angle := float(side)*TAU/6.0
			ring.append(points[i]+frame[0]*cos(angle)*radius+frame[1]*sin(angle)*radius)
		rings.append(ring)
	for i in points.size()-1:
		for side in 6:
			var next := (side+1)%6
			_quad(rings[i][side],rings[i+1][side],rings[i+1][next],rings[i][next],2,Vector2(0.24,0.42))
	for side in 6:
		_tri(points[0],rings[0][side],rings[0][(side+1)%6],2,Vector2.ZERO,Vector2.UP,Vector2.RIGHT)
		_tri(points[-1],rings[-1][(side+1)%6],rings[-1][side],2,Vector2.ZERO,Vector2.UP,Vector2.RIGHT)


func _quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,material: int,uv: Vector2) -> void:
	_tri(a,b,c,material,Vector2.ZERO,Vector2(0,uv.y),uv)
	_tri(a,c,d,material,Vector2.ZERO,uv,Vector2(uv.x,0))


func _tri(a: Vector3,b: Vector3,c: Vector3,material: int,ua: Vector2,ub: Vector2,uc: Vector2) -> void:
	var normal := (b-a).cross(c-a).normalized()
	var surface: SurfaceTool = _surfaces[material]
	# Godot's front-face order is clockwise; retain the authored outward normal.
	for vertex in [[a,ua],[c,uc],[b,ub]]:
		surface.set_normal(normal)
		surface.set_uv(vertex[1])
		surface.add_vertex(vertex[0])
	_triangles[material] += 1
