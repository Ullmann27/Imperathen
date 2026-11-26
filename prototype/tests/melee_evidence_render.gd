extends SceneTree
## Evidence renderer for level-A melee (D-038): real rigs driven by the real
## core state on a neutral test floor, frame sequences around each contact.
## Not a test and not part of the game. Run under a display:
##   MELEE_EVIDENCE_OUT=<dir> MELEE_EVIDENCE_COMMIT=<sha> godot --path prototype \
##     --fixed-fps 60 --resolution 960x720 --script res://tests/melee_evidence_render.gd
## Each sequence writes fNNN.png at fixed offsets around the contact frame
## plus meta.json (per-frame phase/clip frame/events and the impact records
## the audio hub published); render_metadata.json describes the run.
const Core = preload("res://scripts/domain/melee/melee_core.gd")
const Tracks = preload("res://scripts/domain/melee/melee_tracks.gd")
const Person = preload("res://scripts/visuals/village_person.gd")
const Presenter = preload("res://scripts/visuals/melee_presenter.gd")
const Fx = preload("res://scripts/visuals/melee_impact_fx.gd")
const Probe = preload("res://tests/melee_rig_probe.gd")
const CombatCamera = preload("res://scripts/visuals/melee_camera.gd")
const AI = preload("res://scripts/domain/melee/melee_ai.gd")
const Impacts = preload("res://scripts/domain/melee/combat_impacts.gd")
const OFFSETS := [-16, -9, -4, -1, 0, 2, 6, 16]

var OUT := "user://melee_evidence"
var _heard: Array = []
var _ai := {}
var _offsets: Array = OFFSETS
var _cam_a := Vector3.ZERO
var _cam_d := Vector3.ZERO
var _seqs: Array = []
var _seq := -1
var _state: Dictionary
var _frame := 0
var _end := 0
var _contact := -1
var _save: Dictionary = {}
var _meta: Array = []
var _rig := {}
var _pres := {}
var _fx: Node3D
var _cam: Camera3D
var _pending := -1
var _label := ""
var _dyncam = null
var _legacy := false
var _frame_ms: Array = []
var _last_usec := 0
var _spear_model: Node3D
var _spear_axis := Vector3.ZERO


func _hear(record: Dictionary) -> void:
	_heard.append({"kind":record.kind, "outcome":record.outcome, "frame":record.frame, "clip_frame":record.clip_frame,
		"material_a":record.material_a, "material_b":record.material_b, "energy_j":record.energy_j,
		"weapon_id":record.weapon_id, "weapon_class":record.weapon_class, "sound_hint":record.sound_hint})


func _initialize() -> void:
	if not OS.get_environment("MELEE_EVIDENCE_OUT").is_empty():
		OUT = OS.get_environment("MELEE_EVIDENCE_OUT")
	DirAccess.make_dir_recursive_absolute(OUT)
	Impacts.connect_listener(_hear)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.64, 0.71, 0.78)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.58, 0.58, 0.62)
	env.environment.ambient_light_energy = 0.9
	get_root().add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	get_root().add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16, 16)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.47, 0.41, 0.31)
	mat.roughness = 1.0
	ground.material_override = mat
	get_root().add_child(ground)
	_rig.legionary = Person.new()
	get_root().add_child(_rig.legionary)
	_rig.legionary.configure("player", "italia", 18)
	_rig.legionary.set_service_gear(true)
	_rig.legionary.sample_service_combat("thrust", 0.0)
	_rig.axe = Person.new()
	get_root().add_child(_rig.axe)
	_rig.axe.configure("enemy", "germania", 30)
	_rig.axe.configure_meshy("unit_germanic_axe_fighter")
	_rig.axe.sample_armed_pose("cut_inward", 0.0)
	_rig.youth = Person.new()
	get_root().add_child(_rig.youth)
	_rig.youth.configure("player", "italia", 12)
	_rig.youth.position = Vector3(0, -50, 0)
	_rig.spear = Node3D.new()
	get_root().add_child(_rig.spear)
	_spear_model = (load("res://assets/soldiers/spear_near.glb") as PackedScene).instantiate() as Node3D
	_spear_model.rotation.y = PI
	_rig.spear.add_child(_spear_model)
	var sk := Probe.skeleton_of(_spear_model)
	var far := Vector3.ZERO
	for v in Probe.bone_vertices(Probe.body_mesh(_spear_model), sk, "Hand_R"):
		if v.length() > far.length():
			far = v
	_spear_axis = far.normalized()
	var player := _spear_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player:
		player.stop()
	_fx = Fx.new()
	get_root().add_child(_fx)
	_cam = Camera3D.new()
	get_root().add_child(_cam)
	_cam.fov = 42
	# id, attacker rig/kit, move, defender rig/kit, guard, bearing on defender, distance tweak, shield
	_seqs = [
		["hit_weapon_side", "legionary", "thrust", "axe", "guard_front", 90.0, 0.02, true, -1.0],
		["block_front", "legionary", "thrust", "axe", "guard_front", 0.0, 0.02, true, -1.0],
		["block_axe_on_scutum", "axe", "axe_overhead", "legionary", "guard_high", 0.0, 0.02, true, 1.0],
		["scutum_edge_catches_flank", "axe", "axe_cut_inward", "legionary", "guard_front", 70.0, 0.03, true, -1.0],
		["flank_hit_reaction", "axe", "axe_overhead", "legionary", "guard_front", 105.0, 0.03, true, -1.0],
		["whiff_out_of_reach", "axe", "axe_overhead", "legionary", "", 0.0, -0.95, true, 1.0],
		["youth_jab_on_raider", "youth", "jab_right", "axe", "", 90.0, 0.02, true, -1.0],
		["spear_reach_vs_axe", "spear", "spear_thrust", "axe", "", 80.0, 0.03, true, -1.0],
		["dynamic_camera_block", "axe", "axe_overhead", "legionary", "guard_high", 0.0, 0.02, true, 1.0, true],
		["before_legacy_hit_weapon_side", "legionary", "thrust", "axe", "guard_front", 90.0, 0.02, true, -1.0, false, true],
		# Both fighters driven by melee_ai.gd from 4 m apart (approach, guard,
		# strike, reaction): frames around the first hit / around a hit that
		# follows a broken guard.
		["ai_duel_first_hit", "legionary", "", "axe", "", 0.0, 0.0, true, -1.0, false, false,
			{"seed":3, "center":"hit", "nth":1, "offsets":[-70, -50, -34, -22, -12, -6, -2, 0, 2, 5, 10, 22]}],
		["ai_duel_guard_break_then_hit", "legionary", "", "axe", "", 0.0, 0.0, true, 1.0, false, false,
			{"seed":16, "center":"hit", "nth":2, "offsets":[-56, -51, -50, -47, -40, -28, -14, -4, 0, 3, 8, 20]}]]
	_next()


func _kit(rig: String) -> String:
	return {"legionary":"legionary", "axe":"axe_fighter", "youth":"youth_unarmed", "spear":"spearman"}[rig]


func _setup(seq: Array, silent: bool) -> Dictionary:
	var attacker := _kit(seq[1])
	var defender := _kit(seq[3])
	var timing := Tracks.timing(attacker, seq[2])
	var tip: Vector3 = Tracks.segment(attacker, seq[2], int(timing.peak))[1]
	var flat := Vector2(tip.x, tip.z)
	var spot := flat.normalized() * (flat.length() + float(timing.radius) + float(Tracks.kit(defender).radius) - float(seq[6]))
	if seq.size() > 11:
		var duel := Core.new_state(int(seq[11].seed))
		duel.silent = silent
		Core.add_fighter(duel, "a", attacker, {"team":"a"})
		Core.add_fighter(duel, "d", defender, {"team":"d", "x":0.3, "z":-4.0})
		return duel
	var state := Core.new_state(21)
	state.silent = silent
	Core.add_fighter(state, "a", attacker, {"team":"a"})
	Core.add_fighter(state, "d", defender, {"team":"d", "x":spot.x, "z":spot.y})
	Core.face(state, "d", "a")
	state.fighters.d.yaw = float(state.fighters.d.yaw) + deg_to_rad(float(seq[5]))
	state.fighters.d.has_shield = bool(seq[7])
	if not str(seq[4]).is_empty():
		Core.command(state, "d", "guard", {"style":seq[4]})
		Core.step(state, 0.5)
	Core.command(state, "a", "attack", {"move":seq[2]})
	return state


## AI sequences: both fighters decide and move through melee_ai.gd.
func _drive(state: Dictionary) -> void:
	if _ai.is_empty():
		return
	for pair: Array in [["a", "d"], ["d", "a"]]:
		AI.apply(state, pair[0], pair[1], AI.decide(state, pair[0], pair[1]), 1.0 / 60.0)


func _next() -> void:
	_seq += 1
	if _seq >= _seqs.size():
		_write_metadata()
		quit(0)
		return
	var seq: Array = _seqs[_seq]
	_label = seq[0]
	# Dry domain pass: find the contact (or whiff) frame deterministically.
	var dry := _setup(seq, true)
	_ai = seq[11] if seq.size() > 11 else {}
	_offsets = _ai.get("offsets", OFFSETS)
	_contact = -1
	var seen := 0
	for f in range(1, 140 if _ai.is_empty() else 2400):
		_drive(dry)
		for e: Dictionary in Core.step(dry, 1.0 / 60.0):
			if _contact >= 0:
				continue
			if _ai.is_empty() and e.type in ["hit", "block", "parry", "whiff"] and e.get("attacker", "a") == "a":
				_contact = f
			elif not _ai.is_empty() and e.type == _ai.center:
				seen += 1
				if seen == int(_ai.nth):
					_contact = f
		if _contact >= 0:
			break
	_cam_a = Vector3(float(dry.fighters.a.x), 0, float(dry.fighters.a.z))
	_cam_d = Vector3(float(dry.fighters.d.x), 0, float(dry.fighters.d.z))
	_save.clear()
	for o in _offsets:
		_save[_contact + o] = true
	_end = _contact + _offsets[-1] + 1
	_state = _setup(seq, false)
	_heard = []
	# Fresh effects per sequence: nothing from the previous exchange lingers.
	_fx.queue_free()
	_fx = Fx.new()
	get_root().add_child(_fx)
	_frame = 0
	_meta = []
	_pres.clear()
	var a_rig: Node3D = _rig[seq[1]]
	var d_rig: Node3D = _rig[seq[3]]
	for key: String in _rig:
		(_rig[key] as Node3D).visible = _rig[key] == a_rig or _rig[key] == d_rig
	_pres.a = Presenter.new()
	if seq[1] == "spear":
		_pres.a.bind_rig(a_rig, _spear_model, "spearman", "a", _spear_axis)
	else:
		_pres.a.bind_person(a_rig, _kit(seq[1]), "a")
	_pres.d = Presenter.new()
	_pres.d.bind_person(d_rig, _kit(seq[3]), "d")
	_pres.a.apply(_state)
	_pres.d.apply(_state)
	var a := Vector3(float(_state.fighters.a.x), 0, float(_state.fighters.a.z))
	var d := Vector3(float(_state.fighters.d.x), 0, float(_state.fighters.d.z))
	if not _ai.is_empty():
		# Fixed camera on where the two stand at the centred event.
		a = _cam_a
		d = _cam_d
	var mid := (a + d) * 0.5
	var across := (d - a).normalized().cross(Vector3.UP).normalized() * float(seq[8])
	_cam.look_at_from_position(mid + across * 3.3 + Vector3(0, 1.45, 0) + (d - a).normalized() * 0.4, mid + Vector3(0, 1.05, 0))
	_dyncam = null
	_legacy = seq.size() > 10 and seq[10]
	if seq.size() > 9 and seq[9]:
		# Over the defender's shoulder with the real combat camera.
		_dyncam = CombatCamera.new()
		_dyncam.aspect = 960.0 / 720.0
		_dyncam.fov_deg = _cam.fov
		_cam.global_transform = _dyncam.update(d, a, 1.0 / 60.0)
	DirAccess.make_dir_recursive_absolute(OUT + "/" + _label)
	_pending = -1


func _process(_delta: float) -> bool:
	if _seq >= _seqs.size():
		return true
	var now := Time.get_ticks_usec()
	if _last_usec > 0:
		_frame_ms.append((now - _last_usec) / 1000.0)
	_last_usec = now
	# The image of the previous step is on screen now.
	if _pending >= 0:
		get_root().get_viewport().get_texture().get_image().save_png("%s/%s/f%03d.png" % [OUT, _label, _pending])
		_pending = -1
	if _frame >= _end:
		var file := FileAccess.open("%s/%s/meta.json" % [OUT, _label], FileAccess.WRITE)
		file.store_string(JSON.stringify({"contact":_contact, "frames":_meta, "impact_records":_heard}))
		file.close()
		_next()
		return false
	_frame += 1
	_drive(_state)
	var events := Core.step(_state, 1.0 / 60.0)
	_pres.a.apply(_state)
	_pres.d.apply(_state)
	if _legacy:
		# BEFORE: the previously shipped presentation at the same frames and
		# camera (service sword armed_pose, Meshy pose), for D-038 comparison.
		var fa: Dictionary = _state.fighters.a
		var leg: Node3D = _rig.legionary
		if fa.action == "attack":
			leg.sample_service_combat(str(fa.move), float(fa.t) / float(Tracks.timing("legionary", str(fa.move)).duration))
		else:
			leg.sample_service_combat("thrust", 0.0)
		_rig.axe.sample_armed_pose("guard_front", 0.5)
	if _dyncam != null:
		for e: Dictionary in events:
			_dyncam.impact(e)
		var fa := Vector3(float(_state.fighters.a.x), 0, float(_state.fighters.a.z))
		var fd := Vector3(float(_state.fighters.d.x), 0, float(_state.fighters.d.z))
		var shield: Array = Core.shield_world(_state.fighters.d)
		var occluder := [] if shield.is_empty() else [shield[0], shield[1], shield[2], Core.shield_half(_state.fighters.d)]
		_cam.global_transform = _dyncam.update(fd, fa, 1.0 / 60.0, occluder)
	var labels := []
	for e: Dictionary in events:
		if e.type in ["hit", "block", "parry", "guard_broken", "whiff", "shield_broken"]:
			var point: Vector3 = e.get("point", Vector3.ZERO)
			var normal := Vector3(float(_state.fighters.a.x), 1.2, float(_state.fighters.a.z)) - point
			if e.type != "whiff":
				_fx.spawn(e, point, normal)
			labels.append("%s%s" % [e.type, (" " + str(e.get("zone", ""))) if e.type == "hit" else ""])
		elif e.type in ["reaction", "interrupted"] and e.get("kind", "") != "recoil":
			labels.append("%s %s %s" % [e.type, e.get("kind", ""), e.get("direction", "")])
	var f: Dictionary = _state.fighters.a
	_meta.append({"frame":_frame, "phase":Core.phase(f), "clip_frame":Tracks.frame_of(float(f.t)) if f.action == "attack" else -1,
		"move":f.move, "defender":_state.fighters.d.action, "events":labels})
	if _save.has(_frame):
		_pending = _frame
	return false


func _write_metadata() -> void:
	var sorted := _frame_ms.duplicate()
	sorted.sort()
	var models := {}
	for path: String in ["res://assets/characters/hero_quality_0.glb", "res://assets/meshy/characters/unit_germanic_axe_fighter_0.glb",
			"res://assets/weapons/gladius_lod0.glb", "res://assets/weapons/scutum_lod0.glb", "res://assets/meshy/equipment/weap_germanic_hand_axe_0.glb",
			"res://assets/meshy/equipment/gear_germanic_round_shield_0.glb", "res://assets/soldiers/spear_near.glb",
			"res://scripts/domain/melee/melee_track_data.gd"]:
		models[path] = FileAccess.get_sha256(path)
	var meta := {"source_commit":OS.get_environment("MELEE_EVIDENCE_COMMIT"), "profile":"test floor, project default quality (no Fold7 profile applied)",
		"engine":Engine.get_version_info().string, "renderer":str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		"adapter":RenderingServer.get_video_adapter_name(), "vendor":RenderingServer.get_video_adapter_vendor(),
		"api":RenderingServer.get_video_adapter_api_version(), "resolution":str(get_root().get_viewport().get_visible_rect().size),
		"static_memory_mb":Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"video_memory_mb":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"frames":sorted.size(), "frame_ms_median":sorted[sorted.size() / 2] if not sorted.is_empty() else 0.0,
		"frame_ms_p95":sorted[int(sorted.size() * 0.95)] if not sorted.is_empty() else 0.0,
		"lighting":"1 DirectionalLight3D (shadows on, energy 1.1, -48/35 deg) + ambient colour 0.58/0.58/0.62, background colour, no GI/fog",
		"models_sha256":models, "note":"Xvfb software GL; frame times include PNG saving and are not device performance."}
	var file := FileAccess.open(OUT + "/render_metadata.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(meta, "  "))
	file.close()
