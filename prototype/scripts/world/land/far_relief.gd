extends Node3D
## Land beyond the streamed terrain, out to a mountain horizon, in two draw
## calls. "Near" is four nested grids of the regional height field (250 m
## cells around the walker up to 2 km cells over the whole 32 km region); it
## lies a little below the streamed sectors, which cover it where they are
## loaded. "Massif" is a fixed mountain range north of the region's edge.
## Neither has collision: nothing here can be reached on foot.
## The range is original backdrop geography, not surveyed terrain.

const Plan = preload("res://scripts/world/world_stream_plan.gd")
const LandSurface = preload("res://scripts/world/land/land_surface.gd")
## The world camera must reach the far corners of the massif.
const CAMERA_FAR_M := 70000.0
const LEVELS := 4
const CELLS := 16
## Each coarser grid lies lower than the finer one above it by more than both
## can miss the height field (measured over the region: a 250 m cell up to
## 3.7 m, 500 m 12.5 m, 1 km 14.7 m, 2 km 34 m), so no coarse ground shows through.
const LEVEL_DROP_M: Array[float] = [4.5, 22.0, 50.0, 95.0]
const MASSIF_REACH_M := 48000.0
## Southern end of the west and east flanks of the range.
const FLANK_SOUTH_Z := 2000.0
## Massif cell size per quality profile (metres).
const MASSIF_STEP_M := {"low":1600.0, "balanced":1200.0, "high":800.0, "very_high":600.0}

var material: ShaderMaterial
var triangles := 0
var _near: MeshInstance3D
var _massif: MeshInstance3D
var _anchor := Vector2i(2147483647, 0)
var _profile := ""
static var _ridges: FastNoiseLite
static var _detail: FastNoiseLite


func _init() -> void:
	material = LandSurface.make_far()
	_near = _layer("Near")
	_massif = _layer("Massif")


func _layer(label: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


## Height of the range above the regional ground: 0 inside the 32 km region
## and to its south, foothills from the northern, western and eastern edge.
static func massif_height(p: Vector2) -> float:
	var beyond := maxf(absf(p.x), absf(p.y)) - Plan.WORLD_HALF_M
	if beyond <= 0.0:
		return 0.0
	var northness := smoothstep(-.30, .40, -p.y / p.length())
	if northness <= 0.0:
		return 0.0
	if _ridges == null:
		_ridges = FastNoiseLite.new()
		_ridges.seed = 5801
		_ridges.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		_ridges.fractal_octaves = 3
		_ridges.fractal_gain = .45
		_ridges.frequency = 1.0 / 15000.0
		_detail = FastNoiseLite.new()
		_detail.seed = 5802
		_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_detail.fractal_octaves = 3
		_detail.frequency = 1.0 / 3200.0
	var ridge := clampf(_ridges.get_noise_2d(p.x, p.y) * .5 + .5, 0.0, 1.0)
	var foothills := smoothstep(0.0, 9000.0, beyond)
	var high := smoothstep(9000.0, 26000.0, beyond)
	var height := foothills * (260.0 + 1650.0 * ridge * ridge) + high * (420.0 + 780.0 * ridge)
	height += foothills * 150.0 * _detail.get_noise_2d(p.x, p.y) * (.4 + ridge)
	return maxf(0.0, height) * northness


static func height(p: Vector2) -> float:
	return Plan.terrain_height(p) + massif_height(p)


## Call with the walker's position; rebuilds the near grids only when the
## position crosses a 500 m lattice line.
func follow(position: Vector3, quality: String) -> void:
	var profile := quality if MASSIF_STEP_M.has(quality) else "balanced"
	if profile != _profile:
		_profile = profile
		_massif.mesh = _build_massif(float(MASSIF_STEP_M[profile]))
	if not position.is_finite():
		return
	var anchor := Vector2i(roundi(position.x / 500.0), roundi(position.z / 500.0))
	if anchor != _anchor:
		_anchor = anchor
		_near.mesh = _build_near(Vector2(anchor) * 500.0)
	triangles = _count(_near.mesh) + _count(_massif.mesh)


func _count(mesh: Mesh) -> int:
	return 0 if mesh == null else mesh.surface_get_array_index_len(0) / 3


## Footprint of grid level around a centre: CELLS x CELLS cells on the
## level's own world lattice; the coarsest level is the whole region.
static func level_rect(level: int, centre: Vector2) -> Rect2:
	var cell := Plan.SECTOR_SIZE_M * (1 << level)
	if level == LEVELS - 1:
		return Rect2(-Plan.WORLD_HALF_M, -Plan.WORLD_HALF_M, Plan.WORLD_SIZE_M, Plan.WORLD_SIZE_M)
	var snapped_centre := (centre / (cell * 2.0)).round() * cell * 2.0
	var half := cell * CELLS * .5
	var rect := Rect2(snapped_centre - Vector2(half, half), Vector2(half, half) * 2.0)
	return rect.intersection(Rect2(-Plan.WORLD_HALF_M, -Plan.WORLD_HALF_M, Plan.WORLD_SIZE_M, Plan.WORLD_SIZE_M))


func _build_near(centre: Vector2) -> ArrayMesh:
	var surface := _Grid.new()
	for level in LEVELS:
		var rect := level_rect(level, centre)
		var cell := Plan.SECTOR_SIZE_M * (1 << level)
		# The finer grid covers the middle; keep one cell of overlap under its rim.
		var hole := Rect2()
		if level > 0:
			hole = level_rect(level - 1, centre).grow(-cell)
		surface.add(rect, cell, -LEVEL_DROP_M[level], hole, func(p: Vector2) -> float: return Plan.terrain_height(p))
	return surface.commit()


func _build_massif(step: float) -> ArrayMesh:
	var surface := _Grid.new()
	var edge := Plan.WORLD_HALF_M
	var reach := MASSIF_REACH_M
	var sample := func(p: Vector2) -> float: return height(p)
	surface.add(Rect2(-reach, -reach, reach * 2.0, reach - edge), step, 0.0, Rect2(), sample)
	surface.add(Rect2(-reach, -edge, reach - edge, edge + FLANK_SOUTH_Z), step, 0.0, Rect2(), sample)
	surface.add(Rect2(edge, -edge, reach - edge, edge + FLANK_SOUTH_Z), step, 0.0, Rect2(), sample)
	return surface.commit()


## Regular grids with normals from the sampled heights, merged in one surface.
class _Grid:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	func add(rect: Rect2, wanted_cell: float, offset: float, hole: Rect2, sample: Callable) -> void:
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			return
		var columns := maxi(1, roundi(rect.size.x / wanted_cell))
		var rows := maxi(1, roundi(rect.size.y / wanted_cell))
		var cell := Vector2(rect.size.x / columns, rect.size.y / rows)
		var side := columns + 3
		var heights := PackedFloat32Array()
		heights.resize(side * (rows + 3))
		for row in rows + 3:
			for column in side:
				heights[row * side + column] = sample.call(rect.position + Vector2(column - 1, row - 1) * cell)
		var first := vertices.size()
		for row in rows + 1:
			for column in columns + 1:
				var at := (row + 1) * side + column + 1
				var p := rect.position + Vector2(column, row) * cell
				vertices.append(Vector3(p.x, heights[at] + offset, p.y))
				normals.append(Vector3((heights[at - 1] - heights[at + 1]) / cell.x, 2.0, (heights[at - side] - heights[at + side]) / cell.y).normalized())
		for row in rows:
			for column in columns:
				var middle := rect.position + (Vector2(column, row) + Vector2(.5, .5)) * cell
				if hole.size.x > 0.0 and hole.has_point(middle):
					continue
				var a := first + row * (columns + 1) + column
				var c := a + columns + 1
				indices.append_array([a, a + 1, c, a + 1, c + 1, c])

	func commit() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
