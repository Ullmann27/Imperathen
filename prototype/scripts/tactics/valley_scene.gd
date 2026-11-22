extends Node3D

signal leave_requested
signal battle_finished
const Rules = preload("res://scripts/battle/battle_model.gd")
const Landscape = preload("res://scripts/tactics/valley_landscape.gd")
const HUD = preload("res://scripts/tactics/valley_hud.gd")
const Soldier = preload("res://scripts/visuals/soldier_visual.gd")
const SIDES := {"ally":Color("#67d7c4"),"enemy":Color("#e58663")}
var model = Rules.new()
var hud = HUD.new()
var land = Landscape.new()
var far_ranks = preload("res://scripts/visuals/far_ranks.gd").new()
var camera := Camera3D.new()
var focus := Vector2(0,4.5)
var distance := 38.0
var selected := []
var actors := {}
var targets := {}
var standards := {}
var groups := {}
var profile := "balanced"
var paused := true
var speed := 1.0
var message := "Halte das Talzeichen für 120 s. Wähle einen Verband und drücke Fortsetzen."
var pending := ""
var fingers := {}
var gesture := ""
var origin := Vector2.ZERO
var cursor := Vector2.ZERO
var pressed_at := 0
var ghost := MultiMeshInstance3D.new()
var sampled_step := -1
var lod_due := 0.0

func _ready() -> void:
	add_child(land)
	add_child(far_ranks)
	land.apply_quality(profile)
	add_child(camera)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#b6c6ca")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#ccc8b6")
	environment.ambient_light_energy = 0.59
	environment.fog_enabled = true
	environment.fog_light_color = Color("#b7b4a4")
	environment.fog_density = 0.002
	camera.environment = environment
	camera.fov = 52
	camera.current = true
	_place_camera()
	_marker("objective","◆  TALZEICHEN",Color("#ffe39b"))
	standards.objective.position = _surface(Rules.OBJECTIVE) + Vector3.UP*0.8
	for s: Dictionary in model.squads.values():
		_marker(s.id,s.name.to_upper(),SIDES[s.side])
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.31
	mesh.bottom_radius = 0.31
	mesh.height = 0.09
	mesh.radial_segments = 8
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.35,1.0,0.8,0.72)
	mesh.material = mat
	ghost.multimesh = MultiMesh.new()
	ghost.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	ghost.multimesh.mesh = mesh
	add_child(ghost)
	add_child(hud)
	hud.populate(model)
	hud.requested.connect(_action)
	_sync_units()
	_refresh()
	print("IMPERATHEN_VALLEY_READY")

func _surface(p: Vector2) -> Vector3:
	return Vector3(p.x,Rules.ground_height(p.x,p.y),p.y)

func _marker(id: String,caption: String,tint: Color) -> void:
	var flag := Label3D.new()
	flag.text = caption
	flag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	flag.font_size = 30
	flag.pixel_size = 0.022
	flag.outline_size = 8
	flag.modulate = tint
	add_child(flag)
	standards[id] = flag

func _place_camera() -> void:
	var center := _surface(focus)
	camera.position = center + Vector3(0,0.79,0.69)*distance
	camera.look_at(center,Vector3.UP)

func _process(delta: float) -> void:
	if not paused and model.outcome == "ongoing":
		model.tick(minf(delta,0.5)*speed)
		if model.outcome != "ongoing":
			paused = true
			battle_finished.emit()
	var direction := Vector2(float(Input.is_key_pressed(KEY_D))-float(Input.is_key_pressed(KEY_A)),float(Input.is_key_pressed(KEY_S))-float(Input.is_key_pressed(KEY_W)))
	if direction != Vector2.ZERO:
		_pan(direction.normalized()*delta*distance*0.55)
	lod_due -= delta
	if sampled_step != model.steps or lod_due <= 0:
		lod_due = 0.28
		sampled_step = model.steps
		_sync_units()
		_refresh()
	for id in targets:
		var actor: Node3D = actors[id]
		actor.position = actor.position.lerp(targets[id],1.0-exp(-delta*19.0))
	if gesture == "touch" and not selected.is_empty() and Time.get_ticks_msec()-pressed_at >= 360:
		gesture = "deploy"
		message = "Ziehe die Front. Loslassen bestätigt die markierten Plätze."
		_preview()

func _sync_units() -> void:
	var live := {}
	var distant := {}
	var counts := [0,0,0]
	for s: Dictionary in model.squads.values():
		var flag: Label3D = standards[s.id]
		flag.position = _surface(Vector2(s.x,s.z))+Vector3.UP*2.75
		flag.visible = s.strength > 0 and s.status != "withdrawn"
		flag.text = ("◆ " if s.id in selected else "") + str(s.name).to_upper()
		flag.modulate = Color("#ffe098") if s.id in selected else SIDES[s.side]
		if not flag.visible:
			continue
		var i := 0
		for man in model.soldiers(s.id):
			var id: String = man.id
			live[id] = true
			var destination := _surface(Vector2(man.x,man.z))
			var dist := camera.position.distance_to(destination)
			var near_limit := 13.0 if profile == "low" else (25.0 if profile == "high" else 18.0)
			var mid_limit := near_limit + (42.0 if profile == "high" else 30.0)
			var detail := 0 if dist < near_limit else (1 if dist < mid_limit else 2)
			var role := "spear" if s.kind == "spear" else ("archer" if s.kind == "archer" else "heavy")
			if id == s.officer_id and s.side == "ally" and s.kind == "infantry":
				role = "officer"
			counts[detail] += 1
			if detail == 2:
				if not distant.has(role):
					distant[role] = []
				distant[role].append(Transform3D(Basis(Vector3.UP,float(man.facing)+PI),destination))
				if actors.has(id):
					actors[id].queue_free()
					actors.erase(id)
					targets.erase(id)
				i += 1
				continue
			if not actors.has(id):
				var actor = Soldier.new()
				actor.role = role
				actor.variant = i % 3
				actor.detail = detail
				actors[id] = actor
				actor.position = destination
				add_child(actor)
			var node = actors[id]
			if node.role != role:
				node.configure(role,node.variant)
			node.set_detail(detail)
			node.rotation.y = float(man.facing) + PI
			var pose: String = man.pose
			if pose == "idle" and s.formation in ["shield_wall","testudo"]:
				pose = "wall" if s.formation == "shield_wall" else "testudo"
			if node.state != pose or (pose in ["attack","shoot"] and node.player and not node.player.is_playing()):
				node.play_state(pose)
			targets[id] = destination
			i += 1
	far_ranks.sync(distant)
	get_node("/root/RuntimeDisplay").set_unit_counts(counts[0],counts[1],counts[2])
	for id in actors.keys():
		if not live.has(id):
			var fallen = actors[id]
			targets.erase(id)
			actors.erase(id)
			fallen.play_state("death")
			var fade := create_tween()
			fade.tween_interval(1.25)
			fade.tween_callback(fallen.queue_free)

func _refresh() -> void:
	hud.refresh(model,selected,paused,speed,message)

func _action(action: String,arg: String = "") -> void:
	match action:
		"leave":
			leave_requested.emit()
			return
		"pause":
			if model.outcome == "ongoing":
				paused = not paused
				message = "Zeit angehalten. Befehle können erteilt werden." if paused else "Talzeichen halten · Formation durch Ziehen ausrichten."
		"speed": speed = 0.35 if speed == 1.0 else 1.0
		"zoom_in": _zoom(0.8)
		"zoom_out": _zoom(1.25)
		"multi": pass
		"select": _select(arg,hud.group_button.button_pressed)
		"form": _issue("form",arg)
		"command":
			if arg in ["move","attack_move","attack","flank","focus_fire"]:
				pending = arg
				message = "Gegnerischen Verband wählen." if arg in ["attack","flank","focus_fire"] else "Ziel auf dem Gelände wählen."
			else:
				_issue(arg)
	_refresh()

func _select(id: String, add: bool) -> void:
	if not model.squads.has(id) or model.squads[id].side != "ally":
		return
	if add and id in selected:
		selected.erase(id)
	else:
		if not add:
			selected.clear()
		if id not in selected:
			selected.append(id)
	pending = ""
	var s: Dictionary = model.squads[id]
	message = "%s · %s · Moral %d · Erschöpfung %d" % [s.name,model.FORMATIONS[s.formation],s.morale,s.fatigue]
	_refresh()

func _issue(command: String, arg: Variant = null) -> void:
	var result: Dictionary = model.order(selected,command,arg)
	message = result.message
	pending = ""
	_refresh()

func _pan(amount: Vector2) -> void:
	focus = (focus + amount).clamp(Vector2(-29,-23),Vector2(29,23))
	_place_camera()

func _zoom(factor: float) -> void:
	distance = clampf(distance*factor,5.0,65.0)
	_place_camera()
	lod_due = 0

func _ground(pixel: Vector2) -> Vector2:
	var ray := camera.project_ray_normal(pixel)
	var eye := camera.project_ray_origin(pixel)
	var t := -eye.y/minf(-0.001,ray.y)
	for i in 5:
		var at := eye+ray*t
		t = (Rules.ground_height(at.x,at.z)-eye.y)/minf(-0.001,ray.y)
	var point := eye+ray*t
	return Vector2(point.x,point.z)

func _pick(pixel: Vector2) -> String:
	var nearest := ""
	var threshold := 32.0
	for s: Dictionary in model.squads.values():
		if s.strength <= 0 or s.status == "withdrawn":
			continue
		var p := _surface(Vector2(s.x,s.z))
		var d := minf(camera.unproject_position(p+Vector3.UP*0.65).distance_to(pixel),camera.unproject_position(standards[s.id].position).distance_to(pixel))
		if d < threshold:
			nearest = s.id
			threshold = d
	return nearest

func _tap(pixel: Vector2, command_click: bool, add: bool) -> void:
	var id := _pick(pixel)
	if not pending.is_empty():
		if pending in ["attack","flank","focus_fire"]:
			_issue(pending,id)
		else:
			_issue(pending,_ground(pixel))
	elif id != "" and model.squads[id].side == "ally" and not command_click:
		_select(id,add or hud.group_button.button_pressed)
	elif not selected.is_empty():
		if id != "" and model.squads[id].side == "enemy":
			_issue("attack",id)
		else:
			_issue("move",_ground(pixel))

func _preview() -> void:
	var slots: Array = model.preview_group(selected,_ground(origin),_ground(cursor))
	ghost.multimesh.instance_count = slots.size()
	for i in slots.size():
		ghost.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,_surface(slots[i])+Vector3.UP*0.12))

func reset_gesture() -> void:
	gesture = ""
	fingers.clear()
	hud.marquee.hide()
	ghost.multimesh.instance_count = 0

func _input(event: InputEvent) -> void:
	if not is_node_ready():
		return
	if event is InputEventKey:
		if event.pressed and not event.echo and _key(event):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if _touch(event):
			get_viewport().set_input_as_handled()
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton:
		if gesture == "" and hud.blocks(event.position):
			return
		if event.pressed:
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP: _zoom(0.89)
				MOUSE_BUTTON_WHEEL_DOWN: _zoom(1.12)
				MOUSE_BUTTON_LEFT: _begin("box",event.position)
				MOUSE_BUTTON_RIGHT: _begin("right",event.position)
				MOUSE_BUTTON_MIDDLE: _begin("pan",event.position)
				_: return
		elif gesture in ["box","right","pan"]:
			_end(event.position,event.shift_pressed)
		else:
			return
	elif event is InputEventMouseMotion and gesture in ["box","right","pan"]:
		cursor = event.position
		if gesture == "box":
			hud.selection_box(origin,cursor)
		elif gesture == "right":
			_preview()
		else:
			_pan(_ground(cursor-event.relative)-_ground(cursor))
	else:
		return
	get_viewport().set_input_as_handled()

func _begin(kind: String,p: Vector2) -> void:
	gesture = kind
	origin = p
	cursor = p
	pressed_at = Time.get_ticks_msec()

func _end(p: Vector2,add := false) -> void:
	var moved := p.distance_to(origin)>9
	match gesture:
		"box":
			if moved:
				var box := Rect2(origin,p-origin).abs()
				if not add:
					selected.clear()
				for s: Dictionary in model.squads.values():
					if s.side == "ally" and s.strength > 0 and box.has_point(camera.unproject_position(_surface(Vector2(s.x,s.z)))) and s.id not in selected:
						selected.append(s.id)
				pending = ""
			else:
				_tap(p,false,add)
		"right","deploy":
			if moved:
				_issue("deploy",{"start":_ground(origin),"end":_ground(p)})
			elif gesture == "right":
				_tap(p,true,add)
		"touch":
			if not moved:
				_tap(p,false,add)
	reset_gesture()
	_refresh()

func _touch(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed:
			if hud.blocks(event.position):
				return false
			fingers[event.index] = event.position
			if fingers.size() == 1:
				_begin("touch",event.position)
			else:
				gesture = "pinch"
				ghost.multimesh.instance_count = 0
		elif fingers.has(event.index):
			fingers.erase(event.index)
			if gesture == "pinch":
				if fingers.is_empty():
					reset_gesture()
			else:
				_end(event.position)
		else:
			return false
	elif fingers.has(event.index):
		var old: Vector2 = fingers[event.index]
		fingers[event.index] = event.position
		if gesture == "pinch" and fingers.size() == 2:
			var both := fingers.keys()
			var other: Vector2 = fingers[both[1] if both[0] == event.index else both[0]]
			var previous := (old+other)*0.5
			var center: Vector2 = (event.position+other)*0.5
			_pan(_ground(previous)-_ground(center))
			_zoom(clampf(old.distance_to(other)/maxf(1,event.position.distance_to(other)),0.7,1.4))
		else:
			cursor = event.position
			if gesture == "touch" and pressed_at + 360 <= Time.get_ticks_msec():
				gesture = "deploy"
			if gesture == "deploy":
				_preview()
	else:
		return false
	return true

func _key(event: InputEventKey) -> bool:
	match event.keycode:
		KEY_ESCAPE:
			if pending != "" or gesture != "":
				pending = ""
				reset_gesture()
			else:
				_action("leave")
		KEY_SPACE: _action("pause")
		KEY_H: _issue("hold")
		KEY_R: _issue("rally")
		KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9:
			var key := event.keycode-KEY_1
			if event.ctrl_pressed:
				groups[key] = selected.duplicate()
			elif groups.has(key):
				selected = groups[key].duplicate()
			elif key < hud.card_by_id.size():
				_select(hud.card_by_id.keys()[key],event.shift_pressed)
		_: return false
	_refresh()
	return true

func _exit_tree() -> void:
	var display := get_node_or_null("/root/RuntimeDisplay")
	if display:
		display.set_unit_counts(-1,-1,-1)
