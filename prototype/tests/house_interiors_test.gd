extends SceneTree
## Furnished Valdora interiors: every placement is checked against the actual
## render geometry (house shell, imported table/bench, the kit meshes), the
## gameplay colliders and the household designs. Headless physics only; not a
## device performance measurement. Optional user arg: JSON report path.

const Regional = preload("res://scripts/world/regional_village.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const Art = preload("res://scripts/world/village_art.gd")
const Kit = preload("res://scripts/world/village/interior_kit.gd")
const Designs = preload("res://scripts/world/village/household_designs.gd")
const Family = preload("res://scripts/world/village/architecture/valdora_house_family.gd")
const TEST_LAYER := 1 << 19
const CONTACT_TOLERANCE := .006
const OVERLAP_TOLERANCE := .012
const CAPSULE_RADIUS := .30
var failures: Array[String] = []
var checks := 0
var stage: Node3D
var report := {"houses": {}}


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func _run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	Art.box_collider(stage, Vector3(300, .5, 150), Vector3(30, -.26, 0))
	var region := Regional.new()
	stage.add_child(region)
	var started := Time.get_ticks_usec()
	region.show_origin("italia")
	report.region_build_ms = (Time.get_ticks_usec() - started) / 1000.0
	var interiors = region.get_node_or_null("HouseInteriors")
	_check(interiors != null, "The interior builder is part of the Italian village")
	if interiors == null:
		_finish()
		return
	report.interior_build_ms = interiors.build_usec / 1000.0
	_check(Kit.meshes.is_empty(), "Source kit meshes are released after the rooms are merged")
	Kit.ensure()
	var lods := {}
	for prop: String in Kit.meshes:
		var surface: Dictionary = RenderingServer.mesh_get_surface((Kit.meshes[prop] as Mesh).get_rid(), 0)
		lods[prop] = (surface.get("lods", []) as Array).size()
	report.kit = {"props": Kit.meshes.size(), "import_lod_levels": lods}
	_check(Kit.meshes.size() == Kit.info.size(), "Every kit prop in the manifest was imported (%d/%d)" % [Kit.meshes.size(), Kit.info.size()])
	_check(interiors.errors.is_empty(), "Designs resolve without errors: %s" % [interiors.errors])
	await physics_frame
	await physics_frame
	var furnished := 0
	var ids: Array = []
	for home: Dictionary in Layout.HOMES:
		ids.append(home.id)
	ids.append(Designs.ATRIUM)
	for id: String in ids:
		var house := region.get_node(NodePath(id)) as Node3D
		if id != Designs.ATRIUM:
			_check(house.has_node("DoorstepSupplies"), "Doorstep supplies remain outside " + id)
		if not interiors.furnishes(id):
			continue
		furnished += 1
		_check(not house.has_node("Household"), "The generic household set is replaced in " + id)
		if id == Designs.FAMILY:
			_check(house.has_node("FamilyHome/DrinkingCup") and house.has_node("FamilyHome/DrinkingJug"),
				"The family home keeps the story's drinking cup and jug")
			_check(house.get_node("FamilyHome").has_meta("rest_anchor") and house.get_node("FamilyHome").has_meta("drink_anchor"),
				"The family home keeps its rest and drink anchors")
			_check(house.get_node("FamilyHome").get_child_count() == 2, "Only the story props remain of the generic family set (%d)" % house.get_node("FamilyHome").get_child_count())
		_check(house.has_node("Interior"), "A designed interior exists in " + id)
		_shell_geometry(house, id)
	_check(furnished == 21, "All twenty households and the atrium house are furnished: %d" % furnished)
	for id: String in ids:
		if interiors.furnishes(id):
			await _check_house(interiors, region.get_node(NodePath(id)) as Node3D, id)
	var ground := StaticBody3D.new()
	ground.collision_layer = TEST_LAYER
	ground.collision_mask = 0
	var slab := CollisionShape3D.new()
	slab.shape = BoxShape3D.new()
	(slab.shape as BoxShape3D).size = Vector3(300, 1, 300)
	slab.position.y = -.5
	ground.add_child(slab)
	stage.add_child(ground)
	for site: String in Designs.SITES:
		if Designs.items(site).is_empty():
			continue
		var place := region.find_child(Designs.SITES[site].node, true, false) as Node3D
		_check(place != null and place.has_node("Interior"), "The site %s is furnished" % site)
		if place and place.has_node("Interior"):
			_check(place.global_position.distance_to(Designs.SITES[site].at) < .01, "%s stands at its authored place" % site)
			await _check_house(interiors, place, site)
	ground.queue_free()
	await _check_family_home(interiors, region.get_node(Designs.FAMILY))
	await _check_forge(interiors, region)
	_check_openings(region.get_node("weaver_home"))
	_check_parity(interiors)
	_check_contract()
	await _check_lights(interiors, region)
	for id: String in ["carpenter_home", "smith_home", "dairy_home", "baker_home", "vintner_home"]:
		await _walk_into(region.get_node(id))
	await _walk_into(region.get_node(Designs.ATRIUM), 6.2, 3.0, .065)
	_finish()


func _finish() -> void:
	report.checks = checks
	report.failures = failures
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var file := FileAccess.open(args[0], FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
	if is_instance_valid(stage):
		stage.free()
	print("HOUSE_INTERIORS_RESULT checks=%d failures=%d" % [checks, failures.size()])
	for message: String in failures.slice(0, 80):
		printerr("FAIL: " + message)
	print("HOUSE_INTERIORS_PASS" if failures.is_empty() else "HOUSE_INTERIORS_FAIL")
	quit(0 if failures.is_empty() else 1)


## Test-only bodies made from the visible house meshes (walls, paving, the
## imported table and bench), so contact is measured against what is drawn.
func _authored_shell_meshes(house: Node3D, id: String) -> Array[Node]:
	if not Family.is_family_house(house):
		return house.find_children(Designs.shell(id).meshes, "MeshInstance3D", true, false)
	var result: Array[Node] = []
	for mesh: MeshInstance3D in house.find_children("*", "MeshInstance3D", true, false):
		if mesh.has_meta("valdora_family_shell") and not String(mesh.name).ends_with("_far") and mesh.mesh != null:
			result.append(mesh)
	return result


func _shell_geometry(house: Node3D, id: String) -> void:
	var meshes := _authored_shell_meshes(house, id)
	_check(not meshes.is_empty(), id + " has actual authored shell meshes to test")
	for mesh: MeshInstance3D in meshes:
		var body := StaticBody3D.new()
		body.collision_layer = TEST_LAYER
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		shape.shape = mesh.mesh.create_trimesh_shape()
		body.add_child(shape)
		stage.add_child(body)
		body.global_transform = mesh.global_transform


func _item_body(house: Node3D, record: Dictionary) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = TEST_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = (Kit.meshes[record.prop] as Mesh).create_trimesh_shape()
	body.add_child(shape)
	stage.add_child(body)
	body.global_transform = house.get_node("Interior").global_transform * record.transform
	return body


func _check_house(interiors: Node3D, house: Node3D, id: String) -> void:
	var placed: Array = interiors.manifest.get(id, [])
	var design: Array = Designs.items(id)
	var summary := {"household": house.get_node("Interior").get_meta("household"), "items": placed.size(), "props": {}}
	# Inventory: every designed entry is placed, nothing else is.
	_check(placed.size() == design.size(), "%s places all %d designed items (%d)" % [id, design.size(), placed.size()])
	for i in mini(placed.size(), design.size()):
		_check(placed[i].prop == design[i].prop, "%s item %d is %s" % [id, i, design[i].prop])
	var props := {}
	for record: Dictionary in placed:
		props[record.prop] = int(props.get(record.prop, 0)) + 1
	summary.props = props
	var frame := Designs.shell(id)
	for category: String in Designs.basics(id):
		var found := false
		for prop: String in Designs.CATEGORY[category]:
			found = found or props.has(prop)
		_check(found, "%s has a %s" % [id, category])
	var profession: String = Designs.profession(id)
	for prop: String in Designs.SIGNATURE.get(profession, []):
		_check(props.has(prop), "%s (%s) contains %s" % [id, profession, prop])
	var bodies := []
	for record: Dictionary in placed:
		bodies.append(_item_body(house, record))
	await physics_frame
	var space := stage.get_world_3d().direct_space_state
	var room: Transform3D = house.get_node("Interior").global_transform
	var worst := 0.0
	for index in placed.size():
		var record: Dictionary = placed[index]
		var box := (record.transform as Transform3D) * Kit.aabb(record.prop)
		var label := "%s/%s#%d" % [id, record.prop, index]
		# Inside the plaster faces.
		_check(box.position.x >= frame.wall.W - .003 and box.end.x <= frame.wall.E + .003 and box.position.z >= frame.wall.N - .003 \
			and box.end.z <= frame.wall.S + .003, "%s stays inside the walls: %s" % [label, box])
		# Nothing stands or hangs in front of a window or in the door.
		if record.wall != "" and frame.has("openings"):
			var across: bool = record.wall in ["N", "S"]
			var face := Rect2(box.position.x if across else box.position.z, box.position.y, box.size.x if across else box.size.z, box.size.y)
			for hole: Rect2 in frame.openings[record.wall]:
				_check(not hole.intersects(face), "%s leaves the opening %s of the %s wall free" % [label, hole, record.wall])
		if record.hanging:
			var probe := PhysicsShapeQueryParameters3D.new()
			var sphere := SphereShape3D.new()
			sphere.radius = .02
			probe.shape = sphere
			probe.collision_mask = TEST_LAYER
			probe.exclude = [bodies[index].get_rid()]
			probe.transform = Transform3D(Basis.IDENTITY, room * (record.transform as Transform3D).origin)
			_check(not space.intersect_shape(probe, 1).is_empty(), "%s hangs from a peg, not from the air" % label)
			continue
		if record.mounted or record.leaning:
			var gap := _wall_gap(space, room, record, box, bodies[index])
			_check(gap >= -.002 and gap <= CONTACT_TOLERANCE, "%s touches its wall (gap %.4f m)" % [label, gap])
			if record.mounted:
				continue
		var contact := _support_gap(space, room, box, bodies[index], record)
		worst = maxf(worst, absf(contact))
		_check(absf(contact) <= CONTACT_TOLERANCE, "%s rests on %s (gap %.4f m)" % [label, record.on, contact])
	summary.worst_contact_m = worst
	# Flames start on a wick, a candle or the fire bed, never in the air.
	var flames := 0
	for index in placed.size():
		var record: Dictionary = placed[index]
		for flame: Array in Kit.FLAMES.get(record.prop, []):
			flames += 1
			# Measured against the drawn mesh: the highest vertex within 3 cm of
			# the flame axis (wick tip, candle top or fire bed) lies just below.
			var base: Vector3 = flame[0]
			var top := -INF
			for vertex: Vector3 in (Kit.meshes[record.prop] as Mesh).get_faces():
				if Vector2(vertex.x - base.x, vertex.z - base.z).length() <= .03 and vertex.y <= base.y + .03:
					top = maxf(top, vertex.y)
			_check(base.y - top >= -.03 and base.y - top <= .015, "%s/%s: a flame starts on its wick or fire bed (gap %.4f m)" % [id, record.prop, base.y - top])
	var flame_node := house.get_node("Interior").get_node_or_null("Flames") as MeshInstance3D
	_check((flame_node == null and flames == 0) or (flame_node != null and int(flame_node.get_meta("flames")) == flames),
		"%s shows %d flame(s)" % [id, flames])
	summary.flames = flames
	summary.lights = house.get_node("Interior").find_children("*", "OmniLight3D", false, false).size()
	var grime := house.get_node("Interior").get_node_or_null("Grime") as MeshInstance3D
	_check(grime != null, "%s shows soot, ash or trodden dirt" % id)
	if grime:
		var stain := grime.mesh.get_aabb()
		_check(stain.position.x >= frame.wall.W - .001 and stain.end.x <= frame.wall.E + .001 and stain.position.z >= frame.wall.N - .001 \
			and stain.end.z <= frame.wall.S + .001 and stain.position.y >= .003, "%s: grime stays on the room's own surfaces: %s" % [id, stain])
		summary.grime_triangles = grime.mesh.surface_get_array_len(0) / 3
	_overlaps(id, placed, frame)
	_door_and_paths(house, id, summary, frame)
	var meshes := 0
	var triangles := 0
	for layer: MeshInstance3D in house.get_node("Interior").find_children("*", "MeshInstance3D", false, false):
		meshes += layer.mesh.get_surface_count()
		for s in layer.mesh.get_surface_count():
			triangles += layer.mesh.surface_get_array_index_len(s) / 3
	summary.draw_surfaces = meshes
	summary.triangles = triangles
	_check(meshes <= 30, "%s stays within 30 merged surfaces (%d)" % [id, meshes])
	_check(triangles <= 60000, "%s stays within 60k interior triangles (%d)" % [id, triangles])
	report.houses[id] = summary
	for body: StaticBody3D in bodies:
		body.queue_free()
	await physics_frame


## Distance from the lowest point of a placed item down to the surface below it.
func _support_gap(space: PhysicsDirectSpaceState3D, room: Transform3D, box: AABB, own: StaticBody3D, record: Dictionary) -> float:
	var best := INF
	var steps := 6
	for i in steps + 1:
		for j in steps + 1:
			var local := Vector3(lerpf(box.position.x + .01, box.end.x - .01, float(i) / steps), box.position.y + .03,
				lerpf(box.position.z + .01, box.end.z - .01, float(j) / steps))
			var from := room * local
			var ray := PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * .25, TEST_LAYER, [own.get_rid()])
			var hit := space.intersect_ray(ray)
			if hit.is_empty():
				continue
			var gap := (room.affine_inverse() * (hit.position as Vector3)).y
			gap = box.position.y - gap
			if absf(gap) < absf(best):
				best = gap
	return best


## Horizontal distance from an item's back face to the plaster it should touch.
func _wall_gap(space: PhysicsDirectSpaceState3D, room: Transform3D, record: Dictionary, box: AABB, own: StaticBody3D) -> float:
	var side: String = record.wall
	var normal := {"W": Vector3.LEFT, "E": Vector3.RIGHT, "N": Vector3.FORWARD, "S": Vector3.BACK}[side] as Vector3
	var back: float = {"W": box.position.x, "E": box.end.x, "N": box.position.z, "S": box.end.z}[side]
	var best := INF
	for i in 9:
		for j in 9:
			var u := float(i) / 8.0
			var v := float(j) / 8.0
			var local := Vector3(lerpf(box.position.x, box.end.x, u), lerpf(box.position.y + .02, box.end.y - .02, v), lerpf(box.position.z, box.end.z, u))
			if side in ["W", "E"]:
				local.x = back - normal.x * .03
			else:
				local.z = back - normal.z * .03
			var from := room * local
			var ray := PhysicsRayQueryParameters3D.create(from, from + room.basis * normal * .12, TEST_LAYER, [own.get_rid()])
			var hit := space.intersect_ray(ray)
			if hit.is_empty():
				continue
			var reach: float = (room.affine_inverse() * (hit.position as Vector3) - local).dot(normal) - .03
			best = minf(best, reach)
	return best


func _overlaps(id: String, placed: Array, frame: Dictionary) -> void:
	var fixed := []
	for box: AABB in frame.fixed:
		fixed.append({"name": "fixed obstacle %s" % box, "box": box})
	if not Designs.is_site(id):
		fixed[0].name = "table" if id != Designs.ATRIUM else "basin"
		if id != Designs.ATRIUM:
			fixed[1].name = "bench"
	var boxes := []
	for record: Dictionary in placed:
		boxes.append(_shrink((record.transform as Transform3D) * Kit.aabb(record.prop)))
	for i in placed.size():
		var a: Dictionary = placed[i]
		var on_glb: String = {"glb_table": "table", "glb_bench": "bench"}.get(a.on, "")
		for item: Dictionary in fixed:
			if item.name == on_glb or a.prop in Kit.CANOPY:
				continue
			_check(not boxes[i].intersects(item.box), "%s/%s does not cut into the %s" % [id, a.prop, item.name])
		for j in range(i + 1, placed.size()):
			var b: Dictionary = placed[j]
			if _related(a, b, placed) or not boxes[i].intersects(boxes[j]):
				continue
			failures.append("%s: %s and %s overlap" % [id, a.prop, b.prop])
			checks += 1


## Overlap tolerance without inverting thin boxes such as a rush mat.
func _shrink(box: AABB) -> AABB:
	var inset := Vector3(minf(OVERLAP_TOLERANCE, box.size.x * .25), minf(OVERLAP_TOLERANCE, box.size.y * .25), minf(OVERLAP_TOLERANCE, box.size.z * .25))
	return AABB(box.position + inset, box.size - inset * 2)


func _related(a: Dictionary, b: Dictionary, placed: Array) -> bool:
	if a.prop in Kit.CANOPY or b.prop in Kit.CANOPY:
		return true
	# Resting on, hanging from, or sharing a support is intended contact.
	for pair in [[a, b], [b, a]]:
		var child: Dictionary = pair[0]
		var parent: Dictionary = pair[1]
		if parent.id != "" and (child.on == parent.id or child.get("rail", "") == parent.id):
			return true
	if a.on == b.on and a.on not in ["floor", "wall"]:
		return true
	if a.hanging or b.hanging:
		return a.hanging and b.hanging
	return false


func _door_and_paths(house: Node3D, id: String, summary: Dictionary, frame: Dictionary) -> void:
	var space := stage.get_world_3d().direct_space_state
	var room: Transform3D = house.get_node("Interior").global_transform
	var door := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = frame.doorway[1]
	door.shape = box
	door.collision_mask = 1
	door.transform = room * Transform3D(Basis.IDENTITY, frame.doorway[0])
	var blocking := space.intersect_shape(door, 4)
	_check(blocking.is_empty(), "%s keeps the doorway clear: %s" % [id, blocking.map(func(hit): return hit.collider.name)])
	# Flood fill from the door with a 0.60 m wide capsule.
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = 1.70
	query.shape = capsule
	query.collision_mask = 1
	query.margin = .005
	var step := .1
	var free := {}
	var cells := Vector2i(roundi(frame.grid.x / step), roundi(frame.grid.y / step))
	for i in range(-cells.x, cells.x + 1):
		for j in range(-cells.y, cells.y + 1):
			var cell := Vector2i(i, j)
			query.transform = room * Transform3D(Basis.IDENTITY, Vector3(i * step, .95, j * step))
			free[cell] = space.intersect_shape(query, 1).is_empty()
	var start := Vector2i(roundi(frame.door.x / step), roundi(frame.door.y / step))
	var reached := {start: true}
	var frontier: Array[Vector2i] = [start]
	_check(free.get(start, false), "%s: the doorway cell is free" % id)
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := cell + offset
			if free.get(next, false) and not reached.has(next):
				reached[next] = true
				frontier.append(next)
	summary.walkable_m2 = reached.size() * step * step
	for point: Vector2 in frame.stations:
		var near := false
		for cell: Vector2i in reached:
			near = near or Vector2(cell.x * step, cell.y * step).distance_to(point) <= .36
		_check(near, "%s: a 0.60 m path reaches the use point %s" % [id, point])


## The committed shell contract must match the data the builder places against.
func _check_contract() -> void:
	var expected := JSON.stringify(Designs.contract(), "  ", true)
	var path := "res://assets/interiors/shell_contract.json"
	if OS.get_environment("IMPERATHEN_WRITE_SHELL_CONTRACT") == "1":
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(expected + "\n")
		file.close()
	_check(FileAccess.file_exists(path) and FileAccess.get_file_as_string(path).strip_edges() == expected.strip_edges(),
		"shell_contract.json matches household_designs.gd contract()")


func _check_parity(interiors: Node3D) -> void:
	var signatures := {}
	for profile: String in ["low", "balanced", "high", "very_high"]:
		interiors.set_quality(profile)
		var parts := []
		for shape: CollisionShape3D in interiors.get_parent().find_children("*", "CollisionShape3D", true, false):
			if shape.get_parent().name == "InteriorCollision":
				parts.append("%s|%s|%s" % [shape.get_parent().get_parent().get_meta("household_id"), shape.global_transform, _shape_key(shape.shape)])
		parts.sort()
		signatures[profile] = str(parts).sha256_text()
		report["collision_shapes_" + profile] = parts.size()
	_check(signatures.low == signatures.very_high and signatures.balanced == signatures.high and signatures.low == signatures.balanced,
		"Gameplay collision is identical in every quality profile")
	interiors.set_quality("balanced")


func _shape_key(shape: Shape3D) -> String:
	if shape is BoxShape3D:
		return "box%s" % (shape as BoxShape3D).size
	if shape is CylinderShape3D:
		return "cyl%.3f/%.3f" % [(shape as CylinderShape3D).radius, (shape as CylinderShape3D).height]
	return shape.get_class()


func _check_lights(interiors: Node3D, region: Node3D) -> void:
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.make_current()
	var everything: Array = interiors.get_parent().find_children("*", "OmniLight3D", true, false).filter(
		func(light: Node) -> bool: return light.has_meta("kind"))
	for profile: String in ["low", "balanced", "high", "very_high"]:
		interiors.set_quality(profile)
		for id: String in ["weaver_home", "smith_home", "south_baker_home", "baker_home", "vintner_home", Designs.ATRIUM]:
			var house := region.get_node(id) as Node3D
			var inside: Array = house.get_node("Interior").find_children("*", "OmniLight3D", false, false)
			camera.global_position = inside[0].global_position + Vector3(.2, .4, .2)
			interiors._process(1.0 / 60.0)
			var shown := 0
			var elsewhere := 0
			for light: OmniLight3D in everything:
				if light.visible:
					shown += 1
					elsewhere += 0 if light in inside else 1
			var expected := mini(int(interiors.LIGHT_COUNT[profile]), inside.size())
			_check(shown == expected and elsewhere == 0, "%s in %s shows %d of its %d light(s), none elsewhere (%d, %d)" % [id, profile, expected,
				inside.size(), shown, elsewhere])
			if expected > 0:
				var strongest := true
				for light: OmniLight3D in inside:
					strongest = strongest and (light.visible or float(light.get_meta("strength")) <= 1.0)
				_check(strongest and (inside.filter(func(light: OmniLight3D) -> bool: return light.visible)[0] as OmniLight3D).light_energy > .2,
					"%s in %s keeps its fire among the shown lights" % [id, profile])
	var forge := region.find_child(Designs.SITES[Designs.FORGE].node, true, false) as Node3D
	var confined := 0
	var hearths := 0
	var lamps := 0
	for light: OmniLight3D in everything:
		var outdoors := forge.is_ancestor_of(light)
		confined += 1 if (light.light_cull_mask == interiors.FIRE_LAYER) != outdoors else 0
		hearths += 1 if light.get_meta("kind") == "fire" else 0
		lamps += 1 if light.get_meta("kind") == "lamp" else 0
		_check(not light.shadow_enabled, "Interior lights cast no real-time shadow (%s)" % light.get_path())
	_check(confined == everything.size(), "Indoor lights reach only their house, the open forge reaches the lane (%d/%d)" % [confined, everything.size()])
	for id: String in ["weaver_home", Designs.ATRIUM]:
		var house := region.get_node(id) as Node3D
		for mesh: MeshInstance3D in _authored_shell_meshes(house, id):
			_check((mesh.layers & interiors.FIRE_LAYER) != 0, "%s shell mesh %s receives the hearth light" % [id, mesh.name])
	report.hearth_lights = hearths
	report.lamp_lights = lamps
	_check(hearths == 22, "Twenty hearths, the atrium brazier and the forge carry a fire light (%d)" % hearths)
	_check(lamps >= 12, "Oil lamps and candles carry their own small lights (%d)" % lamps)
	interiors.set_quality("balanced")
	camera.queue_free()
	await physics_frame


## The family home is shared with the I-01 slice: its cups, jug and people
## keep their places; the furniture offers the surfaces they stand on.
func _check_family_home(interiors: Node3D, house: Node3D) -> void:
	var slots: Dictionary = Designs.I01_SLOTS
	var placed: Array = interiors.manifest[Designs.FAMILY]
	var room: Transform3D = house.get_node("Interior").global_transform
	for record: Dictionary in placed:
		_check(record.prop not in ["table_meal", "tavern_set", "shelf_bowls"], "The family home lays no cups or jug of its own (%s)" % record.prop)
	var bodies := []
	for record: Dictionary in placed:
		bodies.append(_item_body(house, record))
	await physics_frame
	var space := stage.get_world_3d().direct_space_state
	for point: Vector2 in slots.shelf_cups:
		for offset: Vector2 in [Vector2.ZERO, Vector2(.09, 0), Vector2(-.09, 0), Vector2(0, .09), Vector2(0, -.09)]:
			var from: Vector3 = room * Vector3(point.x + offset.x, float(slots.shelf_top) + .2, point.y + offset.y)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * .5, TEST_LAYER))
			var height: float = (room.affine_inverse() * (hit.position as Vector3)).y if not hit.is_empty() else -1.0
			_check(absf(height - float(slots.shelf_top)) <= .004, "The cup shelf carries the I-01 cup at %s (top %.4f m)" % [point + offset, height])
	var spots: Array = []
	for point: Vector2 in slots.table_cups:
		spots.append([point, float(slots.table_top), .11])
	spots.append([slots.table_jug, float(slots.table_top), .16])
	spots.append([slots.bench_jug, .50, .16])
	spots.append([slots.bench_cup, .50, .11])
	for point: Vector2 in slots.shelf_cups:
		spots.append([point, float(slots.shelf_top), .11])
	for spot: Array in spots:
		var probe := PhysicsShapeQueryParameters3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = spot[2]
		cylinder.height = .30
		probe.shape = cylinder
		probe.collision_mask = TEST_LAYER
		probe.transform = room * Transform3D(Basis.IDENTITY, Vector3((spot[0] as Vector2).x, float(spot[1]) + .17, (spot[0] as Vector2).y))
		var hits := space.intersect_shape(probe, 4).filter(func(hit: Dictionary) -> bool: return hit.collider in bodies)
		_check(hits.is_empty(), "The I-01 slot at %s is free of interior props" % [spot[0]])
	for person: Vector2 in slots.people:
		var probe := PhysicsShapeQueryParameters3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = .28
		capsule.height = 1.7
		probe.shape = capsule
		probe.collision_mask = 1
		probe.transform = room * Transform3D(Basis.IDENTITY, Vector3(person.x, .9, person.y))
		var blocking := space.intersect_shape(probe, 4)
		_check(blocking.is_empty(), "A person can stand at the I-01 place %s: %s" % [person, blocking.map(func(hit): return hit.collider.name)])
	for body: StaticBody3D in bodies:
		body.queue_free()
	await physics_frame


## The smithy keeps the work stations of the apprenticeship usable.
func _check_forge(interiors: Node3D, region: Node3D) -> void:
	var forge := region.find_child(Designs.SITES[Designs.FORGE].node, true, false) as Node3D
	if ResourceLoader.exists(Family.FORGE_SCENE, "PackedScene"):
		var shell := forge.get_node_or_null("Interior/AuthoredForgeShell") as Node3D
		_check(is_instance_valid(shell) and shell.scene_file_path == Family.FORGE_SCENE, "The authored forge shell is used in the live settlement")
		if is_instance_valid(shell):
			var meshes := shell.find_children("*", "MeshInstance3D", true, false)
			_check(meshes.size() == 2, "Only the original shell and distant proxy are rendered; no duplicated workshop fixtures")
			var original := shell.find_child("valdora_forge_shell", true, false) as MeshInstance3D
			var proxy := shell.find_child("valdora_forge_far", true, false) as MeshInstance3D
			_check(is_instance_valid(original) and is_instance_valid(proxy), "The two original forge LOD roles are present")
			if is_instance_valid(original) and is_instance_valid(proxy):
				for profile: String in ["low", "balanced", "high", "very_high"]:
					interiors.set_quality(profile)
					var ranges: Dictionary = Family.RANGES[profile]
					_check(is_equal_approx(original.visibility_range_end, float(ranges.house)) and is_equal_approx(proxy.visibility_range_begin, float(ranges.house)), "Forge shell and proxy share the house LOD boundary in " + profile)
				interiors.set_quality("balanced")
	var Childhood = load("res://scripts/story/village_childhood.gd")
	for pair: Array in [["Bellows", "bellows"], ["Anvil", "anvil"], ["QuenchTrough", "quench"]]:
		var marker := forge.get_node_or_null(pair[0]) as Node3D
		_check(marker != null, "The forge has a %s" % pair[0])
		if marker == null:
			continue
		var point: Vector2 = Childhood.POINTS[pair[1]]
		var distance := Vector2(marker.global_position.x, marker.global_position.z).distance_to(point)
		_check(distance >= .55 and distance <= 1.7, "The work point %s is within reach of the %s (%.2f m)" % [pair[1], pair[0], distance])
	_check(forge.has_node("Hearth") and forge.has_node("ToolRack") and forge.has_meta("smith_anchor"), "Hearth, tool rack and the smith's anchor exist")
	var water := forge.get_node_or_null("Interior/Water") as MeshInstance3D
	_check(water != null, "The slack tub holds water")
	if water:
		var trough: Dictionary = (interiors.manifest[Designs.FORGE] as Array).filter(func(record: Dictionary) -> bool: return record.prop == "quench_trough")[0]
		var tub := (trough.transform as Transform3D) * Kit.aabb("quench_trough")
		var surface := water.mesh.get_aabb()
		_check(tub.grow(.001).encloses(surface) and surface.position.y < tub.end.y - .05 and surface.position.y > tub.end.y - .2,
			"The water lies inside the tub below its rim: %s in %s" % [surface, tub])
	var flames := forge.get_node("Interior/Flames") as MeshInstance3D
	interiors.set_forge_work("forge_bellows")
	_check(float(flames.get_instance_shader_parameter("vigor")) > 1.5, "Working the bellows makes the forge fire flare")
	interiors.set_forge_work("")
	_check(is_equal_approx(float(flames.get_instance_shader_parameter("vigor")), 1.0), "The fire settles when the work stops")
	await physics_frame


## The recorded door and window openings are holes in the drawn shell, and
## the plaster beside them is solid.
func _check_openings(house: Node3D) -> void:
	var space := stage.get_world_3d().direct_space_state
	var frame := Designs.shell(house.name)
	var room: Transform3D = house.get_node("Interior").global_transform
	var total := 0
	for side: String in frame.openings:
		var plane: float = frame.wall[side]
		var out := signf(plane)
		for hole: Rect2 in frame.openings[side]:
			total += 1
			var open := true
			# Quarter points: the window lattice crosses the middle of the opening.
			for u: float in [.25, .75]:
				for v: float in [.25, .75]:
					var a := hole.position.x + hole.size.x * u
					var y := hole.position.y + hole.size.y * v
					if is_zero_approx(hole.position.y):
						# Door: the open leaf hangs inside; probe the passage beside it.
						a = hole.position.x + hole.size.x * lerpf(.4, .9, u)
					var from := Vector3(a, y, plane - out * .05) if side in ["N", "S"] else Vector3(plane - out * .05, y, a)
					var to := from + (Vector3(0, 0, out) if side in ["N", "S"] else Vector3(out, 0, 0)) * .5
					open = open and space.intersect_ray(PhysicsRayQueryParameters3D.create(room * from, room * to, TEST_LAYER)).is_empty()
			_check(open, "%s wall opening %s is open in the drawn shell" % [side, hole])
			for beside: float in [hole.position.x - .2, hole.end.x + .2]:
				var y := hole.position.y + hole.size.y * .5
				var from := Vector3(beside, y, plane - out * .05) if side in ["N", "S"] else Vector3(plane - out * .05, y, beside)
				var to := from + (Vector3(0, 0, out) if side in ["N", "S"] else Vector3(out, 0, 0)) * .5
				_check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(room * from, room * to, TEST_LAYER)).is_empty(),
					"%s wall is solid beside the opening %s (at %.2f)" % [side, hole, beside])
	_check(total == 5, "One door and four windows are recorded for the shared shell (%d)" % total)


func _walk_into(home: Node3D, start_z := 4.6, destination_z := .7, floor_height := Layout.HOUSE_FLOOR) -> void:
	var actor := CharacterBody3D.new()
	actor.collision_layer = 2
	actor.collision_mask = 1 | Layout.CITIZEN_LAYER
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .28
	capsule.height = 1.8
	shape.shape = capsule
	actor.add_child(shape)
	stage.add_child(actor)
	actor.global_position = home.to_global(Vector3(0, 1, start_z))
	var direction := -home.global_basis.z
	for frame in 200:
		await physics_frame
		actor.velocity.x = direction.x * 1.6
		actor.velocity.z = direction.z * 1.6
		actor.velocity.y = -.3 if actor.is_on_floor() else actor.velocity.y - 19.6 / 60.0
		actor.move_and_slide()
		if home.to_local(actor.global_position).z < destination_z:
			break
	_check(home.to_local(actor.global_position).z < destination_z + .1, "A real capsule walks through the furnished doorway of " + home.name)
	_check(absf(actor.global_position.y - .9 - floor_height) < .03, "and stands on the paving in " + home.name)
	actor.free()
	await physics_frame
