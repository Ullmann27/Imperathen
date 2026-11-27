extends Node3D
## Spatial presentation of the saved population. The commuter's clock, route,
## place of work and identity all belong to CityLife. Only nearby bodies exist.
const Life = preload("res://scripts/domain/city_life.gd")
const Population = preload("res://scripts/domain/city_population.gd")
const Figure = preload("res://scripts/visuals/village_person.gd")
const Activities := preload("res://scripts/visuals/resident_activity.gd")
const LIMITS := {"low": 3, "balanced": 6, "high": 9, "very_high": 12}
const ENTER_RANGE := 48.0
const LEAVE_RANGE := 58.0
const SCAN_PER_STEP := 24
const SEARCH_BUDGET_USEC := 450

var life: Life
var observer: CharacterBody3D
var camera: Camera3D
var profile := "balanced"
var actors := {}
var _cursor := 0
var _social_clock := 0.0
var _capsule := CapsuleShape3D.new()

func setup(source: Life, player: CharacterBody3D, view: Camera3D, quality: String) -> void:
	life = source
	observer = player
	camera = view
	profile = quality
	_capsule.radius = 0.25
	_capsule.height = 1.68

func _physics_process(delta: float) -> void:
	if life == null or not is_instance_valid(observer):
		return
	if delta <= 0.0:
		return
	var now := int(life.state.t)
	for person: int in actors.keys():
		var actor: CharacterBody3D = actors[person]
		if life.is_indoors(person, now) or observer.position.distance_squared_to(actor.position) > LEAVE_RANGE * LEAVE_RANGE:
			_retire(person)
			continue
		var target := _target(person, now)
		var way := Vector3(target.x - actor.position.x, 0, target.z - actor.position.z)
		# A long calendar skip changes the projection immediately. Re-stream
		# the person at the new place instead of crossing intervening walls.
		if way.length_squared() > 36.0:
			_retire(person)
			continue
		var speed := float(life.walk_speed_cm(person)) / 100.0
		var step := way.limit_length(speed * delta)
		actor.velocity = Vector3(step.x / delta, -0.4 if actor.is_on_floor() else actor.velocity.y - 19.6 * delta, step.z / delta)
		var before := actor.position
		actor.move_and_slide()
		var movement := Vector2(actor.position.x - before.x, actor.position.z - before.z)
		var figure: Figure = actor.get_node("Figure")
		var actual_speed := movement.length() / delta
		figure.drive(actual_speed)
		actor.set_meta("actual_speed",actual_speed)
		if movement.length_squared() > 0.000001:
			figure.rotation.y = rotate_toward(figure.rotation.y, atan2(-movement.x, -movement.y), delta * 4.5)
	_social_clock += delta
	var refresh_contact := _social_clock >= 0.20
	if refresh_contact:
		_social_clock = 0.0
	_update_visible_activities(now,delta,refresh_contact)
	# Bound the search independently of total city size and spread model
	# instantiation across physics frames.
	var count: int = life.state.residents.size()
	var started := Time.get_ticks_usec()
	for scan in mini(count, SCAN_PER_STEP):
		if scan > 0 and Time.get_ticks_usec() - started >= SEARCH_BUDGET_USEC:
			break
		var person := _cursor
		_cursor = (_cursor + 1) % count
		if actors.has(person) or life.is_indoors(person, now):
			continue
		var resident: Dictionary = life.state.residents[person]
		if life.age(resident) < 18:
			continue # The current resident rig has adult proportions.
		var foot := life.position_of(person, now)
		var distance := observer.position.distance_squared_to(foot)
		if distance > ENTER_RANGE * ENTER_RANGE:
			continue
		var replace := -1
		if actors.size() >= int(LIMITS.get(profile, 6)):
			# A closer pedestrian can enter a full pool. The margin keeps
			# neighbours at nearly equal distances from trading slots.
			var worst := distance + 36.0
			for other: int in actors:
				var d := observer.position.distance_squared_to((actors[other] as Node3D).position)
				if d > worst:
					worst = d
					replace = other
			if replace < 0:
				continue
		if _materialize(person, resident, foot):
			if replace >= 0:
				_retire(replace)
			break

func _update_visible_activities(now: int, delta: float, refresh_contact: bool) -> void:
	# Only the bounded pool of actual streamed residents is considered.
	# A buyer can address a vendor even though the vendor's domain with
	# field is not reciprocal; never invent a partner from proximity alone.
	var requests := {}
	for person: int in actors:
		var resident: Dictionary = life.state.residents[person]
		var peer := Activities.partner_id(resident,now)
		if peer >= 0 and actors.has(peer):
			requests[person] = peer
			if not requests.has(peer):
				requests[peer] = person
	for person: int in actors:
		var resident: Dictionary = life.state.residents[person]
		var actor: CharacterBody3D = actors[person]
		var figure: Figure = actor.get_node("Figure")
		var moving := float(actor.get_meta("actual_speed",0.0)) > 0.06 or life.is_walking(person,now)
		figure.set_resident_prop(Activities.city_prop(resident,now))
		var other := int(requests.get(person,-1))
		var partner: Figure
		if not moving and other >= 0 and actors.has(other):
			var other_body: CharacterBody3D = actors[other]
			if float(other_body.get_meta("actual_speed",0.0)) <= 0.06 and not life.is_walking(other,now) and actor.global_position.distance_to(other_body.global_position) <= 2.8:
				var other_figure := other_body.get_node("Figure") as Figure
				var start := figure.gaze_anchor()
				var finish := other_figure.gaze_anchor()
				if start.is_finite() and finish.is_finite():
					if refresh_contact or int(actor.get_meta("contact_peer",-1)) != other:
						var ray := PhysicsRayQueryParameters3D.create(start,finish,1,[actor.get_rid(),other_body.get_rid()])
						actor.set_meta("contact_clear",get_world_3d().direct_space_state.intersect_ray(ray).is_empty())
						actor.set_meta("contact_peer",other)
					if bool(actor.get_meta("contact_clear",false)):
						partner = other_figure
		if moving or other < 0 or not actors.has(other):
			actor.set_meta("contact_peer",-1)
		figure.set_gaze_target(partner)
		var talking := is_instance_valid(partner) and Activities.speaker(person,other,now) == person
		if bool(actor.get_meta("activity_speaking",false)) and not talking:
			figure.set_conversation_focus(false)
		actor.set_meta("activity_speaking",talking)
		if is_instance_valid(partner):
			var offset := partner.global_position - figure.global_position
			if Vector2(offset.x,offset.z).length() > .12:
				figure.rotation.y = rotate_toward(figure.rotation.y,atan2(-offset.x,-offset.z),delta*2.8)
			if talking:
				figure.keep_talking()
		elif not moving and Activities.standing_work(resident,now):
			figure.keep_working()
		actor.set_meta("visible_activity","walking" if moving else str(resident.act))


func _target(person: int, now: int) -> Vector3:
	if not life.is_walking(person, now):
		var resident: Dictionary = life.state.residents[person]
		return life.slot_position(resident.at, int(resident.slot))
	# Follow toward the *next* simulation sample at gait speed between whole
	# clock seconds. Pure graph sampling never changes the simulated resident.
	return life.position_of(person, now + 1)

func _materialize(person: int, resident: Dictionary, point: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.65, point + Vector3.DOWN * 0.95, 1)
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.70:
		return false
	var foot: Vector3 = hit.position
	var fit := PhysicsShapeQueryParameters3D.new()
	fit.shape = _capsule
	fit.collision_mask = 3
	fit.transform.origin = foot + Vector3.UP * (0.5 * _capsule.height + 0.012)
	if not space.intersect_shape(fit, 1).is_empty():
		return false
	var actor := CharacterBody3D.new()
	actor.name = Population.resident_id(person)
	actor.set_meta("resident_name", str(resident.name))
	actor.collision_layer = 2
	actor.collision_mask = 3
	actor.floor_snap_length = 0.24
	actor.position = foot + Vector3.UP * 0.003
	var shape := CollisionShape3D.new()
	shape.shape = _capsule
	shape.position.y = _capsule.height / 2.0
	actor.add_child(shape)
	add_child(actor)
	var figure := Figure.new()
	figure.name = "Figure"
	figure.profile = profile
	figure.position.y = 0.90
	figure.rotation.y = life.slot_facing(resident.at, int(resident.slot))
	actor.add_child(figure)
	var appearance := "civilian_woman" if resident.female else ("elder" if life.age(resident) >= 62 else "civilian_man")
	figure.configure_resident(resident.origin, life.age(resident), appearance, int(resident.look), camera, Population.resident_id(person))
	actors[person] = actor
	return true

func _retire(person: int) -> void:
	var actor: CharacterBody3D = actors[person]
	actors.erase(person)
	remove_child(actor)
	actor.queue_free()
