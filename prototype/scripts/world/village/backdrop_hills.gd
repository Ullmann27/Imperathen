extends RefCounted
## North backdrop hills: a closed landform standing on the streamed regional
## ground. Height = regional ground mesh + non-negative relief, so the terrain
## never shows through, the back and the ends run out onto the terrain and the
## collision is the visible surface itself. Metres, +Y up, -Z north.
##
## The grid subdivides each 250/12 m terrain cell into SUBDIVISION x SUBDIVISION
## cells with the terrain's own diagonal. Every hill triangle therefore lies
## inside one terrain triangle and interpolating the terrain at hill vertices
## reproduces the terrain surface exactly; relief >= 0 keeps the hill on or above it.

const Terrain = preload("res://scripts/world/regional_terrain.gd")
const SUBDIVISION := 6
## Vertex index ranges (inclusive). x: -208.3..208.3 m, z: -152.8..-66.0 m.
const COLUMN_FIRST := -60
const COLUMN_LAST := 60
const ROW_FIRST := -44
const ROW_LAST := -19
## The relief is zero south of the foot line. The raider ground at z = -62/-64
## and the open approach to the north gate (z = -49) remain level meadow.
const FOOT_Z := -66.8
const FOOT_VARIATION_M := 2.6
const RISE_M := 32.0
const BACK_Z := -150.0
const FALL_M := 40.0
const END_X := 205.0
const TAPER_M := 45.0
## Scrub and stone albedo (sRGB). These equal #687451/#a1957b taken through one
## sRGB-to-linear step: exactly the albedo the former backdrop rendered with.
const SCRUB := Color("232d15")
const STONE := Color("5b4d33")
const COLOR_BLEND_M := 2.5


static func step_m() -> float:
	return Terrain.Plan.SECTOR_SIZE_M / Terrain.GRID / SUBDIVISION


static func foot_z(x: float) -> float:
	return FOOT_Z - FOOT_VARIATION_M * (0.5 + 0.5 * sin(x * 0.043 + 1.1))


## Height above the regional ground (>= 0). The crest keeps the former
## irregular ridge profile (same harmonics) between about z = -100 and -110.
static func relief(p: Vector2) -> float:
	var front := smoothstep(0.0, 1.0, (foot_z(p.x) - p.y) / RISE_M)
	var back := smoothstep(0.0, 1.0, (p.y - BACK_Z) / FALL_M)
	var ends := smoothstep(0.0, 1.0, (END_X - absf(p.x)) / TAPER_M)
	var crest := 11.0 + 4.2 * sin(p.x * .069) + 2.5 * sin(p.x * .16 + p.y * .079) \
		+ 1.45 * cos(p.x * .22 - p.y * .14) + 1.05 * sin(p.x * .473 + p.y * .24)
	return maxf(0.0, crest * front * back * ends)


static func vertex_position(column: int, row: int) -> Vector3:
	var p := Vector2(column * step_m(), row * step_m())
	return Vector3(p.x, Terrain.surface_height(p) + relief(p), p.y)


static func vertex_color(position: Vector3, height_above_ground: float) -> Color:
	var stone := smoothstep(9.0, 20.0, height_above_ground + 3.0 * sin(position.x * .14))
	# .28 on the converted palette equals the former .13 darkening before conversion.
	var hill := SCRUB.lerp(STONE, stone).darkened(.28 * absf(sin(position.x * .3 + position.z * .52)))
	return Terrain.ground_color(position).lerp(hill, smoothstep(0.0, COLOR_BLEND_M, height_above_ground))


static func covers(p: Vector2) -> bool:
	return p.x >= COLUMN_FIRST * step_m() and p.x <= COLUMN_LAST * step_m() \
		and p.y >= ROW_FIRST * step_m() and p.y <= ROW_LAST * step_m()


## Height of the built hill mesh at a global point (same triangulation), or
## -INF outside its footprint.
static func surface_height(p: Vector2) -> float:
	if not covers(p):
		return -INF
	var step := step_m()
	var column := clampi(floori(p.x / step), COLUMN_FIRST, COLUMN_LAST - 1)
	var row := clampi(floori(p.y / step), ROW_FIRST, ROW_LAST - 1)
	var fx := p.x / step - column
	var fz := p.y / step - row
	var a := vertex_position(column, row).y
	var b := vertex_position(column + 1, row).y
	var c := vertex_position(column, row + 1).y
	var d := vertex_position(column + 1, row + 1).y
	return a + (b - a) * fx + (c - a) * fz if fx + fz <= 1.0 else d + (c - d) * (1.0 - fx) + (b - d) * (1.0 - fz)


## One indexed surface. Cells whose three corners all have zero relief would
## coincide with the regional ground and are left out; the remaining boundary
## edges therefore lie exactly on the terrain (no floating rim).
static func build_mesh() -> ArrayMesh:
	var columns := COLUMN_LAST - COLUMN_FIRST + 1
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lifted := PackedByteArray()
	for row in range(ROW_FIRST, ROW_LAST + 1):
		for column in range(COLUMN_FIRST, COLUMN_LAST + 1):
			var p := Vector2(column * step_m(), row * step_m())
			var above := relief(p)
			var position := Vector3(p.x, Terrain.surface_height(p) + above, p.y)
			lifted.append(1 if above > 0.0 else 0)
			surface.set_color(vertex_color(position, above))
			surface.add_vertex(position)
	for row in ROW_LAST - ROW_FIRST:
		for column in columns - 1:
			var a := row * columns + column
			var b := a + 1
			var c := a + columns
			var d := c + 1
			# Same vertex order and diagonal as RegionalTerrain._make_sector.
			for triangle: Array in [[a, b, c], [b, d, c]]:
				if lifted[triangle[0]] or lifted[triangle[1]] or lifted[triangle[2]]:
					for index: int in triangle:
						surface.add_index(index)
	surface.generate_normals()
	return surface.commit()


## Material shared by the visual mesh: sRGB vertex albedo, like the terrain.
static func material() -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.vertex_color_is_srgb = true
	paint.roughness = .96
	paint.cull_mode = BaseMaterial3D.CULL_BACK
	return paint
