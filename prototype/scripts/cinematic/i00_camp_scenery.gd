extends RefCounted
## I-00 presentation scenery. All dimensions in metres; deterministic and
## deliberately independent of navigation, NPC logic and combat authority.
const Art = preload("res://scripts/world/village_art.gd")
const Terrain = preload("res://scripts/world/regional_terrain.gd")
const Plan = preload("res://scripts/world/world_stream_plan.gd")
const PLATFORM_MIN := Vector2(-26.0, -39.0)
const PLATFORM_MAX := Vector2(26.0, 23.0)
const TERRAIN_CLEARANCE := 0.12
const APRON_WIDTH := 12.0
const APRON_RINGS := 3
const HALF_W := 1.90
const HALF_D := 1.45
const RIDGE := 2.12
const HEM := 0.07
const GRID_X := 48
const GRID_Z := 56

## Each streamed terrain triangle is linear between the regular grid vertices.
## Cover the entire platform with the enclosing grid, not just its centre.
## These are regional/world-local coordinates, as used by the stage OFFSET.
static func grounded_elevation(at: Vector2) -> float:
	var step := Plan.SECTOR_SIZE_M / float(Terrain.GRID)
	var low := at + PLATFORM_MIN
	var high := at + PLATFORM_MAX
	var highest := -INF
	for z in range(floori(low.y / step), ceili(high.y / step) + 1):
		for x in range(floori(low.x / step), ceili(high.x / step) + 1):
			var ground := Terrain.surface_height(Vector2(float(x) * step, float(z) * step))
			highest = maxf(highest, ground)
	return highest + TERRAIN_CLEARANCE


static func build(parent: Node3D) -> Node3D:
	var camp := Node3D.new()
	camp.name = "CampScenery"
	parent.add_child(camp)
	_ground(camp)
	_terrain_apron(camp, parent.position)
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 1.0
	pole_mesh.bottom_radius = 1.0
	pole_mesh.height = 1.0
	pole_mesh.radial_segments = 8
	pole_mesh.rings = 1
	var timber := Art.material(Color("493a29"), 0.89, false)
	var hemp := Art.material(Color("908168"), 0.96, false)
	var cloth := Art.material(Color.WHITE, 0.94, false)
	cloth.vertex_color_use_as_albedo = true
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var linen := [Color("94866d"), Color("a0967c"), Color("897c65")]
	var index := 0
	for x: float in [-18.0, 18.0]:
		for z: float in [-18.0, -7.0, 4.0]:
			_tent(camp, Vector3(x, 0, z), index, linen[index % linen.size()], cloth, timber, hemp, pole_mesh)
			index += 1
	camp.set_meta("tent_count", index)
	return camp


static func _material_mesh(parent: Node3D, label: String, surface: SurfaceTool, paint: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = surface.commit()
	node.material_override = paint
	parent.add_child(node)
	return node


static func _vertex(surface: SurfaceTool, p: Vector3, color: Color, normal: Vector3) -> void:
	surface.set_normal(normal)
	surface.set_color(color)
	surface.add_vertex(p)


static func _face(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	# Godot's front face is clockwise; use the corresponding outward normal.
	var normal := (c - a).cross(b - a).normalized()
	_vertex(surface, a, color, normal)
	_vertex(surface, b, color, normal)
	_vertex(surface, c, color, normal)


static func _ground_point(x: float, z: float) -> Vector3:
	# Keep the entire walk/formation plane within 25 mm of the original
	# ground so that existing planted feet and authored anchors stay valid.
	var y := 0.015 + 0.005 * sin(x * 1.7 + z * 0.63) + 0.004 * cos(z * 2.1 - x * 0.32)
	return Vector3(x, y, z)


static func _mud_color(p: Vector3) -> Color:
	var variation := 0.5 + 0.24 * sin(p.x * 0.73 + p.z * 1.11) + 0.20 * cos(p.z * 0.43 - p.x * 1.3)
	var shade := Color("302e28").lerp(Color("655647"), clampf(variation, 0.0, 1.0))
	var path := 1.0 - smoothstep(2.4, 3.6, absf(p.x))
	var rut := 1.0 - smoothstep(0.13, 0.58, absf(absf(p.x) - 1.15))
	shade = shade.lerp(Color("504237"), path * 0.52)
	return shade.lerp(Color("282925"), rut * path * 0.65)


static func _ground(parent: Node3D) -> void:
	# The thin support hides the edge of the scenic platform, not the village.
	Art.box(parent, Vector3(52, 0.18, 62), Vector3(0, -0.115, -8), Art.material(Color("302b25"), 0.9, false))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zi in GRID_Z:
		var z0 := -39.0 + 62.0 * float(zi) / GRID_Z
		var z1 := -39.0 + 62.0 * float(zi + 1) / GRID_Z
		for xi in GRID_X:
			var x0 := -26.0 + 52.0 * float(xi) / GRID_X
			var x1 := -26.0 + 52.0 * float(xi + 1) / GRID_X
			var a := _ground_point(x0, z0)
			var b := _ground_point(x1, z0)
			var c := _ground_point(x1, z1)
			var d := _ground_point(x0, z1)
			for p: Vector3 in [a, b, c, a, c, d]:
				_vertex(surface, p, _mud_color(p), Vector3.UP)
	var mud := Art.material(Color.WHITE, 0.76, false)
	mud.vertex_color_use_as_albedo = true
	_material_mesh(parent, "MudSurface", surface, mud)
	_puddles(parent)


## A visual-only embankment closes the raised platform into the existing
## landscape. Its inner edge uses the exact mud grid; its outer edge samples
## the actual streamed surface. No collision/streaming state is modified.
static func _terrain_apron(parent: Node3D, origin: Vector3) -> void:
	var inner: Array[Vector2] = [PLATFORM_MIN, Vector2(PLATFORM_MAX.x, PLATFORM_MIN.y), PLATFORM_MAX, Vector2(PLATFORM_MIN.x, PLATFORM_MAX.y)]
	var low := PLATFORM_MIN - Vector2.ONE * APRON_WIDTH
	var high := PLATFORM_MAX + Vector2.ONE * APRON_WIDTH
	var outer: Array[Vector2] = [low, Vector2(high.x, low.y), high, Vector2(low.x, high.y)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in range(4):
		var next := (side + 1) % 4
		var steps := GRID_X if side % 2 == 0 else GRID_Z
		for i in range(steps):
			var u0 := float(i) / float(steps)
			var u1 := float(i + 1) / float(steps)
			var a := inner[side].lerp(inner[next], u0)
			var b := inner[side].lerp(inner[next], u1)
			var oa := outer[side].lerp(outer[next], u0)
			var ob := outer[side].lerp(outer[next], u1)
			for ring in range(APRON_RINGS):
				var t0 := float(ring) / float(APRON_RINGS)
				var t1 := float(ring + 1) / float(APRON_RINGS)
				var p0 := _apron_point(origin, oa, a, t0)
				var p1 := _apron_point(origin, ob, b, t0)
				var p2 := _apron_point(origin, ob, b, t1)
				var p3 := _apron_point(origin, oa, a, t1)
				_apron_triangle(surface, origin, [p0, p1, p2], [t0, t0, t1])
				_apron_triangle(surface, origin, [p0, p2, p3], [t0, t1, t1])
	var paint := Art.material(Color.WHITE, 0.86, false)
	paint.vertex_color_use_as_albedo = true
	_material_mesh(parent, "TerrainApron", surface, paint)


static func _apron_point(origin: Vector3, outer: Vector2, inner: Vector2, t: float) -> Vector3:
	var at := outer.lerp(inner, t)
	if t >= 1.0:
		return _ground_point(inner.x, inner.y)
	var terrain := Terrain.surface_height(Vector2(origin.x + at.x, origin.z + at.y)) - origin.y
	var crest := _ground_point(inner.x, inner.y).y
	var y := lerpf(terrain + 0.035, crest, smoothstep(0.0, 1.0, t))
	return Vector3(at.x, maxf(terrain + 0.035, y), at.y)


static func _apron_triangle(surface: SurfaceTool, origin: Vector3, points: Array[Vector3], blend: Array[float]) -> void:
	var normal := (points[2] - points[0]).cross(points[1] - points[0]).normalized()
	for i in range(3):
		var p := points[i]
		var color := Terrain.ground_color(origin + p).lerp(_mud_color(p), blend[i])
		_vertex(surface, p, color, normal)


static func _puddles(parent: Node3D) -> void:
	# One opaque, low-roughness batch: no planar reflection, transparency,
	# screen texture, additional lights or particle systems on mobile.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var positions := [Vector2(-4.3, -27), Vector2(4.0, -22), Vector2(-4.6, -17),
		Vector2(4.4, -10), Vector2(-4.1, -3), Vector2(4.2, 4),
		Vector2(-12.0, 1), Vector2(12.8, 3), Vector2(-14, -25), Vector2(14.5, -26),
		Vector2(-6.3, 10), Vector2(6.7, 13)]
	for i in positions.size():
		var at: Vector2 = positions[i]
		var center := Vector3(at.x, 0.029, at.y)
		var radius_x := 0.42 + 0.12 * (i % 4)
		var radius_z := 0.85 + 0.23 * (i % 3)
		for j in 14:
			var a := _puddle_edge(center, radius_x, radius_z, i, j)
			var b := _puddle_edge(center, radius_x, radius_z, i, j + 1)
			_vertex(surface, center, Color("3c3b35"), Vector3.UP)
			_vertex(surface, a, Color("51483b"), Vector3.UP)
			_vertex(surface, b, Color("51483b"), Vector3.UP)
	var water := Art.material(Color.WHITE, 0.24, false)
	water.vertex_color_use_as_albedo = true
	var node := _material_mesh(parent, "RainPuddles", surface, water)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("puddle_count", positions.size())


static func _puddle_edge(center: Vector3, rx: float, rz: float, seed: int, step: int) -> Vector3:
	var t := TAU * float(step % 14) / 14.0
	var irregular := 1.0 + 0.16 * sin(t * 3.0 + seed) + 0.09 * cos(t * 5.0 - seed)
	return center + Vector3(cos(t) * rx * irregular, 0.0, sin(t) * rz * irregular)


static func _canvas_point(a: Vector3, b: Vector3, c: Vector3, d: Vector3, u: float, v: float) -> Vector3:
	var p := a.lerp(b, u).lerp(d.lerp(c, u), v)
	# Sewn edges remain exact, with shallow sag and longitudinal folds.
	p.y -= sin(PI * u) * sin(PI * v) * (0.055 + 0.020 * cos(v * TAU * 3.0))
	return p


static func _panel(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tone: Color) -> void:
	for y in 8:
		for x in 8:
			var u := float(x) / 8.0
			var v := float(y) / 8.0
			var p0 := _canvas_point(a, b, c, d, u, v)
			var p1 := _canvas_point(a, b, c, d, u + 0.125, v)
			var p2 := _canvas_point(a, b, c, d, u + 0.125, v + 0.125)
			var p3 := _canvas_point(a, b, c, d, u, v + 0.125)
			var tint := tone.darkened(0.03 + 0.035 * (1.0 + sin(v * TAU * 3.0)))
			_face(surface, p0, p1, p2, tint)
			_face(surface, p0, p2, p3, tint)


static func _beam(parent: Node3D, a: Vector3, b: Vector3, radius: float, mesh: CylinderMesh, paint: Material) -> void:
	var direction := b - a
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = paint
	node.position = (a + b) * 0.5
	node.quaternion = Quaternion(Vector3.UP, direction.normalized())
	node.scale = Vector3(radius, direction.length(), radius)
	parent.add_child(node)


static func _tent(parent: Node3D, at: Vector3, index: int, tone: Color, cloth: Material, timber: Material, hemp: Material, pole_mesh: CylinderMesh) -> void:
	var tent := Node3D.new()
	tent.name = "CampaignTent_%02d" % index
	tent.position = at
	# Tents face the center aisle rather than away from the soldiers.
	tent.rotation.y = PI * 0.5 if at.x < 0.0 else -PI * 0.5
	parent.add_child(tent)
	var back_l := Vector3(-HALF_W, HEM, -HALF_D)
	var back_r := Vector3(HALF_W, HEM, -HALF_D)
	var front_l := Vector3(-HALF_W, HEM, HALF_D)
	var front_r := Vector3(HALF_W, HEM, HALF_D)
	var ridge_back := Vector3(0, RIDGE, -HALF_D)
	var ridge_front := Vector3(0, RIDGE, HALF_D)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_panel(surface, back_l, ridge_back, ridge_front, front_l, tone)
	_panel(surface, ridge_back, back_r, front_r, ridge_front, tone)
	_face(surface, back_l, back_r, ridge_back, tone.darkened(0.12))
	# Actual open entrance: two flaps leave a triangular doorway, no cube.
	_face(surface, front_l, ridge_front, Vector3(-0.54, HEM, HALF_D + 0.08), tone.darkened(0.07))
	_face(surface, ridge_front, front_r, Vector3(0.54, HEM, HALF_D + 0.08), tone.darkened(0.04))
	_material_mesh(tent, "Canvas", surface, cloth)
	_beam(tent, Vector3(0, HEM, -HALF_D), ridge_back + Vector3.UP * 0.12, 0.047, pole_mesh, timber)
	_beam(tent, Vector3(0, HEM, HALF_D), ridge_front + Vector3.UP * 0.12, 0.047, pole_mesh, timber)
	_beam(tent, ridge_back, ridge_front, 0.036, pole_mesh, timber)
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			var stake := Vector3(x * 2.45, 0.09, z * 1.82)
			var edge := Vector3(x * 1.50, 0.47, z * HALF_D)
			_beam(tent, stake - Vector3.UP * 0.08, stake + Vector3.UP * 0.16, 0.027, pole_mesh, timber)
			_beam(tent, stake, edge, 0.012, pole_mesh, hemp)
	tent.set_meta("guy_count", 4)
	# Supply details are off the entrance center; the inside remains legible.
	for x: float in [-1.25, 1.25]:
		var crate_at := Vector3(x, 0.20, HALF_D + 0.27)
		Art.box(tent, Vector3(0.46, 0.37, 0.47), crate_at, timber)
		for dx: float in [-0.15, 0.15]:
			Art.box(tent, Vector3(0.055, 0.40, 0.49), crate_at + Vector3(dx, 0, 0), timber)
	Art.batch_static(tent)
