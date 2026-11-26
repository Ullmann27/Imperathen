extends Node3D
## Visible people, workplaces and raiders are projections of saved village state.
## Their meshes never create workers, production, damage, friendships or XP.

const Life = preload("res://scripts/story/village_life.gd")
const Economy = preload("res://scripts/domain/village_economy.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const Art = preload("res://scripts/world/village_art.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const Behavior = preload("res://scripts/domain/npc_behavior.gd")
const Childhood = preload("res://scripts/story/village_childhood.gd")
const Strike = preload("res://scripts/domain/raider_strike.gd")
const COUNCIL := "res://assets/politics/council/valdora_council.glb"
const COUNCIL_COLLISION := "res://assets/politics/council/valdora_council_collision.glb"
const COUNCIL_ENTRANCE := Vector3(16.0, 0.012, 9.5)
const SOUTH_ROAD := "res://assets/politics/suedweg/suedweg_bohlen.glb"
const SUPPLIED_PLANKS := "res://assets/politics/suedweg/suedweg_ersatzbohlen.glb"
const PLACES := {"farm":Vector2(24,-30), "woodcamp":Vector2(-43,14),
	"quarry":Vector2(48,-12), "trade":Vector2(25,24), "watchpost":Vector2(0,-48)}
var actors: Dictionary = {}
var raiders: Dictionary = {}
var workplaces: Dictionary = {}
var state: Dictionary = {}
var quality := "balanced"
var active := false
var focused := ""
var _focus_yaw := 0.0
var _ready_scene := false
var _wood: StandardMaterial3D
var _stone: StandardMaterial3D
var _linen: StandardMaterial3D
var _council: Node3D
var _south_road: Node3D
var _supplied_planks: Node3D
# Domain targets arrive every Life.STEP. Only spawn/restore places a body;
# ordinary play sweeps towards those targets on the physics clock.
const RAIDER_SPEED := 0.12 / Life.STEP
const RAIDER_TURN_SPEED := 5.0
const RAIDER_ACCELERATION := 2.4
const RAIDER_BRAKING := 6.0
const RAIDER_ALIGN_FROM := deg_to_rad(20.0)
const RAIDER_ALIGN_TO := deg_to_rad(75.0)
## Turning towards the player while standing: 180 degrees in under 0.5 s.
const RAIDER_FACE_SPEED := 6.5
var _raider_targets: Dictionary = {}
var _raider_states: Dictionary = {}
var _route_points: Dictionary = {}
var _route_clock: Dictionary = {}
var _world_id := ""
var _world_seconds := -1.0
var _restore_raiders := false
var physical_raiders := false
var raider_sight_check: Callable


func _physics_process(delta: float) -> void:
	_advance_raiders(delta)
	_update_attention(delta)


func _advance_raiders(delta: float) -> void:
	if not active or not visible or delta <= 0.0:
		return
	# Bound a delayed frame without replacing the swept collision operation.
	var elapsed := minf(delta, .1)
	var saved: Array = state.get("player",{}).get("position",[0.0,0.0,0.0])
	var player := Vector2(float(saved[0]),float(saved[2]))
	for id: String in raiders:
		var actor: CharacterBody3D = raiders[id]
		var figure: Node3D = actor.get_node("Figure")
		if not actor.visible or int(actor.get_meta("health",0)) <= 0:
			figure.drive(0.0)
			continue
		var target: Vector3 = _raider_targets.get(id,actor.position)
		var point := Vector2(actor.global_position.x,actor.global_position.z)
		var enemy: Dictionary = _raider_states.get(id,{})
		# The same visible-swing window as VillageLife: a raider that has begun
		# its blow stands and completes it, even if the player steps away.
		var swinging := not enemy.is_empty() and Strike.swinging(float(enemy.get("attack_timer",Strike.APPROACH_SECONDS)))
		var engaged := point.distance_to(player) <= Strike.engage_distance()
		if state.village.has("unarmed") and engaged:
			engaged = raider_sight_check.is_valid() and bool(raider_sight_check.call(point,player))
		if physical_raiders:
			var goal := point
			if not engaged and not swinging and not enemy.is_empty():
				_route_clock[id] = float(_route_clock.get(id,0.0))-elapsed
				if float(_route_clock[id]) <= 0.0 or not _route_points.has(id):
					# The stateless route is re-evaluated ten times per second
					# from the actual swept body, exactly as the rule tick does.
					var probe := enemy.duplicate()
					probe.x = point.x
					probe.z = point.y
					_route_points[id] = Life.raider_waypoint(state,probe)
					_route_clock[id] = Life.STEP
				goal = _route_points[id]
			target = to_local(Vector3(goal.x,actor.global_position.y,goal.y))
		var offset := target-actor.position
		offset.y = 0.0
		var before := actor.position
		var pace := RAIDER_SPEED
		var wanted_heading := actor.rotation.y
		if offset.length_squared() > .0001:
			wanted_heading = atan2(-offset.x,-offset.z)
		if physical_raiders:
			# A body does not reach walking speed within one frame and does not
			# walk sideways while it turns. It turns towards its next waypoint,
			# steps off as it comes to face it and gathers pace over half a
			# second; it slows into a sharp corner instead of pivoting at full
			# pace. Sliding along a contact is not held back by its heading.
			var limit := RAIDER_SPEED
			if not bool(actor.get_meta("yielding",false)):
				limit *= 1.0-smoothstep(RAIDER_ALIGN_FROM,RAIDER_ALIGN_TO,absf(angle_difference(actor.rotation.y,wanted_heading)))
			var held := float(actor.get_meta("pace",0.0))
			pace = move_toward(held,limit,(RAIDER_ACCELERATION if limit > held else RAIDER_BRAKING)*elapsed)
		var displacement := offset.limit_length(pace*elapsed)
		var hit: KinematicCollision3D
		if displacement.length_squared() > .00000001:
			hit = actor.move_and_collide(displacement)
			if hit != null:
				_slide_raider(actor,hit,displacement)
		var travelled := actor.position-before
		var actual_speed := Vector2(travelled.x,travelled.z).length()/elapsed
		figure.drive(actual_speed)
		actor.set_meta("actual_speed",actual_speed)
		# The pace is the walker's own effort, not the distance a contact left
		# him: clamping it to a deflected step would leave him creeping round
		# every person in his way (measured: 0.05 m/s past the watch post).
		actor.set_meta("pace",0.0 if offset.length_squared() <= .0001 else pace)
		actor.set_meta("yielding",hit != null)
		if swinging or (offset.length_squared() <= .0001 and point.distance_to(player) <= Strike.reach()+.5):
			# A standing fighter keeps the player in front of him.
			var towards := player-point
			if towards.length() > .05:
				actor.rotation.y = rotate_toward(actor.rotation.y,atan2(-towards.x,-towards.y),RAIDER_FACE_SPEED*elapsed)
		elif hit != null and travelled.length_squared() > .00000001:
			# Along a contact the body faces where it actually goes.
			actor.rotation.y = rotate_toward(actor.rotation.y,atan2(-travelled.x,-travelled.z),RAIDER_TURN_SPEED*elapsed)
		elif offset.length_squared() > .0001:
			actor.rotation.y = rotate_toward(actor.rotation.y,wanted_heading,RAIDER_TURN_SPEED*elapsed)


func _slide_raider(actor: CharacterBody3D, hit: KinematicCollision3D, displacement: Vector3) -> void:
	# Continue the blocked remainder along the contact plane (swept again, so
	# the slide itself cannot tunnel). A wall met head-on still stops the body.
	var remainder := hit.get_remainder()
	remainder.y = 0.0
	var normal := hit.get_normal()
	normal.y = 0.0
	if remainder.length_squared() < .00000001 or normal.length_squared() < .0001:
		return
	normal = normal.normalized()
	var slide := remainder-normal*minf(0.0,remainder.dot(normal))
	if _is_person(hit.get_collider()) and slide.length() < remainder.length()*.35:
		# Two people meeting head-on both step to their right, deterministically.
		slide = Vector3(-displacement.z,0.0,displacement.x).normalized()*remainder.length()*.5
	if slide.length_squared() > .00000001:
		actor.move_and_collide(slide)


func _is_person(collider: Object) -> bool:
	if collider is CharacterBody3D and raiders.values().has(collider):
		return true
	return collider is CollisionObject3D and int((collider as CollisionObject3D).collision_layer) & Layout.CITIZEN_LAYER != 0


func _process(delta: float) -> void:
	if not focused.is_empty() and actors.has(focused) and delta > 0.0:
		var actor: Node3D = actors[focused]
		actor.rotation.y = rotate_toward(actor.rotation.y,_focus_yaw,minf(delta,.1)*3.2)
	_update_nameplates()


func raid_observations() -> Dictionary:
	var positions := {}
	if physical_raiders and visible:
		for id: String in raiders:
			var actor: Node3D = raiders[id]
			if actor.visible:
				positions[id] = Vector2(actor.global_position.x,actor.global_position.z)
	return {"world_id":_world_id,"positions":positions}


func sync_raid_state(data: Dictionary) -> void:
	# Combat health, action cues and endpoints update on every physics step.
	# The expensive settlement/UI refresh remains on its existing cadence.
	if not _ready_scene or not data.get("village",{}).get("enabled",false):
		return
	state = data
	_sync_raiders()


func behavior_observations() -> Dictionary:
	var result := {}
	for id: String in actors:
		var actor: Node3D = actors[id]
		if not actor.visible:
			continue
		var point := actor.global_position
		result[id] = {"position":[point.x,point.y,point.z],"route_distance":0.0}
	return result


func _update_attention(delta: float) -> void:
	if not active or not visible or not focused.is_empty() or not Behavior.enabled(state):
		return
	var saved: Array = state.get("player",{}).get("position",[0.0,0.0,0.0])
	var player := Vector3(float(saved[0]),float(saved[1]),float(saved[2]))
	var parent := get_parent()
	if parent != null and parent.has_method("get_player_position"):
		player = parent.get_player_position()
	for id: String in actors:
		var actor: Node3D = actors[id]
		if not actor.visible or actor.get_meta("companion_controlled",false):
			_set_social_pose(actor,false)
			continue
		var intent := Behavior.view(state,id)
		if intent.is_empty():
			_set_social_pose(actor,false)
			continue
		var activity: String = str(intent.activity)
		var contact := _physical_social_contact(id,actor,intent,player)
		_set_social_pose(actor,not contact.is_empty())
		var target := player
		if activity in ["greet","socialize"]:
			# A social decision is not a conversation until the two *visible*
			# real bodies meet. This also prevents a face turn through a house.
			if contact.is_empty():
				continue
			target = contact.target
		elif activity == "space":
			if not _social_line_clear(actor.global_position,player):
				continue
		elif activity in ["alert","assist"]:
			var distance := INF
			for enemy: Dictionary in state.village.raid.enemies:
				if int(enemy.health) <= 0:
					continue
				var at := Vector3(float(enemy.x),0,float(enemy.z))
				if actor.position.distance_squared_to(at) < distance and _social_line_clear(actor.global_position,at):
					distance = actor.position.distance_squared_to(at)
					target = at
			if distance == INF:
				continue
		else:
			continue
		var offset := target-actor.global_position
		if Vector2(offset.x,offset.z).length() > .1:
			actor.rotation.y = rotate_toward(actor.rotation.y,atan2(-offset.x,-offset.z),minf(delta,.1)*3.2)


func _physical_social_contact(id: String, actor: Node3D, intent: Dictionary, player: Vector3) -> Dictionary:
	# Presentation-only gate. Do not credit social memory, change decisions,
	# modify animation rigs or rewrite the authoritative village state here.
	if not active or not is_instance_valid(actor) or not actor.visible:
		return {}
	var partner_id := str(intent.get("partner",""))
	var activity := str(intent.get("activity",""))
	if activity not in ["greet","socialize"] or partner_id.is_empty():
		return {}
	var target: Vector3
	var permitted_distance := 1.5
	if partner_id == "player":
		if activity != "greet":
			return {}
		target = Vector3(player.x,actor.global_position.y,player.z)
		permitted_distance = 3.0
	else:
		if activity != "socialize":
			return {}
		var counterpart := _physical_partner(partner_id)
		if not is_instance_valid(counterpart) or not counterpart.visible:
			return {}
		# Both residents must independently choose each other, not merely
		# receive an unverified animation cue from one person's intention.
		var other_intent := Behavior.view(state,partner_id)
		if other_intent.is_empty() or other_intent.get("activity","") != "socialize" or str(other_intent.get("partner","")) != id:
			return {}
		target = counterpart.global_position
	var origin := actor.global_position
	var ground_distance := Vector2(origin.x,origin.z).distance_to(Vector2(target.x,target.z))
	if ground_distance > permitted_distance or absf(origin.y-target.y) > 1.2:
		return {}
	if not _social_line_clear(origin,target):
		return {}
	return {"target":target}


func _physical_partner(partner_id: String) -> Node3D:
	if actors.has(partner_id):
		return actors[partner_id] as Node3D
	var parent := get_parent()
	if parent != null:
		var population: Variant = parent.get("population")
		if population is Node:
			var bodies: Variant = (population as Node).get("actors")
			if bodies is Dictionary and bodies.has(partner_id):
				return bodies[partner_id] as Node3D
	return null


func _social_line_clear(first: Vector3, second: Vector3) -> bool:
	if not first.is_finite() or not second.is_finite() or not is_inside_tree():
		return false
	var parent := get_parent()
	if parent != null and parent.has_method("npc_sight_clear"):
		return bool(parent.call("npc_sight_clear",first,second))
	# The isolated visual fixture uses the same two-height occlusion contract
	# as GameWorld; never treat an unavailable geometry test as clear.
	for height: float in [0.85,1.45]:
		var offset := Vector3.UP*height
		var query := PhysicsRayQueryParameters3D.create(first+offset,second+offset,1)
		query.hit_from_inside = true
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return false
	return true


func _set_social_pose(actor: Node3D, allowed: bool) -> void:
	if not is_instance_valid(actor):
		return
	var previously := bool(actor.get_meta("physical_social_pose",false))
	if previously == allowed:
		return
	actor.set_meta("physical_social_pose",allowed)
	var figure := actor.get_node_or_null("Figure")
	if not is_instance_valid(figure):
		return
	if allowed:
		figure.cue("talk")
	else:
		# Stop a social pose if the conversation partner moved, turned a
		# corner, died or became hidden. Animation does not play through walls.
		figure.reset_motion()


func _update_nameplates() -> void:
	var camera := get_viewport().get_camera_3d()
	for actor: Node3D in actors.values():
		var label := actor.get_node("Nameplate") as Label3D
		label.visible = false
		if not visible or not active or not focused.is_empty() or not actor.visible or camera == null:
			continue
		# The renderer's radial visibility range alone does not prevent text at
		# the side of a close camera from crossing its near plane at huge size.
		var camera_position := camera.global_transform.affine_inverse() * label.global_position
		var depth := -camera_position.z
		label.visible = depth >= 3.0 and camera_position.length() <= 6.0


func sync_state(data: Dictionary, profile: String) -> void:
	var next_world := str(data.get("world_id",""))
	var next_seconds := float(data.get("world_seconds",0.0))
	_restore_raiders = next_world != _world_id or next_seconds + .000001 < _world_seconds
	_world_id = next_world
	_world_seconds = next_seconds
	state = data
	quality = profile
	visible = bool(data.get("village", {}).get("enabled", false))
	if not visible:
		_set_collisions(false)
		return
	if not _ready_scene:
		_create()
	_sync_council(Childhood.enabled(data))
	_set_collisions(true)
	var people: Array = data.village.economy.people
	for person: Dictionary in people:
		_sync_actor(str(person.id), str(person.name), str(person.profession), person)
	_sync_actor("decimus", "Decimus", "Dorfverwalter", {"assignment":"idle", "alive":true})
	var economy: Dictionary = Economy.view(data)
	for place: Dictionary in economy.get("workplaces", []):
		var item: Dictionary = workplaces[place.id]
		item.label.text = "%s\n%d / %d · %d %%" % [place.name, place.available, place.required, place.condition]
		item.damaged.visible = int(place.condition) < 100
		item.repaired.visible = int(place.condition) == 100
		item.label.modulate = Color("d8e2a8") if place.working else Color("e1c493")
	_sync_raiders()


func _sync_council(show_room: bool) -> void:
	if not show_room:
		if is_instance_valid(_council):
			remove_child(_council)
			_council.queue_free()
			_council = null
		return
	if is_instance_valid(_council):
		return
	if not ResourceLoader.exists(COUNCIL, "PackedScene") or not ResourceLoader.exists(COUNCIL_COLLISION, "PackedScene"):
		return
	var model := load(COUNCIL) as PackedScene
	var hulls := load(COUNCIL_COLLISION) as PackedScene
	if model == null or hulls == null:
		return
	var room := model.instantiate() as Node3D
	var collisions := hulls.instantiate() as Node3D
	room.name = "ValdoraCouncilRoom"
	room.position = COUNCIL_ENTRANCE
	room.add_child(collisions)
	add_child(room)
	if collisions.find_children("*", "StaticBody3D", true, false).is_empty():
		for surface: MeshInstance3D in collisions.find_children("*", "MeshInstance3D", true, false):
			if surface.mesh != null:
				surface.create_trimesh_collision()
	collisions.hide()
	_council = room


func at_council_records(point: Vector3) -> bool:
	if not is_instance_valid(_council) or not _council.is_visible_in_tree():
		return false
	var local := _council.to_local(point)
	return absf(local.y - 0.9) < 0.5 and Vector2(local.x, local.z).distance_to(Vector2(3.56, 1.94)) < 0.75


func update_south_road(view: Dictionary) -> void:
	var playable := Childhood.enabled(state) and bool(view.get("available", false))
	if playable and not is_instance_valid(_south_road):
		_south_road = _road_detail(SOUTH_ROAD, "LooseSouthRoadBoards", Vector3(1.95, 0.005, 17.0))
		_supplied_planks = _road_detail(SUPPLIED_PLANKS, "SuppliedSouthRoadBoards", Vector3(2.23, 0.005, 18.05))
	if is_instance_valid(_south_road):
		_south_road.visible = playable
	if is_instance_valid(_supplied_planks):
		_supplied_planks.visible = playable and view.get("recommendation", {}).get("route", "") == "wood"


func _road_detail(path: String, label: String, at: Vector3) -> Node3D:
	if not ResourceLoader.exists(path, "PackedScene"):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var detail := scene.instantiate() as Node3D
	detail.name = label
	detail.position = at
	add_child(detail)
	return detail


func _set_collisions(enabled: bool) -> void:
	for body: CollisionObject3D in find_children("*","CollisionObject3D",true,false):
		if not body.has_meta("visible_layer"):
			body.set_meta("visible_layer",body.collision_layer)
		body.collision_layer = int(body.get_meta("visible_layer")) if enabled else 0


func _create() -> void:
	_ready_scene = true
	_wood = Art.material(Color("705b43"))
	_stone = Art.material(Color("969184"))
	_linen = Art.material(Color("c8b995"))
	for id: String in PLACES:
		_create_workplace(id, PLACES[id])
	for item in [[Life.SCOUT_POINT, "Spuren am Waldrand"], [Life.ALARM_POINT, "Alarmhorn"], [Life.RESCUE_POINT, "Sammelpunkt der Verletzten"]]:
		var marker := Node3D.new()
		marker.position = Vector3(item[0].x, 0, item[0].y)
		add_child(marker)
		Art.cylinder(marker, 0.07, 1.5, Vector3(0,0.75,0), _wood)
		var flag := Art.box(marker, Vector3(0.62,0.36,0.02), Vector3(.3,1.35,0), _linen)
		flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var label := Art.label(marker, item[1], Vector3(0,1.95,0), Color("e6d4aa"), 25)
		label.visibility_range_end = 12


func _create_workplace(id: String, at: Vector2) -> void:
	var node := Node3D.new()
	node.name = "Workplace_" + id
	node.position = Vector3(at.x, 0, at.y)
	add_child(node)
	var damaged := Node3D.new()
	damaged.name = "Damaged"
	node.add_child(damaged)
	var repaired := Node3D.new()
	repaired.name = "Repaired"
	node.add_child(repaired)
	for x in [-2.1, 2.1]:
		for z in [-1.3, 1.3]:
			Art.box(node, Vector3(.16,2.2,.16), Vector3(x,1.1,z), _wood, true)
	Art.roof(repaired, 4.6, 3.2, 2.2, .8, _linen)
	var broken := Art.box(damaged, Vector3(3.7,.14,.24), Vector3(0,.4,0), _wood)
	broken.rotation.z = -.28
	# The workplace apron is flush with the path, including its collision.
	Art.box(node, Vector3(4.5,.12,2.9), Vector3(0,-.06,0), _stone, true)
	if id == "woodcamp":
		for index in 6:
			var log := Art.cylinder(node, .17, 2.5, Vector3(-1.2 + (index % 3) * .4, .3 + (index / 3) * .3, .5), _wood)
			log.rotation.z = PI / 2
	elif id == "quarry":
		for index in 5:
			Art.box(node, Vector3(.7,.5,.8), Vector3(-1.5 + (index % 3), .3, -.6 + (index / 3)), _stone)
	elif id == "trade":
		Art.box(node, Vector3(3,.15,1.2), Vector3(0,.85,0), _wood, true)
		for x in [-1, 0, 1]:
			Art.cylinder(node, .16, .42, Vector3(x,1.12,0), _linen)
	elif id == "watchpost":
		Art.box(repaired, Vector3(2.0,.14,1.0), Vector3(0,1.45,0), _wood)
	var label := Art.label(node, Economy.WORKPLACES[id].name, Vector3(0,3.35,0), Color("e6d4aa"), 27)
	label.visibility_range_end = 20
	workplaces[id] = {"node":node, "label":label, "damaged":damaged, "repaired":repaired}


func _sync_actor(id: String, caption: String, profession: String, person: Dictionary) -> void:
	caption = Childhood.display_name(state, id, caption)
	var at: Vector2 = Life.actor_position(state, id)
	if not actors.has(id):
		var actor := CharacterBody3D.new()
		actor.name = "Resident_" + id
		actor.position = Vector3(at.x,0,at.y)
		actor.collision_layer = Layout.CITIZEN_LAYER
		actor.collision_mask = 1 | 2 | 4 | Layout.CITIZEN_LAYER
		actor.floor_snap_length = 0.35
		actor.set_meta("home_position", actor.position)
		var collision := CollisionShape3D.new()
		collision.name = "PersonalSpace"
		var capsule := CapsuleShape3D.new()
		capsule.radius = Layout.CITIZEN_RADIUS
		capsule.height = 1.72
		collision.shape = capsule
		collision.position.y = .90
		actor.add_child(collision)
		add_child(actor)
		var figure := Person.new()
		figure.name = "Figure"
		figure.position.y = .9
		figure.profile = quality
		actor.add_child(figure)
		var appearance := "civilian_woman" if id in ["aelia", "aurelia", "cassia", "drusa", "julia", "valeria", "antonia"] else "civilian_man"
		if id == "severus":
			appearance = "legionary"
		if id == "decimus":
			appearance = "elder"
		figure.configure_resident("italia",32+actors.size()%20,appearance,actors.size(),get_viewport().get_camera_3d())
		if id == "severus":
			figure.configure_meshy("unit_roman_signifer")
		var label := Art.label(actor, caption + " · " + profession, Vector3(0,2.08,0), Color("efdbad"), 27)
		label.name = "Nameplate"
		label.pixel_size = .003
		label.visibility_range_begin = 3.0
		label.visibility_range_end = 6
		label.hide()
		actors[id] = actor
	var actor: CollisionObject3D = actors[id]
	actor.set_meta("display_name",caption)
	actor.get_node("Nameplate").text = caption + " · " + profession
	var can_walk: bool = person.get("assignment", "idle") == "idle" and person.get("alive", true)
	var member: Dictionary = Childhood.CompanionStory.member(state, id)
	var controlled: bool = can_walk and (id == "silvanus" and Childhood.enabled(state) or not member.is_empty())
	actor.set_meta("companion_controlled", controlled)
	if not controlled:
		# Inside a house the figure stands on the raised floor, not in it.
		actor.position = Vector3(at.x, Layout.HOUSE_FLOOR if _indoors(at) else 0.0, at.y)
	actor.visible = bool(person.get("alive", true)) and not state.village.get("militia", []).has(id)
	actor.collision_layer = Layout.CITIZEN_LAYER if actor.visible and visible else 0
	actor.set_meta("assignment", person.get("assignment", "idle"))
	var figure: Node3D = actor.get_node("Figure")
	figure.profile = quality
	figure.refresh_lod(get_viewport().get_camera_3d())
	if focused != id and active and not controlled:
		var intent := Behavior.view(state,id)
		var activity := str(intent.get("activity","work"))
		figure.drive(0.0)
		if person.get("assignment", "idle") not in ["idle", "watchpost", "defense"] and activity == "work":
			figure.keep_working()
		elif actor.get_meta("intent","") != activity:
			# The physical contact gate in _update_attention owns all speech
			# animations. An intention alone may point through a solid building.
			figure.reset_motion()
			actor.set_meta("physical_social_pose",false)
		actor.set_meta("intent",activity)
		actor.set_meta("activity",activity)


func _sync_raiders() -> void:
	var current := {}
	for enemy: Dictionary in state.village.raid.enemies:
		var id := str(enemy.id)
		current[id] = true
		var spawned := not raiders.has(id)
		if spawned:
			var actor := CharacterBody3D.new()
			actor.name = "Raider_" + id
			actor.collision_layer = 1
			actor.collision_mask = 1 | 2 | 4 | Layout.CITIZEN_LAYER
			actor.safe_margin = .006
			add_child(actor)
			var figure := Person.new()
			figure.name = "Figure"
			figure.position.y = .9
			actor.add_child(figure)
			# Owner decision D-040: the night riders are of unknown origin. The
			# second argument only selects the shared northern kit and hair of
			# the two available attacker models; no tribe, people or faction
			# is saved, shown or derived for a raider (label "Angreifer").
			figure.configure("enemy", "germania", 28)
			figure.configure_appearance("spearman", raiders.size())
			if raiders.size()%2 == 0:
				figure.configure_meshy("unit_germanic_axe_fighter")
			var shape := CollisionShape3D.new()
			shape.name = "PersonalSpace"
			var capsule := CapsuleShape3D.new()
			capsule.radius = .28
			capsule.height = 1.8
			shape.shape = capsule
			shape.position.y = .9
			actor.add_child(shape)
			var label := Art.label(actor, "Angreifer", Vector3(0,2.15,0), Color("edb0a1"), 27)
			label.name = "Health"
			label.visibility_range_end = 20
			raiders[id] = actor
		var actor: CharacterBody3D = raiders[id]
		var health := int(enemy.health)
		var previous := int(actor.get_meta("health", health))
		var position := Vector3(float(enemy.x), 0, float(enemy.z))
		_raider_targets[id] = position
		if spawned or _restore_raiders:
			actor.position = position
			# A raider comes up the north road facing his way in; he does not
			# appear with his back to the village and turn round on the spot.
			var ahead: Vector2 = Life.raider_waypoint(state,enemy)-Vector2(position.x,position.z)
			if ahead.length() > .05:
				actor.rotation.y = atan2(-ahead.x,-ahead.y)
			actor.set_meta("pace",0.0)
			actor.reset_physics_interpolation()
			_route_points.erase(id)
		var figure: Node3D = actor.get_node("Figure")
		figure.profile = quality
		figure.refresh_lod(get_viewport().get_camera_3d())
		if spawned or _restore_raiders or not active or health <= 0:
			figure.drive(0.0)
			actor.set_meta("actual_speed",0.0)
		var attack_clock := float(enemy.attack_timer)
		# The domain clock entering the wind-up starts the visible blow, timed
		# so the clip's contact frame meets the damage tick (RaiderStrike).
		# Resets of the clock (approach, after a blow, interrupt) never swing.
		var previous_clock := INF if spawned or _restore_raiders else float(actor.get_meta("attack_clock", attack_clock))
		if active and health > 0 and Strike.swinging(attack_clock) and attack_clock > .000001 and not Strike.swinging(previous_clock):
			var accumulator := float(state.village.social.get("accumulator",0.0))
			figure.cue_strike(maxf(.05,attack_clock-accumulator))
			actor.set_meta("strike_cues",int(actor.get_meta("strike_cues",0))+1)
		actor.set_meta("attack_clock", attack_clock)
		_raider_states[id] = enemy
		# A loaded casualty has no new health delta. Reassert the saved
		# terminal pose after spawn or GameWorld.setup resets the figure.
		# cue("death") is idempotent, so normal sync never restarts the fall.
		if health <= 0:
			figure.cue("death")
		elif health < previous:
			# Every received hit shows its own reaction. The rules interrupt a
			# begun blow on the same hit, so the swing never lands unseen.
			figure.cue("hit")
		actor.set_meta("health", health)
		actor.get_node("Health").text = "Angreifer · %d" % health if health > 0 else "Abgewehrt"
		actor.visible = bool(state.village.raid.active)
		actor.collision_layer = 1 if actor.visible and health > 0 else 0
	for id: String in raiders.keys():
		if not current.has(id):
			var actor: Node3D = raiders[id]
			remove_child(actor)
			actor.free()
			raiders.erase(id)
			_raider_targets.erase(id)
			_raider_states.erase(id)
			_route_points.erase(id)
			_route_clock.erase(id)
	_restore_raiders = false


func nearest(position: Vector3, radius := 3.2) -> String:
	if not visible:
		return ""
	var best := ""
	var distance := radius
	for npc: Dictionary in Life.npc_catalog(state):
		if not actors.has(npc.id):
			continue
		var actor: Node3D = actors[npc.id]
		if not actor.visible or not Life.is_available(state, str(npc.id)):
			continue
		var value := Vector2(position.x, position.z).distance_to(Vector2(actor.position.x, actor.position.z))
		if value < distance:
			distance = value
			best = npc.id
	return best


static func _indoors(at: Vector2) -> bool:
	for home: Dictionary in Layout.HOMES:
		if Layout.house_footprint(home, -0.35).has_point(at):
			return true
	return false


func actor_position(id: String) -> Vector3:
	return actors[id].global_position if actors.has(id) else Vector3.INF


func set_active(value: bool) -> void:
	active = value
	for actor: Node3D in actors.values():
		if not active:
			_set_social_pose(actor,false)
			actor.get_node("Figure").drive(0.0)
	if not active:
		for actor: Node3D in raiders.values():
			actor.get_node("Figure").drive(0.0)
			actor.set_meta("actual_speed",0.0)
	_update_nameplates()


func focus(id: String, player: Vector3) -> void:
	if focused != id:
		clear_focus()
	focused = id
	if actors.has(id):
		var actor: Node3D = actors[id]
		var direction := player - actor.global_position
		_focus_yaw = atan2(-direction.x,-direction.z) if Vector2(direction.x,direction.z).length() > .1 else actor.rotation.y
		actor.get_node("Figure").set_conversation_focus(true)
	_update_nameplates()


func clear_focus() -> void:
	if actors.has(focused):
		actors[focused].get_node("Figure").set_conversation_focus(false)
	focused = ""
	_update_nameplates()


func hint(position: Vector3) -> String:
	if not visible:
		return ""
	var raid: Dictionary = state.village.raid
	var at := Vector2(position.x, position.z)
	if raid.status == "warning":
		if at.distance_to(Life.SCOUT_POINT) < 3.2 and not raid.scouted:
			return "Interagieren · Spuren untersuchen"
		if at.distance_to(Life.ALARM_POINT) < 3.2 and not raid.alarm:
			return "Interagieren · Alarm geben"
	if raid.active and raid.rescue_available and not raid.rescued and at.distance_to(Life.RESCUE_POINT) < 3.2:
		return "Interagieren · Verletzte in Sicherheit bringen"
	var id := nearest(position)
	if not id.is_empty():
		return "Interagieren · Mit %s sprechen" % str(actors[id].get_meta("display_name",id))
	if raid.active:
		return "Angreifen · Blocken Q · Ausweichen R\nAusdauer %d / 100" % int(raid.stamina)
	return ""
