extends Node3D
## Visible people, workplaces and raiders are projections of saved village state.
## Their meshes never create workers, production, damage, friendships or XP.

const Life = preload("res://scripts/story/village_life.gd")
const Economy = preload("res://scripts/domain/village_economy.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const Art = preload("res://scripts/world/village_art.gd")
const Neighborhood = preload("res://scripts/world/village/childhood_neighborhood.gd")
const Childhood = preload("res://scripts/story/childhood_story.gd")
const PLACES := {"farm":Vector2(24,-30), "woodcamp":Vector2(-43,14),
	"quarry":Vector2(48,-12), "trade":Vector2(25,24), "watchpost":Vector2(0,-48)}
var actors: Dictionary = {}
var raiders: Dictionary = {}
var workplaces: Dictionary = {}
var state: Dictionary = {}
var quality := "balanced"
var active := false
var focused := ""
var _ready_scene := false
var _wood: StandardMaterial3D
var _stone: StandardMaterial3D
var _linen: StandardMaterial3D
var _escort_shape: CapsuleShape3D
var _escort_presenting := false


func _process(_delta: float) -> void:
	_update_nameplates()


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
	state = data
	quality = profile
	visible = bool(data.get("village", {}).get("enabled", false))
	if not visible:
		# Hiding a Node3D does not disable PhysicsServer collision. A later
		# regional/legacy game must not retain invisible childhood residents.
		for actor: Node3D in actors.values():
			actor.get_node("ResidentBody").collision_layer = 0
		return
	if not _ready_scene:
		_create()
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
			Art.box(node, Vector3(.16,2.2,.16), Vector3(x,1.1,z), _wood)
	Art.roof(repaired, 4.6, 3.2, 2.2, .8, _linen)
	var broken := Art.box(damaged, Vector3(3.7,.14,.24), Vector3(0,.4,0), _wood)
	broken.rotation.z = -.28
	# The workyard shares the existing ground collider. Keep its visible top at
	# that height; a decorative ten-centimetre slab would bury residents' feet.
	Art.box(node, Vector3(4.5,.12,2.9), Vector3(0,-.06,0), _stone)
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
	if not actors.has(id):
		var actor := Node3D.new()
		actor.name = "Resident_" + id
		actor.set_meta("resident_id",id)
		actor.set_meta("identity_source","village_economy" if id != "decimus" else "village_authority")
		add_child(actor)
		var figure := Person.new()
		figure.name = "Figure"
		figure.position.y = .9
		actor.add_child(figure)
		figure.configure("resident", "italia", 32 + actors.size() % 20)
		var appearance := "civilian_woman" if id in ["aelia", "aurelia", "cassia", "drusa", "julia", "valeria", "antonia"] else "civilian_man"
		if id == "severus":
			appearance = "legionary"
		if id == "decimus":
			appearance = "elder"
		figure.configure_appearance(appearance, actors.size())
		var label := Art.label(actor, caption + " · " + profession, Vector3(0,2.08,0), Color("efdbad"), 27)
		label.name = "Nameplate"
		label.pixel_size = .003
		label.visibility_range_begin = 3.0
		label.visibility_range_end = 6
		label.hide()
		var body := StaticBody3D.new()
		body.name = "ResidentBody"
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = .29
		capsule.height = 1.72
		collision.shape = capsule
		collision.position.y = .86
		body.add_child(collision)
		actor.add_child(body)
		actors[id] = actor
	var actor: Node3D = actors[id]
	var at: Vector2 = Life.actor_position(state, id)
	var childhood := bool(state.get("village",{}).get("childhood",{}).get("enabled",false))
	actor.position = Vector3(at.x,Neighborhood.resident_floor_height_at(at) if childhood else 0.0,at.y)
	actor.visible = bool(person.get("alive", true)) and not state.village.get("militia", []).has(id)
	actor.get_node("ResidentBody").collision_layer = 1 if actor.visible and visible and childhood else 0
	actor.set_meta("assignment", person.get("assignment", "idle"))
	actor.set_meta("display_name",caption)
	var displayed_role: String = str(Neighborhood.IDENTITY_ROLES.get(id,profession)) if childhood else profession
	actor.get_node("Nameplate").text = caption+" · "+displayed_role
	var figure: Node3D = actor.get_node("Figure")
	figure.profile = quality
	figure.refresh_lod(get_viewport().get_camera_3d())
	if person.get("assignment", "idle") not in ["idle", "watchpost", "defense"] and active:
		figure.keep_working()


func _sync_raiders() -> void:
	var current := {}
	for enemy: Dictionary in state.village.raid.enemies:
		var id := str(enemy.id)
		current[id] = true
		if not raiders.has(id):
			var actor := Node3D.new()
			actor.name = "Raider_" + id
			add_child(actor)
			var figure := Person.new()
			figure.name = "Figure"
			figure.position.y = .9
			actor.add_child(figure)
			figure.configure("enemy", "germania", 28)
			figure.configure_appearance("spearman", raiders.size())
			var body := StaticBody3D.new()
			body.name = "Body"
			body.collision_layer = 1
			body.collision_mask = 0
			var shape := CollisionShape3D.new()
			var capsule := CapsuleShape3D.new()
			capsule.radius = .28
			capsule.height = 1.8
			shape.shape = capsule
			shape.position.y = .9
			body.add_child(shape)
			actor.add_child(body)
			var label := Art.label(actor, "Angreifer", Vector3(0,2.15,0), Color("edb0a1"), 27)
			label.name = "Health"
			label.visibility_range_end = 20
			raiders[id] = actor
		var actor: Node3D = raiders[id]
		var health := int(enemy.health)
		var previous := int(actor.get_meta("health", health))
		var position := Vector3(float(enemy.x), 0, float(enemy.z))
		var delta := position - actor.position
		if delta.length_squared() > .001:
			actor.rotation.y = atan2(-delta.x, -delta.z)
		actor.position = position
		var figure: Node3D = actor.get_node("Figure")
		figure.profile = quality
		figure.drive(1.8 if active and health > 0 and delta.length_squared() > .00001 else 0.0)
		var attack_clock := float(enemy.attack_timer)
		if active and health > 0 and attack_clock > float(actor.get_meta("attack_clock", attack_clock)) + .2:
			figure.cue("attack")
		actor.set_meta("attack_clock", attack_clock)
		if health < previous:
			figure.cue("death" if health <= 0 else "hit")
		actor.set_meta("health", health)
		actor.get_node("Health").text = "Angreifer · %d" % health if health > 0 else "Abgewehrt"
		actor.visible = bool(state.village.raid.active)
		actor.get_node("Body").collision_layer = 1 if actor.visible and health > 0 else 0
	for id: String in raiders.keys():
		if not current.has(id):
			var actor: Node3D = raiders[id]
			remove_child(actor)
			actor.free()
			raiders.erase(id)


func nearest(position: Vector3, radius := 3.2) -> String:
	if not visible:
		return ""
	var best := ""
	var distance := radius
	for npc: Dictionary in Life.npc_catalog():
		if not actors.has(npc.id):
			continue
		var actor: Node3D = actors[npc.id]
		if not actor.visible or not Life.is_available(state, str(npc.id)):
			continue
		var value := Vector2(position.x, position.z).distance_to(Vector2(actor.position.x, actor.position.z))
		if value < distance:
			# Do not start a family conversation through the outside wall. The
			# target's own capsule is excluded; solid doors and walls are not.
			if is_inside_tree() and bool(state.get("village",{}).get("childhood",{}).get("enabled",false)):
				var query := PhysicsRayQueryParameters3D.create(position+Vector3.UP*.45,actor.global_position+Vector3.UP*1.35,1)
				query.exclude = [actor_collision_rid(str(npc.id))]
				if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
					continue
			distance = value
			best = npc.id
	return best


func actor_position(id: String) -> Vector3:
	return actors[id].global_position if actors.has(id) else Vector3.INF


func actor_collision_rid(id: String) -> RID:
	if not actors.has(id):
		return RID()
	var body := actors[id].get_node_or_null("ResidentBody") as StaticBody3D
	return body.get_rid() if body != null else RID()


func escort_progress_limit(data: Dictionary, delta: float) -> float:
	# The domain remains the only owner of progress and the saved position. This
	# query grants only the next clear portion of its fixed, authored escape route.
	# Sweeps include the player and other bodies, not only static house geometry.
	if not Childhood.enabled(data) or data.village.childhood.scene_id != "night_escort":
		return INF
	var progress := float(data.village.childhood.escort.progress)
	if not is_inside_tree() or not actors.has("julia") or not is_finite(delta) or delta <= 0.0:
		return progress
	if not actors.julia.visible:
		return progress
	if _escort_shape == null:
		_escort_shape = CapsuleShape3D.new()
		_escort_shape.radius = .29
		_escort_shape.height = 1.72
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _escort_shape
	query.collision_mask = 1 | 2 | 4
	query.margin = .002
	query.exclude = [actor_collision_rid("julia")]
	var space := get_world_3d().direct_space_state
	var limit := minf(Childhood._escort_length(),progress+Childhood.ESCORT_SPEED*delta)
	var clear := progress
	while clear < limit-.000001:
		var next := minf(limit,clear+.08)
		var from := _escort_query_position(Childhood._escort_point(clear))
		var to := _escort_query_position(Childhood._escort_point(next))
		query.transform.origin = from
		query.motion = Vector3.ZERO
		if not space.intersect_shape(query,1).is_empty():
			return clear
		query.motion = to-from
		var fractions := space.cast_motion(query)
		if fractions.size() < 2 or fractions[0] < .9999:
			return clear
		clear = next
	return clear


func sync_escort(data: Dictionary, delta: float) -> void:
	# Called after the domain accepts the collision-limited step. This projects
	# that exact saved position every frame; it does not simulate a second Julia.
	var following: bool = Childhood.enabled(data) and data.village.childhood.scene_id == "night_escort"
	if not following or not active or not actors.has("julia") or not actors.julia.visible:
		if _escort_presenting and actors.has("julia"):
			actors.julia.get_node("Figure").drive(0.0)
		_escort_presenting = false
		return
	_escort_presenting = true
	var actor: Node3D = actors.julia
	var at: Vector2 = Life.actor_position(data,"julia")
	var target := Vector3(at.x,Neighborhood.resident_floor_height_at(at),at.y)
	var direction := target-actor.position
	direction.y = 0.0
	actor.position = target
	var speed := minf(Childhood.ESCORT_SPEED,direction.length()/maxf(delta,.0001))
	actor.get_node("Figure").drive(speed)
	if direction.length() > .0001:
		actor.rotation.y = atan2(-direction.x,-direction.z)


static func _escort_query_position(point: Vector2) -> Vector3:
	# A small query margin above the exact round-sole support prevents the floor
	# contact itself from being mistaken for a wall or an obstructing person.
	return Vector3(point.x,Neighborhood.resident_floor_height_at(point)+.868,point.y)


func set_active(value: bool) -> void:
	active = value
	for actor: Node3D in actors.values():
		if not active:
			actor.get_node("Figure").drive(0.0)
	_update_nameplates()


func focus(id: String, player: Vector3) -> void:
	focused = id
	if actors.has(id) and actors[id].visible and Life.is_available(state,id):
		var actor: Node3D = actors[id]
		var direction := player - actor.global_position
		actor.rotation.y = atan2(-direction.x, -direction.z)
		actor.get_node("Figure").cue("talk")
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
