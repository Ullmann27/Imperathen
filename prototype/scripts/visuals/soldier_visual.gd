extends Node3D
## A presentation-only soldier. The simulation owns movement, timing and casualties.

const ROLES := ["heavy", "spear", "archer", "officer"]
const AuthoredGround := preload("res://scripts/visuals/authored_ground.gd")
const LODS := ["near", "mid", "far"]
const LOOPING := ["idle", "march", "run", "block", "wall", "testudo", "retreat"]
const ALIASES := {"walk": "march", "fall": "death", "shield_wall": "wall", "bow": "shoot"}
const STRIDES := {"march":1.30, "run":1.75, "retreat":1.48}
const SWAP_AFTER := ["attack", "hit", "shoot"]
const TINTS := [Color.WHITE, Color(0.96, 0.88, 0.77), Color(0.83, 0.91, 0.97)]
const FRONTIER_ROLES := {"heavy": "legionary", "spear": "spearman", "archer": "archer", "officer": "officer"}
const FacialMotion := preload("res://scripts/visuals/facial_motion.gd")
const CharacterMotion := preload("res://scripts/visuals/character_motion.gd")

static var _scenes: Dictionary = {}
static var _far_meshes: Dictionary = {}
static var _materials: Dictionary = {}
static var _clip_lengths: Dictionary = {}
var role := "heavy"
var variant := 0
var face_seed := -1
var _appearance_seed := 0
var detail := 0
var state := "idle"
var player: AnimationPlayer
var _animation_sources: Dictionary = {}
var _body: Node3D
var _phase := 0.0
var _manual_live := false
var _blend_left := 0.0
var _face := FacialMotion.new()

func _ready() -> void:
	if _body == null:
		_replace_body()

func configure(new_role: String, new_variant: int = 0) -> void:
	var resolved := new_role if new_role in ROLES else "heavy"
	var tint := posmod(new_variant, TINTS.size())
	if resolved == role and tint == variant and _body and _appearance_seed == new_variant:
		return
	_appearance_seed = new_variant
	role = resolved
	variant = tint
	_replace_body()

func set_detail(level: int) -> void:
	level = clampi(level, 0, LODS.size() - 1)
	if level == detail:
		return
	if player and player.current_animation != "" and player.current_animation_length > 0:
		_phase = player.current_animation_position / player.current_animation_length
	detail = level
	_replace_body()

func play_state(new_state: String, phase: float = 0.0) -> void:
	_manual_live = false
	_blend_left = 0.0
	if player:
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	var clip: String = ALIASES.get(new_state, new_state)
	if clip == state and player and player.is_playing():
		return
	state = clip
	_phase = clampf(phase, 0.0, 1.0)
	_play_clip()

# Distance along a rendered step sets the gait phase. Other poses advance in
# simulation seconds, so pause and slow time affect the whole pose consistently.
func present(pose: String, phase: float, delta: float) -> void:
	if not player:
		return
	var clip: String = ALIASES.get(pose,pose)
	if not player.has_animation(clip):
		clip = "idle"
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var looping := clip in LOOPING
	var animation := _playback_animation(clip, looping)
	if not _manual_live or state != clip or player.assigned_animation != clip:
		var blend := .12 if _manual_live else 0.0
		_manual_live = true
		state = clip
		player.play(clip,blend)
		_blend_left = blend
	# Both locomotion and actions use the timeline retained by ValleyScene.
	# Replacing a far actor or changing its mesh cannot restart an attack.
	var target := (fposmod(phase,1.0) if looping else clampf(phase,0.0,1.0))*animation.length
	var forward := target-player.current_animation_position
	if looping:
		forward = fposmod(forward,animation.length)
	if forward < 0.0 or forward > animation.length*.5:
		player.seek(target,true)
		player.advance(0.0)
	else:
		player.advance(forward)
		_blend_left = maxf(0.0, _blend_left - forward)
	_face.advance(delta, clip, detail)


## The authored rank motion cannot be exchanged in a crossfade or an action.
func blending() -> bool:
	return _manual_live and _blend_left > 0.0


func switch_ready() -> bool:
	return not blending() and not (_manual_live and state in SWAP_AFTER)


func reset_presentation() -> void:
	_manual_live = false
	_blend_left = 0.0


## A reused rig is a different visual owner, never a different soldier UID.
## Reset every instance's tint and face to the new roster identity.
func prepare_reuse(new_variant: int, new_seed: int) -> void:
	variant = posmod(new_variant, TINTS.size())
	face_seed = new_seed
	_appearance_seed = new_variant
	reset_presentation()
	if not is_instance_valid(_body):
		return
	var meshes: Array = [_body] if _body is MeshInstance3D else _body.find_children("*", "MeshInstance3D", true, false)
	for instance: MeshInstance3D in meshes:
		if instance.has_meta("formation_authored_material_known"):
			instance.material_override = instance.get_meta("formation_authored_material", null)
		_apply_tint(instance)
	if detail < 2:
		preload("res://scripts/visuals/roman_faces.gd").apply(_body, face_seed)
	_face.bind(_body, "soldier_%s_%d_%d" % [role, variant, face_seed])


static func clip_length(role_name: String, clip: String) -> float:
	if not _clip_lengths.has(role_name):
		var template := _scene(role_name,1).instantiate() as Node3D
		var animator := template.find_child("AnimationPlayer",true,false) as AnimationPlayer
		var lengths := {}
		if animator:
			for name: StringName in animator.get_animation_list():
				lengths[str(name)] = animator.get_animation(name).length
		_clip_lengths[role_name] = lengths
		template.free()
	return maxf(.01,float(_clip_lengths[role_name].get(clip,1.0)))


static func _scene(role_name: String, level: int) -> PackedScene:
	var path := "res://assets/soldiers/%s_%s.glb" % [role_name, LODS[level]]
	if level < 2:
		var candidate := "res://assets/characters/frontier_%s_%d.glb" % [FRONTIER_ROLES[role_name], level]
		if ResourceLoader.exists(candidate, "PackedScene"):
			path = candidate
	if not _scenes.has(path):
		_scenes[path] = load(path) as PackedScene
	return _scenes[path]

static func far_mesh(role_name: String) -> Mesh:
	if role_name not in ROLES:
		role_name = "heavy"
	if not _far_meshes.has(role_name):
		var template := _scene(role_name, 2).instantiate() as Node3D
		var mesh_instance := template as MeshInstance3D
		if mesh_instance == null:
			mesh_instance = template.find_children("*", "MeshInstance3D", true, false)[0]
		_far_meshes[role_name] = mesh_instance.mesh
		template.free()
	return _far_meshes[role_name]

func _body_scene() -> PackedScene:
	# Keep asset selection separate from the production player/skin binding.
	# Verification can exercise an exported fallback through this same driver.
	return _scene(role, detail)

func _replace_body() -> void:
	if _body:
		remove_child(_body)
		_body.free()
	player = null
	_animation_sources.clear()
	if detail == 2:
		var instance := MeshInstance3D.new()
		instance.mesh = far_mesh(role)
		_body = instance
		_apply_tint(instance)
	else:
		var scene := _body_scene()
		_body = scene.instantiate() as Node3D
		# Frontier replacements stand on soles above their origin; lower the
		# whole model by the authored lift (bones and clips are unchanged).
		if scene.resource_path.begins_with("res://assets/characters/frontier_"):
			_body.position.y = -AuthoredGround.sole_lift(scene.resource_path, _body) * _body.scale.y
		player = _body.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player:
			for animation_name: StringName in player.get_animation_list():
				_animation_sources[str(animation_name)] = player.get_animation(animation_name)
			# Keep clip maps private without duplicating every animation track
			# for every soldier. Changed loop modes are copied on first use.
			for library_name: StringName in player.get_animation_library_list():
				var library := player.get_animation_library(library_name).duplicate() as AnimationLibrary
				player.remove_animation_library(library_name)
				player.add_animation_library(library_name, library)
		for instance in _body.find_children("*", "MeshInstance3D", true, false):
			_apply_tint(instance as MeshInstance3D)
	add_child(_body)
	if detail < 2:
		preload("res://scripts/visuals/roman_faces.gd").apply(_body, face_seed if face_seed != -1 else _appearance_seed)
	_face.bind(_body, "soldier_%s_%d" % [role, variant])
	_play_clip()

func _apply_tint(instance: MeshInstance3D) -> void:
	if not instance.has_meta("formation_authored_material_known"):
		instance.set_meta("formation_authored_material_known", true)
		if instance.material_override != null:
			instance.set_meta("formation_authored_material", instance.material_override)
	if variant == 0:
		return
	var base := instance.mesh.surface_get_material(0) as StandardMaterial3D
	if not base:
		return
	var key := "%s/%d/%d/%d" % [role, detail, variant, base.get_instance_id()]
	if not _materials.has(key):
		var tinted := base.duplicate() as StandardMaterial3D
		tinted.albedo_color *= TINTS[variant]
		_materials[key] = tinted
	instance.material_override = _materials[key]

func _play_clip() -> void:
	if player == null:
		return
	var clip := state if player.has_animation(state) else "idle"
	var animation := _playback_animation(clip, clip in LOOPING)
	player.play(clip)
	player.seek(_phase * animation.length, true)
	_face.pose(clip, _phase, detail)


func _playback_animation(clip: String, looping: bool) -> Animation:
	var mode := Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	var animation := player.get_animation(clip)
	if animation.loop_mode == mode:
		return animation
	animation = CharacterMotion.playback_animation(_animation_sources[clip], mode)
	if player.get_animation(clip) != animation:
		var slash := clip.find("/")
		var library_name := clip.substr(0, slash) if slash >= 0 else ""
		var animation_name := clip.substr(slash + 1)
		var library := player.get_animation_library(library_name)
		library.remove_animation(animation_name)
		library.add_animation(animation_name, animation)
	return animation
