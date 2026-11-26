extends RefCounted
## Per-household interior designs for Valdora (58 BC, near Aquileia). One
## shared house shell (door at local +Z, paving at Layout.HOUSE_FLOOR) carries
## its imported table (NW), wall bench (E wall) and corner jar (SW, by the door).
## Coordinates are house-local metres above the paving. Sources and design
## assumptions: docs/35_interiors/INTERIORS.md.
##
## Item keys: prop, id (optional), on ("floor", "wall", "peg", a support id,
## "glb_table", "glb_bench"), at (x, z; relative to the support), yaw (deg),
## wall ("W", "E", "N", "S") with along (metres along the wall), height for
## wall-mounted props, level (support surface index), rail and peg for hanging.

# Visible plaster faces and the edge of the paving inside the shared shell.
const Layout = preload("res://scripts/world/village/village_layout.gd")
const WALL := {"W": -2.68, "E": 2.68, "N": -2.17, "S": 2.17}
const PAVING := Vector2(2.635, 2.125)
const GLB_TABLE := {"rect": Rect2(-1.825, -1.1525, 1.45, 1.085), "top": .85}
const GLB_BENCH := {"rect": Rect2(1.68, -.95, .50, 1.90), "top": .50}
const GLB_JAR := {"centre": Vector2(-2.23, 1.47), "radius": .27, "height": .62}
const DOOR := Vector2(0.0, 1.95)
# Clear door and window openings of the shared shell: Rect2(along the wall,
# above the paving, width, height), "S"/"N" along x and "E"/"W" along z.
const OPENINGS := {
	"S": [Rect2(-.56, 0, 1.12, 2.0975), Rect2(-2.25, 1.1675, .90, .87), Rect2(1.35, 1.1675, .90, .87)],
	"E": [Rect2(-.45, 1.1675, .90, .87)], "N": [Rect2(-.43, 1.3375, .86, .73)], "W": [],
}
const HEARTH := Vector2(1.62, 1.50)
const ATRIUM := "AtriumHouse"

const FAMILY := "baker_home"
const FORGE := "VillageForge"
const MARKET := "ValdoraMarket"
# Open-air work places furnished like rooms: origin and yaw in village space.
const SITES := {
	"VillageForge": {"at": Vector3(34.1, 0, -26.2), "yaw": 0.0, "kind": "smithy", "node": "VillageForge",
		"label": "Dorfschmiede (offener Anbau vor dem Schmiedehaus)"},
	"ValdoraMarket": {"at": Vector3(25, 0, 24), "yaw": 0.0, "kind": "market", "node": "MarketDeliveries",
		"label": "Marktstände an der Südstraße: Lebensmittel sowie Töpfer- und Tuchware"},
}
const HOUSEHOLDS := {
	"baker_home": {"household": "Familie des Helden: Silvanus, Julia und ihr zwölfjähriger Sohn (Kleinbauern)", "profession": "family", "wealth": 1},
	"carpenter_home": {"household": "Marius (25), Zimmermann, mit Frau und Kleinkind", "profession": "carpenter", "wealth": 2},
	"weaver_home": {"household": "Tullia (34), Weberin, mit Mann und Tochter", "profession": "weaver", "wealth": 2},
	"farmer_home": {"household": "Domitius (26), Feldarbeiter, mit den Eltern (Pachtbauern)", "profession": "farmer", "wealth": 1},
	"potter_home": {"household": "Gaius (48), Töpfer, mit Frau", "profession": "potter", "wealth": 2},
	"healer_home": {"household": "Priscilla (46), Heilerin, nimmt Kranke auf", "profession": "healer", "wealth": 2},
	"elder_home": {"household": "Ältestenpaar, wohlhabende Kleinbauern mit Hausaltar", "profession": "elder", "wealth": 3},
	"scribe_home": {"household": "Cassian (44), Schreiber, Witwer", "profession": "scribe", "wealth": 3},
	"vintner_home": {"household": "Octavia (52), Weinbäuerin; schenkt im Wohnraum Wein aus (taberna vinaria)", "profession": "vintner", "wealth": 2},
	"guard_home": {"household": "Lucius (31) und ein Kamerad der Straßenwache", "profession": "guard", "wealth": 1},
	"smith_home": {"household": "Nerva (61), Schmied, mit Frau; Esse im Anbau vor dem Haus", "profession": "smith", "wealth": 2},
	"cloth_home": {"household": "Sabina (29), Tuchhändlerin; Ware im Haus gelagert", "profession": "cloth_trader", "wealth": 3},
	"wagon_home": {"household": "Titus (41), Wagenführer, mit Frau und zwei Kindern", "profession": "carter", "wealth": 2},
	"charcoal_home": {"household": "Köhlerfamilie mit zwei Kindern", "profession": "charcoal_burner", "wealth": 1},
	"leather_home": {"household": "Riemer- und Gerberehepaar", "profession": "leatherworker", "wealth": 2},
	"grain_home": {"household": "Hilarus (39), Müller, mit Frau und Mutter", "profession": "miller", "wealth": 2},
	"south_baker_home": {"household": "Bassa (42), Brotverkäuferin, Backhaushalt", "profession": "baker", "wealth": 2},
	"south_weaver_home": {"household": "Mina (23), Spinnerin, mit ihrer Mutter (Weberin)", "profession": "spinner", "wealth": 1},
	"cooper_home": {"household": "Felix (35), Fassbinder, mit Frau", "profession": "cooper", "wealth": 2},
	"dairy_home": {"household": "Hirtenfamilie des Leontius (57), Milch und Käse", "profession": "dairy", "wealth": 2},
	"AtriumHouse": {"household": "Wohlhabende Familie des Atriumhauses (Grundbesitzer)", "profession": "landowner", "wealth": 4},
}
# The family home is furnished here; its three cups and the jug (table, shelf,
# bench) are live I-01 story props and stay with world/village/i01_props.gd.
const EXCLUDED: Array[String] = []
# I-01 places its props on these surfaces (room-local metres above the paving).
const I01_SLOTS := {"shelf_top": 1.08, "shelf_cups": [Vector2(-2.32, .78), Vector2(-2.32, 1.08), Vector2(-2.32, 1.38)],
	"table_top": .865, "table_cups": [Vector2(-1.35, -.98), Vector2(-.50, -.50), Vector2(-.85, -.15)], "table_jug": Vector2(-.55, -.85),
	"bench_jug": Vector2(1.93, .18), "bench_cup": Vector2(1.93, -.38),
	"people": [Vector2(-1.15, -1.72), Vector2(.05, -.05), Vector2(-1.0, .55), Vector2(.95, -.45)]}
# Every household needs these; professions add their signature items.
const BASIC := ["hearth", "sleeping", "storage", "tableware", "seat"]
const SIGNATURE := {
	"carpenter": ["workbench_low", "carpentry_tools"], "weaver": ["loom_madder", "loom_weights_pile", "spinning_basket"],
	"farmer": ["farm_tools_lean", "hang_sickles", "sack_grain"], "potter": ["shelf_rack", "jar_olla", "amphora_stand"],
	"healer": ["hang_herbs", "mortar_pestle", "pallet_madder"], "elder": ["lararium", "arca", "bed_fine", "chair_wicker"],
	"scribe": ["desk_writing", "capsa", "scroll_pile"], "vintner": ["dolium", "barrel", "amphora_rack", "tavern_set", "workbench", "basket_grapes", "candle_dish"],
	"guard": ["guard_kit", "hang_cloak"], "smith": ["smith_tools", "iron_bars", "basket_charcoal"],
	"cloth_trader": ["cloth_bolts", "workbench"], "carter": ["wheel_lean", "rope_coil", "hang_leather"],
	"charcoal_burner": ["basket_charcoal", "pallet_brown"], "leatherworker": ["hide_frame", "hides_stack", "hang_leather"],
	"miller": ["quern", "sack_flour", "basket_flour"], "baker": ["hearth_baker", "kneading_trough", "bread_loaves"],
	"spinner": ["loom_warp", "spinning_basket", "basket_wool"], "cooper": ["barrel", "staves_bundle", "workbench_low"],
	"dairy": ["cheese_press", "bucket_milk", "cheese_stack"],
	"family": ["wall_shelf_deep", "table_bread", "farm_tools_lean", "pallet_brown", "oil_lamp"],
	"smithy": ["forge_shelter", "forge_hearth", "forge_bellows", "anvil_block", "tool_rack_smith", "quench_trough", "iron_blooms", "iron_bars",
		"basket_charcoal", "smith_wares", "smith_wares_b", "smith_tools", "oil_lamp"],
	"market": ["stall_trestle", "stall_trestle_b", "balance_scale", "crate_greens", "bread_loaves", "cheese_stack", "cloth_bolts",
		"shelf_jars", "amphora_stand", "basket_apples"],
	"landowner": ["cartibulum", "arca", "lararium", "loom_warp", "candelabrum", "armarium", "bronze_vessels"],
}
# The atrium is a reception and working hall; sleeping rooms are not modelled.
const BASIC_ATRIUM := ["hearth", "storage", "tableware", "seat"]
const BASIC_SITE := {"smithy": ["hearth", "storage"], "market": ["storage", "tableware"]}
const CATEGORY := {
	"hearth": ["hearth_cook", "hearth_baker", "hearth_ring", "brazier", "forge_hearth"],
	"sleeping": ["bed_madder", "bed_ochre", "bed_woad", "bed_natural", "bed_brown", "bed_fine", "pallet_brown", "pallet_madder"],
	"storage": ["chest_wood", "chest_small", "arca", "shelf_rack", "shelf_low", "wall_shelf", "dolium", "jar_olla", "jar_coarse",
		"sack_grain", "sack_hemp", "sack_flour", "basket_empty", "basket_grain", "basket_apples", "basket_onions", "basket_charcoal",
		"barrel", "amphora_stand", "capsa"],
	"tableware": ["table_meal", "table_bread", "shelf_bowls", "shelf_jars", "bread_loaves", "bronze_vessels"],
	"seat": ["stool_three", "stool_log", "bench_short", "bench_plain", "chair_wicker"],
}


## Physical frame of a house type: floor height, plaster faces, the planes that
## standing furniture keeps to (paving edge or painted dado), fixed obstacles
## (imported furniture, columns, basin) and the door, all in house-local metres.
static func shell(id: String) -> Dictionary:
	if id == FORGE:
		# Lean-to (posts at x = -0.10 and 1.25, z = -3.15 and 3.0) in front of the
		# smith's house; its entry ramp ends inside the shelter and stays clear.
		# The work stations are the points the apprenticeship uses
		# (story/village_childhood.gd POINTS bellows, anvil, quench).
		var posts := []
		for x: float in [-.10, 1.25]:
			for z: float in [-3.15, 3.0]:
				posts.append(AABB(Vector3(x - .06, 0, z - .06), Vector3(.12, 2.55, .12)))
		return {"floor": 0.0, "wall": {"W": -1.9, "E": 1.5, "N": -3.5, "S": 3.35}, "stand": {"W": -1.9, "E": 1.5, "N": -3.5, "S": 3.35},
			"fixed": posts, "door": Vector2(-1.3, 0), "doorway": [Vector3(.55, 1.30, .2), Vector3(1.6, 1.10, 1.2)], "grid": Vector2(1.7, 3.2),
			"stations": [Vector2(-1.4, -2.2), Vector2(-1.3, 0), Vector2(-1.4, 2.4), Vector2(.45, -1.35), Vector2(.30, 1.25), Vector2(-.45, .55)],
			"meshes": "", "site": true}
	if id == MARKET:
		return {"floor": 0.0, "wall": {"W": -3.6, "E": 3.6, "N": -3.4, "S": 3.4}, "stand": {"W": -3.6, "E": 3.6, "N": -3.4, "S": 3.4},
			"fixed": [], "door": Vector2(0, 2.6), "doorway": [Vector3(0, .95, 2.0), Vector3(6.0, 1.75, 1.0)], "grid": Vector2(3.5, 3.3),
			"stations": [Vector2(0, 2.6), Vector2(-1.25, .65), Vector2(1.25, .65), Vector2(-1.0, -1.8), Vector2(1.3, -1.8)],
			"meshes": "", "site": true}
	if id == ATRIUM:
		# Domus by art/architecture/build_atrium.py: side dado to 1.06 m, rear
		# dado and wall panels, fauces walls either side of the entrance.
		var fixed := [AABB(Vector3(-1.66, 0, -1.89), Vector3(3.32, .25, 3.78)), AABB(Vector3(-4.11, 0, -4.38), Vector3(1.96, .56, .58)),
			AABB(Vector3(2.60, 0, -4.48), Vector3(.62, .95, .62)), AABB(Vector3(3.21, 0, -4.39), Vector3(.48, .75, .48)),
			AABB(Vector3(-1.14, 0, 2.64), Vector3(.22, 2.7, 2.12)), AABB(Vector3(.92, 0, 2.64), Vector3(.22, 2.7, 2.12)),
			AABB(Vector3(-1.905, 0, -2.05), Vector3(.37, .03, 4.1)), AABB(Vector3(1.535, 0, -2.05), Vector3(.37, .03, 4.1)),
			AABB(Vector3(-1.545, 0, -2.08), Vector3(3.09, .03, .32)), AABB(Vector3(-1.545, 0, 1.76), Vector3(3.09, .03, .32))]
		for x: float in [-2.0, 2.0]:
			for z: float in [-2.15, 2.15]:
				fixed.append(AABB(Vector3(x - .28, 0, z - .28), Vector3(.56, 3.0, .56)))
		return {"floor": .065, "wall": {"W": -5.20, "E": 5.20, "N": -4.70, "S": 4.74},
			"stand": {"W": -5.12, "E": 5.12, "N": -4.73, "S": 4.74}, "fixed": fixed, "door": Vector2(0, 3.9),
			"doorway": [Vector3(0, .95, 3.7), Vector3(1.6, 1.75, 1.6)], "grid": Vector2(5.1, 4.65),
			"stations": [Vector2(0, 3.9), Vector2(-3.95, -.9), Vector2(4.1, -1.2), Vector2(0, -2.25), Vector2(3.6, 2.2), Vector2(-3.6, 2.6)],
			"meshes": "Domus_tetrastyle"}
	var house_fixed := [AABB(Vector3(GLB_TABLE.rect.position.x, 0, GLB_TABLE.rect.position.y), Vector3(GLB_TABLE.rect.size.x, .86, GLB_TABLE.rect.size.y)),
		AABB(Vector3(GLB_BENCH.rect.position.x, 0, GLB_BENCH.rect.position.y), Vector3(GLB_BENCH.rect.size.x, .52, GLB_BENCH.rect.size.y)),
		AABB(Vector3(GLB_JAR.centre.x - .27, 0, GLB_JAR.centre.y - .27), Vector3(.54, .62, .54))]
	# The open door leaf swings 100 degrees inward from its hinge at (-0.575, 2.15).
	for k in 12:
		var point := Vector2(-.575, 2.15).lerp(Vector2(-.575, 2.15) + Vector2(1.12, 0).rotated(-deg_to_rad(100)), k / 11.0)
		house_fixed.append(AABB(Vector3(point.x - .045, 0, point.y - .045), Vector3(.09, 2.1, .09)))
	return {"floor": .3925, "wall": WALL, "stand": {"W": -PAVING.x, "E": PAVING.x, "N": -PAVING.y, "S": PAVING.y},
		"fixed": house_fixed, "door": DOOR, "doorway": [Vector3(.075, .95, 1.38), Vector3(1.15, 1.75, 1.55)],
		"grid": Vector2(2.6, 2.1), "stations": stations(id), "meshes": "frontier_house_*", "wall_top": 2.80, "openings": OPENINGS}


static func is_site(id: String) -> bool:
	return SITES.has(id)


static func basics(id: String) -> Array:
	if is_site(id):
		return BASIC_SITE[SITES[id].kind]
	return BASIC_ATRIUM if id == ATRIUM else BASIC


static func profession(id: String) -> String:
	return SITES[id].kind if is_site(id) else HOUSEHOLDS[id].profession


## Soot, ash and trodden dirt follow the household: 1.0 poor, less with wealth.
static func grime(id: String) -> float:
	if is_site(id):
		return 1.0
	return [1.0, 1.0, .8, .55, .3][int(HOUSEHOLDS[id].wealth)]


## Machine-readable interface for shell builders (architecture families):
## what a house shell must provide so these interiors fit. Mirrored in
## res://assets/interiors/shell_contract.json; house_interiors_test.gd fails
## when the file and this function disagree.
static func contract() -> Dictionary:
	var users: Array = []
	for id: String in HOUSEHOLDS:
		if id != ATRIUM and id != FAMILY:
			users.append(id)
	users.sort()
	var households := {}
	for id: String in HOUSEHOLDS:
		households[id] = {"shell": "atrium_house" if id == ATRIUM else "frontier_house", "profession": HOUSEHOLDS[id].profession,
			"wealth": HOUSEHOLDS[id].wealth, "signature_props": SIGNATURE.get(HOUSEHOLDS[id].profession, [])}
	return {
		"schema": 2,
		"units": "metres; house-local axes of the house node: +Y up, entrance at +Z; heights above the walkable floor unless named _abs",
		"source": "prototype/scripts/world/village/household_designs.gd (contract), tools/art/build_architecture.py, art/architecture/build_atrium.py",
		"shells": {
			"frontier_house": {"used_by": users + ["baker_home (family home; cups and jug are I-01 props)"], "floor_abs": .3925,
				"plaster_faces": WALL, "standing_limits": {"x": PAVING.x, "z": PAVING.y}, "wall_plate_height": 2.8675,
				# Clear sizes inside the timber frames (tools/art/build_architecture.py opening_frame).
				"door": {"wall": "S", "centre_x": 0.0, "clear_width": 1.12, "clear_height": 2.0975,
					"open_leaf": {"hinge": [-.575, 2.15], "open_degrees": 100, "length": 1.12, "thickness": .064}},
				"windows": [{"wall": "S", "x": [-2.25, -1.35], "sill": 1.1675, "head": 2.0375}, {"wall": "S", "x": [1.35, 2.25], "sill": 1.1675, "head": 2.0375},
					{"wall": "E", "z": [-.45, .45], "sill": 1.1675, "head": 2.0375}, {"wall": "N", "x": [-.43, .43], "sill": 1.3375, "head": 2.0675}],
				"baked_furniture": [{"name": "table", "x": [-1.825, -.375], "z": [-1.1525, -.0675], "top": GLB_TABLE.top},
					{"name": "wall_bench", "x": [1.68, 2.18], "z": [-.95, .95], "top": GLB_BENCH.top},
					{"name": "corner_jar", "centre": [GLB_JAR.centre.x, GLB_JAR.centre.y], "radius": GLB_JAR.radius, "height": GLB_JAR.height}],
				"zones": {"hearth": {"centre": [HEARTH.x, HEARTH.y], "radius": .53, "light_height": .62},
					"bed": {"x": [.54, 2.53], "z": [-2.12, -1.08]}, "west_wall_work": {"x": [-2.635, -1.9], "z": [-1.15, 1.15]},
					"doorway_clear": {"x": [-.5, .65], "z": [.6, 2.17], "height": [.075, 1.825]}},
				"stations": [[DOOR.x, DOOR.y], [.95, -.85], [.80, 1.20], [-.80, .25], [-1.75, .45]]},
			"atrium_house": {"used_by": [ATRIUM], "floor_abs": .065,
				"plaster_faces": shell(ATRIUM).wall, "standing_limits": shell(ATRIUM).stand,
				"door": {"wall": "S", "centre_x": 0.0, "clear_width": 1.84, "passage_z": [2.65, 4.75], "open_leaves": "against the fauces walls"},
				"windows": [{"wall": "S", "x": [-4.05, -2.87], "sill": 1.605, "head": 2.465}, {"wall": "S", "x": [2.87, 4.05], "sill": 1.605, "head": 2.465}],
				"obstacles": "impluvium basin, four columns, rear bench, two jars, mosaic strips (see shell())",
				"dado_height": {"side": 1.06, "rear": 1.04}},
		},
		"sites": {
			FORGE: {"origin_abs": [SITES[FORGE].at.x, SITES[FORGE].at.y, SITES[FORGE].at.z], "yaw_deg": 0.0, "kind": "smithy",
				"roof_posts": [[-.10, -3.15], [-.10, 3.0], [1.25, -3.15], [1.25, 3.0]], "roof_x": [-.82, 1.42], "roof_z": [-3.42, 3.32],
				"eaves_height": [2.48, 2.92], "open_sides": ["W", "N", "S"], "house_wall_x": 1.45,
				"house_ramp": {"x": [-.10, 1.45], "z": [-.43, .83]},
				"work_points": {"bellows": [-1.4, -2.2], "anvil": [-1.3, 0.0], "quench": [-1.4, 2.4]},
				"needs": "A lean-to or workshop shell of at least 2.3 x 6.6 m with 2.3 m clear height at the lane side, open to the lane; the hearth stands in the north third, the house door in the middle stays free."},
		},
		"family_home": {"id": FAMILY, "story_props": "three cups and the jug belong to the I-01 slice (world/village/i01_props.gd)",
			"shelf_top": I01_SLOTS.shelf_top, "table_top": I01_SLOTS.table_top, "bench_top": GLB_BENCH.top,
			"shelf_cups": I01_SLOTS.shelf_cups.map(func(p: Vector2) -> Array: return [p.x, p.y]),
			"table_cups": I01_SLOTS.table_cups.map(func(p: Vector2) -> Array: return [p.x, p.y]),
			"table_jug": [I01_SLOTS.table_jug.x, I01_SLOTS.table_jug.y], "bench_jug": [I01_SLOTS.bench_jug.x, I01_SLOTS.bench_jug.y],
			"bench_cup": [I01_SLOTS.bench_cup.x, I01_SLOTS.bench_cup.y],
			"people": I01_SLOTS.people.map(func(p: Vector2) -> Array: return [p.x, p.y])},
		"interiors": _interior_records(),
		"min_corridor_width": .60,
		"needs_from_shells": [
			"A collider whose top equals the visible paving, flat within the standing limits.",
			"Door clear width >= 1.10 m and height >= 2.00 m; an open leaf rests against a wall, outside the doorway-clear box.",
			"Interior furniture as separate nodes, not merged into roof or wall meshes (frontier_house bakes table and bench into its roof-board surface).",
			"A hearth zone of about 1.1 x 1.1 m near a window or the door (smoke, light) with >= 2.6 m clear height above.",
			"One solid wall run >= 2.3 m without openings below 1.9 m (loom, shelf rack, workbench) and a solid back wall run >= 2.0 m for a bed.",
			"Plaster faces without openings between 1.2 and 2.0 m where shelves, peg rails or a house shrine hang.",
			"Wealth tiers: 1-2 one room of >= 20 m2; 3 adds storage space or a second room; 4 (atrium) separate reception and work areas.",
			"Publish these same keys per new shell so house_interiors.gd can place against it.",
		],
		"households": households,
	}


## One record per interior: where it stands in the village and its clear room.
static func _interior_records() -> Array:
	var records: Array = []
	for home: Dictionary in Layout.HOMES:
		records.append({"id": home.id, "kind": "house", "shell": "frontier_house", "origin_abs": [home.at.x, home.at.y, home.at.z],
			"yaw_deg": snappedf(rad_to_deg(float(home.yaw)), .001), "floor_abs": Layout.HOUSE_FLOOR,
			"bounds_local": {"min": [WALL.W, 0.0, WALL.N], "max": [WALL.E, 2.8675, WALL.S]},
			"door": {"wall": "S", "x": [-.56, .56], "height": 2.0975}, "windows": "shells.frontier_house.windows",
			"wealth": HOUSEHOLDS[home.id].wealth, "profession": HOUSEHOLDS[home.id].profession})
	var atrium := shell(ATRIUM)
	records.append({"id": ATRIUM, "kind": "atrium", "shell": "atrium_house", "origin_abs": [14.0, 0.0, -30.0], "yaw_deg": 0.0, "floor_abs": atrium.floor,
		"bounds_local": {"min": [atrium.wall.W, 0.0, atrium.wall.N], "max": [atrium.wall.E, 3.0, atrium.wall.S]},
		"door": {"wall": "S", "x": [-.92, .92], "passage_z": [2.65, 4.75]}, "windows": "shells.atrium_house.windows",
		"wealth": HOUSEHOLDS[ATRIUM].wealth, "profession": HOUSEHOLDS[ATRIUM].profession})
	for site: String in SITES:
		var frame := shell(site)
		records.append({"id": site, "kind": SITES[site].kind, "shell": "open site", "origin_abs": [SITES[site].at.x, SITES[site].at.y, SITES[site].at.z],
			"yaw_deg": snappedf(rad_to_deg(float(SITES[site].yaw)), .001), "floor_abs": 0.0,
			"bounds_local": {"min": [frame.wall.W, 0.0, frame.wall.N], "max": [frame.wall.E, 2.95, frame.wall.S]}, "door": {}, "windows": []})
	return records


static func _floor(prop: String, x: float, z: float, yaw := 0.0, id := "") -> Dictionary:
	return {"id": id, "prop": prop, "on": "floor", "at": Vector2(x, z), "yaw": yaw}


static func _wall(prop: String, side: String, along: float, id := "") -> Dictionary:
	return {"id": id, "prop": prop, "on": "floor", "wall": side, "along": along, "yaw": 0.0}


static func _mount(prop: String, side: String, along: float, height: float, id := "") -> Dictionary:
	return {"id": id, "prop": prop, "on": "wall", "wall": side, "along": along, "height": height, "yaw": 0.0}


static func _on(prop: String, support: String, x: float, z: float, level := 0, yaw := 0.0, id := "") -> Dictionary:
	return {"id": id, "prop": prop, "on": support, "at": Vector2(x, z), "level": level, "yaw": yaw}


static func _hang(prop: String, rail: String, peg: int) -> Dictionary:
	return {"id": "", "prop": prop, "on": "peg", "rail": rail, "peg": peg}


## Hearth corner, sleeping place along the back wall and the table setting.
static func _core(bed: String, hearth := "hearth_cook", seat := "bench_short") -> Array:
	var list := [_floor(hearth, HEARTH.x, HEARTH.y, 0.0, "hearth"), _floor("firewood_small", 2.42, 1.52, 90.0, "wood")]
	if bed == "bed_fine":
		list.append(_floor(bed, 1.55, -1.60, 180.0, "bed"))
	elif bed.begins_with("pallet"):
		list.append(_floor(bed, 1.55, -1.70, 180.0, "bed"))
	else:
		list.append(_floor(bed, 1.55, -1.62, 180.0, "bed"))
	if seat != "":
		list.append(_floor(seat, -1.10, -1.42, 0.0, "seat"))
	list.append(_on("table_meal", "glb_table", -1.05, -.62))
	return list


static func _rail_west(id := "rail") -> Dictionary:
	# Above the corner jar, so hanging cloth clears its 0.62 m rim.
	return _mount("peg_rail", "W", 1.45, 1.75, id)


static func _rail_east(id := "rail") -> Dictionary:
	# Above the head of the bed, clear of the east window, where a loom or
	# house shrine takes the west wall.
	return _mount("peg_rail", "E", -1.6, 1.95, id)


static func items(id: String) -> Array:
	var list: Array = []
	match id:
		"baker_home":
			# Parents' bed, the boy's pallet, the cup shelf at the height the
			# I-01 cups use (top 1.08 m) and a table laid without drinking vessels.
			list = [_floor("hearth_cook", HEARTH.x, HEARTH.y, 0.0, "hearth"), _floor("firewood_small", 2.42, 1.52, 90.0, "wood"),
				_floor("bed_madder", 1.55, -1.62, 180.0, "bed"), _wall("pallet_brown", "W", -.55),
				_mount("wall_shelf_deep", "W", 1.05, .845, "cupshelf"), _on("oil_lamp", "cupshelf", .50, .08, 0, 200.0),
				_on("table_bread", "glb_table", -1.55, -.42), _on("candle_dish", "glb_table", -1.18, -.28),
				_mount("wall_shelf", "E", 1.50, 1.45, "shelf"), _on("shelf_jars", "shelf", -.25, 0), _on("cheese_stack", "shelf", .30, 0),
				_wall("chest_wood", "S", -1.40, "chest"), _wall("farm_tools_lean", "N", -.05), _floor("stool_three", -.05, -.90),
				_floor("sack_grain", -2.38, -1.88), _floor("basket_apples", -1.93, -1.87), _on("basket_onions", "glb_bench", 1.93, .66),
				_rail_east(), _hang("hang_cloak", "rail", 1), _hang("hang_onions", "rail", 3), _floor("bucket", .95, 1.95),
				_floor("rush_mat", .85, -.62)]
		"VillageForge":
			# West (-x) is the lane and the three work stations; the house wall
			# and its ramp (z -0.45 .. 0.85) are east. Hearth and bellows north,
			# anvil within two steps of the fire, slack tub and stock south.
			list = [_floor("forge_shelter", 0, 0), _floor("forge_hearth", .82, -2.25, -90.0, "hearth"), _floor("forge_bellows", -.40, -2.25, -90.0),
				_floor("anvil_block", -.55, -.92, 180.0, "anvil"), _floor("tool_rack_smith", 1.08, -1.17, -90.0),
				_floor("quench_trough", -.30, 2.45), _floor("workbench", 1.0, 1.60, -90.0, "bench"),
				_on("smith_wares", "bench", -.30, .02), _on("oil_lamp", "bench", .17, -.14, 0, 140.0),
				_on("smith_tools", "bench", .46, .0, 0, 100.0), _floor("chest_wood", .62, 2.93, 180.0, "stock"),
				_on("smith_wares_b", "stock", 0, .0), _floor("iron_bars", .40, 2.25), _floor("iron_blooms", .84, -3.10),
				_floor("basket_charcoal", .24, -3.07), _floor("basket_charcoal", -.55, -2.95), _floor("bucket", .35, -.80)]
		"ValdoraMarket":
			# Two trestle stalls face the street (+z); sellers stand behind.
			list = [_floor("stall_trestle_b", -1.25, -1.0, 0.0, "food"), _on("bread_loaves", "food", -.55, .05),
				_on("cheese_stack", "food", -.02, -.04), _on("balance_scale", "food", .52, .08, 0, 12.0),
				_floor("stall_trestle", 1.25, -1.0, 0.0, "wares"), _on("shelf_jars", "wares", -.55, .0), _on("shelf_bowls", "wares", -.05, .06),
				_on("cloth_bolts", "wares", .52, .02), _floor("crate_greens", -2.15, .12, 8.0), _floor("basket_apples", -1.45, .0),
				_floor("basket_onions", -.75, -.03), _floor("sack_grain", -2.0, -2.0), _floor("sack_grain", -1.58, -2.14),
				_floor("stool_three", -.30, -2.2), _floor("jar_olla", .62, -.08), _floor("jar_coarse", 1.08, -.05),
				_floor("amphora_stand", 1.95, .0), _floor("chest_small", 2.1, -2.15, 180.0, "box"), _on("cloth_bolts_b", "box", 0, 0),
				_floor("stool_log", .35, -2.25)]
		"carpenter_home":
			list = _core("bed_ochre")
			list += [_wall("workbench_low", "W", .05, "work"), _on("carpentry_tools", "work", .0, .02),
				_floor("stool_three", -.20, -.50), _mount("wall_shelf", "N", -1.1, 1.42, "shelf"),
				_on("shelf_bowls", "shelf", -.30, 0), _on("oil_lamp", "shelf", .35, 0), _rail_west(),
				_hang("hang_cloak", "rail", 1), _hang("hang_herbs", "rail", 3), _wall("chest_wood", "S", -1.40, "chest"),
				_floor("basket_apples", -2.36, -1.86), _floor("sack_grain", -1.92, -1.88), _wall("broom", "N", .05),
				_floor("rush_mat", .85, -.62), _floor("bucket", .95, 1.95)]
		"weaver_home":
			list = _core("bed_woad")
			list += [_wall("loom_madder", "W", .25, "loom"), _floor("loom_weights_pile", -1.75, 1.0),
				_floor("spinning_basket", -1.25, .92), _floor("basket_wool", -2.36, -1.86), _floor("sack_hemp", -1.92, -1.88),
				_floor("stool_three", -.20, -.50), _mount("wall_shelf", "N", -1.1, 1.42, "shelf"),
				_on("cloth_bolts", "shelf", -.30, .03), _on("shelf_bowls", "shelf", .32, 0), _wall("chest_small", "S", -1.45),
				_rail_east(), _hang("hang_cloak", "rail", 1), _hang("hang_herbs", "rail", 3), _floor("rush_mat", .85, -.62)]
		"farmer_home":
			list = _core("bed_brown")
			list += [_wall("pallet_brown", "W", 0.0), _wall("farm_tools_lean", "N", -.05), _rail_west(),
				_hang("hang_sickles", "rail", 1), _hang("hang_onions", "rail", 3), _floor("sack_grain", -2.35, -1.85),
				_floor("sack_grain", -1.93, -1.87), _floor("basket_onions", -1.45, 1.80), _floor("basket_apples", -.97, 1.83),
				_floor("jar_coarse", 1.0, 2.0), _floor("stool_log", -.20, -.50), _on("basket_bread", "glb_bench", 1.93, .50),
				_mount("wall_shelf", "N", -1.1, 1.42, "shelf"), _on("shelf_jars", "shelf", 0, 0)]
		"potter_home":
			list = _core("bed_madder", "hearth_cook", "")
			list += [_wall("shelf_rack", "W", 0.0, "rack"), _on("shelf_jars", "rack", -.25, 0, 0, 0), _on("shelf_jars", "rack", .25, 0, 1),
				_on("shelf_bowls", "rack", -.2, 0, 1), _on("shelf_jars", "rack", .1, 0, 2), _wall("shelf_low", "N", -1.10, "low"),
				_on("shelf_bowls", "low", -.2, 0, 0), _on("shelf_jars", "low", .1, 0, 1), _on("shelf_bowls", "low", .2, 0, 2),
				_floor("amphora_stand", -2.25, -1.72), _floor("jar_olla", -1.58, 1.84), _floor("jar_olla", -1.13, 1.88),
				_floor("stool_three", -.20, -.50), _on("shelf_jars", "glb_bench", 1.93, -.45, 0, 90),
				_on("shelf_jars", "glb_bench", 1.93, .40, 0, 90), _rail_west(), _hang("hang_cloak", "rail", 1), _floor("rush_mat", .85, -.62)]
		"healer_home":
			list = _core("bed_natural", "hearth_cook", "")
			list += [_wall("pallet_madder", "N", -1.6), _wall("shelf_rack", "W", 0.0, "rack"), _on("shelf_jars", "rack", 0, 0, 0),
				_on("shelf_bowls", "rack", -.15, 0, 1), _on("mortar_pestle", "rack", .3, 0, 1), _on("shelf_jars", "rack", .1, 0, 2),
				_on("mortar_pestle", "glb_table", -.62, -.35), _rail_west(), _hang("hang_herbs", "rail", 0), _hang("hang_herbs", "rail", 1),
				_hang("hang_herbs", "rail", 2), _hang("hang_onions", "rail", 3), _mount("wall_shelf", "E", 1.50, 1.45, "eshelf"),
				_on("shelf_jars", "eshelf", -.25, 0), _on("oil_lamp", "eshelf", .35, 0), _wall("chest_small", "S", -1.45),
				_floor("stool_three", -.20, -.50), _floor("bucket", .95, 1.95), _floor("basket_empty", -2.3, .90)]
		"elder_home":
			list = _core("bed_fine", "hearth_cook", "")
			list += [_wall("arca", "N", -1.10), _mount("lararium", "W", .88, 1.25), _wall("chest_wood", "S", -1.40, "chest"),
				_floor("chair_wicker", .05, -.70, 180.0), _floor("stool_three", -2.05, -.85), _on("oil_lamp", "glb_table", -.55, -.3),
				_wall("shelf_rack", "W", 0.0, "rack"), _on("shelf_jars", "rack", 0, 0, 0), _on("shelf_bowls", "rack", 0, 0, 1),
				_on("cheese_stack", "rack", -.1, 0, 2), _floor("amphora_stand", -2.25, -1.72), _floor("candelabrum", .62, -.78),
				_floor("rush_mat", .85, -.25), _rail_east(), _hang("hang_cloak", "rail", 1), _hang("hang_onions", "rail", 3),
				_on("cloth_bolts", "chest", 0, 0)]
		"scribe_home":
			list = _core("bed_woad", "hearth_cook", "")
			list += [_wall("desk_writing", "W", .15, "desk"), _floor("stool_three", -1.90, .40), _floor("capsa", -2.42, .90),
				_wall("shelf_low", "N", -1.10, "low"), _on("scroll_pile", "low", 0, 0, 0), _on("scroll_pile", "low", 0, 0, 1),
				_on("shelf_bowls", "low", 0, 0, 2), _wall("chest_wood", "S", -1.40, "chest"), _on("oil_lamp", "glb_table", -.55, -.3),
				_wall("amphora_lean", "N", .15), _floor("stool_three", -.20, -.50), _rail_west(), _hang("hang_cloak", "rail", 1)]
		"vintner_home":
			# Wine sold from the living room: counter by the west wall, amphorae
			# and the press vats behind, guests at the house table.
			list = [_floor("hearth_cook", HEARTH.x, HEARTH.y, 0.0, "hearth"), _floor("firewood_small", 2.42, 1.52, 90.0, "wood"),
				_floor("bed_ochre", 1.55, -1.62, 180.0, "bed"), _on("table_meal", "glb_table", -1.05, -.62),
				_on("tavern_set", "glb_table", -1.42, -.30, 0, 200.0), _on("candle_dish", "glb_table", -.62, -.25),
				_wall("workbench", "W", .12, "counter"), _on("tavern_set", "counter", -.28, 0),
				_on("oil_lamp", "counter", .55, .05, 0, 40.0), _floor("dolium", -2.19, -1.69),
				_wall("amphora_rack", "N", -1.02), _floor("barrel", .08, -1.82), _wall("amphora_lean", "S", -1.55),
				_wall("amphora_lean", "S", -1.20), _on("basket_grapes", "glb_bench", 1.93, .45), _floor("jar_olla", .90, 2.0),
				_floor("stool_three", -.20, -.50), _floor("stool_log", .32, -.98), _rail_west(), _hang("hang_cloak", "rail", 1),
				_hang("hang_onions", "rail", 3)]
		"guard_home":
			list = _core("bed_brown", "hearth_cook", "")
			list += [_wall("pallet_brown", "W", 0.0), _wall("guard_kit", "N", -1.02), _wall("chest_small", "S", -1.45),
				_rail_west(), _hang("hang_cloak", "rail", 1), _hang("hang_cloak", "rail", 3), _floor("stool_log", -.20, -.50),
				_floor("jar_coarse", 1.0, 2.0), _floor("sack_hemp", -2.35, -1.85)]
		"smith_home":
			list = _core("bed_madder")
			list += [_wall("workbench_low", "W", .05, "work"), _on("smith_tools", "work", 0, .05, 0, 90), _floor("iron_bars", -1.55, 1.0, 20.0),
				_wall("chest_wood", "S", -1.40, "chest"), _on("smith_tools", "chest", 0, 0), _floor("basket_charcoal", -2.30, -1.80),
				_floor("bucket", .95, 1.95), _rail_west(), _hang("hang_leather", "rail", 1), _hang("hang_cloak", "rail", 3),
				_floor("stool_three", -.20, -.50), _mount("wall_shelf", "N", -1.1, 1.42, "shelf"), _on("shelf_jars", "shelf", 0, 0)]
		"cloth_home":
			list = _core("bed_woad", "hearth_cook", "")
			list += [_wall("workbench", "W", .10, "counter"), _on("cloth_bolts", "counter", -.35, 0, 0, 90),
				_on("cloth_bolts_b", "counter", .30, 0, 0, 80), _wall("shelf_rack", "N", -1.10, "rack"),
				_on("cloth_bolts", "rack", -.25, 0, 0), _on("cloth_bolts_b", "rack", .25, 0, 0), _on("cloth_bolts_b", "rack", -.25, 0, 1),
				_on("cloth_bolts", "rack", .25, 0, 1), _on("cloth_bolts", "rack", 0, 0, 2), _wall("chest_wood", "S", -1.40, "chest"),
				_floor("basket_wool", -2.30, -1.80), _floor("spinning_basket", -1.55, .95), _floor("stool_three", -.20, -.50),
				_rail_west(), _hang("hang_cloak", "rail", 1), _floor("rush_mat", .85, -.62)]
		"wagon_home":
			list = _core("bed_ochre")
			list += [_wall("pallet_madder", "W", 0.0), _wall("wheel_lean", "N", -.05), _wall("chest_small", "S", -1.55),
				_floor("rope_coil", -1.0, 1.85), _rail_west(), _hang("hang_leather", "rail", 0), _hang("hang_leather", "rail", 2),
				_floor("sack_grain", -2.35, -1.85), _on("basket_bread", "glb_bench", 1.93, .50), _floor("stool_log", -.20, -.50)]
		"charcoal_home":
			list = _core("pallet_brown")
			list += [_wall("pallet_madder", "W", 0.0), _floor("basket_charcoal", -2.30, -1.80), _floor("basket_charcoal", -1.45, 1.82),
				_floor("sack_hemp", -1.0, 1.85), _floor("stool_log", -.20, -.50), _floor("stool_log", .95, .45),
				_floor("jar_coarse", 1.0, 2.0), _floor("pot_cook", .78, -.05), _floor("rush_mat", .85, -.62)]
		"leather_home":
			list = _core("bed_brown", "hearth_cook", "")
			list += [_wall("workbench", "W", .05, "work"), _on("hides_stack", "work", 0, 0),
				_wall("hide_frame", "N", -.10), _floor("basket_empty", -1.40, 1.82), _rail_west(), _hang("hang_leather", "rail", 1),
				_hang("hang_leather", "rail", 3), _floor("bucket", .95, 1.95), _floor("stool_three", -.20, -.50),
				_floor("stool_three", -1.10, -1.45), _floor("sack_hemp", -2.35, -1.85), _floor("basket_empty", -1.88, -1.86)]
		"grain_home":
			list = _core("bed_natural")
			list += [_floor("quern", -1.35, 1.74), _floor("quern", -2.25, -1.70, -10.0), _floor("sack_grain", -2.0, 1.0),
				_floor("sack_grain", .25, -1.0), _on("sack_flour", "glb_bench", 1.93, -.50), _on("basket_flour", "glb_bench", 1.93, .45),
				_wall("shelf_rack", "W", 0.0, "rack"), _on("shelf_jars", "rack", 0, 0, 0), _on("bread_loaves", "rack", 0, 0, 1),
				_on("basket_grain", "glb_bench", 1.93, -.01),
				_on("shelf_jars", "rack", 0, 0, 2), _floor("stool_three", -.20, -.50), _wall("broom", "N", .15)]
		"south_baker_home":
			list = _core("bed_madder", "hearth_baker", "")
			list += [_wall("kneading_trough", "W", 0.0), _wall("shelf_rack", "N", -1.10, "rack"), _on("bread_loaves", "rack", 0, 0, 0),
				_on("bread_loaves", "rack", 0, 0, 1), _on("bread_loaves", "rack", 0, 0, 2), _floor("sack_flour", -1.68, 1.86),
				_floor("sack_flour", -1.22, 1.88), _floor("basket_flour", -1.95, .85), _floor("quern", -2.25, -1.70),
				_on("basket_bread", "glb_bench", 1.93, .45), _floor("stool_three", -.20, -.50)]
		"south_weaver_home":
			list = _core("bed_madder", "hearth_cook", "")
			list += [_wall("pallet_brown", "N", -1.6), _wall("loom_warp", "W", .25, "loom"), _floor("loom_weights_pile", -1.75, 1.0),
				_floor("spinning_basket", -1.25, .92), _on("spinning_basket", "glb_bench", 1.93, .45), _floor("basket_wool", .20, -1.05),
				_wall("chest_small", "S", -1.45), _floor("stool_three", -.20, -.50), _rail_east(), _hang("hang_cloak", "rail", 1)]
		"cooper_home":
			list = _core("bed_ochre", "hearth_cook", "")
			list += [_wall("workbench_low", "W", .05, "work"), _on("carpentry_tools", "work", 0, .02, 0, 90), _floor("barrel", -2.33, -1.80),
				_floor("barrel", -1.75, -1.82), _floor("staves_bundle", -1.35, 1.80, 90.0), _floor("bucket", .95, 1.95),
				_on("bucket", "glb_bench", 1.93, .50), _floor("stool_three", -.20, -.50), _floor("stool_three", -1.10, -1.45)]
		"AtriumHouse":
			# The matron's loom stood in the atrium "ex vetere more" (Asconius on
			# 52 BC); strongbox and house shrine are atrium furniture; the stone
			# table by the impluvium is Varro's cartibulum.
			list = [_wall("loom_warp", "W", -1.0, "loom"), _floor("loom_weights_pile", -4.15, .15), _floor("spinning_basket", -4.25, -2.35),
				_floor("basket_wool", -3.75, -2.45), _floor("chair_wicker", -3.55, -.55, 90.0), _wall("arca", "E", -1.20),
				_mount("lararium", "E", .90, 1.25), _wall("armarium", "E", -2.85, "cupboard"),
				_on("bronze_vessels", "cupboard", 0, 0), _floor("cartibulum", 0, -2.78, 0.0, "stone_table"),
				_on("bronze_vessels", "stone_table", -.2, 0), _on("oil_lamp", "stone_table", .38, .05),
				_floor("candelabrum", -.95, -2.95), _floor("candelabrum", .95, -2.95), _floor("brazier", 3.0, -.4),
				_floor("table_round", 3.65, 1.25, 0.0, "round_table"), _on("table_meal", "round_table", 0, 0, 0, 30.0),
				_floor("stool_three", 3.05, 1.6), _floor("chair_wicker", 4.35, 1.05, -100.0), _floor("amphora_stand", 4.45, -4.25),
				_wall("chest_wood", "S", 4.35, "chest"), _on("cloth_bolts", "chest", 0, 0), _wall("shelf_low", "W", 3.2, "low"),
				_on("shelf_jars", "low", 0, 0, 0), _on("shelf_bowls", "low", 0, 0, 1), _on("bronze_vessels", "low", 0, 0, 2),
				_wall("bench_plain", "W", 1.4)]
		"dairy_home":
			list = _core("bed_brown", "hearth_cook", "")
			list += [_wall("cheese_press", "W", .10), _wall("shelf_rack", "N", -1.10, "rack"), _on("cheese_stack", "rack", 0, 0, 0),
				_on("cheese_stack", "rack", 0, 0, 1), _on("cheese_stack", "rack", 0, 0, 2), _floor("bucket_milk", -1.75, .95),
				_floor("bucket_milk", -1.35, 1.85), _floor("jar_coarse", -2.30, -1.80), _on("basket_bread", "glb_bench", 1.93, .45),
				_floor("stool_three", -.20, -.50), _rail_west(), _hang("hang_cloak", "rail", 1), _hang("hang_herbs", "rail", 3)]
	return list


## Places a person must be able to reach from the door (house-local x, z).
static func stations(id: String) -> Array:
	# Door, bedside, hearth, table and the west wall (shelf, loom or bench).
	var points := [DOOR, Vector2(.95, -.85), Vector2(.80, 1.20), Vector2(-.80, .25), Vector2(-1.75, .45)]
	var profession: String = HOUSEHOLDS.get(id, {}).get("profession", "")
	match profession:
		"weaver", "spinner":
			points.append(Vector2(-1.55, .45))
		"carpenter", "cooper", "smith", "cloth_trader", "leatherworker":
			points.append(Vector2(-1.65, .45))
		"scribe":
			points.append(Vector2(-1.75, .80))
		"baker":
			points.append(Vector2(-1.70, .45))
		"dairy":
			points.append(Vector2(-1.75, .45))
	return points
