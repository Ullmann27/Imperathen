extends Node3D
## Stable residents and authored routines. No production, recruitment or narrative rewards.

const Layout = preload("res://scripts/world/village/village_layout.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const Art = preload("res://scripts/world/village_art.gd")
var actors: Dictionary = {}
var origin_id := ""
var active := false
var seconds := 0.0
var profile := "balanced"
var focused_id := ""
var recruited := 0
var _player_position := Vector3.ZERO
var _route_clocks: Dictionary = {}
var _initialized := false

func show_origin(id: String, time: float, recruited_count: int) -> void:
	var rebuild := origin_id != id
	if origin_id != id:
		origin_id = id
		for actor: Node3D in actors.values():
			remove_child(actor)
			actor.free()
		actors.clear()
		_route_clocks.clear()
		_initialized = false
		if id == "italia":
			for index in Layout.RESIDENTS.size():
				_add_resident(Layout.RESIDENTS[index],index)
	set_recruited(recruited_count)
	advance_to(time,rebuild or not _initialized)

func _add_resident(item: Dictionary, index: int) -> void:
	var actor := CharacterBody3D.new()
	actor.name = item.id
	actor.position = item.at
	actor.collision_layer = Layout.CITIZEN_LAYER
	actor.collision_mask = 1 | 2 | Layout.CITIZEN_LAYER
	actor.safe_margin = .006
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = Layout.CITIZEN_RADIUS
	capsule.height = 1.72
	shape.shape = capsule
	shape.position.y = .90
	shape.name = "PersonalSpace"
	actor.add_child(shape)
	actor.set_meta("resident_id",item.id)
	actor.set_meta("occupation",item.occupation)
	add_child(actor)
	var figure := Person.new()
	figure.name = "Figure"
	figure.position.y = .9
	figure.profile = profile
	actor.add_child(figure)
	figure.configure_resident("italia",int(item.age),item.appearance,index,get_viewport().get_camera_3d())
	var nameplate := Art.label(actor,item.name+" · "+item.occupation,Vector3(0,2.05,0),Color("#efdbad"),29)
	nameplate.name = "Nameplate"
	nameplate.pixel_size = .003
	nameplate.visibility_range_begin = 3.0
	nameplate.visibility_range_end = 7.0
	nameplate.hide()
	actors[item.id] = actor

func set_recruited(count: int) -> void:
	recruited = clampi(count,0,Layout.VOLUNTEERS.size())
	for id: String in actors:
		var index := Layout.VOLUNTEERS.find(id)
		actors[id].visible = index < 0 or index >= recruited
		actors[id].collision_layer = Layout.CITIZEN_LAYER if actors[id].visible else 0

func set_quality(next_profile: String) -> void:
	if next_profile not in ["low","balanced","high","very_high"]:
		return
	profile = next_profile
	for actor: Node3D in actors.values():
		actor.get_node("Figure").profile = profile
		actor.get_node("Figure").refresh_lod(get_viewport().get_camera_3d())

func set_active(enabled: bool) -> void:
	active = enabled
	if not active:
		for actor: Node3D in actors.values():
			actor.get_node("Figure").drive(0.0)
			actor.get_node("Nameplate").hide()

func advance_to(time: float, force := false) -> void:
	if not active and not force:
		return
	var next_time := maxf(0.0,time)
	var elapsed := next_time-seconds
	# Loading a saved time is an explicit placement operation. Ordinary play
	# never teleports along the routine: each displacement is swept by physics.
	if force or elapsed < 0.0 or elapsed > 2.0:
		_place_routines(next_time)
		seconds = next_time
		return
	seconds = next_time
	if elapsed <= 0.0:
		return
	for index in Layout.RESIDENTS.size():
		var item: Dictionary = Layout.RESIDENTS[index]
		if not actors.has(item.id):
			continue
		var actor: CharacterBody3D = actors[item.id]
		if not actor.visible or focused_id == item.id:
			continue
		var clock := float(_route_clocks.get(item.id,seconds-elapsed))
		var previous: Dictionary = Layout.pose_at(item,clock,index)
		# A blocked resident waits for space rather than allowing its invisible
		# schedule to run far ahead and cutting across a house on the next turn.
		if actor.position.distance_to(previous.position) < .42:
			clock += elapsed
		_route_clocks[item.id] = clock
		var pose: Dictionary = Layout.pose_at(item,clock,index)
		var target: Vector3 = pose.position
		var motion := (target-actor.position).limit_length((.82+float(index%5)*.085)*elapsed)
		motion.y = 0
		var before := actor.position
		var hit: KinematicCollision3D
		if motion.length_squared() > .00000001:
			hit = actor.move_and_collide(motion)
		if hit != null:
			var blocker := hit.get_collider() as CollisionObject3D
			# Give way to a person using a short tested sideways step. An actual
			# wall is never bypassed by assigning a new transform through it.
			if blocker != null and (blocker.collision_layer & (2 | Layout.CITIZEN_LAYER)) != 0:
				var side := Vector3(-motion.z,0,motion.x).normalized() * .62 * elapsed
				if not actor.test_move(actor.global_transform,side):
					actor.move_and_collide(side)
		actor.set_meta("yielding",hit != null)
		var travelled := actor.position-before
		var actual_speed := travelled.length()/maxf(.0001,elapsed)
		if travelled.length_squared() > .00000001:
			actor.rotation.y = lerp_angle(actor.rotation.y,atan2(-travelled.x,-travelled.z),minf(1.0,elapsed*8.0))
		var figure: Node3D = actor.get_node("Figure")
		figure.drive(actual_speed)
		if pose.activity == "work" and actual_speed < .05:
			figure.keep_working()
		actor.set_meta("activity","march" if actual_speed > .05 else pose.activity)


func _place_routines(time: float) -> void:
	_initialized = true
	var occupied: Array[Vector3] = []
	var excluded: Array[RID] = []
	for actor: CharacterBody3D in actors.values():
		excluded.append(actor.get_rid())
	for index in Layout.RESIDENTS.size():
		var item: Dictionary = Layout.RESIDENTS[index]
		if not actors.has(item.id):
			continue
		var actor: CharacterBody3D = actors[item.id]
		var pose := Layout.pose_at(item,time,index)
		actor.position = _free_start(pose.position,item.at,occupied,excluded)
		_route_clocks[item.id] = time
		if actor.visible:
			occupied.append(actor.position)
		actor.set_meta("activity",pose.activity)
		actor.set_meta("yielding",false)
		actor.get_node("Figure").drive(0.0)


func _free_start(desired: Vector3, origin: Vector3, occupied: Array[Vector3], excluded: Array[RID]) -> Vector3:
	var candidates: Array[Vector3] = [desired]
	for radius in [.7,1.15,1.8]:
		for index in 8:
			var angle := TAU*index/8.0
			candidates.append(desired+Vector3(cos(angle),0,sin(angle))*radius)
	candidates.append(origin)
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = Layout.CITIZEN_RADIUS
	capsule.height = 1.72
	query.shape = capsule
	query.collision_mask = 1 | 2 | Layout.CITIZEN_LAYER
	query.exclude = excluded
	for point: Vector3 in candidates:
		var clear := true
		for other: Vector3 in occupied:
			if point.distance_to(other) < Layout.CITIZEN_RADIUS*2+.04:
				clear = false
				break
		if not clear:
			continue
		query.transform = Transform3D(Basis.IDENTITY,point+Vector3.UP*.90)
		if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
			return point
	push_error("No clear resident spawn beside %s" % desired)
	return origin

func update_nearby(player_position: Vector3, show_labels: bool) -> void:
	_player_position = player_position
	var closest := nearest_npc(player_position,5.0)
	var camera := get_viewport().get_camera_3d()
	for id: String in actors:
		var actor: Node3D = actors[id]
		var label := actor.get_node("Nameplate") as Label3D
		label.visible = false
		if not show_labels or not actor.visible or id != closest or not focused_id.is_empty() or camera == null:
			continue
		# The radial range alone allows a nearby side label to cross the camera's
		# near plane at enormous size. Match the inhabited-village depth guard.
		var camera_position := camera.global_transform.affine_inverse() * label.global_position
		label.visible = -camera_position.z >= 3.0 and camera_position.length() <= 7.0

func nearest_npc(position: Vector3, radius: float) -> String:
	var best := ""
	var distance := radius+1.0
	for id: String in actors:
		var actor: Node3D = actors[id]
		if not actor.visible:
			continue
		var value := Vector2(position.x,position.z).distance_to(Vector2(actor.global_position.x,actor.global_position.z))
		if value > radius:
			continue
		# A passer-by should not steal a nearly equal-range conversation with the
		# stationary person at a desk or shop. Close residents still take priority.
		var priority := value-(.35 if id in ["livia","cassian","aulus","titus"] else 0.0)
		if priority < distance:
			distance = priority
			best = id
	return best

func actor_position(id: String) -> Vector3:
	return (actors[id] as Node3D).global_position if actors.has(id) else Vector3.INF

func info(id: String) -> Dictionary:
	var definition := Layout.resident(id)
	if definition.is_empty() or not actors.has(id) or not actors[id].visible:
		return {}
	return {"id":id,"name":definition.name,"occupation":definition.occupation,"greeting":definition.greeting,"position":actor_position(id)}

func focus(id: String, viewer: Vector3) -> bool:
	if not actors.has(id) or not actors[id].visible:
		return false
	focused_id = id
	var actor: Node3D = actors[id]
	var offset := viewer-actor.global_position
	if Vector2(offset.x,offset.z).length() > .1:
		actor.rotation.y = atan2(-offset.x,-offset.z)
	actor.get_node("Figure").drive(0.0)
	actor.get_node("Figure").cue("talk")
	return true

func clear_focus() -> void:
	if not focused_id.is_empty() and actors.has(focused_id):
		actors[focused_id].get_node("Figure").reset_motion()
	focused_id = ""

func set_wagon_work(enabled: bool) -> void:
	if enabled and active and actors.has("titus"):
		actors.titus.get_node("Figure").keep_working()

func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in actors:
		var actor: Node3D = actors[id]
		result.append({"id":id,"position":actor.position,"visible":actor.visible,"activity":actor.get_meta("activity","idle")})
	return result
