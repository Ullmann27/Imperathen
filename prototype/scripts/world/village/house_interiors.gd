extends Node3D
## Furnished Valdora households built from the interior kit. Presentation and
## physical obstacles only: no ledger, story, economy or save side effects.
##
## Each house gets one "Interior" node: two merged meshes (furniture and
## clutter, one surface per material, so a room costs about one draw call per
## material), one mesh each for flames, standing water and grime (soot, ash,
## trodden dirt), one static body with the gameplay colliders (identical in
## every quality profile) and an OmniLight3D per hearth, lamp and candle. Only
## the lights of the room nearest the camera are shown. The smithy and the
## market are furnished the same way as open sites. `manifest` keeps every
## placement for tests.

const Layout = preload("res://scripts/world/village/village_layout.gd")
const Kit = preload("res://scripts/world/village/interior_kit.gd")
const Designs = preload("res://scripts/world/village/household_designs.gd")
const Family = preload("res://scripts/world/village/architecture/valdora_house_family.gd")
# Visibility end in metres for [furniture, clutter] per quality profile.
const RANGES := {"low": [10.0, 5.0], "balanced": [14.0, 7.0], "high": [24.0, 12.0], "very_high": [30.0, 16.0]}
const LIGHT_RADIUS := {"low": 0.0, "balanced": 9.0, "high": 11.0, "very_high": 13.0}
# Real lights shown in the nearest room: its hearth first, then lamps and candles.
const LIGHT_COUNT := {"low": 0, "balanced": 2, "high": 3, "very_high": 4}
const FLAME_SHADER := preload("res://shaders/interior_flame.gdshader")
const GRIME_SIZE := 128
# Stations of the smithy that the apprenticeship steps use, by work id.
const FORGE_WORK := {"forge_bellows": 1.7, "forge_anvil": 1.25, "forge_quench": .8}
const WALL_YAW := {"N": 0.0, "W": 90.0, "E": -90.0, "S": 180.0}
const PEG_HOOK := Vector3(0.0, .078, .11)
const PEG_X := [-.35, -.1167, .1167, .35]
const FIRE_COLOR := Color(1.0, .58, .30)
# Visual layer 12: house shells and their furnishings. Hearth lights only
# affect this layer, so an unshadowed fire inside does not light the street
# or neighbouring houses through the wall.
const FIRE_LAYER := 1 << 11

var manifest: Dictionary = {}
var errors: Array[String] = []
var build_usec := 0
var _profile := "balanced"
var _layers: Array[GeometryInstance3D] = []
var _fires: Array[OmniLight3D] = []
var _active: Array[OmniLight3D] = []
var _clock := 0.0
var _flame_material: ShaderMaterial
var _water_material: StandardMaterial3D
var _grime_material: StandardMaterial3D
var _forge_vigor := 1.0
var _forge_flames: MeshInstance3D
var _forge_shell: Node3D


static func furnishes(id: String) -> bool:
	return Designs.HOUSEHOLDS.has(id) and id not in Designs.EXCLUDED


## `houses` holds the house instances by household id; `dressing` is the
## settlement dressing whose generic household set each designed room replaces.
func build(houses: Node3D, dressing: Node = null) -> void:
	var started := Time.get_ticks_usec()
	Kit.ensure()
	for home: Dictionary in Layout.HOMES:
		if not furnishes(home.id):
			continue
		var house := houses.get_node_or_null(NodePath(home.id)) as Node3D
		if house == null:
			errors.append("Missing house " + home.id)
			continue
		if dressing and dressing.has_method("release_household"):
			dressing.release_household(home.id)
		_furnish(house, home.id)
	var atrium := houses.get_node_or_null(NodePath(Designs.ATRIUM)) as Node3D
	if atrium and furnishes(Designs.ATRIUM):
		_furnish(atrium, Designs.ATRIUM)
	for site: String in Designs.SITES:
		if Designs.items(site).is_empty():
			continue
		var title: String = Designs.SITES[site].node
		var place: Node3D = dressing.release_site(title) if dressing and dressing.has_method("release_site") else null
		if place == null:
			place = Node3D.new()
			place.name = title
			place.position = Designs.SITES[site].at
			place.rotation.y = Designs.SITES[site].yaw
			houses.add_child(place)
		var room := _furnish(place, site)
		if site == Designs.FORGE:
			_forge_flames = room.get_node_or_null("Flames") as MeshInstance3D
			# The story and tests address the stations by these names.
			for pair: Array in [["Hearth", "forge_hearth"], ["Bellows", "forge_bellows"], ["Anvil", "anvil_block"],
					["ToolRack", "tool_rack_smith"], ["QuenchTrough", "quench_trough"]]:
				for record: Dictionary in manifest[site]:
					if record.prop == pair[1]:
						var marker := Marker3D.new()
						marker.name = pair[0]
						marker.transform = record.transform
						place.add_child(marker)
	Kit.release_meshes()
	build_usec = Time.get_ticks_usec() - started
	set_quality(_profile)


func _furnish(house: Node3D, id: String) -> Node3D:
	var frame := Designs.shell(id)
	var site := Designs.is_site(id)
	var room := Node3D.new()
	room.name = "Interior"
	room.position = Vector3(0, float(frame.floor), 0)
	room.set_meta("household_id", id)
	room.set_meta("household", Designs.SITES[id].label if site else Designs.HOUSEHOLDS[id].household)
	house.add_child(room)
	var placed := resolve(Designs.items(id), id)
	manifest[id] = placed
	# Every visible part of the house shell receives the fires inside it,
	# whatever the shell is called (frontier house or a later house family).
	if not site:
		for shell: MeshInstance3D in house.find_children("*", "MeshInstance3D", true, false):
			if not room.is_ancestor_of(shell):
				shell.layers |= FIRE_LAYER
	if id == Designs.FORGE:
		_forge_shell = Family.instantiate_forge_shell(_profile)
		if is_instance_valid(_forge_shell):
			room.add_child(_forge_shell)
			_fit_forge_fixtures(_forge_shell, placed)
	# Keep the interior kit's four aligned post colliders, but do not render
	# its redundant roof when the authored shell is actually instantiated.
	_merge(room, placed)
	_collide(room, placed)
	_add_flames(room, placed, not site)
	_add_water(room, placed)
	_add_grime(room, placed, id, frame)
	return room


## Flame geometry and one light per burning prop (hearth, lamp, candle).
func _add_flames(room: Node3D, placed: Array, confined: bool) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for index in placed.size():
		var record: Dictionary = placed[index]
		var pose: Transform3D = record.transform
		var lamp: bool = record.prop in ["oil_lamp", "candle_dish", "candelabrum"]
		var flames: Array = Kit.FLAMES.get(record.prop, [])
		for k in flames.size():
			var flame: Array = flames[k]
			_flame(tool, pose * (flame[0] as Vector3), float(flame[1]), float(index * 7 + k * 3))
			count += 1
			if float(flame[2]) > 0.0:
				var at: Vector3 = pose * (flame[0] as Vector3)
				if lamp:
					_add_fire(room, at + Vector3(0, float(flame[1]) + .05, 0), float(flame[2]), confined, 2.7)
				else:
					# Above the fire and a little towards the room, so the glow
					# reaches walls and furniture instead of blowing out the ash bed.
					var inward := Vector3(-pose.origin.x, 0, -pose.origin.z).limit_length(.28)
					_add_fire(room, pose.origin + inward + Vector3(0, (flame[0] as Vector3).y + .52, 0), float(flame[2]), confined, 4.6)
		if Kit.GLOWS.has(record.prop):
			var glow: Array = Kit.GLOWS[record.prop]
			var towards := Vector3(-pose.origin.x, 0, -pose.origin.z).limit_length(.28)
			_add_fire(room, pose * (glow[0] as Vector3) + towards, float(glow[1]), confined, 4.6)
	if count == 0:
		return
	if _flame_material == null:
		_flame_material = ShaderMaterial.new()
		_flame_material.shader = FLAME_SHADER
	var node := MeshInstance3D.new()
	node.name = "Flames"
	node.mesh = tool.commit()
	node.material_override = _flame_material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = .3
	node.set_meta("tier", "flame")
	node.set_meta("flames", count)
	room.add_child(node)
	_layers.append(node)


func _flame(tool: SurfaceTool, at: Vector3, height: float, phase: float) -> void:
	var sides := 6
	var rings := 6
	var wide := height * (.30 if height < .08 else .22)
	var rows: Array = []
	for j in rings + 1:
		var h := float(j) / rings
		var radius := wide * sin(PI * pow(h, .62)) * .5 + (.0 if j in [0, rings] else wide * .06)
		var row: Array = []
		for i in sides:
			var angle := TAU * i / sides
			row.append([at + Vector3(cos(angle) * radius, h * height, sin(angle) * radius), Vector3(cos(angle), .25, sin(angle)).normalized(),
				Vector2(float(i) / sides, h)])
		rows.append(row)
	for j in rings:
		for i in sides:
			var next := (i + 1) % sides
			for corner: Array in [rows[j][i], rows[j + 1][i], rows[j + 1][next], rows[j][i], rows[j + 1][next], rows[j][next]]:
				tool.set_normal(corner[1])
				tool.set_uv(corner[2])
				tool.set_uv2(Vector2(phase, height))
				tool.add_vertex(corner[0])


func _add_water(room: Node3D, placed: Array) -> void:
	var tool: SurfaceTool = null
	for record: Dictionary in placed:
		if not Kit.WATER.has(record.prop):
			continue
		if tool == null:
			tool = SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var surface: Array = Kit.WATER[record.prop]
		var half := (surface[1] as Vector2) * .5
		var centre: Vector3 = surface[0]
		var corners := [Vector3(-half.x, 0, -half.y), Vector3(half.x, 0, -half.y), Vector3(half.x, 0, half.y), Vector3(-half.x, 0, half.y)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			tool.set_normal((record.transform as Transform3D).basis * Vector3.UP)
			tool.set_uv(Vector2(corners[k].x, corners[k].z))
			tool.add_vertex((record.transform as Transform3D) * (centre + corners[k]))
	if tool == null:
		return
	if _water_material == null:
		_water_material = StandardMaterial3D.new()
		_water_material.resource_name = "Interior_water"
		_water_material.albedo_color = Color(.045, .065, .062)
		_water_material.roughness = .07
		_water_material.metallic_specular = .7
	var node := MeshInstance3D.new()
	node.name = "Water"
	node.mesh = tool.commit()
	node.material_override = _water_material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.layers |= FIRE_LAYER
	node.set_meta("tier", "furniture")
	room.add_child(node)
	_layers.append(node)


## Soot above and beside every hearth, ash and charcoal crumbs around it,
## trodden dirt inside the door: alpha patches a few millimetres off the
## plaster and the paving (the Compatibility renderer has no decals). The
## amount follows the household's wealth.
func _add_grime(room: Node3D, placed: Array, id: String, frame: Dictionary) -> void:
	var amount := Designs.grime(id)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var limits: Dictionary = frame.stand
	var area := Rect2(limits.W, limits.N, limits.E - limits.W, limits.S - limits.N)
	var soot := Color(.035, .03, .028)
	var site := Designs.is_site(id)
	for record: Dictionary in placed:
		var prop: String = record.prop
		var at: Vector3 = (record.transform as Transform3D).origin
		if prop.begins_with("hearth_") or prop == "forge_hearth":
			_floor_patch(tool, at, Vector2(1.05, 1.05), 0, Color(.34, .32, .30, .62 * amount), area)
			_floor_patch(tool, at + Vector3(.1, 0, -.05), Vector2(.95, .95), 2, Color(.05, .045, .04, .85 * amount), area)
			if site:
				continue
			for side: String in ["W", "E", "N", "S"]:
				var plane: float = frame.wall[side]
				var distance := absf((at.x if side in ["W", "E"] else at.z) - plane)
				if distance > 1.35:
					continue
				var along := at.z if side in ["W", "E"] else at.x
				var strength := amount * (1.0 - distance / 1.9)
				var holes: Array = frame.get("openings", {}).get(side, [])
				_wall_patch(tool, frame, side, along, 2.25, Vector2(1.15, 1.0), 0, Color(soot, .62 * strength), holes)
				_wall_patch(tool, frame, side, along, 1.0, Vector2(.75, 1.05), 1, Color(soot, .40 * strength), holes)
		elif prop == "anvil_block":
			_floor_patch(tool, at, Vector2(.9, .9), 2, Color(.07, .065, .06, .8), area)
			_floor_patch(tool, at, Vector2(.75, .75), 0, Color(.12, .11, .10, .45), area)
		elif prop.begins_with("stall_"):
			# Earth trodden bare where customers stand.
			_floor_patch(tool, at + (record.transform as Transform3D).basis.z * 1.0, Vector2(1.2, .8), 0, Color(.23, .18, .12, .55), area)
			_floor_patch(tool, at + (record.transform as Transform3D).basis.z * .9, Vector2(1.0, .7), 2, Color(.16, .13, .09, .6), area)
		elif prop == "basket_charcoal":
			_floor_patch(tool, at, Vector2(.5, .5), 2, Color(.03, .03, .03, .8 * amount), area)
		elif prop == "brazier":
			_floor_patch(tool, at, Vector2(.6, .6), 2, Color(.2, .19, .18, .5 * amount), area)
		elif prop in ["quern", "kneading_trough", "sack_flour"]:
			_floor_patch(tool, at, Vector2(.62, .62), 2, Color(.86, .83, .76, .55), area)
		elif prop.begins_with("loom_w") or prop == "loom_madder":
			_floor_patch(tool, at + (record.transform as Transform3D).basis.z * .35, Vector2(.7, .45), 2, Color(.62, .56, .46, .5), area)
		elif prop.begins_with("bed_") or prop.begins_with("pallet_"):
			# Straw that worked out of the mattress.
			_floor_patch(tool, at + (record.transform as Transform3D).basis.z * .55, Vector2(.8, .3), 2, Color(.62, .52, .30, .55 * amount), area)
	if not site:
		var door: Vector2 = frame.door
		var inward := Vector3(-door.x, 0, -door.y).normalized()
		var entry := Vector3(door.x, 0, door.y)
		_floor_patch(tool, entry + inward * .25, Vector2(.62, .78), 3, Color(.20, .15, .10, .60 * amount), area)
		_floor_patch(tool, entry + inward * 1.05, Vector2(.55, .9), 3, Color(.22, .17, .12, .32 * amount), area)
		_floor_patch(tool, entry + inward * .5, Vector2(.7, .7), 2, Color(.30, .24, .15, .45 * amount), area)
	var mesh := tool.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	if _grime_material == null:
		_grime_material = StandardMaterial3D.new()
		_grime_material.resource_name = "Interior_grime"
		_grime_material.albedo_texture = _grime_texture()
		_grime_material.vertex_color_use_as_albedo = true
		_grime_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_grime_material.roughness = 1.0
		_grime_material.metallic_specular = 0.0
		_grime_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_grime_material.render_priority = 1
	var node := MeshInstance3D.new()
	node.name = "Grime"
	node.mesh = mesh
	node.material_override = _grime_material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.layers |= FIRE_LAYER
	node.set_meta("tier", "furniture")
	room.add_child(node)
	_layers.append(node)


## Four soft shapes in one texture: 0 cloud, 1 rising plume, 2 crumbs, 3 smear.
func _grime_texture() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 58
	noise.frequency = .035
	noise.fractal_octaves = 3
	var size := GRIME_SIZE
	var image := Image.create(size * 2, size * 2, true, Image.FORMAT_RGBA8)
	for variant in 4:
		var corner := Vector2i(variant % 2, variant / 2) * size
		for y in size:
			for x in size:
				var p := Vector2((x + .5) / size * 2.0 - 1.0, (y + .5) / size * 2.0 - 1.0)
				var n := noise.get_noise_2d(x + variant * 211, y + variant * 97) * .5 + .5
				var fine := noise.get_noise_2d(x * 5.0 + 31, y * 5.0 + variant * 17) * .5 + .5
				var alpha := 0.0
				match variant:
					0:
						alpha = pow(clampf(1.0 - p.length(), 0, 1), 1.3) * (.45 + .85 * n)
					1:
						# Image y grows downwards: the plume is widest at the bottom.
						var up := (1.0 - p.y) * .5
						var width := lerpf(.85, .32, up)
						alpha = clampf(1.0 - absf(p.x + (n - .5) * .5 * up) / width, 0, 1) * pow(clampf(1.0 - up, 0, 1), .8) \
							* clampf(up * 9.0, 0, 1) * (.5 + .7 * n)
					2:
						alpha = smoothstep(.60, .70, fine) * pow(clampf(1.0 - p.length(), 0, 1), .8) * (.6 + .4 * n)
					3:
						var q := Vector2(p.x * 1.25, p.y)
						alpha = pow(clampf(1.0 - q.length(), 0, 1), 1.1) * (.35 + .9 * noise.get_noise_2d(x * 2.5, y * .6 + 400) * .5 + .45)
				var edge := minf(minf(x, size - 1 - x), minf(y, size - 1 - y)) / 6.0
				image.set_pixel(corner.x + x, corner.y + y, Color(1, 1, 1, clampf(alpha, 0, 1) * clampf(edge, 0, 1)))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _patch_uv(variant: int, u: float, v: float) -> Vector2:
	return (Vector2(variant % 2, variant / 2) + Vector2(u, v)) * .5


## Horizontal patch on the paving, clipped to the room.
func _floor_patch(tool: SurfaceTool, centre: Vector3, half: Vector2, variant: int, tint: Color, area: Rect2) -> void:
	if tint.a <= .02:
		return
	var steps := 4
	var height := .004 + .0012 * variant
	for i in steps:
		for j in steps:
			var corners := []
			var inside := true
			for offset: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var u := (i + offset.x) / steps
				var v := (j + offset.y) / steps
				var point := Vector3(centre.x + (u * 2.0 - 1.0) * half.x, height, centre.z + (v * 2.0 - 1.0) * half.y)
				inside = inside and area.has_point(Vector2(point.x, point.z))
				corners.append([point, _patch_uv(variant, u, v)])
			if not inside:
				continue
			# Counter-clockwise seen from above (Godot front faces are clockwise).
			for k: int in [0, 1, 2, 0, 2, 3]:
				tool.set_normal(Vector3.UP)
				tool.set_color(tint)
				tool.set_uv(corners[k][1])
				tool.add_vertex(corners[k][0])


## Vertical patch on the plaster of one wall; cells over a door or window
## opening (Rect2 in metres along the wall and above the floor) are left out.
func _wall_patch(tool: SurfaceTool, frame: Dictionary, side: String, along: float, height: float, half: Vector2, variant: int,
		tint: Color, holes: Array) -> void:
	if tint.a <= .02:
		return
	var plane: float = frame.wall[side]
	var inward := -signf(plane)
	var top: float = frame.get("wall_top", 2.8)
	var horizontal: bool = side in ["N", "S"]
	var low: float = (frame.wall.W if horizontal else frame.wall.N) + .03
	var high: float = (frame.wall.E if horizontal else frame.wall.S) - .03
	var steps := 8
	for i in steps:
		for j in steps:
			var corners := []
			var keep := true
			var cell := Rect2()
			for offset: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var u := (i + offset.x) / steps
				var v := (j + offset.y) / steps
				var a := along + (u * 2.0 - 1.0) * half.x
				var y := height + (1.0 - v * 2.0) * half.y
				keep = keep and a >= low and a <= high and y >= .02 and y <= top
				cell = Rect2(a, y, 0, 0) if corners.is_empty() else cell.expand(Vector2(a, y))
				var point := Vector3(a, y, plane + inward * .004) if horizontal else Vector3(plane + inward * .004, y, a)
				corners.append([point, _patch_uv(variant, u, v)])
			for hole: Rect2 in holes:
				keep = keep and not hole.grow(.07).intersects(cell)
			if not keep:
				continue
			var normal := Vector3(0, 0, inward) if horizontal else Vector3(inward, 0, 0)
			# Wind the two triangles so the front faces the room.
			var edge_a: Vector3 = corners[1][0] - corners[0][0]
			var edge_b: Vector3 = corners[2][0] - corners[0][0]
			var order: Array = [0, 1, 2, 0, 2, 3] if edge_a.cross(edge_b).dot(normal) < 0.0 else [0, 2, 1, 0, 3, 2]
			for k: int in order:
				tool.set_normal(normal)
				tool.set_color(tint)
				tool.set_uv(corners[k][1])
				tool.add_vertex(corners[k][0])


## Turns design entries into house-local transforms (y = 0 is the paving).
func resolve(items: Array, house_id := "") -> Array:
	var placed: Array = []
	var by_id := {}
	var frame := Designs.shell(house_id)
	for item: Dictionary in items:
		var prop: String = item.prop
		if not Kit.info.has(prop) or not Kit.meshes.has(prop):
			errors.append("%s: unknown kit prop %s" % [house_id, prop])
			continue
		var yaw := deg_to_rad(float(item.get("yaw", 0.0)))
		var pose := Transform3D.IDENTITY
		var support: String = item.on
		var top := 0.0
		if item.has("wall"):
			var side: String = item.wall
			var basis := Basis(Vector3.UP, deg_to_rad(WALL_YAW[side]) + yaw)
			var bounds := Transform3D(basis, Vector3.ZERO) * Kit.aabb(prop)
			var leaning := prop in Kit.LEANING
			var mounted := support == "wall"
			# Standing furniture keeps its feet on the paving; leaning and hung
			# props touch the plaster itself.
			var plane: float = frame.wall[side] if leaning or mounted else frame.stand[side]
			if leaning or mounted:
				plane -= signf(plane) * .002
			var origin := Vector3.ZERO
			match side:
				"W": origin = Vector3(plane - bounds.position.x, 0, item.along)
				"E": origin = Vector3(plane - bounds.end.x, 0, item.along)
				"N": origin = Vector3(item.along, 0, plane - bounds.position.z)
				"S": origin = Vector3(item.along, 0, plane - bounds.end.z)
			if mounted:
				origin.y = float(item.height)
			pose = Transform3D(basis, origin)
		elif support == "floor":
			pose = Transform3D(Basis(Vector3.UP, yaw), Vector3(item.at.x, 0, item.at.y))
		elif support == "peg":
			var rail: Dictionary = by_id.get(item.rail, {})
			if rail.is_empty():
				errors.append("%s: %s hangs on missing rail %s" % [house_id, prop, item.rail])
				continue
			pose = (rail.transform as Transform3D) * Transform3D(Basis.IDENTITY, PEG_HOOK + Vector3(PEG_X[int(item.peg)], 0, 0))
		else:
			var base := Transform3D.IDENTITY
			var level := int(item.get("level", 0))
			if support == "glb_table":
				top = Designs.GLB_TABLE.top
			elif support == "glb_bench":
				top = Designs.GLB_BENCH.top
			elif by_id.has(support):
				base = by_id[support].transform
				var tops: Array = Kit.TOPS.get(by_id[support].prop, [])
				if level >= tops.size():
					errors.append("%s: %s has no surface %d for %s" % [house_id, by_id[support].prop, level, prop])
					continue
				top = tops[level]
			else:
				errors.append("%s: %s rests on missing support %s" % [house_id, prop, support])
				continue
			pose = base * Transform3D(Basis(Vector3.UP, yaw), Vector3(item.at.x, top, item.at.y))
		var record := {"id": item.get("id", ""), "prop": prop, "on": support, "transform": pose, "rail": item.get("rail", ""),
			"level": int(item.get("level", 0)), "wall": item.get("wall", ""),
			"tier": "detail" if Kit.is_detail(prop) or support not in ["floor", "wall"] else "furniture",
			"leaning": prop in Kit.LEANING, "mounted": support == "wall", "hanging": Kit.hanging(prop),
			"collides": support in ["floor", "wall"] and not Kit.collision(prop).is_empty()}
		placed.append(record)
		if record.id != "":
			by_id[record.id] = record
	return placed


## The original GLB has baked-in legacy station coordinates. Fit the mesh to
## the current design's room-local envelope, not the other way around. Keep
## the gameplay transforms, colliders and markers identical. If the asset
## is missing, malformed or would require excessive compression, retain the
## existing kit visual; never suppress it on an unsuccessful import.
func _fit_forge_fixtures(model: Node3D, placed: Array) -> void:
	for record: Dictionary in placed:
		var prop: String = record.prop
		if not Family.FORGE_FIXTURES.has(prop):
			continue
		var fixture_name: String = Family.FORGE_FIXTURES[prop]
		var mesh := model.find_child(fixture_name, true, false) as MeshInstance3D
		if mesh == null or mesh.mesh == null or mesh.get_parent() != model:
			continue
		var old_pose := model.transform * mesh.transform
		var source: AABB = old_pose * mesh.mesh.get_aabb()
		var target: AABB = (record.transform as Transform3D) * Kit.aabb(prop)
		if not source.size.is_finite() or not target.size.is_finite() or minf(source.size.x, minf(source.size.y, source.size.z)) <= .001:
			continue
		var scale_fit := target.size / source.size
		if minf(scale_fit.x, minf(scale_fit.y, scale_fit.z)) < .65:
			continue
		# A narrow tool board must not become an unnaturally thick slab.
		scale_fit = Vector3(minf(scale_fit.x, 1.2), minf(scale_fit.y, 1.2), minf(scale_fit.z, 1.2))
		var offset := target.get_center() - source.get_center() * scale_fit
		offset.y = target.position.y - source.position.y * scale_fit.y
		var fitted := Transform3D(Basis.from_scale(scale_fit), offset) * old_pose
		var actual: AABB = fitted * mesh.mesh.get_aabb()
		if not target.grow(.002).encloses(actual):
			continue
		mesh.transform = model.transform.affine_inverse() * fitted
		mesh.visible = true
		mesh.set_meta("forge_work_prop", prop)
		record["authored_visual"] = fixture_name


func _merge(room: Node3D, placed: Array) -> void:
	for tier: String in ["furniture", "detail"]:
		var tools := {}
		for record: Dictionary in placed:
			if record.tier != tier:
				continue
			if record.prop == "forge_shelter" and room.has_node("AuthoredForgeShell"):
				continue
			if record.has("authored_visual"):
				continue
			var mesh: Mesh = Kit.meshes[record.prop]
			for surface in mesh.get_surface_count():
				var key := Kit.material_for(mesh.surface_get_material(surface)).resource_name
				if not tools.has(key):
					var tool := SurfaceTool.new()
					tool.begin(Mesh.PRIMITIVE_TRIANGLES)
					tools[key] = tool
				(tools[key] as SurfaceTool).append_from(mesh, surface, record.transform)
		if tools.is_empty():
			continue
		var merged := ArrayMesh.new()
		var keys := tools.keys()
		keys.sort()
		for key: String in keys:
			(tools[key] as SurfaceTool).commit(merged)
			merged.surface_set_material(merged.get_surface_count() - 1, Kit.materials[key.trim_prefix("Interior_")])
		var node := MeshInstance3D.new()
		node.name = "Furniture" if tier == "furniture" else "Clutter"
		node.mesh = merged
		node.set_meta("tier", tier)
		node.layers |= FIRE_LAYER
		room.add_child(node)
		_layers.append(node)


func _collide(room: Node3D, placed: Array) -> void:
	var body := StaticBody3D.new()
	body.name = "InteriorCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	room.add_child(body)
	for record: Dictionary in placed:
		if not record.collides:
			continue
		for part: Dictionary in Kit.collision(record.prop):
			var shape := CollisionShape3D.new()
			shape.name = "%s_%d" % [record.prop, body.get_child_count()]
			shape.shape = part.shape
			shape.transform = (record.transform as Transform3D) * Transform3D(Basis.IDENTITY, part.offset)
			body.add_child(shape)


func _add_fire(parent: Node3D, at: Vector3, strength: float, confined := true, reach := 4.6) -> void:
	var light := OmniLight3D.new()
	light.name = "HearthGlow" if reach > 3.0 else "LampGlow"
	light.position = at
	light.light_color = FIRE_COLOR if reach > 3.0 else Color(1.0, .68, .38)
	light.omni_range = reach
	light.omni_attenuation = 1.35
	light.light_specular = .25
	light.shadow_enabled = false
	if confined:
		light.light_cull_mask = FIRE_LAYER
	light.set_meta("strength", strength)
	light.set_meta("kind", "fire" if reach > 3.0 else "lamp")
	light.visible = false
	parent.add_child(light)
	_fires.append(light)


## Bellows work makes the forge fire flare; the story state calls this with
## the active work id of the apprenticeship ("" when nobody works).
func set_forge_work(work: String) -> void:
	_forge_vigor = float(FORGE_WORK.get(work, 1.0))
	if is_instance_valid(_forge_flames):
		_forge_flames.set_instance_shader_parameter("vigor", _forge_vigor)


func set_quality(profile: String) -> void:
	_profile = profile if RANGES.has(profile) else "balanced"
	Kit.set_profile(_profile)
	if is_instance_valid(_forge_shell):
		Family.apply_quality(_forge_shell, _profile)
	var ranges: Array = RANGES[_profile]
	for layer: GeometryInstance3D in _layers:
		var tier: String = layer.get_meta("tier")
		layer.visibility_range_end = ranges[1] if tier == "detail" else ranges[0]
		layer.visibility_range_end_margin = 2.0
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if tier == "furniture" and layer.name == "Furniture" \
			and _profile in ["high", "very_high"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for light: OmniLight3D in _fires:
		light.visible = false
	_active.clear()


func _process(delta: float) -> void:
	_clock += delta
	var radius: float = LIGHT_RADIUS[_profile]
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null or radius <= 0.0 or not is_visible_in_tree():
		for light: OmniLight3D in _active:
			light.visible = false
		_active.clear()
		return
	# Only the room nearest the camera is lit by real lights (each one costs
	# shading time on a phone); embers and flames glow everywhere.
	var nearest: OmniLight3D = null
	var best := radius * radius
	for light: OmniLight3D in _fires:
		var distance := light.global_position.distance_squared_to(camera.global_position)
		if distance < best:
			best = distance
			nearest = light
	var chosen: Array[OmniLight3D] = []
	if nearest:
		for light: OmniLight3D in _fires:
			if light.get_parent() == nearest.get_parent():
				chosen.append(light)
		chosen.sort_custom(func(a: OmniLight3D, b: OmniLight3D) -> bool: return float(a.get_meta("strength")) > float(b.get_meta("strength")))
		chosen.resize(mini(chosen.size(), int(LIGHT_COUNT[_profile])))
	for light: OmniLight3D in _active:
		if light not in chosen:
			light.visible = false
	_active = chosen
	for index in _active.size():
		var light := _active[index]
		light.visible = true
		var t := _clock + index * 1.9
		var flicker := 1.0 + .07 * sin(t * 7.3) + .05 * sin(t * 12.9 + 1.7) + .03 * sin(t * 23.1 + .4)
		var vigor := _forge_vigor if is_instance_valid(_forge_flames) and light.get_parent() == _forge_flames.get_parent() else 1.0
		light.light_energy = 1.25 * float(light.get_meta("strength")) * flicker * vigor
