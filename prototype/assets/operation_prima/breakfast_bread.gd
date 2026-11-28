extends RefCounted
## Godot-native breakfast bread on an oval serving board.

const PLATTER_SEGMENTS: int = 24
const LOAF_SEGMENTS: int = 24
const LOAF_AROUND: int = 18
const SCORE_SEGMENTS: int = 14
const PLATTER_CENTER := Vector3(0.02655, 0.0, 0.0234)
const PLATTER_RADIUS := Vector2(0.23605, 0.2466)
const PLATTER_TOP_Y: float = 0.012
const LOAF_HALF_LENGTH: float = 0.166
const LOAF_HALF_DEPTH: float = 0.076
const LOAF_CENTER_Y: float = 0.014
const LOAF_HEIGHT: float = 0.060
const LOAF_BOTTOM: float = 0.006
const SCORE_WIDTH: float = 0.004


static func build_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	_append_platter(mesh)
	_append_loaf(mesh)
	_append_scores(mesh)
	return mesh


static func _append_platter(mesh: ArrayMesh) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(_surface_material("oak"))
	var center_top := Vector3(PLATTER_CENTER.x, PLATTER_TOP_Y, PLATTER_CENTER.z)
	var center_bottom := Vector3(PLATTER_CENTER.x, 0.0, PLATTER_CENTER.z)
	for segment in PLATTER_SEGMENTS:
		var angle0 := TAU * float(segment) / float(PLATTER_SEGMENTS)
		var angle1 := TAU * float(segment + 1) / float(PLATTER_SEGMENTS)
		var inner0 := _platter_point(angle0, 0.88, PLATTER_TOP_Y)
		var inner1 := _platter_point(angle1, 0.88, PLATTER_TOP_Y)
		var peak0 := _platter_point(angle0, 0.96, 0.018)
		var peak1 := _platter_point(angle1, 0.96, 0.018)
		var edge0 := _platter_point(angle0, 1.0, 0.014)
		var edge1 := _platter_point(angle1, 1.0, 0.014)
		var bottom0 := _platter_point(angle0, 1.0, 0.0)
		var bottom1 := _platter_point(angle1, 1.0, 0.0)
		_triangle(tool, center_top, inner1, inner0)
		_triangle(tool, inner0, inner1, peak1)
		_triangle(tool, inner0, peak1, peak0)
		_triangle(tool, peak0, peak1, edge1)
		_triangle(tool, peak0, edge1, edge0)
		_triangle(tool, edge0, edge1, bottom0)
		_triangle(tool, edge1, bottom1, bottom0)
		_triangle(tool, center_bottom, bottom0, bottom1)
	tool.index()
	tool.generate_normals()
	tool.commit(mesh)


static func _append_loaf(mesh: ArrayMesh) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(_surface_material("food"))
	var stride := LOAF_AROUND + 1
	for ring in range(LOAF_SEGMENTS + 1):
		var longitudinal := lerpf(-1.0, 1.0, float(ring) / float(LOAF_SEGMENTS))
		for side in range(LOAF_AROUND + 1):
			var angle := TAU * float(side) / float(LOAF_AROUND)
			var point := _loaf_point(longitudinal, angle)
			tool.set_uv(Vector2(float(ring) / float(LOAF_SEGMENTS), float(side) / float(LOAF_AROUND)))
			tool.add_vertex(point)
	for ring in LOAF_SEGMENTS:
		for side in LOAF_AROUND:
			var a := ring * stride + side
			var b := (ring + 1) * stride + side
			var c := ring * stride + side + 1
			var d := (ring + 1) * stride + side + 1
			tool.add_index(a)
			tool.add_index(b)
			tool.add_index(c)
			tool.add_index(c)
			tool.add_index(b)
			tool.add_index(d)
	tool.generate_normals()
	tool.commit(mesh)


static func _append_scores(mesh: ArrayMesh) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(_surface_material("bread_cut"))
	for score in 3:
		var lane := float(score - 1) * LOAF_HALF_LENGTH * 0.34
		for segment in SCORE_SEGMENTS:
			var across0 := lerpf(-0.64, 0.64, float(segment) / float(SCORE_SEGMENTS))
			var across1 := lerpf(-0.64, 0.64, float(segment + 1) / float(SCORE_SEGMENTS))
			var left0 := _score_point(lane, across0, -SCORE_WIDTH * 0.5)
			var right0 := _score_point(lane, across0, SCORE_WIDTH * 0.5)
			var left1 := _score_point(lane, across1, -SCORE_WIDTH * 0.5)
			var right1 := _score_point(lane, across1, SCORE_WIDTH * 0.5)
			_triangle(tool, left0, left1, right0)
			_triangle(tool, right0, left1, right1)
	tool.index()
	tool.generate_normals()
	tool.commit(mesh)


static func _loaf_point(longitudinal: float, angle: float) -> Vector3:
	var section := sqrt(maxf(0.0, 1.0 - longitudinal * longitudinal))
	var irregularity := 1.0 + 0.015 * sin(longitudinal * 11.0 + angle * 5.0) \
		+ 0.01 * cos(longitudinal * 7.0 - angle * 3.0)
	var vertical := sin(angle)
	var y := LOAF_CENTER_Y + vertical * (LOAF_HEIGHT if vertical >= 0.0 else LOAF_BOTTOM) * section * irregularity
	var x := PLATTER_CENTER.x + longitudinal * LOAF_HALF_LENGTH
	var z := PLATTER_CENTER.z + cos(angle) * LOAF_HALF_DEPTH * section * irregularity
	if vertical > 0.35 and absf(z - PLATTER_CENTER.z) <= LOAF_HALF_DEPTH * section * 0.70:
		for score in 3:
			var lane := float(score - 1) * LOAF_HALF_LENGTH * 0.34
			var score_x := PLATTER_CENTER.x + lane + (z - PLATTER_CENTER.z) * 0.18
			var cut := clampf(1.0 - absf(x - score_x) / 0.008, 0.0, 1.0)
			y -= cut * 0.003
	return Vector3(x, y, z)


static func _score_point(lane: float, across: float, side: float) -> Vector3:
	var z_offset := across * LOAF_HALF_DEPTH
	var x := PLATTER_CENTER.x + lane + z_offset * 0.18 + side
	var longitudinal := clampf((x - PLATTER_CENTER.x) / LOAF_HALF_LENGTH, -0.98, 0.98)
	var section := sqrt(maxf(0.0, 1.0 - longitudinal * longitudinal))
	var normalized_depth := clampf(z_offset / maxf(0.001, LOAF_HALF_DEPTH * section), -0.98, 0.98)
	var angle := acos(normalized_depth)
	var irregularity := 1.0 + 0.015 * sin(longitudinal * 11.0 + angle * 5.0) \
		+ 0.01 * cos(longitudinal * 7.0 - angle * 3.0)
	var top := LOAF_CENTER_Y + LOAF_HEIGHT * section * sqrt(maxf(0.0, 1.0 - normalized_depth * normalized_depth)) * irregularity
	return Vector3(x, top - 0.0008, PLATTER_CENTER.z + z_offset)


static func _platter_point(angle: float, radius: float, y: float) -> Vector3:
	return Vector3(
		PLATTER_CENTER.x + cos(angle) * PLATTER_RADIUS.x * radius,
		y,
		PLATTER_CENTER.z + sin(angle) * PLATTER_RADIUS.y * radius,
	)


static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	tool.set_uv(_uv(a))
	tool.add_vertex(a)
	tool.set_uv(_uv(b))
	tool.add_vertex(b)
	tool.set_uv(_uv(c))
	tool.add_vertex(c)


static func _uv(point: Vector3) -> Vector2:
	return Vector2(point.x * 4.0, point.z * 4.0)


static func _surface_material(slot: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "INT_" + slot
	material.roughness = 0.94
	match slot:
		"oak":
			material.albedo_color = Color(0.70, 0.49, 0.29)
		"bread_cut":
			material.albedo_color = Color(0.60, 0.37, 0.22)
		_:
			material.albedo_color = Color(0.86, 0.63, 0.37)
	return material
