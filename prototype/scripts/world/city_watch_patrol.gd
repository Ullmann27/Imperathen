extends Node3D
## A visiting market escort (creative campaign extension), walking on the same
## baked road graph as urban commuters. The visible bodies use army roster UIDs.
const Watch = preload("res://scripts/domain/city_watch.gd")
const Streets = preload("res://scripts/domain/city_streets.gd")
const Slots = preload("res://scripts/battle/formation_slots.gd")
const Soldier = preload("res://scripts/visuals/soldier_visual.gd")
const Touch = preload("res://scripts/ui/touch_action.gd")
const Combat = preload("res://scripts/domain/combat_actions.gd")
const ROAD_POINTS := [Vector3(-37,0.1,62),Vector3(37,0.1,62),Vector3(37,0.1,68),Vector3(-37,0.1,68)]
const PACE := 1.35
const APPROACH_LIMIT := 8.0
const YIELD_TIME := 1.0
var city
var records: Array[Dictionary] = []
var bodies: Array[CharacterBody3D] = []
var slots: Array[Vector2] = []
var path := PackedVector3Array()
var circuit := 0.0
var distance := 0.0
var phase := "march"
var pressure := 0.0
var contact_time := 0.0
var _warned := false
var _near_time := 0.0
var _cooldown := 0.0
var _lod_time := 0.0
var _next_lod := 0
var _day := -1
var _slot_points := PackedVector3Array()
var _heading := Vector3.RIGHT
var _panel := PanelContainer.new()
var _statement := Label.new()
var _choices := HBoxContainer.new()
var _yield := Touch.new()
var _answer := Touch.new()

func setup(host: Node3D, streets: Streets, hud: Control) -> bool:
	city = host
	records = Watch.roster(city.campaign.data)
	if records.size() != Watch.COUNT or records[0].status != "active" or not _build_circuit(streets):
		return false
	_day = int(city.campaign.data.calendar.clock.jdn)
	distance = fposmod((float(city.campaign.data.calendar.clock.second) - 8 * 3600) * PACE + 25.0,circuit)
	if city.campaign.data.calendar.clock.second < 6 * 3600 or city.campaign.data.calendar.clock.second >= 19 * 3600:
		distance = 0.0
	for person: Dictionary in records:
		if person.status == "active":
			_add_soldier(person)
	slots = Slots.offsets("column",bodies.size(),1.65)
	_project_slots()
	for i in bodies.size():
		bodies[i].position = _slot_points[i] + Vector3.UP * 0.03
		bodies[i].rotation.y = atan2(-_heading.x,-_heading.z)
	_build_panel(hud)
	city.campaign.city_watch_observation = observation
	return true

func _build_circuit(streets: Streets) -> bool:
	for i in ROAD_POINTS.size():
		var a := streets.node_for("march.corner_%d" % i,ROAD_POINTS[i])
		var b := streets.node_for("march.corner_%d" % ((i+1)%ROAD_POINTS.size()),ROAD_POINTS[(i+1)%ROAD_POINTS.size()])
		var leg := streets.route(a,b)
		if leg.size() < 2:
			return false
		for point in leg:
			if path.is_empty() or point.distance_squared_to(path[-1]) > 0.0001:
				path.append(point)
	circuit = Streets.polyline_length(path)
	return circuit > 10.0

func _add_soldier(person: Dictionary) -> void:
	var unit := CharacterBody3D.new()
	unit.name = person.uid
	unit.set_meta("actor_uid","sol:"+str(person.uid))
	unit.set_meta("display_name",person.name)
	unit.collision_layer = 2
	unit.collision_mask = 3
	unit.floor_snap_length = 0.25
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .25
	capsule.height = 1.68
	collider.shape = capsule
	collider.position.y = 0.85
	unit.add_child(collider)
	var figure := Soldier.new()
	figure.name = "Soldier"
	figure.detail = 1 if city.profile in ["balanced","low"] else 0
	var role: String = ["officer","spear","heavy","heavy","spear","heavy"][bodies.size()]
	figure.configure(role,int(person.appearance_seed))
	# Company Blender meshes face +Z after glTF conversion. The city
	# CharacterBody navigation contract faces -Z; rotate only its visual.
	figure.rotation.y = PI
	unit.add_child(figure)
	add_child(unit)
	bodies.append(unit)

func _project_slots() -> void:
	_slot_points.clear()
	_heading = Streets.along(path,distance)[1]
	for slot: Vector2 in slots:
		var sample := Streets.along(path,fposmod(distance-slot.y,circuit))
		var right: Vector3 = (sample[1] as Vector3).cross(Vector3.UP).normalized()
		_slot_points.append(sample[0] + right*slot.x)

func _build_panel(hud: Control) -> void:
	_panel.name = "WatchDialogue"
	hud.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.anchor_top = .37
	_panel.anchor_bottom = .37
	_panel.offset_left = -150
	_panel.offset_right = 150
	var column := VBoxContainer.new()
	_panel.add_child(column)
	_statement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_statement.custom_minimum_size.x = 296
	column.add_child(_statement)
	column.add_child(_choices)
	for button: Button in [_yield,_answer]:
		button.custom_minimum_size = Vector2(135,56)
		_choices.add_child(button)
	_yield.text = "Platz machen"
	_yield.pressed.connect(reply.bind("yield"))
	_answer.pressed.connect(func(): reply("resist" if phase == "dispute" else "argue"))
	_panel.hide()

func _talk_panel() -> void:
	_panel.show()
	_statement.text = ("%s · Wachführer\n»Du hältst unseren Zug auf. Lass uns passieren.«" % records[0].name) if phase == "talk" else "»Genug jetzt. Tritt zur Seite.«"
	_answer.text = "Widersprechen" if phase == "talk" else "Sich widersetzen"
	_answer.visible = phase == "talk" or int(city.campaign.data.player.age) >= 18

func suspend() -> void:
	if is_instance_valid(_panel):
		_panel.hide()

func _clear_path() -> bool:
	var a := bodies[0].global_position + Vector3.UP*1.1
	var b: Vector3 = city.player.global_position + Vector3.UP*.15
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1)).is_empty()

func observation() -> Dictionary:
	if bodies.is_empty() or not is_inside_tree() or city.paused or city.market.is_open() or city._tablet_dialog.visible:
		return {}
	return {"world_id":city.campaign.data.world_id,"commander":bodies[0].get_meta("actor_uid"),"day":_day,
		"phase":phase,"pressure":pressure,"distance":_gap(bodies[0]),"clear":_clear_path(),"contact_time":contact_time,
		"guard":float(city.training.state().get("guard_remaining",0.0))>0}

func _gap(body: Node3D) -> float:
	var feet: Vector3 = city.player.global_position - Vector3.UP * city.SOLE_OFFSET
	return body.global_position.distance_to(feet)

func reply(choice: String) -> bool:
	var result: Dictionary = city.campaign.execute("city_watch_reply",{"choice":choice})
	city._market_message(result.message)
	if not result.ok:
		return false
	match choice:
		"yield":
			_regroup()
		"argue":
			phase = "dispute"
			_talk_panel()
		"resist":
			phase = "scuffle"
			contact_time = 0.0
			_panel.hide()
	return true

func _regroup() -> void:
	phase = "regroup"
	_panel.hide()
	_cooldown = 12.0
	pressure = 0.0
	_near_time = 0.0
	_warned = false

func tick(delta: float) -> void:
	if bodies.is_empty() or delta <= 0:
		return
	_day = int(city.campaign.data.calendar.clock.jdn)
	_cooldown = maxf(0,_cooldown-delta)
	# Stagger changes of skeletons/meshes; all tiers retain their physics body.
	_lod_time -= delta
	if _lod_time <= 0.0:
		_update_detail(bodies[_next_lod])
		_next_lod = (_next_lod+1) % bodies.size()
		_lod_time = .08
	var second := int(city.campaign.data.calendar.clock.second)
	var on_shift := second >= 6*3600 and second < 19*3600
	if phase == "march" and on_shift:
		distance = fposmod(distance + PACE*delta,circuit)
		_project_slots()
	var leader: CharacterBody3D = bodies[0]
	for i in bodies.size():
		var at := _slot_points[i]
		var speed := PACE + .35
		if i == 0 and phase in ["approach","talk","dispute","scuffle"]:
			var toward := _toward_player()
			at = city.player.position - toward * 1.15
			speed = 1.65
			if phase in ["talk","dispute"]:
				at = leader.position
				leader.rotation.y = rotate_toward(leader.rotation.y,atan2(-toward.x,-toward.z),delta*5.0)
		_drive(bodies[i],at,speed,delta)
	var gap := _gap(leader)
	match phase:
		"march":
			if on_shift and _cooldown == 0.0:
				_sense(delta)
		"approach":
			if gap > APPROACH_LIMIT:
				_regroup()
			elif gap <= 1.75 and _clear_path():
				phase = "talk"
				_talk_panel()
		"talk","dispute":
			if gap > 2.8 or not _clear_path():
				_regroup()
			else:
				_talk_panel()
		"scuffle":
			contact_time += delta
			var contact_phase := Combat.phase("jab_right",contact_time)
			leader.get_node("Soldier").present("block",minf(1,contact_time/0.68),delta)
			if gap < 1.65 and contact_phase == "active" and _clear_path():
				var hit: Dictionary = city.campaign.execute("city_watch_contact")
				if hit.ok:
					city.player.move_and_collide(_toward_player()*0.32)
					city._market_message(hit.message)
					_regroup()
			elif contact_time >= .68:
				city._market_message("Du weichst zurück. Die Wache zieht weiter.")
				_regroup()
		"regroup":
			if _flat(leader.position-_slot_points[0]).length() <= .18:
				phase = "march"

func _drive(body: CharacterBody3D, target: Vector3, speed: float, delta: float) -> void:
	var toward := _flat(target-body.position)
	var step := toward.limit_length(speed*delta)
	if body == bodies[0] and phase in ["approach","regroup","scuffle"] and toward.length() > .2:
		# A commander leaving an inside file may have a comrade between him
		# and the player. Sweep the actual capsule before choosing a sidestep.
		var probe := toward.limit_length(.45)
		if body.test_move(body.global_transform,probe):
			for angle: float in [55.0,-55.0,85.0,-85.0,110.0,-110.0]:
				var alternate := probe.rotated(Vector3.UP,deg_to_rad(angle))
				if not body.test_move(body.global_transform,alternate):
					step = alternate.normalized() * speed * delta
					break
	var before := body.position
	body.velocity = Vector3(step.x/delta, -.4 if body.is_on_floor() else body.velocity.y - 19.6*delta, step.z/delta)
	body.move_and_slide()
	var movement := _flat(body.position-before)
	var moving := movement.length_squared() > .000001
	if moving:
		body.rotation.y = rotate_toward(body.rotation.y, atan2(-movement.x,-movement.z),delta*4.0)
	var model: Soldier = body.get_node("Soldier")
	if body == bodies[0] and phase == "scuffle":
		return
	# Actual displacement, not a perpetual one-second walk cycle, drives
	# the imported gait. The column stops moving its feet when blocked.
	var gait_phase := float(body.get_meta("city_watch_gait_phase",0.0))
	if moving:
		gait_phase = fposmod(gait_phase + movement.length()/float(Soldier.STRIDES.march),1.0)
		body.set_meta("city_watch_gait_phase",gait_phase)
		model.present("march",gait_phase,delta)
	else:
		gait_phase = fposmod(gait_phase+delta/2.0,1.0)
		body.set_meta("city_watch_gait_phase",gait_phase)
		model.present("idle",gait_phase,delta)

func _update_detail(body: CharacterBody3D) -> void:
	var figure: Soldier = body.get_node("Soldier")
	var gap := _gap(body)
	var near_range := 8.0 if city.profile == "low" else 16.0
	var far_range := 36.0 if city.profile == "low" else 58.0
	# Separate entry and exit distances avoid rebuilding at a boundary.
	if gap < near_range - (1.5 if figure.detail > 0 else 0.0):
		figure.set_detail(0)
	elif gap > far_range + (3.0 if figure.detail < 2 else 0.0):
		# This small six-man street patrol remains animated at distance.
		# The battle-only far mesh has no skeleton and would slide.
		figure.set_detail(1)
	else:
		figure.set_detail(1)

func _toward_player() -> Vector3:
	var direction := _flat(city.player.position - bodies[0].position).normalized()
	return direction if direction.length_squared() > .1 else _heading

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x,0,v.z)

func _sense(delta: float) -> void:
	var record: Dictionary = city.campaign.data.world_state.politics.get("street_watch",{})
	if record.get("day",-1) == _day:
		return
	var nearest := 999.0
	for body in bodies:
		nearest = minf(nearest,_gap(body))
	var relative := _flat(city.player.position-bodies[0].position)
	var front := relative.dot(_heading)
	var sideways := relative - _heading*front
	var blocking := nearest <= .8 or (front >= 0 and front < 2.3 and sideways.length() < 1.0)
	if blocking:
		_near_time += delta
		if not _warned and _near_time >= YIELD_TIME:
			_warned = true
			city._market_message("»Wir kennen dich schon. Heute bleibt die Straße frei.«" if Watch.reputation(city.campaign.data) < 0 else "»Bahn frei, bitte!« Der Wachzug muss über die Marktstraße.")
			if nearest <= .85:
				var side := _heading.cross(Vector3.UP)
				city.player.move_and_collide(side * (.22 if side.dot(relative) >= 0 else -.22))
	var following := _warned and front < 0 and front > -4.8 and sideways.length() < 1.3 and _flat(city.player.velocity).dot(_heading) > .65
	if blocking or following:
		pressure = minf(Watch.PRESSURE_SECONDS,pressure+delta)
	else:
		pressure = maxf(0,pressure-delta*2.0)
		_near_time = maxf(0,_near_time-delta)
		if pressure == 0.0:
			_warned = false
	if _warned and pressure >= Watch.PRESSURE_SECONDS and _gap(bodies[0]) <= APPROACH_LIMIT:
		phase = "approach"

func _exit_tree() -> void:
	if is_instance_valid(city) and city.campaign != null and city.campaign.city_watch_observation == Callable(self,"observation"):
		city.campaign.city_watch_observation = Callable()
