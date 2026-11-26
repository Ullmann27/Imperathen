extends RefCounted
## Ecological placement of the Valdora vegetation (Aquileia region, 58 BC).
## Deterministic: the same seed and ground always give the same landscape, so
## colliders, saves and renders agree across runs and graphics profiles.
## Metres, +Y up, -Z north. The village plan lives in village_layout.gd; the
## brook follows village_scenery.gd (_bank). Species and habitats follow
## docs/vegetation/ARTENLISTE_VALDORA_58VC.md.
##
## Habitats, from wet to dry:
##   water edge    reed belts, sedge, rush, yellow flag, purple loosestrife
##   riparian      white willow (pollarded near the village), black alder,
##                 black poplar, narrow-leaved ash, elder and hazel
##   wood          oak-hornbeam wood (Q. robur, Carpinus, Fraxinus, Ulmus,
##                 Acer campestre) with hazel/hawthorn understorey, glades
##   wood edge     mantle of blackthorn, hawthorn, hazel; fringe of tall herbs
##   hills         Turkey oak, oak and hornbeam groves, scrub, dry grass,
##                 a terraced vineyard on the south-facing slope
##   fields        parcels of naked wheat, barley, emmer, millet, beans and
##                 fallow with arable weeds at the margins; hedgerows (Varro's
##                 natural hedge) and rows of vines married to pollard maples
##   meadow        hay meadow with flowering patches, grazed pasture by the
##                 village, damp meadow toward the lagoon side
##   village       elders by the houses, kitchen gardens behind them
## Clustering comes from noise fields and Poisson-disc spacing per species;
## nothing is spread evenly. No new collider enters the raid-route survey
## rectangle (x -30..56, z -110..36): the village keeps its existing trees.

const Layout = preload("res://scripts/world/village/village_layout.gd")
const Plan = preload("res://scripts/world/world_stream_plan.gd")
## Shared land mask of the terrain branch (tracks, brook, fen channel, bed).
const Land = preload("res://scripts/world/village/valdora_land.gd")

## Survey area of the static raid-route plan: only collider-free plants here.
const RAID_SURVEY := Rect2(-30.0, -110.0, 86.0, 146.0)
const ENCLOSURE := Rect2(-21.0, -49.0, 69.0, 79.0)
## Bounds of every house footprint and walled yard in village_layout.gd.
const LAYOUT_BOUNDS := Rect2(-47.0, -51.0, 99.0, 83.0)
const VILLAGE_PLANE := Rect2(-90.0, -100.0, 180.0, 170.0)
## The village keeps its own trodden verges (village_scenery.gd): no meadow
## blades and no meadow cards inside this rectangle.
const GRASS_FREE := Rect2(-44.0, -50.0, 90.0, 86.0)
const EXTENT := Rect2(-300.0, -230.0, 520.0, 420.0)
const CHUNK := 16.0
const FIELD_ROTATION := 0.14
## Trunk collider radius at chest height for a scale-1 instance.
const TRUNK := {"quercus_robur": .5, "quercus_cerris": .42, "ulmus_minor": .36, "fraxinus_angustifolia": .34,
	"carpinus_betulus": .3, "populus_nigra": .6, "salix_alba": .45, "salix_alba_pollard": .36,
	"alnus_glutinosa": .3, "acer_campestre": .26, "acer_campestre_arbustum": .22}
## Crown radius of a scale-1 instance (manifest values, rounded up).
const CROWN := {"quercus_robur": 7.3, "quercus_cerris": 5.3, "ulmus_minor": 5.5, "fraxinus_angustifolia": 5.1,
	"carpinus_betulus": 4.7, "populus_nigra": 6.5, "salix_alba": 5.7, "salix_alba_pollard": 2.7,
	"alnus_glutinosa": 3.9, "acer_campestre": 4.3, "acer_campestre_arbustum": 2.0, "corylus_avellana": 2.7,
	"crataegus_monogyna": 2.3, "prunus_spinosa": 1.8, "sambucus_nigra": 2.6, "vitis_arbustum": 2.3, "vitis_stake": 1.3}
const HERB := {"meadow": 0, "pasture": 1, "dry": 2, "sedge": 3, "rush": 4, "reed": 5, "reed_plume": 6,
	"loosestrife": 7, "poppy": 8, "cornflower": 9, "daisy": 10, "sage": 11, "knapweed": 12,
	"buttercup": 13, "carrot": 14, "iris": 15}
const CROP := {"wheat": 0, "barley": 2, "emmer": 3, "millet": 4, "foxtail": 5, "bean": 6, "kale": 7,
	"leek": 8, "lentil": 9, "stubble": 10, "flax": 11}

var seed := 58
var ground_height: Callable
var brook_source_z := -95.0
var trees: Array = []          # {asset, position, yaw, scale, custom, collider}
var cards: Dictionary = {}     # chunk key -> {atlas, center, buffer, count}
var colliders: Array = []      # [Vector3 base, radius]
var counts: Dictionary = {}
var _noise: Dictionary = {}
var _grid: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init(height: Callable = Callable(), source_z: float = -95.0) -> void:
	ground_height = height
	brook_source_z = source_z
	for spec: Array in [["clump", .045, 3], ["patch", .11, 2], ["edge", .022, 3], ["glade", .016, 2], ["wet", .03, 2],
			["fine", .35, 1], ["stand", .011, 3], ["species", .028, 2]]:
		var noise := FastNoiseLite.new()
		noise.seed = seed * 31 + spec[0].hash() % 1000
		noise.frequency = spec[1]
		noise.fractal_octaves = spec[2]
		_noise[spec[0]] = noise


## Planting height: the visible surface, lowered on the level village ground
## by the brook's bank and bed profile (valdora_land.gd).
func height(p: Vector2) -> float:
	var h := float(ground_height.call(p)) if ground_height.is_valid() else 0.0
	return h + Land.bed_offset(p, brook_source_z) if h < .05 else h


func noise(kind: String, p: Vector2) -> float:
	return (_noise[kind] as FastNoiseLite).get_noise_2d(p.x, p.y)


# ---------------------------------------------------------------- terrain

static func brook_x(z: float) -> float:
	return Land.brook_x(z)


static func brook_half_width(z: float) -> float:
	return Land.brook_half_width(z)


## Centre line of the brook and, south of z = 65, of the channel that drifts
## east into the reed fen toward the lagoon.
static func fen_x(z: float) -> float:
	return Land.channel_x(z)


## Northernmost brook row whose water is not buried under the backdrop
## hills (same rule as the scenery's spring on the terrain branch).
func _visible_source() -> float:
	var z := brook_source_z
	while z < 0.0:
		var buried := false
		for side: float in [-1.0, 0.0, 1.0]:
			var x := brook_x(z) + side * brook_half_width(z)
			if height(Vector2(x, z)) > .05:
				buried = true
		if not buried:
			return z
		z += .5
	return z


## Signed distance to the waterline (negative over water): the brook and the
## narrowing fen channel down to its end; 99 beyond the spring and the fen end.
func water_distance(p: Vector2) -> float:
	return Land.water_distance(p, brook_source_z)


## 0 dry .. 1 waterlogged: brook proximity, the southern fen, damp hollows.
func wetness(p: Vector2) -> float:
	var near_water := 1.0 - smoothstep(0.0, 16.0, water_distance(p))
	var fen := smoothstep(48.0, 110.0, p.y) * (1.0 - smoothstep(14.0, 55.0, absf(p.x - fen_x(p.y))))
	var hollow := clampf(noise("wet", p) * 1.4, 0.0, 1.0) * .45
	return clampf(maxf(near_water, fen) + hollow * (1.0 - near_water), 0.0, 1.0)


func slope_deg(p: Vector2) -> float:
	var h := height(p)
	var gx := height(p + Vector2(1.5, 0)) - h
	var gz := height(p + Vector2(0, 1.5)) - h
	return rad_to_deg(atan(Vector2(gx, gz).length() / 1.5))


## Western wood edge: irregular bays and promontories, receding toward the fen.
func wood_edge_x(z: float) -> float:
	return -52.0 + 16.0 * noise("edge", Vector2(3.0, z)) + 6.0 * sin(z * .047 + 1.3) - maxf(0.0, z - 45.0) * .55


func hill_rise(p: Vector2) -> float:
	return height(p) - Plan.terrain_height(p) + .06


## Tread of the four landscape tracks that leave the gates (north, south,
## east, west over the bridge); the hill path north of the gate keeps a
## metre more because it is benched into the slope.
func in_track(p: Vector2, margin := 0.0) -> bool:
	return Land.in_track(p, margin + (1.0 if p.y < Land.NORTH_GATE_Z else 0.0))


func near_house(p: Vector2, margin: float) -> bool:
	if not LAYOUT_BOUNDS.grow(margin + 1.0).has_point(p):
		return false
	return Layout.reserved(p, margin) or Layout.road(p)


func house_clearance(p: Vector2) -> float:
	var best := 999.0
	if not ENCLOSURE.grow(12.0).has_point(p):
		return best
	for home: Dictionary in Layout.HOMES:
		var rect := Layout.house_footprint(home)
		var dx := maxf(maxf(rect.position.x - p.x, 0.0), p.x - rect.end.x)
		var dz := maxf(maxf(rect.position.y - p.y, 0.0), p.y - rect.end.y)
		best = minf(best, Vector2(dx, dz).length())
	return best


## Meadow grass for the blade layer (vegetation_grass.gd) at p:
## x cover 0..1 (share of tufts that grow), y height factor, z dryness.
## Bare on tracks (fading with their wear), in water, crops and the village
## enclosure (the village keeps its own trodden verges); thin and short in
## the shade of the wood, short on the pasture by the village and on balks,
## tall and lush on wet ground, dry and sparse toward the stony crests.
## Height and dryness drift in clumps so the meadow is never even.
func grass_cover(p: Vector2) -> Vector3:
	if GRASS_FREE.has_point(p) or water_distance(p) < .15:
		return Vector3.ZERO
	var wear := Land.track_wear(p)
	if wear > .85:
		return Vector3.ZERO
	var cover := 1.0 - wear
	var clump := noise("clump", p)
	var tall := .62 + .38 * clump + .18 * noise("fine", p)
	var dry := clampf(.28 - .5 * clump, 0.0, 1.0)
	var field := parcel(p)
	if not field.is_empty():
		if float(field.boundary) >= 1.5:
			return Vector3.ZERO
		cover *= .8
		tall *= .6
	elif _vineyard(p):
		cover *= .7
		tall *= .45
	var rise := hill_rise(p)
	var wet := wetness(p)
	var inside := wood_edge_x(p.y) - p.x
	if rise > .5:
		if slope_deg(p) > 38.0:
			return Vector3.ZERO
		cover *= lerpf(.85, .35, smoothstep(12.0, 24.0, rise))
		tall *= .7
		dry = clampf(dry + .35, 0.0, 1.0)
	elif inside > 2.0:
		cover *= lerpf(.7, .22, smoothstep(2.0, 14.0, inside)) * (1.6 if noise("glade", p) > .2 else 1.0)
		tall *= .6
		dry *= .5
	elif wet > .5:
		tall *= 1.3
		dry = 0.0
	elif ENCLOSURE.grow(25.0).has_point(p) and clump < .1:
		tall *= .45
	return Vector3(clampf(cover, 0.0, 1.0), clampf(tall, .18, 1.45), dry)


# ----------------------------------------------------------------- fields

## Field parcels on a slightly rotated grid (a nod to the centuriated ager of
## Aquileia). Returns {} outside the farmland.
func parcel(p: Vector2) -> Dictionary:
	var south := p.y > 40.0 and p.y < 150.0 and p.x > -6.0 and p.x < 150.0
	var east := p.x > 58.0 and p.x < 170.0 and p.y > -40.0 and p.y <= 40.0
	if not (south or east) or in_track(p) or wetness(p) > .62:
		return {}
	var q := p.rotated(-FIELD_ROTATION)
	var size := Vector2(44.0, 66.0)
	var cell := Vector2i(floori(q.x / size.x), floori(q.y / size.y))
	var local := Vector2(fposmod(q.x, size.x), fposmod(q.y, size.y))
	var h := absi(hash(cell)) % 1000 / 1000.0
	var crops := ["wheat", "wheat", "barley", "emmer", "millet", "wheat", "bean", "barley", "foxtail", "lentil", "stubble", "flax"]
	var boundary := minf(minf(local.x, size.x - local.x), minf(local.y, size.y - local.y))
	var crop: String = crops[absi(hash(cell * 7 + Vector2i(3, 1))) % crops.size()]
	# Some parcels are split into two strips (different crop, small balk).
	var split := .3 + .4 * (absi(hash(cell * 13)) % 100 / 100.0)
	if h > .55 and absf(local.x - size.x * split) < 1.2:
		return {}
	if h > .55 and local.x > size.x * split:
		crop = crops[absi(hash(cell * 5 + Vector2i(9, 4))) % crops.size()]
		boundary = minf(boundary, local.x - size.x * split)
	elif h > .55:
		boundary = minf(boundary, size.x * split - local.x)
	return {"cell": cell, "crop": crop, "boundary": boundary,
		"local": local, "size": size, "hedge": h < .42, "arbustum": h >= .42 and h < .7, "hash": h}


# ---------------------------------------------------------------- placing

func build(legacy_sites: Array) -> void:
	_rng.seed = seed
	brook_source_z = _visible_source()
	trees.clear()
	cards.clear()
	colliders.clear()
	counts.clear()
	_grid.clear()
	_legacy(legacy_sites)
	_riparian()
	_wood()
	_hills()
	_farmland()
	_village_plants()
	_meadows()
	for chunk: Dictionary in cards.values():
		_shuffle_chunk(chunk)


func _count(key: String, amount := 1) -> void:
	counts[key] = int(counts.get(key, 0)) + amount


## Poisson-disc spacing per category: rejects points closer than `spacing`
## to any tree already placed (trees of every species share one grid).
func _free(p: Vector2, spacing: float) -> bool:
	var cell := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	var reach := ceili(spacing / 4.0)
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			for other: Vector3 in _grid.get(cell + Vector2i(dx, dz), []):
				if Vector2(other.x, other.y).distance_to(p) < minf(spacing, other.z):
					return false
	return true


func _occupy(p: Vector2, spacing: float) -> void:
	var cell := Vector2i(floori(p.x / 4.0), floori(p.y / 4.0))
	if not _grid.has(cell):
		_grid[cell] = []
	_grid[cell].append(Vector3(p.x, p.y, spacing))


func _tree(asset: String, p: Vector2, scale: float, collide: bool, spacing := 0.0, legacy := false) -> bool:
	# Nothing woody roots in open water (brook or fen channel).
	if not legacy and water_distance(p) < .5:
		return false
	# Crowns never reach into a roof: scale down beside houses, or skip.
	var clearance := house_clearance(p)
	if clearance < 99.0 and not legacy:
		if clearance < 1.2:
			return false
		scale = minf(scale, (clearance + .8) / float(CROWN.get(asset, 4.0)))
		if scale < .4:
			return false
	var y := height(p)
	var yaw := _rng.randf_range(-PI, PI)
	var custom := Color(_rng.randf(), _rng.randf_range(.8, 1.25), _rng.randf(), 0.0)
	var record := {"asset": asset, "position": Vector3(p.x, y, p.y), "yaw": yaw, "scale": scale, "custom": custom,
		"collider": collide and not legacy, "legacy": legacy}
	trees.append(record)
	if spacing > 0.0:
		_occupy(p, spacing)
	if collide and not legacy and TRUNK.has(asset):
		if RAID_SURVEY.has_point(p):
			push_error("Vegetation collider inside the raid survey: %s %s" % [asset, p])
		colliders.append([Vector3(p.x, y, p.y), float(TRUNK[asset]) * scale])
	_count(asset)
	return true


func _card(atlas: String, tile: int, p: Vector2, width: float, tall: float, variation := -1.0, stiffness := 1.0) -> void:
	var y := height(p)
	var key := "%s_%d_%d" % [atlas, floori(p.x / CHUNK), floori(p.y / CHUNK)]
	if not cards.has(key):
		cards[key] = {"atlas": atlas, "center": Vector3((floori(p.x / CHUNK) + .5) * CHUNK, y, (floori(p.y / CHUNK) + .5) * CHUNK),
			"buffer": PackedFloat32Array(), "count": 0, "min_y": y, "max_y": y}
	var chunk: Dictionary = cards[key]
	var basis := Basis(Vector3.UP, _rng.randf_range(-PI, PI)).scaled(Vector3(width, tall, width))
	var buffer: PackedFloat32Array = chunk.buffer
	buffer.append_array([basis.x.x, basis.y.x, basis.z.x, p.x, basis.x.y, basis.y.y, basis.z.y, y - .02,
		basis.x.z, basis.y.z, basis.z.z, p.y,
		tile / 16.0, stiffness, variation if variation >= 0.0 else _rng.randf(), _rng.randf()])
	chunk.buffer = buffer
	chunk.count += 1
	chunk.min_y = minf(chunk.min_y, y)
	chunk.max_y = maxf(chunk.max_y, y)
	_count(atlas)


func _shuffle_chunk(chunk: Dictionary) -> void:
	# Profiles draw the first N instances; a deterministic shuffle keeps every
	# density spatially even instead of thinning one corner.
	var count: int = chunk.count
	var source: PackedFloat32Array = chunk.buffer
	var order := range(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(chunk.center)
	for i in range(count - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: int = order[i]
		order[i] = order[j]
		order[j] = swap
	var shuffled := PackedFloat32Array()
	for i in count:
		var from: int = order[i] * 16
		shuffled.append_array(source.slice(from, from + 16))
	chunk.buffer = shuffled


# --------------------------------------------------------------- habitats

func _legacy(sites: Array) -> void:
	# The village's existing tree positions and colliders stay exactly where
	# they are (raid route plan, camera tests); only species and size change.
	for site: Dictionary in sites:
		var at: Vector3 = site.position
		var p := Vector2(at.x, at.z)
		var pick := absi(hash(p)) % 100
		var asset := "acer_campestre"
		var scale := 1.0
		if ENCLOSURE.has_point(p):
			asset = ["ulmus_minor", "acer_campestre", "carpinus_betulus", "acer_campestre"][pick % 4]
			var radius: float = {"ulmus_minor": 5.4, "acer_campestre": 4.2, "carpinus_betulus": 4.6}[asset]
			scale = clampf((house_clearance(p) + 1.2) / radius, .5, .95)
		elif water_distance(p) < 9.0:
			asset = ["salix_alba", "alnus_glutinosa", "salix_alba_pollard"][pick % 3]
			scale = .8 + pick % 25 / 100.0
		else:
			asset = ["quercus_robur", "carpinus_betulus", "fraxinus_angustifolia", "quercus_robur", "ulmus_minor"][pick % 5]
			scale = .75 + pick % 30 / 100.0
		_tree(asset, p, scale, true, 6.0, true)
		_count("legacy_trees")


func _riparian() -> void:
	# Trees on the west bank (outside the raid survey) and along the fen;
	# reed belts, sedge and flags on both banks.
	for i in 900:
		var z := _rng.randf_range(brook_source_z + 4.0, 150.0)
		var side := -1.0 if _rng.randf() < .62 else 1.0
		var offset := _rng.randf_range(4.0, 16.0)
		var p := Vector2(fen_x(z) + side * (brook_half_width(z) + offset), z)
		if RAID_SURVEY.has_point(p) or near_house(p, 2.0) or in_track(p) or not parcel(p).is_empty():
			continue
		if absf(p.y - 4.0) < 5.0:
			continue  # bridge approach stays open
		var clump := noise("clump", p)
		if clump < -.15:
			continue
		var roll := _rng.randf()
		var asset := "salix_alba"
		var spacing := 7.0
		if offset > 11.0 and roll < .22:
			asset = "populus_nigra"
			spacing = 12.0
		elif roll < .42:
			asset = "alnus_glutinosa"
			spacing = 5.5
		elif roll < .55 and absf(z) < 70.0:
			asset = "salix_alba_pollard"
			spacing = 4.5
		elif roll < .66 and offset > 8.0:
			asset = "fraxinus_angustifolia"
			spacing = 7.5
		if not _free(p, spacing):
			continue
		_tree(asset, p, _rng.randf_range(.72, 1.12), true, spacing)
	# Riparian shrubs (no colliders, allowed on the village bank too).
	for i in 700:
		var z := _rng.randf_range(brook_source_z + 2.0, 140.0)
		var side := -1.0 if _rng.randf() < .5 else 1.0
		var p := Vector2(fen_x(z) + side * (brook_half_width(z) + _rng.randf_range(1.2, 9.0)), z)
		if near_house(p, 1.5) or in_track(p) or absf(p.y - 4.0) < 4.0 or noise("clump", p + Vector2(40, 0)) < 0.0:
			continue
		if not _free(p, 2.6):
			continue
		var asset: String = ["sambucus_nigra", "corylus_avellana", "salix_alba_pollard", "corylus_avellana"][_rng.randi() % 4]
		if asset == "salix_alba_pollard":
			if RAID_SURVEY.has_point(p):
				continue
			_tree(asset, p, _rng.randf_range(.7, .95), true, 4.0)
		else:
			_tree(asset, p, _rng.randf_range(.65, 1.05), false, 2.6)
	# Water-edge herbs in clustered belts.
	for i in 9000:
		var z := _rng.randf_range(brook_source_z + 1.0, 160.0)
		var side := -1.0 if _rng.randf() < .5 else 1.0
		var reach := _rng.randf_range(-.6, 3.4) if z < 65.0 else _rng.randf_range(-8.0, 26.0)
		var base_x := fen_x(z)
		var p := Vector2(base_x + side * (brook_half_width(minf(z, 65.0)) + maxf(0.0, z - 65.0) * .18 + reach), z)
		if absf(p.y - 4.0) < 2.6 or in_track(p) or near_house(p, .5):
			continue
		var belt := noise("patch", p)
		var wet := wetness(p)
		var tile := "sedge"
		var tall := _rng.randf_range(.55, 1.0)
		if belt > .15 and wet > .6:
			tile = "reed_plume" if _rng.randf() < .45 else "reed"
			tall = _rng.randf_range(1.9, 2.9)
		elif belt < -.35:
			tile = ["iris", "loosestrife", "rush"][_rng.randi() % 3]
			tall = _rng.randf_range(.8, 1.4)
		elif _rng.randf() < .3:
			tile = "rush"
		_card("herbs", HERB[tile], p, _rng.randf_range(.7, 1.25) * (1.25 if tile.begins_with("reed") else 1.0), tall)


func _wood() -> void:
	# Oak-hornbeam wood west of the brook: canopy trees by Poisson spacing,
	# glades from noise, wetter ground (toward the brook and fen) favours ash
	# and alder, the edge gets a shrub mantle and a herb fringe.
	# Stand density varies at two scales: large open glades and thickets,
	# and species dominate in patches (hornbeam groves, oak stands, ash and
	# alder where the ground is wet) instead of a uniform mix.
	for i in 16000:
		var p := Vector2(_rng.randf_range(EXTENT.position.x, -30.0), _rng.randf_range(-215.0, 175.0))
		var inside := wood_edge_x(p.y) - p.x
		var copse := inside < 0.0 and inside > -28.0 and noise("clump", p * 1.6) > .42
		if (inside < 0.0 and not copse) or RAID_SURVEY.has_point(p) or water_distance(p) < 3.0 or near_house(p, 2.5) or in_track(p, 1.2):
			continue
		var stand := clampf(.55 + noise("stand", p) * 1.1 - maxf(0.0, noise("glade", p) - .2) * 2.5, 0.0, 1.0)
		if copse:
			stand = maxf(stand, .75)
		if _rng.randf() > stand * stand:
			continue
		var wet := wetness(p)
		var patch := noise("species", p)
		var roll := _rng.randf()
		var asset := "quercus_robur"
		if wet > .5 and roll < .55:
			asset = "alnus_glutinosa" if roll < .3 else "fraxinus_angustifolia"
		elif patch < -.22:
			asset = "carpinus_betulus" if roll < .72 else ("quercus_robur" if roll < .9 else "acer_campestre")
		elif patch > .28:
			asset = "quercus_robur" if roll < .7 else ("quercus_cerris" if roll < .82 else "carpinus_betulus")
		else:
			asset = ["quercus_robur", "carpinus_betulus", "ulmus_minor", "fraxinus_angustifolia" if wet > .25 else "acer_campestre",
				"carpinus_betulus", "quercus_robur"][int(roll * 6.0)]
		var spacing: float = {"quercus_robur": 9.5, "quercus_cerris": 9.0, "carpinus_betulus": 5.5, "ulmus_minor": 7.5,
			"fraxinus_angustifolia": 7.5, "alnus_glutinosa": 5.5, "acer_campestre": 6.0}[asset] * lerpf(1.45, .8, stand)
		# Thin, younger trees in the outer few metres of the edge and in copses.
		var scale := _rng.randf_range(.72, 1.14) * lerpf(.7, 1.0, smoothstep(0.0, 14.0, inside))
		if not _free(p, spacing):
			continue
		_tree(asset, p, scale, true, spacing)
	# Understorey and mantle shrubs.
	for i in 8000:
		var p := Vector2(_rng.randf_range(EXTENT.position.x, -28.0), _rng.randf_range(-215.0, 175.0))
		var inside := wood_edge_x(p.y) - p.x
		if inside < -7.0 or (inside > 3.0 and _rng.randf() < .7) or noise("glade", p) > .45:
			continue
		if near_house(p, 1.0) or in_track(p) or water_distance(p) < 1.0:
			continue
		var mantle := inside < 3.0
		# Understorey grows in thickets under gaps, not as an even carpet.
		if not mantle and noise("clump", p + Vector2(90.0, 17.0)) < .2:
			continue
		# The mantle has gaps where the meadow runs up to the trunks.
		if mantle and noise("patch", p * .5) < -.22:
			continue
		var assets := ["prunus_spinosa", "crataegus_monogyna", "corylus_avellana", "prunus_spinosa", "sambucus_nigra"] if mantle \
			else ["corylus_avellana", "corylus_avellana", "crataegus_monogyna"]
		var asset: String = assets[_rng.randi() % assets.size()]
		if not _free(p, 2.4 if mantle else 3.5):
			continue
		_tree(asset, p, _rng.randf_range(.7, 1.15), false, 2.4)
	# Herb fringe outside the mantle and a sparse shaded wood floor.
	for i in 7000:
		var p := Vector2(_rng.randf_range(EXTENT.position.x, -26.0), _rng.randf_range(-215.0, 175.0))
		var inside := wood_edge_x(p.y) - p.x
		if inside < -11.0 or near_house(p, .5) or in_track(p) or water_distance(p) < .5:
			continue
		if inside < -3.0:
			var tile: String = ["dry", "meadow", "carrot", "knapweed", "meadow", "dry"][_rng.randi() % 6]
			_card("herbs", HERB[tile], p, _rng.randf_range(.8, 1.3), _rng.randf_range(.6, 1.1))
		elif inside > 4.0 and _rng.randf() < .35:
			_card("herbs", HERB["sedge" if wetness(p) > .4 else "meadow"], p, _rng.randf_range(.6, 1.0), _rng.randf_range(.35, .6), .2)


func _hills() -> void:
	# Groves on the slopes outside the raid survey, scrub and dry grass inside;
	# denser in the hollows, thinning toward the stony crest.
	for i in 7000:
		var p := Vector2(_rng.randf_range(-210.0, 210.0), _rng.randf_range(-215.0, -60.0))
		var rise := hill_rise(p)
		if rise < 1.0 or in_track(p) or p.x < wood_edge_x(p.y):
			continue
		if _vineyard(p):
			continue
		var crest := smoothstep(14.0, 24.0, rise)
		var grove := noise("clump", p * 1.3) > -.05 + crest * .5
		if not RAID_SURVEY.has_point(p) and grove and slope_deg(p) < 32.0:
			var roll := _rng.randf()
			var asset := "quercus_cerris" if roll < .45 else ("quercus_robur" if roll < .62 else ("carpinus_betulus" if roll < .85 else "acer_campestre"))
			if _free(p, 8.0):
				_tree(asset, p, _rng.randf_range(.65, 1.0) * lerpf(1.0, .7, crest), true, 8.0)
				continue
		if noise("patch", p) > .1 and _free(p, 2.8):
			var asset: String = ["crataegus_monogyna", "prunus_spinosa", "prunus_spinosa", "corylus_avellana"][_rng.randi() % 4]
			_tree(asset, p, _rng.randf_range(.6, 1.0), false, 2.8)
	for i in 9000:
		var p := Vector2(_rng.randf_range(-150.0, 150.0), _rng.randf_range(-170.0, -58.0))
		if hill_rise(p) < .4 or in_track(p) or p.x < wood_edge_x(p.y) or _vineyard(p):
			continue
		var tile: String = ["dry", "dry", "meadow", "sage", "knapweed", "buttercup", "pasture"][_rng.randi() % 7]
		_card("herbs", HERB[tile], p, _rng.randf_range(.8, 1.3), _rng.randf_range(.4, .85))


func _vineyard(p: Vector2) -> bool:
	return p.x > 62.0 and p.x < 118.0 and p.y > -96.0 and p.y < -70.0


func _farmland() -> void:
	# Vineyard rows along the contour of the south-facing slope ("die Reben
	# stehen jedes Jahr am selben Hang"): stakes 1.5 m apart, rows 2.4 m.
	var row := 0
	var z := -94.0
	while z < -71.0:
		var x := 63.5 + (row % 2) * .75
		while x < 117.0:
			var p := Vector2(x + _rng.randf_range(-.12, .12), z + _rng.randf_range(-.1, .1))
			if hill_rise(p) > .3 and not in_track(p):
				_tree("vitis_stake", p, _rng.randf_range(.9, 1.08), false, 0.0)
				if _rng.randf() < .5:
					_card("herbs", HERB["pasture"], p + Vector2(0, 1.2), _rng.randf_range(.7, 1.1), _rng.randf_range(.25, .45))
			x += 1.5
		z += 2.4
		row += 1
	# Field parcels with crops, margins, hedgerows and married vines.
	var step := 1.15
	var x0 := -6.0
	while x0 < 170.0:
		var z0 := -40.0
		while z0 < 150.0:
			var p := Vector2(x0 + _rng.randf_range(-.45, .45), z0 + _rng.randf_range(-.45, .45))
			z0 += step
			var field := parcel(p)
			if field.is_empty() or field.boundary < 1.5:
				continue
			var crop: String = field.crop
			var margin: bool = field.boundary < 4.5
			var tile: int = CROP[crop]
			if margin and _rng.randf() < .22:
				_card("herbs", HERB[["poppy", "cornflower", "poppy", "carrot", "meadow"][_rng.randi() % 5]], p,
					_rng.randf_range(.7, 1.0), _rng.randf_range(.55, .85))
				continue
			var tall: float = {"wheat": 1.05, "barley": .9, "emmer": 1.05, "millet": .95, "foxtail": .85, "bean": .8,
				"lentil": .45, "stubble": .35, "flax": .75}.get(crop, 1.0) * _rng.randf_range(.85, 1.08)
			_card("crops", tile, p, _rng.randf_range(.85, 1.1), tall, -1.0, .9)
		x0 += step
	# Boundaries: hedgerows of thorn and hazel with standard trees, or rows of
	# pollard field maples carrying vines (arbustum).
	var done := {}
	for gx in range(-1, 6):
		for gz in range(-2, 4):
			var cell := Vector2i(gx, gz)
			for edge in 2:
				var key := "%d_%d_%d" % [gx, gz, edge]
				if done.has(key):
					continue
				done[key] = true
				var h := absi(hash(Vector3i(gx, gz, edge))) % 1000 / 1000.0
				var size := Vector2(44.0, 66.0)
				var start := Vector2(gx * size.x, gz * size.y)
				var end := start + (Vector2(size.x, 0) if edge == 0 else Vector2(0, size.y))
				var length := start.distance_to(end)
				var t := 0.0
				while t < length:
					var q := start.lerp(end, t / length)
					var p := q.rotated(FIELD_ROTATION) + Vector2(_rng.randf_range(-.4, .4), _rng.randf_range(-.4, .4))
					var inside_farm := not parcel(p + Vector2(2.5, 2.5)).is_empty() or not parcel(p - Vector2(2.5, 2.5)).is_empty()
					if not inside_farm or in_track(p) or RAID_SURVEY.has_point(p) or ENCLOSURE.grow(4.0).has_point(p):
						t += 4.0
						continue
					if h < .45:
						if _rng.randf() < .09 and _free(p, 9.0):
							_tree(["quercus_robur", "ulmus_minor", "acer_campestre"][_rng.randi() % 3], p, _rng.randf_range(.7, 1.0), true, 9.0)
						elif _free(p, 1.9):
							_tree(["prunus_spinosa", "crataegus_monogyna", "corylus_avellana", "crataegus_monogyna", "sambucus_nigra"][_rng.randi() % 5],
								p, _rng.randf_range(.75, 1.15), false, 1.9)
						t += _rng.randf_range(1.4, 2.4)
					elif h < .72:
						if _free(p, 7.0) and _tree("acer_campestre_arbustum", p, _rng.randf_range(.9, 1.06), true, 7.0):
							trees.append({"asset": "vitis_arbustum", "position": trees[-1].position, "yaw": trees[-1].yaw,
								"scale": trees[-1].scale, "custom": Color(_rng.randf(), 1.0, _rng.randf(), 0.0), "collider": false, "legacy": false})
							_count("vitis_arbustum")
						t += 8.5
					else:
						t += 6.0


func _village_plants() -> void:
	# Elders by houses and yards; kitchen gardens behind a few homes.
	for home: Dictionary in Layout.HOMES:
		var rect := Layout.house_footprint(home)
		var turned := not is_zero_approx(float(home.yaw))
		var bed := Rect2(rect.position.x + .6, rect.position.y - 2.5, rect.size.x - 1.2, 1.6) if not turned \
			else Rect2(rect.end.x + .9, rect.position.y + .6, 1.6, rect.size.y - 1.2)
		if absi(hash(str(home.id))) % 3 == 0:
			continue
		var plants := ["kale", "leek", "bean", "kale", "lentil", "leek"]
		var row := 0
		var along := bed.size.x if not turned else bed.size.y
		var t := .2
		while t < along:
			for lane in 2:
				var p := bed.position + (Vector2(t, .4 + lane * .8) if not turned else Vector2(.4 + lane * .8, t))
				if Layout.reserved(p, .2) or Layout.road(p) or in_track(p) or p.y > 28.5 or p.y < -48.0:
					continue
				var crop: String = plants[(row + lane + absi(hash(str(home.id)))) % plants.size()]
				_card("crops", CROP[crop], p, _rng.randf_range(.45, .6), _rng.randf_range(.45, .7) if crop != "bean" else .9, -1.0, 1.2)
			t += .55
			row += 1
		_count("gardens")
	for i in 60:
		var home: Dictionary = Layout.HOMES[_rng.randi() % Layout.HOMES.size()]
		var rect := Layout.house_footprint(home, 1.3)
		var corner: Vector2 = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)][_rng.randi() % 4]
		var p: Vector2 = corner + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
		if Layout.reserved(p, .9) or Layout.road(p) or in_track(p, .6) or not ENCLOSURE.has_point(p) or not _free(p, 9.0):
			continue
		if absf(p.x) < 3.5 or absf(p.x - 30.0) < 3.5:
			continue  # main and east streets stay clear
		_tree("sambucus_nigra", p, _rng.randf_range(.55, .75), false, 9.0)
		_count("village_elders")


func _meadows() -> void:
	# Hay meadow, pasture and damp meadow outside the village verges
	# (village_scenery.gd keeps its own verge clumps inside the enclosure).
	var verge := GRASS_FREE
	var flowers := ["poppy", "cornflower", "daisy", "sage", "knapweed", "buttercup", "carrot"]
	for i in 42000:
		var p := Vector2(_rng.randf_range(-130.0, 175.0), _rng.randf_range(-70.0, 165.0))
		if verge.has_point(p) or in_track(p) or p.x < wood_edge_x(p.y) - 9.0 or water_distance(p) < 3.0:
			continue
		if not parcel(p).is_empty() or hill_rise(p) > .5 or near_house(p, .5):
			continue
		var wet := wetness(p)
		var clump := noise("clump", p)
		var density := .55 + .45 * clump
		if _rng.randf() > density:
			continue
		var tile := "meadow"
		var tall := _rng.randf_range(.45, .95)
		var near_village := ENCLOSURE.grow(25.0).has_point(p)
		if wet > .55:
			tile = ["sedge", "meadow", "rush", "loosestrife"][_rng.randi() % 4]
		elif near_village and clump < .1:
			tile = "pasture"
			tall = _rng.randf_range(.25, .45)
		elif clump < -.3:
			tile = "dry"
		var patch := noise("patch", p)
		if absf(patch) > .42:
			# Each flower species blooms in its own drift, not sprinkled evenly.
			tile = flowers[absi(int(patch * 37.0) + floori(p.x / 23.0)) % flowers.size()]
		_card("herbs", HERB[tile], p, _rng.randf_range(.7, 1.25), tall)
	# Solitary field trees in open meadow (outside the raid survey).
	for i in 400:
		var p := Vector2(_rng.randf_range(-40.0, 170.0), _rng.randf_range(-60.0, 160.0))
		if RAID_SURVEY.has_point(p) or not parcel(p).is_empty() or in_track(p) or p.x < wood_edge_x(p.y) or hill_rise(p) > .5:
			continue
		if noise("clump", p) < .05 or not _free(p, 18.0):
			continue
		var asset: String = ["quercus_robur", "ulmus_minor", "quercus_robur", "populus_nigra" if wetness(p) > .3 else "acer_campestre"][_rng.randi() % 4]
		_tree(asset, p, _rng.randf_range(.85, 1.12), true, 22.0)
		_count("solitary_trees")
