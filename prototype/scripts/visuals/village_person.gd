extends Node3D
## Presentation of a domain person. The enclosing body owns collision and movement.

const COLORS := {"italia":"b88753","germania":"718675","han":"6f8792","wa":"cebb8d","vistula":"948095"}
const COMPANIONS := {"italia":"marcus","germania":"albrun","han":"lin","wa":"aki","vistula":"mira"}
const LOOPS := ["idle","march","run","talk","work"]
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
var clip := "idle"
var phase := 0.0
var speed := 0.0
var _remaining := 0.0
var _check_lod := 0.0
var _posed := false


func configure(kind: String, origin: String, years: int) -> void:
	if role == kind and home == origin and age == years and body:
		return
	role = kind
	home = origin
	age = years
	identity = COMPANIONS.get(home,"marcus") if role == "companion" else role
	_reload(maxi(0,detail))


func _path(level: int) -> String:
	if role in ["mentor","recruit","enemy"]:
		var equipment := "officer" if role == "mentor" else ("spear" if role == "recruit" else "heavy")
		var lod: String = ["near","mid","mid","far"][level]
		return "res://assets/soldiers/%s_%s.glb" % [equipment,lod]
	return "res://assets/village_characters/villager_%d.glb" % level


func _reload(level: int) -> void:
	var saved_phase := phase
	var path := _path(level)
	if not scenes.has(path):
		scenes[path] = load(path)
	if body:
		remove_child(body)
		body.free()
	detail = level
	body = scenes[path].instantiate()
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
	_play(clip,saved_phase,0)


func _style(shape: MeshInstance3D) -> void:
	for i in range(shape.mesh.get_surface_count()):
		var source := shape.mesh.surface_get_material(i) as StandardMaterial3D
		if not source: continue
		if "CharacterPalette" in source.resource_name:
			source.vertex_color_use_as_albedo = true
		elif "Linen" in source.resource_name or role == "enemy":
			var key := "%d/%s/%s" % [source.get_instance_id(),home,role]
			if not materials.has(key):
				var mat := source.duplicate() as StandardMaterial3D
				var color := Color(COLORS.get(home,"b88753"))
				if role == "companion": color = color.lerp(Color("#697b84"),0.52)
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


func sample_pose(action: String, normalized: float) -> void:
	_posed = true
	_play(action,normalized,0)


func _play(action: String, normalized: float, blend: float) -> void:
	clip = action
	phase = clampf(normalized,0,1)
	if not animator: return
	var name_in_file := action
	if not animator.has_animation(name_in_file):
		name_in_file = "attack" if action == "train" else "idle"
	var animation := animator.get_animation(name_in_file)
	animation.loop_mode = Animation.LOOP_LINEAR if action in LOOPS else Animation.LOOP_NONE
	animator.play(name_in_file,blend)
	animator.seek(phase*animation.length,true)
	animator.advance(0)


func _process(delta: float) -> void:
	_check_lod -= delta
	if _check_lod <= 0:
		_check_lod = 0.32
		var camera := get_viewport().get_camera_3d()
		if camera:
			var d := global_position.distance_to(camera.global_position)
			var factor := float({"low":0.55,"balanced":0.86,"high":1.15,"very_high":1.5}.get(profile,1.0))
			var lod := 0 if d < 11*factor else (1 if d < 23*factor else (2 if d < 44*factor else 3))
			if lod != detail: _reload(lod)
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
