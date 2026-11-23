extends Node3D
## Walkable additions to existing houses. This view never creates people or goods.

const Art = preload("res://scripts/world/village_art.gd")
const Childhood = preload("res://scripts/story/childhood_story.gd")
const FLOOR_HEIGHT := 0.3925
const DOOR_WIDTH := 1.12
const RAMP_INNER := 2.08
const RAMP_OUTER := 3.48
const HOMES := {
	"family": {"node":"south_weaver_home", "at":Vector3(-5,0,24), "yaw":0.0, "label":"Haus von Julia und Silvanus"},
	"neighbors": {"node":"south_baker_home", "at":Vector3(-14,0,24), "yaw":0.0, "label":"Nachbarhaus · Backstube"},
	"smith": {"node":"smith_home", "at":Vector3(38,0,-26), "yaw":-PI/2, "label":"Sextus · Schmiede"},
}
const IDENTITY_ROLES := {"julia":"Mutter · Bäuerin", "silvanus":"Vater · Lastenträger", "sextus":"Schmied"}

var enabled := false
var homes: Dictionary = {}
var _additions: Array[Node3D] = []
var _solids: Array[StaticBody3D] = []
var _roofs: Dictionary = {}
var _shells: Dictionary = {}
var _replaced_steps: Array[MeshInstance3D] = []
var _original_visibility: Dictionary = {}
var _materials: Dictionary = {}
var _details: Array[GeometryInstance3D] = []
var _interior_id := ""
var _memorials: Dictionary = {}
var _work_cover: Node3D


func build(regional: Node3D) -> void:
	if not is_instance_valid(regional):
		return
	var unchanged := homes.size() == HOMES.size()
	for id: String in HOMES:
		var home := regional.get_node_or_null(NodePath(HOMES[id].node)) as Node3D
		unchanged = unchanged and is_instance_valid(home) and homes.get(id) == home
	if unchanged:
		return
	_restore_visuals()
	for addition: Variant in _additions:
		if is_instance_valid(addition):
			addition.free()
	homes.clear()
	_additions.clear()
	_solids.clear()
	_roofs.clear()
	_shells.clear()
	_replaced_steps.clear()
	_original_visibility.clear()
	_details.clear()
	_memorials.clear()
	_work_cover = null
	_interior_id = ""
	_materials = {
		"wood":Art.material(Color("6c4d32")), "linen":Art.material(Color("b9aa82")),
		"clay":Art.material(Color("a56743")), "dark":Art.material(Color("47392b")),
		"iron":Art.material(Color("343b3b"),.42), "stone":Art.material(Color("a8997b")),
		"grain":Art.material(Color("c2a965")), "water":Art.material(Color("536f76"),.18),
	}
	_materials.iron.metallic = .62
	_build_lane()
	for id: String in HOMES:
		var home := regional.get_node_or_null(NodePath(HOMES[id].node)) as Node3D
		if home == null:
			continue
		homes[id] = home
		_roofs[id] = []
		_shells[id] = []
		for mesh: Variant in home.find_children("*","MeshInstance3D",true,false):
			var part := str(mesh.name)
			if part.begins_with("House_Roof") or part in ["House_Front_Gable","House_Rear_Gable"]:
				_roofs[id].append(mesh)
				_original_visibility[mesh.get_instance_id()] = mesh.visible
			if part in ["House_Threshold","House_Entry_Step_Upper","House_Entry_Step_Lower"]:
				_replaced_steps.append(mesh)
				_original_visibility[mesh.get_instance_id()] = mesh.visible
			# Shipped GLBs group geometry by material. Their oak mesh contains
			# both roof boards and furniture; hiding that mesh would erase tables.
			if part.begins_with("frontier_house_"):
				_add_material_cutaway(home,mesh,id)
		var interior := Node3D.new()
		interior.name = "ChildhoodInterior"
		home.add_child(interior)
		_additions.append(interior)
		_build_floor(interior)
		_build_household(interior,id)
		var label := Art.label(interior,HOMES[id].label,Vector3(0,2.75,2.62),Color("e7d3a6"),25)
		label.name = "HouseholdName"
		label.pixel_size = .0026
		label.visibility_range_begin = 3.0
		label.visibility_range_end = 10.0
	_set_enabled(enabled)


func _add_material_cutaway(home: Node3D,source: MeshInstance3D,id: String) -> void:
	if source.mesh == null:
		return
	var outer := ArrayMesh.new()
	var inner := ArrayMesh.new()
	var changed_steps := false
	var changed_roof := false
	var local_transform := home.global_transform.affine_inverse()*source.global_transform
	for surface in source.mesh.get_surface_count():
		if source.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var original := source.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = original[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			indices.resize(vertices.size())
			for i in indices.size(): indices[i] = i
		var outer_indices := PackedInt32Array()
		var inner_indices := PackedInt32Array()
		var material := source.get_active_material(surface)
		var stone := material != null and material.resource_name in ["ARCH_Limestone","ARCH_Limestone_Damp"]
		for face in range(0,indices.size(),3):
			var a := local_transform*vertices[indices[face]]
			var b := local_transform*vertices[indices[face+1]]
			var c := local_transform*vertices[indices[face+2]]
			var step := stone and _step_vertex(a) and _step_vertex(b) and _step_vertex(c)
			changed_steps = changed_steps or step
			if step:
				continue
			for k in 3: outer_indices.append(indices[face+k])
			var above_wall := (a.y+b.y+c.y)/3.0 > 3.10
			changed_roof = changed_roof or above_wall
			if not above_wall:
				for k in 3: inner_indices.append(indices[face+k])
		_append_surface(outer,original,outer_indices,material)
		_append_surface(inner,original,inner_indices,material)
	if not changed_steps and not changed_roof:
		return
	var outer_view: MeshInstance3D
	var inner_view: MeshInstance3D
	if changed_steps and outer.get_surface_count()>0:
		outer_view = _shell_view(source,outer,"ChildhoodExterior")
	if inner.get_surface_count()>0:
		inner_view = _shell_view(source,inner,"ChildhoodInteriorView")
	_original_visibility[source.get_instance_id()] = source.visible
	_shells[id].append({"source":source,"outer":outer_view,"inner":inner_view,"steps":changed_steps})
	if changed_roof:
		_roofs[id].append(source)


func _shell_view(source: MeshInstance3D,mesh: ArrayMesh,label: String) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.name = label
	view.mesh = mesh
	view.transform = source.transform
	view.cast_shadow = source.cast_shadow
	view.hide()
	source.get_parent().add_child(view)
	_additions.append(view)
	return view


static func _step_vertex(point: Vector3) -> bool:
	return absf(point.x)<1.02 and point.z>2.08 and point.z<3.50 and point.y<.52


static func _append_surface(mesh: ArrayMesh,original: Array,indices: PackedInt32Array,material: Material) -> void:
	if indices.is_empty():
		return
	var arrays := original.duplicate()
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(mesh.get_surface_count()-1,material)


func _build_lane() -> void:
	var lane := Node3D.new()
	lane.name = "SouthernHouseLane"
	add_child(lane)
	_additions.append(lane)
	var paint := Art.material(Color("a18b6c"))
	paint.albedo_texture = load("res://assets/village/track_color.png")
	paint.uv1_scale = Vector3(12,1,1)
	var path := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(49.5,1.5)
	path.mesh = plane
	path.material_override = paint
	path.position = Vector3(5.75,.008,28.7)
	path.name = "HouseholdLane"
	lane.add_child(path)
	for x in [-14.0,-5.0]:
		var approach := MeshInstance3D.new()
		var slab := PlaneMesh.new()
		slab.size = Vector2(1.25,1.25)
		approach.mesh = slab
		approach.material_override = paint
		approach.position = Vector3(x,.009,28.1)
		lane.add_child(approach)


func sync_state(data: Dictionary) -> void:
	_set_enabled(Childhood.enabled(data))
	var deceased: Array[String] = []
	for person: Dictionary in data.get("village",{}).get("economy",{}).get("people",[]):
		if not bool(person.get("alive",true)):
			deceased.append(str(person.get("id","")))
	for id: String in _memorials:
		var names: Array[String] = []
		if id == "family":
			if deceased.has("silvanus"): names.append("Silvanus")
			if deceased.has("julia"): names.append("Julia")
		elif id == "smith" and deceased.has("sextus"):
			names.append("Sextus")
		_memorials[id].visible = enabled and not names.is_empty()
		_memorials[id].get_node("Names").text = "In Erinnerung an\n"+" und ".join(names)
	if is_instance_valid(_work_cover):
		_work_cover.visible = enabled and deceased.has("sextus")


func _set_enabled(value: bool) -> void:
	enabled = value
	for addition: Variant in _additions:
		if is_instance_valid(addition):
			addition.visible = enabled
	for body: Variant in _solids:
		if is_instance_valid(body):
			body.collision_layer = 1 if enabled else 0
	for mesh: Variant in _replaced_steps:
		if is_instance_valid(mesh):
			mesh.visible = false if enabled else bool(_original_visibility.get(mesh.get_instance_id(),true))
	if not enabled:
		_interior_id = ""
	_apply_cutaway_views()


func _build_floor(parent: Node3D) -> void:
	_solid(parent,Vector3(5.40,.22,4.34),Vector3(0,FLOOR_HEIGHT-.11,0),"ContinuousFloor")
	# A visible stone slope replaces the original uncollided steps only in this
	# chapter. Its top and the physics wedge share the exact same vertices.
	var points := PackedVector3Array([
		Vector3(-.55,FLOOR_HEIGHT,RAMP_INNER), Vector3(.55,FLOOR_HEIGHT,RAMP_INNER),
		Vector3(-.55,0,RAMP_OUTER), Vector3(.55,0,RAMP_OUTER),
		Vector3(-.55,-.05,RAMP_INNER), Vector3(.55,-.05,RAMP_INNER),
		Vector3(-.55,-.05,RAMP_OUTER), Vector3(.55,-.05,RAMP_OUTER),
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in [0,2,1,1,2,3, 0,4,2,2,4,6, 1,3,5,3,7,5, 0,1,4,1,5,4, 2,6,3,3,6,7]:
		surface.add_vertex(points[index])
	surface.generate_normals()
	var ramp := MeshInstance3D.new()
	ramp.name = "StoneEntranceSlope"
	ramp.mesh = surface.commit()
	ramp.material_override = _materials.stone
	parent.add_child(ramp)
	var body := StaticBody3D.new()
	body.name = "EntranceSlopeBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var geometry := ConvexPolygonShape3D.new()
	geometry.points = points
	shape.shape = geometry
	body.add_child(shape)
	parent.add_child(body)
	_solids.append(body)
	# Match the authored 1.12 m frame rather than the broader rough-wall gap.
	for side in [-1,1]:
		_solid(parent,Vector3(.13,2.12,.22),Vector3(side*.625,FLOOR_HEIGHT+1.06,2.38),"DoorJamb")
	_solid(parent,Vector3(1.38,.18,.23),Vector3(0,2.57,2.38),"DoorLintel")
	# Existing original furniture is retained and receives matching collision.
	_solid(parent,Vector3(1.45,.84,.98),Vector3(-1.1,FLOOR_HEIGHT+.42,-.61),"OriginalTable")
	_solid(parent,Vector3(.5,.52,1.9),Vector3(1.93,FLOOR_HEIGHT+.26,0),"OriginalBench")
	_solid(parent,Vector3(.14,2.08,1.10),Vector3(-.67,FLOOR_HEIGHT+1.06,1.61),"OpenDoorLeaf")


func _build_household(parent: Node3D, id: String) -> void:
	var props := Node3D.new()
	props.name = "HouseholdObjects"
	parent.add_child(props)
	if id == "smith":
		_box(props,Vector3(1.7,.82,.72),Vector3(.55,FLOOR_HEIGHT+.41,-1.55),"wood","SmithWorkbench",true)
		_box(props,Vector3(.64,.18,.29),Vector3(.55,FLOOR_HEIGHT+.91,-1.55),"iron","Anvil",false)
		_box(props,Vector3(.13,.16,.48),Vector3(.55,FLOOR_HEIGHT+.82,-1.55),"iron","AnvilFoot",false)
		for index in 3:
			_box(props,Vector3(.055,.045,.43),Vector3(.05+index*.20,FLOOR_HEIGHT+.85,-1.51),"wood","ToolHandle%d"%index,false)
			_box(props,Vector3(.15,.08,.08),Vector3(.05+index*.20,FLOOR_HEIGHT+.88,-1.69),"iron","ToolHead%d"%index,false)
		_jar(props,Vector3(-2.24,FLOOR_HEIGHT,-1.68),.26,.58,"WaterForWork",true)
		_work_cover = _box(props,Vector3(.78,.025,.43),Vector3(.55,FLOOR_HEIGHT+1.015,-1.55),"dark","UnusedAnvilCover",false)
		_work_cover.hide()
	else:
		_box(props,Vector3(2.02,.29,.84),Vector3(.67,FLOOR_HEIGHT+.145,-1.62),"wood","FamilyBed",true)
		_box(props,Vector3(1.96,.13,.79),Vector3(.67,FLOOR_HEIGHT+.355,-1.62),"linen","SleepingBedding",false)
		_box(props,Vector3(.39,.13,.69),Vector3(1.36,FLOOR_HEIGHT+.47,-1.62),"linen","Pillow",false)
		_box(props,Vector3(1.24,.07,.72),Vector3(-1.69,FLOOR_HEIGHT+.035,-1.62),"linen","ChildSleepingMat",false)
		_jar(props,Vector3(-2.22,FLOOR_HEIGHT,-1.72),.21,.52,"StoredGrain",false)
		for index in 3:
			var loaf := Art.sphere(props,.13,Vector3(-1.47+index*.29,FLOOR_HEIGHT+.91,-.77),_materials.grain,Vector3(1,.42,.66))
			loaf.name = "Bread%d"%index
			_details.append(loaf)
	_jar(props,Vector3(-1.55,FLOOR_HEIGHT+.865,-.32),.12,.28,"DrinkingJug",true)
	_cup(props,Vector3(-.88,FLOOR_HEIGHT+.872,-.31),"DrinkingCup")
	var plate := Art.cylinder(props,.17,.027,Vector3(-.56,FLOOR_HEIGHT+.875,-.78),_materials.clay,.18)
	plate.name = "EatingDish"
	_details.append(plate)
	_box(props,Vector3(.60,.55,.65),Vector3(2.16,FLOOR_HEIGHT+.275,-1.62),"wood","HouseholdStore",true)
	_box(props,Vector3(.57,.06,.62),Vector3(2.16,FLOOR_HEIGHT+.58,-1.62),"linen","StoreCover",false)
	if id in ["family","smith"]:
		var memorial := Node3D.new()
		memorial.name = "HouseholdMemorial"
		memorial.position = Vector3(1.48,0,3.02)
		parent.add_child(memorial)
		_box(memorial,Vector3(.56,.14,.34),Vector3(0,.07,0),"stone","MemorialStone",false)
		_cup(memorial,Vector3(0,.14,0),"RemembranceCup")
		var words := Art.label(memorial,"",Vector3(0,.64,0),Color("d6c49c"),23)
		words.name = "Names"
		words.visibility_range_end = 7.0
		words.pixel_size = .0025
		memorial.hide()
		_memorials[id] = memorial


func _box(parent: Node3D,size: Vector3,at: Vector3,paint: String,label: String,solid: bool) -> MeshInstance3D:
	var item := Art.box(parent,size,at,_materials[paint])
	item.name = label
	_details.append(item)
	if solid:
		_solid(parent,size,at,label+"Body")
	return item


func _solid(parent: Node3D,size: Vector3,at: Vector3,label: String) -> StaticBody3D:
	var body := Art.box_collider(parent,size,at)
	body.name = label
	_solids.append(body)
	return body


func _jar(parent: Node3D,at: Vector3,radius: float,height: float,label: String,water: bool) -> void:
	var root := Node3D.new()
	root.name = label
	root.position = at
	parent.add_child(root)
	var pot := Art.sphere(root,radius,Vector3(0,height*.43,0),_materials.clay,Vector3(1,height*.43/radius,1))
	_details.append(pot)
	_details.append(Art.cylinder(root,radius*.44,height*.25,Vector3(0,height*.86,0),_materials.clay,radius*.48))
	_details.append(Art.cylinder(root,radius*.36,.012,Vector3(0,height*.985,0),_materials.water if water else _materials.grain))
	var handle := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius*.16
	torus.outer_radius = radius*.29
	torus.rings = 12
	torus.ring_segments = 6
	handle.mesh = torus
	handle.material_override = _materials.clay
	handle.rotation.x = PI/2
	handle.position = Vector3(radius*.74,height*.73,0)
	root.add_child(handle)
	_details.append(handle)


func _cup(parent: Node3D,at: Vector3,label: String) -> void:
	var cup := Art.cylinder(parent,.063,.11,at+Vector3.UP*.055,_materials.clay,.078)
	cup.name = label
	_details.append(cup)
	_details.append(Art.cylinder(parent,.064,.01,at+Vector3.UP*.108,_materials.water))


func set_quality(profile: String) -> void:
	var distance := float({"low":20.0,"balanced":34.0,"high":48.0,"very_high":60.0}.get(profile,34.0))
	for detail: Variant in _details:
		if is_instance_valid(detail):
			detail.visibility_range_end = distance
			detail.visibility_range_end_margin = 2.0


func update_view(player_position: Vector3) -> void:
	_interior_id = house_at(Vector2(player_position.x,player_position.z)) if enabled else ""
	_apply_cutaway_views()


func _apply_cutaway_views() -> void:
	for id: String in _roofs:
		for roof: Variant in _roofs[id]:
			if is_instance_valid(roof):
				roof.visible = false if id == _interior_id else bool(_original_visibility.get(roof.get_instance_id(),true))
	for id: String in _shells:
		for item: Dictionary in _shells[id]:
			if not is_instance_valid(item.source):
				continue
			var source: MeshInstance3D = item.source
			var inside := enabled and id == _interior_id
			var originally_visible := bool(_original_visibility.get(source.get_instance_id(),true))
			source.visible = originally_visible and (not enabled or (not inside and not item.steps))
			if is_instance_valid(item.outer): item.outer.visible = originally_visible and enabled and not inside
			if is_instance_valid(item.inner): item.inner.visible = originally_visible and inside


static func house_at(point: Vector2) -> String:
	for id: String in HOMES:
		var local := _to_local(id,Vector3(point.x,0,point.y))
		if absf(local.x) < 2.68 and local.z > -2.17 and local.z < 2.17:
			return id
	return ""


static func floor_height_at(point: Vector2) -> float:
	if not house_at(point).is_empty():
		return FLOOR_HEIGHT
	for id: String in HOMES:
		var local := _to_local(id,Vector3(point.x,0,point.y))
		if absf(local.x) < .55 and local.z >= RAMP_INNER and local.z <= RAMP_OUTER:
			return FLOOR_HEIGHT*(RAMP_OUTER-local.z)/(RAMP_OUTER-RAMP_INNER)
	return 0.0


static func resident_floor_height_at(point: Vector2, radius: float = .29) -> float:
	# A round capsule is supported slightly above the plane's value on a ramp,
	# and keeps contact with the raised floor while rolling over its front edge.
	# These are the same dimensions used by ContinuousFloor/EntranceSlopeBody.
	var height := floor_height_at(point)
	var slope := FLOOR_HEIGHT/(RAMP_OUTER-RAMP_INNER)
	for id: String in HOMES:
		var local := _to_local(id,Vector3(point.x,0,point.y))
		if absf(local.x) >= .55 or local.z < RAMP_INNER or local.z > RAMP_OUTER+radius:
			continue
		var floor_edge := maxf(0.0,local.z-2.17)
		if floor_edge < radius:
			height = maxf(height,FLOOR_HEIGHT-radius+sqrt(radius*radius-floor_edge*floor_edge))
		var contact_z := local.z-radius*slope/sqrt(1.0+slope*slope)
		if contact_z >= RAMP_INNER and contact_z <= RAMP_OUTER:
			var plane := FLOOR_HEIGHT*(RAMP_OUTER-local.z)/(RAMP_OUTER-RAMP_INNER)
			height = maxf(height,plane+radius*(sqrt(1.0+slope*slope)-1.0))
	return height


static func entrance_position(id: String) -> Vector3:
	return _to_world(id,Vector3(0,0,3.65)) if HOMES.has(id) else Vector3.INF


static func navigation_target(player: Vector3,target: Vector3) -> Vector3:
	var player_home := house_at(Vector2(player.x,player.z))
	var target_home := house_at(Vector2(target.x,target.z))
	if not player_home.is_empty() and player_home == target_home:
		return target
	# Leave through the inner door centre first, including when the next goal is
	# a different house. A direction straight to the outside would point at a wall.
	if not player_home.is_empty():
		var inner := _to_world(player_home,Vector3(0,FLOOR_HEIGHT,1.70))
		return inner if Vector2(player.x-inner.x,player.z-inner.z).length() > .60 else entrance_position(player_home)
	for id: String in HOMES:
		var local := _to_local(id,player)
		if absf(local.x) < .60 and local.z >= 2.17 and local.z < 3.60:
			return _to_world(id,Vector3(0,FLOOR_HEIGHT,1.65)) if target_home == id else entrance_position(id)
	if not target_home.is_empty():
		var entrance := entrance_position(target_home)
		if Vector2(player.x-entrance.x,player.z-entrance.z).length() > .65:
			return entrance
		return _to_world(target_home,Vector3(0,FLOOR_HEIGHT,1.65))
	return target


static func _to_local(id: String,point: Vector3) -> Vector3:
	return (point-HOMES[id].at).rotated(Vector3.UP,-float(HOMES[id].yaw))


static func _to_world(id: String,point: Vector3) -> Vector3:
	return HOMES[id].at+point.rotated(Vector3.UP,float(HOMES[id].yaw))


func _restore_roofs() -> void:
	for items: Array in _roofs.values():
		for mesh: Variant in items:
			if is_instance_valid(mesh):
				mesh.visible = bool(_original_visibility.get(mesh.get_instance_id(),true))


func _restore_visuals() -> void:
	_restore_roofs()
	for items: Array in _shells.values():
		for item: Dictionary in items:
			if is_instance_valid(item.source): item.source.visible = bool(_original_visibility.get(item.source.get_instance_id(),true))
			if is_instance_valid(item.outer): item.outer.hide()
			if is_instance_valid(item.inner): item.inner.hide()
	for mesh: Variant in _replaced_steps:
		if is_instance_valid(mesh):
			mesh.visible = bool(_original_visibility.get(mesh.get_instance_id(),true))


func snapshot() -> Dictionary:
	var paths: Dictionary = {}
	for id: String in homes:
		paths[id] = {"household_node":HOMES[id].node,"entrance":entrance_position(id),"floor":FLOOR_HEIGHT,"door_width":DOOR_WIDTH,"roof_hidden":id==_interior_id}
	return {"enabled":enabled,"houses":paths,"new_residents":0,"collision_bodies":_solids.size()}


func _exit_tree() -> void:
	_restore_visuals()
