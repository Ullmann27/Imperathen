extends RefCounted
## Deterministic regional coordinates and bounded streaming demand.
## This planner never creates meshes, advances the simulation or teleports anyone.

const WORLD_SIZE_M := 32000.0
const WORLD_HALF_M := WORLD_SIZE_M / 2.0
const SECTOR_SIZE_M := 250.0
const SECTORS_PER_AXIS := 128
const WORLD_SECTOR_COUNT := SECTORS_PER_AXIS * SECTORS_PER_AXIS
const SCHEMA_VERSION := 1
const PROFILES := {
	"low": {"near_radius":0, "middle_radius":1, "far_radius":3,
		"near_limit":1, "middle_limit":8, "far_limit":24, "detailed_people":16},
	"balanced": {"near_radius":1, "middle_radius":2, "far_radius":4,
		"near_limit":9, "middle_limit":16, "far_limit":32, "detailed_people":32},
	"high": {"near_radius":1, "middle_radius":3, "far_radius":5,
		"near_limit":9, "middle_limit":40, "far_limit":48, "detailed_people":48},
	"very_high": {"near_radius":2, "middle_radius":4, "far_radius":6,
		"near_limit":25, "middle_limit":56, "far_limit":64, "detailed_people":72}
}
const REGION_NAMES := [
	["Nordwestliche Höhen", "Nördliche Wälder", "Ostpässe"],
	["Westliche Felder", "Grenztal", "Steinbruchhügel"],
	["Südliche Auen", "Flusslande", "Küstenlande"]
]
const REGION_BIOMES := [
	["highland", "forest", "highland"],
	["farmland", "valley", "quarry"],
	["wetland", "river", "coast"]
]
## Place names describe the fictional playable region, not an archaeological map.
const POIS := [
	{"id":"home_village", "name":"Unser Grenzdorf", "kind":"village", "position":[0.0,0.0,0.0], "content_status":"existing_village"},
	{"id":"western_farm", "name":"Westliche Höfe", "kind":"farm", "position":[-1250.0,0.0,250.0], "content_status":"planned"},
	{"id":"forest_camp", "name":"Waldarbeiterlager", "kind":"woodcamp", "position":[-750.0,0.0,-1500.0], "content_status":"planned"},
	{"id":"stone_quarry", "name":"Alter Steinbruch", "kind":"quarry", "position":[1500.0,0.0,-750.0], "content_status":"planned"},
	{"id":"river_bridge", "name":"Flussbrücke", "kind":"bridge", "position":[750.0,0.0,1750.0], "content_status":"planned"},
	{"id":"watch_fort", "name":"Grenzwache", "kind":"fort", "position":[3000.0,0.0,-2500.0], "content_status":"planned"},
	{"id":"market_town", "name":"Marktstadt", "kind":"town", "position":[-6000.0,0.0,1500.0], "content_status":"planned"},
	{"id":"forest_settlement", "name":"Siedlung am Wald", "kind":"village", "position":[-1500.0,0.0,-8500.0], "content_status":"planned"},
	{"id":"western_pass", "name":"Westlicher Pass", "kind":"pass", "position":[-9500.0,0.0,-10000.0], "content_status":"planned"},
	{"id":"eastern_pass", "name":"Östlicher Pass", "kind":"pass", "position":[10500.0,0.0,-8500.0], "content_status":"planned"},
	{"id":"eastern_quarries", "name":"Östliche Brüche", "kind":"quarry", "position":[10000.0,0.0,500.0], "content_status":"planned"},
	{"id":"southern_ford", "name":"Südliche Furt", "kind":"ford", "position":[-8500.0,0.0,9500.0], "content_status":"planned"},
	{"id":"river_town", "name":"Flussstadt", "kind":"town", "position":[1500.0,0.0,10500.0], "content_status":"planned"},
	{"id":"coastal_port", "name":"Küstenhafen", "kind":"port", "position":[11000.0,0.0,11000.0], "content_status":"planned"}
]
const ROAD_LINKS := [
	["home_village","western_farm"], ["home_village","forest_camp"],
	["home_village","stone_quarry"], ["home_village","river_bridge"],
	["stone_quarry","watch_fort"], ["western_farm","market_town"],
	["forest_camp","forest_settlement"], ["forest_settlement","western_pass"],
	["watch_fort","eastern_pass"], ["stone_quarry","eastern_quarries"],
	["market_town","southern_ford"], ["river_bridge","river_town"],
	["river_town","coastal_port"], ["southern_ford","river_town"],
	["eastern_quarries","coastal_port"], ["western_pass","market_town"]
]


static func bounds() -> Dictionary:
	return {"schema_version":SCHEMA_VERSION, "width_m":WORLD_SIZE_M,
		"height_m":WORLD_SIZE_M, "area_km2":1024.0, "sector_size_m":SECTOR_SIZE_M,
		"sectors_per_axis":SECTORS_PER_AXIS, "sector_count":WORLD_SECTOR_COUNT,
		"minimum":[-WORLD_HALF_M,-WORLD_HALF_M], "maximum":[WORLD_HALF_M,WORLD_HALF_M],
		"content_status":"regional_plan", "historical_geography":false}


static func sector_for_position(position: Vector3) -> Vector2i:
	if not position.is_finite():
		return Vector2i(-1,-1)
	var x := clampf(position.x, -WORLD_HALF_M, WORLD_HALF_M - 0.01)
	var z := clampf(position.z, -WORLD_HALF_M, WORLD_HALF_M - 0.01)
	return Vector2i(floori((x + WORLD_HALF_M) / SECTOR_SIZE_M),
		floori((z + WORLD_HALF_M) / SECTOR_SIZE_M))


static func sector_valid(sector: Vector2i) -> bool:
	return sector.x >= 0 and sector.y >= 0 and sector.x < SECTORS_PER_AXIS and sector.y < SECTORS_PER_AXIS


static func sector_id(sector: Vector2i) -> String:
	return "%03d:%03d" % [sector.x,sector.y] if sector_valid(sector) else ""


static func sector_origin(sector: Vector2i) -> Vector3:
	if not sector_valid(sector):
		return Vector3(INF,INF,INF)
	return Vector3(-WORLD_HALF_M + sector.x * SECTOR_SIZE_M, 0.0,
		-WORLD_HALF_M + sector.y * SECTOR_SIZE_M)


static func local_coordinates(position: Vector3) -> Dictionary:
	var sector := sector_for_position(position)
	if not sector_valid(sector):
		return {"ok":false,"message":"Ungültige Weltkoordinaten."}
	var origin := sector_origin(sector)
	var clamped := Vector3(clampf(position.x,-WORLD_HALF_M,WORLD_HALF_M - 0.01),
		position.y,clampf(position.z,-WORLD_HALF_M,WORLD_HALF_M - 0.01))
	return {"ok":true,"sector":[sector.x,sector.y],"origin":[origin.x,origin.y,origin.z],
		"local":[clamped.x-origin.x,clamped.y,clamped.z-origin.z],
		"clamped":not clamped.is_equal_approx(position)}


static func region_at(position: Vector3) -> Dictionary:
	if not position.is_finite():
		return {}
	var x := 0 if position.x < -4000.0 else (2 if position.x >= 4000.0 else 1)
	var z := 0 if position.z < -4000.0 else (2 if position.z >= 4000.0 else 1)
	return {"id":"region_%d_%d" % [x,z], "name":REGION_NAMES[z][x],
		"biome":REGION_BIOMES[z][x], "historical_geography":false}


static func region_label(position: Vector3) -> String:
	return str(region_at(position).get("name","Unbekannte Region"))


## Global-coordinate height sampling keeps adjacent sector borders identical.
## The existing village remains flat within 125 m; outer terrain blends in gently.
## This is original prototype geography, not surveyed historical terrain.
static func terrain_height(position: Vector2) -> float:
	if not position.is_finite():
		return INF
	var blend := smoothstep(125.0,500.0,position.length())
	var rolling := 60.0*sin(position.x*0.0006)*cos(position.y*0.00045)
	rolling += 24.0*sin((position.x+position.y)*0.0011)
	var ridge := maxf(0.0,sin(position.x*0.00016)*cos(position.y*0.00018))
	return blend * clampf(rolling+260.0*ridge*ridge,-35.0,320.0)


static func points_of_interest() -> Array:
	return POIS.duplicate(true)


static func roads() -> Array:
	var places := {}
	for place in POIS:
		places[place.id] = place
	var result := []
	for connection in ROAD_LINKS:
		var first: Dictionary = places[connection[0]]
		var last: Dictionary = places[connection[1]]
		var start := Vector3(first.position[0],0.0,first.position[2])
		var finish := Vector3(last.position[0],0.0,last.position[2])
		result.append({"id":"%s__%s" % [first.id,last.id],"from":first.id,"to":last.id,
			"start":first.position.duplicate(),"end":last.position.duplicate(),
			"distance_m":start.distance_to(finish),"content_status":"planned"})
	return result


static func plan(position: Vector3, quality: String = "balanced") -> Dictionary:
	if not position.is_finite():
		return {"ok":false,"message":"Ungültige Weltkoordinaten.","sectors":[]}
	var profile_name := quality if PROFILES.has(quality) else "balanced"
	var profile: Dictionary = PROFILES[profile_name]
	var center := sector_for_position(position)
	var candidates: Array[Dictionary] = []
	var radius: int = profile.far_radius
	for dz in range(-radius,radius+1):
		for dx in range(-radius,radius+1):
			var sector := center + Vector2i(dx,dz)
			if not sector_valid(sector):
				continue
			var ring := maxi(absi(dx),absi(dz))
			var lod := 0 if ring <= int(profile.near_radius) else (1 if ring <= int(profile.middle_radius) else 2)
			var origin := sector_origin(sector)
			var biome: Dictionary = region_at(origin + Vector3(SECTOR_SIZE_M/2.0,0.0,SECTOR_SIZE_M/2.0))
			candidates.append({"id":sector_id(sector),"x":sector.x,"z":sector.y,
				"origin":[origin.x,origin.y,origin.z],"lod":lod,"ring":ring,
				"distance_squared":dx*dx+dz*dz,"collision":lod==0,"full_simulation":lod==0,
				"region_id":biome.id,"biome":biome.biome})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a.distance_squared != b.distance_squared:
			return a.distance_squared < b.distance_squared
		if a.z != b.z:
			return a.z < b.z
		return a.x < b.x)
	var limits := [int(profile.near_limit),int(profile.middle_limit),int(profile.far_limit)]
	var counts := [0,0,0]
	var selected := []
	for sector in candidates:
		var lod: int = sector.lod
		if counts[lod] < limits[lod]:
			selected.append(sector)
			counts[lod] += 1
	return {"ok":true,"quality":profile_name,"center":[center.x,center.y],
		"sectors":selected,"counts":counts,"limits":limits,
		"active_limit":limits[0]+limits[1]+limits[2],
		"detailed_people_limit":int(profile.detailed_people),
		"region":region_at(position),"coordinates":local_coordinates(position),
		"content_status":"streaming_demand_only"}


## Ordered create/upgrade requests and unload IDs for an external streamer.
## Stable sectors are reused; no frame creates more than the supplied budget.
static func transition(previous: Dictionary, current: Dictionary, create_budget: int = 4) -> Dictionary:
	if not current.get("ok",false):
		return {"ok":false,"create":[],"unload":[],"pending":0}
	var old := {}
	var desired := {}
	for sector in previous.get("sectors",[]):
		old[sector.id] = sector
	for sector in current.get("sectors",[]):
		desired[sector.id] = sector
	var create := []
	var pending := 0
	var budget := clampi(create_budget,0,32)
	for sector in current.get("sectors",[]):
		if not old.has(sector.id) or int(old[sector.id].lod) != int(sector.lod):
			if create.size() < budget:
				create.append(sector.duplicate(true))
			else:
				pending += 1
	var unload: Array[String] = []
	for id in old:
		if not desired.has(id):
			unload.append(str(id))
	unload.sort()
	return {"ok":true,"create":create,"unload":unload,"pending":pending}


static func overview(position: Vector3 = Vector3.ZERO, quality: String = "balanced") -> Dictionary:
	var result := plan(position,quality)
	if not result.ok:
		return result
	return {"ok":true,"title":"Regionale Welt – 32 × 32 km",
		"area_km2":1024,"region":result.region.name,"sector_count":WORLD_SECTOR_COUNT,
		"requested_sectors":result.sectors.size(),"active_limit":result.active_limit,
		"detailed_people_limit":result.detailed_people_limit,"places":points_of_interest(),
		"roads":roads(),"playable_place_ids":["home_village"],
		"status":"Gestreamte Geländegrundlage; Grenzdorf vorhanden, Fernorte und deren Bevölkerung noch geplant."}
