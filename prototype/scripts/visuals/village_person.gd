extends Node3D
## Presentation of a domain person. The enclosing body owns collision and movement.

const COLORS := {"italia":"a45c47","germania":"809081","han":"ad9865","wa":"e0d1b7","vistula":"797b78"}
const COMPANION_COLORS := {"italia":"ddd0ab","germania":"91907a","han":"8197a4","wa":"d4c7ac","vistula":"ac6853"}
const HAIR := {"italia":["",""],"germania":["","braid"],"han":["knot","knot"],"wa":["tie","tie"],"vistula":["braid","braid"]}
const COMPANIONS := {"italia":"marcus","germania":"albrun","han":"lin","wa":"aki","vistula":"mira"}
const LOOPS := ["idle","march","run","talk","work"]
const FacialMotion := preload("res://scripts/visuals/facial_motion.gd")
const HERO_PATH := "res://assets/characters/hero_quality_%d.glb"
const LOD_DISTANCES := [11.0,23.0,44.0]
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
var _lod_profile := ""


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
	detail = level
	body = replacement
	active_model_path = path
	body.name = "Model"
	body.rotation.y = PI
	var size_factor := 1.0
	if role in ["player","companion"]:
		size_factor = 1.14 if age >= 18 else 1.0
		if role == "companion": size_factor *= 0.97
	body.scale = Vector3.ONE * size_factor
	add_child(body)
	body.position.y = -0.9
	animator = body.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if animator:
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for shape: MeshInstance3D in body.find_children("*","MeshInstance3D",true,false):
		_style(shape)
	_face.bind(body, identity)
	_play(clip,saved_phase,0)
	_face.pose(clip,saved_phase,detail)
	# Retaining every hero PackedScene would also retain every embedded texture
	# tier. Live instances keep their own references; inactive tiers may unload.
	if path.begins_with("res://assets/characters/hero_quality_") or previous_path.begins_with("res://assets/characters/hero_quality_"):
		for cached_path: String in scenes.keys():
			if cached_path.begins_with("res://assets/characters/hero_quality_") and cached_path != path:
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
			if age >= 18 and home == "italia": face_id = "adult_marcus" if role == "companion" else "adult_italia"
			if not materials.has(face_id):
				var face := source.duplicate() as StandardMaterial3D
				face.vertex_color_use_as_albedo = false
				face.albedo_texture = load("res://assets/village_characters/faces/%s.webp" % face_id)
				face.roughness = 0.77
				materials[face_id] = face
			shape.set_surface_override_material(i,materials[face_id])
		elif source.resource_name in ["Civilian_Linen","Overgarment"] or role == "enemy":
			var key := "%d/%s/%s" % [source.get_instance_id(),home,role]
			if not materials.has(key):
				var mat := source.duplicate() as StandardMaterial3D
				var color := Color(COLORS.get(home,"b88753"))
				if role == "companion": color = Color(COMPANION_COLORS.get(home,"ddd0ab"))
				if role == "enemy": color = Color("#a78f79")
				mat.albedo_color = color
				materials[key] = mat
			shape.set_surface_override_material(i,materials[key])


func drive(metres_per_second: float) -> void:
	speed = metres_per_second
	_posed = false


func cue(action: String) -> void:
	if action == "death" and clip == "death": return
	_posed = false
	_play(action,0,0.12)
	_remaining = animator.current_animation_length if animator and animator.current_animation != "" else 0.8


func reset_motion() -> void:
	_remaining = 0
	speed = 0
	_posed = false
	_play("idle",0,0)
	_face.pose("idle",0,detail)


func keep_working() -> void:
	if clip != "work": cue("work")
	_remaining = maxf(_remaining,0.3)


func sample_pose(action: String, normalized: float) -> void:
	_posed = true
	_play(action,normalized,0)
	_face.pose(action,normalized,detail)


func _play(action: String, normalized: float, blend: float) -> void:
	clip = action
	if _blade: _blade.visible = role == "player" and age >= 18 and clip in ["attack","train","block"]
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


func refresh_lod(camera: Camera3D) -> void:
	if not is_instance_valid(camera) or not body: return
	var distance := global_position.distance_to(camera.global_position)
	var factor := float({"low":0.55,"balanced":0.86,"high":1.15,"very_high":1.5}.get(profile,1.0))
	var level := 0
	for threshold: float in LOD_DISTANCES:
		if distance >= threshold * factor: level += 1
	var same_profile := profile == _lod_profile
	_lod_profile = profile
	# A narrow dead band prevents repeated asset loads when walking along a LOD
	# boundary. An explicit graphics-profile change is applied without delay.
	if same_profile and detail >= 0:
		if level > detail and distance < LOD_DISTANCES[detail] * factor * 1.10:
			return
		if level < detail and distance > LOD_DISTANCES[detail - 1] * factor * 0.90:
			return
	if level != detail: _reload(level)


func _process(delta: float) -> void:
	_check_lod -= delta
	if _check_lod <= 0:
		_check_lod = 0.32
		refresh_lod(get_viewport().get_camera_3d())
	if _posed: return
	if clip != "death":
		_remaining = maxf(0,_remaining - delta)
		if _remaining <= 0:
			var next := "idle" if speed < 0.15 else ("march" if speed < 2.65 else "run")
			if next != clip: _play(next,0,0.13)
	if animator and animator.is_playing():
		var advance := delta
		if clip in ["march","run"]:
			var stride := 1.10 if clip == "march" else 1.49
			if age >= 18: stride *= 1.14
			advance *= speed * animator.current_animation_length / stride
		animator.advance(advance)
		if animator.current_animation != "":
			phase = animator.current_animation_position / animator.current_animation_length
	_face.advance(delta,clip,detail)
