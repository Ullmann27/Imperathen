extends Node3D
## Visible people, workplaces and raiders are projections of saved village state.
## Their meshes never create workers, production, damage, friendships or XP.

const Life = preload("res://scripts/story/village_life.gd")
const Economy = preload("res://scripts/domain/village_economy.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const Art = preload("res://scripts/world/village_art.gd")
const Layout = preload("res://scripts/world/village/village_layout.gd")
const Behavior = preload("res://scripts/domain/npc_behavior.gd")
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


func _process(delta: float) -> void:
	_update_nameplates()
	_update_attention(delta)


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
	for id: String in actors:
		var actor: Node3D = actors[id]
		if not actor.visible:
			continue
		var intent := Behavior.view(state,id)
		if intent.is_empty() or intent.activity not in ["greet","space","socialize","alert","assist"]:
			continue
		var target := player
		if state.village.behavior.people.has(intent.partner):
			var other: Array = state.village.behavior.people[intent.partner].position
			target = Vector3(float(other[0]),float(other[1]),float(other[2]))
		elif intent.activity in ["alert","assist"]:
			var distance := INF
			for enemy: Dictionary in state.village.raid.enemies:
				if int(enemy.health) <= 0:
					continue
				var at := Vector3(float(enemy.x),0,float(enemy.z))
				if actor.position.distance_squared_to(at) < distance:
					distance = actor.position.distance_squared_to(at)
					target = at
		var offset := target-actor.global_position
		if Vector2(offset.x,offset.z).length() > .1:
			actor.rotation.y = lerp_angle(actor.rotation.y,atan2(-offset.x,-offset.z),minf(1.0,delta*4.0))


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
		_set_collisions(false)
		return
	if not _ready_scene:
		_create()
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


func _set_collisions(enabled: bool) -> void:
	for body: StaticBody3D in find_children("*","StaticBody3D",true,false):
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
	var at: Vector2 = Life.actor_position(state, id)
	if not actors.has(id):
		var actor := StaticBody3D.new()
		actor.name = "Resident_" + id
		actor.position = Vector3(at.x,0,at.y)
		actor.collision_layer = Layout.CITIZEN_LAYER
		actor.collision_mask = 0
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
	var actor: StaticBody3D = actors[id]
	actor.set_meta("display_name",caption)
	actor.position = Vector3(at.x, 0, at.y)
	actor.visible = bool(person.get("alive", true)) and not state.village.get("militia", []).has(id)
	actor.collision_layer = Layout.CITIZEN_LAYER if actor.visible and visible else 0
	actor.set_meta("assignment", person.get("assignment", "idle"))
	var figure: Node3D = actor.get_node("Figure")
	figure.profile = quality
	figure.refresh_lod(get_viewport().get_camera_3d())
	if focused != id and active:
		var intent := Behavior.view(state,id)
		var activity := str(intent.get("activity","work"))
		figure.drive(0.0)
		if person.get("assignment", "idle") not in ["idle", "watchpost", "defense"] and activity == "work":
			figure.keep_working()
		elif actor.get_meta("intent","") != activity:
			figure.reset_motion()
			if activity in ["greet","socialize","space"]:
				figure.cue("talk")
		actor.set_meta("intent",activity)
		actor.set_meta("activity",activity)


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
			if raiders.size()%2 == 0:
				figure.configure_meshy("unit_germanic_axe_fighter")
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


func actor_position(id: String) -> Vector3:
	return actors[id].global_position if actors.has(id) else Vector3.INF


func set_active(value: bool) -> void:
	active = value
	for actor: Node3D in actors.values():
		if not active:
			actor.get_node("Figure").drive(0.0)
	_update_nameplates()


func focus(id: String, player: Vector3) -> void:
	focused = id
	if actors.has(id):
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
