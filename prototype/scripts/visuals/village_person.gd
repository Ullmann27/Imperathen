extends Node3D
## Presentation of a domain person. The enclosing body owns collision and movement.

const COLORS := {"italia":"a45c47","germania":"809081","han":"ad9865","wa":"e0d1b7","vistula":"797b78"}
const COMPANION_COLORS := {"italia":"ddd0ab","germania":"91907a","han":"8197a4","wa":"d4c7ac","vistula":"ac6853"}
const HAIR := {"italia":["",""],"germania":["","braid"],"han":["knot","knot"],"wa":["tie","tie"],"vistula":["braid","braid"]}
const COMPANIONS := {"italia":"marcus","germania":"albrun","han":"lin","wa":"aki","vistula":"mira"}
const LOOPS := ["idle","march","run","talk","work"]
const FacialMotion := preload("res://scripts/visuals/facial_motion.gd")
const CharacterMotion := preload("res://scripts/visuals/character_motion.gd")
const HandPose := preload("res://scripts/visuals/hand_pose.gd")
const PracticeGear := preload("res://scripts/visuals/practice_gear.gd")
const HERO_PATH := "res://assets/characters/hero_quality_%d.glb"
const FRONTIER_PATH := "res://assets/characters/frontier_%s_%d.glb"
const APPEARANCES := ["civilian_man", "civilian_woman", "elder", "legionary", "officer", "spearman", "archer"]
const CLOTH_TINTS := [Color(1.0, 1.0, 1.0), Color(0.72, 0.90, 1.10), Color(1.10, 0.75, 0.60), Color(0.75, 1.05, 0.79), Color(1.15, 1.06, 0.76), Color(0.76, 0.73, 0.84)]
const RESIDENT_HEIGHTS := [0.97, 1.03, 1.0, 0.95, 1.04, 0.99]
const LOD_DISTANCES := [11.0,23.0,44.0]
const CROWD_LOD_DISTANCES := [6.0,15.0,30.0]
static var scenes := {}
static var materials := {}
var role := "player"
var home := "italia"
var age := 12
var identity := "player"
var profile := "balanced"
var detail := -1
var body: Node3D
var animator: AnimationPlayer
var active_model_path := ""
var clip := "idle"
var phase := 0.0
var speed := 0.0
var _remaining := 0.0
var _check_lod := 0.0
var _posed := false
var _blade: MeshInstance3D
var _face := FacialMotion.new()
var _motion := CharacterMotion.new()
var _hands := HandPose.new()
var _turn_rate := 0.0
var _combat_id := ""
var _combat_progress := 0.0
var _combat_duration := 0.0
var _combat_external := false
var _has_sword := false
var _has_shield := false
var _lod_profile := ""
var appearance_id := ""
var appearance_variation := 0
var _loaned_gear := false
var _gear_nodes: Array[Node3D] = []


func _ready() -> void:
	add_to_group("village_people")


func configure(kind: String, origin: String, years: int) -> void:
	if role == kind and home == origin and age == years and body:
		return
	role = kind
	home = origin
	age = years
	identity = COMPANIONS.get(home,"marcus") if role == "companion" else ("hero_"+home if role == "player" else role)
	_reload(maxi(0,detail))


func configure_appearance(new_appearance: String, variation: int = 0) -> void:
	var selected := new_appearance if new_appearance in APPEARANCES else ""
	var selected_variation := posmod(variation, 18)
	if selected == appearance_id and selected_variation == appearance_variation and body:
		return
	appearance_id = selected
	appearance_variation = selected_variation
	if not appearance_id.is_empty():
		identity = "resident_%s_%d" % [appearance_id, appearance_variation]
	_reload(maxi(0, detail))


func configure_resident(origin: String, years: int, new_appearance: String, variation: int = 0, camera: Camera3D = null) -> void:
	# Resident population builders already know the complete identity. Configure
	# it atomically so they never load an unused generic body or a near LOD first.
	var selected := new_appearance if new_appearance in APPEARANCES else ""
	var selected_variation := posmod(variation, 18)
	var changed := role != "resident" or home != origin or age != years or appearance_id != selected or appearance_variation != selected_variation
	role = "resident"
	home = origin
	age = years
	appearance_id = selected
	appearance_variation = selected_variation
	identity = "resident_%s_%d" % [appearance_id, appearance_variation] if not appearance_id.is_empty() else "resident"
	if not changed and body:
		refresh_lod(camera)
		return
	var level := detail if detail >= 0 else 2
	if is_instance_valid(camera) and is_inside_tree() and camera.is_inside_tree():
		level = _distance_lod(global_position.distance_to(camera.global_position))
		_lod_profile = profile
	_reload(level)


func _frontier_identity() -> String:
	# The new civilian anatomy is adult. Existing youth characters keep their
	# original age route and cannot accidentally receive an adult resident mesh.
	if age < 18:
		return ""
	if not appearance_id.is_empty():
		return appearance_id
	if home == "italia":
		return {"mentor": "officer", "recruit": "spearman", "enemy": "legionary"}.get(role, "")
	return ""


func _path(level: int) -> String:
	# This asset has an authored Italia identity. Other origins and companions
	# keep their own appearances until their replacement models are available.
	if role == "player" and home == "italia":
		var complete_set := true
		for candidate in 4:
			if not ResourceLoader.exists(HERO_PATH % candidate, "PackedScene"):
				complete_set = false
		if complete_set:
			return HERO_PATH % level
	var frontier := _frontier_identity()
	if not frontier.is_empty():
		var complete_set := true
		for candidate in 4:
			if not ResourceLoader.exists(FRONTIER_PATH % [frontier, candidate], "PackedScene"):
				complete_set = false
		if complete_set:
			return FRONTIER_PATH % [frontier, level]
	return _legacy_path(level)


func _legacy_path(level: int) -> String:
	if role in ["mentor","recruit","enemy"]:
		var equipment := "officer" if role == "mentor" else ("spear" if role == "recruit" else "heavy")
		if level >= 2:
			return "res://assets/village_characters/%s_%d.glb" % [equipment,level]
		var lod: String = ["near","mid"][level]
		return "res://assets/soldiers/%s_%s.glb" % [equipment,lod]
	return "res://assets/village_characters/villager_%d.glb" % level


func _reload(level: int) -> void:
	level = clampi(level, 0, 3)
	var saved_phase := phase
	var previous_path := active_model_path
	var path := _path(level)
	var replacement := _instantiate(path)
	if not replacement and path != _legacy_path(level):
		path = _legacy_path(level)
		replacement = _instantiate(path)
	if not replacement:
		push_warning("Character model unavailable: " + path)
		return
	# Load and validate before removing the current model. A failed optional
	# asset must not make a visible actor disappear during a quality transition.
	_blade = null
	if body:
		remove_child(body)
		body.free()
	_gear_nodes.clear()
	detail = level
	body = replacement
	active_model_path = path
	body.name = "Model"
	body.rotation.y = PI
	var size_factor := 1.0
	if role in ["player","companion"]:
		size_factor = 1.14 if age >= 18 else 1.0
		if role == "companion": size_factor *= 0.97
	elif active_model_path.begins_with("res://assets/characters/frontier_") and _frontier_identity() in ["civilian_man", "civilian_woman", "elder"]:
		size_factor = 1.14 * float(RESIDENT_HEIGHTS[appearance_variation % RESIDENT_HEIGHTS.size()])
	body.scale = Vector3.ONE * size_factor
	add_child(body)
	body.position.y = -0.9
	animator = body.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if animator:
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for shape: MeshInstance3D in body.find_children("*","MeshInstance3D",true,false):
		_style(shape)
	_hands.bind(body, active_model_path)
	_face.bind(body, identity)
	_motion.bind(body, role in ["player", "companion"] or (role == "resident" and _frontier_identity() in ["", "civilian_man", "civilian_woman", "elder"]))
	_play(clip,saved_phase,0)
	_face.pose("attack" if not _combat_id.is_empty() else clip,saved_phase,detail)
	if not _combat_id.is_empty():
		_motion.combat(_combat_id, _combat_progress)
		_hands.set_grip(0.18 + 0.82 * smoothstep(0.0, 0.15, _combat_progress) * (1.0 - smoothstep(0.82, 1.0, _combat_progress)))
	_sync_loaned_gear()
	# Retaining every hero PackedScene would also retain every embedded texture
	# tier. Live instances keep their own references; inactive tiers may unload.
	if path.begins_with("res://assets/characters/hero_quality_") or previous_path.begins_with("res://assets/characters/hero_quality_"):
		for cached_path: String in scenes.keys():
			if cached_path.begins_with("res://assets/characters/hero_quality_") and cached_path != path:
				scenes.erase(cached_path)
	elif path.begins_with("res://assets/characters/frontier_"):
		var family := "res://assets/characters/frontier_" + _frontier_identity() + "_"
		for cached_path: String in scenes.keys():
			if cached_path.begins_with(family) and cached_path != path:
				scenes.erase(cached_path)


func _instantiate(path: String) -> Node3D:
	if not scenes.has(path):
		if not ResourceLoader.exists(path, "PackedScene"):
			return null
		var scene := load(path) as PackedScene
		if not scene:
			return null
		scenes[path] = scene
	var instance: Node = (scenes[path] as PackedScene).instantiate()
	if instance is Node3D:
		return instance as Node3D
	instance.free()
	scenes.erase(path)
	return null


func _style(shape: MeshInstance3D) -> void:
	if not shape.mesh: return
	var part := String(shape.name)
	if part.begins_with("Garment_"):
		shape.visible = part == "Garment_"+home
	if part.begins_with("Hair_"):
		var style: String = HAIR.get(home,["",""])[int(role=="companion")]
		shape.visible = part == "Hair_"+style
	if part == "PracticeBlade":
		_blade = shape
		shape.visible = false
	for key in ["Mature","Companion"]:
		var slot := shape.find_blend_shape_by_name(key)
		if slot >= 0:
			shape.set_blend_shape_value(slot,float(age >= 18 if key == "Mature" else role == "companion"))
	for i in range(shape.mesh.get_surface_count()):
		var source := shape.mesh.surface_get_material(i) as StandardMaterial3D
		if not source: continue
		if "CharacterPalette" in source.resource_name:
			source.vertex_color_use_as_albedo = true
		elif source.resource_name == "PortraitSkin":
			var face_id := identity
			if role == "resident": face_id = "hero_" + home
			if age >= 18 and home == "italia": face_id = "adult_marcus" if role == "companion" else "adult_italia"
			if not materials.has(face_id):
				var face := source.duplicate() as StandardMaterial3D
				face.vertex_color_use_as_albedo = false
				face.albedo_texture = load("res://assets/village_characters/faces/%s.webp" % face_id)
				face.roughness = 0.77
				materials[face_id] = face
			shape.set_surface_override_material(i,materials[face_id])
		elif active_model_path.begins_with("res://assets/characters/frontier_") and source.resource_name in ["FrontierCloth", "HeroHair", "FrontierGreyHair"]:
			var key := "%d/frontier/%d" % [source.get_instance_id(), appearance_variation]
			var mat: StandardMaterial3D
			if materials.has(key):
				mat = (materials[key] as WeakRef).get_ref() as StandardMaterial3D
			if not mat:
				mat = source.duplicate() as StandardMaterial3D
				if source.resource_name == "FrontierCloth":
					mat.albedo_color *= CLOTH_TINTS[appearance_variation % CLOTH_TINTS.size()]
				elif source.resource_name == "HeroHair":
					var hair_variant := floori(float(appearance_variation) / 6.0) % 3
					mat.albedo_color *= [Color(0.60, 0.52, 0.44), Color(1.0, 0.88, 0.68), Color(0.72, 0.76, 0.76)][hair_variant]
				else:
					mat.albedo_color *= Color(0.84, 0.86, 0.84) if appearance_variation % 2 else Color(1.15, 1.13, 1.09)
				# Inactive LOD textures may unload; live actor overrides own the
				# material. A cache must not retain all four texture tiers forever.
				materials[key] = weakref(mat)
			shape.set_surface_override_material(i, mat)
		elif source.resource_name in ["Civilian_Linen","Overgarment"] or (role == "enemy" and not active_model_path.begins_with("res://assets/characters/frontier_")):
			var key := "%d/%s/%s" % [source.get_instance_id(),home,role]
			if not materials.has(key):
				var mat := source.duplicate() as StandardMaterial3D
				var color := Color(COLORS.get(home,"b88753"))
				if role == "companion": color = Color(COMPANION_COLORS.get(home,"ddd0ab"))
				if role == "enemy": color = Color("#a78f79")
				mat.albedo_color = color
				materials[key] = mat
			shape.set_surface_override_material(i,materials[key])


func drive(metres_per_second: float, turn_radians_per_second: float = 0.0) -> void:
	speed = maxf(0.0, metres_per_second) if is_finite(metres_per_second) else 0.0
	_turn_rate = clampf(turn_radians_per_second, -3.0, 3.0) if is_finite(turn_radians_per_second) else 0.0
	if _combat_id.is_empty():
		_posed = false


func set_equipment(sword: bool, shield: bool = false) -> void:
	_has_sword = sword
	_has_shield = shield
	if _blade:
		_blade.visible = _has_sword and role == "player" and age >= 18 and clip in ["attack", "train", "block"]


func sample_combat(technique: String, normalized: float) -> void:
	if not technique in CharacterMotion.TECHNIQUES:
		return
	if _combat_id.is_empty():
		_play("idle", 0.0, 0.0)
	_combat_id = technique
	_combat_progress = clampf(normalized, 0.0, 1.0)
	_combat_external = true
	_posed = true
	clip = technique
	phase = _combat_progress
	if _blade:
		_blade.visible = false
	_motion.combat(technique, _combat_progress)
	_hands.set_grip(0.18 + 0.82 * smoothstep(0.0, 0.15, _combat_progress) * (1.0 - smoothstep(0.82, 1.0, _combat_progress)))
	_face.pose("attack", _combat_progress, detail)


func cue_combat(technique: String, duration: float) -> void:
	if not technique in CharacterMotion.TECHNIQUES or not is_finite(duration) or duration <= 0.0:
		return
	sample_combat(technique, 0.0)
	_combat_duration = duration
	_combat_external = false
	_posed = false


func cancel_action() -> void:
	_combat_id = ""
	_combat_duration = 0.0
	_combat_progress = 0.0
	_combat_external = false
	_remaining = 0.0
	_posed = false
	_play("idle", 0.0, 0.12)


func cue(action: String) -> void:
	if action == "death" and clip == "death": return
	_combat_id = ""
	_combat_external = false
	_posed = false
	_play(action,0,0.12)
	_remaining = animator.current_animation_length if animator and animator.current_animation != "" else 0.8


func cue_unarmed(action: String) -> bool:
	# Compatibility for authored presentation cues. Actual hits and the live
	# action clock remain in the model and reach us through sample_combat.
	if not CharacterMotion.TIMING.has(action) or not animator or not _motion.available:
		return false
	cue_combat(action, float(CharacterMotion.TIMING[action].z))
	return true


func set_loaned_gear(enabled: bool) -> void:
	_loaned_gear = enabled
	_sync_loaned_gear()


func _sync_loaned_gear() -> void:
	if not body: return
	if _loaned_gear and _gear_nodes.is_empty():
		_gear_nodes = PracticeGear.attach(body)
	for node: Node3D in _gear_nodes:
		if is_instance_valid(node): node.visible = _loaned_gear


func reset_motion() -> void:
	_combat_id = ""
	_combat_external = false
	_combat_progress = 0.0
	_remaining = 0
	speed = 0
	_posed = false
	_play("idle",0,0)
	_face.pose("idle",0,detail)


func keep_working() -> void:
	if clip != "work": cue("work")
	_remaining = maxf(_remaining,0.3)


func sample_pose(action: String, normalized: float) -> void:
	if action in CharacterMotion.TECHNIQUES:
		sample_combat(action, normalized)
		return
	_combat_id = ""
	_combat_external = false
	_posed = true
	_play(action,normalized,0)
	_face.pose(action,normalized,detail)
	_apply_motion(true)


func _play(action: String, normalized: float, blend: float) -> void:
	_motion.capture_transition(blend if action != clip and action in ["idle", "march", "run"] else 0.0)
	clip = action
	if _blade: _blade.visible = _has_sword and role == "player" and age >= 18 and clip in ["attack","train","block"]
	phase = clampf(normalized,0,1)
	if not animator: return
	var name_in_file := action
	if not animator.has_animation(name_in_file):
		name_in_file = "attack" if action == "train" else "idle"
	if not animator.has_animation(name_in_file): return
	var animation := animator.get_animation(name_in_file)
	animation.loop_mode = Animation.LOOP_LINEAR if action in LOOPS else Animation.LOOP_NONE
	animator.play(name_in_file,blend)
	animator.seek(phase*animation.length,true)
	animator.advance(0)
	_apply_motion()


func _apply_motion(review: bool = false) -> void:
	if clip in ["idle", "march", "run"]:
		_hands.set_grip(0.18 if clip != "run" else 0.34)
		_motion.locomotion(clip, phase, -1.0 if review and clip != "idle" else speed / maxf(body.scale.y, 0.01), _turn_rate)
	elif clip in ["attack", "train"] and role in ["player", "companion"] and not _has_sword:
		_hands.set_grip(0.18 + 0.82 * sin(phase * PI))
		_motion.combat("jab_right", phase)
	else:
		_hands.set_grip(0.18)


func _distance_lod(distance: float) -> int:
	var factor := float({"low":0.55,"balanced":0.86,"high":1.15,"very_high":1.5}.get(profile,1.0))
	var distances: Array = CROWD_LOD_DISTANCES if role == "resident" else LOD_DISTANCES
	var level := 0
	for threshold: float in distances:
		if distance >= threshold * factor: level += 1
	return level


func refresh_lod(camera: Camera3D) -> void:
	if not is_instance_valid(camera) or not body: return
	var distance := global_position.distance_to(camera.global_position)
	var factor := float({"low":0.55,"balanced":0.86,"high":1.15,"very_high":1.5}.get(profile,1.0))
	var distances: Array = CROWD_LOD_DISTANCES if role == "resident" else LOD_DISTANCES
	var level := _distance_lod(distance)
	var same_profile := profile == _lod_profile
	_lod_profile = profile
	# A narrow dead band prevents repeated asset loads when walking along a LOD
	# boundary. An explicit graphics-profile change is applied without delay.
	if same_profile and detail >= 0:
		if level > detail and distance < float(distances[detail]) * factor * 1.10:
			return
		if level < detail and distance > float(distances[detail - 1]) * factor * 0.90:
			return
	if level != detail: _reload(level)


func _process(delta: float) -> void:
	_motion.advance(delta)
	_check_lod -= delta
	if _check_lod <= 0:
		_check_lod = 0.32
		refresh_lod(get_viewport().get_camera_3d())
	if not _combat_id.is_empty():
		if not _combat_external and _combat_duration > 0.0:
			_combat_progress = minf(1.0, _combat_progress + delta / _combat_duration)
			phase = _combat_progress
			_motion.combat(_combat_id, _combat_progress)
			_hands.set_grip(0.18 + 0.82 * smoothstep(0.0, 0.15, _combat_progress) * (1.0 - smoothstep(0.82, 1.0, _combat_progress)))
			_face.advance(delta, "attack", detail)
			if _combat_progress >= 1.0:
				cancel_action()
		return
	if _posed: return
	if clip != "death":
		_remaining = maxf(0,_remaining - delta)
		if _remaining <= 0:
			var stop_threshold := 0.06 if clip in ["march", "run"] else 0.10
			var run_threshold := 2.25 if clip == "run" else 2.55
			var next := "idle" if speed < stop_threshold else ("march" if speed < run_threshold else "run")
			if next != clip:
				var carry_phase := phase if clip in ["march", "run"] and next in ["march", "run"] else 0.0
				_play(next, carry_phase, 0.13)
	if animator and animator.is_playing():
		var advance := delta
		if clip in ["march","run"]:
			var stride := 1.10 if clip == "march" else 1.49
			if _motion.available and _motion.civilian:
				stride = maxf(0.01, _motion.gait_stride(clip, speed / body.scale.y) * body.scale.y)
			elif _frontier_identity() in ["legionary", "officer", "spearman", "archer"] and active_model_path.begins_with("res://assets/characters/frontier_"):
				stride = 1.30 if clip == "march" else 1.75
			else:
				stride *= body.scale.y
			advance *= speed * animator.current_animation_length / stride
		animator.advance(advance)
		if animator.current_animation != "":
			phase = animator.current_animation_position / animator.current_animation_length
	_apply_motion()
	_face.advance(delta,clip,detail)
