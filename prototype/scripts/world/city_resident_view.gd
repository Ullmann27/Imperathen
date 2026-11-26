extends Node3D
## Spatial presentation of the saved population. The commuter's clock, route,
## place of work and identity all belong to CityLife. Only nearby bodies exist.
const Life = preload("res://scripts/domain/city_life.gd")
const Population = preload("res://scripts/domain/city_population.gd")
const Figure = preload("res://scripts/visuals/village_person.gd")
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
		figure.drive(movement.length() / delta)
		if movement.length_squared() > 0.000001:
			figure.rotation.y = rotate_toward(figure.rotation.y, atan2(-movement.x, -movement.y), delta * 4.5)
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
	var appearance := "elder" if life.age(resident) >= 62 else ("civilian_woman" if resident.female else "civilian_man")
	figure.configure_resident(resident.origin, life.age(resident), appearance, int(resident.look), camera, Population.resident_id(person))
	actors[person] = actor
	return true

func _retire(person: int) -> void:
	var actor: CharacterBody3D = actors[person]
	actors.erase(person)
	remove_child(actor)
	actor.queue_free()
