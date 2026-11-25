extends RefCounted
## Deterministic layout descriptors. Counts describe repeated modules, never unique buildings.
const MAX_BUILDINGS := 4096
const BLOCK_SIZE := 4
const ROAD_WIDTH := 8.0


static func generate(config: Dictionary, building_assets: Array, vegetation_assets: Array, road_assets: Array = []) -> Dictionary:
	var count := int(config.get("count", 0))
	if count < 1 or count > MAX_BUILDINGS:
		return {"ok": false, "message": "Gebäudezahl liegt außerhalb 1–4096."}
	var structures: Array[Dictionary] = []
	var roads: Array[Dictionary] = []
	for road: Dictionary in road_assets:
		roads.append(road)
	var largest_footprint := 0.0
	var allowed: Array = config.get("allowed_building_ids", [])
	for value in building_assets:
		if not value is Dictionary:
			continue
		var asset: Dictionary = value
		if str(asset.get("category", "")) == "road":
			roads.append(asset)
			continue
		if not allowed.is_empty() and not allowed.has(str(asset.get("id", ""))):
			continue
		var footprint: Array = asset.get("footprint", [])
		if footprint.size() != 2 or float(footprint[0]) <= 0.0 or float(footprint[1]) <= 0.0:
			return {"ok": false, "message": "Gebäudemaße fehlen: " + str(asset.get("id", ""))}
		largest_footprint = maxf(largest_footprint, maxf(float(footprint[0]), float(footprint[1])))
		structures.append(asset)
	if structures.is_empty():
		return {"ok": false, "message": "Keine Gebäudemodule im Manifest."}
	var spacing := maxf(float(config.get("spacing", 22.0)), largest_footprint + 2.0)
	if not is_finite(spacing) or spacing > 100.0:
		return {"ok": false, "message": "Ungültiger Gebäudeabstand."}
	spacing = ceilf(spacing / 2.0) * 2.0
	var columns := ceili(sqrt(float(count)))
	var rows := ceili(float(count) / float(columns))
	var extent := Vector2(_axis(columns - 1, spacing) + spacing, _axis(rows - 1, spacing) + spacing)
	var offset := Vector2(_axis(columns - 1, spacing), _axis(rows - 1, spacing)) * 0.5
	var random := RandomNumberGenerator.new()
	random.seed = int(config.get("seed", 20261125))
	var buildings: Array[Dictionary] = []
	var occupied := {}
	var ordinary: Array[Dictionary] = []
	var civic: Array[Dictionary] = []
	for asset in structures:
		if str(asset.get("category", "")) == "civic":
			civic.append(asset)
		else:
			ordinary.append(asset)
	if ordinary.is_empty():
		ordinary = structures
	for index in count:
		var column := index % columns
		var row := index / columns
		var asset: Dictionary = civic[(index / 256) % civic.size()] if not civic.is_empty() and index % 256 == 0 else ordinary[random.randi_range(0, ordinary.size() - 1)]
		var at := Vector3(_axis(column, spacing) - offset.x, 0.0, _axis(row, spacing) - offset.y)
		var yaw := PI if (row / BLOCK_SIZE) % 2 == 0 else 0.0
		var entry := {"id": "building_%05d" % index, "asset": str(asset.id), "position": at, "yaw": yaw, "scale": 1.0, "footprint": asset.footprint}
		buildings.append(entry)
		var cell := Vector2i(floori(at.x / spacing), floori(at.z / spacing))
		if not occupied.has(cell):
			occupied[cell] = []
		occupied[cell].append(entry)
	var road_sites: Array[Dictionary] = []
	if not roads.is_empty():
		var road_id := str(roads[0].id)
		var road_x: Array[float] = []
		var road_z: Array[float] = []
		for column in range(BLOCK_SIZE, columns, BLOCK_SIZE):
			road_x.append((_axis(column - 1, spacing) + _axis(column, spacing)) * 0.5 - offset.x)
		for row in range(BLOCK_SIZE, rows, BLOCK_SIZE):
			road_z.append((_axis(row - 1, spacing) + _axis(row, spacing)) * 0.5 - offset.y)
		var west := -extent.x * 0.5 - ROAD_WIDTH * 0.5
		var south := -extent.y * 0.5 - ROAD_WIDTH * 0.5
		var columns_of_road := ceili((extent.x + ROAD_WIDTH) / ROAD_WIDTH)
		var rows_of_road := ceili((extent.y + ROAD_WIDTH) / ROAD_WIDTH)
		road_x.append(west)
		road_x.append(west + columns_of_road * ROAD_WIDTH)
		road_z.append(south)
		road_z.append(south + rows_of_road * ROAD_WIDTH)
		var seen := {}
		for x in road_x:
			for step in range(rows_of_road + 1):
				var z := south + step * ROAD_WIDTH
				_append_road(road_sites, seen, road_id, Vector3(x, -0.02, z))
		for z in road_z:
			for step in range(columns_of_road + 1):
				var x := west + step * ROAD_WIDTH
				_append_road(road_sites, seen, road_id, Vector3(x, -0.02, z))
	var plants: Array[Dictionary] = []
	if not vegetation_assets.is_empty():
		var plant_limit := mini(count * 2 + 12, 1600)
		for index in road_sites.size():
			if plants.size() >= plant_limit:
				break
			var site: Dictionary = road_sites[index]
			var at: Vector3 = site.position + Vector3(ROAD_WIDTH * 0.5 + 1.5, 0.02, ROAD_WIDTH * 0.5 + 1.5)
			if _inside_building(at, spacing, occupied):
				continue
			var asset: Dictionary = vegetation_assets[index % vegetation_assets.size()]
			plants.append({"id": "plant_%05d" % plants.size(), "asset": str(asset.id), "position": at,
				"yaw": random.randf_range(0.0, TAU), "scale": random.randf_range(0.86, 1.12)})
		# Trees on the settlement boundary are separate placements, not buildings.
		var border_count := mini(48, plant_limit - plants.size())
		for index in border_count:
			var angle := TAU * float(index) / float(border_count)
			var at := Vector3(cos(angle) * (extent.x * 0.5 + 20.0), 0, sin(angle) * (extent.y * 0.5 + 20.0))
			if _inside_building(at, spacing, occupied):
				continue
			var asset: Dictionary = vegetation_assets[index % vegetation_assets.size()]
			plants.append({"id": "plant_%05d" % plants.size(), "asset": str(asset.id), "position": at,
				"yaw": random.randf_range(0.0, TAU), "scale": random.randf_range(0.90, 1.10)})
	return {"ok": true, "id": str(config.get("id", "")), "label": str(config.get("label", "")),
		"buildings": buildings, "roads": road_sites, "vegetation": plants,
		"extent": extent, "spacing": spacing, "seed": random.seed,
		"building_count": buildings.size(), "unique_building_modules": structures.size(),
		"content_kind": "deterministic_repeated_asset_layout"}


static func _axis(index: int, spacing: float) -> float:
	return float(index) * spacing + floorf(float(index) / BLOCK_SIZE) * ROAD_WIDTH


static func _append_road(sites: Array[Dictionary], seen: Dictionary, asset: String, at: Vector3) -> void:
	var key := "%d:%d" % [roundi(at.x * 100.0), roundi(at.z * 100.0)]
	if seen.has(key):
		return
	seen[key] = true
	sites.append({"id": "road_%05d" % sites.size(), "asset": asset, "position": at, "yaw": 0.0, "scale": 1.0})


static func _inside_building(at: Vector3, spacing: float, occupied: Dictionary) -> bool:
	var center := Vector2i(floori(at.x / spacing), floori(at.z / spacing))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for entry: Dictionary in occupied.get(center + Vector2i(dx, dz), []):
				var half_size := Vector2(float(entry.footprint[0]), float(entry.footprint[1])) * 0.5 + Vector2.ONE * 0.7
				var position: Vector3 = entry.position
				if absf(position.x - at.x) <= half_size.x and absf(position.z - at.z) <= half_size.y:
					return true
	return false
