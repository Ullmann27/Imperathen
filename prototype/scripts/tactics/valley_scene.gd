extends Node3D

signal leave_requested
signal battle_finished
const Rules = preload("res://scripts/battle/battle_model.gd")
const Landscape = preload("res://scripts/tactics/valley_landscape.gd")
const HUD = preload("res://scripts/tactics/valley_hud.gd")
const Soldier = preload("res://scripts/visuals/soldier_visual.gd")
const Agents = preload("res://scripts/formation/formation_agents.gd")
const Levels = preload("res://scripts/formation/formation_levels.gd")
const SIDES := {"ally":Color("#67d7c4"),"enemy":Color("#e58663")}
## Orders that need a tapped company or a tapped ground point after choosing them.
const ENEMY_PICK := ["attack","flank","focus_fire","charge","pila"]
const GROUND_PICK := ["move","attack_move","face"]
var model = Rules.new()
var hud = HUD.new()
var land = Landscape.new()
var far_ranks = preload("res://scripts/visuals/far_ranks.gd").new()
var camera := Camera3D.new()
var focus := Vector2(0,4.5)
var distance := 38.0
var azimuth := 0.0
var selected := []
var actors := {}
var render_profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/quality_profiles.json")).profiles
var motion := {}
var frame_remainder := 0.0
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
var agents = Agents.new()
var levels = Levels.new()
var rig_pool := {}
var dying_actors := {}
var far_index: Array[String] = []
var rig_instantiations := 0
var presentation_clock := 0.0
var levels_clock := 0.0
var instance_quota := 0
var pool_deferrals := 0
const INSTANCES_PER_PASS := 3

func set_quality(new_profile: String) -> void:
	if new_profile not in ["low", "balanced", "high", "very_high"]:
		return
	profile = new_profile
	levels.profile = profile
	if is_inside_tree():
		land.apply_quality(profile)
		_sync_units()


func _ready() -> void:
	frame_remainder = float(model.snapshot().remainder)
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
	hud.report_ready(model.steps)

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
	camera.position = center + Vector3(0,0.79,0.69).rotated(Vector3.UP,azimuth)*distance
	camera.look_at(center,Vector3.UP)

func _process(delta: float) -> void:
	var elapsed := 0.0
	if not paused and model.outcome == "ongoing":
		elapsed = minf(delta,0.5)*speed
		frame_remainder = fposmod(frame_remainder + elapsed,Rules.STEP)
		model.tick(elapsed)
		if model.outcome != "ongoing":
			paused = true
			battle_finished.emit()
	presentation_clock += maxf(0.0, delta)
	var turn := float(Input.is_key_pressed(KEY_E))-float(Input.is_key_pressed(KEY_Q))
	if turn != 0:
		azimuth += turn*delta*1.2
		_place_camera()
	var direction := Vector2(float(Input.is_key_pressed(KEY_D))-float(Input.is_key_pressed(KEY_A)),float(Input.is_key_pressed(KEY_S))-float(Input.is_key_pressed(KEY_W)))
	if direction != Vector2.ZERO:
		_pan(direction.normalized().rotated(-azimuth)*delta*distance*0.55)
	if hud.probe_step >= 0 and model.steps > hud.probe_step and agents.first_stride_probe < 0:
		agents.first_stride_probe = hud.probe_step
	var substeps: int = agents.advance(model)
	if not agents.first_stride.is_empty():
		if hud.probe_step >= 0:
			hud.report_first_stride(model.steps, agents.first_stride.uid, agents.first_stride.pose, agents.first_stride.meters)
		agents.first_stride_probe = -1
		agents.first_stride = {}
	lod_due -= delta
	if sampled_step != model.steps or lod_due <= 0:
		lod_due = 0.25
		sampled_step = model.steps
		_sync_units()
		_refresh()
	elif substeps > 0:
		_upload_far()
	_present(elapsed)
	if gesture == "touch" and not selected.is_empty() and Time.get_ticks_msec()-pressed_at >= 360:
		gesture = "deploy"
		message = "Ziehe die Front. Loslassen bestätigt die markierten Plätze."
		_preview()


## Simulation level and render detail of every soldier (hysteresis, cooldown,
## per-profile budgets), then the matching rig or distant representation.
## Each soldier uid has exactly one representation at a time.
func _sync_units() -> void:
	agents.sync_model(model)
	var clock_delta := presentation_clock - levels_clock
	levels_clock = presentation_clock
	levels.profile = profile
	levels.assign(agents.agents, camera.global_position, _in_view, _switch_held, clock_delta, dying_actors.size())
	instance_quota = INSTANCES_PER_PASS if presentation_clock > 0.5 else 1000
	for uid: String in agents.agents:
		_apply_detail(agents.agents[uid])
	levels.last = levels.count(agents.agents, dying_actors.size())
	for uid: String in actors.keys():
		if not agents.agents.has(uid):
			if agents.withdrawn_uids.has(uid):
				# Left the field alive: no death clip.
				_release_rig(actors[uid])
				actors.erase(uid)
			else:
				_fall(uid)
	_upload_far()
	for s: Dictionary in model.squads.values():
		var flag: Label3D = standards[s.id]
		flag.visible = s.strength > 0 and s.status != "withdrawn"
		flag.text = ("◆ " if s.id in selected else "") + str(s.name).to_upper()
		flag.modulate = Color("#ffe098") if s.id in selected else SIDES[s.side]
	_place_flags()
	var counts: Dictionary = levels.last
	get_node("/root/RuntimeDisplay").set_unit_counts(int(counts.get("rigs_near", 0)), int(counts.get("rigs_mid", 0)), int(counts.get("far_instances", 0)))


func _in_view(point: Vector3) -> bool:
	return camera.is_position_in_frustum(point)


func _switch_held(uid: String) -> bool:
	if actors.has(uid):
		return not actors[uid].switch_ready()
	var a = agents.agents.get(uid)
	return a != null and a.pose in Soldier.SWAP_AFTER


func _variant(uid: String) -> int:
	return posmod(uid.hash(), Soldier.TINTS.size())


func _apply_detail(a) -> void:
	var node = actors.get(a.uid)
	if a.detail > 1:
		if node != null:
			actors.erase(a.uid)
			_release_rig(node)
		return
	if node != null and (node.detail != a.detail or node.role != a.role):
		actors.erase(a.uid)
		_release_rig(node)
		node = null
	if node == null:
		if rig_pool.get("%s/%d" % [a.role, a.detail], []).is_empty() and instance_quota <= 0:
			# The pool is still warming up: at most INSTANCES_PER_PASS new
			# figures per pass, so a burst of promotions cannot stall a frame.
			# The soldier stays a distant instance until the next pass.
			a.detail = 2
			a.detail_since = -1e9
			pool_deferrals += 1
			return
		node = _take_rig(a.role, a.detail, _variant(a.uid))
		actors[a.uid] = node
		var state: Dictionary = agents.present_state(a, agents.render_fraction(model))
		node.position = state.position
		node.rotation.y = state.yaw
		node.present(state.pose, state.phase, 0.0)


## Rigs are pooled per role and detail: a level-of-detail switch hands the
## soldier to a ready figure instead of instancing and binding a new scene.
func _take_rig(role: String, level: int, variant: int):
	var key := "%s/%d" % [role, level]
	var pool: Array = rig_pool.get(key, [])
	var node
	if pool.is_empty():
		instance_quota -= 1
		node = Soldier.new()
		node.role = role
		node.variant = variant
		node.detail = level
		add_child(node)
		rig_instantiations += 1
	else:
		node = pool.pop_back()
		node.show()
		node.retint(variant)
	node.reset_presentation()
	return node


func _release_rig(node) -> void:
	node.hide()
	var key := "%s/%d" % [node.role, node.detail]
	if not rig_pool.has(key):
		rig_pool[key] = []
	rig_pool[key].append(node)


## The fallen man keeps his figure for the death clip, timed in simulation
## seconds by the agent layer (pause freezes it, fast time speeds it up), then
## the figure returns to the pool. He is never drawn twice and never returns.
func _fall(uid: String) -> void:
	var node = actors[uid]
	actors.erase(uid)
	dying_actors[uid] = node


func _present_fallen(fraction: float, elapsed: float) -> void:
	for uid: String in dying_actors.keys():
		var a = agents.fallen.get(uid)
		var node = dying_actors[uid]
		if a == null:
			dying_actors.erase(uid)
			_release_rig(node)
			continue
		var state: Dictionary = agents.present_state(a, fraction)
		node.position = state.position
		node.rotation.y = state.yaw
		node.present("death", state.phase, elapsed)


func _far_gait(a) -> Color:
	if Agents.continuous(a):
		return far_ranks.gait_data(a.pose, a.prev_phase, a.phase)
	return far_ranks.gait_data(a.pose, a.phase, a.phase)


func _transform(p: Vector2, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), _surface(p))


func _upload_far() -> void:
	var distant := {}
	var gaits := {}
	var starts := {}
	far_index.clear()
	var batch := func(a) -> void:
		if not distant.has(a.role):
			distant[a.role] = []
			gaits[a.role] = []
			starts[a.role] = []
		distant[a.role].append(_transform(a.pos, a.yaw))
		starts[a.role].append(_transform(a.prev_pos, a.prev_yaw))
		gaits[a.role].append(_far_gait(a))
		far_index.append(a.uid)
	for a in agents.agents.values():
		motion[a.uid] = {"pose": a.pose, "phase0": a.prev_phase, "phase1": a.phase, "start": _surface(a.prev_pos),
			"end": _surface(a.pos), "start_yaw": a.prev_yaw, "yaw": a.yaw, "level": a.level, "detail": a.detail}
		if a.detail == 2:
			batch.call(a)
	for uid: String in agents.fallen:
		if not dying_actors.has(uid) and not actors.has(uid):
			batch.call(agents.fallen[uid])
	far_ranks.sync(distant, gaits, starts)


func _present(elapsed: float) -> void:
	var fraction: float = agents.render_fraction(model)
	far_ranks.set_step_fraction(fraction)
	for uid: String in actors:
		var a = agents.agents.get(uid)
		if a == null:
			continue
		var state: Dictionary = agents.present_state(a, fraction)
		var actor = actors[uid]
		actor.position = state.position
		actor.rotation.y = state.yaw
		actor.present(state.pose, state.phase, elapsed)
	_present_fallen(fraction, elapsed)
	_place_flags()


func _place_flags() -> void:
	for s: Dictionary in model.squads.values():
		var flag: Label3D = standards[s.id]
		var unit = agents.units.get(s.id)
		var at: Vector2 = Vector2(s.x, s.z) if unit == null or unit.members.is_empty() else unit.frame_center
		flag.position = _surface(at)+Vector3.UP*2.75
		flag.pixel_size = clampf(camera.position.distance_to(flag.position)*0.00062,0.004,0.032)


## Presentation state per living soldier uid, as drawn this frame (rigs: the
## actual node transform; distant: the same interpolation as rank_stride).
func formation_render_states() -> Dictionary:
	var fraction: float = agents.render_fraction(model)
	var result := {}
	for uid: String in agents.agents:
		var a = agents.agents[uid]
		var state: Dictionary = agents.present_state(a, fraction)
		if actors.has(uid):
			state.position = actors[uid].position
			state.yaw = actors[uid].rotation.y
		state.detail = a.detail
		state.level = Levels.LEVEL_NAMES[a.level]
		state.role = a.role
		state.leaving = a.leaving
		result[uid] = state
	return result


func formation_far_gait(uid: String) -> Color:
	var a = agents.agents.get(uid)
	if a == null:
		return Color()
	var phase: float = agents.present_state(a, agents.render_fraction(model)).phase
	return far_ranks.gait_data(a.pose, phase, phase)


func formation_rig_nodes() -> Dictionary:
	return actors


## Soldiers represented more than once (rig and distant instance, or twice in
## the distant batches). Must always be zero.
func formation_duplicate_count() -> int:
	var seen := {}
	var duplicates := 0
	for uid: String in far_index:
		if seen.has(uid) or actors.has(uid) or dying_actors.has(uid):
			duplicates += 1
		seen[uid] = true
	for uid: String in actors:
		if dying_actors.has(uid):
			duplicates += 1
	return duplicates


func formation_counters() -> Dictionary:
	var result: Dictionary = levels.count(agents.agents, dying_actors.size())
	result.strength = 0
	for s: Dictionary in model.squads.values():
		result.strength += int(s.strength)
	result.dying = agents.fallen.size()
	result.rig_instantiations = rig_instantiations
	result.pool_deferrals = pool_deferrals
	result.pooled_rigs = 0
	for key: String in rig_pool:
		result.pooled_rigs += rig_pool[key].size()
	result.agents = agents.counters.duplicate()
	return result


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
		"group":
			if arg == "talwache":
				selected = model.company_ids("talwache_front")+model.company_ids("talwache_support")
			else:
				selected = model.company_ids(arg)
			pending = ""
			message = "%d Kohorten ausgewählt." % selected.size()
		"select": _select(arg,hud.group_button.button_pressed)
		"form": _issue("form",arg)
		"command":
			if arg in ENEMY_PICK or arg in GROUND_PICK or arg == "follow":
				pending = arg
				if arg in ENEMY_PICK:
					message = "Gegnerischen Verband wählen."
				elif arg == "follow":
					message = "Eigenen Verband wählen, dem gefolgt wird."
				else:
					message = "Blickrichtung auf dem Gelände wählen." if arg == "face" else "Ziel auf dem Gelände wählen."
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
	message = "%s · %s · Moral %d · Erschöpfung %d" % [s.name,model.SHAPES[s.formation],s.morale,s.fatigue]
	if s.pila > 0:
		message += " · Pila %d" % s.pila
	if s.status == "rallying":
		message += " · sammelt sich"
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
		if pending in ENEMY_PICK or pending == "follow":
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
