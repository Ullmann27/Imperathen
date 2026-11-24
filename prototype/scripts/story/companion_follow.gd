extends RefCounted
## Laufzeitnavigation für bestehende Figuren. Keine Spielstandsänderung und keine
## Positionszuweisung: alle Schritte gehen durch CharacterBody3D.move_and_slide.
## Das begrenzte Suchraster wird gegen echte Körper und begehbaren Boden geprüft.

const CELL := 0.6
const MAX_NODES := 4096
const EXPANSIONS_PER_TICK := 12
const SEARCH_MARGIN := 14.0
const MAX_DISTANCE := 128.0
const MAX_HEIGHT_CHANGE := 0.50
const GROUND_CLEARANCE := 0.006
# Kapselsweeps benötigen an Rampen und kleinen Abwärtskanten zusätzlichen
# Prüfabstand. Die Figur selbst wird dadurch nicht angehoben.
const SWEEP_CLEARANCE := 0.075
const GRAVITY := 19.6
const RETRY_SECONDS := 0.8
const WAYPOINT_DISTANCE := 0.12
const ARRIVAL_EPSILON := 0.004
const RETARGET_DISTANCE := 4.0
const RETARGET_INTERVAL := 0.4
const MAX_TURN_RATE := 4.5
const DIRECTIONS := [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1),
	Vector2i(1,1),Vector2i(-1,1),Vector2i(-1,-1),Vector2i(1,-1)]

var actual_speed := 0.0
var status := "idle"
var expanded_nodes := 0
var path: Array[Vector3] = []
var _searching := false
var _clock := 0.0
var _retry_at := 0.0
var _next_target_plan_at := 0.0
var _blocked_seconds := 0.0
var _goal := Vector3.ZERO
var _stop_distance := 1.7
var _origin := Vector3.ZERO
var _bounds := Rect2()
var _open: Array[Dictionary] = []
var _costs: Dictionary = {}
var _parents: Dictionary = {}
var _points: Dictionary = {}
var _closed: Dictionary = {}
var _ground_cache: Dictionary = {}
var _serial := 0
var _body_id := 0
var _foot_bottom := 0.04


func reset() -> void:
	actual_speed = 0.0
	status = "idle"
	path.clear()
	_searching = false
	_clock = 0.0
	_retry_at = 0.0
	_next_target_plan_at = 0.0
	_blocked_seconds = 0.0
	_clear_search()


func pause(body: CharacterBody3D) -> void:
	actual_speed = 0.0
	status = "paused"
	if is_instance_valid(body):
		body.velocity = Vector3.ZERO
		_publish(body)


func move(body: CharacterBody3D, target: Vector3, delta: float, speed := 3.8, stop_distance := 1.7) -> void:
	if not is_instance_valid(body) or not body.is_inside_tree():
		return
	if not target.is_finite() or not is_finite(delta) or delta <= 0.0 or not is_finite(speed) or speed < 0.0 or not is_finite(stop_distance) or stop_distance < 0.0:
		pause(body)
		return
	_clock += delta
	_bind_body(body)
	_retarget(target,stop_distance)
	var at := body.global_position
	var gap := _horizontal(at,target)
	var motion := Vector3.ZERO
	if gap > MAX_DISTANCE:
		status = "out_of_range"
		path.clear()
		_searching = false
	elif gap <= stop_distance+ARRIVAL_EPSILON and _visible_goal(body,at,target):
		status = "arrived"
		path.clear()
		_searching = false
		_blocked_seconds = 0.0
	else:
		# Ein freier kurzer Weg reagiert sofort auf einen gehenden Spieler.
		# Eine bereits gefundene Umgehung wird nicht durch dieselbe blockierte
		# Luftlinie ersetzt, die die Suche ursprünglich nötig gemacht hat.
		var direct := Vector3.INF
		if path.is_empty() and not _searching or gap < 6.0 and _visible_goal(body,at,target):
			direct = _direct_hop(body,at,target,stop_distance)
		if direct.is_finite():
			path.clear()
			_searching = false
			motion = direct-at
			status = "following"
		elif not path.is_empty():
			while not path.is_empty() and _horizontal(at,path.front()) <= WAYPOINT_DISTANCE:
				path.pop_front()
			if not path.is_empty():
				motion = path.front()-at
				status = "following"
			else:
				_retry_at = _clock
		if motion.length_squared() <= 0.000001:
			if not _searching and _clock >= _retry_at:
				_begin_search(body,target,stop_distance)
			if _searching:
				_advance_search(body)
			status = "planning" if _searching else ("following" if not path.is_empty() else "blocked")
			if not path.is_empty():
				motion = path.front()-at
		# Nur nach tatsächlichem Stillstand neu planen. Bewegte Ziele und
		# nachträglich versperrte Wege erlauben keinen Positionssprung.
		if _blocked_seconds >= 0.45:
			path.clear()
			_searching = false
			_retry_at = _clock
			_blocked_seconds = 0.0
	motion.y = 0.0
	var requested := minf(speed,motion.length()/delta)
	var direction := motion.normalized() if motion.length_squared() > 0.000001 else Vector3.ZERO
	body.velocity.x = direction.x*requested
	body.velocity.z = direction.z*requested
	body.velocity.y = -0.3 if body.is_on_floor() else maxf(-30.0,body.velocity.y-GRAVITY*delta)
	body.move_and_slide()
	var travelled := body.global_position-at
	actual_speed = Vector2(travelled.x,travelled.z).length()/delta
	if requested > 0.1 and actual_speed < 0.10:
		_blocked_seconds += delta
	elif actual_speed >= 0.10:
		_blocked_seconds = 0.0
	if actual_speed > 0.04:
		# This controller owns the physical body's heading. A constant angular
		# rate avoids the old frame-dependent second turn in CompanionWorld.
		body.rotation.y = rotate_toward(body.rotation.y,atan2(-travelled.x,-travelled.z),minf(delta,0.1)*MAX_TURN_RATE)
	_publish(body)


func _publish(body: CharacterBody3D) -> void:
	body.set_meta("companion_speed",actual_speed)
	body.set_meta("companion_navigation",status)
	body.set_meta("yielding",status in ["blocked","planning","out_of_range"] or _blocked_seconds > 0.0)


func _bind_body(body: CharacterBody3D) -> void:
	if _body_id == body.get_instance_id():
		return
	_body_id = body.get_instance_id()
	_foot_bottom = 0.04
	for node: Node in body.get_children():
		if node is CollisionShape3D and node.shape is CapsuleShape3D:
			_foot_bottom = node.position.y-float(node.shape.height)*0.5
			break
	path.clear()
	_searching = false
	_retry_at = _clock
	_next_target_plan_at = _clock


func _retarget(target: Vector3, stop_distance: float) -> void:
	if not _searching and path.is_empty() and status != "blocked":
		return
	if _horizontal(_goal,target) < RETARGET_DISTANCE and absf(_stop_distance-stop_distance) < 0.25:
		return
	# Ein neuer Rückweg oder Haltepunkt darf keinen Rest der alten Umgehung
	# ausführen. Kleine Positionsänderungen eines gehenden Spielers lassen
	# die Suche dagegen weiterarbeiten; Neuansätze sind zeitlich begrenzt.
	path.clear()
	_searching = false
	_clear_search()
	_goal = target
	_stop_distance = stop_distance
	_blocked_seconds = 0.0
	_retry_at = maxf(_clock,_next_target_plan_at)


func _direct_hop(body: CharacterBody3D, start: Vector3, target: Vector3, stop_distance: float) -> Vector3:
	var horizontal := Vector3(target.x-start.x,0.0,target.z-start.z)
	var length := maxf(0.0,horizontal.length()-stop_distance)
	if length <= ARRIVAL_EPSILON:
		return Vector3.INF
	var desired := start+horizontal.normalized()*minf(4.0,length)
	var point := _ground_point(body,desired,start.y)
	return point if point.is_finite() and _walk_leg(body,start,point) else Vector3.INF


func _begin_search(body: CharacterBody3D, target: Vector3, stop_distance: float) -> void:
	_clear_search()
	path.clear()
	_origin = body.global_position
	_goal = target
	_stop_distance = stop_distance
	_next_target_plan_at = _clock+RETARGET_INTERVAL
	var a := Vector2(_origin.x,_origin.z)
	var b := Vector2(target.x,target.z)
	_bounds = Rect2(a,Vector2.ZERO).expand(b).grow(SEARCH_MARGIN)
	var first := Vector2i.ZERO
	_costs[first] = 0.0
	_points[first] = _origin
	_push({"key":first,"g":0.0,"f":_heuristic(_origin),"serial":_serial})
	_searching = true


func _clear_search() -> void:
	_open.clear()
	_costs.clear()
	_parents.clear()
	_points.clear()
	_closed.clear()
	_ground_cache.clear()
	expanded_nodes = 0
	_serial = 0


func _advance_search(body: CharacterBody3D) -> void:
	for iteration in EXPANSIONS_PER_TICK:
		if _open.is_empty() or expanded_nodes >= MAX_NODES:
			_searching = false
			_retry_at = _clock+RETRY_SECONDS
			return
		var entry := _pop()
		var key: Vector2i = entry.key
		if _closed.has(key) or float(entry.g) > float(_costs.get(key,INF))+0.00001:
			continue
		_closed[key] = true
		expanded_nodes += 1
		var point: Vector3 = _points[key]
		if _horizontal(point,_goal) <= _stop_distance+CELL*0.5 and _visible_goal(body,point,_goal):
			var final := _final_point(body,point)
			if final.is_finite():
				_build_path(key,final)
				return
		for offset: Vector2i in DIRECTIONS:
			var next := key+offset
			if _closed.has(next):
				continue
			var flat := _origin+Vector3(float(next.x)*CELL,0.0,float(next.y)*CELL)
			if not _bounds.has_point(Vector2(flat.x,flat.z)):
				continue
			var next_point: Vector3 = _ground_cache.get(next,Vector3.INF)
			if not _ground_cache.has(next):
				next_point = _ground_point(body,flat,point.y)
				_ground_cache[next] = next_point
			if not next_point.is_finite() or absf(next_point.y-point.y) > MAX_HEIGHT_CHANGE:
				continue
			var score := float(_costs[key])+point.distance_to(next_point)
			if score >= float(_costs.get(next,INF)) or not _walk_leg(body,point,next_point):
				continue
			_costs[next] = score
			_parents[next] = key
			_points[next] = next_point
			_serial += 1
			_push({"key":next,"g":score,"f":score+_heuristic(next_point),"serial":_serial})


func _final_point(body: CharacterBody3D, from: Vector3) -> Vector3:
	var difference := Vector3(_goal.x-from.x,0.0,_goal.z-from.z)
	if difference.length() <= _stop_distance+ARRIVAL_EPSILON:
		return from
	var desired := from+difference.normalized()*(difference.length()-_stop_distance)
	var final := _ground_point(body,desired,from.y)
	return final if final.is_finite() and _walk_leg(body,from,final) else Vector3.INF


func _build_path(key: Vector2i, final: Vector3) -> void:
	var reverse: Array[Vector3] = [final]
	var cursor := key
	while _parents.has(cursor):
		var point: Vector3 = _points[cursor]
		if point.distance_squared_to(reverse.back()) > 0.0001:
			reverse.append(point)
		cursor = _parents[cursor]
	reverse.reverse()
	path = reverse
	_searching = false
	_retry_at = _clock


func _ground_point(body: CharacterBody3D, point: Vector3, reference_y: float) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(point.x,reference_y+0.65+_foot_bottom,point.z),
		Vector3(point.x,reference_y-0.75+_foot_bottom,point.z),1,[body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or Vector3(hit.normal).y < cos(body.floor_max_angle):
		return Vector3.INF
	return Vector3(point.x,float(hit.position.y)-_foot_bottom+GROUND_CLEARANCE,point.z)


func _walk_leg(body: CharacterBody3D, start: Vector3, end: Vector3) -> bool:
	var length := _horizontal(start,end)
	var count := maxi(1,ceili(length/0.45))
	var previous := start
	for index in range(1,count+1):
		var point := start.lerp(end,float(index)/float(count))
		point = _ground_point(body,point,previous.y)
		if not point.is_finite() or absf(point.y-previous.y) > MAX_HEIGHT_CHANGE:
			return false
		var transform := body.global_transform
		transform.origin = previous+Vector3.UP*SWEEP_CLEARANCE
		if body.test_move(transform,point-previous):
			return false
		previous = point
	return true


func _visible_goal(body: CharacterBody3D, from: Vector3, target: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from+Vector3.UP,
		Vector3(target.x,from.y+1.0,target.z),1,[body.get_rid()])
	return body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _heuristic(point: Vector3) -> float:
	return maxf(0.0,_horizontal(point,_goal)-_stop_distance)


static func _horizontal(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()


func _less(a: Dictionary, b: Dictionary) -> bool:
	return float(a.f) < float(b.f) or is_equal_approx(float(a.f),float(b.f)) and int(a.serial) < int(b.serial)


func _push(entry: Dictionary) -> void:
	_open.append(entry)
	var child := _open.size()-1
	while child > 0:
		var parent := (child-1)>>1
		if not _less(_open[child],_open[parent]):
			break
		var swap: Dictionary = _open[parent]
		_open[parent] = _open[child]
		_open[child] = swap
		child = parent


func _pop() -> Dictionary:
	var result: Dictionary = _open[0]
	var last: Dictionary = _open.pop_back()
	if _open.is_empty():
		return result
	_open[0] = last
	var parent := 0
	while true:
		var left := parent*2+1
		if left >= _open.size():
			break
		var child := left
		if left+1 < _open.size() and _less(_open[left+1],_open[left]):
			child = left+1
		if not _less(_open[child],_open[parent]):
			break
		var swap: Dictionary = _open[parent]
		_open[parent] = _open[child]
		_open[child] = swap
		parent = child
	return result
