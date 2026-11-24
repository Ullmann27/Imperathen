extends Node3D
## Stable residents and authored routines. No production, recruitment or narrative rewards.

const Layout = preload("res://scripts/world/village/village_layout.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const Art = preload("res://scripts/world/village_art.gd")
const Behavior = preload("res://scripts/domain/npc_behavior.gd")
const LocalNavigation = preload("res://scripts/world/village/village_local_navigation.gd")
const SOCIAL_DISTANCE := 1.3
const SOCIAL_RANGE := 5.0
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
var _behavior_state: Dictionary = {}
var _behavior_world := ""
var _behavior_restore := false
var _behavior_seconds := 0.0
var _route_distances: Dictionary = {}
var _route_directions: Dictionary = {}
# Runtime-only path cache; the existing saved physical position is authoritative.
var _local_paths: Dictionary = {}


func sync_behavior(data: Dictionary) -> void:
	var next_world := str(data.get("world_id",""))
	var next_time := float(data.get("world_seconds",0.0))
	_behavior_restore = _behavior_restore or next_world != _behavior_world or next_time+0.000001 < _behavior_seconds
	_behavior_world = next_world
	_behavior_seconds = next_time
	_behavior_state = data


func behavior_observations() -> Dictionary:
	var result := {}
	for id: String in actors:
		var actor: Node3D = actors[id]
		if not actor.visible:
			continue
		var point := actor.global_position
		result[id] = {"position":[point.x,point.y,point.z],"route_distance":float(_route_distances.get(id,0.0)),"route_direction":int(_route_directions.get(id,1))}
	return result

func show_origin(id: String, time: float, recruited_count: int) -> void:
	var rebuild := origin_id != id
	if origin_id != id:
		origin_id = id
		for actor: Node3D in actors.values():
			remove_child(actor)
			actor.free()
		actors.clear()
		_route_clocks.clear()
		_route_distances.clear()
		_route_directions.clear()
		_local_paths.clear()
		_initialized = false
		if id == "italia":
			for index in Layout.RESIDENTS.size():
				_add_resident(Layout.RESIDENTS[index],index)
	set_recruited(recruited_count)
	advance_to(time,rebuild or not _initialized or _behavior_restore)
	_behavior_restore = false

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
	if force or elapsed < 0.0 or elapsed > 2.0 and not Behavior.enabled(_behavior_state):
		_place_routines(next_time)
		seconds = next_time
		return
	seconds = next_time
	if elapsed <= 0.0:
		return
	if Behavior.enabled(_behavior_state):
		_advance_behavior(minf(elapsed,0.25))
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


func _advance_behavior(elapsed: float) -> void:
	for item: Dictionary in Layout.RESIDENTS:
		var id: String = item.id
		if not actors.has(id):
			continue
		var actor: CharacterBody3D = actors[id]
		if not actor.visible or focused_id == id:
			continue
		var intent := Behavior.view(_behavior_state,id)
		if intent.is_empty():
			continue
		var activity: String = intent.activity
		var route := _route_points(item)
		var total := _route_length(route)
		var distance := clampf(float(_route_distances.get(id,0.0)),0.0,total)
		var goal := distance
		var local_target := Vector3.INF
		var local_mode := ""
		var social_arrived := false
		if activity in ["work","weather_pause"]:
			goal = 0.0
		elif activity in ["socialize","explore"]:
			goal = total
			var peer: String = intent.partner
			if activity == "socialize" and not peer.is_empty():
				# A selected partner is a real destination, not a projection
				# onto an unrelated personal route. Fixed service actors stay put.
				goal = distance
				local_mode = "peer"
				if total > .01 and _behavior_state.village.behavior.people.has(peer):
					var other: Dictionary = _behavior_state.village.behavior.people[peer]
					if other.observed and other.activity not in ["absent","flee","alert","assist"]:
						var point: Array = other.position
						var peer_at := Vector3(float(point[0]),actor.global_position.y,float(point[2]))
						var offset := peer_at-actor.global_position
						if offset.length() <= SOCIAL_RANGE:
							social_arrived = offset.length() <= SOCIAL_DISTANCE+.12
							if not social_arrived:
								local_target = peer_at-offset.normalized()*SOCIAL_DISTANCE
		elif activity == "patrol":
			var direction := int(_route_directions.get(id,1))
			if direction > 0 and distance >= total-.08:
				direction = -1
			elif direction < 0 and distance <= .08:
				direction = 1
			_route_directions[id] = direction
			goal = total if direction > 0 else 0.0
		elif activity == "flee":
			goal = _flee_goal(route,total)
		var speed := 1.8 if activity == "flee" else 0.9+float(Layout.RESIDENTS.find(item)%5)*0.06
		var next_distance := move_toward(distance,goal,speed*elapsed)
		var target := _route_point(route,next_distance)
		var motion := Vector3.ZERO
		# After a social detour, safely rejoin the original corridor before
		# resuming work, exploration or patrol. Never snap to the route.
		if local_mode.is_empty() and total > .01 and activity in ["work","weather_pause","explore","socialize","patrol","flee"]:
			var rejoin := to_global(_route_point(route,distance))
			var cached: Dictionary = _local_paths.get(id,{})
			if cached.get("mode","") == "rejoin":
				rejoin = cached.target
			var gap := actor.global_position.distance_to(rejoin)
			if gap > .72 or cached.get("mode","") == "rejoin" and gap > LocalNavigation.ARRIVAL:
				local_mode = "rejoin"
				local_target = rejoin
		if not local_mode.is_empty():
			if local_target != Vector3.INF:
				motion = _local_motion(id,actor,local_target,local_mode,speed,elapsed)
			else:
				_local_paths.erase(id)
		elif activity == "yield":
			_local_paths.erase(id)
			var away := actor.global_position-_player_position
			away.y = 0.0
			if away.length_squared() > .0001:
				motion = away.normalized()*.65*elapsed
				# Courtesy never pushes a resident arbitrarily far from the safe
				# authored corridor or through a wall.
				if (actor.position+motion-_route_point(route,distance)).length() > .72:
					motion = Vector3.ZERO
		elif activity not in ["rest","greet","space","alert","assist","absent"] and total > .01:
			_local_paths.erase(id)
			motion = (target-actor.position).limit_length(speed*elapsed)
			motion.y = 0.0
		else:
			_local_paths.erase(id)
		var before := actor.position
		var hit: KinematicCollision3D
		if motion.length_squared() > .00000001:
			hit = actor.move_and_collide(motion)
		if hit != null:
			if not local_mode.is_empty() and _local_paths.has(id):
				# A new obstacle may invalidate a cached path. Wait briefly
				# rather than spending the entire frame budget replanning.
				_local_paths[id].waypoints = []
				_local_paths[id].retry = seconds+.6
			var blocker := hit.get_collider() as CollisionObject3D
			if local_mode.is_empty() and blocker != null and (blocker.collision_layer & (2 | Layout.CITIZEN_LAYER)) != 0:
				var side := Vector3(-motion.z,0,motion.x).normalized()*.45*elapsed
				if (actor.position+side-_route_point(route,distance)).length() < .72 and not actor.test_move(actor.global_transform,side):
					actor.move_and_collide(side)
		var travelled := actor.position-before
		var actual_speed := travelled.length()/maxf(.0001,elapsed)
		_route_distances[id] = _route_projection(route,actor.position)
		var figure: Node3D = actor.get_node("Figure")
		figure.drive(actual_speed)
		if actual_speed > .05:
			actor.rotation.y = lerp_angle(actor.rotation.y,atan2(-travelled.x,-travelled.z),minf(1.0,elapsed*7.0))
		elif activity in ["greet","space","socialize","alert","assist"]:
			_face_interest(actor,intent,elapsed)
		if activity == "work" and actual_speed < .05 and actor.position.distance_to(item.at) < .15:
			figure.keep_working()
		elif activity == "socialize" and social_arrived and actual_speed < .05:
			var peer: String = intent.partner
			var other: Dictionary = _behavior_state.village.behavior.people.get(peer,{})
			if other.get("activity","") == "socialize" and other.get("partner","") == id:
				figure.keep_talking()
			elif not actor.get_meta("social_arrived",false):
				figure.cue("talk")
		elif actor.get_meta("intent","") != activity and activity in ["greet","space"]:
			figure.cue("talk")
		actor.set_meta("social_arrived",social_arrived)
		actor.set_meta("intent",activity)
		actor.set_meta("activity","march" if actual_speed > .05 else activity)
		actor.set_meta("yielding",hit != null or activity == "yield" or local_target != Vector3.INF and motion.length_squared() < .00000001)


func _local_motion(id: String, actor: CharacterBody3D, target: Vector3, mode: String, speed: float, elapsed: float) -> Vector3:
	var entry: Dictionary = _local_paths.get(id,{})
	if entry.is_empty() or entry.get("mode","") != mode:
		entry = {"mode":mode,"target":target,"waypoints":[],"retry":seconds}
		_local_paths[id] = entry
	var goal_changed: bool = target.distance_to(entry.target) > .45
	if seconds >= float(entry.retry) and (goal_changed or entry.waypoints.is_empty()):
		entry.target = target
		entry.waypoints = LocalNavigation.plan(actor,target)
		entry.retry = seconds+.6
	var waypoints: Array = entry.waypoints
	while not waypoints.is_empty() and actor.global_position.distance_to(waypoints.front()) <= LocalNavigation.ARRIVAL:
		waypoints.pop_front()
	if waypoints.is_empty():
		return Vector3.ZERO
	var next: Vector3 = waypoints.front()
	var motion := (next-actor.global_position).limit_length(speed*elapsed)
	motion.y = 0.0
	return motion


func _face_interest(actor: Node3D, intent: Dictionary, elapsed: float) -> void:
	var target := _player_position
	var peer := str(intent.get("partner",""))
	if _behavior_state.village.behavior.people.has(peer) and bool(_behavior_state.village.behavior.people[peer].observed):
		var point: Array = _behavior_state.village.behavior.people[peer].position
		target = Vector3(float(point[0]),float(point[1]),float(point[2]))
	elif intent.activity in ["alert","assist"]:
		var danger := _nearest_threat(actor.position)
		if danger != Vector3.INF:
			target = danger
	var offset := target-actor.global_position
	if Vector2(offset.x,offset.z).length() > .1:
		actor.rotation.y = lerp_angle(actor.rotation.y,atan2(-offset.x,-offset.z),minf(1.0,elapsed*4.0))


func _nearest_threat(point: Vector3) -> Vector3:
	var nearest := Vector3.INF
	var best := INF
	for enemy: Dictionary in _behavior_state.get("village",{}).get("raid",{}).get("enemies",[]):
		if int(enemy.get("health",0)) <= 0:
			continue
		var at := Vector3(float(enemy.x),0,float(enemy.z))
		if point.distance_squared_to(at) < best:
			best = point.distance_squared_to(at)
			nearest = at
	return nearest


func _flee_goal(route: Array[Vector3], total: float) -> float:
	var start := _route_point(route,0.0)
	var end := _route_point(route,total)
	var start_threat := _nearest_threat(start)
	var end_threat := _nearest_threat(end)
	if start_threat == Vector3.INF or end_threat == Vector3.INF:
		return 0.0
	return total if end.distance_squared_to(end_threat) > start.distance_squared_to(start_threat) else 0.0


func _route_points(item: Dictionary) -> Array[Vector3]:
	var points: Array[Vector3] = [item.at]
	for point: Vector3 in item.route:
		points.append(point)
	return points


func _route_length(points: Array[Vector3]) -> float:
	var length := 0.0
	for index in range(1,points.size()):
		length += points[index-1].distance_to(points[index])
	return length


func _route_point(points: Array[Vector3], distance: float) -> Vector3:
	for index in range(1,points.size()):
		var edge := points[index]-points[index-1]
		var length := edge.length()
		if distance <= length and length > .0001:
			return points[index-1]+edge*(distance/length)
		distance -= length
	return points.back()


func _route_projection(points: Array[Vector3], point: Vector3) -> float:
	var best := INF
	var chosen := 0.0
	var accumulated := 0.0
	for index in range(1,points.size()):
		var edge := points[index]-points[index-1]
		var length := edge.length()
		if length < .0001:
			continue
		var along := clampf((point-points[index-1]).dot(edge)/(length*length),0.0,1.0)
		var projected := points[index-1]+edge*along
		var difference := point.distance_squared_to(projected)
		if difference < best:
			best = difference
			chosen = accumulated+along*length
		accumulated += length
	return chosen


func _place_routines(time: float) -> void:
	_initialized = true
	_local_paths.clear()
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
		if Behavior.enabled(_behavior_state):
			var intent := Behavior.view(_behavior_state,item.id)
			pose.position = item.at
			pose.activity = intent.get("activity","idle")
			if intent.get("observed",false):
				var saved: Array = intent.position
				pose.position = Vector3(float(saved[0]),float(saved[1]),float(saved[2]))
			_route_distances[item.id] = float(intent.get("route_distance",0.0))
			_route_directions[item.id] = int(_behavior_state.village.behavior.people[item.id].get("route_direction",1))
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
	var result := {"id":id,"name":definition.name,"occupation":definition.occupation,"greeting":definition.greeting,"position":actor_position(id)}
	var intent := Behavior.view(_behavior_state,id)
	if not intent.is_empty():
		result.behavior = intent
	return result

func focus(id: String, viewer: Vector3) -> bool:
	if not actors.has(id) or not actors[id].visible:
		return false
	if focused_id != id:
		clear_focus()
	focused_id = id
	var actor: Node3D = actors[id]
	var offset := viewer-actor.global_position
	if Vector2(offset.x,offset.z).length() > .1:
		actor.rotation.y = atan2(-offset.x,-offset.z)
	actor.get_node("Figure").set_conversation_focus(true)
	return true

func clear_focus() -> void:
	if not focused_id.is_empty() and actors.has(focused_id):
		actors[focused_id].get_node("Figure").set_conversation_focus(false)
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
