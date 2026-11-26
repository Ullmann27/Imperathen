extends Node3D
## Valdora paving and paths: cobbled square around the well and market, an
## apron in front of every house entrance (matching its wealth tier), an eaves
## drip strip, trodden or gravelled paths from each door to the nearest lane
## and puddle hollows on the main lanes. Surfaces lie flat 6 mm above the
## ground plane (collider top -0.01 m), so feet, collision and the visible
## paving agree; set stones stand at most 15 mm proud. Visual only: no
## colliders, no navigation or ledger change.

const Family = preload("res://scripts/world/village/architecture/valdora_house_family.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const SHADER = preload("res://scripts/world/village/architecture/valdora_paving.gdshader")
const ASSET_DIR := "res://assets/architecture/valdora/"
const SURFACE_Y := -0.002
const CHUNK := 32.0
const REPEATS := [1.6, 2.4, 1.6, 2.0, 2.4, 1.2, 2.0, 2.0]
enum {COBBLES, FLAGS, GRAVEL, SOIL, SILEX, KERB, TURF, MUD}
## Lane centre lines of the village ground (ground.gdshader, village_layout.road).
const LANES := [
	[Vector2(0, -63), Vector2(0, 39)], [Vector2(-26, 4), Vector2(22, 4)], [Vector2(30, -45), Vector2(30, 27)],
	[Vector2(-18, -36.5), Vector2(34, -36.5)], [Vector2(-18, 28), Vector2(44, 28)], [Vector2(2, 24), Vector2(28, 24)],
	[Vector2(-7, -37.5), Vector2(-7, -19.5)],
]
const RANGES := {"low": 40.0, "balanced": 70.0, "high": 110.0, "very_high": 150.0}

var profile := "balanced"
var patches: Array[Dictionary] = []
var _chunks: Dictionary = {}
var _materials: Dictionary = {}
var _stones: MultiMeshInstance3D
var _nodes: Array[GeometryInstance3D] = []


func build(region: Node3D) -> void:
	_plan(region)
	for patch: Dictionary in patches:
		_emit(patch)
	for key: Vector2i in _chunks:
		var tool: SurfaceTool = _chunks[key]
		tool.index()
		tool.generate_tangents()
		var node := MeshInstance3D.new()
		node.name = "Paving_%d_%d" % [key.x, key.y]
		node.mesh = tool.commit()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_nodes.append(node)
	_place_stones(region)
	set_quality(profile)


func set_quality(next: String) -> void:
	profile = next if RANGES.has(next) else "balanced"
	var paint := _material(profile)
	for node: GeometryInstance3D in _nodes:
		node.material_override = paint
		node.visibility_range_end = RANGES[profile]
		node.visibility_range_end_margin = 4.0
	if _stones:
		_stones.material_override = Family.material(profile, Color("dfd4bd"), "weathered")
		_stones.visibility_range_end = RANGES[profile] * .6


func _material(p: String) -> ShaderMaterial:
	if _materials.has(p):
		return _materials[p]
	var size: int = {"low": 256, "very_high": 1024}.get(p, 512)
	var result := ShaderMaterial.new()
	result.shader = SHADER
	result.resource_name = "VH_ValdoraPaving_" + p
	result.set_shader_parameter("albedo_layers", load(ASSET_DIR + "paving_albedo_%d.jpg" % size))
	result.set_shader_parameter("orm_layers", load(ASSET_DIR + "paving_orm_%d.jpg" % size))
	result.set_shader_parameter("use_normal_map", p != "low")
	if p != "low":
		result.set_shader_parameter("normal_layers", load(ASSET_DIR + "paving_normal_%d.jpg" % size))
	result.set_shader_parameter("use_parallax", p in ["high", "very_high"])
	Family.register_material(result)
	_materials[p] = result
	return result


## Patch plan in world metres: {poly: PackedVector2Array, layer, fringe, moss, dust, hollow, seed}
func _plan(region: Node3D) -> void:
	patches.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 58117
	# Cobbled square around the well and the market stall, flags ringing the well.
	patches.append(_blob(Vector2(-7.6, 3.4), Vector2(6.2, 5.0), 0.0, COBBLES, rng, 1.4, .35, .45, .25))
	patches.append(_blob(Vector2(-7.0, 6.0), Vector2(2.3, 2.3), 0.0, FLAGS, rng, .6, .2, .3, .1))
	patches[-1]["lift"] = 1
	for home: Dictionary in Layout.HOMES:
		var house := region.get_node_or_null(NodePath(home.id)) as Node3D
		if house == null or not Family.is_family_house(house):
			continue
		var data := Family.variant_data(house.get_meta("house_variant"))
		var tier := int(data.get("tier", 2))
		var entry: Dictionary = data.get("metadata", {}).get("entry", {"ramp_start_z": 2.95, "ramp_run": 1.05})
		var foot := float(entry.ramp_start_z) + float(entry.ramp_run)
		var xf := house.transform
		# Apron in front of the ramp foot.
		var apron_layer := SOIL if tier == 1 else (COBBLES if tier == 2 else FLAGS)
		var half := 1.5 if tier < 3 else 2.4
		var apron := PackedVector2Array()
		for p: Vector2 in _round_rect(Vector2(0, foot + .75), Vector2(half, .95), .45, rng):
			var w := xf * Vector3(p.x, 0, p.y)
			apron.append(Vector2(w.x, w.z))
		patches.append({"poly": apron, "layer": apron_layer, "fringe": .9 if tier == 1 else .55, "moss": .25 if tier == 3 else .45,
			"dust": .5, "hollow": .3, "seed": rng.randf(), "lift": 2})
		# Eaves drip strip of gravel where roof water falls.
		var eave_front := str(data.get("roof", "gable_front")) == "eave_front"
		var strips := []
		if eave_front:
			strips = [[Vector2(-3.2, 2.62), Vector2(-.95, 3.2)], [Vector2(.95, 2.62), Vector2(3.2, 3.2)]]
		else:
			strips = [[Vector2(3.05, -2.6), Vector2(3.65, 2.6)], [Vector2(-3.65, -2.6), Vector2(-3.05, 2.6)]]
		if not bool(data.get("features", {}).get("porch", false)):
			for s: Array in strips:
				var poly := PackedVector2Array()
				for p: Vector2 in _round_rect((s[0] + s[1]) * .5, (s[1] - s[0]) * .5, .12, rng):
					var w := xf * Vector3(p.x, 0, p.y)
					poly.append(Vector2(w.x, w.z))
				patches.append({"poly": poly, "layer": GRAVEL, "fringe": .35, "moss": .55, "dust": .3, "hollow": .6, "seed": rng.randf(), "lift": 1})
		# Path from the apron to the nearest lane when it does not cross a house.
		var start3 := xf * Vector3(0, 0, foot + 1.6)
		var start := Vector2(start3.x, start3.z)
		var target := _nearest_lane(start)
		if start.distance_to(target) > .8 and start.distance_to(target) < 18.0 and _clear(start, target):
			patches.append(_path(start, target, SOIL if tier < 3 else GRAVEL, 1.05 if tier < 3 else 1.3, rng))
	# Rutted hollows on the main lanes that fill in wet seasons.
	for at: Vector2 in [Vector2(.6, -8), Vector2(-.5, 12), Vector2(.4, -27), Vector2(29.6, -2), Vector2(14, 4.3), Vector2(8, -36.2)]:
		patches.append(_blob(at, Vector2(rng.randf_range(1.0, 1.7), rng.randf_range(.6, 1.0)), rng.randf_range(-.3, .3), MUD, rng, .9, .1, .2, 1.0))


func _blob(centre: Vector2, radii: Vector2, angle: float, layer: int, rng: RandomNumberGenerator, fringe: float, moss: float, dust: float, hollow: float) -> Dictionary:
	var poly := PackedVector2Array()
	var phase := rng.randf() * TAU
	for i in 28:
		var a := TAU * i / 28.0
		var wobble := 1.0 + .10 * sin(a * 3.0 + phase) + .06 * sin(a * 5.0 + phase * 2.0) + rng.randf_range(-.03, .03)
		poly.append(centre + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(angle) * wobble)
	return {"poly": poly, "layer": layer, "fringe": fringe, "moss": moss, "dust": dust, "hollow": hollow, "seed": rng.randf()}


func _round_rect(centre: Vector2, half: Vector2, radius: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out := PackedVector2Array()
	var r := minf(radius, minf(half.x, half.y))
	var corners := [Vector2(half.x - r, half.y - r), Vector2(-half.x + r, half.y - r), Vector2(-half.x + r, -half.y + r), Vector2(half.x - r, -half.y + r)]
	for c in 4:
		for k in 5:
			var a := PI * .5 * c + PI * .5 * k / 4.0
			out.append(centre + corners[c] + Vector2(cos(a), sin(a)) * r * (1.0 + rng.randf_range(-.08, .08)))
	return out


func _path(a: Vector2, b: Vector2, layer: int, width: float, rng: RandomNumberGenerator) -> Dictionary:
	var axis := (b - a).normalized()
	var side := Vector2(-axis.y, axis.x)
	var bend := rng.randf_range(-.6, .6)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var steps := maxi(3, ceili(a.distance_to(b) / .8))
	for i in steps + 1:
		var t := float(i) / steps
		var centre := a.lerp(b + axis * .6, t) + side * bend * sin(PI * t)
		var w := width * .5 * (1.0 + .18 * sin(t * 9.0 + bend * 4.0))
		left.append(centre + side * w)
		right.append(centre - side * w)
	right.reverse()
	left.append_array(right)
	return {"poly": left, "layer": layer, "fringe": .55, "moss": .2, "dust": .7, "hollow": .45, "seed": rng.randf()}


func _nearest_lane(p: Vector2) -> Vector2:
	var best := p + Vector2(1000, 0)
	for lane: Array in LANES:
		var q := Geometry2D.get_closest_point_to_segment(p, lane[0], lane[1])
		if q.distance_squared_to(p) < best.distance_squared_to(p):
			best = q
	return best


func _clear(a: Vector2, b: Vector2) -> bool:
	var steps := ceili(a.distance_to(b) / .4)
	for i in range(1, steps):
		if Layout.reserved(a.lerp(b, float(i) / steps), .25):
			return false
	return true


## Triangulate a patch on a 0.5 m grid and assign coverage from the border distance.
func _emit(patch: Dictionary) -> void:
	var poly: PackedVector2Array = patch.poly
	var fringe := float(patch.fringe)
	var lo := poly[0]
	var hi := poly[0]
	for p: Vector2 in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	lo -= Vector2.ONE * fringe
	hi += Vector2.ONE * fringe
	const STEP := .5
	var nx := ceili((hi.x - lo.x) / STEP)
	var nz := ceili((hi.y - lo.y) / STEP)
	var layer := float(patch.layer)
	var seed := float(patch.seed)
	var repeat := float(REPEATS[int(patch.layer)])
	var turn := Transform2D(seed * TAU, Vector2.ZERO)
	for i in nx:
		for j in nz:
			var corners := [lo + Vector2(i, j) * STEP, lo + Vector2(i + 1, j) * STEP, lo + Vector2(i + 1, j + 1) * STEP, lo + Vector2(i, j + 1) * STEP]
			var coverage := []
			var any := false
			for c: Vector2 in corners:
				var d := _signed_distance(c, poly)
				var cov := clampf(.5 - d / maxf(fringe, .05), 0.0, 1.0)
				coverage.append(cov)
				any = any or cov > 0.0
			if not any:
				continue
			var centre: Vector2 = (corners[0] + corners[2]) * .5
			var key := Vector2i(floori(centre.x / CHUNK), floori(centre.y / CHUNK))
			if not _chunks.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				_chunks[key] = tool
			var st: SurfaceTool = _chunks[key]
			# Clockwise seen from above (Godot front faces).
			for k in [0, 1, 2, 0, 2, 3]:
				var c: Vector2 = corners[k]
				st.set_uv((turn * c) / repeat)
				st.set_uv2(Vector2(layer, seed))
				st.set_color(Color(coverage[k], float(patch.moss), float(patch.dust), float(patch.hollow)))
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(c.x, SURFACE_Y + float(patch.get("lift", 0)) * .002, c.y))


func _signed_distance(p: Vector2, poly: PackedVector2Array) -> float:
	var best := INF
	for i in poly.size():
		var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		best = minf(best, p.distance_to(q))
	return -best if Geometry2D.is_point_in_polygon(p, poly) else best


## Real set stones: kerbs along flag aprons, stepping stones on poor plots,
## a broken ring of edge stones around the square. Tops <= 15 mm proud.
func _place_stones(region: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90417
	var sites: Array[Transform3D] = []
	for home: Dictionary in Layout.HOMES:
		var house := region.get_node_or_null(NodePath(home.id)) as Node3D
		if house == null or not Family.is_family_house(house):
			continue
		var data := Family.variant_data(house.get_meta("house_variant"))
		var tier := int(data.get("tier", 2))
		var entry: Dictionary = data.get("metadata", {}).get("entry", {"ramp_start_z": 2.95, "ramp_run": 1.05})
		var foot := float(entry.ramp_start_z) + float(entry.ramp_run)
		if tier == 1:
			for k in 3:
				var p := Vector3(rng.randf_range(-.25, .25), 0, foot + .45 + k * .62)
				sites.append(house.transform * Transform3D(Basis(Vector3.UP, rng.randf_range(-.5, .5)).scaled(Vector3(rng.randf_range(.9, 1.2), 1, rng.randf_range(.8, 1.1))), p))
		elif tier == 3:
			var x := -2.3
			while x < 2.3:
				var length := rng.randf_range(.45, .7)
				var p := Vector3(x + length * .5, 0, foot + 1.72)
				sites.append(house.transform * Transform3D(Basis(Vector3.UP, rng.randf_range(-.04, .04)).scaled(Vector3(length / .5, 1, .55)), p))
				x += length + .02
	var ring_centre := Vector2(-7.6, 3.4)
	for i in 64:
		if rng.randf() < .3:
			continue
		var a := TAU * i / 64.0
		var r := Vector2(cos(a) * 6.2, sin(a) * 5.0) * (1.0 + .04 * sin(a * 3.0))
		var p := Vector3(ring_centre.x + r.x, 0, ring_centre.y + r.y)
		if Layout.road(Vector2(p.x, p.z)) or Layout.reserved(Vector2(p.x, p.z), .2):
			continue
		sites.append(Transform3D(Basis(Vector3.UP, -a + rng.randf_range(-.2, .2)).scaled(Vector3(rng.randf_range(.7, 1.1), 1, rng.randf_range(.6, .9))), p))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _stone_mesh()
	multimesh.instance_count = sites.size()
	for i in sites.size():
		multimesh.set_instance_transform(i, sites[i])
	_stones = MultiMeshInstance3D.new()
	_stones.name = "SetStones"
	_stones.multimesh = multimesh
	_stones.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_stones)


## A worn, slightly domed limestone slab 0.5 x 0.4 m, 15 mm proud of the ground.
func _stone_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring := []
	const N := 14
	for k in N:
		var a := TAU * k / N
		var r := Vector2(cos(a) * .25, sin(a) * .20) * (1.0 + .08 * sin(a * 3.0 + 1.3))
		ring.append(r)
	var top := .013
	var tri := []
	for k in N:
		var p0: Vector2 = ring[k]
		var p1: Vector2 = ring[(k + 1) % N]
		var inner0 := p0 * .78
		var inner1 := p1 * .78
		for v in [[Vector3(0, top + .004, 0), 1.0], [Vector3(inner1.x, top, inner1.y), 1.0], [Vector3(inner0.x, top, inner0.y), 1.0],
				[Vector3(inner0.x, top, inner0.y), .4], [Vector3(inner1.x, top, inner1.y), .4], [Vector3(p1.x, top - .006, p1.y), .4],
				[Vector3(inner0.x, top, inner0.y), .4], [Vector3(p1.x, top - .006, p1.y), .4], [Vector3(p0.x, top - .006, p0.y), .4],
				[Vector3(p0.x, top - .006, p0.y), .7], [Vector3(p1.x, top - .006, p1.y), .7], [Vector3(p1.x * 1.04, -.03, p1.y * 1.04), .7],
				[Vector3(p0.x, top - .006, p0.y), .7], [Vector3(p1.x * 1.04, -.03, p1.y * 1.04), .7], [Vector3(p0.x * 1.04, -.03, p0.y * 1.04), .7]]:
			tri.append(v)
	# The list above runs counter-clockwise from above; Godot front faces are clockwise.
	for t in range(0, tri.size(), 3):
		for k in [0, 2, 1]:
			var pos: Vector3 = tri[t + k][0]
			st.set_uv(Vector2(pos.x, pos.z) / 1.2)
			st.set_uv2(Vector2(14.0, fposmod(pos.x * 3.1, 1.0)))
			st.set_color(Color(.3, .25, 0.0, tri[t + k][1]))
			st.add_vertex(pos)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()
