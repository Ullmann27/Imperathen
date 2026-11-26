extends RefCounted
## One land mask for Valdora: the brook, its fen and the four landscape tracks
## that leave the gates. Ground and terrain shaders (valdora_land.gdshaderinc
## mirrors these formulas), the hill path, the brook bed with its collision and
## the vegetation layer all read this file, so worn earth, clear ground, water
## and walkable surface agree. Metres, x east, z south (-z north).

## Half width of the worn tread; plants keep this distance from a centre line.
const TRACK_HALF_WIDTH := 2.4
## Tracks fade into the open land between these distances from the village.
const TRACK_FADE_START_M := 330.0
const TRACK_REACH_M := 420.0
## Outer palisade gates (north z, south z, east x) and the west bridge end.
const NORTH_GATE_Z := -49.0
const SOUTH_GATE_Z := 30.0
const EAST_GATE_X := 48.0
## The east track begins outside the gate yard (village_layout.gd reserves it).
const EAST_TRACK_START_X := 52.0
const EAST_GATE_Z := -13.0
const WEST_BRIDGE_X := -33.0
const BRIDGE_Z := 4.0

## Open brook water ends here; south of it the channel narrows into the fen.
const OPEN_WATER_END_Z := 65.0
const FEN_END_Z := 112.0
## The water narrows to a rounded end over this length at spring and fen.
const END_ROUNDING_M := 3.5
## Water surface and deepest bed below the village ground (y = 0).
const WATER_SURFACE_Y := -0.16
const BED_DEPTH_M := 0.62
## The bank falls from the ground to the waterline over this width.
const BANK_WIDTH_M := 0.9
## The bed reaches its full depth this far inside the waterline.
const SHELF_WIDTH_M := 1.7


## Centre line of the main village lane (ground.gdshader "lane").
static func lane_x(z: float) -> float:
	return .22 * sin(z * .17) + .13 * sin(z * .35)


static func north_track_x(z: float) -> float:
	return lane_x(z) + 2.2 * sin((z + 53.0) * .035) * smoothstep(53.0, 67.0, -z)


static func south_track_x(z: float) -> float:
	return lane_x(z) + 3.0 * sin((z - 38.0) * .02) * smoothstep(38.0, 60.0, z)


static func east_track_z(x: float) -> float:
	return EAST_GATE_Z + 5.0 * sin((x - EAST_GATE_X) * .015) * smoothstep(EAST_GATE_X, EAST_GATE_X + 22.0, x)


static func west_track_z(x: float) -> float:
	return BRIDGE_Z + .14 * sin(x * .43) + 3.0 * sin((x - WEST_BRIDGE_X) * .03) * smoothstep(-WEST_BRIDGE_X, -WEST_BRIDGE_X + 14.0, -x)


## Lateral distance to the nearest landscape track centre line, INF where no
## track runs. The lanes inside the palisade are village_layout.gd's.
static func track_distance(p: Vector2) -> float:
	var best := INF
	if p.y < NORTH_GATE_Z and p.y > -TRACK_REACH_M:
		best = minf(best, absf(p.x - north_track_x(p.y)))
	if p.y > SOUTH_GATE_Z and p.y < TRACK_REACH_M:
		best = minf(best, absf(p.x - south_track_x(p.y)))
	if p.x > EAST_TRACK_START_X and p.x < TRACK_REACH_M:
		# The tread widens from a point as it leaves the gate yard.
		best = minf(best, absf(p.y - east_track_z(p.x)) + maxf(0.0, EAST_TRACK_START_X + 4.0 - p.x) * .6)
	if p.x < WEST_BRIDGE_X and p.x > -TRACK_REACH_M:
		best = minf(best, absf(p.y - west_track_z(p.x)))
	return best


## True on the tread of a landscape track (plus a margin in metres).
static func in_track(p: Vector2, margin := 0.0) -> bool:
	return track_distance(p) < TRACK_HALF_WIDTH + margin


## 0 untouched ground .. 1 bare trodden earth, as the shaders draw it.
static func track_wear(p: Vector2) -> float:
	var reach := 1.0 - smoothstep(TRACK_FADE_START_M, TRACK_REACH_M, maxf(absf(p.x), absf(p.y)))
	return (1.0 - smoothstep(1.25, TRACK_HALF_WIDTH, track_distance(p))) * reach


static func brook_x(z: float) -> float:
	return -28.0 + .52 * sin(z * .18) + .23 * sin(z * .46)


## Centre line of the water: the brook and, south of z = 65, the channel
## that drifts east into the reed fen.
static func channel_x(z: float) -> float:
	return brook_x(minf(z, OPEN_WATER_END_Z)) + maxf(0.0, z - OPEN_WATER_END_Z) * .35


static func brook_half_width(z: float) -> float:
	return 3.78 + .18 * sin(z * .56)


## Half width of the visible water at row z, 0 north of the spring and south
## of the fen end. source_z is the spring (village_scenery.brook_source_z).
static func water_half_width(z: float, source_z: float) -> float:
	if z <= source_z or z >= FEN_END_Z:
		return 0.0
	var width := brook_half_width(minf(z, OPEN_WATER_END_Z))
	width *= lerpf(1.0, .22, smoothstep(OPEN_WATER_END_Z, FEN_END_Z - END_ROUNDING_M, z))
	var head := clampf((z - source_z) / END_ROUNDING_M, 0.0, 1.0)
	var tail := clampf((FEN_END_Z - z) / END_ROUNDING_M, 0.0, 1.0)
	return width * sqrt(head * (2.0 - head)) * sqrt(tail * (2.0 - tail))


## Lateral distance to the waterline (negative over water); 99 beyond the ends.
static func water_distance(p: Vector2, source_z: float) -> float:
	if p.y < source_z - 2.0 or p.y > FEN_END_Z + 2.0:
		return 99.0
	return absf(p.x - channel_x(p.y)) - water_half_width(p.y, source_z)


## Height of the ground relative to the level village ground (<= 0): the bank
## falls to the waterline and the bed deepens towards the middle. The visual
## ground, its collision and the planting height all use this profile.
static func bed_offset(p: Vector2, source_z: float) -> float:
	var half := water_half_width(p.y, source_z)
	if half <= 0.0:
		return 0.0
	var outside := absf(p.x - channel_x(p.y)) - half
	if outside >= BANK_WIDTH_M:
		return 0.0
	if outside >= 0.0:
		return WATER_SURFACE_Y * smoothstep(0.0, 1.0, 1.0 - outside / BANK_WIDTH_M)
	# Narrow water near the spring and in the fen is shallower.
	var deep := smoothstep(0.0, 1.0, minf(1.0, -outside / SHELF_WIDTH_M)) * clampf(half / 2.0, 0.0, 1.0)
	return WATER_SURFACE_Y - (BED_DEPTH_M + WATER_SURFACE_Y) * deep


## Water depth in metres at p (0 on land).
static func water_depth(p: Vector2, source_z: float) -> float:
	if water_distance(p, source_z) >= 0.0:
		return 0.0
	return maxf(0.0, WATER_SURFACE_Y - bed_offset(p, source_z))
