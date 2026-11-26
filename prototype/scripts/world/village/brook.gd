extends RefCounted
## The village ground with the sunk brook bed, the matching collision and the
## water surface. All three are built from valdora_land.gd on one grid, so
## what is drawn, what carries a walker and where the water stands agree.
## Metres, +Y up, -Z north.

const Land = preload("res://scripts/world/village/valdora_land.gd")
const Plan = preload("res://scripts/world/world_stream_plan.gd")
## Regional terrain cell (250 m sector / 12). The bed lies below the terrain
## surface, so the terrain leaves these whole cells open (regional_terrain.gd)
## and this ground fills them: the brook's column under the village ground
## and, south of it, the apron around the fen channel.
const CELL_M := 250.0 / 12.0
const TERRAIN_OPENINGS: Array[Rect2] = [
	Rect2(-2.0 * CELL_M, -4.0 * CELL_M, CELL_M, 7.0 * CELL_M),
	Rect2(-2.0 * CELL_M, 3.0 * CELL_M, 2.0 * CELL_M, 3.0 * CELL_M)]
const APRON := Rect2(-2.0 * CELL_M, 3.0 * CELL_M, 2.0 * CELL_M, 3.0 * CELL_M)
## Level village ground (x, z); the brook strip replaces it between the two x.
const PLANE := Rect2(-90.0, -100.0, 180.0, 170.0)
const STRIP_WEST_X := -35.0
const STRIP_EAST_X := -21.0
## Drawn ground lies just above its collision so feet never sink into it.
const GROUND_Y := -0.008
const COLLISION_Y := -0.01
## Distances from the waterline (negative: over water) of the grid columns
## on each side of the centre line.
const COLUMN_OFFSETS: Array[float] = [-2.6, -1.7, -1.15, -.7, -.3, 0.0, .3, .6, .9, 1.6]
## Bridge deck (game_world.gd): planks from x -32.8 to -23.2, z 2.45 to 5.55,
## top at 0.08. A walker crosses on the deck, not through the bed below it.
const DECK := Rect2(-32.8, 2.45, 9.6, 3.1)
const DECK_TOP_Y := 0.08
const DECK_RAMP_M := 0.7
## Water mesh columns as fractions of the half width.
const WATER_COLUMNS: Array[float] = [-1.0, -.93, -.78, -.45, 0.0, .45, .78, .93, 1.0]


## True where the terrain must leave its cell open (p = the cell's centre).
static func replaces_terrain(p: Vector2) -> bool:
	for opening in TERRAIN_OPENINGS:
		if opening.has_point(p):
			return true
	return false


## Rows from the plane's north edge to the end of the fen channel: coarse
## along the brook, fine at spring, fen end and bridge edges.
static func rows(source_z: float) -> PackedFloat32Array:
	var list: Array[float] = [PLANE.position.y, source_z - 1.0, PLANE.end.y, PLANE.end.y + .01,
		DECK.position.y - .15, DECK.position.y, DECK.end.y, DECK.end.y + .15, Land.FEN_END_Z + 1.0, Land.FEN_END_Z + 4.0, APRON.end.y]
	var z := source_z
	while z < Land.FEN_END_Z:
		list.append(z)
		var fine := z < source_z + Land.END_ROUNDING_M + .5 or z > Land.FEN_END_Z - Land.END_ROUNDING_M - 1.0
		z += .5 if fine else 1.5
	list.append(Land.FEN_END_Z)
	list.sort()
	var result := PackedFloat32Array()
	for value in list:
		if result.is_empty() or value - result[-1] > .004:
			result.append(value)
	return result


## x of every column in row z, west to east.
static func columns(z: float, source_z: float) -> PackedFloat32Array:
	var centre := Land.channel_x(z)
	var half := Land.water_half_width(z, source_z)
	var on_plane := z <= PLANE.end.y
	var result := PackedFloat32Array()
	var count := COLUMN_OFFSETS.size()
	result.append(STRIP_WEST_X if on_plane else APRON.position.x)
	for i in range(count - 1, -1, -1):
		result.append(centre - maxf(half + COLUMN_OFFSETS[i], (i + 1) * .03))
	result.append(centre)
	for i in count:
		result.append(centre + maxf(half + COLUMN_OFFSETS[i], (i + 1) * .03))
	result.append(STRIP_EAST_X if on_plane else APRON.end.x)
	return result


## Drawn ground height at a strip vertex.
static func ground_height(p: Vector2, source_z: float, rim: bool) -> float:
	# South of the plane the apron's rim lies exactly on the regional terrain.
	if p.y > PLANE.end.y and (rim or p.y >= APRON.end.y - .001):
		return Plan.terrain_height(p) - .06
	return GROUND_Y + Land.bed_offset(p, source_z)


## Walkable height: the bed, or the bridge deck with a short ramp at each end.
static func walk_height(p: Vector2, source_z: float, rim: bool) -> float:
	var ground := ground_height(p, source_z, rim)
	if not (p.y > PLANE.end.y and (rim or p.y >= APRON.end.y - .001)):
		ground += COLLISION_Y - GROUND_Y
	if p.y < DECK.position.y - .001 or p.y > DECK.end.y + .001:
		return ground
	var beyond := maxf(DECK.position.x - p.x, p.x - DECK.end.x)
	return maxf(ground, lerpf(DECK_TOP_Y, COLLISION_Y, clampf(beyond / DECK_RAMP_M, 0.0, 1.0)))


static func _strip(source_z: float, walkable: bool) -> PackedVector3Array:
	var z_rows := rows(source_z)
	var grid: Array[PackedVector3Array] = []
	for z in z_rows:
		var xs := columns(z, source_z)
		var line := PackedVector3Array()
		for i in xs.size():
			var p := Vector2(xs[i], z)
			var rim := i == 0 or i == xs.size() - 1
			line.append(Vector3(p.x, walk_height(p, source_z, rim) if walkable else ground_height(p, source_z, rim), z))
		grid.append(line)
	var triangles := PackedVector3Array()
	for row in grid.size() - 1:
		for column in grid[row].size() - 1:
			var a := grid[row][column]
			var b := grid[row][column + 1]
			var c := grid[row + 1][column]
			var d := grid[row + 1][column + 1]
			triangles.append_array([a, b, c, b, d, c])
	return triangles


## Level ground west and east of the strip plus the strip with the bed.
static func ground_mesh(source_z: float) -> ArrayMesh:
	var triangles := _strip(source_z, false)
	for span: Vector2 in [Vector2(PLANE.position.x, STRIP_WEST_X), Vector2(STRIP_EAST_X, PLANE.end.x)]:
		var a := Vector3(span.x, GROUND_Y, PLANE.position.y)
		var b := Vector3(span.y, GROUND_Y, PLANE.position.y)
		var c := Vector3(span.x, GROUND_Y, PLANE.end.y)
		var d := Vector3(span.y, GROUND_Y, PLANE.end.y)
		triangles.append_array([a, b, c, b, d, c])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in triangles:
		surface.set_uv(Vector2(vertex.x, vertex.z))
		surface.add_vertex(vertex)
	surface.index()
	surface.generate_normals()
	surface.generate_tangents()
	return surface.commit()


static func collision_shape(source_z: float) -> ConcavePolygonShape3D:
	var faces := PackedVector3Array()
	var triangles := _strip(source_z, true)
	# Columns that coincide where the water has no width give empty triangles.
	for i in range(0, triangles.size(), 3):
		if (triangles[i + 1] - triangles[i]).cross(triangles[i + 2] - triangles[i]).length_squared() > 1e-10:
			faces.append_array([triangles[i], triangles[i + 1], triangles[i + 2]])
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	return shape


## Water surface between the waterlines. UV.x = -1 west bank .. 1 east bank,
## UV.y = metres along the brook, COLOR.r = depth as a share of the deepest bed.
static func water_mesh(source_z: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lines: Array = []
	for z in rows(source_z):
		if z < source_z - .001 or z > Land.FEN_END_Z + .001:
			continue
		var centre := Land.channel_x(z)
		# The sheet reaches slightly into the bank so no gap shows at the waterline.
		var half := Land.water_half_width(z, source_z) + .04
		var line := []
		for fraction in WATER_COLUMNS:
			var p := Vector2(centre + fraction * half, z)
			line.append([Vector3(p.x, Land.WATER_SURFACE_Y, z), fraction,
				clampf(Land.water_depth(p, source_z) / (Land.BED_DEPTH_M + Land.WATER_SURFACE_Y), 0.0, 1.0)])
		lines.append(line)
	for row in lines.size() - 1:
		for column in WATER_COLUMNS.size() - 1:
			for corner: Array in [lines[row][column], lines[row][column + 1], lines[row + 1][column],
					lines[row][column + 1], lines[row + 1][column + 1], lines[row + 1][column]]:
				surface.set_normal(Vector3.UP)
				surface.set_tangent(Plane(1, 0, 0, 1))
				surface.set_uv(Vector2(corner[1], corner[0].z))
				surface.set_color(Color(corner[2], 0, 0, 1))
				surface.add_vertex(corner[0])
	surface.index()
	return surface.commit()
