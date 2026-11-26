extends Node3D
## View over a mounted SoldierRoster UID. Horse and rider share one gameplay
## position. The existing horse skeleton and seated overlay supply the gait.
const Pose := preload("res://scripts/world/mounted_rider_pose.gd")
const HorseScene := preload("res://assets/horse/valdora_horse_rig.glb")
const RIDERS := [
	preload("res://assets/characters/frontier_civilian_man_0.glb"),
	preload("res://assets/characters/frontier_civilian_man_1.glb")]
var role := "cavalry"
var variant := 0
var detail := 1
var _seat: BoneAttachment3D
var _animation: AnimationPlayer
var _mounted := true
var _walker: AnimationPlayer
var _body: Node3D
var _pose := Pose.new()
var _lean := 0.0


func _ready() -> void:
	var horse := HorseScene.instantiate() as Node3D
	horse.rotation.y = PI # Valley figures face +Z; the riding rig faces -Z.
	add_child(horse)
	var skeleton := horse.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_seat = BoneAttachment3D.new()
	_seat.bone_name = "SOCKET_RIDER"
	skeleton.add_child(_seat)
	_animation = horse.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_build_rider()
	present("idle", 0.0, 0.0)


func _build_rider() -> void:
	if _body:
		_pose.stop()
		remove_child(_body)
		_body.free()
	_body = RIDERS[detail].instantiate()
	add_child(_body)
	_walker = _body.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_pose.start(_body)
	_pose.seated(_lean)
	var grip := BoneAttachment3D.new()
	grip.bone_name = "Hand_R"
	_pose.skeleton.add_child(grip)
	var shaft := MeshInstance3D.new()
	var wood := CylinderMesh.new()
	wood.height = 1.85
	wood.top_radius = 0.016
	wood.bottom_radius = 0.018
	wood.radial_segments = 7
	wood.rings = 0
	var finish := StandardMaterial3D.new()
	finish.albedo_color = Color("#795337")
	wood.material = finish
	shaft.mesh = wood
	grip.add_child(shaft)
	shaft.global_basis = global_basis
	var head := MeshInstance3D.new()
	var blade := PrismMesh.new()
	blade.size = Vector3(0.064, 0.19, 0.026)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("#8a8990")
	iron.metallic = 0.68
	blade.material = iron
	head.mesh = blade
	head.position.y = 0.98
	shaft.add_child(head)
	if not _mounted:
		_start_walking()


func _start_walking() -> void:
	_pose.stop()
	_walker.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_body.position = Vector3(0.66, 0, 0)


func set_mounted(value: bool) -> void:
	if value == _mounted:
		return
	_mounted = value
	if _mounted:
		_pose.start(_body)
	else:
		_start_walking()


func set_detail(level: int) -> void:
	if level != detail:
		detail = clampi(level, 0, 1)
		_build_rider()


func present(state: String, phase: float, _elapsed: float) -> void:
	var clip := "idle"
	if state in ["run", "retreat"]:
		clip = "canter"
	elif state == "march":
		clip = "trot"
	if _animation.current_animation != clip:
		_animation.play(clip)
	var length := _animation.get_animation(clip).length
	_animation.seek(fposmod(phase, 1.0) * length, true)
	if not _mounted:
		var foot_clip := "march" if state == "run" or state == "retreat" else state
		if not _walker.has_animation(foot_clip):
			foot_clip = "idle"
		if _walker.has_animation(foot_clip):
			_walker.play(foot_clip)
			_walker.seek(fposmod(phase, 1.0) * _walker.get_animation(foot_clip).length, true)
		return
	_lean = 1.0 if state in ["attack", "run", "retreat"] else 0.0
	_pose.seated(_lean)
	_body.global_position += _seat.global_position - _pose.pelvis_world()


func play_state(_state: String) -> void:
	# The roster has already removed this rider; remove his mount in the same frame.
	hide()
