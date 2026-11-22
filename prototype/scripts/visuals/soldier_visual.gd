extends Node3D
## A presentation-only soldier. The simulation owns movement, timing and casualties.

const ROLES := ["heavy", "spear", "archer", "officer"]
const LODS := ["near", "mid", "far"]
const LOOPING := ["idle", "march", "run", "block", "wall", "testudo", "retreat"]
const ALIASES := {"walk": "march", "fall": "death", "shield_wall": "wall", "bow": "shoot"}
const TINTS := [Color.WHITE, Color(0.96, 0.88, 0.77), Color(0.83, 0.91, 0.97)]

static var _scenes: Dictionary = {}
static var _far_meshes: Dictionary = {}
static var _materials: Dictionary = {}
var role := "heavy"
var variant := 0
var detail := 0
var state := "idle"
var player: AnimationPlayer
var _body: Node3D
var _phase := 0.0

func _ready() -> void:
	if _body == null:
		_replace_body()

func configure(new_role: String, new_variant: int = 0) -> void:
	var resolved := new_role if new_role in ROLES else "heavy"
	var tint := posmod(new_variant, TINTS.size())
	if resolved == role and tint == variant and _body:
		return
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
	var clip: String = ALIASES.get(new_state, new_state)
	if clip == state and player and player.is_playing():
		return
	state = clip
	_phase = clampf(phase, 0.0, 1.0)
	_play_clip()

static func _scene(role_name: String, level: int) -> PackedScene:
	var path := "res://assets/soldiers/%s_%s.glb" % [role_name, LODS[level]]
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

func _replace_body() -> void:
	if _body:
		remove_child(_body)
		_body.free()
	player = null
	if detail == 2:
		var instance := MeshInstance3D.new()
		instance.mesh = far_mesh(role)
		_body = instance
		_apply_tint(instance)
	else:
		_body = _scene(role, detail).instantiate() as Node3D
		player = _body.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for instance in _body.find_children("*", "MeshInstance3D", true, false):
			_apply_tint(instance as MeshInstance3D)
	add_child(_body)
	_play_clip()

func _apply_tint(instance: MeshInstance3D) -> void:
	if variant == 0:
		return
	var base := instance.mesh.surface_get_material(0) as StandardMaterial3D
	var key := "%s/%d/%d" % [role, detail, variant]
	if not _materials.has(key):
		var tinted := base.duplicate() as StandardMaterial3D
		tinted.albedo_color *= TINTS[variant]
		_materials[key] = tinted
	instance.material_override = _materials[key]

func _play_clip() -> void:
	if player == null:
		return
	var clip := state if player.has_animation(state) else "idle"
	var animation := player.get_animation(clip)
	animation.loop_mode = Animation.LOOP_LINEAR if clip in LOOPING else Animation.LOOP_NONE
	player.play(clip)
	player.seek(_phase * animation.length, true)
