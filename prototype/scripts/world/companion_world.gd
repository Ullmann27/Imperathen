extends RefCounted
## Bindet dieselben vorhandenen Figuren an die Begleitregie. Nur beobachtete
## Körperpositionen werden gespeichert; Wege bleiben ein flüchtiger Cache.

const Follow = preload("res://scripts/story/companion_follow.gd")
const Story = preload("res://scripts/story/companion_story.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const I01 = preload("res://scripts/story/i01_three_cups.gd")
const I03 = preload("res://scripts/story/i03_shortcut.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const Gear = preload("res://scripts/visuals/party_gear.gd")
var world: Node3D
var controllers: Dictionary = {"marcus":Follow.new(), "silvanus":Follow.new()}
# Recent player footfalls let a group file through the same doorway. Only
# local actors have controllers. No persistent count depends on this trail.
var _trail: Array[Vector3] = []


func _init(owner_world: Node3D) -> void:
	world = owner_world


func actor(id: String) -> CharacterBody3D:
	if id == "marcus":
		return world._companion as CharacterBody3D
	return world.village_life_world.actors.get(id) as CharacterBody3D


func home(id: String) -> Vector3:
	# During the open I-01 morning Silvanus sits at the breakfast table on the
	# raised house floor; afterwards he walks out to his door work.
	if id == "silvanus" and bool(I01.presentation(world._state).get("silvanus_at_table", false)):
		var seat: Vector2 = I01.POINTS.silvanus_table
		return Vector3(seat.x, Layout.HOUSE_FLOOR, seat.y)
	if id not in Story.ACTORS:
		if Childhood.EXTRA_NPCS.has(id):
			var at: Vector2 = Childhood.POINTS[Childhood.EXTRA_NPCS[id].point]
			return Vector3(at.x, 0.0, at.y)
		if Childhood.NEIGHBORS.has(id):
			var at: Vector2 = Childhood.NEIGHBORS[id].position
			return Vector3(at.x, 0.0, at.y)
		return actor(id).get_meta("home_position", actor(id).position)
	var point: Vector2 = Childhood.POINTS.marcus if id == "marcus" else Childhood.POINTS.father
	return Vector3(point.x, 0.0, point.y)


func sync(data: Dictionary) -> void:
	var members: Dictionary = data.get("world_state", {}).get("party", {}).get("members", {})
	for uid: String in members:
		var id := "marcus" if uid == "pc:companion" else uid.trim_prefix("vil:")
		if not controllers.has(id) and actor(id) != null:
			controllers[id] = Follow.new()
	for id: String in controllers:
		var body := actor(id)
		if body != null:
			var membership := Story.member(data, id)
			body.set_meta("actor_uid", Story.actor_uid(data, id))
			Gear.sync(body.get_node("Figure"), membership.get("equipment", {}))


func reset(data: Dictionary) -> void:
	_trail.clear()
	for id: String in controllers.keys():
		if id not in Story.ACTORS and Story.member(data, id).is_empty():
			controllers.erase(id)
			continue
		controllers[id].reset()
		var body := actor(id)
		if body == null:
			continue
		body.velocity = Vector3.ZERO
		if body.has_meta("waiting_anchor"):
			body.remove_meta("waiting_anchor")
		var membership := Story.member(data, id)
		var available := Story.available(data, id)
		var recovering: bool = membership.get("status", "") == "active" and membership.order == "home" and body.visible and body.get_meta("assignment", "idle") == "idle"
		body.set_meta("companion_controlled", available or recovering)
		if not Childhood.enabled(data) and membership.is_empty():
			if id == "marcus":
				body.global_position = world.to_global(home(id))
			continue
		if id == "silvanus" and not available and membership.is_empty():
			continue
		# Einmalige Platzierung beim Neu-/Laden, niemals beim normalen State-Sync.
		body.global_position = Story.restored_position(data, id, world.to_global(home(id)))


func pause() -> void:
	for id: String in controllers:
		var body := actor(id)
		if body != null:
			controllers[id].pause(body)
			body.get_node("Figure").drive(0.0)


func advance(delta: float) -> void:
	var data: Dictionary = world._state
	if not Childhood.enabled(data) and data.get("world_state", {}).get("party", {}).get("members", {}).is_empty():
		return
	var paused: bool = not world._active or world._mode != "person" or data.village.raid.active or data.encounter.active
	var night: String = data.village.get("childhood", {}).get("night_event", "")
	if paused or (night == "released" and data.village.raid.status != "aftermath"):
		pause()
		return
	var step := Childhood.current_step(data)
	var specs := Childhood.companion_specs(data)
	var player: Vector3 = world.get_player_position()
	if not _trail.is_empty() and player.distance_to(_trail.back()) > 6.0:
		_trail.clear()
	if _trail.is_empty() or player.distance_to(_trail.back()) >= 0.6:
		_trail.append(player)
		if _trail.size() > 4 + controllers.size() * 3:
			_trail.pop_front()
	var follower := 0
	for id: String in controllers:
		var body := actor(id)
		# I-03: before the two have parted Marcus is no companion yet, but he
		# walks his own errand: with the boy, or ahead to Cassia's stall.
		var station := I03.marcus_station(data, Childhood.i03_ctx(data)) if id == "marcus" and Childhood.enabled(data) else "home"
		if body == null or not body.visible:
			continue
		var membership := Story.member(data, id)
		var available := Story.available(data, id)
		var recovering: bool = not available and membership.get("status", "") == "active" and membership.order == "home" and body.get_meta("companion_controlled", false)
		if not available and station == "home" and not recovering:
			continue
		var night_call: bool = id in ["silvanus", "julia", "sextus"] and (night == "pending" or str(step.get("id", "")) in ["family_evening", "night_rest", "i11_forge", "i12_father"])
		if night == "pending" and not night_call:
			controllers[id].pause(body)
			body.get_node("Figure").drive(0.0)
			continue
		body.set_meta("companion_controlled", true)
		var target := world.to_global(home(id))
		var distance := 0.15
		var speed := 1.45
		var mode := "return"
		if membership.get("order", "") != "wait" and body.has_meta("waiting_anchor"):
			body.remove_meta("waiting_anchor")
		if recovering:
			mode = "recover"
			speed = 0.85
		elif night_call:
			# Family and smith return on foot to their authored duties as the
			# night approaches. A previous request cannot move I-10 elsewhere.
			mode = "return"
			speed = 3.0
		elif membership.get("status", "") == "active":
			mode = str(membership.order)
			var slot := follower
			follower += 1
			match mode:
				"wait":
					if not body.has_meta("waiting_anchor"):
						body.set_meta("waiting_anchor", _waiting_anchor(body, slot))
					target = body.get_meta("waiting_anchor")
					if Vector2(target.x - body.global_position.x, target.z - body.global_position.z).length() < 0.2:
						controllers[id].pause(body)
						body.set_meta("companion_mode", mode)
						body.set_meta("activity", "rest")
						body.get_node("Figure").drive(0.0)
						continue
				"home":
					pass
				"train":
					# The same supervised practice ground as the player.
					target = world.to_global(Vector3(0, 0, -7))
					distance = 1.3 + slot * 0.5
				"follow", "assist":
					var trail_index := maxi(0, _trail.size() - 1 - (slot + 1) * 2)
					target = _trail[trail_index]
					distance = 1.25 + slot * 0.4 if trail_index == 0 else 0.55
					var role := str(membership.assignment)
					var tasks := Story.task_roles(str(step.get("id", "")))
					# A guide and carrier walk to the actual task site. If
					# their assignment changes, the ordinary follow path resumes.
					if mode == "assist" and tasks.has(role) and step.get("npc", "") != id:
						var site := Childhood._target(data, step)
						target = world.to_global(Vector3(site.x, 0, site.y))
						distance = 2.1 if role in ["guide", "watch"] else 1.15
			speed = 4.1 if body.global_position.distance_to(target) > 5.0 else 2.3
		elif not membership.is_empty():
			# Dismissal suppresses optional scene direction. This physical
			# actor walks back to their own station.
			pass
		elif station == "stall":
			var place: Vector2 = I03.marcus_stall(Childhood.i03_ctx(data))
			target = world.to_global(Vector3(place.x, 0.0, place.y))
			speed = 2.3
			mode = "errand"
		elif station == "follow":
			var stall: Vector2 = I03.marcus_stall(Childhood.i03_ctx(data))
			var stall_at := world.to_global(Vector3(stall.x, 0.0, stall.y))
			if Vector2(player.x-stall_at.x, player.z-stall_at.z).length() <= 5.0 and str(data.village.childhood.screenplay.i03_stance).is_empty():
				# Arriving together: Marcus steps up to the stall himself.
				target = stall_at
				mode = "errand"
			else:
				target = player
				distance = 1.7
				mode = "follow"
			speed = 4.1 if Vector2(player.x-body.global_position.x, player.z-body.global_position.z).length() > 5.0 else 2.3
		elif specs.has(id):
			var spec: Dictionary = specs[id]
			target = player
			distance = 2.1 if Story.tone(data, id) == "rival" else 1.7
			speed = 4.1 if Vector2(player.x-body.global_position.x, player.z-body.global_position.z).length() > 5.0 else 2.3
			mode = "follow"
			var stop: Array = spec.get("stops", {}).get(str(step.get("id", "")), [])
			if stop.size() == 2:
				var at := world.to_global(Vector3(float(stop[0]), 0.0, float(stop[1])))
				if Vector2(player.x-at.x, player.z-at.z).length() <= 6.0:
					target = at
					distance = 0.18
					mode = "hold"
		var before := body.global_position
		controllers[id].move(body, target, delta, speed, distance)
		var travelled := body.global_position-before
		var actual_speed := Vector2(travelled.x, travelled.z).length()/maxf(delta, 0.0001)
		# Follow.move already turns this exact body at its bounded angular rate.
		# The visual adapter must not rotate it a second time in the same tick.
		body.get_node("Figure").drive(actual_speed)
		body.set_meta("companion_mode", mode)
		var activity := "march" if actual_speed > 0.05 else "rest"
		if actual_speed <= 0.05 and controllers[id].status == "arrived":
			if mode == "train" or (mode == "assist" and Story.task_roles(str(step.get("id", ""))).has(membership.get("assignment", ""))):
				activity = "work"
				body.get_node("Figure").keep_working()
		body.set_meta("activity", activity)


## Freeze only the village return anchors. The market receives the existing
## bodies, never a re-created resident, and only people actually travelling
## together can depart with the player.
func departing_for_market(data: Dictionary, at: Vector3) -> Array[CharacterBody3D]:
	var people: Array[CharacterBody3D] = []
	for id: String in controllers:
		var membership := Story.member(data, id)
		if membership.get("status", "") != "active" or membership.order not in ["follow", "assist"] or not Story.available(data, id):
			continue
		var body := actor(id)
		if is_instance_valid(body) and body.is_visible_in_tree() and body.global_position.distance_to(at) <= 8.0:
			people.append(body)
	return people

## The oak entry ramp and threshold are the single-file section of a furnished
## house. A request here means waiting beside the entrance. All displacement
## towards the free lane still uses the ordinary collision-checked controller.
func _waiting_anchor(body: CharacterBody3D, slot: int) -> Vector3:
	var here := body.global_position
	if not Childhood.enabled(world._state):
		return here
	for dwelling: Dictionary in Layout.HOMES:
		var local: Vector3 = (world.to_local(here) - dwelling.at).rotated(Vector3.UP, -float(dwelling.yaw))
		if absf(local.x) <= 0.95 and local.z >= 1.7 and local.z <= 4.35:
			var side := -1.0 if slot % 2 == 0 else 1.0
			var verge := Vector3(1.55 * side, 0, 4.55).rotated(Vector3.UP, float(dwelling.yaw))
			return world.to_global(dwelling.at + verge)
	return here
