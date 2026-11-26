extends RefCounted
## Ground height for planting, matching what is actually drawn: the flat
## village plane, the streamed regional terrain (same triangulation as
## regional_terrain.gd) and any backdrop landform mesh handed in (the
## "Foothills" of village_scenery.gd, whichever version is built). Plants sit
## on the visible surface whether or not that surface has collision.

const Plan = preload("res://scripts/world/world_stream_plan.gd")
const PLANE := Rect2(-90.0, -100.0, 180.0, 170.0)
const BUCKET := 4.0
const GRID := 12

var _triangles: Dictionary = {}


func add_mesh(node: MeshInstance3D) -> void:
	if node == null or node.mesh == null:
		return
	var transform := node.global_transform if node.is_inside_tree() else node.transform
	for surface in node.mesh.get_surface_count():
		var arrays := node.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0, count - 2, 3):
			var a := transform * vertices[indices[i] if not indices.is_empty() else i]
			var b := transform * vertices[indices[i + 1] if not indices.is_empty() else i + 1]
			var c := transform * vertices[indices[i + 2] if not indices.is_empty() else i + 2]
			var low := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)))
			var high := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))
			for bx in range(floori(low.x / BUCKET), floori(high.x / BUCKET) + 1):
				for bz in range(floori(low.y / BUCKET), floori(high.y / BUCKET) + 1):
					var key := Vector2i(bx, bz)
					if not _triangles.has(key):
						_triangles[key] = PackedVector3Array()
					var list: PackedVector3Array = _triangles[key]
					list.append_array([a, b, c])
					_triangles[key] = list


func height(p: Vector2) -> float:
	var h := 0.0
	if not PLANE.has_point(p) or p.length() > 120.0:
		h = regional(p)
		if PLANE.has_point(p):
			h = maxf(h, 0.0)
	var list: PackedVector3Array = _triangles.get(Vector2i(floori(p.x / BUCKET), floori(p.y / BUCKET)), PackedVector3Array())
	for i in range(0, list.size(), 3):
		var y := _on_triangle(p, list[i], list[i + 1], list[i + 2])
		if y > h:
			h = y
	return h


## Height of the regional terrain mesh (sector grid of 250/12 m, -6 cm).
static func regional(p: Vector2) -> float:
	var step := Plan.SECTOR_SIZE_M / GRID
	var column := floori(p.x / step)
	var row := floori(p.y / step)
	var fx := p.x / step - column
	var fz := p.y / step - row
	var a := Plan.terrain_height(Vector2(column, row) * step)
	var b := Plan.terrain_height(Vector2(column + 1, row) * step)
	var c := Plan.terrain_height(Vector2(column, row + 1) * step)
	var d := Plan.terrain_height(Vector2(column + 1, row + 1) * step)
	var h := a + (b - a) * fx + (c - a) * fz if fx + fz <= 1.0 else d + (c - d) * (1.0 - fx) + (b - d) * (1.0 - fz)
	return h - .06


static func _on_triangle(p: Vector2, a: Vector3, b: Vector3, c: Vector3) -> float:
	var v0 := Vector2(b.x - a.x, b.z - a.z)
	var v1 := Vector2(c.x - a.x, c.z - a.z)
	var v2 := Vector2(p.x - a.x, p.y - a.z)
	var den := v0.x * v1.y - v1.x * v0.y
	if absf(den) < 1e-9:
		return -INF
	var v := (v2.x * v1.y - v1.x * v2.y) / den
	var w := (v0.x * v2.y - v2.x * v0.y) / den
	var u := 1.0 - v - w
	if u < -1e-4 or v < -1e-4 or w < -1e-4:
		return -INF
	return a.y * u + b.y * v + c.y * w
